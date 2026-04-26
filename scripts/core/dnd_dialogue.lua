-- DnD Master dialogue library
-- Pure data table of voice lines for Maxwell (Master) and Charlie (Mistress).
-- The widget that renders these is in scripts/widgets/dndmaster_widget.lua.
-- The dispatcher that picks lines and sends them to clients lives in
-- modmain.lua under the DnDMaster_* helpers.
--
-- Each entry: {speaker = "maxwell"|"charlie", text = "..."}
-- Categories are used to pick a contextually-appropriate line; if a
-- category has no entries the dispatcher falls back to "generic".

local DnDDialogue = {}

DnDDialogue.SPEAKERS = {
    MAXWELL = "maxwell",   -- Smug game master, taunting but fair
    CHARLIE = "charlie",   -- Cryptic, dangerous, whispers
}

-- Pools of lines per category. The first word is who's speaking.
DnDDialogue.LINES = {
    -- Player joined / world load
    intro = {
        {speaker = "maxwell", text = "Ah. Another guest. Try not to die *too* quickly."},
        {speaker = "maxwell", text = "Welcome to the game. The rules? You'll learn them. The hard way."},
        {speaker = "maxwell", text = "Oh good, fresh meat. I was getting bored."},
        {speaker = "charlie", text = "...we've been waiting..."},
    },

    -- Boss event warning (mini-tier, dusk before)
    boss_warning_mini = {
        {speaker = "maxwell", text = "Something stirs in the woods tonight. Sleep lightly."},
        {speaker = "maxwell", text = "I'd sharpen a spear if I were you. Tomorrow's guests are... rough."},
        {speaker = "maxwell", text = "Dawn brings teeth and bark. Be ready, or be lunch."},
    },

    -- Boss event warning (big bad, dusk before)
    boss_warning_bigbad = {
        {speaker = "maxwell", text = "Hmm. The dice rolled poorly for you tonight. *Very* poorly."},
        {speaker = "maxwell", text = "Some things are better left sleeping. Yet here we are."},
        {speaker = "charlie", text = "...you should run... but where would you go..."},
        {speaker = "maxwell", text = "I'd offer a wager, but the house always wins this one."},
    },

    -- Boss arrived (morning of)
    boss_arrived = {
        {speaker = "maxwell", text = "Ah. Right on schedule. Try to make it interesting."},
        {speaker = "maxwell", text = "The curtain rises. Don't disappoint your audience."},
    },

    -- Boss defeated
    boss_defeated = {
        {speaker = "maxwell", text = "Lucky. Take your spoils before I change my mind."},
        {speaker = "maxwell", text = "Hm. Better than I expected. I almost feel cheated."},
        {speaker = "charlie", text = "...one less in my garden..."},
    },

    -- Player died
    player_died = {
        {speaker = "maxwell", text = "And so another piece leaves the board."},
        {speaker = "maxwell", text = "Tsk. Were you even *trying*?"},
        {speaker = "charlie", text = "...rest now..."},
    },

    -- Treasure hunt fired
    treasure_hint = {
        {speaker = "maxwell", text = "I've left a little something out there. Find it before nightfall, hm?"},
        {speaker = "maxwell", text = "A gift. Don't say I never did anything for you."},
    },

    -- Day milestone (every 10 days)
    day_milestone = {
        {speaker = "maxwell", text = "Still alive? Impressive. Or perhaps just stubborn."},
        {speaker = "maxwell", text = "Ten more sunrises. The forest is starting to remember your face."},
    },

    -- Generic / fallback
    generic = {
        {speaker = "maxwell", text = "Carry on, then. The shadows are watching."},
        {speaker = "charlie", text = "..."},
    },
}

-- Pick a random line for a category. Falls back to "generic" if the
-- requested category is empty or missing.
function DnDDialogue.Pick(category)
    local pool = DnDDialogue.LINES[category]
    if not pool or #pool == 0 then
        pool = DnDDialogue.LINES.generic
    end
    return pool[math.random(#pool)]
end

return DnDDialogue
