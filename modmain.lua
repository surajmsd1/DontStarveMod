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

-- Load event data from external file
local EventData = require "events/event_data"
local SIMPLE_EVENTS = EventData.SIMPLE_EVENTS
local TIMED_EVENTS = EventData.TIMED_EVENTS
local WAVE_EVENTS = EventData.WAVE_EVENTS
local SPECIAL_EVENTS = EventData.SPECIAL_EVENTS

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

        -- Store reference globally for prefabs to access (use _G for prefab compatibility)
        _G.MysteryBoxEventManager = EventManager
        GLOBAL.MysteryBoxEventManager = EventManager

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
-- SCOUT MODE DROP-IN ACTION
-- =============================================================================

-- Add custom action for dropping in from scout mode
local SCOUT_DROP_ACTION = GLOBAL.Action({
    priority = 10,
    instant = true,
})
SCOUT_DROP_ACTION.id = "SCOUT_DROP"
SCOUT_DROP_ACTION.str = "Drop In"
SCOUT_DROP_ACTION.fn = function(act)
    local doer = act.doer
    if doer and doer:HasTag("scouting") then
        -- Call the exit function from the tower
        local tower = doer._scout_tower
        if tower and tower:IsValid() then
            -- Exit scout mode, staying at current position (not teleporting back)
            -- We need to access the ExitScoutMode function - it's defined in the prefab
            -- For now, we'll duplicate the exit logic here

            -- Stop map reveal task
            if doer._scout_reveal_task then
                doer._scout_reveal_task:Cancel()
                doer._scout_reveal_task = nil
            end

            -- Restore speed
            doer.components.locomotor.runspeed = doer._scout_original_speed or 8
            doer.components.locomotor.walkspeed = doer._scout_original_walkspeed or 4

            -- Restore health
            if doer.components.health then
                doer.components.health:SetInvincible(false)
            end

            -- Restore hunger/sanity
            if doer.components.hunger and doer._scout_hunger_rate then
                doer.components.hunger.hungerrate = doer._scout_hunger_rate
            end
            if doer.components.sanity and doer._scout_sanity_mode then
                doer.components.sanity.mode = doer._scout_sanity_mode
            end

            -- Restore combat
            if doer.components.combat and doer._scout_combat_enabled then
                doer.components.combat:SetAttackPeriod(0.5)
            end

            -- Restore visual
            doer.AnimState:SetMultColour(1, 1, 1, 1)

            -- Remove tags
            doer:RemoveTag("scouting")
            doer:RemoveTag("notarget")

            -- CLIENT-SIDE: Remove overlay and restore camera
            if doer._scout_overlay then
                doer._scout_overlay:Kill()
                doer._scout_overlay = nil
            end
            if doer._scout_original_zoom and GLOBAL.TheCamera and GLOBAL.TheCamera.SetDistance then
                GLOBAL.TheCamera:SetDistance(doer._scout_original_zoom)
                doer._scout_original_zoom = nil
            end

            -- Announce
            if doer.components.talker then
                doer.components.talker:Say("Dropped in!")
            end

            -- Play drop sound
            doer.SoundEmitter:PlaySound("dontstarve/common/teleportato/teleportato_pulled")

            -- Deactivate tower
            tower.AnimState:PlayAnimation("idle_off", true)
            tower.SoundEmitter:KillSound("loop")
            tower.scout_active = false
            tower.scout_player = nil

            -- Clear stored values
            doer._scout_original_speed = nil
            doer._scout_original_walkspeed = nil
            doer._scout_original_pos = nil
            doer._scout_tower = nil
            doer._scout_hunger_rate = nil
            doer._scout_sanity_mode = nil
            doer._scout_combat_enabled = nil

            Log("Scout mode: Player dropped in at current location")
            return true
        end
    end
    return false
end

-- Register the action
AddAction(SCOUT_DROP_ACTION)

