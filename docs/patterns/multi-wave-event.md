# Multi-Wave Event Pattern

## Overview
This pattern creates timed, multi-wave combat encounters with announcements, rewards between waves, and victory conditions.

## Basic Pattern

```lua
local function StartArenaChallenge(world, player)
    local x, y, z = player.Transform:GetWorldPosition()

    -- Drop initial gear
    SpawnNear("spear", x, z, 3)
    SpawnNear("armorwood", x, z, 3)

    -- WAVE 1 (immediate)
    TheNet:Announce("WAVE 1: SPIDERS!")
    for i = 1, 8 do
        SpawnNear("spider", x, z, 10)
    end

    -- WAVE 2 (after 45 seconds)
    world:DoTaskInTime(45, function()
        TheNet:Announce("WAVE 2: HOUNDS!")
        -- Wave 1 reward
        SpawnNear("goldnugget", x, z, 3)
        SpawnNear("goldnugget", x, z, 3)
        -- Spawn wave 2 enemies
        for i = 1, 5 do
            SpawnNear("hound", x, z, 12)
        end
    end)

    -- WAVE 3 (after 90 seconds)
    world:DoTaskInTime(90, function()
        TheNet:Announce("FINAL WAVE: THE GUARDIAN!")
        -- Wave 2 reward
        SpawnNear("redgem", x, z, 3)
        SpawnNear("bluegem", x, z, 3)
        -- Spawn boss
        SpawnNear("leif", x, z, 15)
    end)

    -- Victory rewards (after 150 seconds)
    world:DoTaskInTime(150, function()
        TheNet:Announce("VICTORY! Claim your rewards!")
        for i = 1, 5 do
            SpawnNear("purplegem", x, z, 5)
        end
    end)
end
```

## Advanced: Track Enemy Deaths

```lua
local ArenaChallenge = {
    spawnedEnemies = {},
    currentWave = 0,
    isActive = false,
}

function ArenaChallenge:Start(world, player)
    self.spawnedEnemies = {}
    self.currentWave = 0
    self.isActive = true
    self.world = world
    self.player = player
    self.x, self.y, self.z = player.Transform:GetWorldPosition()

    self:StartWave(1)
end

function ArenaChallenge:SpawnEnemy(prefab)
    local enemy = SpawnPrefab(prefab)
    if enemy then
        local angle = math.random() * 2 * math.pi
        local dist = 10 + math.random() * 5
        enemy.Transform:SetPosition(
            self.x + math.cos(angle) * dist,
            0,
            self.z + math.sin(angle) * dist
        )

        table.insert(self.spawnedEnemies, enemy)

        -- Listen for death
        enemy:ListenForEvent("death", function(inst)
            self:OnEnemyDeath(inst)
        end)

        -- Listen for removal (if player runs away)
        enemy:ListenForEvent("onremove", function(inst)
            self:OnEnemyDeath(inst)
        end)
    end
    return enemy
end

function ArenaChallenge:OnEnemyDeath(enemy)
    -- Remove from tracking
    for i, e in ipairs(self.spawnedEnemies) do
        if e == enemy then
            table.remove(self.spawnedEnemies, i)
            break
        end
    end

    -- Check if wave complete
    if #self.spawnedEnemies == 0 and self.isActive then
        self:OnWaveComplete()
    end
end

function ArenaChallenge:OnWaveComplete()
    TheNet:Announce("Wave " .. self.currentWave .. " complete!")

    -- Drop wave rewards
    self:DropWaveReward()

    -- Start next wave or victory
    if self.currentWave < 3 then
        self.world:DoTaskInTime(5, function()
            self:StartWave(self.currentWave + 1)
        end)
    else
        self:OnVictory()
    end
end

function ArenaChallenge:StartWave(waveNum)
    self.currentWave = waveNum

    local waves = {
        [1] = {prefab = "spider", count = 8, announce = "WAVE 1: SPIDERS!"},
        [2] = {prefab = "hound", count = 5, announce = "WAVE 2: HOUNDS!"},
        [3] = {prefab = "leif", count = 1, announce = "FINAL WAVE: TREEGUARD!"},
    }

    local wave = waves[waveNum]
    if not wave then return end

    TheNet:Announce(wave.announce)

    for i = 1, wave.count do
        self:SpawnEnemy(wave.prefab)
    end
end

function ArenaChallenge:DropWaveReward()
    local rewards = {
        [1] = {"goldnugget", "goldnugget", "spear"},
        [2] = {"redgem", "bluegem", "armorwood"},
        [3] = {"purplegem", "purplegem", "thulecite"},
    }

    local loot = rewards[self.currentWave] or {}
    for _, item in ipairs(loot) do
        SpawnNear(item, self.x, self.z, 3)
    end
end

function ArenaChallenge:OnVictory()
    self.isActive = false
    TheNet:Announce("ARENA COMPLETE! LEGENDARY REWARDS!")

    -- Epic loot explosion
    local epicLoot = {
        "purplegem", "purplegem", "purplegem",
        "yellowgem", "orangegem", "greengem",
        "thulecite", "thulecite", "thulecite",
        "armorruins", "ruinshat",
    }

    for _, item in ipairs(epicLoot) do
        SpawnNear(item, self.x, self.z, 5)
    end
end

function ArenaChallenge:Cancel()
    self.isActive = false
    -- Remove all spawned enemies
    for _, enemy in ipairs(self.spawnedEnemies) do
        if enemy and enemy:IsValid() then
            enemy:Remove()
        end
    end
    self.spawnedEnemies = {}
end
```

