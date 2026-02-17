-- Boss & Seasonal Events for Mystery Box DnD Gamemaster Mod
-- Major encounters and seasonal-themed events

-- Get GLOBAL reference
local _G = GLOBAL or _G
local AllPlayers = _G.AllPlayers
local SpawnPrefab = _G.SpawnPrefab
local TheNet = _G.TheNet

local EventTypes = require("events/event_types")

local BossEvents = {}

-- Helper: Find a random player and their position
local function GetRandomPlayerPosition()
    local players = {}
    for _, v in ipairs(AllPlayers) do
        table.insert(players, v)
    end

    if #players == 0 then
        return nil, 0, 0, 0
    end

    local player = players[math.random(#players)]
    local x, y, z = player.Transform:GetWorldPosition()
    return player, x, y, z
end

-- Helper: Spawn multiple entities around a position
local function SpawnEntitiesAround(prefab, count, x, z, radius)
    local spawned = {}
    for i = 1, count do
        local entity = SpawnPrefab(prefab)
        if entity then
            local angle = math.random() * 2 * math.pi
            local dist = math.random() * radius
            local px = x + math.cos(angle) * dist
            local pz = z + math.sin(angle) * dist
            entity.Transform:SetPosition(px, 0, pz)
            table.insert(spawned, entity)
        end
    end
    return spawned
end

-- Helper: Drop loot near position
local function DropLootNear(lootTable, x, z, radius)
    for _, item in ipairs(lootTable) do
        local loot = SpawnPrefab(item)
        if loot then
            local angle = math.random() * 2 * math.pi
            local dist = math.random() * radius
            loot.Transform:SetPosition(x + math.cos(angle) * dist, 0, z + math.sin(angle) * dist)
        end
    end
end

-- Helper: Find a random walkable position in the world
local function GetRandomWorldPosition()
    -- Get a random position within a reasonable range of existing players
    local player, px, py, pz = GetRandomPlayerPosition()
    if not player then
        return 0, 0, 0
    end

    -- Random offset from player (50-100 units away)
    local angle = math.random() * 2 * math.pi
    local dist = 50 + math.random() * 50
    local x = px + math.cos(angle) * dist
    local z = pz + math.sin(angle) * dist

    return x, 0, z
end

--------------------------------------------------------------------------------
-- MINI-BOSS WARNING EVENT
-- Announces an incoming boss, gives players time to prepare, spawns supplies
--------------------------------------------------------------------------------
BossEvents.MiniBossWarning = EventTypes.CreateEvent({
    id = "miniboss_warning",
    name = "Mini-Boss Incoming!",
    description = "A powerful creature approaches! Prepare yourself - supplies incoming!",
    category = EventTypes.CATEGORY.BOSS,
    rarity = EventTypes.RARITY.RARE,
    trigger = EventTypes.TRIGGER.WEEKLY,

    GetAnnouncement = function()
        return "DANGER! A powerful creature stirs... You have 60 seconds to prepare!"
    end,

    Execute = function(world, target)
        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Drop preparation supplies near all players
        for _, p in ipairs(AllPlayers) do
            local px, py, pz = p.Transform:GetWorldPosition()

            -- Combat supplies
            local supplies = {"spear", "armorwood", "footballhat", "healingsalve", "healingsalve"}
            DropLootNear(supplies, px, pz, 5)
        end

        -- Schedule the boss spawn after 60 seconds
        world:DoTaskInTime(60, function()
            -- Announce boss arrival
            if TheNet and TheNet.Announce then
                TheNet:Announce("The creature has arrived!")
            end

            -- Spawn a treeguard (mini-boss) near a random player
            local targetPlayer, tx, ty, tz = GetRandomPlayerPosition()
            if targetPlayer then
                local boss = SpawnPrefab("leif")  -- Treeguard
                if boss then
                    boss.Transform:SetPosition(tx + 15, 0, tz + 15)
                    print("[Mystery Box] Mini-Boss (Leif) spawned!")

                    -- Also spawn some treasure near the boss as incentive
                    local treasure = {"goldnugget", "goldnugget", "redgem", "bluegem", "gears"}
                    DropLootNear(treasure, tx + 15, tz + 15, 3)
                end
            end
        end)

        print("[Mystery Box] Mini-Boss Warning triggered! Boss in 60 seconds...")
        return true
    end,
})

--------------------------------------------------------------------------------
-- TREASURE HUNT EVENT
-- Spawns a mystery box at a random location, announces coordinates to all
--------------------------------------------------------------------------------
BossEvents.TreasureHunt = EventTypes.CreateEvent({
    id = "treasure_hunt",
    name = "Treasure Hunt!",
    description = "A valuable treasure has appeared somewhere in the world!",
    category = EventTypes.CATEGORY.REWARD,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.DAILY,

    GetAnnouncement = function()
        return "TREASURE HUNT! A mystery box has appeared somewhere in the wilderness!"
    end,

    Execute = function(world, target)
        -- Find a random location away from players
        local x, y, z = GetRandomWorldPosition()

        -- Spawn a mystery box
        local box = SpawnPrefab("mysterybox")
        if box then
            box.Transform:SetPosition(x, 0, z)

            -- Make this box extra valuable - add more loot around it
            local bonusLoot = {"goldnugget", "goldnugget", "purplegem", "thulecite"}
            DropLootNear(bonusLoot, x, z, 5)

            -- Announce approximate direction to players
            local player, px, py, pz = GetRandomPlayerPosition()
            if player then
                local dx = x - px
                local dz = z - pz
                local direction = ""

                if math.abs(dx) > math.abs(dz) then
                    direction = dx > 0 and "EAST" or "WEST"
                else
                    direction = dz > 0 and "NORTH" or "SOUTH"
                end

                local distance = math.sqrt(dx * dx + dz * dz)
                local distDesc = distance > 100 and "far" or "nearby"

                if TheNet and TheNet.Announce then
                    TheNet:Announce("The treasure lies " .. distDesc .. " to the " .. direction .. "!")
                end
            end

            print("[Mystery Box] Treasure Hunt box spawned at: " .. x .. ", " .. z)
            return true
        end

        return false
    end,
})

--------------------------------------------------------------------------------
-- SEASONAL EVENTS
--------------------------------------------------------------------------------

-- AUTUMN: Harvest Festival - spawn tons of food
BossEvents.HarvestFestival = EventTypes.CreateEvent({
    id = "harvest_festival",
    name = "Harvest Festival!",
    description = "The spirits celebrate autumn with a bounty of food!",
    category = EventTypes.CATEGORY.REWARD,
    rarity = EventTypes.RARITY.COMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "HARVEST FESTIVAL! Food rains from the sky!"
    end,

    Execute = function(world, target)
        -- Only trigger in autumn
        local season = world.state and world.state.season or "autumn"
        if season ~= "autumn" then
            print("[Mystery Box] Harvest Festival skipped - not autumn")
            return false
        end

        -- Spawn food near all players
        for _, player in ipairs(AllPlayers) do
            local x, y, z = player.Transform:GetWorldPosition()

            local food = {
                "carrot", "carrot", "carrot",
                "corn", "corn",
                "pumpkin", "pumpkin",
                "berries", "berries", "berries",
                "honey", "honey"
            }
            DropLootNear(food, x, z, 8)
        end

        print("[Mystery Box] Harvest Festival triggered!")
        return true
    end,
})

-- WINTER: Frostbite Challenge - spawn warm gear + ice enemies
BossEvents.FrostbiteChallenge = EventTypes.CreateEvent({
    id = "frostbite_challenge",
    name = "Frostbite Challenge!",
    description = "Winter's wrath arrives early! Warm gear and icy foes appear!",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "WINTER'S WRATH! Ice hounds approach, but warm gear awaits!"
    end,

    Execute = function(world, target)
        -- Only trigger in winter
        local season = world.state and world.state.season or "autumn"
        if season ~= "winter" then
            print("[Mystery Box] Frostbite Challenge skipped - not winter")
            return false
        end

        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn ice hounds
        SpawnEntitiesAround("icehound", 4, x, z, 12)

        -- Drop warm gear
        local warmGear = {"beefalohat", "winterhat", "heatrock", "torch", "torch"}
        DropLootNear(warmGear, x, z, 6)

        print("[Mystery Box] Frostbite Challenge triggered!")
        return true
    end,
})

-- SPRING: Frog Rain - spawn frogs + rain gear
BossEvents.FrogRain = EventTypes.CreateEvent({
    id = "frog_rain",
    name = "Frog Rain!",
    description = "It's raining frogs! And also... useful items!",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.COMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "IT'S RAINING FROGS! Quick, grab the loot!"
    end,

    Execute = function(world, target)
        -- Only trigger in spring
        local season = world.state and world.state.season or "autumn"
        if season ~= "spring" then
            print("[Mystery Box] Frog Rain skipped - not spring")
            return false
        end

        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn frogs
        SpawnEntitiesAround("frog", 15, x, z, 15)

        -- Drop rain gear and weapons
        local gear = {"umbrella", "raincoat", "spear", "spear"}
        DropLootNear(gear, x, z, 5)

        -- Trigger rain
        if world:HasTag("forest") then
            world:PushEvent("ms_forceprecipitation", true)
        end

        print("[Mystery Box] Frog Rain triggered!")
        return true
    end,
})

-- SUMMER: Heat Wave - spawn cooling items + fire hounds
BossEvents.HeatWave = EventTypes.CreateEvent({
    id = "heat_wave",
    name = "Heat Wave!",
    description = "Scorching heat brings fire hounds! But also ice and cooling gear!",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "HEAT WAVE! Fire hounds approach! Grab the ice!"
    end,

    Execute = function(world, target)
        -- Only trigger in summer
        local season = world.state and world.state.season or "autumn"
        if season ~= "summer" then
            print("[Mystery Box] Heat Wave skipped - not summer")
            return false
        end

        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn fire hounds
        SpawnEntitiesAround("firehound", 3, x, z, 12)

        -- Drop cooling gear
        local coolGear = {"icehat", "ice", "ice", "ice", "watermelon", "watermelon"}
        DropLootNear(coolGear, x, z, 6)

        print("[Mystery Box] Heat Wave triggered!")
        return true
    end,
})

-- Function to register all boss events with the event manager
function BossEvents.RegisterAll(eventManager)
    eventManager:RegisterEvent(BossEvents.MiniBossWarning)
    eventManager:RegisterEvent(BossEvents.TreasureHunt)
    eventManager:RegisterEvent(BossEvents.HarvestFestival)
    eventManager:RegisterEvent(BossEvents.FrostbiteChallenge)
    eventManager:RegisterEvent(BossEvents.FrogRain)
    eventManager:RegisterEvent(BossEvents.HeatWave)

    print("[Mystery Box] Registered 6 boss/seasonal events")
end

return BossEvents
