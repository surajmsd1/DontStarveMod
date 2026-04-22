-- Event Manager for Mystery Box DnD Gamemaster Mod
-- Core system to schedule, track, and trigger events

-- Get GLOBAL reference (passed from modmain or available in env)
local _G = GLOBAL or _G
local Class = _G.Class
local TheNet = _G.TheNet
local GetTime = _G.GetTime

local EventTypes = require("events/event_types")

local EventManager = Class(function(self, world)
    self.world = world
    self.events = {}           -- Registered events by ID
    self.eventsByTrigger = {}  -- Events grouped by trigger type
    self.eventsByCategory = {} -- Events grouped by category
    self.lastDayProcessed = 0  -- Track which day we last processed
    self.lastWeekProcessed = 0 -- Track which week we last processed
    self.eventHistory = {}     -- Log of triggered events
    self.currentStreak = 0     -- Consecutive days with box activation
    self.lastActivationDay = -1 -- Last day a box was activated

    -- Initialize trigger groups
    for _, trigger in pairs(EventTypes.TRIGGER) do
        self.eventsByTrigger[trigger] = {}
    end

    -- Initialize category groups
    for _, category in pairs(EventTypes.CATEGORY) do
        self.eventsByCategory[category] = {}
    end

    print("[Mystery Box] Event Manager initialized")
end)

-- Register an event with the manager
function EventManager:RegisterEvent(event)
    if not event.id or event.id == "" then
        print("[Mystery Box] ERROR: Cannot register event without ID")
        return false
    end

    if self.events[event.id] then
        print("[Mystery Box] WARNING: Overwriting existing event: " .. event.id)
    end

    self.events[event.id] = event

    -- Add to trigger group
    if event.trigger and self.eventsByTrigger[event.trigger] then
        table.insert(self.eventsByTrigger[event.trigger], event)
    end

    -- Add to category group
    if event.category and self.eventsByCategory[event.category] then
        table.insert(self.eventsByCategory[event.category], event)
    end

    print("[Mystery Box] Registered event: " .. event.id)
    return true
end

-- Get current day number from the world
function EventManager:GetCurrentDay()
    if self.world and self.world.state then
        return self.world.state.cycles or 0
    end
    return 0
end

-- Get current week number (1 week = 7 days)
function EventManager:GetCurrentWeek()
    return math.floor(self.GetCurrentDay(self) / 7)
end

-- Check if it's daytime
function EventManager:IsDaytime()
    if self.world and self.world.state then
        return self.world.state.isday or false
    end
    return false
end

-- Get current season
function EventManager:GetSeason()
    if self.world and self.world.state then
        return self.world.state.season or "autumn"
    end
    return "autumn"
end

-- Select a random event from a list based on rarity weights
function EventManager:SelectWeightedEvent(eventList)
    if not eventList or #eventList == 0 then
        return nil
    end

    -- Calculate total weight
    local totalWeight = 0
    for _, event in ipairs(eventList) do
        local rarity = event.rarity or EventTypes.RARITY.COMMON
        totalWeight = totalWeight + rarity.weight
    end

    -- Roll and select
    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, event in ipairs(eventList) do
        local rarity = event.rarity or EventTypes.RARITY.COMMON
        cumulative = cumulative + rarity.weight
        if roll <= cumulative then
            return event
        end
    end

    -- Fallback to first event
    return eventList[1]
end

-- Trigger a specific event by ID
function EventManager:TriggerEvent(eventId, target)
    local event = self.events[eventId]
    if not event then
        print("[Mystery Box] ERROR: Event not found: " .. eventId)
        return false
    end

    return self:ExecuteEvent(event, target)
end

-- Execute an event with optional dramatic pause
function EventManager:ExecuteEvent(event, target, useDramaticPause)
    if not event then
        return false
    end

    print("[Mystery Box] Triggering event: " .. event.name)

    -- If dramatic pause requested, delay the reveal
    if useDramaticPause then
        return self:ExecuteEventWithDrama(event, target)
    end

    -- Announce to all players
    local announcement = event:GetAnnouncement()
    if announcement and announcement ~= "" then
        self:AnnounceToAll(announcement)
    end

    -- Optional warning delay: give players time to react before hostile spawns.
    -- Event authors opt in via `warning_delay` in their event config (see
    -- event_types.lua). A nil/0 value preserves the original immediate behavior.
    local warning_delay = event.warning_delay or 0
    if warning_delay > 0 and self.world and self.world.DoTaskInTime then
        print(string.format("[Mystery Box] Spawn delayed %ds for warning: %s",
            warning_delay, event.name))
        self.world:DoTaskInTime(warning_delay, function()
            if event.GetPreSpawnAnnouncement then
                local msg = event:GetPreSpawnAnnouncement()
                if msg and msg ~= "" then
                    self:AnnounceToAll(msg)
                end
            end
            local success = event:Execute(self.world, target)
            table.insert(self.eventHistory, {
                id = event.id,
                name = event.name,
                day = self:GetCurrentDay(),
                success = success,
                time = GetTime(),
            })
        end)
        return true
    end

    -- Execute the event
    local success = event:Execute(self.world, target)

    -- Log to history
    table.insert(self.eventHistory, {
        id = event.id,
        name = event.name,
        day = self:GetCurrentDay(),
        success = success,
        time = GetTime(),
    })

    return success
end

