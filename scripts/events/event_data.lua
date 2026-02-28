-- Mystery Box Mod - Event Data
-- Pure data definitions for all events (no game logic)
-- This file is loaded by modmain.lua and registers events with the EventManager

-- Inline constants to avoid require chain issues in prefab context
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

local EventData = {}

-- =============================================================================
-- SIMPLE EVENTS: Spawn items immediately
-- =============================================================================
EventData.SIMPLE_EVENTS = {
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

-- =============================================================================
-- TIMED EVENTS: Spawn items/loot with delays for dramatic effect
-- =============================================================================
EventData.TIMED_EVENTS = {
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

-- =============================================================================
-- WAVE EVENTS: Complex multi-phase events with multiple waves and announcements
-- =============================================================================
EventData.WAVE_EVENTS = {
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

-- =============================================================================
-- SPECIAL EVENTS: Require custom execute logic (can't be fully data-driven)
-- =============================================================================
EventData.SPECIAL_EVENTS = {
    beefalo_stampede = {
        name = "BEEFALO STAMPEDE!",
        announcement = "BEEFALO STAMPEDE! The herd charges!",
        category = EVENT_CATEGORY.CHALLENGE,
        rarity = EVENT_RARITY.UNCOMMON,
        trigger = EVENT_TRIGGER.MANUAL,
    },
}

-- =============================================================================
-- BOX EVENT POOLS: Which events can be triggered by each box type
-- =============================================================================
EventData.BOX_POOLS = {
    -- Golden boxes: Only reward and social events
    golden = {
        categories = {EVENT_CATEGORY.REWARD, EVENT_CATEGORY.SOCIAL},
        -- Explicit event list (optional override)
        events = nil,
    },
    -- Cursed boxes: Challenge, danger, and boss events (better rewards)
    cursed = {
        categories = {EVENT_CATEGORY.CHALLENGE, EVENT_CATEGORY.DANGER, EVENT_CATEGORY.BOSS},
        events = nil,
    },
    -- Normal mystery boxes: Use loot table (handled in mysterybox.lua)
    normal = {
        categories = nil,
        events = nil,
    },
}

return EventData
