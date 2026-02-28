-- Mystery Box Mod - Loot System
-- Flexible loot distribution with player scaling and participation tracking

local LootSystem = {}

-- =============================================================================
-- LOOT PACK DEFINITIONS
-- =============================================================================

LootSystem.PACKS = {
    -- ==========================================================================
    -- STARTER/BASIC PACKS
    -- ==========================================================================

    starter_kit = {
        per_player = {"torch", "pickaxe", "axe"},
        shared = {"flint", "flint", "twigs", "twigs", "log", "log"},
    },

    survival_basics = {
        per_player = {"backpack", "torch"},
        shared = {"rope", "rope", "cutgrass", "cutgrass", "twigs", "twigs"},
    },

    -- ==========================================================================
    -- COMBAT PACKS
    -- ==========================================================================

    combat_kit = {
        per_player = {"spear", "armorwood", "healingsalve", "healingsalve"},
        shared = {"footballhat", "hambat"},
    },

    warrior_pack = {
        per_player = {"hambat", "armorwood", "footballhat"},
        shared = {"spear", "spear", "healingsalve", "healingsalve", "healingsalve"},
        bonus = {
            rolls = 1,
            table = {
                {"armorruins", 1},
                {"ruins_bat", 1},
                {"nightsword", 2},
            },
        },
    },

    tank_pack = {
        per_player = {"armorwood", "armorwood", "footballhat", "healingsalve", "healingsalve"},
        shared = {"marble", "marble", "marble"},
    },

    -- ==========================================================================
    -- FOOD PACKS
    -- ==========================================================================

    feast = {
        per_player = {"cookedmeat", "cookedmeat", "honey"},
        shared = {
            "cookedfish", "cookedfish", "cookedfish",
            "berries_cooked", "berries_cooked", "berries_cooked",
            "carrot_cooked", "carrot_cooked",
            "dragonfruit_cooked",
        },
    },

    gourmet_feast = {
        per_player = {"baconeggs", "honeynuggets"},
        shared = {
            "bonestew", "bonestew",
            "butterflymuffin", "butterflymuffin",
            "taffy", "taffy",
            "pumpkincookie",
        },
    },

    winter_feast = {
        per_player = {"hotchili", "meatballs"},
        shared = {
            "cookedmeat", "cookedmeat", "cookedmeat",
            "honey", "honey",
            "heatrock",
        },
    },

    -- ==========================================================================
    -- BUILDING/RESOURCE PACKS
    -- ==========================================================================

    builders = {
        per_player = {"boards", "boards", "rope"},
        shared = {
            "log", "log", "log", "log", "log", "log", "log", "log",
            "rocks", "rocks", "rocks", "rocks", "rocks",
            "goldnugget", "goldnugget", "goldnugget", "goldnugget",
            "cutstone", "cutstone",
        },
    },

    mega_resources = {
        per_player = {"boards", "cutstone", "rope", "rope"},
        shared = {
            "log", "log", "log", "log", "log", "log", "log", "log", "log", "log",
            "rocks", "rocks", "rocks", "rocks", "rocks", "rocks", "rocks", "rocks",
            "goldnugget", "goldnugget", "goldnugget", "goldnugget", "goldnugget",
            "nitre", "nitre", "nitre",
            "marble", "marble",
        },
    },

    -- ==========================================================================
    -- MAGIC/ARCANE PACKS
    -- ==========================================================================

    arcane = {
        per_player = {"nightmarefuel", "nightmarefuel"},
        shared = {"redgem", "redgem", "bluegem", "bluegem"},
        bonus = {
            rolls = 3,
            table = {
                {"purplegem", 8},
                {"yellowgem", 3},
                {"orangegem", 3},
                {"greengem", 2},
                {"opalstaff", 1},
            },
        },
    },

    shadow_magic = {
        per_player = {"nightmarefuel", "nightmarefuel", "nightmarefuel"},
        shared = {"purplegem", "purplegem"},
        bonus = {
            rolls = 2,
            table = {
                {"nightsword", 3},
                {"armor_sanity", 3},
                {"onemanband", 2},
                {"shadowheart", 1},
            },
        },
    },

    gem_jackpot = {
        shared = {"redgem", "redgem", "bluegem", "bluegem", "purplegem"},
        bonus = {
            rolls = 6,
            table = {
                {"redgem", 15},
                {"bluegem", 15},
                {"purplegem", 10},
                {"yellowgem", 5},
                {"orangegem", 5},
                {"greengem", 3},
                {"opalpreciousgem", 1},
            },
        },
    },

    -- ==========================================================================
    -- BOSS/ENDGAME PACKS
    -- ==========================================================================

    boss_loot = {
        per_player = {"goldnugget", "goldnugget", "goldnugget", "meat", "meat"},
        shared = {"purplegem", "purplegem", "thulecite"},
        bonus = {
            rolls = 6,
            table = {
                {"goldnugget", 20},
                {"redgem", 12},
                {"bluegem", 12},
                {"purplegem", 8},
                {"yellowgem", 4},
                {"orangegem", 4},
                {"greengem", 3},
                {"thulecite", 3},
                {"gears", 5},
            },
        },
    },

    legendary_cache = {
        per_player = {"thulecite", "purplegem"},
        shared = {"orangegem", "yellowgem", "greengem"},
        bonus = {
            rolls = 4,
            table = {
                {"armorruins", 3},
                {"ruinshat", 3},
                {"ruins_bat", 2},
                {"orangestaff", 2},
                {"greenstaff", 2},
                {"yellowstaff", 1},
                {"opalstaff", 1},
            },
        },
    },

    -- ==========================================================================
    -- ARENA WAVE REWARDS
    -- ==========================================================================

    arena_wave_1 = {
        per_player = {"healingsalve", "healingsalve"},
        shared = {"goldnugget", "goldnugget", "goldnugget", "spear"},
    },

    arena_wave_2 = {
        per_player = {"armorwood", "healingsalve", "healingsalve"},
        shared = {"goldnugget", "goldnugget", "goldnugget", "goldnugget", "redgem", "hambat"},
    },

    arena_wave_3 = {
        per_player = {"footballhat", "healingsalve", "healingsalve", "healingsalve"},
        shared = {"goldnugget", "goldnugget", "goldnugget", "goldnugget", "goldnugget", "bluegem", "redgem"},
    },

    arena_final = {
        per_player = {"purplegem", "goldnugget", "goldnugget", "goldnugget"},
        shared = {"greengem", "orangegem", "yellowgem", "thulecite", "thulecite"},
        bonus = {
            rolls = 3,
            table = {
                {"armorruins", 3},
                {"ruinshat", 3},
                {"ruins_bat", 2},
                {"orangestaff", 1},
                {"greenstaff", 1},
            },
        },
    },

    -- ==========================================================================
    -- BOX-SPECIFIC PACKS
    -- ==========================================================================

    -- Mystery box: decent variety, medium reward
    mystery_common = {
        shared = {"goldnugget"},
        bonus = {
            rolls = 4,
            table = {
                {"goldnugget", 20},
                {"silk", 15}, {"rope", 15},
                {"boards", 12}, {"cutstone", 12},
                {"gears", 5},
                {"redgem", 4}, {"bluegem", 4},
                {"purplegem", 2},
            },
        },
    },

    -- Golden box: guaranteed good stuff, gem focused
    golden_box = {
        shared = {"goldnugget", "goldnugget", "goldnugget", "goldnugget", "goldnugget"},
        bonus = {
            rolls = 5,
            table = {
                {"goldnugget", 25},
                {"silk", 15}, {"honey", 15}, {"beeswax", 10},
                {"redgem", 8}, {"bluegem", 8},
                {"purplegem", 4},
                {"greengem", 2}, {"orangegem", 2}, {"yellowgem", 2},
                {"gears", 3},
            },
        },
    },

    -- Cursed box: nightmare themed, high risk high reward
    cursed_box = {
        shared = {"purplegem", "purplegem", "nightmarefuel", "nightmarefuel"},
        bonus = {
            rolls = 6,
            table = {
                {"nightmarefuel", 20},
                {"purplegem", 15},
                {"livinglog", 10},
                {"yellowgem", 5}, {"orangegem", 5}, {"greengem", 5},
                {"thulecite", 4},
                {"nightsword", 2},
                {"armor_sanity", 2},
                {"shadowheart", 1},
            },
        },
    },

    -- ==========================================================================
    -- SEASONAL/THEMED PACKS
    -- ==========================================================================

    winter_survival = {
        per_player = {"winterhat", "heatrock"},
        shared = {
            "log", "log", "log", "log",
            "charcoal", "charcoal", "charcoal",
            "beardhair", "beardhair",
        },
        bonus = {
            rolls = 1,
            table = {
                {"beefalohat", 3},
                {"walrushat", 1},
            },
        },
    },

    summer_survival = {
        per_player = {"strawhat", "umbrella"},
        shared = {
            "ice", "ice", "ice", "ice",
            "watermelon", "watermelon",
            "nitre", "nitre",
        },
        bonus = {
            rolls = 1,
            table = {
                {"icehat", 2},
                {"eyebrellahat", 1},
            },
        },
    },

    explorer_kit = {
        per_player = {"lantern", "compass"},
        shared = {
            "lightbulb", "lightbulb", "lightbulb",
            "rope", "rope",
            "twigs", "twigs", "twigs", "twigs",
        },
    },

    bee_bonanza = {
        shared = {
            "honey", "honey", "honey", "honey", "honey",
            "honeycomb", "honeycomb", "honeycomb",
            "beeswax", "beeswax",
            "bee", "bee", "bee",
            "killerbee", "killerbee",
        },
    },

    spider_haul = {
        shared = {
            "silk", "silk", "silk", "silk", "silk", "silk",
            "spidergland", "spidergland", "spidergland",
            "monstermeat", "monstermeat", "monstermeat",
            "spidereggsack",
        },
    },
}

