-- Tower Network Screen
-- Right-click a lookout tower to see discovered towers and fast-travel

local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local Image = require "widgets/image"

local TELEPORT_SANITY_COST = 15

local function AngleToCardinal(angle)
    local deg = math.deg(angle)
    if     deg >= -22.5  and deg < 22.5   then return "E"
    elseif deg >= 22.5   and deg < 67.5   then return "SE"
    elseif deg >= 67.5   and deg < 112.5  then return "S"
    elseif deg >= 112.5  and deg < 157.5  then return "SW"
    elseif deg >= 157.5  or  deg < -157.5 then return "W"
    elseif deg >= -157.5 and deg < -112.5 then return "NW"
    elseif deg >= -112.5 and deg < -67.5  then return "N"
    else                                       return "NE"
    end
end

local function TowerKey(tower)
    if not (tower and tower.Transform) then return nil end
    local tx, _, tz = tower.Transform:GetWorldPosition()
    return math.floor(tx) .. "_" .. math.floor(tz)
end

local function GetTowerDisplayName(tower)
    -- Preferred: use the authoritative name from the server-synced shared
    -- table. Every tower is registered there on activation, so this is
    -- reliable for both the current tower and discovered peers.
    local key = TowerKey(tower)
    local shared = MysteryBox_SharedTowers
    if key and shared and shared[key] and shared[key].name then
        return shared[key].name
    end

    -- Fallback: parse the generated name from the debug string tag list
    -- (format: "towername_Wilson_s_Marsh").
    if tower.GetDebugString then
        local debugStr = tower:GetDebugString()
        if debugStr then
            local tagName = debugStr:match("towername_([%w_]+)")
            if tagName then
                local name = tagName:gsub("_", " ")
                name = name:gsub("(%w) s ", "%1's ")
                return name
            end
        end
    end

    -- Last resort: position-based name
    if tower.Transform then
        local x, _, z = tower.Transform:GetWorldPosition()
        local dir = ""
        if z > 0 then dir = dir .. "North " else dir = dir .. "South " end
        if x > 0 then dir = dir .. "East" else dir = dir .. "West" end
        return dir .. " Tower"
    end

    return "Lookout Tower"
end

