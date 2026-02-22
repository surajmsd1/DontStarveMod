# Data-Driven Events Pattern

## Problem
Our current modmain.lua has 21 events, each with ~30 lines of nearly identical code. This is:
- Hard to maintain
- Easy to introduce bugs
- Tedious to add new events

## Solution: Data Tables + Generic Executor

Instead of 21 separate functions, define events as DATA and have ONE function execute them.

## Current Pattern (BAD - Duplicated Code)

```lua
-- Event 1: 30 lines
mgr:RegisterEvent({
    id = "spider_ambush",
    name = "SPIDER AMBUSH!",
    Execute = function(self, world, target)
        local player = target or GetRandomPlayer()
        if not player then return end
        local x, y, z = player.Transform:GetWorldPosition()
        for i = 1, 8 do SpawnNear("spider", x, z, 10) end
        SpawnNear("spear", x, z, 3)
    end,
})

-- Event 2: Another 30 lines of nearly identical code
mgr:RegisterEvent({
    id = "hound_wave",
    name = "HOUND WAVE!",
    Execute = function(self, world, target)
        local player = target or GetRandomPlayer()  -- DUPLICATE
        if not player then return end               -- DUPLICATE
        local x, y, z = player.Transform:GetWorldPosition()  -- DUPLICATE
        for i = 1, 5 do SpawnNear("hound", x, z, 10) end
        for i = 1, 5 do SpawnNear("goldnugget", x, z, 5) end
    end,
})
-- ... repeat 19 more times
```

## Better Pattern (GOOD - Data-Driven)

```lua
-- Define events as DATA (compact, readable)
local EVENT_DATA = {
    spider_ambush = {
        name = "SPIDER AMBUSH!",
        announcement = "WARNING: Spiders emerging! Gear nearby...",
        category = "CHALLENGE",
        rarity = "COMMON",
        spawns = {
            {prefab = "spider", count = 8, radius = 10},
            {prefab = "spear", count = 1, radius = 3},
            {prefab = "armorwood", count = 1, radius = 3},
        },
    },
    hound_wave = {
        name = "HOUND WAVE!",
        announcement = "DANGER: Hounds approach!",
        category = "CHALLENGE",
        rarity = "UNCOMMON",
        spawns = {
            {prefab = "hound", count = 5, radius = 10},
            {prefab = "goldnugget", count = 5, radius = 5},
        },
    },
    loot_explosion = {
        name = "LOOT EXPLOSION!",
        announcement = "Items rain from the sky!",
        category = "REWARD",
        rarity = "UNCOMMON",
        spawns = {
            {prefab = "goldnugget", count = 10, radius = 5, velocity = true},
            {prefab = "redgem", count = 3, radius = 5, velocity = true},
            {prefab = "silk", count = 5, radius = 5, velocity = true},
        },
    },
}

-- ONE generic executor for all simple events
local function ExecuteSpawnEvent(eventData, world, target)
    local player = target or GetRandomPlayer()
    if not player then return false end
    local x, y, z = player.Transform:GetWorldPosition()

    for _, spawn in ipairs(eventData.spawns) do
        for i = 1, spawn.count do
            if spawn.velocity then
                SpawnWithVelocity(spawn.prefab, x, z, 8)
            else
                SpawnNear(spawn.prefab, x, z, spawn.radius)
            end
        end
    end
    return true
end

-- Register all events from data
for id, data in pairs(EVENT_DATA) do
    mgr:RegisterEvent({
        id = id,
        name = data.name,
        category = EVENT_CATEGORY[data.category],
        rarity = EVENT_RARITY[data.rarity],
        GetAnnouncement = function() return data.announcement end,
        Execute = function(self, world, target)
            return ExecuteSpawnEvent(data, world, target)
        end,
    })
end
```

## Multi-Wave Events (Special Case)

For complex events like Arena Challenge, use a wave data structure:

```lua
local WAVE_EVENTS = {
    arena_challenge = {
        name = "ARENA CHALLENGE!",
        announcement = "Survive 3 waves!",
        category = "CHALLENGE",
        rarity = "RARE",
        waves = {
            {
                delay = 0,
                announcement = "WAVE 1: SPIDERS!",
                spawns = {{prefab = "spider", count = 8, radius = 10}},
                rewards = {{prefab = "spear", count = 1}, {prefab = "armorwood", count = 1}},
            },
            {
                delay = 45,
                announcement = "WAVE 2: HOUNDS!",
                spawns = {{prefab = "hound", count = 5, radius = 12}},
                rewards = {{prefab = "goldnugget", count = 5}},
            },
            {
                delay = 90,
                announcement = "FINAL WAVE: THE GUARDIAN!",
                spawns = {{prefab = "leif", count = 1, radius = 15}},
                rewards = {{prefab = "purplegem", count = 2}, {prefab = "thulecite", count = 1}},
            },
        },
    },
}

-- Generic wave executor
local function ExecuteWaveEvent(eventData, world, target)
    local player = target or GetRandomPlayer()
    if not player then return false end
    local x, y, z = player.Transform:GetWorldPosition()

    for _, wave in ipairs(eventData.waves) do
        world:DoTaskInTime(wave.delay, function()
            if wave.announcement then
                GLOBAL.TheNet:Announce(wave.announcement)
            end
            -- Spawn enemies
            for _, spawn in ipairs(wave.spawns or {}) do
                for i = 1, spawn.count do
                    SpawnNear(spawn.prefab, x, z, spawn.radius or 10)
                end
            end
            -- Drop rewards
            for _, reward in ipairs(wave.rewards or {}) do
                for i = 1, reward.count do
                    SpawnNear(reward.prefab, x, z, 3)
                end
            end
        end)
    end
    return true
end
```

## Benefits

| Aspect | Before (Code) | After (Data) |
|--------|---------------|--------------|
| Lines per event | ~30 | ~10 |
| Adding new event | Copy-paste + modify | Add data entry |
| Bug fixes | Fix in 21 places | Fix in 1 function |
| Readability | Walls of code | Clear data tables |

## Migration Plan

1. Create `EVENT_DATA` table with all simple events
2. Create `ExecuteSpawnEvent` generic function
3. Test one event works
4. Migrate remaining events one by one
5. Delete old code

## When NOT to Use Data-Driven

Some events need custom logic:
- Events with complex conditions
- Events that track state over time
- Events with unique mechanics

For these, keep as custom functions but minimize duplication.