-- =============================================================================
-- CORE FUNCTIONS
-- =============================================================================

-- Get count of valid (alive, not ghost) players
function LootSystem.GetPlayerCount()
    local count = 0
    for _, player in ipairs(AllPlayers or {}) do
        if player and player:IsValid()
           and not player:HasTag("playerghost")
           and player.components and player.components.health
           and not player.components.health:IsDead() then
            count = count + 1
        end
    end
    return math.max(1, count)  -- At least 1
end

-- Get list of valid players
function LootSystem.GetValidPlayers()
    local players = {}
    for _, player in ipairs(AllPlayers or {}) do
        if player and player:IsValid()
           and not player:HasTag("playerghost")
           and player.components and player.components.health
           and not player.components.health:IsDead() then
            table.insert(players, player)
        end
    end
    return players
end

-- Roll from a weighted table
function LootSystem.RollWeighted(weightedTable)
    if not weightedTable or #weightedTable == 0 then
        return nil
    end

    local total = 0
    for _, entry in ipairs(weightedTable) do
        total = total + entry[2]
    end

    local roll = math.random() * total
    local cumulative = 0
    for _, entry in ipairs(weightedTable) do
        cumulative = cumulative + entry[2]
        if roll <= cumulative then
            return entry[1]
        end
    end

    return weightedTable[1][1]  -- Fallback
