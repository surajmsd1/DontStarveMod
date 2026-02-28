-- Mission Definitions
-- Data-driven mission templates that can be triggered by events or boxes
-- Each mission defines objectives, rewards, and optional boss spawns

local MissionTracker = require "systems/mission_tracker"

local MissionDefs = {}

-- Helper: scale requirement by player count
local function Scaled(base)
    local count = #(AllPlayers or {})
    return math.ceil(base * (1 + (math.max(0, count - 1)) * 0.5))
end

-- =============================================================================
-- GATHERING MISSIONS
-- =============================================================================

MissionDefs.resource_drive = {
    id = "resource_drive",
    name = "Resource Drive",
    description = "The team needs supplies! Gather resources together.",
    category = "gather",
    objectives = {
        { type = "collect", target = "log", required = 20, label = "Logs" },
        { type = "collect", target = "rocks", required = 15, label = "Rocks" },
        { type = "collect", target = "cutgrass", required = 10, label = "Grass" },
    },
    rewards = { loot_pack = "builders" },
}

MissionDefs.gold_rush = {
    id = "gold_rush",
    name = "Gold Rush",
    description = "Find gold nuggets scattered across the world!",
    category = "gather",
    time_limit = 480,  -- 1 day
    objectives = {
        { type = "collect", target = "goldnugget", required = 15, label = "Gold Nuggets" },
    },
    rewards = { loot_pack = "gem_jackpot" },
}

MissionDefs.silk_harvest = {
    id = "silk_harvest",
    name = "Silk Harvest",
    description = "The spiders are everywhere. Make use of them.",
    category = "gather",
    objectives = {
        { type = "collect", target = "silk", required = 12, label = "Silk" },
        { type = "collect", target = "spidergland", required = 6, label = "Spider Glands" },
    },
    rewards = { loot_pack = "spider_haul" },
}

MissionDefs.gem_collector = {
    id = "gem_collector",
    name = "Gem Collector",
    description = "Rare gems have been spotted. Collect them all!",
    category = "gather",
    time_limit = 960,  -- 2 days
    objectives = {
        { type = "collect", target = "redgem", required = 3, label = "Red Gems" },
        { type = "collect", target = "bluegem", required = 3, label = "Blue Gems" },
    },
    rewards = { items = {"purplegem", "purplegem", "yellowgem", "thulecite"} },
}

-- =============================================================================
-- COMBAT / KILL MISSIONS
-- =============================================================================

MissionDefs.spider_hunt = {
    id = "spider_hunt",
    name = "Spider Extermination",
    description = "Clear out the spider infestation!",
    category = "challenge",
    objectives = {
        { type = "kill", target = "spider", required = 15, label = "Spiders" },
        { type = "kill", target = "spider_warrior", required = 5, label = "Spider Warriors" },
    },
    rewards = { loot_pack = "combat_kit" },
}

MissionDefs.hound_defense = {
    id = "hound_defense",
    name = "Hound Defense",
    description = "A massive hound wave approaches! Defend the camp!",
    category = "challenge",
    time_limit = 600,  -- 10 minutes
    objectives = {
        { type = "kill", target = "hound", required = 12, label = "Hounds" },
    },
    rewards = { loot_pack = "warrior_pack" },
}

MissionDefs.shadow_purge = {
    id = "shadow_purge",
    name = "Shadow Purge",
    description = "The shadows grow restless. Destroy the nightmare creatures!",
    category = "challenge",
    objectives = {
        { type = "kill", target = "crawlinghorror", required = 4, label = "Crawling Horrors" },
        { type = "kill", target = "terrorbeak", required = 3, label = "Terrorbeaks" },
    },
    rewards = { loot_pack = "shadow_magic" },
}

MissionDefs.pig_war = {
    id = "pig_war",
    name = "Pig Uprising",
    description = "The werepigs are on the loose!",
    category = "challenge",
    time_limit = 480,
    objectives = {
        { type = "kill", target = "pigman", required = 8, label = "Werepigs" },
    },
    rewards = { loot_pack = "feast" },
}

-- =============================================================================
-- BOSS MISSIONS
-- =============================================================================

MissionDefs.deerclops_hunt = {
    id = "deerclops_hunt",
    name = "Deerclops Hunt",
    description = "A Deerclops has been sighted! Band together and take it down!",
    category = "boss",
    icon = "deerclops",
    objectives = {
        { type = "boss", target = "deerclops", required = 1, label = "Deerclops" },
    },
    rewards = { loot_pack = "boss_loot" },
    -- Spawns the boss near a random player
    on_start_spawn = {
        prefab = "deerclops",
        announce = "A Deerclops emerges from the fog!",
    },
}