-- Add action handler to players
AddComponentAction("SCENE", "locomotor", function(inst, doer, actions, right)
    -- When scouting and pressing action key, offer drop-in option
    if doer and doer:HasTag("scouting") and not right then
        table.insert(actions, GLOBAL.ACTIONS.SCOUT_DROP)
    end
end)

-- Also allow pressing space anywhere while scouting
AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.SCOUT_DROP, "doshortaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.SCOUT_DROP, "doshortaction"))

-- =============================================================================
-- LOOKOUT TOWER SYSTEM (Auto-spawned, unlocked by chests)
-- =============================================================================

-- Track which branches have unlocked towers
local UnlockedBranches = {}

-- Cache of towers by branch_id for fast lookup (avoids FindEntities)
local TowerCache = {}

-- Get the branch/node ID at a position
local function GetBranchAtPosition(x, z)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.Map then
        local node_id = GLOBAL.TheWorld.Map:GetNodeIdAtPoint(x, 0, z)
        if node_id and GLOBAL.TheWorld.topology and GLOBAL.TheWorld.topology.ids then
            local room_name = GLOBAL.TheWorld.topology.ids[node_id]
            return node_id, room_name
        end
        return node_id, nil
    end
    return nil, nil
end

-- Unlock tower in a branch when chest is opened
local function UnlockBranchTower(branch_id)
    if branch_id and not UnlockedBranches[branch_id] then
        UnlockedBranches[branch_id] = true
        Log("Branch " .. tostring(branch_id) .. " tower UNLOCKED!")

        -- Use cached tower reference (fast) instead of FindEntities (slow)
        local tower = TowerCache[branch_id]
        if tower and tower:IsValid() and tower.Unlock then
            tower:Unlock()
            GLOBAL.TheNet:Announce("A Lookout Tower has been unlocked!")
        else
            -- Fallback: clear invalid cache entry
            TowerCache[branch_id] = nil
            Log("WARNING: Tower for branch " .. tostring(branch_id) .. " not found in cache")
        end
    end
end

-- Called when any mystery box is opened - unlock the branch tower
local function OnChestOpened(player)
    if player then
        local x, y, z = player.Transform:GetWorldPosition()
        local branch_id, room_name = GetBranchAtPosition(x, z)
        Log("Chest opened in branch: " .. tostring(branch_id) .. " (" .. tostring(room_name) .. ")")
        if branch_id then
            UnlockBranchTower(branch_id)
        end
    end
end

-- Get list of all unlocked towers for teleportation UI
local function GetUnlockedTowers(currentTower)
    local towers = {}
    for branch_id, tower in pairs(TowerCache) do
        if tower and tower:IsValid() and not tower._net_is_locked:value() then
            local room_name = nil
            if GLOBAL.TheWorld.topology and GLOBAL.TheWorld.topology.ids then
                room_name = GLOBAL.TheWorld.topology.ids[branch_id]
            end
            local x, y, z = tower.Transform:GetWorldPosition()
            table.insert(towers, {
                tower = tower,
                branch_id = branch_id,
                room_name = room_name,
                position = {x = x, y = y, z = z},
                isCurrentTower = (currentTower and currentTower == tower),
            })
        end
    end
    return towers
end

-- Teleport player to a tower
local function TeleportToTower(player, targetTower)
    if not player or not player:IsValid() then return false end
    if not targetTower or not targetTower:IsValid() then return false end

    local x, y, z = targetTower.Transform:GetWorldPosition()

    -- Play teleport effects
    if player.SoundEmitter then
        player.SoundEmitter:PlaySound("dontstarve/common/teleportato/teleportato_pulled")
    end

    -- Spawn visual effect at origin
    local fx = GLOBAL.SpawnPrefab("collapse_small")
    if fx then
        local px, py, pz = player.Transform:GetWorldPosition()
        fx.Transform:SetPosition(px, py, pz)
    end

    -- Teleport
    player.Transform:SetPosition(x + 1, 0, z + 1)  -- Offset slightly from tower

    -- Spawn visual effect at destination
    local fx2 = GLOBAL.SpawnPrefab("collapse_small")
    if fx2 then
        fx2.Transform:SetPosition(x + 1, 0, z + 1)
    end

    -- Play arrival sound
    if player.SoundEmitter then
        player.SoundEmitter:PlaySound("dontstarve/common/teleportato/teleportato_ready")
    end

    Log("Teleported " .. tostring(player) .. " to tower at branch " .. tostring(targetTower._branch_id))
    return true