-- Execute event with dramatic pause and sound
function EventManager:ExecuteEventWithDrama(event, target)
    -- Play dramatic sound
    if target and target.SoundEmitter then
        target.SoundEmitter:PlaySound("dontstarve/common/together/chest_retune")
    end

    -- Announce suspense message
    self:AnnounceToAll("The mystery box glows...")

    -- Schedule the actual event after a dramatic pause (2 seconds)
    self.world:DoTaskInTime(2, function()
        -- Play reveal sound
        if target and target.SoundEmitter then
            target.SoundEmitter:PlaySound("dontstarve/common/together/chest_retune_open")
        end

        -- Announce the event
        local announcement = event:GetAnnouncement()
        if announcement and announcement ~= "" then
            self:AnnounceToAll(announcement)
        end

        -- Execute the event
        local success = event:Execute(self.world, target)

        -- Log to history
        table.insert(self.eventHistory, {
            id = event.id,
            name = event.name,
            day = self:GetCurrentDay(),
            success = success,
            time = GetTime(),
        })
    end)

    return true -- Return immediately, event executes after delay
end

-- Trigger a random event of a specific trigger type
function EventManager:TriggerRandomEvent(triggerType, target)
    local eventList = self.eventsByTrigger[triggerType]
    if not eventList or #eventList == 0 then
        print("[Mystery Box] No events registered for trigger: " .. triggerType)
        return false
    end

    local event = self:SelectWeightedEvent(eventList)
    if event then
        return self:ExecuteEvent(event, target)
    end

    return false
end

-- Announce message to all players
function EventManager:AnnounceToAll(message)
    if TheNet and TheNet.Announce then
        TheNet:Announce(message)
    end
    print("[Mystery Box] ANNOUNCEMENT: " .. message)
end

-- Called when a new day starts (dawn)
function EventManager:OnDayStart()
    local currentDay = self:GetCurrentDay()

    -- Prevent duplicate processing
    if currentDay <= self.lastDayProcessed then
        return
    end

    self.lastDayProcessed = currentDay
    print("[Mystery Box] Day " .. currentDay .. " has begun!")

    -- Trigger daily events
    self:TriggerRandomEvent(EventTypes.TRIGGER.DAILY, nil)

    -- Check for weekly events (every 7 days)
    local currentWeek = self:GetCurrentWeek()
    if currentWeek > self.lastWeekProcessed then
        self.lastWeekProcessed = currentWeek
        print("[Mystery Box] Week " .. currentWeek .. " milestone!")
        self:TriggerRandomEvent(EventTypes.TRIGGER.WEEKLY, nil)
    end
end

-- Called when season changes
function EventManager:OnSeasonChange(season)
    print("[Mystery Box] Season changed to: " .. season)
    self:TriggerRandomEvent(EventTypes.TRIGGER.SEASONAL, nil)
end

-- Called when mystery box is activated
function EventManager:OnMysteryBoxActivate(target)
    return self:TriggerRandomEvent(EventTypes.TRIGGER.MANUAL, target)
end

-- Get event history for debugging
function EventManager:GetHistory()
    return self.eventHistory
end

-- Get count of registered events
function EventManager:GetEventCount()
    local count = 0
    for _ in pairs(self.events) do
        count = count + 1
    end
    return count
end

-- Streak System: Track consecutive days of box activation
function EventManager:UpdateStreak()
    local currentDay = self:GetCurrentDay()

    if self.lastActivationDay == currentDay - 1 then
        -- Consecutive day! Increase streak
        self.currentStreak = self.currentStreak + 1
        print("[Mystery Box] Streak increased to: " .. self.currentStreak)
    elseif self.lastActivationDay ~= currentDay then
        -- Streak broken or first activation today
        self.currentStreak = 1
        print("[Mystery Box] Streak reset to 1")
    end

    self.lastActivationDay = currentDay
    return self.currentStreak
end

-- Get current streak
function EventManager:GetStreak()
    return self.currentStreak
end

-- Get streak bonus multiplier (1.0 = no bonus, up to 2.0 at max streak)
function EventManager:GetStreakBonus()
    -- Every 3 days of streak adds 0.1 bonus, max at 2.0
    local bonus = 1.0 + math.min(self.currentStreak * 0.1, 1.0)
    return bonus
end

-- Called when a box is activated (updates streak)
function EventManager:OnBoxActivated(boxType, target)
    self:UpdateStreak()

    local streak = self:GetStreak()
    if streak >= 3 then
        self:AnnounceToAll("Streak Bonus! " .. streak .. " days in a row!")
    end
end

-- Trigger event for specific box type with dramatic pause
function EventManager:TriggerBoxEvent(boxType, target)
    -- Update streak tracking
    self:OnBoxActivated(boxType, target)

    local eventList = nil
    local useDrama = true

    if boxType == "cursed" then
        -- Cursed box: Only challenge, danger, and boss events
        eventList = {}
        for _, event in ipairs(self.eventsByCategory[EventTypes.CATEGORY.CHALLENGE] or {}) do
            table.insert(eventList, event)
        end
        for _, event in ipairs(self.eventsByCategory[EventTypes.CATEGORY.DANGER] or {}) do
            table.insert(eventList, event)
        end
        for _, event in ipairs(self.eventsByCategory[EventTypes.CATEGORY.BOSS] or {}) do
            table.insert(eventList, event)
        end
    elseif boxType == "golden" then
        -- Golden box: Only reward and social events
        eventList = {}
        for _, event in ipairs(self.eventsByCategory[EventTypes.CATEGORY.REWARD] or {}) do
            table.insert(eventList, event)
        end
        for _, event in ipairs(self.eventsByCategory[EventTypes.CATEGORY.SOCIAL] or {}) do
            table.insert(eventList, event)
        end
    else
        -- Normal box: Use manual trigger events
        eventList = self.eventsByTrigger[EventTypes.TRIGGER.MANUAL]
    end

    if not eventList or #eventList == 0 then
        print("[Mystery Box] No events available for box type: " .. boxType)
        return false
    end

    local event = self:SelectWeightedEvent(eventList)
    if event then
        return self:ExecuteEvent(event, target, useDrama)
    end

    return false
end

return EventManager
