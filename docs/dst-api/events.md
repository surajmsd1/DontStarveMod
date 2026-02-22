# Events API Reference

## Overview
DST uses an event-driven system for communication between entities and components. Events allow loose coupling - entities can broadcast happenings without knowing who's listening.

## Quick Reference

| Method | Purpose |
|--------|---------|
| `inst:ListenForEvent(name, fn)` | Listen for event on entity |
| `inst:PushEvent(name, data)` | Trigger event on entity |
| `inst:RemoveEventCallback(name, fn)` | Stop listening |
| `TheWorld:ListenForEvent(name, fn)` | Listen for world events |
| `TheWorld:PushEvent(name, data)` | Trigger world events |

## Listening for Events

### Basic Pattern
```lua
inst:ListenForEvent("eventname", function(inst, data)
    -- Handle event
    print("Event received!")
end)
```

### With Data
```lua
inst:ListenForEvent("attacked", function(inst, data)
    local attacker = data.attacker
    local damage = data.damage
    print("Attacked by " .. tostring(attacker) .. " for " .. damage)
end)
```

### Listen on Another Entity
```lua
-- Listen for player death from any entity
inst:ListenForEvent("death", function(player)
    print("Player died!")
end, player)  -- Third argument: source entity
```

## Pushing Events

### Basic Push
```lua
inst:PushEvent("myevent")
```

### Push with Data
```lua
inst:PushEvent("myevent", {
    value = 100,
    source = "mysterybox",
    target = player
})
```

## Common Entity Events

### Combat Events

**death**
```lua
inst:ListenForEvent("death", function(inst, data)
    print("Entity died")
    -- data may contain: cause, afflicter
end)
```

**attacked**
```lua
inst:ListenForEvent("attacked", function(inst, data)
    -- data.attacker - who attacked
    -- data.damage - amount of damage
    -- data.weapon - weapon used (may be nil)
end)
```

**killed**
```lua
-- Fires when THIS entity kills something
inst:ListenForEvent("killed", function(inst, data)
    -- data.victim - what was killed
end)
```

**healthdelta**
```lua
inst:ListenForEvent("healthdelta", function(inst, data)
    -- data.amount - change amount (negative = damage)
    -- data.oldpercent - health % before
    -- data.newpercent - health % after
end)
```

### Interaction Events

**onpickup**
```lua
inst:ListenForEvent("onpickup", function(inst, data)
    -- data.owner - who picked it up
end)
```

**ondropped**
```lua
inst:ListenForEvent("ondropped", function(inst)
    print("Item was dropped")
end)
```

**onremove**
```lua
inst:ListenForEvent("onremove", function(inst)
    print("Entity being removed from world")
end)
```

### State Events

**animover**
```lua
-- Fires when current animation finishes
inst:ListenForEvent("animover", function(inst)
    inst.AnimState:PlayAnimation("idle")
end)
```

**animqueueover**
```lua
-- Fires when animation queue is empty
inst:ListenForEvent("animqueueover", function(inst)
    print("All animations done")
end)
```

**entitysleep**
```lua
-- Entity went out of active range
inst:ListenForEvent("entitysleep", function(inst)
    print("Entity sleeping (inactive)")
end)
```

**entitywake**
```lua
-- Entity came into active range
inst:ListenForEvent("entitywake", function(inst)
    print("Entity woke up (active)")
end)
```

## World Events

Listen/push on `TheWorld` for global events.

### Phase & Time

**phasechanged**
```lua
TheWorld:ListenForEvent("phasechanged", function(world, data)
    -- data.newphase - "day", "dusk", or "night"
    print("Phase: " .. data.newphase)
end)
```

**cycleschanged**
```lua
TheWorld:ListenForEvent("cycleschanged", function(world, cycles)
    print("Day " .. (cycles + 1))
end)
```

**seasonchanged** (via WatchWorldState preferred)
```lua
-- Better approach:
TheWorld:WatchWorldState("season", function(world, season)
    print("Season: " .. season)
end)
```

### ms_ Events (Server Commands)

These push events change world state:

```lua
-- Force phase
TheWorld:PushEvent("ms_setphase", "day")

-- Force season
TheWorld:PushEvent("ms_setseason", "winter")

-- Force precipitation
TheWorld:PushEvent("ms_forceprecipitation", true)  -- Start rain
TheWorld:PushEvent("ms_forceprecipitation", false) -- Stop rain

-- Force moon phase
TheWorld:PushEvent("ms_setmoonphase", "full")

-- Spawn hounds attack
TheWorld:PushEvent("ms_sendhoundwave")

-- Skip time
TheWorld:PushEvent("ms_advanceseason")
TheWorld:PushEvent("ms_nextcycle")
```

### Player Events

