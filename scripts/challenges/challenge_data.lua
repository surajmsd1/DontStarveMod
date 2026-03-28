--[[
================================================================================
CHALLENGE DATA - Data-driven challenge definitions
================================================================================

HOW THIS SYSTEM WORKS:
----------------------
1. Each challenge is a table with configuration (no hardcoded UI logic)
2. The ObjectiveTracker widget reads this config and renders dynamically
3. Tracking logic is defined here via "track_events" and "check_progress"
4. Rewards are granted automatically when all objectives complete

CHALLENGE STRUCTURE:
--------------------
{
    id = "unique_id",              -- Unique identifier
    title = "Display Title",       -- Shown in UI header

    objectives = {                 -- Array of objectives to complete
        {
            id = "obj_id",         -- Unique within this challenge
            text = "Collect X",    -- Display text (use %d for count)
            target = 10,           -- Target count to complete
            prefab = "itemname",   -- What prefab to track (for item collection)
        },
    },

    reward = {
        text = "Reward: Item",     -- Display text
        prefab = "prefabname",     -- What to give on completion
        count = 1,                 -- How many to give
    },

    -- Events to listen for (DST event names)
    track_events = {"itemget", "killed", "picksomething"},

    -- Function to check if an event contributes to an objective
    -- Returns: objective_id, amount (or nil if not relevant)
    check_progress = function(player, event_name, event_data)
        -- Custom logic here
        return "obj_id", 1
    end,
}

ADDING A NEW CHALLENGE:
-----------------------
1. Add a new entry to CHALLENGES table below
2. Define objectives with unique ids
3. Implement check_progress function for your tracking logic
4. Challenge will be available via GetChallenge(id)

================================================================================
--]]

local CHALLENGES = {}

--------------------------------------------------------------------------------
-- CHALLENGE: Day One Survival
-- Collect basic resources to get started
--------------------------------------------------------------------------------
CHALLENGES.day_one = {
    id = "day_one",
    title = "Day One Survival",

    objectives = {
        {
            id = "grass",
            text = "Grass: %d/10",
            target = 10,
            prefab = "cutgrass",
        },
        {
            id = "twigs",
            text = "Twigs: %d/10",
            target = 10,
            prefab = "twigs",
        },
    },

    reward = {
        text = "Reward: Backpack",
        prefab = "backpack",
        count = 1,
    },

    track_events = {"itemget"},

    check_progress = function(player, event_name, event_data)
        if event_name == "itemget" and event_data.item then
            local prefab = event_data.item.prefab
            if prefab == "cutgrass" then
                return "grass", 1
            elseif prefab == "twigs" then
                return "twigs", 1
            end
        end
        return nil, 0
    end,
}

--------------------------------------------------------------------------------
-- CHALLENGE: Hunter's Trial
-- Kill creatures to prove your worth
--------------------------------------------------------------------------------
CHALLENGES.hunters_trial = {
    id = "hunters_trial",
    title = "Hunter's Trial",

    objectives = {
        {
            id = "rabbits",
            text = "Rabbits: %d/3",
            target = 3,
            prefab = "rabbit",
        },
        {
            id = "spiders",
            text = "Spiders: %d/5",
            target = 5,
            prefab = "spider",
        },
    },

    reward = {
        text = "Reward: Spear + Log Suit",
        prefab = "spear",  -- Primary reward
        count = 1,
        bonus = {"armorwood"},  -- Additional rewards
    },

    track_events = {"killed"},

    check_progress = function(player, event_name, event_data)
        if event_name == "killed" and event_data.victim then
            local prefab = event_data.victim.prefab
            if prefab == "rabbit" then
                return "rabbits", 1
            elseif prefab == "spider" then
                return "spiders", 1
            end
        end
        return nil, 0
    end,
}

--------------------------------------------------------------------------------
-- CHALLENGE: Lumberjack
-- Gather wood resources
--------------------------------------------------------------------------------
CHALLENGES.lumberjack = {
    id = "lumberjack",
    title = "Lumberjack",

    objectives = {
        {
            id = "logs",
            text = "Logs: %d/20",
            target = 20,
            prefab = "log",
        },
    },

    reward = {
        text = "Reward: Golden Axe",
        prefab = "goldenaxe",
        count = 1,
    },

    track_events = {"itemget"},

    check_progress = function(player, event_name, event_data)
        if event_name == "itemget" and event_data.item then
            if event_data.item.prefab == "log" then
                return "logs", 1
            end
        end
        return nil, 0
    end,
}

--------------------------------------------------------------------------------
-- CHALLENGE: Miner
-- Gather stone and minerals
--------------------------------------------------------------------------------
CHALLENGES.miner = {
    id = "miner",
    title = "Miner",

    objectives = {
        {
            id = "rocks",
            text = "Rocks: %d/20",
            target = 20,
            prefab = "rocks",
        },
        {
            id = "gold",
            text = "Gold: %d/5",
            target = 5,
            prefab = "goldnugget",
        },
    },

    reward = {
        text = "Reward: Golden Pickaxe",
        prefab = "goldenpickaxe",
        count = 1,
    },

    track_events = {"itemget"},

    check_progress = function(player, event_name, event_data)
        if event_name == "itemget" and event_data.item then
            local prefab = event_data.item.prefab
            if prefab == "rocks" then
                return "rocks", 1
            elseif prefab == "goldnugget" then
                return "gold", 1
            end
        end
        return nil, 0
    end,
}

--------------------------------------------------------------------------------
-- API FUNCTIONS
--------------------------------------------------------------------------------

local ChallengeData = {}

-- Get a challenge by ID
-- @param id string - Challenge identifier
-- @return table|nil - Challenge data or nil if not found
function ChallengeData.GetChallenge(id)
    return CHALLENGES[id]
end

-- Get all challenge IDs
-- @return table - Array of challenge IDs
function ChallengeData.GetAllChallengeIds()
    local ids = {}
    for id, _ in pairs(CHALLENGES) do
        table.insert(ids, id)
    end
    return ids
end

-- Get a random challenge
-- @param exclude table|nil - Array of IDs to exclude
-- @return table|nil - Random challenge data
function ChallengeData.GetRandomChallenge(exclude)
    exclude = exclude or {}
    local exclude_set = {}
    for _, id in ipairs(exclude) do
        exclude_set[id] = true
    end

    local available = {}
    for id, challenge in pairs(CHALLENGES) do
        if not exclude_set[id] then
            table.insert(available, challenge)
        end
    end

    if #available > 0 then
        return available[math.random(#available)]
    end
    return nil
end

return ChallengeData
