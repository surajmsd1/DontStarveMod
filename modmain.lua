-- Mystery Box Mod - Main Entry Point
-- DnD Gamemaster style mod that triggers daily/weekly events with rewards and dangers

-- Safer logging function with verbose mode
local VERBOSE = true
local function Log(msg)
    print("[Mystery Box] " .. tostring(msg))
end

local function LogVerbose(msg)
    if VERBOSE then
        print("[Mystery Box DEBUG] " .. tostring(msg))
    end
end

Log("Mod loading...")

-- Register all prefabs
PrefabFiles = {
    "mysterybox",
    "cursedbox",
    "goldenbox",
    "lookouttower",
}

-- Display names for prefabs
GLOBAL.STRINGS.NAMES.MYSTERYBOX = "Mystery Box"
GLOBAL.STRINGS.NAMES.CURSEDBOX = "Cursed Box"
GLOBAL.STRINGS.NAMES.GOLDENBOX = "Golden Box"
GLOBAL.STRINGS.NAMES.LOOKOUTTOWER = "Lookout Tower"

-- Inspection descriptions
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.MYSTERYBOX = "I wonder what's inside..."
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.CURSEDBOX = "It radiates dark energy..."
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.GOLDENBOX = "It shimmers with good fortune!"

-- Global reference to event manager (set when world initializes)
local EventManager = nil

-- Track the last phase to detect day transitions
local lastPhase = nil

-- Event categories and rarity (inline to avoid require issues)
local EVENT_CATEGORY = {
    REWARD = "reward",
    CHALLENGE = "challenge",
    DANGER = "danger",
    BOSS = "boss",
    SOCIAL = "social",
}

local EVENT_RARITY = {
    COMMON = {name = "Common", weight = 60},
    UNCOMMON = {name = "Uncommon", weight = 25},
    RARE = {name = "Rare", weight = 10},
    LEGENDARY = {name = "Legendary", weight = 5},
}

local EVENT_TRIGGER = {
    DAILY = "daily",
    WEEKLY = "weekly",
    MANUAL = "manual",
    SEASONAL = "seasonal",
}

