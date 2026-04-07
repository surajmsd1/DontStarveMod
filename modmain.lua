-- Mystery Box Mod - Main Entry Point
-- DnD Gamemaster style mod that triggers daily/weekly events with rewards and dangers

-- Version - UPDATE THIS ON EVERY CHANGE
local MOD_VERSION = "DEV-4.1.1"

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

Log("Mod loading... Version: " .. MOD_VERSION)

-- Announce version when player spawns into world (runs on server, only on Master not Caves)
AddSimPostInit(function()
    if GLOBAL.TheWorld.ismastersim and not GLOBAL.TheWorld:HasTag("cave") then
        GLOBAL.TheWorld:DoTaskInTime(3, function()
            GLOBAL.TheNet:Announce("[Mystery Box] Version " .. MOD_VERSION .. " loaded!")
        end)
    end
end)

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
-- LOOKOUT TOWER: Scout Mode System
-- =============================================================================
-- Server: EnterScoutMode (prefab) adds "scouting" tag
-- Client: Polls tag → shows/hides overlay
-- Exit: SPACE (RPC), max distance, or interaction → all call ExitScoutMode
--
-- =============================================================================
-- DST CLIENT/SERVER ARCHITECTURE - LESSONS LEARNED
-- =============================================================================
--
-- DST runs as SERVER + CLIENT even in single player.
--
-- SERVER has:
--   - player.components (locomotor, health, inventory, etc.)
--   - Prefab logic, game state, entity spawning
--   - TheWorld.ismastersim = true
--
-- CLIENT has:
--   - player.HUD (UI widgets, health bars, overlays)
--   - TheInput (keyboard/mouse handling)
--   - TheCamera (zoom, position)
--   - TheWorld.ismastersim = false
--
-- TAGS sync automatically between server and client!
--   Server: player:AddTag("scouting")
--   Client: player:HasTag("scouting") returns true (after sync)
--
-- EVENTS do NOT sync! Use tags or RPC instead.
--
-- RPC (Remote Procedure Call) for client→server communication:
--   Server: AddModRPCHandler("ModName", "FunctionName", function(player) ... end)
--   Client: SendModRPCToServer(MOD_RPC["ModName"]["FunctionName"])
--
-- Common pattern for UI that responds to server state:
--   1. Server adds/removes a tag
--   2. Client polls for tag with DoPeriodicTask
--   3. Client shows/hides UI based on tag
-- =============================================================================

-- Exit scout mode (SERVER only)
local function ExitScoutMode(player, message)
    if not player or not player:HasTag("scouting") then
        return false
    end

    -- Cancel tasks
    if player._scout_task then
        player._scout_task:Cancel()
        player._scout_task = nil
    end

    -- Remove listeners
    if player._scout_action_listener then
        player:RemoveEventCallback("performaction", player._scout_action_listener)
        player._scout_action_listener = nil
    end

    -- Restore player state
    if player.components.locomotor then
        player.components.locomotor.runspeed = player._scout_original_speed or 8
        player.components.locomotor.walkspeed = 4
    end
    player.AnimState:SetMultColour(1, 1, 1, 1)
    player:RemoveTag("scouting")

    -- Feedback
    if player.components.talker and message then
        player.components.talker:Say(message)
    end

    -- Reset tower and start cooldown
    local tower = player._scout_tower
    if tower and tower:IsValid() then
        tower.scout_active = false
        tower.scout_player = nil
        tower.cooldown_until = GLOBAL.GetTime() + 300  -- 5 minutes
        -- Re-enable via component property (this also adds the tag)
        if tower.components.activatable then
            tower.components.activatable.inactive = true
        end
    end

    -- Cleanup
    player._scout_original_speed = nil
    player._scout_tower = nil
    player._scout_tower_pos = nil

    Log("Scout mode OFF")
    return true
end

-- Expose to prefab
GLOBAL.MysteryBox_ExitScoutMode = ExitScoutMode

-- RPC for SPACE key
AddModRPCHandler("MysteryBox", "ExitScoutMode", function(player)
    ExitScoutMode(player, "Dropped in!")
end)

-- =============================================================================
-- CLIENT: Overlay management
-- =============================================================================

