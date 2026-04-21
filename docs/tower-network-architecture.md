# Tower Network Implementation - Lessons Learned

## The Challenge

Implementing a "Tower Network" UI where players can see all discovered lookout towers and teleport between them. Sounds simple, but DST's server/client architecture made this surprisingly difficult.

## What We Tried (And Why It Failed)

### Attempt 1: Global Lua Table
```lua
-- modmain.lua
GLOBAL.MysteryBox_DiscoveredTowers = {}

-- When discovering a tower:
GLOBAL.MysteryBox_DiscoveredTowers[guid] = { x = x, z = z, name = name }
```

**Why it failed:** DST runs server and client in separate Lua environments, even in single-player. The `GLOBAL` table on the server is completely different from `GLOBAL` on the client. The screen (UI) runs on client and sees an empty table.

### Attempt 2: Store on TheWorld
```lua
-- modmain.lua
GLOBAL.TheWorld.discovered_towers = {}

-- Screen reads:
local towers = TheWorld.discovered_towers
```

**Why it failed:** Same problem - `TheWorld` on server is a different object than `TheWorld` on client. Properties set on server don't appear on client.

### Attempt 3: Use Entity Tags + Scan Ents
```lua
-- On discovery:
tower:AddTag("tower_discovered")

-- Screen scans:
for k, ent in pairs(Ents) do
    if ent:HasTag("tower_discovered") then ...
end
```

**Why it failed:** Tags DO sync from server to client, but `Ents` on client only contains **nearby entities**. Far-away towers aren't loaded on the client, so they don't appear in `Ents`.

### Attempt 4: TheSim:FindEntities with Huge Radius
```lua
local allTowers = TheSim:FindEntities(0, 0, 0, 50000, {"lookouttower"})
```

**Why it failed:** Same issue - `TheSim:FindEntities` on client only returns entities that are loaded on the client (nearby ones).

### Attempt 5: Store on Player Object
```lua
-- RPC handler (runs on server):
AddModRPCHandler("MysteryBox", "DiscoverTower", function(player, target)
    player.discovered_towers[key] = { x = x, z = z, name = name }
end)

-- Screen reads:
local towers = self.owner.discovered_towers
```

**Why it partially failed:** The `player` in the RPC is the server-side player object. Setting properties on it doesn't sync to the client-side player object. Client still saw empty table.

## The Solution That Works

**Store on BOTH server AND client:**

```lua
-- Right-click handler (runs on CLIENT):
GLOBAL.TheInput:AddMouseButtonHandler(function(button, down)
    local target = GLOBAL.TheInput:GetWorldEntityUnderMouse()
    if target and target:HasTag("lookouttower") then
        -- 1. Tell server (for persistence/tags)
        SendModRPCToServer(MOD_RPC["MysteryBox"]["DiscoverTower"], target)

        -- 2. Also store on CLIENT player directly
        if not player.discovered_towers then
            player.discovered_towers = {}
        end
        local x, _, z = target.Transform:GetWorldPosition()
        local key = math.floor(x) .. "_" .. math.floor(z)
        player.discovered_towers[key] = { x = x, z = z, name = name }

        -- Now screen can read from client player's table
        GLOBAL.TheFrontEnd:PushScreen(TowerNetworkScreen(player, target))
    end
end)
```

**Key insight:** The right-click handler runs on CLIENT, so `player` in that context IS the client-side player. We can store data directly on it.

## DST Server/Client Architecture Summary

| Thing | Syncs Server → Client? | Notes |
|-------|------------------------|-------|
| Entity Tags | YES | `inst:AddTag("foo")` syncs automatically |
| Entity Properties | NO | `inst.foo = "bar"` is server-only |
| GLOBAL tables | NO | Separate Lua environments |
| TheWorld | NO | Different objects on server/client |
| ThePlayer | NO | Different objects, same entity |
| Ents | PARTIAL | Client only has nearby entities |
| NetVars | YES | Complex to set up, but properly syncs |
| RPCs | ONE-WAY | Client → Server or Server → Client |

## Other Gotchas We Hit

### 1. Custom Screen Require Paths
```lua
-- WRONG (fails at runtime):
GLOBAL.TheInput:AddMouseButtonHandler(function()
    local MyScreen = require("screens/myscreen")  -- Module not found!
end)

-- RIGHT (load at startup):
local MyScreen = require("screens/towernetworkscreen")  -- Top of modmain.lua
GLOBAL.TheInput:AddMouseButtonHandler(function()
    GLOBAL.TheFrontEnd:PushScreen(MyScreen(player))  -- Works
end)
```

### 2. GLOBAL Strict Mode
```lua
-- WRONG (crashes in DST's strict mode):
if GLOBAL.MysteryBox_Foo then ...  -- Error: variable not declared

-- RIGHT:
if rawget(GLOBAL, "MysteryBox_Foo") then ...
-- Or just create it first:
GLOBAL.MysteryBox_Foo = GLOBAL.MysteryBox_Foo or {}
```

### 3. HUD Widget Z-Order
```lua
-- Scout overlay was covering minimap
-- WRONG: Just add overlay
player.HUD.root:AddChild(ScoutOverlay(player))

-- RIGHT: Move overlay to back, re-add everything else on top
player._scout_overlay = player.HUD.root:AddChild(ScoutOverlay(player))
player._scout_overlay:MoveToBack()
for _, child in pairs(player.HUD.root.children) do
    if child ~= player._scout_overlay then
        player.HUD.root:AddChild(child)  -- Re-add moves to top
    end
end
```

### 4. Arrow Texture Doesn't Exist
```lua
-- WRONG (texture doesn't exist):
Image("images/hud.xml", "arrow.tex")  -- WARNING! Could not find region

-- RIGHT (use existing texture):
Image("images/global_redux.xml", "scrollbar_handle.tex")
```

## Multiplayer Limitations

Current implementation stores discoveries per-player in a non-syncing table. In multiplayer:
- Each player tracks their own discoveries
- Players don't share discoveries with each other
- Teleportation works fine once you've personally visited a tower

To fix: Would need NetVars or a server-authoritative shared table with proper client sync.

## Files Changed

- `modmain.lua` - Discovery storage, RPCs, right-click handler
- `scripts/screens/towernetworkscreen.lua` - Reads from player.discovered_towers
- `scripts/prefabs/lookouttower.lua` - Scout mode, biome/coastline reveal
- `scripts/widgets/towerindicator.lua` - HUD indicator for nearby towers
