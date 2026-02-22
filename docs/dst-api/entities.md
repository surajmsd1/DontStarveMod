# Entities & Prefabs API

## Overview
Entities are the core objects in DST - everything from players, mobs, items, structures, and effects. Prefabs are the "blueprints" that define how entities are created.

## Quick Reference

| API | Description |
|-----|-------------|
| `SpawnPrefab("name")` | Create entity from prefab |
| `CreateEntity()` | Create empty entity (for custom prefabs) |
| `entity:Remove()` | Delete entity from world |
| `entity.Transform:SetPosition(x, y, z)` | Set position |
| `entity.Transform:GetWorldPosition()` | Get position |
| `entity:AddTag("tag")` | Add tag to entity |
| `entity:HasTag("tag")` | Check if entity has tag |
| `entity:AddComponent("name")` | Add component |

## Spawning Entities

### SpawnPrefab

**Purpose:** Create a new entity from a prefab definition.

**In modmain.lua:**
```lua
local spider = GLOBAL.SpawnPrefab("spider")
if spider then
    spider.Transform:SetPosition(x, 0, z)
end
```

**In prefab files:**
```lua
local spider = SpawnPrefab("spider")
if spider then
    spider.Transform:SetPosition(x, 0, z)
end
```

**Parameters:**
- `prefab_name` (string): Name of the prefab to spawn

**Returns:**
- Entity object on success
- `nil` if prefab doesn't exist

**Gotchas:**
- ALWAYS check if return value is nil
- Use `GLOBAL.SpawnPrefab` in modmain.lua
- Direct `SpawnPrefab` works in prefab files

### SpawnNear Pattern
```lua
-- Spawn entity at random position near a point
local function SpawnNear(prefab, x, z, radius)
    local entity = SpawnPrefab(prefab)
    if entity then
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * radius
        entity.Transform:SetPosition(
            x + math.cos(angle) * dist,
            0,
            z + math.sin(angle) * dist
        )
    end
    return entity
end

-- Usage
SpawnNear("spider", playerX, playerZ, 10)  -- Spawn spider within 10 units
```

## Transform Component

Every entity has a Transform for position/rotation.

### SetPosition
```lua
-- Set absolute world position
entity.Transform:SetPosition(x, y, z)

-- y is vertical (usually 0 for ground)
spider.Transform:SetPosition(100, 0, 200)
```

### GetWorldPosition
```lua
-- Get current position (returns 3 values)
local x, y, z = entity.Transform:GetWorldPosition()

-- Common pattern
local x, y, z = player.Transform:GetWorldPosition()
SpawnPrefab("spider").Transform:SetPosition(x + 5, 0, z + 5)
```

### SetRotation
```lua
-- Set rotation in degrees (0-360)
entity.Transform:SetRotation(90)
```

### GetRotation
```lua
local rotation = entity.Transform:GetRotation()
```

## Entity Lifecycle

### Creating Custom Entities

**In prefab file (scripts/prefabs/myentity.lua):**
```lua
require "prefabutil"

local assets = {
    Asset("ANIM", "anim/myanimation.zip"),
}

local function fn()
    local inst = CreateEntity()

    -- Required entity components
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()  -- Required for multiplayer

    -- Physics (for items that can be picked up)
    MakeInventoryPhysics(inst)

    -- Animation setup
    inst.AnimState:SetBank("mybank")
    inst.AnimState:SetBuild("mybuild")
    inst.AnimState:PlayAnimation("idle")

    -- Tags
    inst:AddTag("structure")

    -- Network sync point
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Server-only components below
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    return inst
end

return Prefab("myentity", fn, assets)
```

### Removing Entities
```lua
-- Delete entity from world
entity:Remove()

-- Safe removal pattern (delayed)
entity:DoTaskInTime(0, function()
    entity:Remove()
end)
```

### IsValid Check
```lua
-- Check if entity still exists
if entity and entity:IsValid() then
    -- Safe to use entity
end
```

## Tags System

Tags are string labels for categorizing and identifying entities.

### Adding Tags
```lua
inst:AddTag("monster")
inst:AddTag("hostile")
inst:AddTag("mymod_special")
```

### Checking Tags
```lua
if entity:HasTag("player") then
    -- It's a player
end

if entity:HasTag("monster") and not entity:HasTag("epic") then
    -- Regular monster, not a boss
end
```

### Removing Tags
```lua
inst:RemoveTag("hostile")
```

### Common Tags
| Tag | Meaning |
|-----|---------|
| `player` | Player character |
| `monster` | Hostile creature |
| `hostile` | Will attack players |
| `animal` | Passive creature |
| `structure` | Built structure |
| `INLIMBO` | Not physically in world |
| `FX` | Visual effect |
| `NOCLICK` | Can't be clicked |
| `notarget` | Combat ignores this |
| `epic` | Boss creature |

## Finding Entities

