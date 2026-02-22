# Boss Fight Pattern

## Overview
This pattern creates epic boss encounters with preparation phases, staged combat, health tracking, and reward systems.

## Basic Boss Encounter

```lua
local BossFight = {
    isActive = false,
    boss = nil,
    prepTime = 60,  -- 60 seconds to prepare
}

function BossFight:Start(world, player)
    self.isActive = true
    self.world = world
    self.player = player
    self.x, self.y, self.z = player.Transform:GetWorldPosition()

    -- PHASE 1: Preparation
    self:StartPrepPhase()
end

function BossFight:StartPrepPhase()
    TheNet:Announce("BOSS INCOMING! 60 seconds to prepare!")

    -- Drop preparation supplies
    local gear = {"spear", "spear", "armorwood", "footballhat", "healingsalve", "healingsalve"}
    for _, item in ipairs(gear) do
        SpawnNear(item, self.x, self.z, 5)
    end

    -- Countdown announcements
    self.world:DoTaskInTime(30, function()
        TheNet:Announce("30 SECONDS REMAINING!")
    end)

    self.world:DoTaskInTime(50, function()
        TheNet:Announce("10 SECONDS!")
    end)

    -- Start fight phase
    self.world:DoTaskInTime(self.prepTime, function()
        self:StartFightPhase()
    end)
end

function BossFight:StartFightPhase()
    TheNet:Announce("THE BOSS HAS ARRIVED!")

    -- Spawn the boss
    self.boss = SpawnPrefab("deerclops")
    if self.boss then
        self.boss.Transform:SetPosition(self.x + 15, 0, self.z + 15)

        -- Track boss death
        self.boss:ListenForEvent("death", function()
            self:OnBossDefeated()
        end)

        -- Track boss removal (if despawned)
        self.boss:ListenForEvent("onremove", function()
            if self.isActive then
                self:OnBossFailed()
            end
        end)
    end
end

function BossFight:OnBossDefeated()
    self.isActive = false
    TheNet:Announce("VICTORY! The boss has been slain!")

    -- Drop epic rewards
    local rewards = {
        "purplegem", "purplegem", "purplegem",
        "yellowgem", "orangegem", "greengem",
        "thulecite", "thulecite", "thulecite",
        "armorruins",
    }

    for _, item in ipairs(rewards) do
        SpawnNear(item, self.x, self.z, 8)
    end
end

function BossFight:OnBossFailed()
    self.isActive = false
    TheNet:Announce("The boss has escaped...")
end
```

## Multi-Phase Boss

```lua
local MultiBoss = {
    currentPhase = 0,
    maxPhases = 3,
    boss = nil,
    isActive = false,
}

function MultiBoss:Start(world, player)
    self.isActive = true
    self.world = world
    self.x, self.y, self.z = player.Transform:GetWorldPosition()
    self.currentPhase = 0

    TheNet:Announce("EPIC BOSS BATTLE BEGINS!")
    self:NextPhase()
end

function MultiBoss:NextPhase()
    self.currentPhase = self.currentPhase + 1

    if self.currentPhase > self.maxPhases then
        self:OnVictory()
        return
    end

    -- Phase configuration
    local phases = {
        [1] = {
            boss = "leif",
            announce = "PHASE 1: The Forest Guardian!",
            healthMod = 0.5,  -- Half health
            reward = {"goldnugget", "goldnugget", "livinglog"},
        },
        [2] = {
            boss = "spiderqueen",
            announce = "PHASE 2: The Spider Queen!",
            healthMod = 0.75,
            reward = {"silk", "silk", "silk", "spidergland", "purplegem"},
        },
        [3] = {
            boss = "deerclops",
            announce = "FINAL PHASE: DEERCLOPS!",
            healthMod = 1.0,  -- Full health
            reward = {"deerclops_eyeball", "thulecite", "armorruins"},
        },
    }

    local phase = phases[self.currentPhase]
    TheNet:Announce(phase.announce)

    -- Drop phase reward from previous
    if self.currentPhase > 1 then
        local prevReward = phases[self.currentPhase - 1].reward
        for _, item in ipairs(prevReward) do
            SpawnNear(item, self.x, self.z, 5)
        end
    end

    -- Spawn boss with modified health
    self.boss = SpawnPrefab(phase.boss)
    if self.boss then
        self.boss.Transform:SetPosition(self.x + 10, 0, self.z + 10)

        -- Modify health
        if self.boss.components.health and phase.healthMod ~= 1.0 then
            local maxHealth = self.boss.components.health.maxhealth
            self.boss.components.health:SetMaxHealth(maxHealth * phase.healthMod)
        end

        -- Track death
        self.boss:ListenForEvent("death", function()
            self:OnPhaseComplete()
        end)
    end
end

function MultiBoss:OnPhaseComplete()
    TheNet:Announce("PHASE " .. self.currentPhase .. " COMPLETE!")

    -- Short break before next phase
    self.world:DoTaskInTime(5, function()
        self:NextPhase()
    end)
end

function MultiBoss:OnVictory()
    self.isActive = false
    TheNet:Announce("LEGENDARY VICTORY! ALL PHASES CLEARED!")

    -- Epic final reward
    local epicLoot = {
        "yellowgem", "orangegem", "greengem",
        "thulecite", "thulecite", "thulecite", "thulecite", "thulecite",
        "armorruins", "ruinshat", "ruins_bat",
        "amulet", "orangestaff",
    }

    for i, item in ipairs(epicLoot) do
        self.world:DoTaskInTime(i * 0.1, function()
            local loot = SpawnPrefab(item)
            if loot then
                local angle = math.random() * 2 * math.pi
                loot.Transform:SetPosition(self.x + math.cos(angle) * 3, 3, self.z + math.sin(angle) * 3)
                if loot.Physics then
                    loot.Physics:SetVel(math.cos(angle) * 3, 8, math.sin(angle) * 3)
                end
            end
        end)
    end
end
```