end

-- Build the full item list from a loot pack
-- Returns: {items = {"prefab1", "prefab2", ...}, player_count = N}
function LootSystem.BuildLootList(packName, playerCountOverride)
    local pack = LootSystem.PACKS[packName]
    if not pack then
        print("[LootSystem] ERROR: Unknown pack '" .. tostring(packName) .. "'")
        return {items = {}, player_count = 0}
    end

    local playerCount = playerCountOverride or LootSystem.GetPlayerCount()
    local items = {}

    -- Add per-player items (multiply by player count)
    if pack.per_player then
        for _, prefab in ipairs(pack.per_player) do
            for i = 1, playerCount do
                table.insert(items, prefab)
            end
        end
    end

    -- Add shared items (once regardless of player count)
    if pack.shared then
        for _, prefab in ipairs(pack.shared) do
            table.insert(items, prefab)
        end
    end

    -- Roll bonus items from weighted table
    if pack.bonus and pack.bonus.table then
        local rolls = pack.bonus.rolls or 1
        for i = 1, rolls do
            local item = LootSystem.RollWeighted(pack.bonus.table)
            if item then
                table.insert(items, item)
            end
        end
    end

    return {items = items, player_count = playerCount}
end

-- Spawn loot at a position with physics (items fly out)
function LootSystem.SpawnLoot(items, x, y, z, options)
    options = options or {}
    local radius = options.radius or 3
    local velocity = options.velocity or 5
    local height = options.height or 1
    local delay = options.delay or 0  -- Delay between spawns for dramatic effect

    local spawned = {}

    for i, prefab in ipairs(items) do
        local spawnDelay = delay * (i - 1)

        if spawnDelay > 0 then
            -- Delayed spawn
            TheWorld:DoTaskInTime(spawnDelay, function()
                local item = SpawnPrefab(prefab)
                if item then
                    item.Transform:SetPosition(x, y + height, z)
                    if item.Physics then
                        local angle = math.random() * 2 * math.pi
                        local speed = velocity * (0.8 + math.random() * 0.4)
                        item.Physics:SetVel(
                            speed * math.cos(angle),
                            velocity,
                            speed * math.sin(angle)
                        )
                    end
                end
            end)
        else
            -- Immediate spawn
            local item = SpawnPrefab(prefab)
            if item then
                item.Transform:SetPosition(x, y + height, z)
                if item.Physics then
                    local angle = math.random() * 2 * math.pi
                    local speed = velocity * (0.8 + math.random() * 0.4)
                    item.Physics:SetVel(
                        speed * math.cos(angle),
                        velocity,
                        speed * math.sin(angle)
                    )
                end
                table.insert(spawned, item)
            end
        end
    end

    return spawned
