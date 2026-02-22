# Quest System Pattern

## Overview
This pattern implements multi-step objectives with state tracking, progress announcements, and completion rewards.

## Basic Quest Structure

```lua
local Quest = {
    id = "gather_resources",
    name = "Resource Gatherer",
    description = "Collect materials for the village",
    objectives = {},
    currentObjective = 1,
    isComplete = false,
    isActive = false,
}

function Quest:Start(player)
    self.isActive = true
    self.player = player

    -- Define objectives
    self.objectives = {
        {
            id = "gather_logs",
            description = "Gather 20 logs",
            type = "collect",
            target = "log",
            required = 20,
            current = 0,
        },
        {
            id = "gather_rocks",
            description = "Gather 20 rocks",
            type = "collect",
            target = "rocks",
            required = 20,
            current = 0,
        },
        {
            id = "gather_gold",
            description = "Gather 10 gold nuggets",
            type = "collect",
            target = "goldnugget",
            required = 10,
            current = 0,
        },
    }

    TheNet:Announce("QUEST STARTED: " .. self.name)
    self:AnnounceCurrentObjective()

    -- Start tracking
    self:SetupTracking()
end

function Quest:AnnounceCurrentObjective()
    local obj = self.objectives[self.currentObjective]
    if obj then
        TheNet:Announce("Objective: " .. obj.description .. " (" .. obj.current .. "/" .. obj.required .. ")")
    end
end

function Quest:SetupTracking()
    -- Track item pickups
    if self.player then
        self.player:ListenForEvent("itemget", function(player, data)
            self:OnItemPickup(data.item)
        end)
    end
end

function Quest:OnItemPickup(item)
    if not self.isActive or self.isComplete then return end

    local obj = self.objectives[self.currentObjective]
    if not obj then return end

    if obj.type == "collect" and item.prefab == obj.target then
        obj.current = obj.current + 1

        -- Progress announcement every 5 items
        if obj.current % 5 == 0 or obj.current == obj.required then
            TheNet:Announce(obj.description .. ": " .. obj.current .. "/" .. obj.required)
        end

        -- Check completion
        if obj.current >= obj.required then
            self:CompleteObjective()
        end
    end
end

function Quest:CompleteObjective()
    local obj = self.objectives[self.currentObjective]
    TheNet:Announce("OBJECTIVE COMPLETE: " .. obj.description)

    self.currentObjective = self.currentObjective + 1

    if self.currentObjective > #self.objectives then
        self:Complete()
    else
        self:AnnounceCurrentObjective()
    end
end

function Quest:Complete()
    self.isComplete = true
    self.isActive = false

    TheNet:Announce("QUEST COMPLETE: " .. self.name .. "!")

    -- Give rewards
    local x, y, z = self.player.Transform:GetWorldPosition()
    local rewards = {"redgem", "bluegem", "purplegem", "thulecite"}
    for _, item in ipairs(rewards) do
        SpawnNear(item, x, z, 5)
    end
end
```

## Kill Quest

```lua
local KillQuest = {
    targets = {},
    killCount = 0,
    requiredKills = 10,
    targetPrefab = "spider",
}

function KillQuest:Start(world, player)
    self.world = world
    self.player = player
    self.killCount = 0

    TheNet:Announce("HUNT QUEST: Kill " .. self.requiredKills .. " spiders!")

    -- Listen for kills globally
    world:ListenForEvent("entity_death", function(world, data)
        self:OnEntityDeath(data.inst)
    end)
end

function KillQuest:OnEntityDeath(entity)
    if entity.prefab == self.targetPrefab then
        self.killCount = self.killCount + 1

        -- Progress updates
        if self.killCount % 5 == 0 or self.killCount == self.requiredKills then
            TheNet:Announce("Spider kills: " .. self.killCount .. "/" .. self.requiredKills)
        end

        if self.killCount >= self.requiredKills then
            self:Complete()
        end
    end
end

function KillQuest:Complete()
    TheNet:Announce("HUNT COMPLETE! All spiders eliminated!")
    -- Rewards
end
```

## Location Quest

