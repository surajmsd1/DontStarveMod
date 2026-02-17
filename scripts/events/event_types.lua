-- Event Types for Mystery Box DnD Gamemaster Mod
-- Defines event categories and their properties

local EventTypes = {}

-- Event categories - each has different risk/reward profiles
EventTypes.CATEGORY = {
    REWARD = "reward",      -- Pure positive outcomes (items, buffs)
    CHALLENGE = "challenge", -- Danger + reward (fight enemies, get loot)
    DANGER = "danger",       -- Pure danger (survival test)
    BOSS = "boss",           -- Major encounter (big risk, big reward)
    SOCIAL = "social",       -- Fun events (cosmetic, silly)
}

-- Rarity tiers with weights for random selection
EventTypes.RARITY = {
    COMMON = {name = "Common", weight = 60, color = "white"},
    UNCOMMON = {name = "Uncommon", weight = 25, color = "green"},
    RARE = {name = "Rare", weight = 10, color = "blue"},
    LEGENDARY = {name = "Legendary", weight = 5, color = "purple"},
}

-- Event trigger types
EventTypes.TRIGGER = {
    DAILY = "daily",       -- Fires once per day at dawn
    WEEKLY = "weekly",     -- Fires every 7 days
    MANUAL = "manual",     -- Triggered by mystery box activation
    SEASONAL = "seasonal", -- Fires on season change
}

-- Base event structure template
-- All events should follow this structure
EventTypes.EventTemplate = {
    id = "",                    -- Unique identifier
    name = "",                  -- Display name
    description = "",           -- What happens
    category = EventTypes.CATEGORY.REWARD,
    rarity = EventTypes.RARITY.COMMON,
    trigger = EventTypes.TRIGGER.MANUAL,

    -- Function to execute when event triggers
    -- @param world - TheWorld reference
    -- @param target - Player who triggered (or nil for world events)
    -- @return boolean - success
    Execute = function(world, target)
        return false
    end,

    -- Optional: Announcement message
    GetAnnouncement = function()
        return ""
    end,
}

-- Helper function to create a new event
function EventTypes.CreateEvent(config)
    local event = {}

    -- Copy template defaults
    for k, v in pairs(EventTypes.EventTemplate) do
        event[k] = v
    end

    -- Override with provided config
    for k, v in pairs(config) do
        event[k] = v
    end

    return event
end

-- Calculate total weight for a rarity tier selection
function EventTypes.GetTotalRarityWeight()
    local total = 0
    for _, rarity in pairs(EventTypes.RARITY) do
        total = total + rarity.weight
    end
    return total
end

-- Select a random rarity based on weights
function EventTypes.SelectRandomRarity()
    local total = EventTypes.GetTotalRarityWeight()
    local roll = math.random() * total
    local cumulative = 0

    for name, rarity in pairs(EventTypes.RARITY) do
        cumulative = cumulative + rarity.weight
        if roll <= cumulative then
            return name, rarity
        end
    end

    return "COMMON", EventTypes.RARITY.COMMON
end

return EventTypes
