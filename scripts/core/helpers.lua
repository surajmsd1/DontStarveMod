-- Mystery Box Mod - Helper Functions
-- Shared utilities for spawning, logging, and player selection

local Helpers = {}

-- Logging configuration
local VERBOSE = true

function Helpers.Log(msg)
    print("[Mystery Box] " .. tostring(msg))
end

function Helpers.LogVerbose(msg)
    if VERBOSE then
        print("[Mystery Box DEBUG] " .. tostring(msg))
    end
end

function Helpers.SetVerbose(enabled)
    VERBOSE = enabled
end

-- Get a random valid player (not dead, not invalid)
function Helpers.GetRandomPlayer()
    local players = AllPlayers or {}

    -- Filter to valid, alive players
    local validPlayers = {}
    for _, player in ipairs(players) do
        if player
           and player:IsValid()
           and not player:HasTag("playerghost")
           and player.components
           and player.components.health
           and not player.components.health:IsDead() then
            table.insert(validPlayers, player)
        end
    end

    if #validPlayers == 0 then
        Helpers.Log("WARNING: No valid players found")
        return nil
    end

    local player = validPlayers[math.random(#validPlayers)]
    Helpers.LogVerbose("GetRandomPlayer: Selected " .. tostring(player))
    return player
end

-- Spawn prefab near a position with random offset
function Helpers.SpawnNear(prefab, x, z, radius)
    Helpers.LogVerbose("SpawnNear: " .. tostring(prefab) .. " at (" .. tostring(x) .. ", " .. tostring(z) .. ")")

    local entity = SpawnPrefab(prefab)
    if entity then
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * radius
        local spawnX = x + math.cos(angle) * dist
        local spawnZ = z + math.sin(angle) * dist
        entity.Transform:SetPosition(spawnX, 0, spawnZ)
        Helpers.LogVerbose("SUCCESS: Spawned " .. prefab .. " at (" .. spawnX .. ", " .. spawnZ .. ")")
    else
        Helpers.Log("ERROR: Failed to spawn " .. prefab)
    end
    return entity
end

-- Spawn prefab with upward velocity (for "rain" effects)
function Helpers.SpawnWithVelocity(prefab, x, z, velY)
    Helpers.LogVerbose("SpawnWithVelocity: " .. prefab)

    local entity = SpawnPrefab(prefab)
    if entity then
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * 3
        entity.Transform:SetPosition(x + math.cos(angle) * dist, 3, z + math.sin(angle) * dist)
        if entity.Physics then
            entity.Physics:SetVel(math.cos(angle) * 2, velY or 5, math.sin(angle) * 2)
        end
        Helpers.LogVerbose("SUCCESS: Spawned " .. prefab .. " with velocity")
    else
        Helpers.Log("ERROR: Failed to spawn " .. prefab)
    end
    return entity
end

-- Get player position safely
function Helpers.GetPlayerPosition(player)
    if player and player:IsValid() and player.Transform then
        return player.Transform:GetWorldPosition()
    end
    return nil, nil, nil
end

-- Check if entity is valid and usable
function Helpers.IsValidEntity(entity)
    return entity and entity:IsValid()
end

return Helpers