## Health-Based Phase Transitions

```lua
local HealthPhaseBoss = {
    boss = nil,
    phase = 1,
}

function HealthPhaseBoss:Start(world, player)
    self.world = world
    local x, y, z = player.Transform:GetWorldPosition()

    TheNet:Announce("THE ANCIENT ONE AWAKENS!")

    self.boss = SpawnPrefab("deerclops")
    if not self.boss then return end

    self.boss.Transform:SetPosition(x + 15, 0, z + 15)

    -- Track health changes
    self.boss:ListenForEvent("healthdelta", function(inst, data)
        self:OnHealthChange(inst)
    end)

    self.boss:ListenForEvent("death", function()
        self:OnDefeated()
    end)
end

function HealthPhaseBoss:OnHealthChange(boss)
    local healthPercent = boss.components.health:GetPercent()

    -- Phase 2 at 66% health
    if healthPercent <= 0.66 and self.phase == 1 then
        self.phase = 2
        self:TriggerPhase2()
    end

    -- Phase 3 at 33% health
    if healthPercent <= 0.33 and self.phase == 2 then
        self.phase = 3
        self:TriggerPhase3()
    end
end

function HealthPhaseBoss:TriggerPhase2()
    TheNet:Announce("THE BOSS GROWS STRONGER!")

    -- Enrage: increase damage
    if self.boss.components.combat then
        local baseDamage = self.boss.components.combat.defaultdamage or 50
        self.boss.components.combat:SetDefaultDamage(baseDamage * 1.5)
    end

    -- Spawn adds
    local x, y, z = self.boss.Transform:GetWorldPosition()
    for i = 1, 4 do
        SpawnNear("spider_warrior", x, z, 8)
    end
end

function HealthPhaseBoss:TriggerPhase3()
    TheNet:Announce("FINAL PHASE! THE BOSS IS DESPERATE!")

    -- Desperate: even more damage, spawn more adds
    if self.boss.components.combat then
        local baseDamage = self.boss.components.combat.defaultdamage or 50
        self.boss.components.combat:SetDefaultDamage(baseDamage * 2)
    end

    local x, y, z = self.boss.Transform:GetWorldPosition()
    for i = 1, 6 do
        SpawnNear("hound", x, z, 10)
    end
end

function HealthPhaseBoss:OnDefeated()
    TheNet:Announce("THE ANCIENT ONE HAS FALLEN!")
    -- Rewards here
end
```

## Boss Timer / Enrage

