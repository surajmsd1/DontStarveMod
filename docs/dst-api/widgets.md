# DST Widget & UI System

## Overview
DST's UI is built on a Lua widget tree. Everything on screen -- HUD badges, inventory, crafting menu, buttons, text -- is a Widget. Understanding this system is essential for building custom HUD elements like a quest tracker.

## Widget Class Hierarchy

```
Widget (base class)
├── Screen (full-screen container)
│   └── PlayerHud (the game HUD, holds Controls)
├── Text (text labels)
├── Image (static images)
├── ImageButton (clickable image buttons)
├── Button (text buttons)
├── Badge (circular progress meters -- health, hunger, sanity)
│   ├── HealthBadge
│   ├── HungerBadge
│   └── SanityBadge
├── UIAnim (animated sprites)
├── ScrollableList (scrollable item list)
├── UIClock (the day/night clock)
├── StatusDisplays (container for all status badges)
└── Controls (master HUD container, holds everything)
```

### Key Source Files (in DST scripts/)
```
widgets/widget.lua          -- Base class, all methods
widgets/text.lua            -- Text rendering
widgets/image.lua           -- Image display
widgets/imagebutton.lua     -- Clickable image buttons
widgets/badge.lua           -- Circular progress meters
widgets/statusdisplays.lua  -- Health/hunger/sanity layout
widgets/controls.lua        -- Master HUD container
widgets/scrollablelist.lua  -- Scrollable panels
widgets/uiclock.lua         -- Day/night clock
screens/playerhud.lua       -- HUD screen setup
```

---

## Widget Base Class

All widgets inherit from Widget. Here are the essential methods:

### Lifecycle
```lua
local Widget = require "widgets/widget"

-- Constructor pattern
local MyWidget = Class(Widget, function(self, owner)
    Widget._ctor(self, "MyWidget")  -- name for debugging
    self.owner = owner
end)
```

### Parent-Child Tree
```lua
-- Add a child widget (returns the child)
local child = self:AddChild(Widget("child_name"))

-- Remove child
self:RemoveChild(child)

-- Kill widget and all children
self:Kill()

-- Kill all children (keep self)
self:KillAllChildren()
```

### Positioning
```lua
-- Set position (relative to parent)
self:SetPosition(x, y, z)       -- z usually 0
self:SetPosition(Vector3(x,y,z))

-- Get position
local pos = self:GetPosition()
local x, y, z = pos:Get()

-- Nudge relative to current position
self:Nudge(Vector3(10, 0, 0))

-- Set scale
self:SetScale(1.2, 1.2, 1.2)
local sx, sy, sz = self:GetScale()

-- Rotation
self:SetRotation(45)  -- degrees
```

### Visibility
```lua
self:Show()
self:Hide()
local visible = self:IsVisible()

-- Check full chain (are all parents also visible?)
local shown = self:IsVisible()
```

### Animations (Tweens)
```lua
-- Animate position over time
self:MoveTo(startPos, endPos, duration, callback)

-- Animate scale over time
self:ScaleTo(fromScale, toScale, duration, callback)

-- Animate color/alpha
self:TintTo(fromTint, toTint, duration, callback)

-- Cancel animations
self:CancelMoveTo()
self:CancelScaleTo()
```

### Rendering Order
```lua
self:MoveToFront()
self:MoveToBack()
```

### Focus & Input
```lua
self:SetFocus()
self:ClearFocus()
self:SetClickable(true)  -- or false

-- Focus callbacks (override in subclass)
function MyWidget:OnGainFocus() end
function MyWidget:OnLoseFocus() end

-- Control handling
function MyWidget:OnControl(control, down) end
function MyWidget:OnMouseButton(button, down, x, y) end
```

### Hover Text
```lua
self:SetHoverText("Tooltip text here", {
    font = NEWFONT,
    size = 22,
    offset_x = 0,
    offset_y = 50,
    colour = {1,1,1,1},
    bg = true,
})
self:ClearHoverText()
```

---

## Text Widget

Displays text strings. Fonts and sizes are set at construction.

### Construction
```lua
local Text = require "widgets/text"

-- Common fonts: BODYTEXTFONT, TITLEFONT, NEWFONT, TALKINGFONT, NUMBERFONT
local label = self:AddChild(Text(BODYTEXTFONT, 30, "Hello World!"))
```

