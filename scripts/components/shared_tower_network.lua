-- Server-authoritative list of discovered towers, shared across all players
-- and persisted in the world save via OnSave/OnLoad. Attached to TheWorld.
-- Clients receive snapshots via RPCs from modmain.lua.

local SharedTowerNetwork = Class(function(self, inst)
    self.inst = inst
    self.towers = {}
end)

local function MakeKey(x, z)
    return math.floor(x) .. "_" .. math.floor(z)
end

function SharedTowerNetwork:AddTower(tower)
    if not tower or not tower:IsValid() then return nil end
    local x, _, z = tower.Transform:GetWorldPosition()
    local key = MakeKey(x, z)
    if self.towers[key] then
        return key, self.towers[key], false
    end
    local name = tower.tower_display_name or "Lookout Tower"
    local entry = { x = x, z = z, name = name }
    self.towers[key] = entry
    return key, entry, true
end

function SharedTowerNetwork:GetTowers()
    return self.towers
end

function SharedTowerNetwork:OnSave()
    return { towers = self.towers }
end

function SharedTowerNetwork:OnLoad(data)
    if data and data.towers then
        self.towers = data.towers
    end
end

return SharedTowerNetwork