```lua
local TimedBoss = {
    boss = nil,
    timeLimit = 180,  -- 3 minutes
    timerTask = nil,
    isEnraged = false,
}

function TimedBoss:Start(world, player)
    self.world = world
    local x, y, z = player.Transform:GetWorldPosition()

    TheNet:Announce("DEFEAT THE BOSS IN 3 MINUTES!")

    self.boss = SpawnPrefab("bearger")
    self.boss.Transform:SetPosition(x + 15, 0, z + 15)

    self.boss:ListenForEvent("death", function()
        self:OnDefeated()
    end)

    -- Timer warnings
    world:DoTaskInTime(60, function()
        if self.boss and self.boss:IsValid() then
            TheNet:Announce("2 MINUTES REMAINING!")
        end
    end)

    world:DoTaskInTime(120, function()
        if self.boss and self.boss:IsValid() then
            TheNet:Announce("1 MINUTE! BOSS ENRAGING!")
            self:Enrage()
        end
    end)

    -- Time's up
    self.timerTask = world:DoTaskInTime(self.timeLimit, function()
        if self.boss and self.boss:IsValid() then
            self:OnTimeout()
        end
    end)
end

function TimedBoss:Enrage()
    if self.isEnraged then return end
    self.isEnraged = true

    -- Make boss red and angry
    self.boss.AnimState:SetMultColour(1, 0.5, 0.5, 1)

    -- Double damage and speed
    if self.boss.components.combat then
        self.boss.components.combat:SetDefaultDamage(100)
    end
    if self.boss.components.locomotor then
        self.boss.components.locomotor:SetExternalSpeedMultiplier(self.boss, "enrage", 1.5)
    end
end

function TimedBoss:OnDefeated()
    TheNet:Announce("BOSS DEFEATED IN TIME! BONUS REWARDS!")

    -- Cancel timer
    if self.timerTask then
        self.timerTask:Cancel()
    end

    -- Extra rewards for beating timer
    local x, y, z = self.boss.Transform:GetWorldPosition()
    for i = 1, 10 do
        SpawnNear("goldnugget", x, z, 5)
    end
end

function TimedBoss:OnTimeout()
    TheNet:Announce("TIME'S UP! The boss escapes with your loot...")

    if self.boss and self.boss:IsValid() then
        -- Boss despawns, taking potential loot
        self.boss:Remove()
    end
end
```

## Spawn Boss Helper

```lua
local function SpawnBossWithSetup(prefab, x, z, onDeath, healthMod)
    local boss = SpawnPrefab(prefab)
    if not boss then
        print("ERROR: Failed to spawn boss: " .. prefab)
        return nil
    end

    -- Position
    boss.Transform:SetPosition(x, 0, z)

    -- Modify health
    if healthMod and boss.components.health then
        local maxHealth = boss.components.health.maxhealth
        boss.components.health:SetMaxHealth(maxHealth * healthMod)
        boss.components.health:SetPercent(1)  -- Full health
    end

    -- Death callback
    if onDeath then
        boss:ListenForEvent("death", function()
            onDeath(boss)
        end)
    end

    return boss
end

-- Usage
local boss = SpawnBossWithSetup("deerclops", 100, 200, function(boss)
    TheNet:Announce("Boss defeated!")
end, 0.5)  -- Half health
```

## Key Concepts

### Tracking Boss Health
```lua
boss:ListenForEvent("healthdelta", function(inst, data)
    local pct = inst.components.health:GetPercent()
    print("Boss health: " .. math.floor(pct * 100) .. "%")
end)
```

### Boss Adds (Minions)
```lua
local function SpawnAdds(bossX, bossZ, prefab, count)
    for i = 1, count do
        local add = SpawnPrefab(prefab)
        if add then
            local angle = (i / count) * 2 * math.pi
            add.Transform:SetPosition(
                bossX + math.cos(angle) * 8,
                0,
                bossZ + math.sin(angle) * 8
            )
        end
    end
end
```

### Reward Scaling
```lua
local function GetBossRewards(difficulty, playerCount)
    local baseRewards = {
        easy = {"goldnugget", "redgem"},
        medium = {"purplegem", "thulecite"},
        hard = {"yellowgem", "armorruins"},
    }

    local rewards = baseRewards[difficulty] or baseRewards.easy

    -- Scale with player count
    local scaled = {}
    for _, item in ipairs(rewards) do
        for i = 1, playerCount do
            table.insert(scaled, item)
        end
    end

    return scaled
end
```

## See Also

- [multi-wave-event.md](multi-wave-event.md) - Wave-based combat
- [loot-tables.md](loot-tables.md) - Reward systems
- [components.md](../dst-api/components.md) - Health/Combat components
