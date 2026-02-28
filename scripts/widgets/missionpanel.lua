-- Mission Panel Widget
-- Collapsible HUD panel showing shared mission progress
-- DST-themed using existing game textures and fonts

local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"

-- Color palette (DST-themed)
local COLORS = {
    TITLE = { 1, 0.9, 0.5, 1 },           -- Golden
    HEADER_BG = { 0.15, 0.12, 0.1, 0.9 },  -- Dark brown
    BODY_BG = { 0.1, 0.08, 0.06, 0.85 },   -- Darker brown
    TEXT = { 0.9, 0.85, 0.75, 1 },          -- Parchment
    DIM_TEXT = { 0.6, 0.55, 0.45, 1 },      -- Dimmed parchment
    PROGRESS_BG = { 0.2, 0.18, 0.15, 1 },   -- Dark
    PROGRESS_FILL = { 0.4, 0.7, 0.3, 1 },   -- Green
    PROGRESS_BOSS = { 0.8, 0.2, 0.2, 1 },   -- Red
    COMPLETE = { 0.3, 0.8, 0.3, 1 },        -- Bright green
    FAILED = { 0.8, 0.3, 0.3, 1 },          -- Red
    TIMER_WARN = { 1, 0.6, 0.2, 1 },        -- Orange
    CATEGORY_CHALLENGE = { 0.9, 0.7, 0.3, 1 },
    CATEGORY_BOSS = { 0.8, 0.25, 0.25, 1 },
    CATEGORY_GATHER = { 0.5, 0.8, 0.4, 1 },
    CATEGORY_EXPLORE = { 0.4, 0.7, 0.9, 1 },
}

local PANEL_WIDTH = 280
local HEADER_HEIGHT = 32
local MISSION_SPACING = 8
local OBJECTIVE_HEIGHT = 22
local PROGRESS_BAR_WIDTH = 140
local PROGRESS_BAR_HEIGHT = 10

local MissionPanel = Class(Widget, function(self, owner)
    Widget._ctor(self, "MissionPanel")
    self.owner = owner
    self.collapsed = false
    self.missions = {}          -- cached mission data from server
    self.mission_widgets = {}   -- mission_id -> widget references
    self.recent_finished = {}

    -- Root positioning (top-right of screen)
    self:SetHAnchor(ANCHOR_RIGHT)
    self:SetVAnchor(ANCHOR_TOP)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self:SetPosition(-PANEL_WIDTH / 2 - 10, -20, 0)

    -- Main container
    self.container = self:AddChild(Widget("Container"))

    -- Header bar (always visible)
    self:_BuildHeader()

    -- Body container (collapsible)
    self.body = self.container:AddChild(Widget("Body"))
    self.body:SetPosition(0, -HEADER_HEIGHT / 2, 0)

    -- "No missions" text
    self.empty_text = self.body:AddChild(Text(BODYTEXTFONT, 16))
    self.empty_text:SetPosition(0, -20)
    self.empty_text:SetString("No active missions")
    self.empty_text:SetColour(unpack(COLORS.DIM_TEXT))

    -- Start update loop for timers
    self:StartUpdating()
end)