### Key Methods
```lua
-- Set text content
label:SetString("New text here")

-- Set color (RGBA 0-1)
label:SetColour(1, 1, 1, 1)          -- white
label:SetColour({1, 0.5, 0, 1})      -- orange

-- Set font size
label:SetSize(24)

-- Set font
label:SetFont(NUMBERFONT)

-- Text alignment
label:SetHAlign(ANCHOR_LEFT)   -- ANCHOR_LEFT, ANCHOR_MIDDLE, ANCHOR_RIGHT
label:SetVAlign(ANCHOR_TOP)    -- ANCHOR_TOP, ANCHOR_MIDDLE, ANCHOR_BOTTOM

-- Word wrapping
label:EnableWordWrap(true)
label:EnableWhitespaceWrap(true)

-- Region size (for wrapping/clipping)
label:SetRegionSize(width, height)

-- Truncation with ellipsis
label:SetTruncatedString("Very long text...", maxwidth, maxchars, "...")

-- Multi-line truncation (auto-shrinks font to fit)
label:SetMultilineTruncatedString("Long text", maxlines, maxwidth, maxchars, "...")
```

### Font Constants
```lua
BODYTEXTFONT  -- Default body text
TITLEFONT     -- Large titles
NEWFONT       -- Clean modern font
TALKINGFONT   -- Speech bubbles
NUMBERFONT    -- Numeric displays
CHATFONT      -- Chat window
BUTTONFONT    -- Button labels
```

---

## Image Widget

Displays a texture from an atlas (XML+TEX pair).

### Construction
```lua
local Image = require "widgets/image"

-- atlas = XML file, tex = texture name within atlas
local img = self:AddChild(Image("images/ui.xml", "button_small.tex"))
```

### Key Methods
```lua
-- Change texture
img:SetTexture("images/ui.xml", "new_texture.tex")

-- Set size in pixels
img:SetSize(100, 50)

-- Scale to specific size (maintains ratio)
img:ScaleToSize(100, 50)

-- Tint color (RGBA)
img:SetTint(1, 0.5, 0, 1)    -- orange tint
img:SetFadeAlpha(0.5)          -- transparency

-- Registration point (anchor within image)
img:SetHRegPoint(ANCHOR_MIDDLE)  -- ANCHOR_LEFT, ANCHOR_MIDDLE, ANCHOR_RIGHT
img:SetVRegPoint(ANCHOR_MIDDLE)  -- ANCHOR_TOP, ANCHOR_MIDDLE, ANCHOR_BOTTOM

-- Click interaction textures
img:SetMouseOverTexture("images/ui.xml", "hover.tex")
img:SetDisabledTexture("images/ui.xml", "disabled.tex")

-- Shader effects
img:SetEffect("shaders/myeffect.ksh")
```

### Common Atlas/Texture Pairs (Built-in)
```lua
-- UI elements
"images/ui.xml", "button_small.tex"
"images/ui.xml", "button_small_over.tex"
"images/ui.xml", "button_small_disabled.tex"

-- HUD elements
"images/hud.xml", "bg_oval.tex"
"images/hud.xml", "bg_plain.tex"

-- Status icons
"images/rain.xml", "rain.tex"
```

---

## ImageButton Widget

Clickable button with image states for normal, hover, disabled, down, selected.

### Construction
```lua
local ImageButton = require "widgets/imagebutton"

local btn = self:AddChild(ImageButton(
    "images/ui.xml",          -- atlas
    "button_small.tex",       -- normal texture
    "button_small_over.tex",  -- focus/hover texture
    "button_small_disabled.tex", -- disabled texture
    nil,                      -- down texture (optional)
    nil,                      -- selected texture (optional)
    {1, 1},                   -- scale
    {0, 0}                    -- offset
))
```

### Key Methods
```lua
-- Set click handler
btn.onclick = function()
    print("Button clicked!")
end

-- Alternative: set via method
btn:SetOnClick(function()
    print("Clicked!")
end)

-- Disable/enable
btn:Disable()
btn:Enable()

-- State colors (RGBA)
btn:SetImageNormalColour(1, 1, 1, 1)
btn:SetImageFocusColour(1, 1, 0.5, 1)
btn:SetImageDisabledColour(0.5, 0.5, 0.5, 1)

-- Scale animation on hover
btn:SetFocusScale(1.1, 1.1, 1.1)
btn:SetNormalScale(1, 1, 1)

-- Force image size
btn:ForceImageSize(200, 50)

-- Sound on focus
btn:SetFocusSound("dontstarve/HUD/click_move")

-- Add text label on button
btn:SetText("Click Me")
btn:SetTextSize(24)
btn:SetFont(BUTTONFONT)
```

---

## Badge Widget (Progress Meters)

Circular progress indicators used for health, hunger, sanity, etc.

### How Badges Work
```lua
-- Badge is constructed with:
-- anim_bank, owner, tint_color, icon_info, use_circular_meter
local Badge = require "widgets/badge"

-- Example: Create a custom badge
local mybadge = self:AddChild(Badge(
    "status_health",           -- anim bank
    owner,                     -- player entity
    {1, 0, 0, 1},            -- red tint
    nil,                       -- icon (optional)
    true                       -- circular meter
))
```

