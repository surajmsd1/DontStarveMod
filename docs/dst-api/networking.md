# Networking & Multiplayer API

## Overview
Don't Starve Together is a multiplayer game with a client-server architecture. Understanding how data flows between server and clients is critical for mod development.

## Quick Reference

| Concept | Description |
|---------|-------------|
| `TheWorld.ismastersim` | True if running on server |
| `TheNet` | Network interface |
| `SetPristine()` | Network sync point in prefab creation |
| `netvars` | Network-synced variables |
| `RPC` | Remote Procedure Calls |

## Server vs Client

### The Golden Rule
```lua
-- ALWAYS check this before server-only code
if not TheWorld.ismastersim then
    return
end
```

### What Runs Where

| Code Location | Server | Client |
|---------------|--------|--------|
| `modmain.lua` | ✓ | ✓ |
| Component logic | ✓ | ✗ |
| Brain/AI | ✓ | ✗ |
| Input handling | ✗ | ✓ |
| Animation | ✓ | ✓ |
| Sound effects | ✓ | ✓ |

### Prefab Split Pattern
```lua
local function fn()
    local inst = CreateEntity()

    -- SHARED CODE (runs on server AND client)
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("mybank")
    inst.AnimState:SetBuild("mybuild")

    inst:AddTag("mytag")

    -- NETWORK SYNC POINT
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst  -- Client stops here
    end

    -- SERVER ONLY CODE (below SetPristine)
    inst:AddComponent("health")
    inst:AddComponent("combat")
    inst:AddComponent("lootdropper")

    return inst
end
```

## TheNet API

### Announcements
```lua
-- Show message to ALL players
TheNet:Announce("Hello everyone!")

-- In modmain.lua
GLOBAL.TheNet:Announce("Server message!")
```

### Player Information
```lua
-- Get all player user IDs
local users = TheNet:GetClientTable()
for _, user in ipairs(users) do
    print("Player: " .. user.name)
    print("UserID: " .. user.userid)
end

-- Check if this is a dedicated server
local isDedicated = TheNet:IsDedicated()

-- Check if server is online
local isOnline = TheNet:IsOnlineMode()
```

### AllPlayers
```lua
-- Get all player entities
local players = AllPlayers
for _, player in ipairs(players) do
    local name = player:GetDisplayName()
    local x, y, z = player.Transform:GetWorldPosition()
end

-- In modmain.lua
local players = GLOBAL.AllPlayers
```

## Network Variables (netvars)

For syncing data from server to clients.

### Basic NetVars
```lua
local function fn()
    local inst = CreateEntity()

    -- Add before SetPristine
    inst.entity:AddNetwork()

    -- Create net variable
    inst.myvalue = net_byte(inst.GUID, "mymod.myvalue", "myvaluedirty")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        -- Client can READ netvar
        inst:ListenForEvent("myvaluedirty", function()
            print("Value changed to: " .. inst.myvalue:value())
        end)
        return inst
    end

    -- Server can WRITE netvar
    inst.myvalue:set(42)

    return inst
end
```

### NetVar Types
| Type | Lua Type | Range |
|------|----------|-------|
| `net_bool` | boolean | true/false |
| `net_byte` | number | 0-255 |
| `net_ushort` | number | 0-65535 |
| `net_int` | number | full int |
| `net_float` | number | decimal |
| `net_string` | string | any string |
| `net_entity` | entity | entity reference |

### NetVar Pattern
```lua
-- In prefab
local function fn()
    local inst = CreateEntity()
    inst.entity:AddNetwork()

    -- Create synced health display
    inst.nethealthpercent = net_byte(inst.GUID, "mymod.healthpct")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Update when health changes
    inst:ListenForEvent("healthdelta", function()
        local pct = inst.components.health:GetPercent()
        inst.nethealthpercent:set(math.floor(pct * 100))
    end)

    return inst
end
```

## Remote Procedure Calls (RPC)

For client-to-server communication.

### Defining RPC
```lua
-- In modmain.lua
AddModRPCHandler("mymod", "myaction", function(player, data)
    -- This runs on SERVER
    print(player:GetDisplayName() .. " sent: " .. tostring(data))
end)
```

### Sending RPC (client to server)
```lua
-- Client-side code
SendModRPCToServer(MOD_RPC["mymod"]["myaction"], "hello")
```