function MissionPanel:_BuildHeader()
    -- Header background
    self.header_bg = self.container:AddChild(Image("images/global.xml", "square.tex"))
    self.header_bg:SetSize(PANEL_WIDTH, HEADER_HEIGHT)
    self.header_bg:SetTint(unpack(COLORS.HEADER_BG))

    -- Header icon (small star/skull icon)
    self.header_icon = self.container:AddChild(Text(TITLEFONT, 18))
    self.header_icon:SetPosition(-PANEL_WIDTH / 2 + 18, 1)
    self.header_icon:SetString("*")
    self.header_icon:SetColour(unpack(COLORS.TITLE))

    -- Title text
    self.header_title = self.container:AddChild(Text(TITLEFONT, 18))
    self.header_title:SetPosition(-15, 1)
    self.header_title:SetString("MISSIONS")
    self.header_title:SetColour(unpack(COLORS.TITLE))

    -- Mission count badge
    self.header_count = self.container:AddChild(Text(BODYTEXTFONT, 14))
    self.header_count:SetPosition(PANEL_WIDTH / 2 - 50, 1)
    self.header_count:SetColour(unpack(COLORS.DIM_TEXT))
    self.header_count:SetString("0 active")

    -- Collapse/expand toggle (clickable area over the whole header)
    self.toggle_btn = self.container:AddChild(ImageButton(
        "images/global.xml", "square.tex",  -- normal
        "images/global.xml", "square.tex",  -- focus
        "images/global.xml", "square.tex",  -- disabled
        "images/global.xml", "square.tex",  -- down
        "images/global.xml", "square.tex"   -- selected
    ))
    self.toggle_btn:SetPosition(0, 0)
    self.toggle_btn:ForceImageSize(PANEL_WIDTH, HEADER_HEIGHT)
    self.toggle_btn:SetTint(1, 1, 1, 0)  -- Invisible button over header
    self.toggle_btn:SetOnClick(function() self:ToggleCollapse() end)

    -- Collapse arrow
    self.collapse_arrow = self.container:AddChild(Text(BODYTEXTFONT, 16))
    self.collapse_arrow:SetPosition(PANEL_WIDTH / 2 - 16, 1)
    self.collapse_arrow:SetString("v")
    self.collapse_arrow:SetColour(unpack(COLORS.DIM_TEXT))
end

function MissionPanel:ToggleCollapse()
    self.collapsed = not self.collapsed
    if self.collapsed then
        self.body:Hide()
        self.collapse_arrow:SetString(">")
    else
        self.body:Show()
        self.collapse_arrow:SetString("v")
    end
    if self.owner and self.owner.SoundEmitter then
        self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click_move")
    end
end

-- Update the panel with mission data from the server
-- snapshot: array of mission tables from MissionTracker:GetMissionSnapshot()
function MissionPanel:SetMissions(snapshot, recent)
    self.missions = snapshot or {}
    self.recent_finished = recent or {}
    self:_RebuildBody()
end

function MissionPanel:_RebuildBody()
    -- Clear existing mission widgets
    for _, w in pairs(self.mission_widgets) do
        if w.root then w.root:Kill() end
    end
    self.mission_widgets = {}

    -- Update header count
    local count = #self.missions
    self.header_count:SetString(count .. " active")

    -- Show/hide empty text
    if count == 0 and #self.recent_finished == 0 then
        self.empty_text:Show()
    else
        self.empty_text:Hide()
    end

    -- Build each mission card
    local yOffset = -10
    for _, mission in ipairs(self.missions) do
        local widget_data = self:_BuildMissionCard(mission, yOffset)
        self.mission_widgets[mission.id] = widget_data
        yOffset = yOffset - widget_data.height - MISSION_SPACING
    end

    -- Show recently completed/failed
    for _, finished in ipairs(self.recent_finished) do
        local w = self:_BuildFinishedCard(finished, yOffset)
        yOffset = yOffset - 30 - MISSION_SPACING
    end

    -- Background for body
    if self.body_bg then self.body_bg:Kill() end
    local totalHeight = math.abs(yOffset) + 10
    if totalHeight > 20 then
        self.body_bg = self.body:AddChild(Image("images/global.xml", "square.tex"))
        self.body_bg:SetSize(PANEL_WIDTH, totalHeight)
        self.body_bg:SetPosition(0, -totalHeight / 2 + 5)
        self.body_bg:SetTint(unpack(COLORS.BODY_BG))
        self.body_bg:MoveToBack()
    end
end

