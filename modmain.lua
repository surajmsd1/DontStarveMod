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
    LogVerbose("GetRandomPlayer: AllPlayers has " .. #players .. " players")
    if #players == 0 then
        LogVerbose("WARNING: No players found!")
        return nil
    end
    local player = players[math.random(#players)]
    LogVerbose("Selected player: " .. tostring(player))
    return player
end

local function SpawnNear(prefab, x, z, radius)
    LogVerbose("SpawnNear: " .. prefab .. " at (" .. x .. ", " .. z .. ") radius " .. radius)
    local entity = GLOBAL.SpawnPrefab(prefab)
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

-- Register all events
local function RegisterAllEvents(mgr)
    Log("Registering events...")

    -- =====================
    -- REWARD EVENTS
    -- =====================

    -- Daily Gift (Reward)
    mgr:RegisterEvent({
        id = "daily_gift",
        name = "Daily Gift",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "The spirits have left a small gift..." end,
        Execute = function(self, world, target)
            local player = target or GetRandomPlayer()
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
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            SpawnNear("mysterybox", x, z, 5)
            SpawnNear("redgem", x, z, 3)
            SpawnNear("bluegem", x, z, 3)
        end,
    })

    -- LOOT EXPLOSION (Reward - Epic for Golden Box)
    mgr:RegisterEvent({
        id = "loot_explosion",
        name = "LOOT EXPLOSION!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "LOOT EXPLOSION! Items rain from the sky!" end,
        Execute = function(self, world, target)
            Log("Executing LOOT EXPLOSION!")
            local player = target or GetRandomPlayer()
            if not player then
                Log("ERROR: No player for loot explosion")
                return
            end
            local x, y, z = player.Transform:GetWorldPosition()
            Log("Player position: " .. x .. ", " .. z)

            local loot = {
                "goldnugget", "goldnugget", "goldnugget", "goldnugget", "goldnugget",
                "redgem", "bluegem", "purplegem",
                "silk", "silk", "silk",
                "rope", "rope",
                "boards", "boards", "boards",
                "cutgrass", "cutgrass", "cutgrass", "cutgrass",
                "twigs", "twigs", "twigs", "twigs",
                "log", "log", "log",
                "meat", "meat",
                "honey", "honey",
            }

            -- Spawn items with delay for dramatic effect
            for i, item in ipairs(loot) do
                world:DoTaskInTime(i * 0.1, function()
                    SpawnWithVelocity(item, x, z, 8)
                end)
            end
            Log("LOOT EXPLOSION: Scheduled " .. #loot .. " items to spawn!")
        end,
    })

    -- GEAR UP! (Reward)
    mgr:RegisterEvent({
        id = "gear_up",
        name = "GEAR UP!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "GEAR UP! Equipment for everyone!" end,
        Execute = function(self, world, target)
            Log("Executing GEAR UP!")
            for _, player in ipairs(GLOBAL.AllPlayers or {}) do
                local x, y, z = player.Transform:GetWorldPosition()
                SpawnNear("spear", x, z, 2)
                SpawnNear("armorwood", x, z, 2)
                SpawnNear("footballhat", x, z, 2)
                SpawnNear("torch", x, z, 2)
            end
        end,
    })

    -- FEAST TIME (Reward)
    mgr:RegisterEvent({
        id = "feast_time",
        name = "FEAST TIME!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "FEAST TIME! Food for everyone!" end,
        Execute = function(self, world, target)
            Log("Executing FEAST TIME!")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            local foods = {
                "cookedmeat", "cookedmeat", "cookedmeat", "cookedmeat",
                "cookedfish", "cookedfish",
                "honey", "honey", "honey",
                "berries_cooked", "berries_cooked", "berries_cooked",
                "carrot_cooked", "carrot_cooked",
                "dragonfruit_cooked",
                "cookedsmallmeat", "cookedsmallmeat",
            }

            for _, food in ipairs(foods) do
                SpawnWithVelocity(food, x, z, 6)
            end
        end,
    })

    -- MAGIC STORM (Reward - Rare)
    mgr:RegisterEvent({
        id = "magic_storm",
        name = "MAGIC STORM!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "MAGIC STORM! Arcane power descends!" end,
        Execute = function(self, world, target)
            Log("Executing MAGIC STORM!")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            local magic = {
                "redgem", "redgem", "redgem",
                "bluegem", "bluegem", "bluegem",
                "purplegem", "purplegem",
                "yellowgem",
                "orangegem",
                "greengem",
                "amulet", -- Life Giving Amulet
                "blueamulet", -- Chilled Amulet
            }

            for i, item in ipairs(magic) do
                world:DoTaskInTime(i * 0.15, function()
                    SpawnWithVelocity(item, x, z, 10)
                end)
            end
        end,
    })

    -- BUILDER'S DREAM (Reward)
    mgr:RegisterEvent({
        id = "builders_dream",
        name = "BUILDER'S DREAM!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "BUILDER'S DREAM! Construction materials everywhere!" end,
        Execute = function(self, world, target)
            Log("Executing BUILDER'S DREAM!")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- 40 logs, 40 rocks, 20 gold, 10 rope
            for i = 1, 40 do SpawnNear("log", x, z, 8) end
            for i = 1, 40 do SpawnNear("rocks", x, z, 8) end
            for i = 1, 20 do SpawnNear("goldnugget", x, z, 8) end
            for i = 1, 10 do SpawnNear("rope", x, z, 8) end
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
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            for i = 1, 15 do SpawnNear("butterfly", x, z, 12) end
            SpawnNear("bugnet", x, z, 2)
        end,
    })

    -- =====================
    -- CHALLENGE EVENTS
    -- =====================

    -- Spider Ambush (Challenge)
    mgr:RegisterEvent({
        id = "spider_ambush",
        name = "SPIDER AMBUSH!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "WARNING: Spiders emerging! Gear nearby..." end,
        Execute = function(self, world, target)
            Log("Executing SPIDER AMBUSH!")
            local player = target or GetRandomPlayer()
            if not player then
                Log("ERROR: No player for spider ambush")
                return
            end
            local x, y, z = player.Transform:GetWorldPosition()
            Log("Spawning spiders at: " .. x .. ", " .. z)

            -- Spawn gear first
            SpawnNear("spear", x + 5, z + 5, 2)
            SpawnNear("armorwood", x + 5, z + 5, 2)

            -- Then spawn spiders
            local spiderCount = math.random(5, 8)
            for i = 1, spiderCount do
                SpawnNear("spider", x, z, 8)
            end
            Log("Spawned " .. spiderCount .. " spiders!")
        end,
    })

    -- Hound Wave (Challenge)
    mgr:RegisterEvent({
        id = "hound_wave",
        name = "HOUND WAVE!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "DANGER: Hounds approach! Gold awaits the brave!" end,
        Execute = function(self, world, target)
            Log("Executing HOUND WAVE!")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Spawn gold as reward marker
            for i = 1, 5 do SpawnNear("goldnugget", x - 8, z - 8, 3) end

            -- Spawn hounds
            local houndCount = math.random(3, 5)
            for i = 1, houndCount do SpawnNear("hound", x, z, 10) end
            Log("Spawned " .. houndCount .. " hounds!")
        end,
    })

    -- ARENA CHALLENGE (Challenge - Epic multi-wave)
    mgr:RegisterEvent({
        id = "arena_challenge",
        name = "ARENA CHALLENGE!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "ARENA CHALLENGE BEGINS! Survive 3 waves!" end,
        Execute = function(self, world, target)
            Log("=== ARENA CHALLENGE STARTING ===")
            local player = target or GetRandomPlayer()
            if not player then
                Log("ERROR: No player for arena challenge")
                return
            end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Drop initial gear
            SpawnNear("spear", x, z, 3)
            SpawnNear("armorwood", x, z, 3)
            SpawnNear("healingsalve", x, z, 3)

            -- WAVE 1: Spiders (immediate)
            Log("ARENA WAVE 1: Spiders!")
            if GLOBAL.TheNet then GLOBAL.TheNet:Announce("WAVE 1: SPIDERS!") end
            for i = 1, 8 do SpawnNear("spider", x, z, 10) end

            -- WAVE 2: Hounds (after 45 seconds)
            world:DoTaskInTime(45, function()
                Log("ARENA WAVE 2: Hounds!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("WAVE 2: HOUNDS APPROACH!") end
                -- Wave 1 rewards
                SpawnNear("spear", x, z, 3)
                SpawnNear("armorwood", x, z, 3)
                for i = 1, 3 do SpawnNear("goldnugget", x, z, 4) end
                -- Spawn hounds
                for i = 1, 5 do SpawnNear("hound", x, z, 12) end
            end)

            -- WAVE 3: The Guardian (after 90 seconds)
            world:DoTaskInTime(90, function()
                Log("ARENA WAVE 3: The Guardian!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("FINAL WAVE: THE GUARDIAN AWAKENS!") end
                -- Wave 2 rewards
                for i = 1, 5 do SpawnNear("goldnugget", x, z, 5) end
                SpawnNear("redgem", x, z, 3)
                SpawnNear("bluegem", x, z, 3)
                -- Spawn the guardian (Treeguard)
                SpawnNear("leif", x, z, 15)
            end)

            -- Victory rewards (after 150 seconds)
            world:DoTaskInTime(150, function()
                Log("ARENA CHALLENGE: Victory rewards!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("ARENA COMPLETE! Claim your legendary rewards!") end
                SpawnNear("purplegem", x, z, 3)
                SpawnNear("purplegem", x, z, 3)
                SpawnNear("greengem", x, z, 3)
                SpawnNear("orangegem", x, z, 3)
                SpawnNear("yellowgem", x, z, 3)
                SpawnNear("thulecite", x, z, 3)
                SpawnNear("armorruins", x, z, 3)
            end)
        end,
    })

    -- SHADOW INVASION (Challenge - Creepy)
    mgr:RegisterEvent({
        id = "shadow_invasion",
        name = "SHADOW INVASION!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "SHADOW INVASION! The darkness hungers..." end,
        Execute = function(self, world, target)
            Log("=== SHADOW INVASION STARTING ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Wave 1: 2 crawling horrors
            Log("Shadow Wave 1!")
            if GLOBAL.TheNet then GLOBAL.TheNet:Announce("The shadows stir...") end
            for i = 1, 2 do SpawnNear("crawlinghorror", x, z, 15) end

            -- Wave 2: 4 crawling horrors (30 sec)
            world:DoTaskInTime(30, function()
                Log("Shadow Wave 2!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("THE SHADOWS GROW STRONGER!") end
                for i = 1, 4 do SpawnNear("crawlinghorror", x, z, 15) end
            end)

            -- Wave 3: 6 crawling horrors (60 sec)
            world:DoTaskInTime(60, function()
                Log("Shadow Wave 3!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("DARKNESS OVERWHELMS!") end
                for i = 1, 6 do SpawnNear("crawlinghorror", x, z, 15) end
            end)

            -- Rewards (90 sec)
            world:DoTaskInTime(90, function()
                Log("Shadow Invasion Rewards!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("The shadows recede... rewards remain!") end
                for i = 1, 5 do SpawnNear("nightmarefuel", x, z, 5) end
                SpawnNear("nightsword", x, z, 3)
                SpawnNear("armor_sanity", x, z, 3)
            end)
        end,
    })

    -- FROG APOCALYPSE (Challenge - Chaos)
    mgr:RegisterEvent({
        id = "frog_apocalypse",
        name = "FROG APOCALYPSE!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "FROG APOCALYPSE! Ribbit ribbit DOOM!" end,
        Execute = function(self, world, target)
            Log("=== FROG APOCALYPSE ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Give player an umbrella
            SpawnNear("umbrella", x, z, 2)

            -- Spawn LOTS of frogs
            for i = 1, 50 do
                SpawnNear("frog", x, z, 20)
            end

            -- Bonus frog legs as rewards scattered around
            for i = 1, 10 do
                SpawnNear("froglegs", x, z, 15)
            end

            Log("Spawned 50 frogs!")
        end,
    })

    -- BEEFALO STAMPEDE (Challenge - Chaos)
    mgr:RegisterEvent({
        id = "beefalo_stampede",
        name = "BEEFALO STAMPEDE!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "BEEFALO STAMPEDE! The herd charges!" end,
        Execute = function(self, world, target)
            Log("=== BEEFALO STAMPEDE ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Spawn beefalo in a line formation charging toward player
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
                    -- Make them angry!
                    if beefalo.components.combat then
                        beefalo.components.combat:SetTarget(player)
                    end
                end
            end

            -- Spawn beefalo wool and meat as bonus loot
            for i = 1, 5 do SpawnNear("beefalowool", x, z, 8) end
            for i = 1, 3 do SpawnNear("meat", x, z, 8) end

            Log("Spawned 15 angry beefalo!")
        end,
    })

    -- METEOR SHOWER (Challenge - Chaos)
    mgr:RegisterEvent({
        id = "meteor_shower",
        name = "METEOR SHOWER!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "METEOR SHOWER! Rocks fall from the sky!" end,
        Execute = function(self, world, target)
            Log("=== METEOR SHOWER ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Spawn meteors over time
            for i = 1, 20 do
                world:DoTaskInTime(i * 0.5, function()
                    local meteorX = x + (math.random() - 0.5) * 30
                    local meteorZ = z + (math.random() - 0.5) * 30

                    -- Spawn rock and gold nuggets (simulating meteor impact)
                    SpawnNear("rocks", meteorX, meteorZ, 2)
                    SpawnNear("rocks", meteorX, meteorZ, 2)
                    if math.random() < 0.3 then
                        SpawnNear("goldnugget", meteorX, meteorZ, 2)
                    end
                    if math.random() < 0.1 then
                        SpawnNear("moonrocknugget", meteorX, meteorZ, 2)
                    end
                end)
            end

            -- Bonus: spawn some flint and nitre
            for i = 1, 10 do SpawnNear("flint", x, z, 15) end
            for i = 1, 5 do SpawnNear("nitre", x, z, 15) end

            Log("Meteor shower started!")
        end,
    })

    -- TREEGUARD ARMY (Challenge - Boss-like)
    mgr:RegisterEvent({
        id = "treeguard_army",
        name = "TREEGUARD ARMY!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "TREEGUARD ARMY! The forest awakens in fury!" end,
        Execute = function(self, world, target)
            Log("=== TREEGUARD ARMY ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Spawn 3 Treeguards
            for i = 1, 3 do
                SpawnNear("leif", x, z, 20)
            end

            -- But also spawn living logs as consolation prizes
            for i = 1, 20 do
                SpawnNear("livinglog", x, z, 25)
            end

            -- And some pinecones for replanting
            for i = 1, 10 do SpawnNear("pinecone", x, z, 15) end

            Log("Spawned 3 Treeguards and 20 living logs!")
        end,
    })

    -- PENGULL INVASION (Challenge - Winter Chaos)
    mgr:RegisterEvent({
        id = "pengull_invasion",
        name = "PENGULL INVASION!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "PENGULL INVASION! Winter comes early!" end,
        Execute = function(self, world, target)
            Log("=== PENGULL INVASION ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Spawn 30 pengulls
            for i = 1, 30 do
                SpawnNear("penguin", x, z, 20)
            end

            -- Spawn ice and fish everywhere
            for i = 1, 15 do SpawnNear("ice", x, z, 15) end
            for i = 1, 10 do SpawnNear("fish", x, z, 15) end

            -- Bonus: winter gear
            SpawnNear("winterhat", x, z, 3)
            SpawnNear("heatrock", x, z, 3)

            Log("Spawned 30 pengulls!")
        end,
    })

    -- =====================
    -- BOSS EVENTS
    -- =====================

    -- Mini-Boss Warning (Boss)
    mgr:RegisterEvent({
        id = "miniboss_warning",
        name = "Mini-Boss Incoming!",
        category = EVENT_CATEGORY.BOSS,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.WEEKLY,
        GetAnnouncement = function() return "DANGER! A creature stirs... Prepare! (60 seconds)" end,
        Execute = function(self, world, target)
            Log("=== MINI-BOSS WARNING ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Drop preparation gear
            SpawnNear("spear", x, z, 3)
            SpawnNear("spear", x, z, 3)
            SpawnNear("armorwood", x, z, 3)
            SpawnNear("footballhat", x, z, 3)
            SpawnNear("healingsalve", x, z, 3)
            SpawnNear("healingsalve", x, z, 3)

            -- Boss arrives after 60 seconds
            world:DoTaskInTime(60, function()
                Log("Mini-boss arrives!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("THE CREATURE ARRIVES!") end
                SpawnNear("leif", x, z, 15)
            end)
        end,
    })

    -- GIANT AWAKENS (Boss - Epic)
    mgr:RegisterEvent({
        id = "giant_awakens",
        name = "A GIANT AWAKENS!",
        category = EVENT_CATEGORY.BOSS,
        rarity = EVENT_RARITY.LEGENDARY,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "SOMETHING MASSIVE STIRS... 60 SECONDS TO PREPARE!" end,
        Execute = function(self, world, target)
            Log("=== GIANT AWAKENS ===")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()

            -- Drop LOTS of preparation gear
            SpawnNear("hambat", x, z, 3)
            SpawnNear("armorwood", x, z, 3)
            SpawnNear("armorwood", x, z, 3)
            SpawnNear("footballhat", x, z, 3)
            SpawnNear("footballhat", x, z, 3)
            for i = 1, 5 do SpawnNear("healingsalve", x, z, 4) end
            for i = 1, 3 do SpawnNear("cookedmeat", x, z, 4) end

            -- Giant arrives after 60 seconds
            world:DoTaskInTime(60, function()
                Log("GIANT ARRIVES!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("THE GIANT IS HERE!") end
                -- Random giant: Deerclops or Bearger
                local giants = {"deerclops", "bearger"}
                local giant = giants[math.random(#giants)]
                SpawnNear(giant, x, z, 20)
                Log("Spawned: " .. giant)
            end)

            -- Victory rewards after 3 minutes
            world:DoTaskInTime(180, function()
                Log("Giant battle rewards!")
                if GLOBAL.TheNet then GLOBAL.TheNet:Announce("MASSIVE LOOT EXPLOSION!") end
                -- 30+ items explosion
                for i = 1, 10 do SpawnWithVelocity("goldnugget", x, z, 10) end
                for i = 1, 5 do SpawnWithVelocity("redgem", x, z, 10) end
                for i = 1, 5 do SpawnWithVelocity("bluegem", x, z, 10) end
                for i = 1, 3 do SpawnWithVelocity("purplegem", x, z, 10) end
                SpawnWithVelocity("yellowgem", x, z, 10)
                SpawnWithVelocity("orangegem", x, z, 10)
                SpawnWithVelocity("greengem", x, z, 10)
                SpawnWithVelocity("thulecite", x, z, 10)
                SpawnWithVelocity("thulecite", x, z, 10)
                SpawnWithVelocity("thulecite", x, z, 10)
            end)
        end,
    })

    -- =====================
    -- SOCIAL EVENTS
    -- =====================

    -- Pig Party (Social)
    mgr:RegisterEvent({
        id = "pig_party",
        name = "Pig Party!",
        category = EVENT_CATEGORY.SOCIAL,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.DAILY,
        GetAnnouncement = function() return "FRIENDS: Pigs want to party!" end,
        Execute = function(self, world, target)
            Log("Executing PIG PARTY!")
            for _, player in ipairs(GLOBAL.AllPlayers or {}) do
                local x, y, z = player.Transform:GetWorldPosition()
                for i = 1, 3 do SpawnNear("pigman", x, z, 5) end
            end
        end,
    })

    -- Treasure Hunt (Reward/Social)
    mgr:RegisterEvent({
        id = "treasure_hunt",
        name = "Treasure Hunt!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        GetAnnouncement = function() return "TREASURE HUNT! A mystery box appeared somewhere nearby!" end,
        Execute = function(self, world, target)
            Log("Executing TREASURE HUNT!")
            local player = target or GetRandomPlayer()
            if not player then return end
            local x, y, z = player.Transform:GetWorldPosition()
            local angle = math.random() * 2 * math.pi
            local dist = 50 + math.random() * 30
            SpawnNear("mysterybox", x + math.cos(angle) * dist, z + math.sin(angle) * dist, 5)
        end,
    })

    -- =====================
    -- SUMMARY
    -- =====================
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

-- Log successful initialization
Log("Mod initialized successfully!")
Log("DnD Gamemaster mode enabled - daily and weekly events active!")