### Full RPC Example
```lua
-- modmain.lua

-- Define handler (runs on server)
AddModRPCHandler("mysterybox", "requestbox", function(player)
    if player and player:IsValid() then
        local x, y, z = player.Transform:GetWorldPosition()
        local box = GLOBAL.SpawnPrefab("mysterybox")
        if box then
            box.Transform:SetPosition(x + 2, 0, z + 2)
        end
    end
end)

-- Client would call:
-- SendModRPCToServer(MOD_RPC["mysterybox"]["requestbox"])
```

## Classified Pattern

For complex server-client communication, use "classified" entities.

```lua
-- player_classified contains synced player data
-- Access via player.player_classified

-- Example: Check synced inventory on client
local function HasItem(player, prefab)
    if TheWorld.ismastersim then
        -- Server: use component directly
        return player.components.inventory:Has(prefab, 1)
    else
        -- Client: would need classified sync
        -- (Complex, usually not needed for mods)
    end
end
```

## Common Patterns

### Safe Player Iteration
```lua
local function DoForAllPlayers(fn)
    for _, player in ipairs(AllPlayers) do
        if player and player:IsValid() and not player:HasTag("playerghost") then
            fn(player)
        end
    end
end

-- Usage
DoForAllPlayers(function(player)
    local x, y, z = player.Transform:GetWorldPosition()
    SpawnPrefab("goldnugget").Transform:SetPosition(x, 0, z)
end)
```

### Server-Only Event Trigger
```lua
local function TriggerServerEvent()
    if not TheWorld.ismastersim then
        return  -- Only server runs this
    end

    TheNet:Announce("Server event starting!")
    -- Server logic here
end
```

### Multiplayer Scaling
```lua
local function GetScaledCount(baseCount)
    local playerCount = #AllPlayers
    -- More players = more spawns
    return math.ceil(baseCount * (1 + (playerCount - 1) * 0.5))
end

-- Base: 5 spiders
-- 1 player: 5 spiders
-- 2 players: 8 spiders (5 * 1.5)
-- 3 players: 10 spiders (5 * 2.0)
```

### Broadcast to All Players
```lua
local function BroadcastMessage(message)
    -- TheNet:Announce shows in chat
    TheNet:Announce(message)

    -- Or speech bubble on each player
    for _, player in ipairs(AllPlayers) do
        if player.components.talker then
            player.components.talker:Say(message)
        end
    end
end
```

## Dedicated Server Considerations

### Check for Dedicated
```lua
if TheNet:IsDedicated() then
    -- No local player, different behavior needed
end
```

### GetPlayer() Issues
```lua
-- ThePlayer only exists on clients
-- On dedicated server, ThePlayer is nil

-- Use AllPlayers instead
local function GetFirstPlayer()
    if #AllPlayers > 0 then
        return AllPlayers[1]
    end
    return nil
end
```

## Gotchas

1. **ThePlayer is client-only**
   ```lua
   -- WRONG on server
   local player = ThePlayer

   -- CORRECT
   local player = AllPlayers[1]  -- Or iterate
   ```

2. **Components are server-only**
   ```lua
   -- On client, this fails:
   player.components.health  -- nil!

   -- Must use netvars for client-side data
   ```

3. **Don't assume player count**
   ```lua
   -- WRONG
   local player = AllPlayers[1]  -- Might not exist!

   -- CORRECT
   if #AllPlayers > 0 then
       local player = AllPlayers[1]
   end
   ```

4. **Events don't auto-sync**
   - Server-side events stay on server
   - Use netvars or RPC for cross-boundary communication

5. **Spawning on client does nothing**
   ```lua
   -- Client-side SpawnPrefab creates temporary entity
   -- Only server spawns persist
   ```

## Testing Multiplayer

### Console Commands
```lua
-- Check if server
print(TheWorld.ismastersim)

-- Check player count
print("#AllPlayers: " .. #AllPlayers)

-- Check network status
print("Dedicated: " .. tostring(TheNet:IsDedicated()))
print("Online: " .. tostring(TheNet:IsOnlineMode()))
```

### Local Testing
1. Host game with "Allow Pause" disabled
2. Have another player join via LAN
3. Test both server (host) and client perspectives

## See Also

- [entities.md](entities.md) - SetPristine pattern
- [events.md](events.md) - World events
- [components.md](components.md) - Server-only components

## Sources

- DST Game Scripts: `scripts/networking.lua`
- DST Game Scripts: `scripts/netvars.lua`
- Klei Forums networking guides
