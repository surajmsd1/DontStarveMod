-- Mystery Box Mod - Main Entry Point
-- DnD Gamemaster style mod that triggers daily/weekly events with rewards and dangers

-- Safer logging function
local function Log(msg)
    print("[Mystery Box] " .. tostring(msg))
end

Log("Mod loading...")

-- Register all box prefabs
PrefabFiles = {
    "mysterybox",
    "cursedbox",
    "goldenbox",
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
        Log("Registered event: " .. event.id)
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
        if not eventList or #eventList == 0 then return nil end
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
                return event
            end
        end
        return eventList[1]
    end

    function mgr:AnnounceToAll(message)
        if GLOBAL.TheNet and GLOBAL.TheNet.Announce then
            GLOBAL.TheNet:Announce(message)
        end
        Log("ANNOUNCEMENT: " .. message)
    end

    function mgr:ExecuteEvent(event, target)
        if not event then return false end
        Log("Triggering event: " .. event.name)

        local ok, err = GLOBAL.pcall(function()
            local announcement = event.GetAnnouncement and event:GetAnnouncement()
            if announcement and announcement ~= "" then
                self:AnnounceToAll(announcement)
            end
            if event.Execute then
                event:Execute(self.world, target)
            end
        end)

        if not ok then
            Log("ERROR executing event: " .. tostring(err))
        end
        return ok
    end

    function mgr:TriggerRandomEvent(triggerType, target)
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
        if currentDay <= self.lastDayProcessed then return end
        self.lastDayProcessed = currentDay
        Log("Day " .. currentDay .. " has begun!")
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
        local eventList = nil
        if boxType == "cursed" then
            eventList = {}
            for _, e in ipairs(self.eventsByCategory[EVENT_CATEGORY.CHALLENGE] or {}) do
                table.insert(eventList, e)
            end
            for _, e in ipairs(self.eventsByCategory[EVENT_CATEGORY.BOSS] or {}) do
                table.insert(eventList, e)
            end
        elseif boxType == "golden" then
            eventList = {}
            for _, e in ipairs(self.eventsByCategory[EVENT_CATEGORY.REWARD] or {}) do
                table.insert(eventList, e)
            end
            for _, e in ipairs(self.eventsByCategory[EVENT_CATEGORY.SOCIAL] or {}) do
                table.insert(eventList, e)
            end
        else
            eventList = self.eventsByTrigger[EVENT_TRIGGER.MANUAL]
        end

        if not eventList or #eventList == 0 then
            Log("No events for box type: " .. tostring(boxType))
            return false
        end

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

    return mgr
end

-- Helper functions for events
local function GetRandomPlayer()
    local players = GLOBAL.AllPlayers or {}
    if #players == 0 then return nil end
    return players[math.random(#players)]
end

local function SpawnNear(prefab, x, z, radius)
    local entity = GLOBAL.SpawnPrefab(prefab)
    if entity then
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * radius
        entity.Transform:SetPosition(x + math.cos(angle) * dist, 0, z + math.sin(angle) * dist)
    end
    return entity
end

-- Register all events
local function RegisterAllEvents(mgr)
    -- Daily Gift (Reward)
    mgr:RegisterEvent({
        id = "daily_gift",
        name = "Daily Gift",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "The spirits have left a small gift..." end,
        Execute = function(self, world, target)
            local player = GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            local gifts = {"goldnugget", "silk", "rope", "boards"}
            SpawnNear(gifts[math.random(#gifts)], x, z, 3)
        end,
    })

    -- Weekly Treasure (Reward)
    mgr:RegisterEvent({
        id = "weekly_treasure",
        name = "Weekly Treasure",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.WEEKLY,
        GetAnnouncement = function() return "A week survived! Treasure appears!" end,
        Execute = function(self, world, target)
            local player = GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            SpawnNear("mysterybox", x, z, 5)
            SpawnNear("redgem", x, z, 3)
            SpawnNear("bluegem", x, z, 3)
        end,
    })

    -- Spider Ambush (Challenge)
    mgr:RegisterEvent({
        id = "spider_ambush",
        name = "Spider Ambush!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "WARNING: Spiders emerging! Gear nearby..." end,
        Execute = function(self, world, target)
            local player = GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            for i = 1, math.random(5, 8) do SpawnNear("spider", x, z, 8) end
            SpawnNear("spear", x + 10, z + 10, 2)
            SpawnNear("armorwood", x + 10, z + 10, 2)
        end,
    })

    -- Hound Wave (Challenge)
    mgr:RegisterEvent({
        id = "hound_wave",
        name = "Hound Wave!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "DANGER: Hounds approach with gems!" end,
        Execute = function(self, world, target)
            local player = GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            for i = 1, math.random(3, 5) do SpawnNear("hound", x, z, 10) end
            for i = 1, 3 do SpawnNear("goldnugget", x - 8, z - 8, 3) end
        end,
    })

    -- Butterfly Bonanza (Reward)
    mgr:RegisterEvent({
        id = "butterfly_bonanza",
        name = "Butterfly Bonanza!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "BONUS: Butterflies everywhere!" end,
        Execute = function(self, world, target)
            local player = GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            for i = 1, 15 do SpawnNear("butterfly", x, z, 12) end
            SpawnNear("bugnet", x, z, 2)
        end,
    })

    -- Pig Party (Social)
    mgr:RegisterEvent({
        id = "pig_party",
        name = "Pig Party!",
        category = EVENT_CATEGORY.SOCIAL,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "FRIENDS: Pigs want to party!" end,
        Execute = function(self, world, target)
            for _, player in ipairs(GLOBAL.AllPlayers or {}) do
                local x, y, z = player.Transform:GetWorldPosition()
                for i = 1, 2 do SpawnNear("pigman", x, z, 5) end
            end
        end,
    })

    -- Treasure Hunt (Reward)
    mgr:RegisterEvent({
        id = "treasure_hunt",
        name = "Treasure Hunt!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "TREASURE HUNT! A box appeared somewhere!" end,
        Execute = function(self, world, target)
            local player = GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            local angle = math.random() * 2 * math.pi
            local dist = 50 + math.random() * 30
            SpawnNear("mysterybox", x + math.cos(angle) * dist, z + math.sin(angle) * dist, 5)
        end,
    })

    -- Mini-Boss Warning (Boss)
    mgr:RegisterEvent({
        id = "miniboss_warning",
        name = "Mini-Boss Incoming!",
        category = EVENT_CATEGORY.BOSS,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.WEEKLY,
        GetAnnouncement = function() return "DANGER! A creature stirs... Prepare!" end,
        Execute = function(self, world, target)
            local player = GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            SpawnNear("spear", x, z, 3)
            SpawnNear("armorwood", x, z, 3)
            SpawnNear("healingsalve", x, z, 3)
            world:DoTaskInTime(60, function()
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("The creature arrives!") end
                SpawnNear("leif", x, z, 15)
            end)
        end,
    })

    Log("Registered " .. mgr:GetEventCount() .. " events")
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

-- Log successful initialization
Log("Mod initialized successfully!")
Log("DnD Gamemaster mode enabled - daily and weekly events active!")
