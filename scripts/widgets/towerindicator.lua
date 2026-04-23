-- Tower Indicator Widget
-- Shows an arrow pointing toward nearby undiscovered towers.
-- Iterates a small registry (MysteryBox_LookoutTowers) instead of scanning
-- every entity every frame.

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local INDICATOR_RANGE = 150  -- Show indicator when tower is within this range
local INDICATOR_MIN_RANGE = 20  -- Hide when very close
local UPDATE_INTERVAL = 0.25  -- seconds between recalculations

local TowerIndicator = Class(Widget, function(self, owner)
    Widget._ctor(self, "TowerIndicator")
    self.owner = owner

    self.arrow = self:AddChild(Image("images/global_redux.xml", "scrollbar_handle.tex"))
    self.arrow:SetScale(1.2, 1.6)
    self.arrow:SetTint(1, 0.85, 0.3, 1)

    self.dist_text = self:AddChild(Text(BODYTEXTFONT, 18))
    self.dist_text:SetPosition(0, -28)
    self.dist_text:SetColour(1, 0.9, 0.5, 0.9)

    self.label = self:AddChild(Text(BODYTEXTFONT, 14))
    self.label:SetPosition(0, 28)
    self.label:SetString("Tower Nearby")
    self.label:SetColour(1, 0.9, 0.5, 0.7)

    self:Hide()
    self.inst:DoPeriodicTask(UPDATE_INTERVAL, function() self:Refresh() end)
end)

function TowerIndicator:Refresh()
    if not self.owner or not self.owner:IsValid() then
        self:Hide()
        return
    end

    local registry = rawget(_G, "MysteryBox_LookoutTowers")
    if not registry then
        self:Hide()
        return
    end

    local px, _, pz = self.owner.Transform:GetWorldPosition()
    local shared = rawget(_G, "MysteryBox_SharedTowers") or {}

    local nearestTower = nil
    local nearestDistSq = math.huge

    for tower in pairs(registry) do
        if tower and tower:IsValid() then
            local tx, _, tz = tower.Transform:GetWorldPosition()
            local key = math.floor(tx) .. "_" .. math.floor(tz)
            local discovered = shared[key] ~= nil or tower:HasTag("tower_discovered")
            if not discovered then
                local dx = tx - px
                local dz = tz - pz
                local distSq = dx*dx + dz*dz
                if distSq < nearestDistSq
                    and distSq < INDICATOR_RANGE * INDICATOR_RANGE
                    and distSq > INDICATOR_MIN_RANGE * INDICATOR_MIN_RANGE then
                    nearestTower = tower
                    nearestDistSq = distSq
                end
            end
        end
    end

    if nearestTower then
        self:Show()
        local tx, _, tz = nearestTower.Transform:GetWorldPosition()
        local dx = tx - px
        local dz = tz - pz
        self.arrow:SetRotation(90 - math.deg(math.atan2(dz, dx)))
        self.dist_text:SetString(string.format("%dm", math.floor(math.sqrt(nearestDistSq))))
    else
        self:Hide()
    end
end

return TowerIndicator
