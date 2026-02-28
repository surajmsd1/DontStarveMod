-- Tower Selection Widget
-- UI for selecting which tower to teleport to

local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"

-- Friendly names for biome room types
-- Based on actual DST room names from map/rooms/forest/*.lua
local BIOME_NAMES = {
    -- === DESERT BIOMES ===
    -- Dragonfly Desert (Badlands)
    DragonflyArena = "Dragonfly Desert",
    Badlands = "Badlands",
    BGBadlands = "Badlands",
    HoundyBadlands = "Hound Mound Desert",
    BuzzardyBadlands = "Buzzard Desert",

    -- Oasis/Antlion Desert (Lightning Bluff)
    LightningBluffOasis = "Oasis",
    LightningBluffAntlion = "Antlion Desert",
    LightningBluffLightning = "Volt Goat Desert",
    BGLightningBluff = "Sandstorm Desert",
    Lightning = "Lightning Plains",

    -- === DECIDUOUS BIOMES ===
    MagicalDeciduous = "Glommer Statue",
    DeepDeciduous = "Deciduous Forest",
    BGDeciduous = "Deciduous Forest",
    DeciduousMole = "Deciduous Moles",
    MolesvilleDeciduous = "Molesville",
    DeciduousClearing = "Deciduous Clearing",

    -- === PIG BIOMES ===
    PigKingdom = "Pig King",
    PigCity = "Pig King",
    PigVillage = "Pig Village",
    PigTown = "Pig Town",
    PigCamp = "Pig Camp",

    -- === WALRUS BIOMES ===
    WalrusHut_Plains = "MacTusk Camp",
    WalrusHut_Grassy = "MacTusk Camp",
    WalrusHut_Rocky = "MacTusk Camp",

    -- === FOREST BIOMES ===
    Forest = "Forest",
    BGForest = "Forest",
    DeepForest = "Deep Forest",
    BGDeepForest = "Deep Forest",
    CrappyForest = "Sparse Forest",
    CrappyDeepForest = "Sparse Forest",
    BurntForest = "Burnt Forest",
    SpiderForest = "Spider Forest",
    Clearing = "Clearing",
    BurntClearing = "Burnt Clearing",
    MoonbaseOne = "Moon Stone",
    ForestMole = "Mole Colony",

    -- === MOOSE/GOOSE ===
    MooseGooseBreedingGrounds = "Moose/Goose Nest",

    -- === GRASS/PLAINS BIOMES ===
    PondyGrass = "Pond Grasslands",
    Grassland = "Grasslands",
    BGGrass = "Grasslands",
    Plains = "Plains",

    -- === SAVANNA BIOMES ===
    Savanna = "Savanna",
    BGSavanna = "Savanna",
    BeefalowPlain = "Beefalo Plains",

    -- === MARSH/SWAMP ===
    Marsh = "Swamp",
    BGMarsh = "Swamp",
    Tentacleland = "Tentacle Marsh",

    -- === ROCKY BIOMES ===
    Rocky = "Rockyland",
    BGRocky = "Rockyland",
    SpiderRocky = "Spider Rockyland",

    -- === BEE BIOMES ===
    BeeClearing = "Bee Queen",
    Beefalowland = "Beefalo Plains",

    -- === SPECIAL AREAS ===
    Graveyard = "Graveyard",
    ChessArea = "Chess Biome",
    Chessworld = "Chess Biome",

    -- === MISC ===
    Mosaic = "Mosaic Biome",
    Wormhole = "Wormhole Area",
    StartArea = "Spawn Point",
}

-- Icons for different biome types (using existing game textures)
local BIOME_ICONS = {
    Deciduous = "pigskin.tex",
    PigKing = "pigskin.tex",
    Walrus = "walrushat.tex",
    Forest = "log.tex",
    Grasslands = "cutgrass.tex",
    Savanna = "beefalowool.tex",
    Marsh = "tentaclespots.tex",
    Rocky = "rocks.tex",
    Desert = "nitre.tex",
    Meadow = "Place Flower.tex",
    default = "firepit.tex",  -- Default tower icon
}

local TowerSelect = Class(Widget, function(self, owner, towers, onSelectCallback, onCancelCallback)
    Widget._ctor(self, "TowerSelect")

    self.owner = owner
    self.towers = towers or {}
    self.onSelect = onSelectCallback
    self.onCancel = onCancelCallback
    self.selectedIndex = 1

    -- Full screen setup
    self:SetVAnchor(ANCHOR_MIDDLE)
    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- Dark background overlay
    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetTint(0, 0, 0, 0.85)
    self.bg:SetSize(2000, 2000)

    -- Title
    self.title = self:AddChild(Text(HEADERFONT, 40))
    self.title:SetPosition(0, 250)
    self.title:SetString("Select Destination")
    self.title:SetColour(1, 0.9, 0.5, 1)  -- Golden

    -- Subtitle
    self.subtitle = self:AddChild(Text(UIFONT, 22))
    self.subtitle:SetPosition(0, 210)
    self.subtitle:SetString("Choose a tower to teleport to")
    self.subtitle:SetColour(0.8, 0.8, 0.8, 1)

    -- Tower list container
    self.listContainer = self:AddChild(Widget("ListContainer"))
    self.listContainer:SetPosition(0, 0)

    -- Build tower buttons
    self.buttons = {}
    self:BuildTowerList()

    -- Instructions
    self.instructions = self:AddChild(Text(UIFONT, 20))
    self.instructions:SetPosition(0, -220)
    self.instructions:SetString("[WASD/Arrows] Navigate   [Space/Enter] Select   [Escape] Cancel")
    self.instructions:SetColour(0.6, 0.6, 0.6, 1)

    -- Current tower indicator
    self.currentLabel = self:AddChild(Text(UIFONT, 18))
    self.currentLabel:SetPosition(0, -250)
    self.currentLabel:SetColour(0.5, 0.8, 0.5, 1)

    -- Set up keyboard controls
    self:SetupControls()

    -- Focus first item
    self:UpdateSelection()
end)

function TowerSelect:GetBiomeName(roomName)
    if not roomName then return "Unknown Tower" end

    -- Check exact match first
    if BIOME_NAMES[roomName] then
        return BIOME_NAMES[roomName]
    end

    -- Check partial matches (order matters - check longer keys first)
    local matches = {}
    for key, name in pairs(BIOME_NAMES) do
        if string.find(roomName, key) then
            table.insert(matches, {key = key, name = name, len = #key})
        end
    end
    -- Sort by key length descending (prefer more specific matches)
    table.sort(matches, function(a, b) return a.len > b.len end)
    if #matches > 0 then
        return matches[1].name
    end

    -- Fallback: Clean up the raw room name
    local cleaned = roomName
    -- Remove common prefixes
    cleaned = cleaned:gsub("^BG", "")
    cleaned = cleaned:gsub("^Terrain", "")
    -- Replace underscores with spaces
    cleaned = cleaned:gsub("_", " ")
    -- Add spaces before capitals (camelCase to Title Case)
    cleaned = cleaned:gsub("(%l)(%u)", "%1 %2")
    -- Trim and return
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")

    if cleaned == "" then
        return "Tower"
    end
    return cleaned
end

function TowerSelect:GetBiomeIcon(roomName)
    if not roomName then return BIOME_ICONS.default end

    for key, icon in pairs(BIOME_ICONS) do
        if string.find(roomName, key) then
            return icon
        end
    end

    return BIOME_ICONS.default
end

function TowerSelect:BuildTowerList()
    local startY = 150
    local spacing = 50
    local maxVisible = 6

    -- Clear existing buttons
    for _, btn in ipairs(self.buttons) do
        btn:Kill()
    end
    self.buttons = {}

    -- Sort towers by name for consistency
    local sortedTowers = {}
    for i, tower in ipairs(self.towers) do
        table.insert(sortedTowers, {
            index = i,
            tower = tower,
            name = self:GetBiomeName(tower.room_name),
            isCurrentTower = tower.isCurrentTower,
        })
    end
    table.sort(sortedTowers, function(a, b) return a.name < b.name end)
    self.sortedTowers = sortedTowers

    -- Create buttons for each tower
    for i, data in ipairs(sortedTowers) do
        local yPos = startY - (i - 1) * spacing

        -- Only show if within visible range
        if i <= maxVisible then
            local btn = self.listContainer:AddChild(Widget("TowerButton"))
            btn:SetPosition(0, yPos)

            -- Background for selection highlight
            btn.bg = btn:AddChild(Image("images/global.xml", "square.tex"))
            btn.bg:SetSize(400, 40)
            btn.bg:SetTint(0.3, 0.3, 0.3, 0)

            -- Tower name text
            btn.text = btn:AddChild(Text(UIFONT, 26))
            btn.text:SetPosition(0, 0)
            btn.text:SetString(data.name)

            -- Mark current tower
            if data.isCurrentTower then
                btn.text:SetColour(0.5, 0.5, 0.5, 1)
                btn.text:SetString(data.name .. " (You are here)")
            else
                btn.text:SetColour(1, 1, 1, 1)
            end

            btn.data = data
            table.insert(self.buttons, btn)
        end
    end

    -- Show scroll indicator if more towers than visible
    if #sortedTowers > maxVisible then
        self.scrollHint = self:AddChild(Text(UIFONT, 16))
        self.scrollHint:SetPosition(0, startY - maxVisible * spacing - 10)
        self.scrollHint:SetString("... and " .. (#sortedTowers - maxVisible) .. " more (scroll with arrows)")
        self.scrollHint:SetColour(0.5, 0.5, 0.5, 1)
    end
end

function TowerSelect:UpdateSelection()
    for i, btn in ipairs(self.buttons) do
        if i == self.selectedIndex then
            -- Selected
            btn.bg:SetTint(1, 0.9, 0.5, 0.3)
            if not btn.data.isCurrentTower then
                btn.text:SetColour(1, 0.9, 0.5, 1)
            end
        else
            -- Not selected
            btn.bg:SetTint(0.3, 0.3, 0.3, 0)
            if not btn.data.isCurrentTower then
                btn.text:SetColour(1, 1, 1, 1)
            end
        end
    end
end

function TowerSelect:SetupControls()
    -- Handle keyboard input
    self.handler = TheInput:AddKeyHandler(function(key, down)
        if not down then return end

        if key == KEY_UP or key == KEY_W then
            self:MoveSelection(-1)
        elseif key == KEY_DOWN or key == KEY_S then
            self:MoveSelection(1)
        elseif key == KEY_SPACE or key == KEY_ENTER then
            self:ConfirmSelection()
        elseif key == KEY_ESCAPE then
            self:Cancel()
        end
    end)
end

function TowerSelect:MoveSelection(delta)
    local newIndex = self.selectedIndex + delta

    -- Wrap around
    if newIndex < 1 then
        newIndex = #self.buttons
    elseif newIndex > #self.buttons then
        newIndex = 1
    end

    self.selectedIndex = newIndex
    self:UpdateSelection()

    -- Play sound
    if self.owner and self.owner.SoundEmitter then
        self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click_move")
    end
end

function TowerSelect:ConfirmSelection()
    local selected = self.sortedTowers[self.selectedIndex]

    if selected and not selected.isCurrentTower then
        if self.onSelect then
            self.onSelect(selected.tower)
        end
        self:Close()
    elseif selected and selected.isCurrentTower then
        -- Can't teleport to current tower
        if self.owner and self.owner.SoundEmitter then
            self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
        end
    end
end

function TowerSelect:Cancel()
    if self.onCancel then
        self.onCancel()
    end
    self:Close()
end

function TowerSelect:Close()
    if self.handler then
        self.handler:Remove()
        self.handler = nil
    end
    self:Kill()
end

function TowerSelect:OnDestroy()
    if self.handler then
        self.handler:Remove()
        self.handler = nil
    end
end

return TowerSelect