end

-- Expose functions globally for tower prefab to use
_G.MysteryBoxGetUnlockedTowers = GetUnlockedTowers
_G.MysteryBoxTeleportToTower = TeleportToTower
GLOBAL.MysteryBoxGetUnlockedTowers = GetUnlockedTowers
GLOBAL.MysteryBoxTeleportToTower = TeleportToTower

-- Make this function accessible to prefabs
_G.MysteryBoxOnChestOpened = OnChestOpened
GLOBAL.MysteryBoxOnChestOpened = OnChestOpened

-- Check if a branch tower is unlocked
local function IsBranchUnlocked(branch_id)
    return UnlockedBranches[branch_id] == true
end

_G.MysteryBoxIsBranchUnlocked = IsBranchUnlocked
GLOBAL.MysteryBoxIsBranchUnlocked = IsBranchUnlocked

-- =============================================================================
-- AUTO-SPAWN TOWERS AT BRANCH ENTRANCES
-- =============================================================================

local function SpawnBranchTowers(world)
    if not world.ismastersim then return end

    Log("Spawning Lookout Towers at branch entrances...")

    local topology = GLOBAL.TheWorld.topology
    if not topology or not topology.nodes then
        Log("WARNING: No topology data available for tower spawning")
        return
    end

    -- Find nodes that are "entrance" points to branches
    -- Branches are typically rooms connected to fewer other rooms (peninsulas)
    -- For now, spawn one tower per distinct room type in the first node of each type

    local spawned_rooms = {}
    local tower_count = 0

    for i, node in ipairs(topology.nodes) do
        local room_name = topology.ids and topology.ids[i]

        -- Skip if we already spawned in this room type or if it's a common area
        if room_name and not spawned_rooms[room_name] then
            -- Skip very common/central areas
            local skip_rooms = {
                "Clearing", "Forest", "Grasslands", "Savanna",
                "START", "BeefalowPlains", "Marsh"
            }
            local should_skip = false
            for _, skip in ipairs(skip_rooms) do
                if string.find(room_name, skip) then
                    should_skip = true
                    break
                end
            end

            if not should_skip and node.cent then
                -- Spawn tower at node center
                local x, z = node.cent[1], node.cent[2]

                -- Find valid ground position
                local spawn_x, spawn_z = x, z
                if GLOBAL.TheWorld.Map:IsAboveGroundAtPoint(x, 0, z) then
                    local tower = GLOBAL.SpawnPrefab("lookouttower")
                    if tower then
                        tower.Transform:SetPosition(spawn_x, 0, spawn_z)
                        tower._branch_id = i  -- Store which branch this tower is for
                        -- Auto-spawned towers start LOCKED (uses network sync for visual)
                        tower:SetLocked(true)
                        -- Cache tower reference for fast lookup
                        TowerCache[i] = tower
                        tower_count = tower_count + 1
                        spawned_rooms[room_name] = true
                        LogVerbose("Spawned LOCKED tower at " .. room_name .. " (" .. spawn_x .. ", " .. spawn_z .. ")")
                    end
                end
            end
        end
    end

    Log("Spawned " .. tower_count .. " Lookout Towers across the map")
end

-- Hook into world initialization to spawn towers
AddPrefabPostInit("forest", function(world)
    if world.ismastersim then
        -- Delay tower spawning until world is fully loaded
        world:DoTaskInTime(2, function()
            SpawnBranchTowers(world)
        end)
    end
end)

-- =============================================================================
-- LOOKOUT TOWER CRAFTING RECIPE (Alternative to finding spawned towers)
-- =============================================================================

