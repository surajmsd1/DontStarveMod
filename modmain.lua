-- Mystery Box Mod - Main Entry Point
-- DnD Gamemaster style mod that triggers daily/weekly events with rewards and dangers

-- Version - UPDATE THIS ON EVERY CHANGE
local MOD_VERSION = "DEV-4.30.1-dnd-master"

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

-- Load custom screen at startup (plain require works for mod scripts/)
local TowerNetworkScreen = require("screens/towernetworkscreen")

-- Announce version when player spawns into world (runs on server, only on Master not Caves)
AddSimPostInit(function()
    if GLOBAL.TheWorld.ismastersim and not GLOBAL.TheWorld:HasTag("cave") then
        GLOBAL.TheWorld:DoTaskInTime(3, function()
            GLOBAL.TheNet:Announce("[Mystery Box] Version " .. MOD_VERSION .. " loaded!")
        end)
    end
end)

-- Pre-declare image atlases so the engine loads them at mod init.
-- The DnD Master widget references these at runtime; without these
-- entries Image:SetTexture silently fails. images/avatars.xml + .tex
-- are confirmed present in the DST install (databundles/images.zip).
-- Klei stores Maxwell as "waxwell" internally; the entry inside this
-- atlas is `avatar_waxwell.tex`.
Assets = {
    Asset("ATLAS", "images/avatars.xml"),
    Asset("IMAGE", "images/avatars.tex"),
}

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
        tower.cooldown_until = GLOBAL.GetTime() + 60  -- 1 minute (matches SCOUT_COOLDOWN)
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

    -- Move overlay to back (lowest z-order) so everything else draws on top
    player._scout_overlay:MoveToBack()

    -- Also re-add all existing HUD children to move them on top of overlay
    local children_to_move = {}
    for _, child in pairs(player.HUD.root.children or {}) do
        if child ~= player._scout_overlay then
            table.insert(children_to_move, child)
        end
    end
    for _, child in ipairs(children_to_move) do
        player.HUD.root:AddChild(child)
    end

    -- Zoom out more (4x for better scouting view)
    if GLOBAL.TheCamera then
        player._scout_original_zoom = GLOBAL.TheCamera.distance
        GLOBAL.TheCamera:SetDistance(player._scout_original_zoom * 3)
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
-- TOWER NAMING SYSTEM
-- =============================================================================
-- Each tower gets a name like "Willow's Marsh" or "Wolfgang's Outpost"
-- Format: [DST Character]'s [Biome] — or fallback if no biome available
-- Name stored as tag "towername_X" for client sync
-- =============================================================================

local DST_CHARACTERS = {
    -- Playable
    "Wilson", "Willow", "Wolfgang", "Wendy", "WX-78",
    "Wickerbottom", "Woodie", "Wes", "Maxwell", "Wigfrid",
    "Webber", "Winona", "Warly", "Wormwood", "Wurt",
    "Walter", "Wanda", "Wonkey",
    -- NPCs
    "Pearl", "Charlie", "Antlion", "Pig King", "Merm King",
    "Catcoon", "Glommer", "Chester", "Hutch", "Crabby",
    -- Bosses & mobs
    "Bearger", "Deerclops", "Moose", "Dragonfly",
    "Treeguard", "Spider Queen", "Klaus", "Toadstool",
    "Beefalo", "Tallbird", "Koalefant", "Volt Goat",
    "Hound", "Tentacle", "Merm", "Bunnyman", "Pigman",
    -- Lunar & shadow
    "Celestial Champion", "Ancient Guardian", "Fuelweaver",
    "Gestalts", "Terrorclaw", "Nightmare",
}

local FALLBACK_LANDMARKS = {
    "Outpost", "Watchtower", "Overlook", "Perch",
    "Garrison", "Spire", "Beacon", "Pinnacle",
    "Hideout", "Roost", "Den", "Keep",
}

-- Track which character names have been used this session to avoid repeats
local usedCharacters = {}