```lua
local LocationQuest = {
    checkpoints = {},
    currentCheckpoint = 1,
    checkRadius = 10,
}

function LocationQuest:Start(world, player)
    self.world = world
    self.player = player

    -- Define checkpoints (x, z coordinates)
    self.checkpoints = {
        {x = 100, z = 100, name = "Ancient Altar"},
        {x = -50, z = 200, name = "Mysterious Cave"},
        {x = 150, z = -100, name = "Sacred Grove"},
    }

    TheNet:Announce("EXPLORATION QUEST: Visit 3 sacred locations!")
    self:AnnounceNextLocation()

    -- Start checking position
    self.checkTask = world:DoPeriodicTask(1, function()
        self:CheckPlayerPosition()
    end)
end

function LocationQuest:AnnounceNextLocation()
    local checkpoint = self.checkpoints[self.currentCheckpoint]
    if checkpoint then
        TheNet:Announce("Find the " .. checkpoint.name .. "!")
    end
end

function LocationQuest:CheckPlayerPosition()
    if not self.player or not self.player:IsValid() then return end

    local px, py, pz = self.player.Transform:GetWorldPosition()
    local checkpoint = self.checkpoints[self.currentCheckpoint]

    if not checkpoint then return end

    local dist = math.sqrt((px - checkpoint.x)^2 + (pz - checkpoint.z)^2)

    if dist <= self.checkRadius then
        self:ReachCheckpoint()
    end
end

function LocationQuest:ReachCheckpoint()
    local checkpoint = self.checkpoints[self.currentCheckpoint]
    TheNet:Announce("FOUND: " .. checkpoint.name .. "!")

    -- Drop small reward at location
    SpawnNear("goldnugget", checkpoint.x, checkpoint.z, 3)

    self.currentCheckpoint = self.currentCheckpoint + 1

    if self.currentCheckpoint > #self.checkpoints then
        self:Complete()
    else
        self:AnnounceNextLocation()
    end
end

function LocationQuest:Complete()
    if self.checkTask then
        self.checkTask:Cancel()
    end

    TheNet:Announce("EXPLORATION COMPLETE! All locations discovered!")
    -- Final rewards
end
```

## Quest Chain

```lua
local QuestChain = {
    quests = {},
    currentQuest = 1,
}

function QuestChain:Setup()
    self.quests = {
        {
            name = "Chapter 1: The Beginning",
            objective = "Gather 10 logs",
            type = "collect",
            target = "log",
            required = 10,
            reward = {"goldnugget", "goldnugget"},
        },
        {
            name = "Chapter 2: The Hunt",
            objective = "Kill 5 spiders",
            type = "kill",
            target = "spider",
            required = 5,
            reward = {"spear", "armorwood"},
        },
        {
            name = "Chapter 3: The Boss",
            objective = "Defeat the Treeguard",
            type = "kill",
            target = "leif",
            required = 1,
            reward = {"livinglog", "livinglog", "purplegem"},
        },
    }
end

function QuestChain:Start(world, player)
    self:Setup()
    self.world = world
    self.player = player
    self.currentQuest = 1
    self.progress = 0

    TheNet:Announce("QUEST CHAIN BEGINS!")
    self:StartCurrentQuest()
end

function QuestChain:StartCurrentQuest()
    local quest = self.quests[self.currentQuest]
    if not quest then
        self:CompleteChain()
        return
    end

    self.progress = 0
    TheNet:Announce(quest.name)
    TheNet:Announce("Objective: " .. quest.objective)
end

function QuestChain:UpdateProgress(amount)
    local quest = self.quests[self.currentQuest]
    if not quest then return end

    self.progress = self.progress + amount

    if self.progress >= quest.required then
        self:CompleteQuest()
    end
end

function QuestChain:CompleteQuest()
    local quest = self.quests[self.currentQuest]

    TheNet:Announce("QUEST COMPLETE: " .. quest.name)

    -- Give rewards
    local x, y, z = self.player.Transform:GetWorldPosition()
    for _, item in ipairs(quest.reward) do
        SpawnNear(item, x, z, 5)
    end

    -- Next quest
    self.currentQuest = self.currentQuest + 1

    self.world:DoTaskInTime(5, function()
        self:StartCurrentQuest()
    end)
end

function QuestChain:CompleteChain()
    TheNet:Announce("QUEST CHAIN COMPLETE! You are victorious!")

    -- Epic final reward
    local x, y, z = self.player.Transform:GetWorldPosition()
    local epicRewards = {"yellowgem", "orangegem", "greengem", "thulecite", "armorruins"}
    for _, item in ipairs(epicRewards) do
        SpawnNear(item, x, z, 8)
    end
end
```

## Quest Manager