local tower_recipe = GLOBAL.Recipe(
    "lookouttower",
    {GLOBAL.Ingredient("boards", 4), GLOBAL.Ingredient("goldnugget", 2), GLOBAL.Ingredient("rope", 2)},
    GLOBAL.RECIPETABS.TOWN,
    GLOBAL.TECH.SCIENCE_ONE
)
tower_recipe.atlas = "images/inventoryimages.xml"

-- =============================================================================
-- MISSION TRACKING SYSTEM
-- =============================================================================

local MissionTracker = require "systems/mission_tracker"
local MissionDefs = require "systems/mission_defs"

-- Server-side mission tracker (set during world init)
local MissionTrackerInstance = nil

-- Sync interval for pushing mission data to clients
local MISSION_SYNC_INTERVAL = 1.0

-- =============================================================================
-- MISSION DATA SERIALIZATION (compact string format, no json dependency)
-- =============================================================================

-- Encode mission snapshot to compact string
-- Delimiters (each level uses a unique separator):
--   Missions separated by "\n"
--   Mission fields separated by "\t"
--   Objectives separated by ";"
--   Objective fields separated by ","
--   Recent section separated from missions by "\n\n"
local function EncodeMissions(snapshot, recent)
    local parts = {}

    for _, m in ipairs(snapshot or {}) do
        local objParts = {}
        for _, obj in ipairs(m.objectives or {}) do
            table.insert(objParts, table.concat({
                (obj.label or ""):gsub(",", " "),  -- sanitize
                obj.type or "",
                tostring(obj.current or 0),
                tostring(obj.required or 1),
                obj.completed and "1" or "0",
            }, ","))
        end

        local bossStr = ""
        if m.boss_health then
            bossStr = tostring(math.floor(m.boss_health.current or 0))
                .. ":" .. tostring(math.floor(m.boss_health.max or 0))
        end

        table.insert(parts, table.concat({
            m.id or "",
            (m.name or ""):gsub("\t", " "),  -- sanitize
            m.category or "",
            tostring(math.floor(m.time_remaining or -1)),
            bossStr,
            table.concat(objParts, ";"),
        }, "\t"))
    end

    -- Recent finished missions
    local recentParts = {}
    for _, r in ipairs(recent or {}) do
        table.insert(recentParts, table.concat({
            r.id or "",
            (r.name or ""):gsub("\t", " "),
            r.state or "",
        }, "\t"))
    end

    return table.concat(parts, "\n") .. "\n\n" .. table.concat(recentParts, "\n")
end

-- Decode compact mission string back into table structure (client-side)
local function DecodeMissions(dataStr)
    if not dataStr or dataStr == "" then
        return {}, {}
    end

    -- Split main missions from recent section
    local mainPart, recentPart = dataStr:match("^(.-)\n\n(.*)$")
    if not mainPart then
        mainPart = dataStr
        recentPart = ""
    end

    -- Split string by delimiter, preserving empty fields
    local function splitStr(str, delim)
        local result = {}
        local pattern = "([^" .. delim .. "]*)" .. delim .. "?"
        local lastEnd = 1
        for part, pos in str:gmatch("([^" .. delim .. "]*)" .. delim .. "()") do
            table.insert(result, part)
            lastEnd = pos
        end
        -- Get the last field
        table.insert(result, str:sub(lastEnd))
        return result
    end

    local missions = {}
    if mainPart ~= "" then
        for missionStr in mainPart:gmatch("[^\n]+") do
            local fields = splitStr(missionStr, "\t")

            -- fields: 1=id, 2=name, 3=category, 4=time_rem, 5=boss, 6=objectives
            if #fields >= 5 then
                local mission = {
                    id = fields[1],
                    name = fields[2],
                    category = fields[3],
                    objectives = {},
                }

                local timeRem = tonumber(fields[4])
                if timeRem and timeRem >= 0 then
                    mission.time_remaining = timeRem
                end

                -- Boss health
                if fields[5] ~= "" then
                    local bCur, bMax = fields[5]:match("^(%d+):(%d+)$")
                    if bCur and bMax then
                        mission.boss_health = {
                            current = tonumber(bCur),
                            max = tonumber(bMax),
                        }
                    end
                end

                -- Objectives (field 6, separated by ";")
                if fields[6] and fields[6] ~= "" then
                    for objData in fields[6]:gmatch("[^;]+") do
                        local objFields = {}
                        for f in objData:gmatch("[^,]+") do
                            table.insert(objFields, f)
                        end
                        if #objFields >= 5 then
                            table.insert(mission.objectives, {
                                label = objFields[1],
                                type = objFields[2],
                                current = tonumber(objFields[3]) or 0,
                                required = tonumber(objFields[4]) or 1,
                                completed = objFields[5] == "1",
                            })
                        end
                    end
                end

                table.insert(missions, mission)
            end
        end
    end

    -- Decode recent
    local recent = {}
    if recentPart and recentPart ~= "" then
        for rStr in recentPart:gmatch("[^\n]+") do
            local rFields = {}
            for f in rStr:gmatch("[^\t]+") do
                table.insert(rFields, f)
            end
            if #rFields >= 3 then
                table.insert(recent, {
                    id = rFields[1],
                    name = rFields[2],
                    state = rFields[3],
                })
            end
        end
    end

    return missions, recent