### SetPercent (Key Method)
```lua
-- Update the fill level
-- percent: 0.0 to 1.0
-- max: the maximum value (for number display)
mybadge:SetPercent(0.75, 150)  -- 75% full, max=150 (shows "112")

-- The badge uses AnimState:SetPercent("meter", val) internally
-- for circular meters, or frame-based for linear ones
```

### Badge Animations
```lua
-- Green pulse (healing/positive change)
mybadge:PulseGreen()

-- Red pulse (damage/negative change)
mybadge:PulseRed()

-- Warning state (looping pulse)
mybadge:StartWarning()
mybadge:StopWarning()
```

### PlayerBadge (Character Icon Badge)
```lua
local PlayerBadge = require "widgets/playerbadge"

-- Create badge with character portrait
local badge = self:AddChild(PlayerBadge(
    "wilson",                  -- prefab name (for portrait)
    {80/255, 60/255, 30/255, 1}, -- badge color
    false,                     -- is_ghost
    "wilson"                   -- skin build (optional)
))
```

---

## UIAnim Widget

Displays animated sprites using DST's animation system.

```lua
local UIAnim = require "widgets/uianim"

local anim = self:AddChild(UIAnim())
anim:GetAnimState():SetBank("status_health")
anim:GetAnimState():SetBuild("status_health")
anim:GetAnimState():PlayAnimation("idle", true)  -- true = loop

-- Control animation
anim:GetAnimState():SetPercent("meter", 0.5)  -- for meter anims
anim:GetAnimState():PushAnimation("anim2", false) -- queue next
```

---

## ScrollableList Widget

Scrollable list of items. Used in crafting menus, server browsers, etc.

### Construction
```lua
local ScrollableList = require "widgets/scrollablelist"

local list = self:AddChild(ScrollableList(
    items,          -- table of item data
    listwidth,      -- width in pixels
    listheight,     -- height in pixels
    itemheight,     -- height of each item row
    itempadding,    -- padding between items
    updatefn,       -- function(context, widget, data, index) to populate item widget
    widgetsCtor,    -- optional: array of pre-built item widgets
    scrollbarOffset, -- optional: horizontal offset for scrollbar
    scrollbarHeight  -- optional: custom scrollbar height
))
```

### Key Methods
```lua
-- Replace entire list
list:SetList(newItems, keepScrollPosition)

-- Add/remove items
list:AddItem(item)
list:RemoveItem(item)

-- Manual scroll
list:Scroll(amount)  -- positive = down, negative = up

-- Refresh display
list:RefreshView()
```

### Usage Pattern
```lua
-- Define items
local items = {
    {name = "Quest 1", progress = 0.5},
    {name = "Quest 2", progress = 1.0},
    {name = "Quest 3", progress = 0.0},
}

-- Define update function (called per visible item)
local function UpdateItem(context, widget, data, index)
    widget.label:SetString(data.name)
    widget.progress:SetPercent(data.progress, 1)
end

-- Create scrollable list
local list = self:AddChild(ScrollableList(items, 300, 400, 40, 5, UpdateItem))
```

---

## Screen Positioning & Anchoring

DST uses anchor-based positioning for responsive layout.

### Anchor Constants
```lua
ANCHOR_MIDDLE = 0
ANCHOR_LEFT   = 1  -- (also ANCHOR_TOP for vertical)
ANCHOR_RIGHT  = 2  -- (also ANCHOR_BOTTOM for vertical)
ANCHOR_TOP    = 1
ANCHOR_BOTTOM = 2
```

### Scale Mode Constants
```lua
SCALEMODE_PROPORTIONAL           -- Scale proportionally to screen
SCALEMODE_FIXEDPROPORTIONAL = 3  -- Fixed proportional (safe area on consoles)
SCALEMODE_FIXEDSCREEN_NONDYNAMIC = 4  -- Scale same as window from 1280x720
```

### Anchoring a Root Widget
```lua
-- Anchor to center of screen
self.root = self:AddChild(Widget("root"))
self.root:SetVAnchor(ANCHOR_MIDDLE)
self.root:SetHAnchor(ANCHOR_MIDDLE)
self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

-- Anchor to top-right corner
self.root = self:AddChild(Widget("root"))
self.root:SetVAnchor(ANCHOR_TOP)
self.root:SetHAnchor(ANCHOR_RIGHT)
self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
```

---

## HUD Architecture

### PlayerHud (Screen)
The top-level HUD screen. Created when a player joins.

```lua
-- PlayerHud structure:
PlayerHud (Screen)
├── overlayroot   -- Weather, vision overlays
├── under_root    -- Under everything
├── root          -- Main content
│   └── Controls  -- All gameplay HUD widgets
└── over_root     -- On top of everything
```

### Controls Widget (The Master HUD Container)
Controls organizes the entire gameplay HUD using anchor-based root nodes:

```lua
-- Controls root nodes (defined in widgets/controls.lua):
top_root         -- Center-top (ANCHOR_TOP, ANCHOR_MIDDLE)
topleft_root     -- Top-left corner
topright_root    -- Top-right corner
bottom_root      -- Center-bottom
bottomright_root -- Bottom-right corner
left_root        -- Middle-left
right_root       -- Middle-right

-- Key children on Controls:
self.status           -- StatusDisplays (health/hunger/sanity badges)
self.inv              -- Inventory bar (bottom_root)
self.craftingmenu     -- Crafting menu (left or right root)
self.sidepanel        -- Side panel (UIClock, etc)
self.containerroot    -- Container windows (chests, etc)
self.containerroot_side -- Side containers
```

### StatusDisplays Widget
Holds all the circular status badges:

```lua
-- StatusDisplays layout (column positions):
-- column1: -80, column2: -40, column3: 0, column4: 40, column5: -120

self.heart  = self:AddChild(HealthBadge(owner))    -- column4, y=20
self.stomach = self:AddChild(HungerBadge(owner))   -- column2, y=20
self.brain  = self:AddChild(SanityBadge(owner))    -- column3, y=-40

-- Event-driven updates:
self.inst:ListenForEvent("healthdelta", function(owner, data)
    self.heart:SetPercent(data.newpercent, owner.components.health.maxhealth)
    if data.newpercent > data.oldpercent then
        self.heart:PulseGreen()
    else
        self.heart:PulseRed()
    end
end, owner)
```

---

## Adding Custom Widgets to the HUD

### Method 1: AddClassPostConstruct on Controls (Recommended)

This is the standard approach used by most mods.

**In modmain.lua:**
```lua
-- Require your custom widget
local MyWidget = GLOBAL.require("widgets/mywidget")

local function ControlsPostConstruct(self)
    -- self = the Controls widget instance
    -- self.owner = the local player entity
    if self.owner then
        self.mywidget = self:AddChild(MyWidget(self.owner))
        self.mywidget:SetPosition(0, 100, 0)
    end
end

AddClassPostConstruct("widgets/controls", ControlsPostConstruct)
```

**In scripts/widgets/mywidget.lua:**
```lua
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"

local MyWidget = Class(Widget, function(self, owner)
    Widget._ctor(self, "MyWidget")
    self.owner = owner

    -- Background
    self.bg = self:AddChild(Image("images/hud.xml", "bg_plain.tex"))
    self.bg:SetSize(200, 60)
    self.bg:SetTint(0, 0, 0, 0.6)

    -- Title text
    self.title = self:AddChild(Text(BODYTEXTFONT, 22, "My Widget"))
    self.title:SetPosition(0, 15, 0)
    self.title:SetColour(1, 1, 0.5, 1)

    -- Value text
    self.value = self:AddChild(Text(NUMBERFONT, 18, "0/100"))
    self.value:SetPosition(0, -10, 0)
end)

function MyWidget:SetValue(current, max)
    self.value:SetString(string.format("%d/%d", current, max))
end

return MyWidget
```

### Method 2: AddClassPostConstruct on StatusDisplays

For adding badges alongside health/hunger/sanity:

```lua
local PlayerBadge = GLOBAL.require("widgets/playerbadge")

AddClassPostConstruct("widgets/statusdisplays", function(self)
    -- Add a custom badge next to the existing ones
    self.mybadge = self:AddChild(PlayerBadge(
        self.owner.prefab,
        {0.2, 0.8, 0.2, 1},  -- green color
        false
    ))
    self.mybadge:SetPosition(-120, -40, 0)

    -- Update it from events
    self.inst:ListenForEvent("mycustomdelta", function(owner, data)
        self.mybadge:SetPercent(data.percent, data.max)
    end, self.owner)
end)
```

### Method 3: Using Specific Root Nodes

For precise screen positioning, add to specific anchor roots:

```lua
AddClassPostConstruct("widgets/controls", function(self)
    -- Add to top-right corner
    self.mytracker = self.topright_root:AddChild(MyTrackerWidget(self.owner))
    self.mytracker:SetPosition(-200, -100, 0)

    -- Add to bottom-right corner
    self.mybutton = self.bottomright_root:AddChild(MyButton(self.owner))
    self.mybutton:SetPosition(-50, 50, 0)
end)
```

### Method 4: Toggle with Keybind

```lua
AddClassPostConstruct("widgets/controls", function(self)
    self.mywidget = self:AddChild(MyWidget(self.owner))
    self.mywidget:Hide()

    -- Toggle with a key
    GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_P, function()
        if self.mywidget:IsVisible() then
            self.mywidget:Hide()
        else
            self.mywidget:Show()
        end
    end)
end)
```

---

## Building a Collapsible/Expandable Panel

DST does not have a built-in collapsible panel widget, but you can build one using Show/Hide and MoveTo animations.

