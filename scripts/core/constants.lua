-- Mystery Box Mod - Constants
-- Shared constants used across all modules

local Constants = {}

-- Event categories for filtering
Constants.EVENT_CATEGORY = {
    REWARD = "reward",
    CHALLENGE = "challenge",
    DANGER = "danger",
    BOSS = "boss",
    SOCIAL = "social",
}

-- Event rarity with selection weights
Constants.EVENT_RARITY = {
    COMMON = {name = "Common", weight = 60},
    UNCOMMON = {name = "Uncommon", weight = 25},
    RARE = {name = "Rare", weight = 10},
    LEGENDARY = {name = "Legendary", weight = 5},
}

-- Event trigger types
Constants.EVENT_TRIGGER = {
    DAILY = "daily",
    WEEKLY = "weekly",
    MANUAL = "manual",
    SEASONAL = "seasonal",
}

-- Scout mode constants
Constants.SCOUT = {
    SPEED_MULTIPLIER = 50,  -- 50x normal speed
    REVEAL_RADIUS = 30,     -- Map reveal radius
    REVEAL_INTERVAL = 0.3,  -- Seconds between reveals
}

return Constants