end

-- RPC: Client requests full mission data refresh
AddModRPCHandler("mysterybox", "request_missions", function(player)
    if not MissionTrackerInstance then return end
    local snapshot = MissionTrackerInstance:GetMissionSnapshot()
    local recent = MissionTrackerInstance:GetRecentFinished()
    local data = EncodeMissions(snapshot, recent)
    SendModRPCToClient(GetClientModRPC("mysterybox", "mission_sync"), player.userid, data)
end)

-- Client RPC: Receive mission data from server
AddClientModRPCHandler("mysterybox", "mission_sync", function(data_str)
    local ok, result1, result2 = GLOBAL.pcall(DecodeMissions, data_str)
    if ok then
        local player = GLOBAL.ThePlayer
        if player and player._mission_panel then
            player._mission_panel:SetMissions(result1, result2)
        end
    else
        LogVerbose("ERROR decoding mission data: " .. tostring(result1))
    end
end)

-- Server: Broadcast mission data to all clients
local function BroadcastMissionData()
    if not MissionTrackerInstance then return end
    local snapshot = MissionTrackerInstance:GetMissionSnapshot()
    local recent = MissionTrackerInstance:GetRecentFinished()
    local data = EncodeMissions(snapshot, recent)
    for _, player in ipairs(GLOBAL.AllPlayers or {}) do
        if player and player:IsValid() then
            SendModRPCToClient(GetClientModRPC("mysterybox", "mission_sync"), player.userid, data)
        end
    end
end

-- Initialize mission tracker when world loads (server-side)
local function InitMissionTracker(world)
    if not world.ismastersim then return end

    MissionTrackerInstance = MissionTracker.Create(world)

    -- When tracker data changes, broadcast to all clients
    MissionTrackerInstance:OnUpdate(function(mission_id, mission_data)
        BroadcastMissionData()
    end)

    -- Track item pickups across all players
    local function SetupPlayerTracking(player)
        player:ListenForEvent("itemget", function(player, data)
            if MissionTrackerInstance and data and data.item then
                MissionTrackerInstance:OnItemCollected(data.item.prefab, 1)
            end
        end)

        -- Track kills
        player:ListenForEvent("killed", function(player, data)
            if MissionTrackerInstance and data and data.victim then
                MissionTrackerInstance:OnEntityKilled(data.victim.prefab)
            end
        end)

        -- Track structure building
        player:ListenForEvent("buildstructure", function(player, data)
            if MissionTrackerInstance and data and data.item then
                MissionTrackerInstance:OnStructureBuilt(data.item.prefab)
            end
        end)
    end

    -- Set up tracking for existing players
    for _, player in ipairs(GLOBAL.AllPlayers or {}) do
        SetupPlayerTracking(player)
    end

    -- Set up tracking for new players who join
    world:ListenForEvent("ms_playerjoined", function(world, player)
        if player then
            SetupPlayerTracking(player)
            -- Send current mission state to new player
            world:DoTaskInTime(2, function()
                if player:IsValid() then
                    BroadcastMissionData()
                end
            end)
        end
    end)

    -- Periodic sync to keep timers and boss health updated
    world:DoPeriodicTask(MISSION_SYNC_INTERVAL, function()
        BroadcastMissionData()
    end)

    -- Store globally for console/event access
    _G.MysteryBoxMissionTracker = MissionTrackerInstance
    GLOBAL.MysteryBoxMissionTracker = MissionTrackerInstance

    Log("Mission Tracker initialized!")
