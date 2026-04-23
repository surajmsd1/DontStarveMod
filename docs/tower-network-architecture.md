# Tower Network Implementation

Players right-click a discovered Lookout Tower to open the Tower Network
screen and fast-travel between towers. Discoveries are **server-authoritative,
saved with the world, and shared across all players**.

## Architecture

```
                        [ server ]
                            │
        TheWorld.components.shared_tower_network
            - towers = { [key] = {x,z,name} }
            - OnSave / OnLoad  (persists in world save)
            - AddTower(tower) → (key, entry, isNew)
                            │
                            │  RPC broadcast
                            ▼
                   (every connected client)
          GLOBAL.MysteryBox_SharedTowers[key] = {x,z,name}
                            │
                            ▼
                TowerNetworkScreen, TowerIndicator
```

**Authority lives on the server.** The client never edits the list directly
— it only mirrors what the server sends. This is what makes discoveries
shared and persistent.

## Save / load (how server save actually works in DST)

DST has two persistence mechanisms for mod data:

1. **Entity OnSave/OnLoad** — each saveable entity can define
   `inst.OnSave = function(inst, data) ... end` and
   `inst.OnLoad = function(inst, data) ... end`. Good for per-entity
   state (e.g. the tower's cooldown).
2. **Component OnSave/OnLoad on `TheWorld`** — attach a custom component
   to `TheWorld`, and the game will call the component's `OnSave` /
   `OnLoad` as part of the world save. Good for **shared, global** state.
   This is how we persist the tower network.

You do NOT call save manually. The game saves on shutdown, on `c_save()`,
and on periodic autosaves. Your component's `OnSave` returns a Lua table;
the engine serialises it into the world save file; `OnLoad` gets it back
the next time the world loads.

The component:

```lua
-- scripts/components/shared_tower_network.lua
local SharedTowerNetwork = Class(function(self, inst)
    self.inst = inst
    self.towers = {}
end)

function SharedTowerNetwork:AddTower(tower)
    -- returns key, entry, isNew
end

function SharedTowerNetwork:GetTowers() return self.towers end

function SharedTowerNetwork:OnSave()
    return { towers = self.towers }
end

function SharedTowerNetwork:OnLoad(data)
    if data and data.towers then self.towers = data.towers end
end
```

Attached via `AddPrefabPostInit("world", ...)`, master sim only:

```lua
AddPrefabPostInit("world", function(world)
    if not GLOBAL.TheWorld.ismastersim then return end
    world:AddComponent("shared_tower_network")
end)
```

DST resolves `"shared_tower_network"` to
`scripts/components/shared_tower_network.lua` automatically (the mod's
`scripts/` is on the package path).

## Discovery flow

```
[client] right-click tower
   │
   │   SendModRPCToServer(DiscoverTower, target)
   ▼
[server] RPC handler → DiscoverTowerServer(target, requester)
   - component:AddTower(target)   (saves via OnSave)
   - target:AddTag("tower_discovered")
   - if new:   broadcast SyncTowerAdd to every player
   - if dup:   only re-send to requester (client cache might be cold)
   ▼
[client] AddClientModRPCHandler("SyncTowerAdd")
   - GLOBAL.MysteryBox_SharedTowers[key] = {x,z,name}
   ▼
TowerNetworkScreen / TowerIndicator read GLOBAL.MysteryBox_SharedTowers
```

`OnActivate` in the tower prefab also calls
`MysteryBox_DiscoverTowerServer(inst)` (server-side only). That way stepping
on a tower auto-discovers it through the same pipeline — saved and
broadcast — even if nobody right-clicked.

## New-player sync

When a player spawns, the server sends the full list to *that player only*:

```lua
AddPlayerPostInit(function(player)
    if GLOBAL.TheWorld.ismastersim then
        player:DoTaskInTime(1, function()
            -- server: send every known tower to this player's client
            for key, entry in pairs(comp:GetTowers()) do
                SendModRPCToClient(
                    CLIENT_MOD_RPC["MysteryBox"]["SyncTowerAdd"],
                    player.userid, key, entry.x, entry.z, entry.name
                )
            end
        end)
    end
end)
```

A 1-second delay gives the client time to finish setup and register its
RPC handlers before the server starts firing snapshots.

## RPCs

| RPC                | Direction        | Payload                          |
|--------------------|------------------|----------------------------------|
| `DiscoverTower`    | client → server  | `target` (tower entity)          |
| `SyncTowerAdd`     | server → client  | `key, x, z, name`                |
| `TowerTeleportPos` | client → server  | `x, z`                           |

Server→client RPCs are registered with `AddClientModRPCHandler` and
invoked with `SendModRPCToClient(CLIENT_MOD_RPC[mod][name], userid, ...)`.

## DST server/client reference

| Thing            | Syncs server → client?      |
|------------------|-----------------------------|
| Entity **tags**  | YES (automatic)             |
| Entity props     | NO                          |
| `GLOBAL` tables  | NO (separate Lua envs)      |
| `TheWorld`       | NO (different object)       |
| `ThePlayer`      | NO (different object)       |
| `Ents`           | PARTIAL (nearby only)       |
| NetVars          | YES                         |
| RPCs             | ONE-WAY (explicit)          |

Everything in `GLOBAL.MysteryBox_SharedTowers` on the client got there by
an explicit RPC. That's why it works.

## Gotchas (still true)

### Require paths in runtime handlers
`require("screens/myscreen")` inside a callback fails. Load screens at
the top of `modmain.lua`:
```lua
local TowerNetworkScreen = require("screens/towernetworkscreen")
```

### Strict GLOBAL
`GLOBAL.MysteryBox_Foo` errors if never declared. Initialise first:
```lua
GLOBAL.MysteryBox_SharedTowers = GLOBAL.MysteryBox_SharedTowers or {}
```

### HUD z-order
Adding an overlay puts it on top of the minimap. Fix with
`MoveToBack()` then re-`AddChild` every other HUD child.

### Missing textures fail silent-ish
`Image("images/hud.xml", "arrow.tex")` warns in `client_log.txt` and
renders nothing. Use an existing atlas (e.g.
`images/global_redux.xml` / `scrollbar_handle.tex`).

## Files

- `scripts/components/shared_tower_network.lua` — server component +
  save/load
- `modmain.lua` — RPCs, world hookup, player-spawn sync, right-click
  handler, server-side discover helper
- `scripts/screens/towernetworkscreen.lua` — reads
  `GLOBAL.MysteryBox_SharedTowers`
- `scripts/prefabs/lookouttower.lua` — `OnActivate` calls
  `MysteryBox_DiscoverTowerServer`
- `scripts/widgets/towerindicator.lua` — checks shared table +
  `tower_discovered` tag

## Debugging

The `client_log.txt`:
`~/Library/Application Support/Klei/DoNotStarveTogether/client_log.txt`

Useful console checks:

```lua
-- server: inspect the live list
for k,v in pairs(TheWorld.components.shared_tower_network.towers) do print(k,v.name) end

-- client: inspect the mirror
for k,v in pairs(MysteryBox_SharedTowers) do print(k,v.name) end

-- force a save (server only)
c_save()
```

If discovery isn't propagating:
1. Screen empty on client → the client RPC handler didn't run. Confirm
   `MysteryBox_SharedTowers` exists and is populated on the client.
2. Empty after relog → component not attached, or `OnSave`/`OnLoad`
   payload malformed. Check the component is present on `TheWorld` and
   that `c_save()` runs without errors.
3. One player sees towers, another doesn't → `SendFullListTo` didn't
   fire for the second player (check `userid` is non-nil at spawn time;
   raise the `DoTaskInTime` delay if needed).
