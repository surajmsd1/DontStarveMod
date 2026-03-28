--[[
================================================================================
OBJECTIVE TRACKER WIDGET - Generic challenge display UI
================================================================================

ARCHITECTURE:
-------------
This widget is DATA-DRIVEN. It does NOT contain hardcoded challenge logic.
Instead, it receives a challenge configuration and renders it dynamically.

INHERITANCE:
------------
ObjectiveTracker extends Widget (DST's base UI class)
    Widget._ctor(self, name)   -- Parent constructor
    self:AddChild(element)     -- Inherited method to add UI elements
    self:SetPosition(x, y, z)  -- Inherited positioning
    self:Kill()                -- Inherited cleanup

HOW TO USE:
-----------
    local ObjectiveTracker = require "widgets/objectivetracker"
    local ChallengeData = require "challenges/challenge_data"

    -- Get challenge config
    local challenge = ChallengeData.GetChallenge("day_one")

    -- Create tracker with config
    local tracker = player.HUD.root:AddChild(ObjectiveTracker(player, challenge))

    -- Update progress (called by event system)
    tracker:AddProgress("grass", 1)

    -- Check if complete
    if tracker:IsComplete() then ...

UI STRUCTURE:
-------------
    ┌─────────────────────────────┐  border (slightly larger)
    │ ┌─────────────────────────┐ │  background
    │ │      Challenge Title    │ │  title text
    │ │  [✓] Objective 1: 5/5   │ │  objective texts (dynamic count)
    │ │  [ ] Objective 2: 3/10  │ │
    │ │      Reward: Item       │ │  reward text
    │ └─────────────────────────┘ │
    └─────────────────────────────┘

================================================================================
--]]

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

--------------------------------------------------------------------------------
-- CLASS DEFINITION
-- Class() is DST's inheritance helper (uses Lua metatables under the hood)
-- First arg: Parent class to inherit from
-- Second arg: Constructor function
--------------------------------------------------------------------------------
local ObjectiveTracker = Class(Widget, function(self, owner, challenge_config)
    -- Call parent constructor (required for inheritance)
    Widget._ctor(self, "ObjectiveTracker")

    -- Store references
    self.owner = owner
    self.config = challenge_config

    -- Initialize progress tracking for each objective
    -- Structure: { objective_id = current_count, ... }
    self.progress = {}
    for _, obj in ipairs(self.config.objectives) do
        self.progress[obj.id] = 0
    end

    self.completed = false

    ----------------------------------------------------------------------------
    -- SCREEN ANCHORING
    -- SetVAnchor: Vertical anchor (TOP, MIDDLE, BOTTOM)
    -- SetHAnchor: Horizontal anchor (LEFT, MIDDLE, RIGHT)
    -- SetPosition: Offset from anchor point
    ----------------------------------------------------------------------------
    self:SetVAnchor(ANCHOR_TOP)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self:SetPosition(150, -100, 0)

    ----------------------------------------------------------------------------
    -- CALCULATE DYNAMIC SIZE
    -- Height depends on number of objectives
    ----------------------------------------------------------------------------
    local num_objectives = #self.config.objectives
    local line_height = 24
    local padding = 20
    local title_height = 30
    local reward_height = 24
    local total_height = title_height + (num_objectives * line_height) + reward_height + padding
    local width = 220

    ----------------------------------------------------------------------------
    -- UI ELEMENTS (layered bottom to top)
    ----------------------------------------------------------------------------

    -- Layer 1: Border (behind everything)
    self.border = self:AddChild(Image("images/global.xml", "square.tex"))
    self.border:SetTint(0.4, 0.35, 0.25, 0.9)
    self.border:SetSize(width + 6, total_height + 6)

    -- Layer 2: Background
    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetTint(0.1, 0.08, 0.05, 0.85)
    self.bg:SetSize(width, total_height)

    -- Layer 3: Title text
    local title_y = total_height/2 - title_height/2
    self.title = self:AddChild(Text(HEADERFONT, 20))
    self.title:SetPosition(0, title_y)
    self.title:SetColour(1, 0.85, 0.4, 1)  -- Gold color
    self.title:SetString(self.config.title)

    -- Layer 4: Objective texts (dynamic based on config)
    self.objective_texts = {}
    local obj_start_y = title_y - 28
    for i, obj in ipairs(self.config.objectives) do
        local text = self:AddChild(Text(BODYTEXTFONT, 16))
        local y = obj_start_y - ((i - 1) * line_height)
        text:SetPosition(0, y)
        text:SetColour(1, 1, 1, 1)
        self.objective_texts[obj.id] = text
    end

    -- Layer 5: Reward text
    local reward_y = -total_height/2 + reward_height/2 + 5
    self.reward_text = self:AddChild(Text(BODYTEXTFONT, 14))
    self.reward_text:SetPosition(0, reward_y)
    self.reward_text:SetColour(0.6, 0.9, 0.6, 1)  -- Light green
    self.reward_text:SetString(self.config.reward.text)

    -- Initial display update
    self:UpdateDisplay()

    -- Enable per-frame updates (for animations if needed)
    self:StartUpdating()
end)

--------------------------------------------------------------------------------
-- UPDATE DISPLAY
-- Refreshes all objective texts based on current progress
--------------------------------------------------------------------------------
function ObjectiveTracker:UpdateDisplay()
    for _, obj in ipairs(self.config.objectives) do
        local current = self.progress[obj.id] or 0
        local target = obj.target
        local is_done = current >= target

        -- Format: "[✓] Text: 5/5" or "[ ] Text: 3/10"
        local check = is_done and "[OK]" or "[ ]"
        local display_text = string.format("%s " .. obj.text, check, current, target)

        -- Update text element
        local text_widget = self.objective_texts[obj.id]
        if text_widget then
            text_widget:SetString(display_text)
            -- Green if complete, white if not
            if is_done then
                text_widget:SetColour(0.4, 1, 0.4, 1)
            else
                text_widget:SetColour(1, 1, 1, 1)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- ADD PROGRESS
-- Increments progress for a specific objective
-- @param objective_id string - Which objective to update
-- @param amount number - How much to add (default 1)
--------------------------------------------------------------------------------
function ObjectiveTracker:AddProgress(objective_id, amount)
    amount = amount or 1

    if self.progress[objective_id] then
        -- Find the target for this objective
        local target = 0
        for _, obj in ipairs(self.config.objectives) do
            if obj.id == objective_id then
                target = obj.target
                break
            end
        end

        -- Increment but don't exceed target
        self.progress[objective_id] = math.min(target, self.progress[objective_id] + amount)
        self:UpdateDisplay()
        self:CheckComplete()
    end
end

--------------------------------------------------------------------------------
-- SET PROGRESS
-- Sets progress to a specific value (for syncing multiplayer state)
-- @param objective_id string - Which objective to update
-- @param value number - Value to set
--------------------------------------------------------------------------------
function ObjectiveTracker:SetProgress(objective_id, value)
    if self.progress[objective_id] ~= nil then
        self.progress[objective_id] = value
        self:UpdateDisplay()
    end
end

--------------------------------------------------------------------------------
-- IS COMPLETE
-- Checks if all objectives are met
-- @return boolean
--------------------------------------------------------------------------------
function ObjectiveTracker:IsComplete()
    for _, obj in ipairs(self.config.objectives) do
        if (self.progress[obj.id] or 0) < obj.target then
            return false
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- CHECK COMPLETE
-- Called after progress updates to see if challenge is done
-- Grants reward and updates UI if complete
--------------------------------------------------------------------------------
function ObjectiveTracker:CheckComplete()
    if self.completed then return end

    if self:IsComplete() then
        self.completed = true

        -- Update UI to show completion
        self.title:SetString("COMPLETE!")
        self.title:SetColour(0.4, 1, 0.4, 1)
        self.reward_text:SetString("Reward granted!")

        -- Grant reward to player
        self:GrantReward()

        -- Hide after delay
        if self.owner and self.owner.DoTaskInTime then
            self.owner:DoTaskInTime(5, function()
                if self:IsValid() then
                    self:Kill()
                end
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- GRANT REWARD
-- Gives the configured reward item(s) to the player
--------------------------------------------------------------------------------
function ObjectiveTracker:GrantReward()
    if not self.owner or not self.owner.components then return end
    if not self.owner.components.inventory then return end

    local reward = self.config.reward

    -- Grant primary reward
    for i = 1, (reward.count or 1) do
        local item = SpawnPrefab(reward.prefab)
        if item then
            self.owner.components.inventory:GiveItem(item)
        end
    end

    -- Grant bonus rewards if any
    if reward.bonus then
        for _, prefab in ipairs(reward.bonus) do
            local item = SpawnPrefab(prefab)
            if item then
                self.owner.components.inventory:GiveItem(item)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- GET PROGRESS
-- Returns current progress for an objective
-- @param objective_id string
-- @return number
--------------------------------------------------------------------------------
function ObjectiveTracker:GetProgress(objective_id)
    return self.progress[objective_id] or 0
end

--------------------------------------------------------------------------------
-- GET ALL PROGRESS
-- Returns full progress table (for multiplayer sync)
-- @return table
--------------------------------------------------------------------------------
function ObjectiveTracker:GetAllProgress()
    return self.progress
end

--------------------------------------------------------------------------------
-- ON UPDATE (called every frame when StartUpdating() is active)
-- Currently unused but available for animations
--------------------------------------------------------------------------------
function ObjectiveTracker:OnUpdate(dt)
    -- Could add pulse animation on progress, etc.
end

return ObjectiveTracker