end

-- Start a mission by definition ID (convenience function for events/console)
local function StartMission(def_or_id)
    if not MissionTrackerInstance then
        Log("ERROR: MissionTracker not initialized")
        return false
    end

    local def = def_or_id
    if type(def_or_id) == "string" then
        def = MissionDefs[def_or_id]
        if not def then
            Log("ERROR: Unknown mission: " .. def_or_id)
            return false
        end
    end

    local success = MissionTrackerInstance:StartMission(def)

    -- Handle boss spawn on start
    if success and def.on_start_spawn then
        local spawn = def.on_start_spawn
        local player = GetRandomPlayer()
        if player then
            local x, y, z = player.Transform:GetWorldPosition()
            local count = spawn.count or 1

            if spawn.announce and GLOBAL.TheNet then
                GLOBAL.TheNet:Announce(spawn.announce)
            end

            for i = 1, count do
                local boss = GLOBAL.SpawnPrefab(spawn.prefab)
                if boss then
                    local angle = math.random() * 2 * math.pi
                    local dist = 15 + math.random() * 10
                    boss.Transform:SetPosition(
                        x + math.cos(angle) * dist, 0,
                        z + math.sin(angle) * dist
                    )
                    -- Track first boss entity for UI health bar
                    if i == 1 then
                        MissionTrackerInstance:SetBossEntity(def.id, boss)
                    end
                    Log("Spawned boss: " .. spawn.prefab)
                end
            end
        end
    end

    return success
end

-- Start a random mission (optionally filtered by category)
local function StartRandomMission(category)
    local def = MissionDefs.GetRandom(category)
    if def then
        return StartMission(def)
    end
    Log("No missions available" .. (category and (" for category: " .. category) or ""))
    return false
end

-- Expose mission functions globally
_G.MysteryBoxStartMission = StartMission
GLOBAL.MysteryBoxStartMission = StartMission
_G.MysteryBoxStartRandomMission = StartRandomMission
GLOBAL.MysteryBoxStartRandomMission = StartRandomMission

-- Hook mission tracker into world initialization
AddPrefabPostInit("world", function(world)
    GLOBAL.pcall(function()
        if GLOBAL.TheWorld.ismastersim then
            world:DoTaskInTime(1, function()
                InitMissionTracker(world)
            end)
        end
    end)
end)

-- =============================================================================
-- MISSION PANEL UI (Client-side HUD widget)
-- =============================================================================

-- Attach mission panel to each player's HUD
AddClassPostConstruct("widgets/controls", function(self)
    -- Wait for owner to be set
    self.inst:DoTaskInTime(0, function()
        local owner = self.owner
        if not owner then return end

        local MissionPanel = require "widgets/missionpanel"
        local panel = self:AddChild(MissionPanel(owner))
        owner._mission_panel = panel

        -- Request initial mission data from server
        self.inst:DoTaskInTime(1, function()
            SendModRPCToServer(GetModRPC("mysterybox", "request_missions"))
        end)

        Log("Mission panel attached to HUD")
    end)
end)

-- Log successful initialization
Log("Mod initialized successfully!")
Log("DnD Gamemaster mode enabled - daily and weekly events active!")
Log("Lookout Tower feature enabled!")
Log("Mission Tracking UI enabled!")