end

-- Convenience: Build and spawn a loot pack at position
function LootSystem.DropPack(packName, x, y, z, options)
    local result = LootSystem.BuildLootList(packName)
    print("[LootSystem] Dropping '" .. packName .. "' (" .. #result.items .. " items for " .. result.player_count .. " players)")
    return LootSystem.SpawnLoot(result.items, x, y, z, options)
end

-- Drop loot pack near a player
function LootSystem.DropPackNearPlayer(packName, player, options)
    if not player or not player:IsValid() then
        return {}
    end
    local x, y, z = player.Transform:GetWorldPosition()
    return LootSystem.DropPack(packName, x, y, z, options)
end

-- =============================================================================
-- PARTICIPATION TRACKING (Optional - events define their own logic)
-- =============================================================================

-- Create a new participation tracker for an event
-- Events define their own eligibility criteria
function LootSystem.CreateParticipationTracker(eventId)
    return {
        event_id = eventId,
        started_at = GetTime and GetTime() or os.time(),
        participants = {},  -- player_guid -> {data}

        -- Record that a player participated
        RecordParticipation = function(self, player, data)
            if player and player:IsValid() and player.GUID then
                self.participants[player.GUID] = self.participants[player.GUID] or {}
                -- Merge data
                for k, v in pairs(data or {}) do
                    if type(v) == "number" and type(self.participants[player.GUID][k]) == "number" then
                        self.participants[player.GUID][k] = self.participants[player.GUID][k] + v
                    else
                        self.participants[player.GUID][k] = v
                    end
                end
                self.participants[player.GUID].last_seen = GetTime and GetTime() or os.time()
            end
        end,

        -- Check if player participated (event defines what counts)
        HasParticipated = function(self, player)
            return player and player.GUID and self.participants[player.GUID] ~= nil
        end,

        -- Get participation data for a player
        GetData = function(self, player)
            return player and player.GUID and self.participants[player.GUID]
        end,

        -- Get all participants
        GetParticipants = function(self)
            local result = {}
            for guid, data in pairs(self.participants) do
                -- Find player by GUID
                for _, player in ipairs(AllPlayers or {}) do
                    if player.GUID == guid then
                        table.insert(result, {player = player, data = data})
                        break
                    end
                end
            end
            return result
        end,

        -- Filter to only eligible players (custom filter function)
        FilterEligible = function(self, filterFn)
            local eligible = {}
            for _, entry in ipairs(self:GetParticipants()) do
                if filterFn(entry.player, entry.data) then
                    table.insert(eligible, entry.player)
                end
            end
            return eligible
        end,
    }
end

-- Drop loot only to eligible players (from participation tracker)
function LootSystem.DropPackToEligible(packName, eligiblePlayers, options)
    if not eligiblePlayers or #eligiblePlayers == 0 then
        print("[LootSystem] No eligible players for loot")
        return {}
    end

    -- Build loot list scaled to eligible player count
    local result = LootSystem.BuildLootList(packName, #eligiblePlayers)

    -- Drop near first eligible player (or could distribute)
    local player = eligiblePlayers[1]
    if player and player:IsValid() then
        local x, y, z = player.Transform:GetWorldPosition()
        print("[LootSystem] Dropping '" .. packName .. "' to " .. #eligiblePlayers .. " eligible players")
        return LootSystem.SpawnLoot(result.items, x, y, z, options)
    end

    return {}
end

return LootSystem
