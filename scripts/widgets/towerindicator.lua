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

    -- Container for the arrow so SetRotation doesn't also spin the text
    self.arrow_root = self:AddChild(Widget("arrow_root"))

    -- Dark halo so the arrow is always visible even on bright backgrounds
    self.halo = self.arrow_root:AddChild(Image("images/global_redux.xml", "scrollbar_bar.tex"))
    self.halo:SetScale(1.1, 1.1)
    self.halo:SetTint(0, 0, 0, 0.55)

    -- Arrow body (scrollbar handle is a tall bar that reads as "up" at rotation 0)
    self.arrow = self.arrow_root:AddChild(Image("images/global_redux.xml", "scrollbar_handle.tex"))
    self.arrow:SetScale(3, 4.5)
    self.arrow:SetTint(1, 0.85, 0.3, 1)  -- Golden tint

    -- Distance text (stays upright, does not rotate with arrow)
    self.dist_text = self:AddChild(Text(BODYTEXTFONT, 26))
    self.dist_text:SetPosition(0, -70)
    self.dist_text:SetColour(1, 0.9, 0.5, 1)

    -- Label (stays upright)
    self.label = self:AddChild(Text(BODYTEXTFONT, 20))
    self.label:SetPosition(0, 70)
    self.label:SetString("Tower Nearby")
    self.label:SetColour(1, 0.9, 0.5, 0.95)

    self:Hide()
    self:StartUpdating()
end)

function TowerIndicator:OnUpdate(dt)
    if not self.owner or not self.owner:IsValid() then
        self:Hide()
        return
    end

    local px, _, pz = self.owner.Transform:GetWorldPosition()

    -- Find nearest undiscovered tower
    local nearestTower = nil
    local nearestDist = math.huge

    for k, ent in pairs(Ents) do
        if ent:IsValid() and ent:HasTag("lookouttower") and not ent:HasTag("tower_discovered") then
            local tx, _, tz = ent.Transform:GetWorldPosition()
            local dist = math.sqrt((tx - px)^2 + (tz - pz)^2)
            if dist < nearestDist and dist < INDICATOR_RANGE and dist > INDICATOR_MIN_RANGE then
                nearestTower = ent
                nearestDist = dist
            end
        end
    end

    if nearestTower then
        self:Show()

        local tx, _, tz = nearestTower.Transform:GetWorldPosition()
        local dx = tx - px
        local dz = tz - pz
        local angle = math.atan2(dz, dx)

        -- Rotate arrow to point at tower.
        -- In DST widget space, positive SetRotation is counter-clockwise and the
        -- arrow texture points "up" (toward +Z / north) at rotation 0. atan2(dz,dx)
        -- returns 0 for east and +pi/2 for north, so we subtract 90 degrees.
        local degrees = math.deg(angle) - 90
        self.arrow_root:SetRotation(degrees)

        -- Update distance text
        self.dist_text:SetString(string.format("%dm", math.floor(nearestDist)))
    else
        self:Hide()
    end
end

return TowerIndicator