### Pattern: Collapsible Panel
```lua
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"

local CollapsiblePanel = Class(Widget, function(self, owner, title)
    Widget._ctor(self, "CollapsiblePanel")
    self.owner = owner
    self.is_expanded = true

    -- Header (always visible)
    self.header = self:AddChild(Widget("header"))

    -- Toggle button
    self.toggle_btn = self.header:AddChild(ImageButton(
        "images/ui.xml",
        "button_small.tex",
        "button_small_over.tex",
        "button_small_disabled.tex"
    ))
    self.toggle_btn:ForceImageSize(30, 30)
    self.toggle_btn:SetPosition(-80, 0, 0)
    self.toggle_btn:SetOnClick(function() self:Toggle() end)

    -- Title
    self.title = self.header:AddChild(Text(BODYTEXTFONT, 22, title or "Panel"))
    self.title:SetPosition(10, 0, 0)
    self.title:SetHAlign(ANCHOR_LEFT)

    -- Content area (collapsible)
    self.content = self:AddChild(Widget("content"))
    self.content:SetPosition(0, -30, 0)

    -- Toggle indicator
    self.arrow = self.header:AddChild(Text(BODYTEXTFONT, 18, "v"))
    self.arrow:SetPosition(-80, 0, 0)
end)

function CollapsiblePanel:Toggle()
    self.is_expanded = not self.is_expanded
    if self.is_expanded then
        self.content:Show()
        self.arrow:SetString("v")
    else
        self.content:Hide()
        self.arrow:SetString(">")
    end
end

function CollapsiblePanel:Expand()
    self.is_expanded = true
    self.content:Show()
    self.arrow:SetString("v")
end

function CollapsiblePanel:Collapse()
    self.is_expanded = false
    self.content:Hide()
    self.arrow:SetString(">")
end

function CollapsiblePanel:AddContentChild(widget)
    return self.content:AddChild(widget)
end

return CollapsiblePanel
```

### Animated Expand/Collapse
```lua
function CollapsiblePanel:Toggle()
    self.is_expanded = not self.is_expanded
    if self.is_expanded then
        -- Animate open
        self.content:Show()
        self.content:ScaleTo({1, 0, 1}, {1, 1, 1}, 0.2)
        self.arrow:SetString("v")
    else
        -- Animate closed
        self.content:ScaleTo({1, 1, 1}, {1, 0, 1}, 0.2, function()
            self.content:Hide()
        end)
        self.arrow:SetString(">")
    end
end
```

---

## Building a Simple Progress Bar

DST does not have a generic progress bar widget, but you can build one with Image widgets.

```lua
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ProgressBar = Class(Widget, function(self, width, height, color)
    Widget._ctor(self, "ProgressBar")
    self.width = width or 200
    self.height = height or 20
    self.fill_color = color or {0.2, 0.8, 0.2, 1}

    -- Background bar
    self.bg = self:AddChild(Image("images/ui.xml", "button_small.tex"))
    self.bg:SetSize(self.width, self.height)
    self.bg:SetTint(0.2, 0.2, 0.2, 0.8)

    -- Fill bar
    self.fill = self:AddChild(Image("images/ui.xml", "button_small.tex"))
    self.fill:SetSize(self.width, self.height)
    self.fill:SetTint(unpack(self.fill_color))

    -- Text label (optional)
    self.label = self:AddChild(Text(NUMBERFONT, self.height - 4, ""))
    self.label:SetColour(1, 1, 1, 1)

    self:SetPercent(0)
end)

function ProgressBar:SetPercent(pct)
    pct = math.max(0, math.min(1, pct))
    local fillWidth = self.width * pct
    if fillWidth < 1 then fillWidth = 1 end
    self.fill:SetSize(fillWidth, self.height)
    -- Shift fill left so it grows from left edge
    local offset = (fillWidth - self.width) / 2
    self.fill:SetPosition(offset, 0, 0)
end

function ProgressBar:SetLabel(text)
    self.label:SetString(text)
end

function ProgressBar:SetColor(r, g, b, a)
    self.fill_color = {r, g, b, a}
    self.fill:SetTint(r, g, b, a)
end

return ProgressBar
```

---

## Networking / Syncing UI Data

### Architecture Overview

UI widgets run **client-side only**. Game logic and components run **server-side only**. To display server data in a widget, you need to sync data from server to client.

```
Server (mastersim)           Client
┌─────────────────┐         ┌──────────────────┐
│ Components       │         │ Widgets/HUD      │
│ Game Logic       │ ──────> │ Display           │
│ Event Triggers   │ netvars │ User Input        │
│                  │ <────── │                   │
│                  │  RPCs   │                   │
└─────────────────┘         └──────────────────┘
```

### Net Variables (Server -> Client Data Sync)

Net variables automatically replicate values from server to all clients. Changes trigger "dirty" events on clients.