local function CreateScoutOverlay(player)
    if player._scout_overlay or not player.HUD or not player.HUD.root then
        return
    end

    local ScoutOverlay = require "widgets/scoutoverlay"
    player._scout_overlay = player.HUD.root:AddChild(ScoutOverlay(player))

    -- Zoom out
    if GLOBAL.TheCamera then
        player._scout_original_zoom = GLOBAL.TheCamera.distance
        GLOBAL.TheCamera:SetDistance(player._scout_original_zoom * 2.5)
    end

    -- Hide fog
    if player.HUD.clouds then player.HUD.clouds:Hide() end
    if player.HUD.over then player.HUD.over:Hide() end
end

local function DestroyScoutOverlay(player)
    if not player._scout_overlay then return end

    player._scout_overlay:Kill()
    player._scout_overlay = nil

    -- Restore zoom
    if player._scout_original_zoom and GLOBAL.TheCamera then
        GLOBAL.TheCamera:SetDistance(player._scout_original_zoom)
        player._scout_original_zoom = nil
    end

    -- Restore fog
    if player.HUD then
        if player.HUD.clouds then player.HUD.clouds:Show() end
        if player.HUD.over then player.HUD.over:Show() end
    end
end

-- Poll for scouting tag
AddPlayerPostInit(function(player)
    player:DoPeriodicTask(0.3, function()
        if player ~= GLOBAL.ThePlayer then return end

        local is_scouting = player:HasTag("scouting")
        local has_overlay = player._scout_overlay ~= nil

        if is_scouting and not has_overlay then
            CreateScoutOverlay(player)
        elseif not is_scouting and has_overlay then
            DestroyScoutOverlay(player)
        end
    end)
end)

-- SPACE key exits scout mode
GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_SPACE, function()
    local player = GLOBAL.ThePlayer
    if player and player:HasTag("scouting") then
        SendModRPCToServer(MOD_RPC["MysteryBox"]["ExitScoutMode"])
    end
end)

-- =============================================================================
-- LOOKOUT TOWER SPAWNING SYSTEM
-- =============================================================================
-- Spawns one lookout tower per biome/node at world load
-- Uses TheWorld.topology.nodes for biome center positions
-- TheWorld.topology.ids contains biome names
-- =============================================================================

local TOWER_SPAWN_ENABLED = true

-- Main biome/task prefixes - these are the actual large areas, not tiny rooms
-- Rooms have names like "Forest:Clearing", we want one tower per task prefix
local MAIN_BIOME_PREFIXES = {
    "Clearing",      -- Spawn/start area
    "Forest",        -- Forest biome
    "Marsh",         -- Swamp
    "Plain",         -- Savanna/grasslands
    "Rocky",         -- Rock biome
    "Graveyard",     -- Graveyard
    "Chess",         -- Chess biome
    "Wormhole",      -- Wormhole area
    "MoonIsland",    -- Lunar island
    "Oasis",         -- Desert oasis
    "Desert",        -- Desert
    "Beefalo",       -- Beefalo plains
    "Beefalow",      -- Alt spelling
    "Pigs",          -- Pig king area
    "Walrus",        -- Walrus camps
    "Spiders",       -- Spider areas
    "Mosaic",        -- Mixed biome
    "Ocean",         -- Skip ocean
}

local function GetBiomePrefix(roomId)
    -- Extract the task/biome name from room ID
    -- Room IDs look like: "Forest:Forest hunters camp" or "Marsh:Tentacle hell"
    if not roomId then return nil end
    local prefix = roomId:match("^([^:]+)")
    return prefix or roomId
end