local TowerNetworkScreen = Class(Screen, function(self, owner, tower)
    Screen._ctor(self, "TowerNetworkScreen")
    self.owner = owner
    self.tower = tower

    -- Full-screen dark overlay (DST standard for popup screens)
    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.black:SetSize(2000, 2000)
    self.black:SetTint(0, 0, 0, 0.75)

    -- Root container for panel content
    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- Panel outer border (DST brown frame style)
    local panelW, panelH = 380, 420
    self.frame = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.frame:SetTint(0.25, 0.2, 0.15, 0.95)
    self.frame:SetSize(panelW + 4, panelH + 4)

    -- Panel background (dark, slightly warm)
    self.bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetTint(0.12, 0.1, 0.08, 0.95)
    self.bg:SetSize(panelW, panelH)

    -- "You are here" label above the title, so the current tower's identity
    -- is obvious (useful for knowing which tower to come back to).
    self.here_label = self.root:AddChild(Text(BODYTEXTFONT, 14))
    self.here_label:SetPosition(0, panelH/2 - 14)
    self.here_label:SetString("You are at")
    self.here_label:SetColour(0.55, 0.5, 0.4, 0.8)

    -- Title: the current tower's name
    local towerName = GetTowerDisplayName(tower)
    self.title = self.root:AddChild(Text(TITLEFONT, 26))
    self.title:SetPosition(0, panelH/2 - 36)
    self.title:SetString(string.upper(towerName))
    self.title:SetColour(0.9, 0.8, 0.6, 1)

    -- Divider
    self.divider = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.divider:SetTint(0.3, 0.25, 0.18, 0.6)
    self.divider:SetSize(panelW - 40, 1)
    self.divider:SetPosition(0, panelH/2 - 56)

    -- Subtitle
    self.subtitle = self.root:AddChild(Text(BODYTEXTFONT, 16))
    self.subtitle:SetPosition(0, panelH/2 - 71)
    self.subtitle:SetString("Tower Network")
    self.subtitle:SetColour(0.6, 0.55, 0.45, 0.8)

    -- Sanity cost note
    self.cost = self.root:AddChild(Text(BODYTEXTFONT, 14))
    self.cost:SetPosition(0, panelH/2 - 88)
    self.cost:SetString("Travel cost: " .. TELEPORT_SANITY_COST .. " Sanity")
    self.cost:SetColour(0.55, 0.4, 0.6, 0.7)

    -- Scroll state + config (used by BuildTowerList and scroll controls)
    self.row_height = 42
    self.max_rows = 6
    self.scroll_offset = 0

    -- Tower list area: row holder (cleared on each render) + persistent
    -- scroll controls (arrows + page indicator).
    self.list = self.root:AddChild(Widget("list"))
    self.list:SetPosition(0, -10)

    self.row_holder = self.list:AddChild(Widget("row_holder"))

    local listVisibleH = self.max_rows * self.row_height

    -- Compact arrow buttons. Both use the same font, size, and forced image
    -- size so the up/down glyphs render symmetrically. ASCII '^' and 'v' are
    -- used (not unicode triangles) because BUTTONFONT renders them
    -- consistently — unicode arrows fell back to a different font and the
    -- two glyphs ended up different sizes.
    self.scroll_up = self.list:AddChild(ImageButton())
    self.scroll_up:SetPosition(165, listVisibleH/2 - 4)
    self.scroll_up:ForceImageSize(22, 22)
    self.scroll_up:SetFont(BUTTONFONT)
    self.scroll_up:SetTextSize(18)
    self.scroll_up:SetText("^")
    self.scroll_up:SetOnClick(function() self:ScrollBy(-1) end)

    self.scroll_down = self.list:AddChild(ImageButton())
    self.scroll_down:SetPosition(165, -listVisibleH/2 + 4)
    self.scroll_down:ForceImageSize(22, 22)
    self.scroll_down:SetFont(BUTTONFONT)
    self.scroll_down:SetTextSize(18)
    self.scroll_down:SetText("v")
    self.scroll_down:SetOnClick(function() self:ScrollBy(1) end)

    self.scroll_indicator = self.list:AddChild(Text(BODYTEXTFONT, 12))
    self.scroll_indicator:SetPosition(165, 0)
    self.scroll_indicator:SetColour(0.55, 0.5, 0.4, 0.8)

    self:BuildTowerList()

    -- Bottom buttons
    local btnY = -panelH/2 + 30

    self.close_btn = self.root:AddChild(ImageButton())
    self.close_btn:SetPosition(0, btnY)
    self.close_btn:SetScale(0.7)
    self.close_btn:SetText("Close")
    self.close_btn:SetFont(BUTTONFONT)
    self.close_btn:SetOnClick(function() self:Close() end)

    -- Focus for gamepad support
    self.default_focus = self.close_btn
end)

function TowerNetworkScreen:BuildTowerList()
    local px, _, pz = self.owner.Transform:GetWorldPosition()
    local currentKey = TowerKey(self.tower)

    -- Read from the shared client-side mirror kept in sync by server RPCs.
    local discoveredTowers = MysteryBox_SharedTowers or {}

    local towerList = {}
    for key, data in pairs(discoveredTowers) do
        if key ~= currentKey then
            local dx = data.x - px
            local dz = data.z - pz
            local dist = math.sqrt(dx * dx + dz * dz)
            local angle = math.atan2(dz, dx)
            table.insert(towerList, {
                key = key,
                name = data.name,
                x = data.x,
                z = data.z,
                dist = dist,
                dir = AngleToCardinal(angle),
            })
        end
    end
    table.sort(towerList, function(a, b) return a.dist < b.dist end)

    self.tower_list = towerList
    self.scroll_offset = 0
    self:RenderVisibleRows()
end

