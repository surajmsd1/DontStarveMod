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
-- EVENT DATA TABLES (Data-driven approach - easy to add/modify events)
-- =============================================================================

-- Simple events: just spawn items near player (no timed waves or special logic)
local SIMPLE_EVENTS = {
    -- REWARD EVENTS
    daily_gift = {
        name = "Daily Gift",
        announcement = "The spirits have left a small gift...",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        spawns = {
            {prefab = {"goldnugget", "silk", "rope", "boards"}, count = 1, radius = 3, random_pick = true},
        },
    },
    weekly_treasure = {
        name = "Weekly Treasure",
        announcement = "A week survived! Treasure appears!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.WEEKLY,
        spawns = {
            {prefab = "mysterybox", count = 1, radius = 5},
            {prefab = "redgem", count = 1, radius = 3},
            {prefab = "bluegem", count = 1, radius = 3},
        },
    },
    feast_time = {
        name = "FEAST TIME!",
        announcement = "FEAST TIME! Food for everyone!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        spawns = {
            {prefab = "cookedmeat", count = 4, radius = 5, velocity = 6},
            {prefab = "cookedfish", count = 2, radius = 5, velocity = 6},
            {prefab = "honey", count = 3, radius = 5, velocity = 6},
            {prefab = "berries_cooked", count = 3, radius = 5, velocity = 6},
            {prefab = "carrot_cooked", count = 2, radius = 5, velocity = 6},
            {prefab = "dragonfruit_cooked", count = 1, radius = 5, velocity = 6},
            {prefab = "cookedsmallmeat", count = 2, radius = 5, velocity = 6},
        },
    },
    builders_dream = {
        name = "BUILDER'S DREAM!",
        announcement = "BUILDER'S DREAM! Construction materials everywhere!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        spawns = {
            {prefab = "log", count = 40, radius = 8},
            {prefab = "rocks", count = 40, radius = 8},
            {prefab = "goldnugget", count = 20, radius = 8},
            {prefab = "rope", count = 10, radius = 8},
        },
    },
    butterfly_bonanza = {
        name = "Butterfly Bonanza!",
        announcement = "BONUS: Butterflies everywhere!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        spawns = {
            {prefab = "butterfly", count = 15, radius = 12},
            {prefab = "bugnet", count = 1, radius = 2},
        },
    },
    gear_up = {
        name = "GEAR UP!",
        announcement = "GEAR UP! Equipment for everyone!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        all_players = true,  -- Special flag: spawn for all players
        spawns = {
            {prefab = "spear", count = 1, radius = 2},
            {prefab = "armorwood", count = 1, radius = 2},
            {prefab = "footballhat", count = 1, radius = 2},
            {prefab = "torch", count = 1, radius = 2},
        },
    },
    treasure_hunt = {
        name = "Treasure Hunt!",
        announcement = "TREASURE HUNT! A mystery box appeared somewhere nearby!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        spawns = {
            {prefab = "mysterybox", count = 1, radius = 5, distance = 60},  -- Spawn far away
        },
    },

    -- CHALLENGE EVENTS
    spider_ambush = {
        name = "SPIDER AMBUSH!",
        announcement = "WARNING: Spiders emerging! Gear nearby...",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.COMMON,
        trigger = EVENT_TRIGGER.DAILY,
        spawns = {
            {prefab = "spear", count = 1, radius = 2, offset_x = 5, offset_z = 5},
            {prefab = "armorwood", count = 1, radius = 2, offset_x = 5, offset_z = 5},
            {prefab = "spider", count = {5, 8}, radius = 8},  -- Random count
        },
    },
    hound_wave = {
        name = "HOUND WAVE!",
        announcement = "DANGER: Hounds approach! Gold awaits the brave!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.DAILY,
        spawns = {
            {prefab = "goldnugget", count = 5, radius = 3, offset_x = -8, offset_z = -8},
            {prefab = "hound", count = {3, 5}, radius = 10},
        },
    },
    frog_apocalypse = {
        name = "FROG APOCALYPSE!",
        announcement = "FROG APOCALYPSE! Ribbit ribbit DOOM!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        spawns = {
            {prefab = "umbrella", count = 1, radius = 2},
            {prefab = "frog", count = 50, radius = 20},
            {prefab = "froglegs", count = 10, radius = 15},
        },
    },
    treeguard_army = {
        name = "TREEGUARD ARMY!",
        announcement = "TREEGUARD ARMY! The forest awakens in fury!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        spawns = {
            {prefab = "leif", count = 3, radius = 20},
            {prefab = "livinglog", count = 20, radius = 25},
            {prefab = "pinecone", count = 10, radius = 15},
        },
    },
    pengull_invasion = {
        name = "PENGULL INVASION!",
        announcement = "PENGULL INVASION! Winter comes early!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        spawns = {
            {prefab = "penguin", count = 30, radius = 20},
            {prefab = "ice", count = 15, radius = 15},
            {prefab = "fish", count = 10, radius = 15},
            {prefab = "winterhat", count = 1, radius = 3},
            {prefab = "heatrock", count = 1, radius = 3},
        },
    },

    -- SOCIAL EVENTS
    pig_party = {
        name = "Pig Party!",
        announcement = "FRIENDS: Pigs want to party!",
        category = EVENT_CATEGORY.SOCIAL,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.DAILY,
        all_players = true,
        spawns = {
            {prefab = "pigman", count = 3, radius = 5},
        },
    },
}

