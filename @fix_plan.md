# Ralph Fix Plan - Mystery Box: DnD Gamemaster Mod

## CRITICAL: DST Modding Rules (READ FIRST!)

### GLOBAL Namespace Rules
In DST mods, you CANNOT use standard Lua globals directly. You MUST use:
- `GLOBAL.pcall` not `pcall`
- `GLOBAL.pairs` not `pairs` (if outside modmain scope)
- `GLOBAL.SpawnPrefab` not `SpawnPrefab` (in modmain.lua)
- `GLOBAL.TheNet` not `TheNet`
- `GLOBAL.AllPlayers` not `AllPlayers`
- `GLOBAL.TheWorld` not `TheWorld`

### Prefab Files Are Different!
Files in `scripts/prefabs/` run in a DIFFERENT environment where:
- `SpawnPrefab`, `CreateEntity`, `Prefab`, `Asset`, `TheWorld` ARE available directly
- Add `require "prefabutil"` at top of prefab files
- To access modmain globals, use `rawget(_G, "MysteryBoxEventManager")`
- Do NOT use `GLOBAL.` prefix in prefab files - it doesn't exist there!

### What We Learned The Hard Way
1. `Class()` needs `GLOBAL.Class()` in modmain
2. `os.time()` doesn't exist - use `GLOBAL.GetTime()`
3. `pcall()` needs `GLOBAL.pcall()` in modmain
4. Prefab files can't see `GLOBAL` - they use `_G` instead
5. Always test after EVERY change - DST errors aren't always clear

## Current Issue
1. Events registered but not executing properly
2. Cursed/Golden boxes say something but events don't actually fire
3. Daily events not triggering on day change
4. Need MORE exciting content!

## Sprint 6: Fix Events + Epic Content

### Critical - Fix Event System (DO THIS FIRST)
- [ ] Debug why MysteryBoxEventManager:TriggerBoxEvent isn't spawning enemies
- [ ] Add verbose logging: log when event starts, when spawning, when complete
- [ ] Verify SpawnNear() is actually creating entities
- [ ] Check if GLOBAL.AllPlayers returns players correctly
- [ ] Test TheNet:Announce actually shows messages to players
- [ ] Make sure world:DoTaskInTime works for delayed spawns

### Critical - Fix Box Events
- [ ] Cursed box says "dangerous" but nothing spawns - fix this!
- [ ] Golden box should shower player with loot - make it rain items!
- [ ] Add sound effects when events trigger (use inst.SoundEmitter)
- [ ] Add visual feedback (screen shake? light flash?)

### High Priority - Multi-Stage Arena Fights
Create "Arena Challenge" event:
- [ ] Wave 1: Announce "WAVE 1: SPIDERS!" → spawn 8 spiders → wait for death → drop spear + armor
- [ ] Wave 2: Announce "WAVE 2: HOUNDS!" → spawn 5 hounds → wait for death → drop gold + gems
- [ ] Wave 3: Announce "FINAL WAVE: THE GUARDIAN!" → spawn Treeguard → drop epic loot
- [ ] Use world:DoTaskInTime to chain waves with 30-60 second delays
- [ ] Track spawned enemies, trigger next wave when all dead

Create "Shadow Invasion" event:
- [ ] Spawn crawling horrors progressively (2, then 4, then 6)
- [ ] Each wave harder, announces "THE SHADOWS GROW STRONGER"
- [ ] Surviving all waves = nightmare fuel x5 + dark sword

Create "Giant Awakens" event:
- [ ] Announce "SOMETHING MASSIVE STIRS... 60 SECONDS TO PREPARE!"
- [ ] Immediately drop supplies: armor, weapons, healing
- [ ] After 60s, spawn Deerclops OR Bearger (random)
- [ ] If killed within 3 minutes = massive loot explosion (30+ items)

### High Priority - Epic Reward Events
- [ ] "LOOT EXPLOSION" - 30 random items burst from ground with physics
- [ ] "GEAR UP!" - every player gets: spear, log armor, football helmet, torch
- [ ] "FEAST TIME" - spawn 20 cooked food items (meat, fish, veggies)
- [ ] "MAGIC STORM" - 10 gems + 5 magic items (amulets, staffs) rain down
- [ ] "BUILDER'S DREAM" - 40 logs, 40 rocks, 20 gold, 10 rope spawn

