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

local function GetTowerDisplayName(tower)
    -- Read the generated name from tags (format: "towername_Wilson_s_Marsh")
    -- Iterate through common tag prefixes to find towername
    local testTags = {
        "towername_North", "towername_South", "towername_East", "towername_West",
        "towername_Central", "towername_Far", "towername_Deep", "towername_Hidden"
    }

    -- Try to find any towername tag by checking HasTag with common prefixes
    -- This is a workaround since we can't iterate all tags on client
    if tower.GetDebugString then
        local debugStr = tower:GetDebugString()
        if debugStr then
            local tagName = debugStr:match("towername_([%w_]+)")
            if tagName then
                local name = tagName:gsub("_", " ")
                name = name:gsub("(%w) s ", "%1's ")
                print("[TowerNetwork] Found name via debug: " .. name)
                return name
            end
        end
    end

    -- Fallback: use position-based name
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

    -- Title
    local towerName = GetTowerDisplayName(tower)
    self.title = self.root:AddChild(Text(TITLEFONT, 26))
    self.title:SetPosition(0, panelH/2 - 30)
    self.title:SetString(string.upper(towerName))
    self.title:SetColour(0.9, 0.8, 0.6, 1)

    -- Divider
    self.divider = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.divider:SetTint(0.3, 0.25, 0.18, 0.6)
    self.divider:SetSize(panelW - 40, 1)
    self.divider:SetPosition(0, panelH/2 - 50)

    -- Subtitle
    self.subtitle = self.root:AddChild(Text(BODYTEXTFONT, 16))
    self.subtitle:SetPosition(0, panelH/2 - 65)
    self.subtitle:SetString("Tower Network")
    self.subtitle:SetColour(0.6, 0.55, 0.45, 0.8)

    -- Sanity cost note
    self.cost = self.root:AddChild(Text(BODYTEXTFONT, 14))
    self.cost:SetPosition(0, panelH/2 - 82)
    self.cost:SetString("Travel cost: " .. TELEPORT_SANITY_COST .. " Sanity")
    self.cost:SetColour(0.55, 0.4, 0.6, 0.7)

    -- Tower list area
    self.list = self.root:AddChild(Widget("list"))
    self.list:SetPosition(0, 0)
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
    local currentKey = nil
    if self.tower and self.tower.Transform then
        local tx, _, tz = self.tower.Transform:GetWorldPosition()
        currentKey = math.floor(tx) .. "_" .. math.floor(tz)
    end

    -- Read from the shared client-side mirror kept in sync by server RPCs.
    local discoveredTowers = MysteryBox_SharedTowers or {}

    local towerList = {}
    local count = 0

    for key, data in pairs(discoveredTowers) do
        count = count + 1
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

    print("[TowerNetwork] Discovered towers: " .. count)
    table.sort(towerList, function(a, b) return a.dist < b.dist end)

    if #towerList == 0 then
        local msg = self.list:AddChild(Text(BODYTEXTFONT, 18))
        msg:SetPosition(0, 20)
        msg:SetString("No other towers discovered yet.")
        msg:SetColour(0.5, 0.45, 0.4, 0.7)

        local hint = self.list:AddChild(Text(BODYTEXTFONT, 14))
        hint:SetPosition(0, -5)
        hint:SetString("Explore the world to find more!")
        hint:SetColour(0.4, 0.38, 0.35, 0.5)
        return
    end

    local rowH = 42
    local startY = (#towerList - 1) * rowH / 2
    local maxRows = 7

    for i, data in ipairs(towerList) do
        if i > maxRows then break end

        local y = startY - (i - 1) * rowH
        local row = self.list:AddChild(Widget("row" .. i))
        row:SetPosition(0, y)

        -- Row background (subtle alternating)
        local rowBg = row:AddChild(Image("images/global.xml", "square.tex"))
        local bgAlpha = (i % 2 == 0) and 0.06 or 0.03
        rowBg:SetTint(1, 1, 1, bgAlpha)
        rowBg:SetSize(320, rowH - 4)

        -- Tower name (left aligned)
        local nameText = row:AddChild(Text(BUTTONFONT, 17))
        nameText:SetPosition(-80, 4)
        nameText:SetString(data.name)
        nameText:SetColour(0.9, 0.85, 0.7, 1)

        -- Distance + direction (right side)
        local infoText = row:AddChild(Text(BODYTEXTFONT, 15))
        infoText:SetPosition(-80, -12)
        infoText:SetString(string.format("%dm  %s", math.floor(data.dist), data.dir))
        infoText:SetColour(0.6, 0.55, 0.45, 0.7)

        -- Travel button
        local btn = row:AddChild(ImageButton())
        btn:SetPosition(130, 0)
        btn:SetScale(0.5)
        btn:SetText("Travel")
        btn:SetFont(BUTTONFONT)
        local targetX, targetZ = data.x, data.z
        btn:SetOnClick(function()
            self:Close()
            SendModRPCToServer(MOD_RPC["MysteryBox"]["TowerTeleportPos"], targetX, targetZ)
        end)
    end

    if #towerList > maxRows then
        local more = self.list:AddChild(Text(BODYTEXTFONT, 13))
        more:SetPosition(0, startY - maxRows * rowH)
        more:SetString("+" .. (#towerList - maxRows) .. " more...")
        more:SetColour(0.4, 0.38, 0.35, 0.5)
    end
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
    return false
end

function TowerNetworkScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " Close"
end

return TowerNetworkScreen