**ms_playerjoined**
```lua
TheWorld:ListenForEvent("ms_playerjoined", function(world, player)
    print(player:GetDisplayName() .. " joined!")
end)
```

**ms_playerleft**
```lua
TheWorld:ListenForEvent("ms_playerleft", function(world, player)
    print(player:GetDisplayName() .. " left!")
end)
```

## Custom Events

### Define Your Own
```lua
-- Push custom event
inst:PushEvent("mymod_boxopened", {
    opener = player,
    loot = {"goldnugget", "redgem"},
    rarity = "rare"
})

-- Listen for custom event
inst:ListenForEvent("mymod_boxopened", function(inst, data)
    print("Box opened by: " .. tostring(data.opener))
    print("Rarity: " .. data.rarity)
end)
```

### Naming Convention
- Prefix with mod name to avoid collisions
- Use underscores: `mymod_event_name`

## Removing Event Listeners

### With Function Reference
```lua
local function OnDeath(inst)
    print("Dead!")
end

inst:ListenForEvent("death", OnDeath)

-- Later...
inst:RemoveEventCallback("death", OnDeath)
```

### Using ReturnedHandle (DST pattern)
```lua
-- Some events return a handle
local handle = inst:ListenForEvent("attacked", function(inst, data)
    -- ...
end)

-- Remove using handle (if API supports it)
```

## Event Handler Pattern

For complex mods, create an event handler object:

```lua
local EventHandler = {
    listeners = {}
}

function EventHandler:RegisterListener(entity, event, fn)
    entity:ListenForEvent(event, fn)
    table.insert(self.listeners, {
        entity = entity,
        event = event,
        fn = fn
    })
end

function EventHandler:CleanupAll()
    for _, listener in ipairs(self.listeners) do
        if listener.entity:IsValid() then
            listener.entity:RemoveEventCallback(listener.event, listener.fn)
        end
    end
    self.listeners = {}
end
```

## Common Patterns

### React to Any Player Death
```lua
-- In modmain.lua
AddPlayerPostInit(function(player)
    player:ListenForEvent("death", function(player)
        GLOBAL.TheNet:Announce(player:GetDisplayName() .. " has died!")
    end)
end)
```

### Track All Spawned Enemies
```lua
local spawnedEnemies = {}

local function SpawnEnemy(prefab, x, z)
    local enemy = SpawnPrefab(prefab)
    if enemy then
        enemy.Transform:SetPosition(x, 0, z)
        table.insert(spawnedEnemies, enemy)

        enemy:ListenForEvent("death", function(inst)
            -- Remove from tracking
            for i, e in ipairs(spawnedEnemies) do
                if e == inst then
                    table.remove(spawnedEnemies, i)
                    break
                end
            end
            CheckVictory()
        end)
    end
    return enemy
end

local function CheckVictory()
    if #spawnedEnemies == 0 then
        TheNet:Announce("All enemies defeated!")
    end
end
```

### Chain Events (Wave System)
```lua
local function StartWave1()
    TheNet:Announce("WAVE 1!")
    for i = 1, 5 do
        SpawnEnemy("spider", x, z)
    end
end

local function StartWave2()
    TheNet:Announce("WAVE 2!")
    for i = 1, 5 do
        SpawnEnemy("hound", x, z)
    end
end

-- Use DoTaskInTime instead of waiting for death events (simpler)
world:DoTaskInTime(0, StartWave1)
world:DoTaskInTime(60, StartWave2)
```

### One-Time Event
```lua
local hasTriggered = false

inst:ListenForEvent("death", function(inst)
    if hasTriggered then return end
    hasTriggered = true

    -- Only runs once
    TheNet:Announce("First death of the game!")
end)
```

## Gotchas

1. **Events don't cross client/server boundary automatically**
   - Server events aren't received by clients
   - Use NetVars for syncing state

2. **Listener function signature**
   ```lua
   -- WRONG - missing inst
   inst:ListenForEvent("death", function(data)

   -- CORRECT
   inst:ListenForEvent("death", function(inst, data)
   ```

3. **Event data may be nil**
   ```lua
   inst:ListenForEvent("myevent", function(inst, data)
       if data then  -- Check data exists
           print(data.value)
       end
   end)
   ```

4. **Don't Push in Listen (infinite loop)**
   ```lua
   -- WRONG - infinite loop
   inst:ListenForEvent("healthdelta", function(inst, data)
       inst:PushEvent("healthdelta", data)
   end)
   ```

5. **Memory leaks with listeners**
   - Remove listeners when entity is destroyed
   - Use `onremove` event to cleanup

## See Also

- [world-state.md](world-state.md) - WatchWorldState patterns
- [components.md](components.md) - Component events
- [networking.md](networking.md) - Network events

## Sources

- DST Game Scripts: `scripts/entityscript.lua`
- DST Game Scripts: `scripts/prefabs/world.lua`