### Medium Priority - Chaos Events
- [ ] "FROG APOCALYPSE" - 50 frogs + force rain + spawn umbrellas
- [ ] "BEEFALO STAMPEDE" - 15 beefalo spawn and charge in one direction
- [ ] "METEOR SHOWER" - spawn falling rocks with goldnuggets inside
- [ ] "TREEGUARD ARMY" - 3 Treeguards but also 20 living logs
- [ ] "PENGULL INVASION" - 30 pengulls + ice + fish everywhere

### Medium Priority - Team Events
- [ ] "PROTECT THE CHEST" - spawn chest with loot, enemies attack it for 2 min
- [ ] "KING OF THE HILL" - marked area, stay in it while enemies attack, survive = win
- [ ] "BOSS RUSH" - 3 mini-bosses back to back, massive rewards at end

### Low Priority - Polish
- [ ] Event cooldown (no repeats within 3 events)
- [ ] Difficulty scaling (day 1-10 = easy, 11-30 = medium, 30+ = hard)
- [ ] Multiplayer scaling (more players = more enemies AND more loot)
- [ ] Sound effects for all major events
- [ ] Screen announcements with colors if possible

## Code Patterns To Use

### Spawning Entities Correctly
```lua
-- In modmain.lua
local function SpawnNear(prefab, x, z, radius)
    local entity = GLOBAL.SpawnPrefab(prefab)
    if entity then
        local angle = math.random() * 2 * math.pi
        local dist = math.random() * radius
        entity.Transform:SetPosition(x + math.cos(angle) * dist, 0, z + math.sin(angle) * dist)
    end
    return entity
end
```

### Multi-Wave Event Pattern
```lua
local function StartArenaChallenge(world, player)
    local x, y, z = player.Transform:GetWorldPosition()

    -- Wave 1
    GLOBAL.TheNet:Announce("ARENA CHALLENGE - WAVE 1: SPIDERS!")
    for i = 1, 8 do SpawnNear("spider", x, z, 10) end

    -- Wave 2 after 45 seconds
    world:DoTaskInTime(45, function()
        GLOBAL.TheNet:Announce("WAVE 2: HOUNDS APPROACH!")
        for i = 1, 5 do SpawnNear("hound", x, z, 12) end
        -- Drop wave 1 reward
        SpawnNear("spear", x, z, 3)
        SpawnNear("armorwood", x, z, 3)
    end)

    -- Wave 3 after 90 seconds
    world:DoTaskInTime(90, function()
        GLOBAL.TheNet:Announce("FINAL WAVE: THE GUARDIAN AWAKENS!")
        SpawnNear("leif", x, z, 15)
        -- Drop wave 2 reward
        for i = 1, 5 do SpawnNear("goldnugget", x, z, 5) end
    end)
end
```

### Accessing Event Manager from Prefabs
```lua
-- In prefab files (cursedbox.lua, etc.)
if rawget(_G, "MysteryBoxEventManager") then
    _G.MysteryBoxEventManager:TriggerBoxEvent("cursed", doer)
end
```

## Testing Commands
```lua
-- Check if manager exists
print(MysteryBoxEventManager and "OK" or "NIL")

-- Check event count
print("Events: " .. MysteryBoxEventManager:GetEventCount())

-- Force trigger daily
MysteryBoxEventManager:OnDayStart()

-- Test specific event
MysteryBoxEventManager:TriggerBoxEvent("cursed", ThePlayer)

-- Spawn test boxes
c_spawn("mysterybox")
c_spawn("cursedbox")
c_spawn("goldenbox")
```

## File Structure
```
DontStarveMod/
├── modinfo.lua          -- Version, metadata
├── modmain.lua          -- ALL event logic lives here (inline, no require)
├── scripts/
│   └── prefabs/
│       ├── mysterybox.lua   -- Basic random loot box
│       ├── cursedbox.lua    -- Triggers challenge events
│       └── goldenbox.lua    -- Triggers reward events
```

## Success Criteria
- [ ] Opening cursed box spawns actual enemies + gives rewards after
- [ ] Opening golden box rains down 10+ items
- [ ] Daily events trigger and announce at dawn
- [ ] At least 3 multi-stage events working
- [ ] Events feel EXCITING and DRAMATIC, not boring