## Configuration Table Pattern

```lua
local WAVE_CONFIG = {
    {
        delay = 0,
        announce = "WAVE 1: SPIDERS!",
        enemies = {
            {prefab = "spider", count = 8},
        },
        rewards = {"goldnugget", "goldnugget"},
    },
    {
        delay = 45,
        announce = "WAVE 2: HOUNDS!",
        enemies = {
            {prefab = "hound", count = 3},
            {prefab = "firehound", count = 2},
        },
        rewards = {"redgem", "bluegem", "spear"},
    },
    {
        delay = 90,
        announce = "FINAL WAVE!",
        enemies = {
            {prefab = "leif", count = 1},
            {prefab = "spider_warrior", count = 4},
        },
        rewards = {"purplegem", "thulecite", "armorruins"},
    },
}

local function RunConfiguredWaves(world, player, config)
    local x, y, z = player.Transform:GetWorldPosition()

    for waveNum, wave in ipairs(config) do
        world:DoTaskInTime(wave.delay, function()
            -- Announce
            TheNet:Announce(wave.announce)

            -- Spawn enemies
            for _, enemyGroup in ipairs(wave.enemies) do
                for i = 1, enemyGroup.count do
                    SpawnNear(enemyGroup.prefab, x, z, 12)
                end
            end

            -- Drop rewards (from previous wave)
            if waveNum > 1 then
                local prevRewards = config[waveNum - 1].rewards
                for _, item in ipairs(prevRewards) do
                    SpawnNear(item, x, z, 3)
                end
            end
        end)
    end

    -- Final rewards
    local totalDelay = config[#config].delay + 60
    world:DoTaskInTime(totalDelay, function()
        TheNet:Announce("VICTORY!")
        for _, item in ipairs(config[#config].rewards) do
            SpawnNear(item, x, z, 3)
        end
    end)
end
```

## Key Concepts

### DoTaskInTime
```lua
-- Run function after X seconds
world:DoTaskInTime(seconds, function()
    -- Code here runs after delay
end)
```

### Tracking Spawned Entities
```lua
local spawned = {}

-- On spawn
table.insert(spawned, entity)

-- On death
entity:ListenForEvent("death", function(inst)
    for i, e in ipairs(spawned) do
        if e == inst then
            table.remove(spawned, i)
            break
        end
    end
end)

-- Check if all dead
if #spawned == 0 then
    OnAllDead()
end
```

### Scaling for Players
```lua
local function GetScaledCount(base)
    local players = #AllPlayers
    return math.ceil(base * (1 + (players - 1) * 0.3))
end

-- 1 player: 8 spiders
-- 2 players: 11 spiders
-- 3 players: 14 spiders
for i = 1, GetScaledCount(8) do
    SpawnEnemy("spider")
end
```

## Common Issues

1. **Player moves away**: Enemies spawn at original position
   - Solution: Store position or track player movement

2. **Entities removed before death event**
   - Listen for both "death" and "onremove"

3. **Too many DoTaskInTime calls**
   - Use a single periodic task that checks state

4. **Rewards spawn during fight**
   - Only drop rewards when wave is complete

## See Also

- [entities.md](../dst-api/entities.md) - Spawning entities
- [events.md](../dst-api/events.md) - Death events
- [prefab-list.md](../dst-api/prefab-list.md) - Enemy prefabs
