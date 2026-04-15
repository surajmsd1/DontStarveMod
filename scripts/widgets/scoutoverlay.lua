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
    local circleRadius = 380  -- Visible circle radius (bigger = more visible)
    local bigSize = 2000      -- Big enough to cover any screen
    -- Mask alpha: < 1.0 lets world + other HUD (e.g. minimap mods) show through
    -- while still giving a "looking through a spyglass" vignette darkening.
    local maskAlpha = 0.7

    -- Top bar (above the circle)
    self.top = self:AddChild(Image("images/global.xml", "square.tex"))
    self.top:SetTint(0, 0, 0, maskAlpha)
    self.top:SetSize(bigSize, bigSize)
    self.top:SetPosition(0, circleRadius + bigSize/2)

    -- Bottom bar (below the circle)
    self.bottom = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bottom:SetTint(0, 0, 0, maskAlpha)
    self.bottom:SetSize(bigSize, bigSize)
    self.bottom:SetPosition(0, -(circleRadius + bigSize/2))

    -- Left bar (left of the circle)
    self.left = self:AddChild(Image("images/global.xml", "square.tex"))
    self.left:SetTint(0, 0, 0, maskAlpha)
    self.left:SetSize(bigSize, bigSize)
    self.left:SetPosition(-(circleRadius + bigSize/2), 0)

    -- Right bar (right of the circle)
    self.right = self:AddChild(Image("images/global.xml", "square.tex"))
    self.right:SetTint(0, 0, 0, maskAlpha)
    self.right:SetSize(bigSize, bigSize)
    self.right:SetPosition(circleRadius + bigSize/2, 0)

    -- Corner pieces to round the square hole into a circle
    -- These are rotated 45 degrees to clip the corners
    local cornerSize = circleRadius * 1.2
    local cornerDist = circleRadius * 0.92

    self.tl = self:AddChild(Image("images/global.xml", "square.tex"))
    self.tl:SetTint(0, 0, 0, maskAlpha)
    self.tl:SetSize(cornerSize, cornerSize)
    self.tl:SetPosition(-cornerDist, cornerDist)
    self.tl:SetRotation(45)

    self.tr = self:AddChild(Image("images/global.xml", "square.tex"))
    self.tr:SetTint(0, 0, 0, maskAlpha)
    self.tr:SetSize(cornerSize, cornerSize)
    self.tr:SetPosition(cornerDist, cornerDist)
    self.tr:SetRotation(45)

    self.bl = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bl:SetTint(0, 0, 0, maskAlpha)
    self.bl:SetSize(cornerSize, cornerSize)
    self.bl:SetPosition(-cornerDist, -cornerDist)
    self.bl:SetRotation(45)

    self.br = self:AddChild(Image("images/global.xml", "square.tex"))
    self.br:SetTint(0, 0, 0, maskAlpha)
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

    -- Distance bar (at bottom of visible circle)
    local barWidth = 160
    local barHeight = 12
    local barY = -circleRadius + 55

    -- Bar frame/border
    self.bar_border = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bar_border:SetTint(0.3, 0.25, 0.2, 0.9)
    self.bar_border:SetSize(barWidth + 6, barHeight + 6)
    self.bar_border:SetPosition(0, barY)

    -- Bar background
    self.bar_bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bar_bg:SetTint(0.15, 0.12, 0.1, 0.9)
    self.bar_bg:SetSize(barWidth, barHeight)
    self.bar_bg:SetPosition(0, barY)

    -- Bar fill (starts empty, fills as you travel)
    self.bar_fill = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bar_fill:SetTint(0.3, 0.8, 0.3, 1)  -- Green initially
    self.bar_fill:SetSize(0, barHeight - 2)
    self.bar_fill:SetPosition(-barWidth/2, barY)

    -- Distance label
    self.dist_label = self:AddChild(Text(UIFONT, 12))
    self.dist_label:SetPosition(0, barY + 15)
    self.dist_label:SetColour(0.9, 0.85, 0.7, 0.8)
    self.dist_label:SetString("TETHER")

    -- Store bar dimensions for updates
    self.barWidth = barWidth
    self.barHeight = barHeight
    self.barY = barY
    self.distPct = 0
    self.maxDistance = 150  -- Must match prefab SCOUT_MAX_DISTANCE

    -- Store starting position for distance calc
    local x, y, z = self.owner.Transform:GetWorldPosition()
    self.startPos = {x = x, z = z}

    self:StartUpdating()
end)

function ScoutOverlay:UpdateDistanceBar(pct, distance)
    self.distPct = pct
    local fillWidth = self.barWidth * pct

    -- Update fill size and position (anchored left)
    self.bar_fill:SetSize(fillWidth, self.barHeight - 2)
    self.bar_fill:SetPosition(-self.barWidth/2 + fillWidth/2, self.barY)

    -- Color gradient: green -> yellow -> red
    local r, g, b
    if pct < 0.5 then
        -- Green to yellow
        r = pct * 2
        g = 0.8
        b = 0.3 * (1 - pct * 2)
    else
        -- Yellow to red
        r = 1
        g = 0.8 * (1 - (pct - 0.5) * 2)
        b = 0
    end
    self.bar_fill:SetTint(r, g, b, 1)

    -- Update label
    local remaining = math.floor((1 - pct) * 150)  -- Approximate remaining distance
    self.dist_label:SetString(string.format("TETHER: %dm", remaining))
end

function ScoutOverlay:OnUpdate(dt)
    if not self.owner or not self.owner:IsValid() then
        self:Kill()
        return
    end

    local x, y, z = self.owner.Transform:GetWorldPosition()
    self.coords:SetString(string.format("X: %.0f  Z: %.0f", x, z))

    -- Calculate distance from start position
    if self.startPos then
        local dx = x - self.startPos.x
        local dz = z - self.startPos.z
        local dist = math.sqrt(dx * dx + dz * dz)
        local pct = math.min(1, dist / self.maxDistance)
        self:UpdateDistanceBar(pct, dist)
    end
end

return ScoutOverlay