local function SpawnTowersAtBiomeCenters()
    if not GLOBAL.TheWorld.ismastersim then return end
    if not TOWER_SPAWN_ENABLED then return end

    local topology = GLOBAL.TheWorld.topology
    if not topology or not topology.nodes or not topology.ids then
        Log("ERROR: No topology data available for tower spawning")
        return
    end

    local nodes = topology.nodes
    local ids = topology.ids

    Log("=== ANALYZING WORLD TOPOLOGY ===")
    Log("Total nodes: " .. #nodes)

    -- First pass: find unique biome prefixes and pick best node for each
    local biomeData = {}  -- biomePrefix -> {nodes = {}, bestNode = nil}

    for i, node in ipairs(nodes) do
        local roomId = ids[i]
        local prefix = GetBiomePrefix(roomId)

        if prefix and prefix ~= "Blank" and not prefix:match("Ocean") then
            if not biomeData[prefix] then
                biomeData[prefix] = {nodes = {}, bestNode = nil, bestIndex = nil}
            end
            table.insert(biomeData[prefix].nodes, {node = node, index = i, roomId = roomId})
        end
    end

    -- Second pass: for each biome, pick the most central/representative node
    local uniqueBiomes = {}
    for prefix, data in pairs(biomeData) do
        -- Pick the first valid node for now (could improve to pick center)
        for _, nodeData in ipairs(data.nodes) do
            local node = nodeData.node
            local x = node.x or (node.cent and node.cent[1])
            local z = node.y or (node.cent and node.cent[2])

            if x and z then
                local isPassable = GLOBAL.TheWorld.Map:IsPassableAtPoint(x, 0, z)
                local isOcean = GLOBAL.TheWorld.Map:IsOceanAtPoint(x, 0, z)

                if isPassable and not isOcean then
                    data.bestNode = node
                    data.bestIndex = nodeData.index
                    data.bestRoomId = nodeData.roomId
                    table.insert(uniqueBiomes, prefix)
                    break
                end
            end
        end
    end

    Log("Found " .. #uniqueBiomes .. " unique biomes")

    -- Third pass: spawn towers at biome centers
    local spawned = 0
    for _, prefix in ipairs(uniqueBiomes) do
        local data = biomeData[prefix]
        if data.bestNode then
            local node = data.bestNode
            local x = node.x or (node.cent and node.cent[1])
            local z = node.y or (node.cent and node.cent[2])

            local tower = GLOBAL.SpawnPrefab("lookouttower")
            if tower then
                tower.Transform:SetPosition(x, 0, z)
                tower.biome_name = prefix
                tower.biome_index = data.bestIndex
                tower.room_id = data.bestRoomId

                spawned = spawned + 1
                Log("Tower #" .. spawned .. ": " .. prefix .. " at (" .. math.floor(x) .. ", " .. math.floor(z) .. ")")
            end
        end
    end

    Log("=== TOWER SPAWNING COMPLETE ===")
    Log("Spawned: " .. spawned .. " towers for " .. #uniqueBiomes .. " biomes")

    if spawned > 0 then
        GLOBAL.TheNet:Announce("[Mystery Box] " .. spawned .. " Lookout Towers placed across the world!")
    end
end

-- Remove all existing lookout towers from the world
local function RemoveAllTowers()
    local existing = GLOBAL.TheSim:FindEntities(0, 0, 0, 10000, {"lookouttower"})
    local count = 0
    if existing then
        for _, tower in ipairs(existing) do
            if tower:IsValid() then
                tower:Remove()
                count = count + 1
            end
        end
    end
    return count
end

-- Chat command: /spawntowers [force]
-- Spawns lookout towers across all biomes. Use "force" to replace existing towers.
AddUserCommand("spawntowers", {
    prettyname = "Spawn Lookout Towers",
    desc = "Spawns lookout towers across biomes. Use 'force' to replace existing ones.",
    permission = GLOBAL.COMMAND_PERMISSION.ADMIN,
    slash = true,
    usermenu = false,
    serverfn = function(params, caller)
        local force = params.rest and params.rest:lower():match("force")

        local existing = GLOBAL.TheSim:FindEntities(0, 0, 0, 10000, {"lookouttower"})
        local existingCount = existing and #existing or 0

        if existingCount > 0 and not force then
            GLOBAL.TheNet:Announce("[Mystery Box] " .. existingCount .. " towers already exist. Use '/spawntowers force' to replace them.")
            return
        end

        if force and existingCount > 0 then
            local removed = RemoveAllTowers()
            Log("Removed " .. removed .. " existing towers")
        end

        SpawnTowersAtBiomeCenters()
    end,
    params = {"rest"},
})

-- Spawn towers after world generation is complete
AddPrefabPostInit("world", function(world)
    if not GLOBAL.TheWorld.ismastersim then return end

    -- Wait for world to fully load before spawning towers
    world:DoTaskInTime(1, function()
        -- Only spawn on fresh worlds or when towers don't exist yet
        -- Check if towers already exist to avoid duplicates on reload
        local existingTowers = GLOBAL.TheSim:FindEntities(0, 0, 0, 10000, {"lookouttower"})
        if existingTowers and #existingTowers > 0 then
            Log("Towers already exist (" .. #existingTowers .. "), skipping spawn")
            return
        end

        SpawnTowersAtBiomeCenters()
    end)
end)

-- Log successful initialization
Log("Mod initialized successfully!")
Log("Lookout Tower system loaded!")