```lua
local QuestManager = {
    activeQuests = {},
    completedQuests = {},
}

function QuestManager:AddQuest(questId, questData)
    if self.activeQuests[questId] then
        return false  -- Already active
    end

    self.activeQuests[questId] = {
        data = questData,
        progress = 0,
        startTime = GetTime(),
    }

    return true
end

function QuestManager:UpdateProgress(questId, amount)
    local quest = self.activeQuests[questId]
    if not quest then return end

    quest.progress = quest.progress + amount

    if quest.progress >= quest.data.required then
        self:CompleteQuest(questId)
    end
end

function QuestManager:CompleteQuest(questId)
    local quest = self.activeQuests[questId]
    if not quest then return end

    -- Move to completed
    self.completedQuests[questId] = {
        data = quest.data,
        completedTime = GetTime(),
        duration = GetTime() - quest.startTime,
    }

    self.activeQuests[questId] = nil

    -- Trigger completion callback
    if quest.data.onComplete then
        quest.data.onComplete()
    end
end

function QuestManager:GetActiveQuests()
    local list = {}
    for id, quest in pairs(self.activeQuests) do
        table.insert(list, {
            id = id,
            name = quest.data.name,
            progress = quest.progress,
            required = quest.data.required,
        })
    end
    return list
end

function QuestManager:GetProgress(questId)
    local quest = self.activeQuests[questId]
    if quest then
        return quest.progress, quest.data.required
    end
    return 0, 0
end
```

## Timed Quest

```lua
local TimedQuest = {
    timeLimit = 300,  -- 5 minutes
    startTime = 0,
}

function TimedQuest:Start(world, player)
    self.world = world
    self.player = player
    self.startTime = GetTime()
    self.progress = 0
    self.required = 20

    TheNet:Announce("TIMED CHALLENGE: Collect 20 gold in 5 minutes!")

    -- Timer warnings
    world:DoTaskInTime(180, function()
        if not self.isComplete then
            TheNet:Announce("2 MINUTES REMAINING!")
        end
    end)

    world:DoTaskInTime(240, function()
        if not self.isComplete then
            TheNet:Announce("1 MINUTE LEFT!")
        end
    end)

    -- Time's up
    world:DoTaskInTime(self.timeLimit, function()
        if not self.isComplete then
            self:OnTimeout()
        end
    end)
end

function TimedQuest:UpdateProgress()
    self.progress = self.progress + 1

    if self.progress >= self.required then
        self:Complete()
    end
end

function TimedQuest:Complete()
    self.isComplete = true
    local duration = GetTime() - self.startTime

    TheNet:Announce("TIMED QUEST COMPLETE! Time: " .. math.floor(duration) .. " seconds!")

    -- Bonus for fast completion
    if duration < 120 then
        TheNet:Announce("SPEED BONUS!")
        -- Extra rewards
    end
end

function TimedQuest:OnTimeout()
    TheNet:Announce("TIME'S UP! Quest failed...")
    -- No rewards or consolation prize
end
```

## Key Concepts

### Event Tracking
```lua
-- Track item pickups
player:ListenForEvent("itemget", function(player, data)
    if data.item.prefab == "goldnugget" then
        quest.progress = quest.progress + 1
    end
end)

-- Track kills
world:ListenForEvent("entity_death", function(world, data)
    if data.inst.prefab == "spider" then
        quest.kills = quest.kills + 1
    end
end)
```

### Progress Persistence (Basic)
```lua
-- Save quest state
local function SaveQuestState(questId, progress)
    -- In a real mod, use SaveData/LoadData
    _G.QuestState = _G.QuestState or {}
    _G.QuestState[questId] = progress
end

-- Load quest state
local function LoadQuestState(questId)
    _G.QuestState = _G.QuestState or {}
    return _G.QuestState[questId] or 0
end
```

### Multiplayer Quest Scaling
```lua
local function GetScaledRequirement(base)
    local playerCount = #AllPlayers
    return math.ceil(base * (1 + (playerCount - 1) * 0.5))
end

-- 1 player: 20 items
-- 2 players: 30 items
-- 3 players: 40 items
quest.required = GetScaledRequirement(20)
```

## See Also

- [multi-wave-event.md](multi-wave-event.md) - Wave-based challenges
- [boss-fight.md](boss-fight.md) - Boss objectives
- [events.md](../dst-api/events.md) - Event tracking
