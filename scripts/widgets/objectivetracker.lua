-- Simple Objective Tracker Widget
-- Shows current mission objectives in corner

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ObjectiveTracker = Class(Widget, function(self, owner)
    Widget._ctor(self, "ObjectiveTracker")
    self.owner = owner

    -- Anchor to top-left of screen
    self:SetVAnchor(ANCHOR_TOP)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self:SetPosition(150, -100, 0)

    -- Panel background with subtle border effect
    self.border = self:AddChild(Image("images/global.xml", "square.tex"))
    self.border:SetTint(0.4, 0.35, 0.25, 0.9)  -- Brown/tan border
    self.border:SetSize(226, 126)

    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetTint(0.1, 0.08, 0.05, 0.85)  -- Dark brown inner
    self.bg:SetSize(220, 120)

    -- Title
    self.title = self:AddChild(Text(HEADERFONT, 22))
    self.title:SetPosition(0, 40)
    self.title:SetColour(1, 0.85, 0.4, 1)  -- Gold
    self.title:SetString("Day One Survival")

    -- Objective 1: Grass
    self.grass_text = self:AddChild(Text(BODYTEXTFONT, 18))
    self.grass_text:SetPosition(0, 12)
    self.grass_text:SetColour(1, 1, 1, 1)

    -- Objective 2: Twigs
    self.twigs_text = self:AddChild(Text(BODYTEXTFONT, 18))
    self.twigs_text:SetPosition(0, -12)
    self.twigs_text:SetColour(1, 1, 1, 1)

    -- Reward line
    self.reward_text = self:AddChild(Text(BODYTEXTFONT, 16))
    self.reward_text:SetPosition(0, -38)
    self.reward_text:SetColour(0.6, 0.9, 0.6, 1)  -- Light green
    self.reward_text:SetString("Reward: Backpack")

    -- Track progress
    self.grass_count = 0
    self.twigs_count = 0
    self.completed = false

    self:UpdateDisplay()
    self:StartUpdating()
end)

function ObjectiveTracker:UpdateDisplay()
    local grass_check = self.grass_count >= 10 and "[OK]" or "[ ]"
    local twigs_check = self.twigs_count >= 10 and "[OK]" or "[ ]"

    local grass_color = self.grass_count >= 10 and {0.4, 1, 0.4, 1} or {1, 1, 1, 1}
    local twigs_color = self.twigs_count >= 10 and {0.4, 1, 0.4, 1} or {1, 1, 1, 1}

    self.grass_text:SetString(string.format("%s Grass: %d/10", grass_check, self.grass_count))
    self.grass_text:SetColour(unpack(grass_color))

    self.twigs_text:SetString(string.format("%s Twigs: %d/10", twigs_check, self.twigs_count))
    self.twigs_text:SetColour(unpack(twigs_color))
end

function ObjectiveTracker:AddGrass(amount)
    self.grass_count = math.min(10, self.grass_count + (amount or 1))
    self:UpdateDisplay()
    self:CheckComplete()
end

function ObjectiveTracker:AddTwigs(amount)
    self.twigs_count = math.min(10, self.twigs_count + (amount or 1))
    self:UpdateDisplay()
    self:CheckComplete()
end

function ObjectiveTracker:CheckComplete()
    if not self.completed and self.grass_count >= 10 and self.twigs_count >= 10 then
        self.completed = true
        self.title:SetString("COMPLETE!")
        self.title:SetColour(0.4, 1, 0.4, 1)
        self.reward_text:SetString("Backpack granted!")

        -- Give reward
        if self.owner and self.owner.components and self.owner.components.inventory then
            local backpack = SpawnPrefab("backpack")
            if backpack then
                self.owner.components.inventory:GiveItem(backpack)
            end
        end

        -- Hide after delay
        self.owner:DoTaskInTime(5, function()
            if self:IsValid() then
                self:Kill()
            end
        end)
    end
end

function ObjectiveTracker:OnUpdate(dt)
    -- Could add animations here
end

return ObjectiveTracker
