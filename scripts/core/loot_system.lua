-- Mystery Box Mod - Loot System
-- Flexible loot distribution with player scaling and participation tracking

local LootSystem = {}

-- =============================================================================
-- LOOT PACK DEFINITIONS
-- =============================================================================

LootSystem.PACKS = {
    -- Basic starter supplies
    starter_kit = {
        per_player = {"torch", "flint", "twigs"},
        shared = {"log", "log", "rocks", "rocks"},
    },

    -- Combat gear for fights
    combat_kit = {
        per_player = {"spear", "armorwood", "healingsalve"},
        shared = {"footballhat"},
    },

    -- Food supplies
    feast = {
        per_player = {"cookedmeat", "cookedmeat", "honey"},
        shared = {
            "cookedfish", "cookedfish",
            "berries_cooked", "berries_cooked", "berries_cooked",
            "carrot_cooked", "carrot_cooked",
        },
    },

    -- Building materials
    builders = {
        per_player = {"rope", "boards"},
        shared = {
            "log", "log", "log", "log", "log",
            "rocks", "rocks", "rocks", "rocks", "rocks",
            "goldnugget", "goldnugget", "goldnugget",
        },
    },

    -- Magic/gem rewards
    arcane = {
        per_player = {"nightmarefuel"},
        shared = {"redgem", "bluegem"},
        bonus = {
            rolls = 2,
            table = {
                {"purplegem", 5},
                {"yellowgem", 2},
                {"orangegem", 2},
                {"greengem", 1},
            },
        },
    },

    -- Boss kill rewards
    boss_loot = {
        per_player = {"goldnugget", "goldnugget", "meat"},
        shared = {"purplegem", "purplegem"},
        bonus = {
            rolls = 5,
            table = {
                {"goldnugget", 20},
                {"redgem", 10},
                {"bluegem", 10},
                {"purplegem", 5},
                {"yellowgem", 2},
                {"orangegem", 2},
                {"greengem", 1},
                {"thulecite", 1},
            },
        },
    },

    -- Arena challenge rewards (scales with difficulty)
    arena_wave_1 = {
        per_player = {"healingsalve"},
        shared = {"goldnugget", "goldnugget"},
    },
    arena_wave_2 = {
        per_player = {"armorwood", "healingsalve"},
        shared = {"goldnugget", "goldnugget", "goldnugget", "redgem"},
    },
    arena_final = {
        per_player = {"purplegem", "goldnugget", "goldnugget"},
        shared = {"greengem", "orangegem", "yellowgem", "thulecite"},
        bonus = {
            rolls = 3,
            table = {
                {"armorruins", 2},
                {"ruinshat", 2},
                {"orangestaff", 1},
                {"greenstaff", 1},
            },
        },
    },

    -- Mystery box random loot (replaces old single-item system)
    mystery_common = {
        shared = {},
        bonus = {
            rolls = 3,
            table = {
                {"log", 15}, {"rocks", 15}, {"cutgrass", 15}, {"twigs", 15}, {"flint", 15},
                {"goldnugget", 8}, {"silk", 8}, {"rope", 8},
                {"boards", 5}, {"cutstone", 5},
                {"gears", 2}, {"redgem", 2}, {"bluegem", 2},
            },
        },
    },

    -- Golden box loot (better)
    golden_box = {
        shared = {"goldnugget", "goldnugget", "goldnugget"},
        bonus = {
            rolls = 4,
            table = {
                {"goldnugget", 20},
                {"silk", 10}, {"honey", 10},
                {"redgem", 5}, {"bluegem", 5},
                {"purplegem", 2},
                {"greengem", 1}, {"orangegem", 1}, {"yellowgem", 1},
            },
        },
    },

    -- Cursed box loot (high risk, high reward)
    cursed_box = {
        shared = {"purplegem"},
        bonus = {
            rolls = 5,
            table = {
                {"nightmarefuel", 15},
                {"purplegem", 10},
                {"livinglog", 8},
                {"yellowgem", 3}, {"orangegem", 3}, {"greengem", 3},
                {"thulecite", 2},
                {"nightsword", 1},
                {"armor_sanity", 1},
            },
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