MissionDefs.bearger_hunt = {
    id = "bearger_hunt",
    name = "Bearger Takedown",
    description = "A rampaging Bearger threatens the camp!",
    category = "boss",
    icon = "bearger",
    objectives = {
        { type = "boss", target = "bearger", required = 1, label = "Bearger" },
    },
    rewards = { loot_pack = "boss_loot" },
    on_start_spawn = {
        prefab = "bearger",
        announce = "The ground shakes... a Bearger approaches!",
    },
}

MissionDefs.treeguard_stand = {
    id = "treeguard_stand",
    name = "Treeguard Stand",
    description = "The forest is angry! Multiple Treeguards are coming!",
    category = "boss",
    icon = "leif",
    objectives = {
        { type = "boss", target = "leif", required = 3, label = "Treeguards" },
    },
    rewards = { loot_pack = "legendary_cache" },
    on_start_spawn = {
        prefab = "leif",
        count = 3,
        announce = "The trees are waking up!",
    },
}

MissionDefs.spider_queen_hunt = {
    id = "spider_queen_hunt",
    name = "Spider Queen Slayer",
    description = "A Spider Queen has hatched! Destroy her before she spreads!",
    category = "boss",
    icon = "spiderqueen",
    time_limit = 600,
    objectives = {
        { type = "boss", target = "spiderqueen", required = 1, label = "Spider Queen" },
    },
    rewards = { loot_pack = "boss_loot" },
    on_start_spawn = {
        prefab = "spiderqueen",
        announce = "A Spider Queen emerges from her den!",
    },
}

-- =============================================================================
-- BUILDING MISSIONS
-- =============================================================================

MissionDefs.fortify_camp = {
    id = "fortify_camp",
    name = "Fortify the Camp",
    description = "Build defenses to protect the base!",
    category = "gather",
    objectives = {
        { type = "build", target = "wall_stone", required = 10, label = "Stone Walls" },
        { type = "build", target = "firepit", required = 1, label = "Fire Pit" },
    },
    rewards = { loot_pack = "combat_kit" },
}

MissionDefs.farm_setup = {
    id = "farm_setup",
    name = "Farm Setup",
    description = "Establish a sustainable food source!",
    category = "gather",
    objectives = {
        { type = "build", target = "slow_farmplot", required = 3, label = "Farm Plots" },
        { type = "build", target = "birdcage", required = 1, label = "Bird Cage" },
    },
    rewards = { loot_pack = "gourmet_feast" },
}

-- =============================================================================
-- MULTI-OBJECTIVE MISSIONS (mix of types)
-- =============================================================================

MissionDefs.survival_challenge = {
    id = "survival_challenge",
    name = "Survival Challenge",
    description = "Prove your team can handle anything!",
    category = "challenge",
    time_limit = 960,  -- 2 days
    objectives = {
        { type = "collect", target = "meat", required = 10, label = "Meat" },
        { type = "kill", target = "spider", required = 10, label = "Spiders" },
        { type = "collect", target = "goldnugget", required = 5, label = "Gold" },
    },
    rewards = { loot_pack = "legendary_cache" },
}

MissionDefs.arcane_research = {
    id = "arcane_research",
    name = "Arcane Research",
    description = "Gather magical components for a powerful ritual!",
    category = "gather",
    objectives = {
        { type = "collect", target = "nightmarefuel", required = 8, label = "Nightmare Fuel" },
        { type = "collect", target = "purplegem", required = 2, label = "Purple Gems" },
        { type = "kill", target = "crawlinghorror", required = 3, label = "Crawling Horrors" },
    },
    rewards = { loot_pack = "arcane" },
}

-- =============================================================================
-- UTILITY: Get all mission defs as a list
-- =============================================================================

function MissionDefs.GetAll()
    local all = {}
    for key, def in pairs(MissionDefs) do
        if type(def) == "table" and def.id then
            table.insert(all, def)
        end
    end
    return all
end

-- Get missions by category
function MissionDefs.GetByCategory(category)
    local result = {}
    for key, def in pairs(MissionDefs) do
        if type(def) == "table" and def.id and def.category == category then
            table.insert(result, def)
        end
    end
    return result
end

-- Get a random mission def, optionally filtered by category
function MissionDefs.GetRandom(category)
    local pool = category and MissionDefs.GetByCategory(category) or MissionDefs.GetAll()
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

return MissionDefs