-- Simple Event Manager class (inline to avoid require issues)
local function CreateEventManager(world)
    local mgr = {
        world = world,
        events = {},
        eventsByTrigger = {},
        eventsByCategory = {},
        lastDayProcessed = 0,
        lastWeekProcessed = 0,
        currentStreak = 0,
        lastActivationDay = -1,
    }

    -- Initialize groups
    for _, trigger in pairs(EVENT_TRIGGER) do
        mgr.eventsByTrigger[trigger] = {}
    end
    for _, category in pairs(EVENT_CATEGORY) do
        mgr.eventsByCategory[category] = {}
    end

    function mgr:RegisterEvent(event)
        if not event.id then return false end
        self.events[event.id] = event
        if event.trigger and self.eventsByTrigger[event.trigger] then
            table.insert(self.eventsByTrigger[event.trigger], event)
        end
        if event.category and self.eventsByCategory[event.category] then
            table.insert(self.eventsByCategory[event.category], event)
        end
        LogVerbose("Registered event: " .. event.id .. " (category: " .. tostring(event.category) .. ", trigger: " .. tostring(event.trigger) .. ")")
        return true
    end

    function mgr:GetCurrentDay()
        if self.world and self.world.state then
            return self.world.state.cycles or 0
        end
        return 0
    end

    function mgr:GetCurrentWeek()
        return math.floor(self:GetCurrentDay() / 7)
    end

    function mgr:SelectWeightedEvent(eventList)
        if not eventList or #eventList == 0 then
            LogVerbose("SelectWeightedEvent: eventList is nil or empty")
            return nil
        end
        LogVerbose("SelectWeightedEvent: choosing from " .. #eventList .. " events")
        local totalWeight = 0
        for _, event in ipairs(eventList) do
            local rarity = event.rarity or EVENT_RARITY.COMMON
            totalWeight = totalWeight + rarity.weight
        end
        local roll = math.random() * totalWeight
        local cumulative = 0
        for _, event in ipairs(eventList) do
            local rarity = event.rarity or EVENT_RARITY.COMMON
            cumulative = cumulative + rarity.weight
            if roll <= cumulative then
                LogVerbose("Selected event: " .. event.id)
                return event
            end
        end
        return eventList[1]
    end

    function mgr:AnnounceToAll(message)
        Log(">>> ANNOUNCEMENT: " .. message)
        if GLOBAL.TheNet and GLOBAL.TheNet.Announce then
            LogVerbose("TheNet:Announce called")
            GLOBAL.TheNet:Announce(message)
        else
            LogVerbose("WARNING: TheNet or TheNet.Announce is nil!")
        end
    end

    function mgr:ExecuteEvent(event, target)
        if not event then
            Log("ERROR: ExecuteEvent called with nil event")
            return false
        end
        Log("=== EXECUTING EVENT: " .. event.name .. " ===")
        LogVerbose("Event ID: " .. event.id)
        LogVerbose("Event Category: " .. tostring(event.category))
        LogVerbose("Target: " .. tostring(target))

        local ok, err = GLOBAL.pcall(function()
            local announcement = event.GetAnnouncement and event:GetAnnouncement()
            if announcement and announcement ~= "" then
                self:AnnounceToAll(announcement)
            else
                LogVerbose("No announcement for this event")
            end
            if event.Execute then
                LogVerbose("Calling event.Execute...")
                event:Execute(self.world, target)
                LogVerbose("event.Execute completed")
            else
                LogVerbose("WARNING: Event has no Execute function!")
            end
        end)

        if not ok then
            Log("ERROR executing event: " .. tostring(err))
        else
            Log("=== EVENT COMPLETE: " .. event.name .. " ===")
        end
        return ok
    end

    function mgr:TriggerRandomEvent(triggerType, target)
        LogVerbose("TriggerRandomEvent called with trigger: " .. tostring(triggerType))
        local eventList = self.eventsByTrigger[triggerType]
        if not eventList or #eventList == 0 then
            Log("No events for trigger: " .. triggerType)
            return false
        end
        local event = self:SelectWeightedEvent(eventList)
        if event then
            return self:ExecuteEvent(event, target)
        end
        return false
    end

    function mgr:OnDayStart()
        local currentDay = self:GetCurrentDay()
        Log("OnDayStart called - currentDay: " .. currentDay .. ", lastDayProcessed: " .. self.lastDayProcessed)
        -- Use < instead of <= so day 0 triggers (cycles start at 0)
        if currentDay < self.lastDayProcessed then return end
        if currentDay == self.lastDayProcessed and self.lastDayProcessed > 0 then return end
        self.lastDayProcessed = currentDay + 1  -- Mark this day as processed
        Log("Day " .. currentDay .. " has begun! Triggering daily event...")
        self:TriggerRandomEvent(EVENT_TRIGGER.DAILY, nil)

        local currentWeek = self:GetCurrentWeek()
        if currentWeek > self.lastWeekProcessed then
            self.lastWeekProcessed = currentWeek
            Log("Week " .. currentWeek .. " milestone!")
            self:TriggerRandomEvent(EVENT_TRIGGER.WEEKLY, nil)
        end
    end

    function mgr:OnSeasonChange(season)
        Log("Season changed to: " .. season)
        self:TriggerRandomEvent(EVENT_TRIGGER.SEASONAL, nil)
    end

    function mgr:TriggerBoxEvent(boxType, target)
        Log("=== BOX EVENT TRIGGERED ===")
        Log("Box Type: " .. tostring(boxType))
        Log("Target Player: " .. tostring(target))

        local eventList = nil
        if boxType == "cursed" then
            eventList = {}
            local challengeEvents = self.eventsByCategory[EVENT_CATEGORY.CHALLENGE] or {}
            local bossEvents = self.eventsByCategory[EVENT_CATEGORY.BOSS] or {}
            LogVerbose("Cursed box: " .. #challengeEvents .. " challenge events, " .. #bossEvents .. " boss events")
            for _, e in ipairs(challengeEvents) do
                table.insert(eventList, e)
            end
            for _, e in ipairs(bossEvents) do
                table.insert(eventList, e)
            end
        elseif boxType == "golden" then
            eventList = {}
            local rewardEvents = self.eventsByCategory[EVENT_CATEGORY.REWARD] or {}
            local socialEvents = self.eventsByCategory[EVENT_CATEGORY.SOCIAL] or {}
            LogVerbose("Golden box: " .. #rewardEvents .. " reward events, " .. #socialEvents .. " social events")
            for _, e in ipairs(rewardEvents) do
                table.insert(eventList, e)
            end
            for _, e in ipairs(socialEvents) do
                table.insert(eventList, e)
            end
        else
            eventList = self.eventsByTrigger[EVENT_TRIGGER.MANUAL]
            LogVerbose("Normal box: using MANUAL trigger events")
        end

        if not eventList or #eventList == 0 then
            Log("ERROR: No events for box type: " .. tostring(boxType))
            Log("Check that events are registered with correct categories!")
            return false
        end

        Log("Found " .. #eventList .. " possible events for " .. tostring(boxType) .. " box")
        local event = self:SelectWeightedEvent(eventList)
        if event then
            return self:ExecuteEvent(event, target)
        end
        return false
    end

    function mgr:GetEventCount()
        local count = 0
        for _ in pairs(self.events) do count = count + 1 end
        return count
    end

    function mgr:GetCategoryEventCount(category)
        local list = self.eventsByCategory[category]
        return list and #list or 0
    end

    return mgr
end

-- Helper functions for events
local function GetRandomPlayer()
    local players = GLOBAL.AllPlayers or {}
    Log("GetRandomPlayer: AllPlayers has " .. #players .. " players")
    if #players == 0 then
        Log("ERROR: No players found in AllPlayers!")
        return nil
    end
    local player = players[math.random(#players)]
    Log("GetRandomPlayer: Selected " .. tostring(player))
    return player
end

local function SpawnNear(prefab, x, z, radius)
    Log("SpawnNear: " .. tostring(prefab) .. " at (" .. tostring(x) .. ", " .. tostring(z) .. ") radius " .. tostring(radius))
    local entity = GLOBAL.SpawnPrefab(prefab)
    Log("SpawnPrefab returned: " .. tostring(entity))
    if entity then
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * radius
        local spawnX = x + math.cos(angle) * dist
        local spawnZ = z + math.sin(angle) * dist
        entity.Transform:SetPosition(spawnX, 0, spawnZ)
        LogVerbose("SUCCESS: Spawned " .. prefab .. " at (" .. spawnX .. ", " .. spawnZ .. ")")
    else
        Log("ERROR: Failed to spawn " .. prefab .. " - SpawnPrefab returned nil!")
    end
    return entity
end

-- Spawn with physics velocity (for "item rain" effect)
local function SpawnWithVelocity(prefab, x, z, velY)
    LogVerbose("SpawnWithVelocity: " .. prefab)
    local entity = GLOBAL.SpawnPrefab(prefab)
    if entity then
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * 3
        entity.Transform:SetPosition(x + math.cos(angle) * dist, 3, z + math.sin(angle) * dist)
        if entity.Physics then
            entity.Physics:SetVel(math.cos(angle) * 2, velY or 5, math.sin(angle) * 2)
        end
        LogVerbose("SUCCESS: Spawned " .. prefab .. " with velocity")
    else
        Log("ERROR: Failed to spawn " .. prefab)
    end
    return entity
end

-- =============================================================================
-- =============================================================================
-- EVENT DATA (loaded from external file)
-- =============================================================================

local EventData = require "events/event_data"
local SIMPLE_EVENTS = EventData.SIMPLE_EVENTS
local TIMED_EVENTS = EventData.TIMED_EVENTS
local WAVE_EVENTS = EventData.WAVE_EVENTS
local SPECIAL_EVENTS = EventData.SPECIAL_EVENTS

-- =============================================================================
-- GENERIC EVENT EXECUTORS
-- =============================================================================

-- Execute simple spawn-based event
local function ExecuteSimpleEvent(data, world, target)
    Log(">>> ExecuteSimpleEvent: " .. data.name)

    local players = data.all_players and (GLOBAL.AllPlayers or {}) or {target or GetRandomPlayer()}
    Log(">>> Players to process: " .. #players)

    for _, player in ipairs(players) do
        if player then
            local x, y, z = player.Transform:GetWorldPosition()

            for _, spawn in ipairs(data.spawns or {}) do
                local prefab = spawn.prefab
                -- Handle random pick from list
                if type(prefab) == "table" and spawn.random_pick then
                    prefab = prefab[math.random(#prefab)]
                end

                -- Handle random count range
                local count = spawn.count
                if type(count) == "table" then
                    count = math.random(count[1], count[2])
                end

                -- Calculate spawn position
                local spawnX = x + (spawn.offset_x or 0)
                local spawnZ = z + (spawn.offset_z or 0)

                -- Adjust for distance spawns (like treasure hunt)
                if spawn.distance then
                    local angle = math.random() * 2 * math.pi
                    spawnX = x + math.cos(angle) * spawn.distance
                    spawnZ = z + math.sin(angle) * spawn.distance
                end

                -- Spawn the items
                Log(">>> Spawning " .. count .. "x " .. tostring(prefab) .. " at (" .. spawnX .. ", " .. spawnZ .. ")")
                for i = 1, count do
                    if spawn.velocity then
                        SpawnWithVelocity(prefab, spawnX, spawnZ, spawn.velocity)
                    else
                        SpawnNear(prefab, spawnX, spawnZ, spawn.radius)
                    end
                end
            end
        end
    end
end

-- Execute timed loot drop event
local function ExecuteTimedEvent(data, world, target)
    Log("Executing " .. data.name)

    local player = target or GetRandomPlayer()
    if not player then return end
    local x, y, z = player.Transform:GetWorldPosition()

    -- Handle initial spawns (like meteor shower flint/nitre)
    if data.initial_spawns then
        for _, spawn in ipairs(data.initial_spawns) do
            for i = 1, spawn.count do
                SpawnNear(spawn.prefab, x, z, spawn.radius)
            end
        end
    end

    -- Handle meteor shower special case
    if data.meteor_count then
        for i = 1, data.meteor_count do
            world:DoTaskInTime(i * data.meteor_delay, function()
                local meteorX = x + (math.random() - 0.5) * data.meteor_spread
                local meteorZ = z + (math.random() - 0.5) * data.meteor_spread
                SpawnNear("rocks", meteorX, meteorZ, 2)
                SpawnNear("rocks", meteorX, meteorZ, 2)
                if math.random() < 0.3 then SpawnNear("goldnugget", meteorX, meteorZ, 2) end
                if math.random() < 0.1 then SpawnNear("moonrocknugget", meteorX, meteorZ, 2) end
            end)
        end
        return
    end

    -- Handle standard timed loot drops
    for i, item in ipairs(data.loot or {}) do
        world:DoTaskInTime(i * data.delay_per_item, function()
            SpawnWithVelocity(item, x, z, data.velocity)
        end)
    end
    Log(data.name .. ": Scheduled " .. #(data.loot or {}) .. " items")
end

-- Execute multi-wave event
local function ExecuteWaveEvent(data, world, target)
    Log("=== " .. data.name .. " STARTING ===")

    local player = target or GetRandomPlayer()
    if not player then return end
    local x, y, z = player.Transform:GetWorldPosition()

    -- Drop initial gear
    if data.initial_gear then
        for _, item in ipairs(data.initial_gear) do
            SpawnNear(item, x, z, 3)
        end
    end

    -- Schedule all waves
    for _, wave in ipairs(data.waves or {}) do
        world:DoTaskInTime(wave.delay, function()
            Log("Wave at " .. wave.delay .. "s: " .. (wave.announce or ""))

            -- Announce
            if wave.announce and GLOBAL.TheNet then
                GLOBAL.TheNet:Announce(wave.announce)
            end

            -- Spawn rewards
            if wave.rewards then
                for _, item in ipairs(wave.rewards) do
                    SpawnNear(item, x, z, 4)
                end
            end

            -- Spawn velocity rewards (like loot explosions)
            if wave.velocity_rewards then
                for _, item in ipairs(wave.velocity_rewards) do
                    SpawnWithVelocity(item, x, z, 10)
                end
            end

            -- Spawn enemies/entities
            if wave.spawns then
                for _, spawn in ipairs(wave.spawns) do
                    local prefab = spawn.prefab
                    if type(prefab) == "table" and spawn.random_pick then
                        prefab = prefab[math.random(#prefab)]
                    end
                    for i = 1, spawn.count do
                        SpawnNear(prefab, x, z, spawn.radius)
                    end
                end
            end
        end)
    end
end

-- Execute beefalo stampede (special targeting logic)
local function ExecuteBeefaloStampede(data, world, target)
    Log("=== BEEFALO STAMPEDE ===")
    local player = target or GetRandomPlayer()
    if not player then return end
    local x, y, z = player.Transform:GetWorldPosition()

    local chargeAngle = math.random() * 2 * math.pi
    local startDist = 30

    for i = 1, 15 do
        local offsetAngle = chargeAngle + (math.random() - 0.5) * 0.5
        local offsetDist = startDist + math.random() * 10
        local spawnX = x + math.cos(offsetAngle) * offsetDist
        local spawnZ = z + math.sin(offsetAngle) * offsetDist

        local beefalo = GLOBAL.SpawnPrefab("beefalo")
        if beefalo then
            beefalo.Transform:SetPosition(spawnX, 0, spawnZ)
            if beefalo.components.combat then
                beefalo.components.combat:SetTarget(player)
            end
        end
    end

    for i = 1, 5 do SpawnNear("beefalowool", x, z, 8) end
    for i = 1, 3 do SpawnNear("meat", x, z, 8) end
    Log("Spawned 15 angry beefalo!")
end

-- =============================================================================
-- EVENT REGISTRATION
-- =============================================================================

local function RegisterAllEvents(mgr)
    Log("Registering events...")

    -- Register simple events
    for id, data in pairs(SIMPLE_EVENTS) do
        mgr:RegisterEvent({
            id = id,
            name = data.name,
            category = data.category,
            rarity = data.rarity,
            trigger = data.trigger,
            GetAnnouncement = function() return data.announcement end,
            Execute = function(self, world, target)
                ExecuteSimpleEvent(data, world, target)
            end,
        })
    end

    -- Register timed events
    for id, data in pairs(TIMED_EVENTS) do
        mgr:RegisterEvent({
            id = id,
            name = data.name,
            category = data.category,
            rarity = data.rarity,
            trigger = data.trigger,
            GetAnnouncement = function() return data.announcement end,
            Execute = function(self, world, target)
                ExecuteTimedEvent(data, world, target)
            end,
        })
    end

    -- Register wave events
    for id, data in pairs(WAVE_EVENTS) do
        mgr:RegisterEvent({
            id = id,
            name = data.name,
            category = data.category,
            rarity = data.rarity,
            trigger = data.trigger,
            GetAnnouncement = function() return data.announcement end,
            Execute = function(self, world, target)
                ExecuteWaveEvent(data, world, target)
            end,
        })
    end

    -- Register special events
    mgr:RegisterEvent({
        id = "beefalo_stampede",
        name = SPECIAL_EVENTS.beefalo_stampede.name,
        category = SPECIAL_EVENTS.beefalo_stampede.category,
        rarity = SPECIAL_EVENTS.beefalo_stampede.rarity,
        trigger = SPECIAL_EVENTS.beefalo_stampede.trigger,
        GetAnnouncement = function() return SPECIAL_EVENTS.beefalo_stampede.announcement end,
        Execute = function(self, world, target)
            ExecuteBeefaloStampede(SPECIAL_EVENTS.beefalo_stampede, world, target)
        end,
    })

    -- Summary
    local eventCount = mgr:GetEventCount()
    Log("=== EVENT REGISTRATION COMPLETE ===")
    Log("Total events: " .. eventCount)
    Log("Reward events: " .. mgr:GetCategoryEventCount(EVENT_CATEGORY.REWARD))
    Log("Challenge events: " .. mgr:GetCategoryEventCount(EVENT_CATEGORY.CHALLENGE))
    Log("Boss events: " .. mgr:GetCategoryEventCount(EVENT_CATEGORY.BOSS))
    Log("Social events: " .. mgr:GetCategoryEventCount(EVENT_CATEGORY.SOCIAL))
end

-- Called when the world is initialized (server-side only)
local function OnWorldPostInit(world)
    local ok, err = GLOBAL.pcall(function()
        if not GLOBAL.TheWorld.ismastersim then
            return
        end

        Log("World initialized, setting up event system...")

        -- Create the event manager
        EventManager = CreateEventManager(world)

        -- Store reference globally for prefabs to access
        -- (disabled due to strict mode - prefabs use rawget instead)
        -- EventManager stored locally, accessed via GLOBAL.TheWorld.event_manager if needed

        -- Register all events
        RegisterAllEvents(EventManager)

        Log("Event system ready with " .. EventManager:GetEventCount() .. " events")
    end)

    if not ok then
        Log("ERROR in OnWorldPostInit: " .. tostring(err))
    end
end

-- Monitor day/night cycle to trigger daily events
local function OnPhaseChange(world, phase)
    local ok, err = GLOBAL.pcall(function()
        if not GLOBAL.TheWorld.ismastersim then
            return
        end

        if phase == "day" and lastPhase ~= "day" then
            Log("Dawn detected!")
            if EventManager then
                EventManager:OnDayStart()
            end
        end

        lastPhase = phase
    end)

    if not ok then
        Log("ERROR in OnPhaseChange: " .. tostring(err))
    end
end

-- Monitor season changes
local function OnSeasonChange(world, season)
    local ok, err = GLOBAL.pcall(function()
        if not GLOBAL.TheWorld.ismastersim then
            return
        end

        Log("Season changed to: " .. season)
        if EventManager then
            EventManager:OnSeasonChange(season)
        end
    end)

    if not ok then
        Log("ERROR in OnSeasonChange: " .. tostring(err))
    end
end

-- Hook into world events when mod loads
AddPrefabPostInit("world", function(world)
    local ok, err = GLOBAL.pcall(function()
        if not GLOBAL.TheWorld.ismastersim then
            return
        end

        -- Initialize after world is ready
        world:DoTaskInTime(0, function()
            OnWorldPostInit(world)
        end)

        -- Listen for phase changes (day/dusk/night)
        world:WatchWorldState("phase", OnPhaseChange)

        -- Listen for season changes
        world:WatchWorldState("season", OnSeasonChange)
    end)

    if not ok then
        Log("ERROR in AddPrefabPostInit: " .. tostring(err))
    end
end)

-- =============================================================================
-- LOOKOUT TOWER: Scout mode overlay and zoom
-- =============================================================================

-- Add overlay when entering scout mode
AddPlayerPostInit(function(player)
    player:ListenForEvent("enterscoutmode", function()
        if player.HUD then
            local ScoutOverlay = require "widgets/scoutoverlay"
            player._scout_overlay = player.HUD.root:AddChild(ScoutOverlay(player))

            -- Zoom out (2.5 = much farther away)
            if GLOBAL.TheCamera then
                player._scout_original_zoom = GLOBAL.TheCamera.distance
                GLOBAL.TheCamera:SetDistance(player._scout_original_zoom * 2.5)
            end

            -- Hide clouds/overlays
            if player.HUD.overlays then
                player._scout_overlays_alpha = {}
                for name, overlay in pairs(player.HUD.overlays) do
                    if overlay.SetAlpha then
                        player._scout_overlays_alpha[name] = true
                        overlay:SetAlpha(0)
                    elseif overlay.Hide then
                        overlay:Hide()
                    end
                end
            end
            -- Also try the over layer
            if player.HUD.over then
                player.HUD.over:Hide()
            end
        end
    end)

    player:ListenForEvent("exitscoutmode", function()
        if player._scout_overlay then
            player._scout_overlay:Kill()
            player._scout_overlay = nil
        end

        -- Restore zoom
        if player._scout_original_zoom and GLOBAL.TheCamera then
            GLOBAL.TheCamera:SetDistance(player._scout_original_zoom)
            player._scout_original_zoom = nil
        end

        -- Restore overlays
        if player.HUD then
            if player.HUD.overlays and player._scout_overlays_alpha then
                for name, overlay in pairs(player.HUD.overlays) do
                    if overlay.SetAlpha then
                        overlay:SetAlpha(1)
                    elseif overlay.Show then
                        overlay:Show()
                    end
                end
                player._scout_overlays_alpha = nil
            end
            if player.HUD.over then
                player.HUD.over:Show()
            end
        end
    end)
end)

-- SPACE key to drop in while scouting
GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_SPACE, function()
    local player = GLOBAL.ThePlayer
    if player and player:HasTag("scouting") then
        if GLOBAL.LookoutTowerExitScout then
            GLOBAL.LookoutTowerExitScout(player, false)  -- false = don't teleport back
        end
    end
end)

-- =============================================================================
-- CHALLENGE SYSTEM - Data-driven challenges with shared multiplayer state
-- =============================================================================
--[[
ARCHITECTURE:
- Challenge definitions live in scripts/challenges/challenge_data.lua
- ObjectiveTracker widget (scripts/widgets/objectivetracker.lua) renders any challenge
- State is stored on TheWorld for multiplayer sync
- Events are tracked via check_progress() function in challenge config

FLOW:
1. Cursed box opened -> StartChallenge("day_one") called
2. Challenge config loaded from ChallengeData
3. ObjectiveTracker UI created for all players
4. Player events trigger check_progress() -> AddProgress() -> UpdateDisplay()
5. When complete: GrantReward() -> Kill UI after delay
--]]

-- Shared challenge state (stored on TheWorld for multiplayer)
local function GetActiveChallenge()
    if GLOBAL.TheWorld and GLOBAL.TheWorld._active_challenge then
        return GLOBAL.TheWorld._active_challenge
    end
    return nil
end

-- Initialize a new challenge
-- @param challenge_id string - ID from challenge_data.lua
local function StartChallenge(challenge_id)
    if not GLOBAL.TheWorld then return end
    if GLOBAL.TheWorld._active_challenge then
        Log("Challenge already active: " .. GLOBAL.TheWorld._active_challenge.config.id)
        return
    end

    -- Load challenge data
    local ok, ChallengeData = GLOBAL.pcall(function()
        return require "challenges/challenge_data"
    end)
    if not ok then
        Log("ERROR: Failed to load challenge_data")
        return
    end

    local config = ChallengeData.GetChallenge(challenge_id)
    if not config then
        Log("ERROR: Challenge not found: " .. tostring(challenge_id))
        return
    end

    -- Initialize shared state
    local state = {
        config = config,
        progress = {},      -- { objective_id = count, ... }
        completed = false,
        trackers = {},      -- { player = widget, ... }
    }

    -- Initialize progress for each objective
    for _, obj in ipairs(config.objectives) do
        state.progress[obj.id] = 0
    end

    GLOBAL.TheWorld._active_challenge = state
    Log("Challenge started: " .. config.title)

    -- Create UI for all current players
    for _, player in ipairs(GLOBAL.AllPlayers or {}) do
        AddChallengeTrackerToPlayer(player)
    end
end

-- Add tracker UI to a specific player
function AddChallengeTrackerToPlayer(player)
    local state = GetActiveChallenge()
    if not state or not player or not player.HUD then return end
    if state.trackers[player] then return end  -- Already has tracker

    local ok, ObjectiveTracker = GLOBAL.pcall(function()
        return require "widgets/objectivetracker"
    end)

    if ok and ObjectiveTracker then
        local tracker = player.HUD.root:AddChild(ObjectiveTracker(player, state.config))

        -- Sync existing progress
        for obj_id, count in pairs(state.progress) do
            tracker:SetProgress(obj_id, count)
        end

        state.trackers[player] = tracker
        Log("Challenge tracker added for: " .. tostring(player))
    end
end

-- Update all player trackers with current progress
local function UpdateAllChallengeTrackers()
    local state = GetActiveChallenge()
    if not state then return end

    for player, tracker in pairs(state.trackers) do
        if tracker and tracker:IsValid() then
            for obj_id, count in pairs(state.progress) do
                tracker:SetProgress(obj_id, count)
            end
            tracker:CheckComplete()
        end
    end
end

-- Handle an event and check if it contributes to challenge progress
-- @param player entity - Player who triggered event
-- @param event_name string - DST event name
-- @param event_data table - Event data
local function OnChallengeEvent(player, event_name, event_data)
    local state = GetActiveChallenge()
    if not state or state.completed then return end

    -- Use challenge's check_progress function to determine contribution
    local obj_id, amount = state.config.check_progress(player, event_name, event_data)

    if obj_id and amount and amount > 0 then
        -- Find target for this objective
        local target = 0
        for _, obj in ipairs(state.config.objectives) do
            if obj.id == obj_id then
                target = obj.target
                break
            end
        end

        -- Update shared progress
        state.progress[obj_id] = math.min(target, (state.progress[obj_id] or 0) + amount)
        Log(string.format("Challenge progress: %s = %d", obj_id, state.progress[obj_id]))

        -- Update all player UIs
        UpdateAllChallengeTrackers()

        -- Check if all objectives complete
        local all_complete = true
        for _, obj in ipairs(state.config.objectives) do
            if (state.progress[obj.id] or 0) < obj.target then
                all_complete = false
                break
            end
        end

        if all_complete then
            state.completed = true
            Log("Challenge COMPLETE: " .. state.config.title)
        end
    end
end

-- Make StartChallenge globally accessible (for cursed box, etc.)
GLOBAL.rawset(GLOBAL, "StartChallenge", StartChallenge)
Log("Challenge system registered!")

-- Set up event tracking for all players
AddPlayerPostInit(function(player)
    -- Add tracker if challenge already active (player joined mid-challenge)
    player:DoTaskInTime(1, function()
        AddChallengeTrackerToPlayer(player)
    end)

    -- Track events defined in active challenge
    local tracked_events = {"itemget", "killed", "picksomething", "finishedwork"}

    for _, event_name in ipairs(tracked_events) do
        player:ListenForEvent(event_name, function(inst, data)
            OnChallengeEvent(player, event_name, data)
        end)
    end
end)

-- Log successful initialization
Log("Mod initialized successfully!")
Log("DnD Gamemaster mode enabled - daily and weekly events active!")
Log("Lookout Tower system loaded!")
Log("Day One objective system loaded!")