function MissionPanel:_BuildMissionCard(mission, yOffset)
    local card = self.body:AddChild(Widget("MissionCard_" .. mission.id))
    local cardHeight = 0

    -- Mission name with category color
    local catColor = COLORS["CATEGORY_" .. string.upper(mission.category or "challenge")] or COLORS.TITLE
    local nameText = card:AddChild(Text(TITLEFONT, 16))
    nameText:SetPosition(0, yOffset)
    nameText:SetString(mission.name)
    nameText:SetColour(unpack(catColor))
    cardHeight = cardHeight + 20

    -- Timer if applicable
    if mission.time_remaining then
        local timerText = card:AddChild(Text(BODYTEXTFONT, 13))
        timerText:SetPosition(PANEL_WIDTH / 2 - 45, yOffset)
        local mins = math.floor(mission.time_remaining / 60)
        local secs = math.floor(mission.time_remaining % 60)
        timerText:SetString(string.format("%d:%02d", mins, secs))
        if mission.time_remaining < 60 then
            timerText:SetColour(unpack(COLORS.TIMER_WARN))
        else
            timerText:SetColour(unpack(COLORS.DIM_TEXT))
        end
        -- Store reference for live updates
        card._timer_text = timerText
        card._time_remaining = mission.time_remaining
    end

    -- Objectives
    for _, obj in ipairs(mission.objectives or {}) do
        yOffset = yOffset - OBJECTIVE_HEIGHT
        cardHeight = cardHeight + OBJECTIVE_HEIGHT

        -- Objective row
        local objRow = card:AddChild(Widget("ObjRow"))
        objRow:SetPosition(0, yOffset)

        -- Check mark or bullet
        local marker = objRow:AddChild(Text(BODYTEXTFONT, 14))
        marker:SetPosition(-PANEL_WIDTH / 2 + 20, 0)
        if obj.completed then
            marker:SetString("+")
            marker:SetColour(unpack(COLORS.COMPLETE))
        else
            marker:SetString("-")
            marker:SetColour(unpack(COLORS.DIM_TEXT))
        end

        -- Label
        local label = objRow:AddChild(Text(BODYTEXTFONT, 13))
        label:SetPosition(-PANEL_WIDTH / 2 + 85, 0)
        label:SetHAlign(ANCHOR_LEFT)
        local labelStr = obj.label
        -- Truncate long labels
        if #labelStr > 16 then
            labelStr = string.sub(labelStr, 1, 14) .. ".."
        end
        label:SetString(labelStr)
        if obj.completed then
            label:SetColour(unpack(COLORS.COMPLETE))
        else
            label:SetColour(unpack(COLORS.TEXT))
        end

        -- Progress: "3/10" text
        local progText = objRow:AddChild(Text(BODYTEXTFONT, 13))
        progText:SetPosition(PANEL_WIDTH / 2 - 35, 0)
        progText:SetString(obj.current .. "/" .. obj.required)
        if obj.completed then
            progText:SetColour(unpack(COLORS.COMPLETE))
        else
            progText:SetColour(unpack(COLORS.TEXT))
        end

        -- Progress bar
        local barBg = objRow:AddChild(Image("images/global.xml", "square.tex"))
        barBg:SetPosition(25, 0)
        barBg:SetSize(PROGRESS_BAR_WIDTH, PROGRESS_BAR_HEIGHT)
        barBg:SetTint(unpack(COLORS.PROGRESS_BG))

        local pct = obj.required > 0 and (obj.current / obj.required) or 0
        pct = math.min(1, pct)
        if pct > 0 then
            local barFill = objRow:AddChild(Image("images/global.xml", "square.tex"))
            local fillWidth = PROGRESS_BAR_WIDTH * pct
            barFill:SetSize(fillWidth, PROGRESS_BAR_HEIGHT)
            -- Offset to left-align within the bar
            barFill:SetPosition(25 - (PROGRESS_BAR_WIDTH - fillWidth) / 2, 0)
            if obj.type == "boss" then
                barFill:SetTint(unpack(COLORS.PROGRESS_BOSS))
            else
                barFill:SetTint(unpack(COLORS.PROGRESS_FILL))
            end
        end
    end

    -- Boss health bar (if boss mission with boss entity)
    if mission.boss_health then
        yOffset = yOffset - OBJECTIVE_HEIGHT - 4
        cardHeight = cardHeight + OBJECTIVE_HEIGHT + 4

        local bossRow = card:AddChild(Widget("BossRow"))
        bossRow:SetPosition(0, yOffset)

        local bossLabel = bossRow:AddChild(Text(TITLEFONT, 13))
        bossLabel:SetPosition(-PANEL_WIDTH / 2 + 50, 0)
        bossLabel:SetString("BOSS HP")
        bossLabel:SetColour(unpack(COLORS.PROGRESS_BOSS))

        -- Boss HP bar
        local barBg = bossRow:AddChild(Image("images/global.xml", "square.tex"))
        barBg:SetPosition(30, 0)
        barBg:SetSize(PROGRESS_BAR_WIDTH + 20, PROGRESS_BAR_HEIGHT + 2)
        barBg:SetTint(unpack(COLORS.PROGRESS_BG))

        local hpPct = mission.boss_health.max > 0
            and (mission.boss_health.current / mission.boss_health.max) or 0
        hpPct = math.max(0, math.min(1, hpPct))
        if hpPct > 0 then
            local fillW = (PROGRESS_BAR_WIDTH + 20) * hpPct
            local barFill = bossRow:AddChild(Image("images/global.xml", "square.tex"))
            barFill:SetSize(fillW, PROGRESS_BAR_HEIGHT + 2)
            barFill:SetPosition(30 - ((PROGRESS_BAR_WIDTH + 20) - fillW) / 2, 0)
            barFill:SetTint(unpack(COLORS.PROGRESS_BOSS))
        end

        local hpText = bossRow:AddChild(Text(BODYTEXTFONT, 12))
        hpText:SetPosition(PANEL_WIDTH / 2 - 35, 0)
        hpText:SetString(math.floor(mission.boss_health.current) .. "/" .. math.floor(mission.boss_health.max))
        hpText:SetColour(unpack(COLORS.TEXT))
    end

    cardHeight = cardHeight + 5  -- padding
    return { root = card, height = cardHeight }