function TowerNetworkScreen:RenderVisibleRows()
    self.row_holder:KillAllChildren()

    local towerList = self.tower_list or {}
    local total = #towerList
    local rowH = self.row_height
    local maxRows = self.max_rows

    -- Empty-state message: hide scroll controls and show hint.
    if total == 0 then
        self.scroll_up:Hide()
        self.scroll_down:Hide()
        self.scroll_indicator:SetString("")

        local msg = self.row_holder:AddChild(Text(BODYTEXTFONT, 18))
        msg:SetPosition(0, 20)
        msg:SetString("No other towers discovered yet.")
        msg:SetColour(0.5, 0.45, 0.4, 0.7)

        local hint = self.row_holder:AddChild(Text(BODYTEXTFONT, 14))
        hint:SetPosition(0, -5)
        hint:SetString("Explore the world to find more!")
        hint:SetColour(0.4, 0.38, 0.35, 0.5)
        return
    end

    -- Clamp scroll offset to valid range.
    local maxOffset = math.max(0, total - maxRows)
    if self.scroll_offset < 0 then self.scroll_offset = 0 end
    if self.scroll_offset > maxOffset then self.scroll_offset = maxOffset end

    local visibleCount = math.min(maxRows, total - self.scroll_offset)
    local startY = (visibleCount - 1) * rowH / 2

    for slot = 1, visibleCount do
        local i = self.scroll_offset + slot
        local data = towerList[i]
        local y = startY - (slot - 1) * rowH

        local row = self.row_holder:AddChild(Widget("row" .. slot))
        row:SetPosition(0, y)

        -- Row background (subtle alternating based on actual index)
        local rowBg = row:AddChild(Image("images/global.xml", "square.tex"))
        local bgAlpha = (i % 2 == 0) and 0.06 or 0.03
        rowBg:SetTint(1, 1, 1, bgAlpha)
        rowBg:SetSize(300, rowH - 4)

        -- Tower name (left aligned)
        local nameText = row:AddChild(Text(BUTTONFONT, 17))
        nameText:SetPosition(-90, 4)
        nameText:SetString(data.name)
        nameText:SetColour(0.9, 0.85, 0.7, 1)

        -- Distance + direction (middle)
        local infoText = row:AddChild(Text(BODYTEXTFONT, 15))
        infoText:SetPosition(-90, -12)
        infoText:SetString(string.format("%dm  %s", math.floor(data.dist), data.dir))
        infoText:SetColour(0.6, 0.55, 0.45, 0.7)

        -- Travel button
        local btn = row:AddChild(ImageButton())
        btn:SetPosition(115, 0)
        btn:SetScale(0.5)
        btn:SetText("Travel")
        btn:SetFont(BUTTONFONT)
        local targetX, targetZ = data.x, data.z
        btn:SetOnClick(function()
            self:Close()
            SendModRPCToServer(MOD_RPC["MysteryBox"]["TowerTeleportPos"], targetX, targetZ)
        end)
    end

    -- Scroll controls: show only when there's something to scroll.
    if total > maxRows then
        self.scroll_up:Show()
        self.scroll_down:Show()
        local first = self.scroll_offset + 1
        local last = self.scroll_offset + visibleCount
        self.scroll_indicator:SetString(string.format("%d-%d\nof %d", first, last, total))
    else
        self.scroll_up:Hide()
        self.scroll_down:Hide()
        self.scroll_indicator:SetString("")
    end
end

function TowerNetworkScreen:ScrollBy(delta)
    if not self.tower_list or #self.tower_list == 0 then return end
    self.scroll_offset = self.scroll_offset + delta
    self:RenderVisibleRows()
end

function TowerNetworkScreen:Close()
    TheFrontEnd:PopScreen(self)
end

function TowerNetworkScreen:OnControl(control, down)
    if TowerNetworkScreen._base.OnControl(self, control, down) then
        return true
    end
    if not down and control == CONTROL_CANCEL then
        self:Close()
        return true
    end
    -- Mouse wheel / gamepad equivalents scroll the tower list.
    if down and control == CONTROL_SCROLLBACK then
        self:ScrollBy(-1)
        return true
    end
    if down and control == CONTROL_SCROLLFWD then
        self:ScrollBy(1)
        return true
    end
    return false
end

function TowerNetworkScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " Close"
end

return TowerNetworkScreen