local function PickRandomCharacter()
    -- If we've used all characters, reset
    if #usedCharacters >= #DST_CHARACTERS then
        usedCharacters = {}
    end

    local available = {}
    for _, name in ipairs(DST_CHARACTERS) do
        local used = false
        for _, u in ipairs(usedCharacters) do
            if u == name then used = true break end
        end
        if not used then
            table.insert(available, name)
        end
    end

    local pick = available[math.random(#available)]
    table.insert(usedCharacters, pick)
    return pick
end

-- Resolve biome prefix for a tower by looking up its topology node.
-- Used when NameTower is called without a biome argument (e.g. deferred
-- auto-naming) so the name still ends with the biome.
local function ResolveBiomeForTower(tower)
    if not tower or not tower.Transform then return nil end
    local world = GLOBAL.TheWorld
    local map = world and world.Map
    local topology = world and world.topology
    if not map or not topology or not topology.ids then return nil end

    local x, _, z = tower.Transform:GetWorldPosition()
    local node_id = map:GetNodeIdAtPoint(x, 0, z)
    local roomId = node_id and topology.ids[node_id]
    if not roomId then return nil end
    local prefix = roomId:match("^([^:]+)")
    if not prefix or prefix == "Blank" or prefix:match("Ocean") then
        return nil
    end
    return prefix
end

local function GenerateTowerName(biome)
    local character = PickRandomCharacter()
    if biome and biome ~= "" then
        return character .. "'s " .. biome
    else
        local landmark = FALLBACK_LANDMARKS[math.random(#FALLBACK_LANDMARKS)]
        return character .. "'s " .. landmark
    end
end

-- Apply a generated name to a tower and sync via tag.
-- If biome wasn't supplied, try to resolve it from world topology so every
-- tower name ends with a biome when possible (easier to tell them apart).
local function NameTower(tower, biome)
    if not biome or biome == "" then
        biome = ResolveBiomeForTower(tower)
    end
    if biome and not tower.biome_name then
        tower.biome_name = biome
    end
    local name = GenerateTowerName(biome)
    tower.tower_display_name = name
    -- Store name as tag for client sync (replace spaces/special chars for tag safety)
    local safeTag = "towername_" .. name:gsub("[^%w]", "_")
    tower:AddTag(safeTag)
    return name
end

-- Expose for use by spawning system
GLOBAL.MysteryBox_NameTower = NameTower

-- =============================================================================
-- TOWER NETWORK: Right-Click Fast Travel
-- =============================================================================
-- Right click a tower → Tower Network screen (replaces examine)
-- Shows discovered towers with distance/direction, click to teleport
-- Discovery is interaction-driven (right-click or OnActivate)
-- Teleport cost: 15 sanity
-- =============================================================================

local TELEPORT_SANITY_COST = 15

-- =============================================================================
-- SHARED TOWER NETWORK (server-authoritative, saved in world, synced to clients)
-- =============================================================================
-- Server owns the list via a component on TheWorld (shared_tower_network).
-- Save/load is automatic through the component's OnSave/OnLoad.
-- Clients mirror it in GLOBAL.MysteryBox_SharedTowers, kept in sync by RPCs.

-- strict GLOBAL: can't read a name that's never been declared, so use rawget
GLOBAL.MysteryBox_SharedTowers = GLOBAL.rawget(GLOBAL, "MysteryBox_SharedTowers") or {}

-- Registry of all loaded lookouttower entities (client + server). Populated
-- via AddPrefabPostInit so TowerIndicator doesn't have to scan every entity
-- every frame. Lifecycle managed by an onremove listener.
GLOBAL.MysteryBox_LookoutTowers = GLOBAL.rawget(GLOBAL, "MysteryBox_LookoutTowers") or {}

AddPrefabPostInit("lookouttower", function(inst)
    local registry = GLOBAL.MysteryBox_LookoutTowers
    registry[inst] = true
    inst:ListenForEvent("onremove", function()
        registry[inst] = nil
    end)
end)

-- SERVER: attach component to TheWorld
AddPrefabPostInit("world", function(world)
    if not GLOBAL.TheWorld.ismastersim then return end
    if world.components.shared_tower_network then return end
    world:AddComponent("shared_tower_network")
    Log("Shared tower network component attached to world")
end)

-- SERVER: broadcast a single new tower entry to every connected player
local function BroadcastTowerAdd(key, entry)
    for _, p in ipairs(GLOBAL.AllPlayers) do
        if p.userid then
            SendModRPCToClient(
                CLIENT_MOD_RPC["MysteryBox"]["SyncTowerAdd"],
                p.userid, key, entry.x, entry.z, entry.name
            )
        end
    end
end

-- SERVER: send the full list to a specific player (used on spawn)
local function SendFullListTo(player)
    if not player or not player.userid then return end
    local world = GLOBAL.TheWorld
    local comp = world and world.components.shared_tower_network
    if not comp then return end
    for key, entry in pairs(comp:GetTowers()) do
        SendModRPCToClient(
            CLIENT_MOD_RPC["MysteryBox"]["SyncTowerAdd"],
            player.userid, key, entry.x, entry.z, entry.name
        )
    end
end

-- CLIENT: receive a tower entry from server
AddClientModRPCHandler("MysteryBox", "SyncTowerAdd", function(key, x, z, name)
    if not key then return end
    GLOBAL.MysteryBox_SharedTowers[key] = { x = x, z = z, name = name }
end)

-- Call rebuild when player spawns
AddPlayerPostInit(function(player)
    -- SERVER side: push the full discovered list to this player's client
    if GLOBAL.TheWorld and GLOBAL.TheWorld.ismastersim then
        player:DoTaskInTime(1, function()
            if player:IsValid() then
                SendFullListTo(player)
            end
        end)
    end

    -- CLIENT side: add tower indicator to HUD (anchored under the minimap)
    player:DoTaskInTime(1, function()
        if player.HUD and player == GLOBAL.ThePlayer then
            local TowerIndicator = require "widgets/towerindicator"
            local parent = player.HUD.controls and player.HUD.controls.topright_root
                        or player.HUD.topright_root
                        or player.HUD.controls
            player._tower_indicator = parent:AddChild(TowerIndicator(player))
            -- topright_root is anchored to top-right of screen: (0,0) sits at
            -- the corner, -X goes left, -Y goes down. Park it below the minimap.
            player._tower_indicator:SetPosition(-110, -240)
            Log("Tower indicator added to HUD")
        end
    end)
end)

-- =========================================================================
-- DnD MASTER (Layer 2): server-pushed dialogue rendered in a HUD widget.
-- Server picks a line via DnDMaster_Speak("category"); RPC ships
-- (speaker, text, duration) to every client; client widget renders it.
-- =========================================================================

local DnDDialogue = require "core/dnd_dialogue"

-- Register the client RPC. Server will call this on every connected
-- player when it wants the Master to speak.
AddClientModRPCHandler("MysteryBox", "DnDMasterSpeak", function(speaker, text, duration)
    local player = GLOBAL.ThePlayer
    if not player or not player._dnd_widget then return end
    player._dnd_widget:Speak(speaker, text, duration)
end)

-- SERVER helper: pick a line for a category and broadcast to all clients.
-- Safe to call any time after world init.
local function DnDMaster_Speak(category, override_duration)
    if not GLOBAL.TheWorld or not GLOBAL.TheWorld.ismastersim then return end
    local line = DnDDialogue.Pick(category)
    if not line then return end
    -- SendModRPCToClient with no userid arg → broadcast to everyone.
    GLOBAL.SendModRPCToClient(
        CLIENT_MOD_RPC["MysteryBox"]["DnDMasterSpeak"],
        nil,
        line.speaker, line.text, override_duration or 6
    )
    Log("DnDMaster [" .. category .. "]: " .. line.speaker .. " says " .. line.text)
end

-- Make it callable from console for testing:
--   DnDMaster_Speak("intro")
--   DnDMaster_Speak("boss_warning_bigbad")
GLOBAL.rawset(GLOBAL, "DnDMaster_Speak", DnDMaster_Speak)

-- CLIENT: inject the widget into each player's HUD.
AddPlayerPostInit(function(player)
    player:DoTaskInTime(1, function()
        if not player.HUD or player ~= GLOBAL.ThePlayer then return end
        if player._dnd_widget then return end
        local DnDMasterWidget = require "widgets/dndmaster_widget"
        player._dnd_widget = player.HUD.root:AddChild(DnDMasterWidget(player))
        Log("DnD Master widget added to HUD")
    end)
end)

-- SERVER: simple triggers that fire dialogue automatically.
-- Greeting on player join (delayed so the widget exists on their client).
AddPlayerPostInit(function(player)
    if not (GLOBAL.TheWorld and GLOBAL.TheWorld.ismastersim) then return end
    player:DoTaskInTime(4, function()
        if player:IsValid() then
            DnDMaster_Speak("intro")
        end
    end)
end)

-- Day milestone: every 10 days the Master gloats. Hooked to phase changes
-- so we catch the dawn transition without needing the EventManager.
local _dnd_last_milestone_day = -1
AddPrefabPostInit("world", function(world)
    if not GLOBAL.TheWorld.ismastersim then return end
    world:ListenForEvent("phasechanged", function(_, phase)
        if phase ~= "day" then return end
        local day = world.state and world.state.cycles or 0
        if day > 0 and day % 10 == 0 and day ~= _dnd_last_milestone_day then
            _dnd_last_milestone_day = day
            DnDMaster_Speak("day_milestone")
        end
    end)
end)

-- =========================================================================

-- SERVER: core discovery logic (called from RPC and from OnActivate)
local function DiscoverTowerServer(target, requesting_player)
    if not target or not target:HasTag("lookouttower") then return end
    local world = GLOBAL.TheWorld
    local comp = world and world.components.shared_tower_network
    if not comp then
        Log("DiscoverTowerServer: shared_tower_network component missing")
        return
    end

    if not target:HasTag("tower_discovered") then
        target:AddTag("tower_discovered")
    end

    local key, entry, isNew = comp:AddTower(target)
    if not key then return end

    if isNew then
        Log("Tower discovered: " .. entry.name .. " at " .. key)
        BroadcastTowerAdd(key, entry)
    elseif requesting_player and requesting_player.userid then
        -- Already known on server but requester might not have it cached yet
        SendModRPCToClient(
            CLIENT_MOD_RPC["MysteryBox"]["SyncTowerAdd"],
            requesting_player.userid, key, entry.x, entry.z, entry.name
        )
    end
end

GLOBAL.MysteryBox_DiscoverTowerServer = DiscoverTowerServer

-- RPC: Discover a tower (client → server)
AddModRPCHandler("MysteryBox", "DiscoverTower", function(player, target)
    DiscoverTowerServer(target, player)
end)

-- RPC: Teleport to position (for tower network UI)
AddModRPCHandler("MysteryBox", "TowerTeleportPos", function(player, targetX, targetZ)
    if not player then return end

    -- Must be near a tower to teleport
    local px, _, pz = player.Transform:GetWorldPosition()
    local nearby = GLOBAL.TheSim:FindEntities(px, 0, pz, 5, {"lookouttower"})
    if not nearby or #nearby == 0 then
        if player.components.talker then
            player.components.talker:Say("I need to be at a tower first.")
        end
        return
    end

    -- Check sanity cost
    if player.components.sanity then
        local currentSanity = player.components.sanity:GetPercent() * player.components.sanity.max
        if currentSanity < TELEPORT_SANITY_COST then
            if player.components.talker then
                player.components.talker:Say("I'm too frazzled to travel...")
            end
            return
        end
        player.components.sanity:DoDelta(-TELEPORT_SANITY_COST)
    end

    -- Teleport!
    player.Transform:SetPosition(targetX, 0, targetZ)
    if player.components.talker then
        player.components.talker:Say("Arrived!")
    end
    Log("Player teleported to " .. math.floor(targetX) .. "," .. math.floor(targetZ))
end)

-- RPC: Teleport to target tower (legacy)
AddModRPCHandler("MysteryBox", "TowerTeleport", function(player, target)
    if not player or not target or not target:HasTag("lookouttower") then
        return
    end

    -- Must be near a tower to teleport
    local px, _, pz = player.Transform:GetWorldPosition()
    local nearby = GLOBAL.TheSim:FindEntities(px, 0, pz, 5, {"lookouttower"})
    if not nearby or #nearby == 0 then
        if player.components.talker then
            player.components.talker:Say("I need to be at a tower first.")
        end
        return
    end

    -- Must have discovered the target
    if not target:HasTag("tower_discovered") then
        if player.components.talker then
            player.components.talker:Say("I haven't found that tower yet.")
        end
        return
    end

    -- Check sanity cost
    if player.components.sanity then
        local currentSanity = player.components.sanity:GetPercent() * player.components.sanity.max
        if currentSanity < TELEPORT_SANITY_COST then
            if player.components.talker then
                player.components.talker:Say("I'm too frazzled to travel... need more sanity.")
            end
            return
        end
        player.components.sanity:DoDelta(-TELEPORT_SANITY_COST)
    end

    -- Teleport
    local tx, ty, tz = target.Transform:GetWorldPosition()
    player.Transform:SetPosition(tx, ty, tz)

    local name = target.tower_display_name or target.biome_name or "Unknown"
    if player.components.talker then
        player.components.talker:Say("Arrived at " .. name .. "!")
    end

    Log("Player teleported to " .. name)
end)

-- Right-click on a tower opens the Tower Network screen
GLOBAL.TheInput:AddMouseButtonHandler(function(button, down)
    if button ~= GLOBAL.MOUSEBUTTON_RIGHT or not down then return end
    local player = GLOBAL.ThePlayer
    if not player or not player.HUD then return end
    if GLOBAL.TheFrontEnd:GetActiveScreen() ~= player.HUD then return end

    local target = GLOBAL.TheInput:GetWorldEntityUnderMouse()
    if target and target:HasTag("lookouttower") then
        -- Tell the server. Server adds to shared list, saves, and broadcasts back.
        SendModRPCToServer(MOD_RPC["MysteryBox"]["DiscoverTower"], target)
        GLOBAL.TheFrontEnd:PushScreen(TowerNetworkScreen(player, target))
    end
end)

-- =============================================================================
-- HIDE OVERHEAD CLOUDS
-- =============================================================================
-- Clouds obstruct the view at high camera zoom. We permanently hide any
-- cloud-ish entities on the world so scout mode stays clear.

local function IsCloudPrefab(name)
    if not name then return false end
    return string.find(name, "cloud") ~= nil
        or string.find(name, "skybox") ~= nil
end

local function HideCloudEntity(inst)
    if not inst or not inst.entity then return end
    if inst.Hide then inst:Hide() end
    if inst.AnimState then
        inst.AnimState:SetMultColour(0, 0, 0, 0)
    end
end

-- Known cloud-ish prefabs — if any of these don't exist in the game, the
-- hook is a no-op, so it's safe to over-include.
local CLOUD_PREFABS = {
    "clouds",
    "cloud",
    "cloudshadow",
    "cloud_shadow",
    "cloudshadow_fx",
    "skycloud",
    "ocean_cloud",
    "oceancloud",
    "cloudmarker",
}
for _, name in ipairs(CLOUD_PREFABS) do
    AddPrefabPostInit(name, HideCloudEntity)
end

-- Sweep any cloud entities that already exist on world init (catches things
-- the prefab hook missed).
AddPrefabPostInit("world", function(world)
    world:DoTaskInTime(2, function()
        for _, ent in pairs(GLOBAL.Ents) do
            if ent and ent.prefab and IsCloudPrefab(ent.prefab) then
                HideCloudEntity(ent)
            end
        end
    end)
end)

-- =============================================================================
-- BIOME OUTLINE REVEAL
-- =============================================================================
-- Given a player and a world position, reveal the outline of the topology
-- node (biome) at that position on the map. Falls back to a large circle
-- reveal if topology data isn't available.

local function RevealBiomeOutline(player, x, z)
    if not player or not player.player_classified then return end
    local explorer = player.player_classified.MapExplorer
    if not explorer then return end

    local world = GLOBAL.TheWorld
    local map = world and world.Map
    local topology = world and world.topology
    if not map or not topology or not topology.nodes then
        explorer:RevealArea(x, 0, z, 120)
        return
    end

    local node_id = map:GetNodeIdAtPoint(x, 0, z)
    local node = node_id and topology.nodes[node_id]
    local poly = node and node.poly

    if not poly or #poly < 2 then
        explorer:RevealArea(x, 0, z, 120)
        return
    end

    local function GetXZ(p)
        return p[1] or p.x, p[2] or p.y or p.z
    end

    -- Reveal along each polygon edge so the outline is contiguous.
    local STEP = 12
    local RADIUS = 20
    for i = 1, #poly do
        local a = poly[i]
        local b = poly[(i % #poly) + 1]
        local ax, az = GetXZ(a)
        local bx, bz = GetXZ(b)
        if ax and az and bx and bz then
            local dx, dz = bx - ax, bz - az
            local dist = math.sqrt(dx * dx + dz * dz)
            local steps = math.max(1, math.ceil(dist / STEP))
            for s = 0, steps do
                local t = s / steps
                explorer:RevealArea(ax + dx * t, 0, az + dz * t, RADIUS)
            end
        end
    end
end

GLOBAL.MysteryBox_RevealBiomeOutline = RevealBiomeOutline

-- =============================================================================
-- BIOME FILL REVEAL
-- =============================================================================
-- Reveals the full interior of the biome (all topology nodes sharing the
-- prefix of the node at the tower's position), not just the outline. The
-- work is spread across frames so a large biome doesn't stall the sim.

local function RevealBiomeFill(player, x, z)
    if not player or not player.player_classified then return end
    local explorer = player.player_classified.MapExplorer
    if not explorer then return end

    local world = GLOBAL.TheWorld
    local map = world and world.Map
    local topology = world and world.topology
    if not map or not topology or not topology.nodes or not topology.ids then
        explorer:RevealArea(x, 0, z, 120)
        return
    end

    local node_id = map:GetNodeIdAtPoint(x, 0, z)
    if not node_id then
        explorer:RevealArea(x, 0, z, 120)
        return
    end

    local this_room = topology.ids[node_id]
    local this_prefix = this_room and this_room:match("^([^:]+)")
    if not this_prefix then
        explorer:RevealArea(x, 0, z, 120)
        return
    end

    -- Only include nodes sharing the biome prefix AND within MAX_RANGE of
    -- the tower (avoids revealing every distant same-biome patch on huge
    -- worlds, which keeps the work bounded).
    local MAX_RANGE = 600
    local MAX_RANGE_SQ = MAX_RANGE * MAX_RANGE
    local target_indices = {}
    for i, room in ipairs(topology.ids) do
        local prefix = room and room:match("^([^:]+)")
        if prefix == this_prefix then
            local n = topology.nodes[i]
            local cent = n and (n.cent or (n.x and {n.x, n.y}))
            if cent then
                local dx = (cent[1] or n.x or 0) - x
                local dz = (cent[2] or n.y or 0) - z
                if dx*dx + dz*dz <= MAX_RANGE_SQ then
                    target_indices[i] = n
                end
            else
                target_indices[i] = n
            end
        end
    end

    local function GetXZ(p)
        return p[1] or p.x, p[2] or p.y or p.z
    end

    -- Build a queue of (node_index, bbox) tuples to process across frames.
    local queue = {}
    for idx, node in pairs(target_indices) do
        local poly = node.poly
        if poly and #poly >= 3 then
            local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
            for _, p in ipairs(poly) do
                local px, pz = GetXZ(p)
                if px and pz then
                    if px < minX then minX = px end
                    if px > maxX then maxX = px end
                    if pz < minZ then minZ = pz end
                    if pz > maxZ then maxZ = pz end
                end
            end
            if minX < maxX and minZ < maxZ then
                table.insert(queue, {idx = idx, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ})
            end
        end
    end

    if #queue == 0 then
        explorer:RevealArea(x, 0, z, 120)
        return
    end

    local STEP = 15
    local RADIUS = 22
    local BUDGET_PER_TICK = 150  -- GetNodeIdAtPoint calls per frame

    -- Capture state for the coroutine-style stepper
    local q_i = 1
    local cur_x = queue[1].minX
    local cur_z = queue[1].minZ

    local function Step()
        if not player:IsValid() or not explorer then return end
        local work = 0
        while work < BUDGET_PER_TICK do
            if q_i > #queue then return end  -- done
            local entry = queue[q_i]

            if map:GetNodeIdAtPoint(cur_x, 0, cur_z) == entry.idx then
                explorer:RevealArea(cur_x, 0, cur_z, RADIUS)
            end
            work = work + 1

            cur_x = cur_x + STEP
            if cur_x > entry.maxX then
                cur_x = entry.minX
                cur_z = cur_z + STEP
                if cur_z > entry.maxZ then
                    q_i = q_i + 1
                    if q_i <= #queue then
                        cur_x = queue[q_i].minX
                        cur_z = queue[q_i].minZ
                    end
                end
            end
        end
        -- More work; schedule another tick
        player:DoTaskInTime(0, Step)
    end

    Step()
end

GLOBAL.MysteryBox_RevealBiomeFill = RevealBiomeFill

-- Reveal coastlines (land/water boundaries) near a position
local function RevealCoastlineNear(player, cx, cz, radius)
    if not player or not player.player_classified then return end
    local explorer = player.player_classified.MapExplorer
    if not explorer then return end

    local world = GLOBAL.TheWorld
    local map = world and world.Map
    if not map then return end

    local STEP = 4  -- finer grid for cleaner shorelines
    local REVEAL_RADIUS = 14
    local count = 0

    local neighbors = {
        {STEP, 0}, {-STEP, 0}, {0, STEP}, {0, -STEP},
        {STEP, STEP}, {STEP, -STEP}, {-STEP, STEP}, {-STEP, -STEP},
    }

    local function IsOcean(tile)
        return tile == GLOBAL.WORLD_TILES.OCEAN_COASTAL
            or tile == GLOBAL.WORLD_TILES.OCEAN_SWELL
            or tile == GLOBAL.WORLD_TILES.OCEAN_ROUGH
            or tile == GLOBAL.WORLD_TILES.OCEAN_BRINEPOOL
            or tile == GLOBAL.WORLD_TILES.OCEAN_HAZARDOUS
            or tile == GLOBAL.WORLD_TILES.OCEAN_WATERLOG
            or (tile and tostring(tile):find("OCEAN"))
    end

    local function IsLand(tile)
        return tile and tile ~= GLOBAL.WORLD_TILES.IMPASSABLE and not IsOcean(tile)
    end

    for x = cx - radius, cx + radius, STEP do
        for z = cz - radius, cz + radius, STEP do
            local dist = math.sqrt((x - cx)^2 + (z - cz)^2)
            if dist <= radius then
                local tile = map:GetTileAtPoint(x, 0, z)
                if IsOcean(tile) then
                    -- 8-way neighbor check; reveal both ocean and land side
                    -- so the shoreline has thickness and aligns with the edge.
                    for _, offset in ipairs(neighbors) do
                        local nx, nz = x + offset[1], z + offset[2]
                        if IsLand(map:GetTileAtPoint(nx, 0, nz)) then
                            explorer:RevealArea(x, 0, z, REVEAL_RADIUS)
                            explorer:RevealArea(nx, 0, nz, REVEAL_RADIUS)
                            count = count + 1
                            break
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        Log("Revealed " .. count .. " coastline points")
    end
end

GLOBAL.MysteryBox_RevealCoastlineNear = RevealCoastlineNear

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
                tower:AddTag("biome_" .. prefix)
                local displayName = NameTower(tower, prefix)

                spawned = spawned + 1
                Log("Tower #" .. spawned .. ": " .. displayName .. " at (" .. math.floor(x) .. ", " .. math.floor(z) .. ")")
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

-- Discovery is interaction-driven: right-click or activating a tower routes
-- through MysteryBox_DiscoverTowerServer, which saves and broadcasts.

-- Log successful initialization
Log("Mod initialized successfully!")
Log("Lookout Tower system loaded!")
