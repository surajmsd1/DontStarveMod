-- Scout Mode Overlay Widget
-- Creates a circular vignette effect to simulate looking through binoculars/telescope

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ScoutOverlay = Class(Widget, function(self, owner)
    Widget._ctor(self, "ScoutOverlay")
    self.owner = owner

    -- Full screen root
    self:SetVAnchor(ANCHOR_MIDDLE)
    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- Create dark vignette edges (4 dark bars around a circle)
    -- Since DST doesn't have shader support in mods, we simulate with overlays

    -- Dark overlay for screen edges
    self.darkness = self:AddChild(Image("images/global.xml", "square.tex"))
    self.darkness:SetTint(0, 0, 0, 0.7)
    self.darkness:SetSize(2000, 2000)

    -- "Scope" circle in center - we'll use a lighter overlay
    -- In reality, we want a hole. DST mods can't do true masking,
    -- so we create a visible circle indicating the scope area

    -- Crosshair effect
    self.crosshair_h = self:AddChild(Image("images/global.xml", "square.tex"))
    self.crosshair_h:SetTint(0.5, 0.5, 0.5, 0.5)
    self.crosshair_h:SetSize(400, 2)

    self.crosshair_v = self:AddChild(Image("images/global.xml", "square.tex"))
    self.crosshair_v:SetTint(0.5, 0.5, 0.5, 0.5)
    self.crosshair_v:SetSize(2, 400)

    -- Scope ring (circular indicator)
    -- We'll use the circle animation or text to simulate
    self.scope_text = self:AddChild(Text(UIFONT, 30))
    self.scope_text:SetPosition(0, 300)
    self.scope_text:SetString("SCOUT MODE - Press SPACE to Drop In")
    self.scope_text:SetColour(1, 0.9, 0.5, 1)

    -- Coordinates display
    self.coords = self:AddChild(Text(UIFONT, 20))
    self.coords:SetPosition(0, -280)
    self.coords:SetColour(0.8, 0.8, 0.8, 0.8)

    -- Speed indicator
    self.speed_text = self:AddChild(Text(UIFONT, 18))
    self.speed_text:SetPosition(0, -310)
    self.speed_text:SetColour(0.6, 0.8, 1, 0.8)
    self.speed_text:SetString("WASD to move | Speed: 50x")

    -- Pulsing animation state
    self.pulse = 0
    self.is_animating = true

    -- Start update loop
    self:StartUpdating()
end)

function ScoutOverlay:OnUpdate(dt)
    if not self.owner or not self.owner:IsValid() then
        self:Kill()
        return
    end

    -- Update coordinates
    local x, y, z = self.owner.Transform:GetWorldPosition()
    self.coords:SetString(string.format("Position: %.0f, %.0f", x, z))

    -- Pulse animation for scope elements
    self.pulse = self.pulse + dt * 2
    local alpha = 0.5 + math.sin(self.pulse) * 0.2
    self.crosshair_h:SetTint(0.5, 0.5, 0.5, alpha)
    self.crosshair_v:SetTint(0.5, 0.5, 0.5, alpha)
end

function ScoutOverlay:Kill()
    self.is_animating = false
    Widget.Kill(self)
end

return ScoutOverlay