#### Available Types
| Type | Lua Type | Range | Use Case |
|------|----------|-------|----------|
| `net_bool` | boolean | true/false | Flags, toggles |
| `net_byte` | number | 0-255 | Small counts, percentages |
| `net_shortint` | number | -32768 to 32767 | Signed small numbers |
| `net_ushortint` | number | 0-65535 | Unsigned medium numbers |
| `net_int` | number | full 32-bit int | Large numbers |
| `net_uint` | number | unsigned 32-bit | Large unsigned |
| `net_float` | number | 32-bit float | Decimal values |
| `net_string` | string | any string | Names, descriptions |
| `net_hash` | hash | string hash | Prefab names (hashed) |
| `net_entity` | entity | GUID reference | Entity references |
| `net_smallbyte` | number | 0-7 | Very small values (3 bits) |
| `net_tinybyte` | number | 0-3 | Tiny values (2 bits) |

#### Declaring Net Variables
```lua
-- In a prefab fn(), BEFORE inst.entity:SetPristine()
-- Pattern: net_TYPE(entityGUID, "unique.path.name", "dirty_event_name")

inst.quest_count = net_byte(inst.GUID, "mysterybox.quest_count", "questcountdirty")
inst.quest_name = net_string(inst.GUID, "mysterybox.quest_name", "questnamedirty")
inst.is_active = net_bool(inst.GUID, "mysterybox.is_active", "isactivedirty")
inst.target_entity = net_entity(inst.GUID, "mysterybox.target", "targetdirty")
```

#### Setting Values (Server Side)
```lua
-- Only call :set() on server (mastersim)
if TheWorld.ismastersim then
    inst.quest_count:set(5)
    inst.quest_name:set("Kill 10 spiders")
    inst.is_active:set(true)
    inst.target_entity:set(someEntity)
end
```

#### Reading Values (Any Side)
```lua
-- :value() works on both server and client
local count = inst.quest_count:value()
local name = inst.quest_name:value()
local active = inst.is_active:value()
local target = inst.target_entity:value()
```

#### Listening for Changes (Client Side)
```lua
-- "dirty" events fire on clients when server calls :set()
inst:ListenForEvent("questcountdirty", function(inst)
    local newCount = inst.quest_count:value()
    -- Update UI here
end)

inst:ListenForEvent("questnamedirty", function(inst)
    local newName = inst.quest_name:value()
    -- Update UI here
end)
```

#### set_local() for Client-Side Prediction
```lua
-- set_local() updates value WITHOUT syncing or firing dirty event
-- Useful for client-side prediction before server confirms
inst.quest_count:set_local(estimated_count)
```

#### net_event (One-Shot Events)
```lua
-- net_event wraps net_bool for triggering one-shot notifications
-- push() sends a pulse to all clients
inst.quest_complete_event = net_event(inst.GUID, "mysterybox.quest_complete")

-- Server triggers:
inst.quest_complete_event:push()

-- Client listens:
inst:ListenForEvent("mysterybox.quest_complete", function(inst)
    -- Show completion animation/sound
end)
```

### Full NetVar + Widget Example
```lua
-- === In prefab file (scripts/prefabs/questtracker.lua) ===
local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    -- Declare netvars BEFORE SetPristine
    inst.quest_progress = net_byte(inst.GUID, "quest.progress", "questprogressdirty")
    inst.quest_total = net_byte(inst.GUID, "quest.total", "questtotaldirty")
    inst.quest_name = net_string(inst.GUID, "quest.name", "questnamedirty")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst  -- Client stops here, netvars still readable
    end

    -- Server sets initial values
    inst.quest_progress:set(0)
    inst.quest_total:set(10)
    inst.quest_name:set("Kill Spiders")

    return inst
end

-- === In widget file (scripts/widgets/questdisplay.lua) ===
local Widget = require "widgets/widget"
local Text = require "widgets/text"

local QuestDisplay = Class(Widget, function(self, tracker_entity)
    Widget._ctor(self, "QuestDisplay")
    self.tracker = tracker_entity

    self.name_label = self:AddChild(Text(BODYTEXTFONT, 22, ""))
    self.name_label:SetPosition(0, 15, 0)

    self.progress_label = self:AddChild(Text(NUMBERFONT, 18, ""))
    self.progress_label:SetPosition(0, -5, 0)

    -- Listen for dirty events to update UI
    self.tracker:ListenForEvent("questnamedirty", function()
        self:Refresh()
    end)
    self.tracker:ListenForEvent("questprogressdirty", function()
        self:Refresh()
    end)

    self:Refresh()
end)

function QuestDisplay:Refresh()
    self.name_label:SetString(self.tracker.quest_name:value())
    local prog = self.tracker.quest_progress:value()
    local total = self.tracker.quest_total:value()
    self.progress_label:SetString(string.format("%d / %d", prog, total))
end

return QuestDisplay
```