end

function MissionPanel:_BuildFinishedCard(finished, yOffset)
    local card = self.body:AddChild(Widget("Finished_" .. finished.id))

    local text = card:AddChild(Text(BODYTEXTFONT, 14))
    text:SetPosition(0, yOffset)

    if finished.state == "completed" then
        text:SetString("+ " .. finished.name .. " - Complete!")
        text:SetColour(unpack(COLORS.COMPLETE))
    else
        text:SetString("x " .. finished.name .. " - Failed")
        text:SetColour(unpack(COLORS.FAILED))
    end

    return card
end

function MissionPanel:OnUpdate(dt)
    if not self.owner or not self.owner:IsValid() then
        return
    end

    -- Update timers on visible missions
    if not self.collapsed then
        for id, w in pairs(self.mission_widgets) do
            if w.root and w.root._timer_text and w.root._time_remaining then
                w.root._time_remaining = w.root._time_remaining - dt
                local t = math.max(0, w.root._time_remaining)
                local mins = math.floor(t / 60)
                local secs = math.floor(t % 60)
                w.root._timer_text:SetString(string.format("%d:%02d", mins, secs))
                if t < 60 then
                    w.root._timer_text:SetColour(unpack(COLORS.TIMER_WARN))
                end
            end
        end
    end
end

-- Show/hide the panel entirely (e.g., hide during loading screens)
function MissionPanel:SetVisible(visible)
    if visible then
        self:Show()
    else
        self:Hide()
    end
end

function MissionPanel:Kill()
    self.mission_widgets = {}
    Widget.Kill(self)
end

return MissionPanel
