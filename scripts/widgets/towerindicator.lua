-- Tower Indicator Widget
-- Shows an arrow pointing toward nearby undiscovered towers

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local INDICATOR_RANGE = 150  -- Show indicator when tower is within this range
local INDICATOR_MIN_RANGE = 20  -- Hide when very close

local TowerIndicator = Class(Widget, function(self, owner)
    Widget._ctor(self, "TowerIndicator")
    self.owner = owner

    -- Arrow using a triangle shape from UI atlas
    self.arrow = self:AddChild(Image("images/global_redux.xml", "scrollbar_handle.tex"))
    self.arrow:SetScale(1.5, 2)
    self.arrow:SetTint(1, 0.85, 0.3, 1)  -- Golden tint

    -- Distance text
    self.dist_text = self:AddChild(Text(BODYTEXTFONT, 18))
    self.dist_text:SetPosition(0, -25)
    self.dist_text:SetColour(1, 0.9, 0.5, 0.9)

    -- Label
    self.label = self:AddChild(Text(BODYTEXTFONT, 14))
    self.label:SetPosition(0, 25)
    self.label:SetString("Tower Nearby")
    self.label:SetColour(1, 0.9, 0.5, 0.7)

    self:Hide()
    self:StartUpdating()
end)

function TowerIndicator:OnUpdate(dt)
    if not self.owner or not self.owner:IsValid() then
        self:Hide()
        return
    end

    local px, _, pz = self.owner.Transform:GetWorldPosition()

    -- Find nearest undiscovered tower. "Discovered" is whatever's in the
    -- shared client mirror synced from the server; the tag is a local hint.
    local shared = MysteryBox_SharedTowers or {}
    local nearestTower = nil
    local nearestDist = math.huge

    for k, ent in pairs(Ents) do
        if ent:IsValid() and ent:HasTag("lookouttower") then
            local tx, _, tz = ent.Transform:GetWorldPosition()
            local key = math.floor(tx) .. "_" .. math.floor(tz)
            local discovered = shared[key] ~= nil or ent:HasTag("tower_discovered")
            if not discovered then
                local dist = math.sqrt((tx - px)^2 + (tz - pz)^2)
                if dist < nearestDist and dist < INDICATOR_RANGE and dist > INDICATOR_MIN_RANGE then
                    nearestTower = ent
                    nearestDist = dist
                end
            end
        end
    end

    if nearestTower then
        self:Show()

        local tx, _, tz = nearestTower.Transform:GetWorldPosition()
        local dx = tx - px
        local dz = tz - pz
        local angle = math.atan2(dz, dx)

        -- Rotate arrow to point at tower (convert to degrees, adjust for DST coordinate system)
        local degrees = -math.deg(angle) + 90
        self.arrow:SetRotation(degrees)

        -- Update distance text
        self.dist_text:SetString(string.format("%dm", math.floor(nearestDist)))
    else
        self:Hide()
    end
end

return TowerIndicator