-- Timed events: spawn items/loot with delays for dramatic effect
local TIMED_EVENTS = {
    loot_explosion = {
        name = "LOOT EXPLOSION!",
        announcement = "LOOT EXPLOSION! Items rain from the sky!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
        delay_per_item = 0.1,
        velocity = 8,
        loot = {
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
        },
    },
    magic_storm = {
        name = "MAGIC STORM!",
        announcement = "MAGIC STORM! Arcane power descends!",
        category = EVENT_CATEGORY.REWARD,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        delay_per_item = 0.15,
        velocity = 10,
        loot = {
            "redgem", "redgem", "redgem",
            "bluegem", "bluegem", "bluegem",
            "purplegem", "purplegem",
            "yellowgem", "orangegem", "greengem",
            "amulet", "blueamulet",
        },
    },
    meteor_shower = {
        name = "METEOR SHOWER!",
        announcement = "METEOR SHOWER! Rocks fall from the sky!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        meteor_count = 20,
        meteor_delay = 0.5,
        meteor_spread = 30,
        initial_spawns = {
            {prefab = "flint", count = 10, radius = 15},
            {prefab = "nitre", count = 5, radius = 15},
        },
    },
}

-- Multi-wave events: complex events with multiple phases and announcements
local WAVE_EVENTS = {
    arena_challenge = {
        name = "ARENA CHALLENGE!",
        announcement = "ARENA CHALLENGE BEGINS! Survive 3 waves!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        initial_gear = {"spear", "armorwood", "healingsalve"},
        waves = {
            {delay = 0, announce = "WAVE 1: SPIDERS!", spawns = {{prefab = "spider", count = 8, radius = 10}}},
            {delay = 45, announce = "WAVE 2: HOUNDS APPROACH!",
             rewards = {"spear", "armorwood", "goldnugget", "goldnugget", "goldnugget"},
             spawns = {{prefab = "hound", count = 5, radius = 12}}},
            {delay = 90, announce = "FINAL WAVE: THE GUARDIAN AWAKENS!",
             rewards = {"goldnugget", "goldnugget", "goldnugget", "goldnugget", "goldnugget", "redgem", "bluegem"},
             spawns = {{prefab = "leif", count = 1, radius = 15}}},
            {delay = 150, announce = "ARENA COMPLETE! Claim your legendary rewards!",
             rewards = {"purplegem", "purplegem", "greengem", "orangegem", "yellowgem", "thulecite", "armorruins"}},
        },
    },
    shadow_invasion = {
        name = "SHADOW INVASION!",
        announcement = "SHADOW INVASION! The darkness hungers...",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.MANUAL,
        waves = {
            {delay = 0, announce = "The shadows stir...", spawns = {{prefab = "crawlinghorror", count = 2, radius = 15}}},
            {delay = 30, announce = "THE SHADOWS GROW STRONGER!", spawns = {{prefab = "crawlinghorror", count = 4, radius = 15}}},
            {delay = 60, announce = "DARKNESS OVERWHELMS!", spawns = {{prefab = "crawlinghorror", count = 6, radius = 15}}},
            {delay = 90, announce = "The shadows recede... rewards remain!",
             rewards = {"nightmarefuel", "nightmarefuel", "nightmarefuel", "nightmarefuel", "nightmarefuel", "nightsword", "armor_sanity"}},
        },
    },
    miniboss_warning = {
        name = "Mini-Boss Incoming!",
        announcement = "DANGER! A creature stirs... Prepare! (60 seconds)",
        category = EVENT_CATEGORY.BOSS,
        rarity = EVENT_RARITY.RARE,
        trigger = EVENT_TRIGGER.WEEKLY,
        initial_gear = {"spear", "spear", "armorwood", "footballhat", "healingsalve", "healingsalve"},
        waves = {
            {delay = 60, announce = "THE CREATURE ARRIVES!", spawns = {{prefab = "leif", count = 1, radius = 15}}},
        },
    },
    giant_awakens = {
        name = "A GIANT AWAKENS!",
        announcement = "SOMETHING MASSIVE STIRS... 60 SECONDS TO PREPARE!",
        category = EVENT_CATEGORY.BOSS,
        rarity = EVENT_RARITY.LEGENDARY,
        trigger = EVENT_TRIGGER.MANUAL,
        initial_gear = {"hambat", "armorwood", "armorwood", "footballhat", "footballhat",
                       "healingsalve", "healingsalve", "healingsalve", "healingsalve", "healingsalve",
                       "cookedmeat", "cookedmeat", "cookedmeat"},
        waves = {
            {delay = 60, announce = "THE GIANT IS HERE!",
             spawns = {{prefab = {"deerclops", "bearger"}, count = 1, radius = 20, random_pick = true}}},
            {delay = 180, announce = "MASSIVE LOOT EXPLOSION!",
             velocity_rewards = {"goldnugget", "goldnugget", "goldnugget", "goldnugget", "goldnugget",
                                "goldnugget", "goldnugget", "goldnugget", "goldnugget", "goldnugget",
                                "redgem", "redgem", "redgem", "redgem", "redgem",
                                "bluegem", "bluegem", "bluegem", "bluegem", "bluegem",
                                "purplegem", "purplegem", "purplegem",
                                "yellowgem", "orangegem", "greengem",
                                "thulecite", "thulecite", "thulecite"}},
        },
    },
}

-- Special events: require custom execute logic (can't be data-driven)
local SPECIAL_EVENTS = {
    beefalo_stampede = {
        name = "BEEFALO STAMPEDE!",
        announcement = "BEEFALO STAMPEDE! The herd charges!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
    },
}

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

-- Log successful initialization
Log("Mod initialized successfully!")
Log("DnD Gamemaster mode enabled - daily and weekly events active!")