### RPC (Client -> Server Communication)

When the client needs to send data TO the server (e.g., button clicks, player actions).

#### Register Handler (Server Side)
```lua
-- In modmain.lua
-- First arg to handler is always the player who sent the RPC
AddModRPCHandler(modname, "RequestQuest", function(player, quest_type)
    if player and player:IsValid() then
        -- Server-side logic
        print(player:GetDisplayName() .. " requested quest: " .. tostring(quest_type))
        -- Start quest, update netvars, etc.
    end
end)
```

#### Send RPC (Client Side)
```lua
-- Legacy style (still works):
SendModRPCToServer(MOD_RPC[modname]["RequestQuest"], "spider_hunt")

-- Newer style (recommended):
SendModRPCToServer(GetModRPC(modname, "RequestQuest"), "spider_hunt")
```

#### Server -> Client RPC
```lua
-- Register client-side handler
AddClientModRPCHandler(modname, "ShowNotification", function(msg)
    -- Runs on client
    -- Update local UI
end)

-- Server sends to specific player:
SendModRPCToClient(GetClientModRPC(modname, "ShowNotification"), player.userid, "Quest complete!")
```

#### Shard -> Shard RPC
```lua
-- Register shard handler
AddShardModRPCHandler(modname, "SyncData", function(data)
    -- Runs on receiving shard
end)

-- Send to all shards:
SendModRPCToShard(GetShardModRPC(modname, "SyncData"), mydata)
```

#### RPC Argument Limitations
- Numbers (integers, floats)
- Short strings
- Entity references (via inst.GUID or the entity itself)
- No tables, functions, or complex objects
- To send complex data, serialize to string (e.g., JSON-like encoding)

### Classified Pattern (Advanced)

For complex player-specific synced state, DST uses "classified" entities. Each player has a `player_classified` entity with net variables for inventory, health, etc.

```lua
-- Example: Reading synced data via classified
local classified = player.player_classified
-- classified has netvars for health, hunger, sanity, etc.
-- that are automatically synced to the owning client

-- For custom mods, you can create your own classified-like entity:
local function CreateQuestClassified(player)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst.quest_1_progress = net_byte(inst.GUID, "quest.1.progress", "q1dirty")
    inst.quest_2_progress = net_byte(inst.GUID, "quest.2.progress", "q2dirty")
    inst.active_quest_count = net_byte(inst.GUID, "quest.count", "qcountdirty")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Server updates these, clients see changes via dirty events
    inst.quest_1_progress:set(0)
    inst.quest_2_progress:set(0)
    inst.active_quest_count:set(0)

    return inst
end
```

---

## Complete Example: Quest Tracker HUD Widget

Putting it all together -- a custom HUD widget that displays quest progress synced from the server.

### modmain.lua
```lua
-- modmain.lua

local QuestTracker = GLOBAL.require("widgets/questtracker")

-- Hook into the Controls widget to add our tracker
AddClassPostConstruct("widgets/controls", function(self)
    if self.owner then
        self.quest_tracker = self.topright_root:AddChild(QuestTracker(self.owner))
        self.quest_tracker:SetPosition(-200, -50, 0)
    end
end)

-- RPC: Client requests to start a quest
AddModRPCHandler(modname, "StartQuest", function(player, quest_id)
    if player and player:IsValid() then
        -- Server logic to start quest
        print("Starting quest for " .. player:GetDisplayName())
    end
end)

-- RPC: Client requests to toggle tracker visibility
AddModRPCHandler(modname, "ToggleTracker", function(player)
    -- Server acknowledges
end)
```