### FindEntity
```lua
-- Find nearest entity matching criteria
local function IsMonster(entity)
    return entity:HasTag("monster") and entity.components.health
end

local nearest = FindEntity(
    player,           -- search from
    20,               -- radius
    IsMonster         -- filter function
)

if nearest then
    print("Found monster: " .. tostring(nearest.prefab))
end
```

### TheSim:FindEntities
```lua
-- Find all entities in radius
local x, y, z = player.Transform:GetWorldPosition()
local entities = TheSim:FindEntities(x, y, z, 30)  -- 30 unit radius

for _, ent in ipairs(entities) do
    if ent:HasTag("spider") then
        ent:Remove()
    end
end
```

### FindEntities with Tags
```lua
-- More efficient: filter by tags
local x, y, z = player.Transform:GetWorldPosition()
local monsters = TheSim:FindEntities(
    x, y, z,
    20,                     -- radius
    {"monster"},            -- must have ALL these tags
    {"player", "companion"} -- must have NONE of these tags
)
```

## Physics

### MakeInventoryPhysics
```lua
-- For items that can be picked up
MakeInventoryPhysics(inst)
```

### MakeCharacterPhysics
```lua
-- For creatures/players
MakeCharacterPhysics(inst, mass, radius)
MakeCharacterPhysics(inst, 50, 0.5)
```

### Setting Velocity
```lua
-- Launch item with physics
if entity.Physics then
    entity.Physics:SetVel(vx, vy, vz)
end

-- Example: Launch item upward
local angle = math.random() * 2 * math.pi
entity.Physics:SetVel(
    math.cos(angle) * 3,  -- x velocity
    8,                     -- y velocity (up)
    math.sin(angle) * 3   -- z velocity
)
```

## Network (Multiplayer)

### IsValid Checks
```lua
-- Check if on server (master simulation)
if not TheWorld.ismastersim then
    return inst  -- Client can't do server logic
end
```

### SetPristine
```lua
-- Required in prefab creation
inst.entity:SetPristine()
if not TheWorld.ismastersim then
    return inst
end
-- Server-only code below this point
```

### Why This Pattern?
- `SetPristine()` marks the "clean" state for network sync
- Clients get entity up to this point
- Server-only components are added after
- This ensures clients don't crash on missing server components

## Common Patterns

### Spawn Multiple with Delay
```lua
-- Spawn 10 spiders over 5 seconds
for i = 1, 10 do
    world:DoTaskInTime(i * 0.5, function()
        local spider = SpawnPrefab("spider")
        if spider then
            spider.Transform:SetPosition(x, 0, z)
        end
    end)
end
```

### Spawn in Circle
```lua
local function SpawnInCircle(prefab, centerX, centerZ, radius, count)
    for i = 1, count do
        local angle = (i / count) * 2 * math.pi
        local entity = SpawnPrefab(prefab)
        if entity then
            entity.Transform:SetPosition(
                centerX + math.cos(angle) * radius,
                0,
                centerZ + math.sin(angle) * radius
            )
        end
    end
end

-- Spawn 8 spiders in a circle
SpawnInCircle("spider", x, z, 10, 8)
```

### Entity Cleanup
```lua
-- Track and cleanup spawned entities
local spawnedEntities = {}

local function SpawnTracked(prefab, x, z)
    local ent = SpawnPrefab(prefab)
    if ent then
        ent.Transform:SetPosition(x, 0, z)
        table.insert(spawnedEntities, ent)
    end
    return ent
end

local function CleanupAll()
    for _, ent in ipairs(spawnedEntities) do
        if ent and ent:IsValid() then
            ent:Remove()
        end
    end
    spawnedEntities = {}
end
```

## Gotchas & Common Mistakes

1. **Forgetting nil check after SpawnPrefab**
   ```lua
   -- WRONG - will crash if prefab doesn't exist
   SpawnPrefab("misspelled"):SetPosition(x, 0, z)

   -- CORRECT
   local ent = SpawnPrefab("spider")
   if ent then
       ent.Transform:SetPosition(x, 0, z)
   end
   ```

2. **Wrong GLOBAL usage**
   ```lua
   -- In modmain.lua: WRONG
   local spider = SpawnPrefab("spider")

   -- In modmain.lua: CORRECT
   local spider = GLOBAL.SpawnPrefab("spider")

   -- In prefab files: Direct access works
   local spider = SpawnPrefab("spider")
   ```

3. **Forgetting y=0 in SetPosition**
   ```lua
   -- WRONG - 2 arguments
   entity.Transform:SetPosition(x, z)

   -- CORRECT - 3 arguments
   entity.Transform:SetPosition(x, 0, z)
   ```

4. **Using entity after Remove()**
   ```lua
   entity:Remove()
   entity:DoSomething()  -- CRASH! Entity is gone
   ```

## See Also

- [prefab-list.md](prefab-list.md) - All spawnable prefab names
- [components.md](components.md) - Component reference
- [networking.md](networking.md) - Multiplayer details

## Sources

- DST Game Scripts: `scripts/prefabs/*.lua`
- DST Game Scripts: `scripts/mainfunctions.lua`
- DST Game Scripts: `scripts/entityscript.lua`
