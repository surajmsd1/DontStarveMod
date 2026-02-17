-- Challenge Events for Mystery Box DnD Gamemaster Mod
-- These events combine danger with rewards - defeat enemies, get loot!

-- Get GLOBAL reference
local _G = GLOBAL or _G
local AllPlayers = _G.AllPlayers
local SpawnPrefab = _G.SpawnPrefab

local EventTypes = require("events/event_types")

local ChallengeEvents = {}

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

--------------------------------------------------------------------------------
-- SPIDER AMBUSH EVENT
-- Spawns 5-10 spiders around a random player, plus armor/weapons nearby
--------------------------------------------------------------------------------
ChallengeEvents.SpiderAmbush = EventTypes.CreateEvent({
    id = "spider_ambush",
    name = "Spider Ambush!",
    description = "Spiders emerge from the shadows! But wait... someone left gear nearby...",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.COMMON,
    trigger = EventTypes.TRIGGER.DAILY,

    GetAnnouncement = function()
        return "WARNING: Spiders are emerging! But there's gear nearby..."
    end,

    Execute = function(world, target)
        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn 5-10 spiders
        local spiderCount = math.random(5, 10)
        SpawnEntitiesAround("spider", spiderCount, x, z, 8)

        -- Drop armor and weapons as reward (spawn further away so player can grab before fighting)
        local loot = {"spear", "armorwood", "footballhat"}
        DropLootNear(loot, x + 10, z + 10, 3)

        print("[Mystery Box] Spider Ambush: " .. spiderCount .. " spiders near " .. (player.name or "player"))
        return true
    end,
})

--------------------------------------------------------------------------------
-- HOUND WAVE EVENT
-- Spawns hounds around a random player, with gold/gems as reward
--------------------------------------------------------------------------------
ChallengeEvents.HoundWave = EventTypes.CreateEvent({
    id = "hound_wave",
    name = "Hound Wave!",
    description = "The hounds are hunting! Valuable treasures lie in their wake...",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.DAILY,

    GetAnnouncement = function()
        return "DANGER: Hounds approach! But they guard precious gems..."
    end,

    Execute = function(world, target)
        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn 3-6 hounds
        local houndCount = math.random(3, 6)
        SpawnEntitiesAround("hound", houndCount, x, z, 10)

        -- Drop gold and gems as reward
        local loot = {"goldnugget", "goldnugget", "goldnugget", "redgem", "bluegem"}
        DropLootNear(loot, x - 8, z - 8, 4)

        print("[Mystery Box] Hound Wave: " .. houndCount .. " hounds near " .. (player.name or "player"))
        return true
    end,
})

--------------------------------------------------------------------------------
-- BUTTERFLY BONANZA EVENT
-- Spawns 20 butterflies (food source!) and gives nets to all players
--------------------------------------------------------------------------------
ChallengeEvents.ButterflyBonanza = EventTypes.CreateEvent({
    id = "butterfly_bonanza",
    name = "Butterfly Bonanza!",
    description = "A beautiful swarm of butterflies appears! Quick, catch them for food!",
    category = EventTypes.CATEGORY.REWARD,
    rarity = EventTypes.RARITY.COMMON,
    trigger = EventTypes.TRIGGER.DAILY,

    GetAnnouncement = function()
        return "BONUS: Butterflies everywhere! Nets are spawning for everyone!"
    end,

    Execute = function(world, target)
        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn 20 butterflies
        SpawnEntitiesAround("butterfly", 20, x, z, 15)

        -- Give every player a bug net
        for _, p in ipairs(AllPlayers) do
            local px, py, pz = p.Transform:GetWorldPosition()
            local net = SpawnPrefab("bugnet")
            if net then
                net.Transform:SetPosition(px + 1, 0, pz + 1)
            end
        end

        print("[Mystery Box] Butterfly Bonanza spawned near " .. (player.name or "player"))
        return true
    end,
})

--------------------------------------------------------------------------------
-- PIG PARTY EVENT
-- Spawns friendly pigs that follow players for a day
--------------------------------------------------------------------------------
ChallengeEvents.PigParty = EventTypes.CreateEvent({
    id = "pig_party",
    name = "Pig Party!",
    description = "Friendly pigs arrive to help! They'll follow you around.",
    category = EventTypes.CATEGORY.SOCIAL,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.DAILY,

    GetAnnouncement = function()
        return "FRIENDS: Pigs have arrived to party! They want to be your friend!"
    end,

    Execute = function(world, target)
        -- Spawn pigs near each player
        for _, player in ipairs(AllPlayers) do
            local x, y, z = player.Transform:GetWorldPosition()

            -- Spawn 2-3 pigs per player
            local pigCount = math.random(2, 3)
            local pigs = SpawnEntitiesAround("pigman", pigCount, x, z, 5)

            -- Make pigs follow the player (give them meat to befriend)
            for _, pig in ipairs(pigs) do
                if pig.components.follower then
                    pig.components.follower:StartFollowing(player)
                    -- Set follow time to about a day (480 seconds)
                    pig.components.follower.maxfollowtime = 480
                end
            end
        end

        print("[Mystery Box] Pig Party started!")
        return true
    end,
})

--------------------------------------------------------------------------------
-- WEATHER CHAOS EVENT
-- Triggers rain/lightning + spawns wet gear (rain coat, rain hat, umbrella)
--------------------------------------------------------------------------------
ChallengeEvents.WeatherChaos = EventTypes.CreateEvent({
    id = "weather_chaos",
    name = "Weather Chaos!",
    description = "A sudden storm approaches! Quick, grab the rain gear!",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.RARE,
    trigger = EventTypes.TRIGGER.DAILY,

    GetAnnouncement = function()
        return "STORM WARNING: Lightning approaches! Rain gear is spawning nearby!"
    end,

    Execute = function(world, target)
        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Trigger rain
        if world and world:HasTag("forest") then
            world:PushEvent("ms_forceprecipitation", true)
        end

        -- Spawn some lightning strikes nearby (but not directly on player)
        for i = 1, 3 do
            local lx = x + math.random(-20, 20)
            local lz = z + math.random(-20, 20)
            local lightning = SpawnPrefab("lightning")
            if lightning then
                lightning.Transform:SetPosition(lx, 0, lz)
            end
        end

        -- Drop rain gear as reward
        local rainGear = {"umbrella", "raincoat", "rainhat", "earmuffshat"}
        DropLootNear(rainGear, x, z, 5)

        print("[Mystery Box] Weather Chaos triggered near " .. (player.name or "player"))
        return true
    end,
})

-- Function to register all challenge events with the event manager
function ChallengeEvents.RegisterAll(eventManager)
    eventManager:RegisterEvent(ChallengeEvents.SpiderAmbush)
    eventManager:RegisterEvent(ChallengeEvents.HoundWave)
    eventManager:RegisterEvent(ChallengeEvents.ButterflyBonanza)
    eventManager:RegisterEvent(ChallengeEvents.PigParty)
    eventManager:RegisterEvent(ChallengeEvents.WeatherChaos)

    print("[Mystery Box] Registered " .. 5 .. " challenge events")
end

return ChallengeEvents
