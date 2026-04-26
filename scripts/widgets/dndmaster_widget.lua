-- DnD Master HUD widget
-- Pops a portrait + speech bubble in the bottom-left corner of every
-- player's HUD when the server pushes a dialogue line. Stays for a
-- few seconds, then fades out. Pure HUD widget — no game pause, no
-- modal screen.
--
-- Spawn pattern in modmain.lua (server triggers, all clients render):
--   Server: SendModRPCToClient(...) with {speaker, text, duration}
--   Client RPC handler calls player._dnd_widget:Speak(speaker, text)
--
-- Asset paths for portraits are best-effort defaults; refine once we
-- confirm what's actually packaged with the game install.

local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"

-- Portrait atlases. These are educated guesses — DST ships character
-- avatars under images/avatars/. If a path fails to load the widget
-- silently falls back to a colored square (set in TrySetPortrait).
local PORTRAITS = {
    maxwell = {atlas = "images/avatars/avatar_waxwell.xml", tex = "avatar_waxwell.tex"},
    charlie = {atlas = "images/avatars/avatar_charlie.xml", tex = "avatar_charlie.tex"},
}

-- Speaker name colors (warm gold for Maxwell, cold purple for Charlie)
local SPEAKER_COLORS = {
    maxwell = {0.95, 0.85, 0.55, 1},
    charlie = {0.75, 0.55, 0.95, 1},
}

local DEFAULT_DURATION = 6  -- seconds the bubble stays before fading

local DnDMasterWidget = Class(Widget, function(self, owner)
    Widget._ctor(self, "DnDMasterWidget")
    self.owner = owner

    -- Anchor to bottom-left of the screen. SCALEMODE_PROPORTIONAL keeps
    -- the widget at a sane size across resolutions.
    self:SetVAnchor(ANCHOR_BOTTOM)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self:SetPosition(180, 130)  -- offset inwards from the corner

    -- Container for the whole popup so we can fade/tween it as one unit.
    self.root = self:AddChild(Widget("dnd_root"))
    self.root:Hide()

    -- Bubble background (dark parchment vibe with warm border)
    self.frame = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.frame:SetTint(0.25, 0.2, 0.15, 0.95)
    self.frame:SetSize(384, 100)
    self.frame:SetPosition(40, 0)  -- shifted right of portrait

    self.bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetTint(0.1, 0.08, 0.08, 0.95)
    self.bg:SetSize(380, 96)
    self.bg:SetPosition(40, 0)

    -- Portrait image (best-effort; falls back to colored square)
    self.portrait_bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.portrait_bg:SetTint(0.3, 0.25, 0.18, 1)
    self.portrait_bg:SetSize(78, 78)
    self.portrait_bg:SetPosition(-160, 0)

    self.portrait = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.portrait:SetSize(72, 72)
    self.portrait:SetPosition(-160, 0)

    -- Speaker name label (top of bubble)
    self.speaker_label = self.root:AddChild(Text(BUTTONFONT, 18))
    self.speaker_label:SetPosition(40, 32)
    self.speaker_label:SetHAlign(ANCHOR_LEFT)
    self.speaker_label:SetString("")

    -- Body text. Typewritten in Speak() so it doesn't appear all at once.
    self.body = self.root:AddChild(Text(TALKINGFONT or BODYTEXTFONT, 22))
    self.body:SetPosition(40, -4)
    self.body:SetRegionSize(360, 70)
    self.body:EnableWordWrap(true)
    self.body:SetHAlign(ANCHOR_LEFT or 0)
    self.body:SetString("")
    self.body:SetColour(0.95, 0.92, 0.85, 1)

    -- Internal state
    self._speak_task = nil
    self._fade_task = nil
    self._char_task = nil
end)

-- Try to swap the portrait Image to a real character avatar. If the
-- atlas isn't found, leave the placeholder square. SetTexture is
-- safe to call with bad paths — the engine logs a warning and the
-- existing texture stays.
function DnDMasterWidget:TrySetPortrait(speaker)
    local p = PORTRAITS[speaker]
    if not p then
        self.portrait:SetTint(0.5, 0.5, 0.5, 1)
        return
    end
    -- The Image widget's :SetTexture(atlas, tex) does the work.
    local ok = pcall(function() self.portrait:SetTexture(p.atlas, p.tex) end)
    if not ok then
        -- Fallback: tint the square to match the speaker
        local c = SPEAKER_COLORS[speaker] or {0.6, 0.6, 0.6, 1}
        self.portrait:SetTint(c[1], c[2], c[3], 1)
    else
        self.portrait:SetTint(1, 1, 1, 1)
    end
end

-- Cancel any pending tasks so a new line doesn't fight an old one.
function DnDMasterWidget:CancelPending()
    if self._speak_task then self._speak_task:Cancel(); self._speak_task = nil end
    if self._fade_task then self._fade_task:Cancel(); self._fade_task = nil end
    if self._char_task then self._char_task:Cancel(); self._char_task = nil end
end

-- Show a line. Called on each client when the server broadcasts dialogue.
--   speaker: "maxwell" | "charlie"
--   text:    the string
--   duration: how long the bubble stays after typing finishes (sec)
function DnDMasterWidget:Speak(speaker, text, duration)
    if not text or text == "" then return end
    duration = duration or DEFAULT_DURATION

    self:CancelPending()
    self.root:Show()

    -- Speaker label + portrait
    local color = SPEAKER_COLORS[speaker] or {0.9, 0.9, 0.9, 1}
    self.speaker_label:SetColour(color[1], color[2], color[3], color[4])
    self.speaker_label:SetString(speaker == "charlie" and "CHARLIE" or "THE MASTER")
    self:TrySetPortrait(speaker)

    -- Typewriter effect: reveal one character every ~30ms. Snappy
    -- enough to read at normal pace, slow enough to feel intentional.
    local full = text
    local idx = 0
    self.body:SetString("")

    local function typeOne()
        idx = idx + 1
        if idx > #full then
            self._char_task = nil
            -- Schedule fade-out after the bubble has settled.
            self._fade_task = self.inst:DoTaskInTime(duration, function()
                self.root:Hide()
                self._fade_task = nil
            end)
            return
        end
        self.body:SetString(string.sub(full, 1, idx))
        self._char_task = self.inst:DoTaskInTime(0.03, typeOne)
    end
    typeOne()
end

-- Force-hide (e.g. on player death or world unload)
function DnDMasterWidget:Silence()
    self:CancelPending()
    self.root:Hide()
end

return DnDMasterWidget
