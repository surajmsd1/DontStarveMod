-- Scout Mode Overlay Widget
-- Spyglass-style circular viewport with black mask

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ScoutOverlay = Class(Widget, function(self, owner)
    Widget._ctor(self, "ScoutOverlay")
    self.owner = owner

    -- Center the whole widget on screen
    self:SetVAnchor(ANCHOR_MIDDLE)
    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- Circle parameters
    local circleRadius = 280  -- Visible circle radius (bigger = more visible)
    local bigSize = 2000      -- Big enough to cover any screen

    -- Top bar (above the circle)
    self.top = self:AddChild(Image("images/global.xml", "square.tex"))
    self.top:SetTint(0, 0, 0, 1)
    self.top:SetSize(bigSize, bigSize)
    self.top:SetPosition(0, circleRadius + bigSize/2)

    -- Bottom bar (below the circle)
    self.bottom = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bottom:SetTint(0, 0, 0, 1)
    self.bottom:SetSize(bigSize, bigSize)
    self.bottom:SetPosition(0, -(circleRadius + bigSize/2))

    -- Left bar (left of the circle)
    self.left = self:AddChild(Image("images/global.xml", "square.tex"))
    self.left:SetTint(0, 0, 0, 1)
    self.left:SetSize(bigSize, bigSize)
    self.left:SetPosition(-(circleRadius + bigSize/2), 0)

    -- Right bar (right of the circle)
    self.right = self:AddChild(Image("images/global.xml", "square.tex"))
    self.right:SetTint(0, 0, 0, 1)
    self.right:SetSize(bigSize, bigSize)
    self.right:SetPosition(circleRadius + bigSize/2, 0)

    -- Corner pieces to round the square hole into a circle
    -- These are rotated 45 degrees to clip the corners
    local cornerSize = circleRadius * 1.2
    local cornerDist = circleRadius * 0.92

    self.tl = self:AddChild(Image("images/global.xml", "square.tex"))
    self.tl:SetTint(0, 0, 0, 1)
    self.tl:SetSize(cornerSize, cornerSize)
    self.tl:SetPosition(-cornerDist, cornerDist)
    self.tl:SetRotation(45)

    self.tr = self:AddChild(Image("images/global.xml", "square.tex"))
    self.tr:SetTint(0, 0, 0, 1)
    self.tr:SetSize(cornerSize, cornerSize)
    self.tr:SetPosition(cornerDist, cornerDist)
    self.tr:SetRotation(45)

    self.bl = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bl:SetTint(0, 0, 0, 1)
    self.bl:SetSize(cornerSize, cornerSize)
    self.bl:SetPosition(-cornerDist, -cornerDist)
    self.bl:SetRotation(45)

    self.br = self:AddChild(Image("images/global.xml", "square.tex"))
    self.br:SetTint(0, 0, 0, 1)
    self.br:SetSize(cornerSize, cornerSize)
    self.br:SetPosition(cornerDist, -cornerDist)
    self.br:SetRotation(45)

    -- Crosshairs
    self.crosshair_h = self:AddChild(Image("images/global.xml", "square.tex"))
    self.crosshair_h:SetTint(1, 1, 1, 0.15)
    self.crosshair_h:SetSize(50, 1)

    self.crosshair_v = self:AddChild(Image("images/global.xml", "square.tex"))
    self.crosshair_v:SetTint(1, 1, 1, 0.15)
    self.crosshair_v:SetSize(1, 50)

    -- Coordinates
    self.coords = self:AddChild(Text(UIFONT, 14))
    self.coords:SetPosition(0, -circleRadius + 25)
    self.coords:SetColour(0.8, 0.8, 0.8, 0.5)

    self:StartUpdating()
end)

function ScoutOverlay:OnUpdate(dt)
    if not self.owner or not self.owner:IsValid() then
        self:Kill()
        return
    end

    local x, y, z = self.owner.Transform:GetWorldPosition()
    self.coords:SetString(string.format("X: %.0f  Z: %.0f", x, z))
end

return ScoutOverlay