### scripts/widgets/questtracker.lua
```lua
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"

local QuestTracker = Class(Widget, function(self, owner)
    Widget._ctor(self, "QuestTracker")
    self.owner = owner
    self.is_expanded = true
    self.quest_rows = {}

    -- Semi-transparent background
    self.bg = self:AddChild(Image("images/ui.xml", "button_small.tex"))
    self.bg:SetSize(250, 30)
    self.bg:SetTint(0, 0, 0, 0.5)

    -- Header
    self.header = self:AddChild(Widget("header"))

    self.title = self.header:AddChild(Text(BODYTEXTFONT, 20, "Quests"))
    self.title:SetColour(1, 0.84, 0, 1)  -- gold
    self.title:SetPosition(0, 0, 0)

    -- Toggle button (text-based, no custom art needed)
    self.toggle = self.header:AddChild(ImageButton(
        "images/ui.xml", "button_small.tex",
        "images/ui.xml", "button_small_over.tex"
    ))
    self.toggle:ForceImageSize(20, 20)
    self.toggle:SetPosition(110, 0, 0)
    self.toggle:SetOnClick(function() self:ToggleExpand() end)

    -- Content area
    self.content = self:AddChild(Widget("content"))
    self.content:SetPosition(0, -25, 0)

    -- Start listening for quest updates
    self:StartUpdating()
end)

function QuestTracker:ToggleExpand()
    self.is_expanded = not self.is_expanded
    if self.is_expanded then
        self.content:Show()
    else
        self.content:Hide()
    end
end

function QuestTracker:AddQuestRow(quest_name, progress, total)
    local row = self.content:AddChild(Widget("quest_row"))
    local yPos = -30 * #self.quest_rows

    row.name = row:AddChild(Text(BODYTEXTFONT, 16, quest_name))
    row.name:SetPosition(-50, yPos, 0)
    row.name:SetHAlign(ANCHOR_LEFT)
    row.name:SetColour(1, 1, 1, 1)

    row.progress = row:AddChild(Text(NUMBERFONT, 16,
        string.format("%d/%d", progress, total)))
    row.progress:SetPosition(80, yPos, 0)
    row.progress:SetColour(0.5, 1, 0.5, 1)

    table.insert(self.quest_rows, row)
    self:ResizeBackground()
    return row
end

function QuestTracker:ClearQuests()
    for _, row in ipairs(self.quest_rows) do
        row:Kill()
    end
    self.quest_rows = {}
    self:ResizeBackground()
end

function QuestTracker:ResizeBackground()
    local rowCount = math.max(1, #self.quest_rows)
    local height = 30 + (rowCount * 30)
    self.bg:SetSize(250, height)
    self.bg:SetPosition(0, -(height/2) + 15, 0)
end

function QuestTracker:OnUpdate(dt)
    -- Periodic refresh from netvars or world state
    -- Override this based on your data source
end

return QuestTracker
```

---

## Reference: Existing Mods for Studying

| Mod | What to Learn | Source |
|-----|--------------|--------|
| **Combined Status** | Badge manipulation, AddClassPostConstruct on multiple widgets, focus show/hide | [GitHub](https://github.com/rezecib/Combined-Status) |
| **Craftpot** | AddClassPostConstruct on controls, custom recipe widget | [GitHub](https://github.com/IMalyugin/craftpot) |
| **Insight** | Advanced networking, RPCs, tooltip widgets | [GitHub](https://github.com/penguin0616/Insight) |
| **Too Many Items** | Toggleable menu widget, container-based layout | [GitHub](https://github.com/taichunmin/dst-too-many-items) |
| **Notebook** | Custom screen with text input | [GitHub](https://github.com/WayOfModding/DST-Mod-Notebook) |

---

## Gotchas

1. **Widgets are client-only** -- They exist per-player in their local game. Server knows nothing about them.

2. **GLOBAL prefix in modmain.lua** -- When requiring widgets in modmain, use `GLOBAL.require()`. In widget files (scripts/widgets/), use `require()` directly.

3. **Font constants must be accessible** -- In modmain.lua use `GLOBAL.BODYTEXTFONT`. In widget scripts, `BODYTEXTFONT` works directly.

4. **SetPristine boundary** -- Net variables must be declared BEFORE `SetPristine()`. Components go AFTER.

5. **Dirty events fire before Lua update** -- If you set multiple netvars at once, all their dirty events fire before the next frame update.

6. **RPC argument limits** -- You cannot send tables or complex objects via RPC. Serialize to string if needed.

7. **Widget positions are relative to parent** -- (0,0) is the center of the parent widget, not the screen corner. Use anchor roots on Controls for screen-relative positioning.

8. **Kill cleanup** -- Always `:Kill()` widgets when done. Leaked widgets cause memory issues. Listen for `"onremove"` on the owner entity to clean up.

9. **HUD scale** -- Use `TheFrontEnd:GetHUDScale()` if you need to account for user HUD scaling settings, but widgets added as children of Controls root nodes auto-scale.

10. **ThePlayer is nil on dedicated servers** -- Always check before using in widget code that might run early.

---

## Sources

- DST Game Scripts: `widgets/widget.lua`, `widgets/text.lua`, `widgets/image.lua`, `widgets/imagebutton.lua`, `widgets/badge.lua`, `widgets/controls.lua`, `widgets/statusdisplays.lua`, `widgets/scrollablelist.lua`, `screens/playerhud.lua`
- Combined Status mod by rezecib: https://github.com/rezecib/Combined-Status
- Klei Forums widget discussions: https://forums.kleientertainment.com/forums/topic/114746-tutorial-for-adding-new-uihudwidgets/
- DST API Docs Wiki: https://dst-api-docs.fandom.com/
- Klei Forums netvars guide: https://forums.kleientertainment.com/forums/topic/48264-net_variable-types-and-sending-data-from-serverhost-to-clients/
- Klei Forums RPC API: https://forums.kleientertainment.com/forums/topic/122473-new-modding-rpcs-api/
- DST Game Scripts repo: https://github.com/penguin0616/dst_gamescripts
