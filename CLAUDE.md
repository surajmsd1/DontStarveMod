# Mystery Box Mod - Development Guidelines

## Project Vision
Transform DST from survival grind into goal-oriented gameplay for expert players. The Mystery Box acts as a DnD gamemaster - triggering events, quests, and challenges.

## Core Principle: Build It Right The First Time

### Before Writing ANY Code:
1. **Check the docs/** folder for existing patterns
2. **Search `docs/dst-api/` for the API you need**
3. **Look at working examples** before inventing new approaches
4. **Test the smallest piece first** in DST console before building full features

### DST Modding Rules (CRITICAL)

#### GLOBAL Namespace (modmain.lua)
```lua
-- In modmain.lua, you MUST prefix game APIs with GLOBAL:
GLOBAL.SpawnPrefab("spider")     -- NOT SpawnPrefab()
GLOBAL.TheNet:Announce("Hi")     -- NOT TheNet
GLOBAL.AllPlayers                -- NOT AllPlayers
GLOBAL.TheWorld                  -- NOT TheWorld
GLOBAL.pcall(fn)                 -- NOT pcall()
```

#### Prefab Files (scripts/prefabs/*.lua)
```lua
-- Prefabs run in DIFFERENT environment - no GLOBAL available!
-- These work directly:
SpawnPrefab("item")
CreateEntity()
TheWorld.ismastersim
Asset("ANIM", "anim/file.zip")
Prefab("name", fn, assets)

-- To access modmain globals from prefabs:
if rawget(_G, "MysteryBoxEventManager") then
    _G.MysteryBoxEventManager:DoSomething()
end
```

#### Always Add At Top of Prefabs
```lua
require "prefabutil"
```

## Documentation Structure

All DST modding knowledge lives in `docs/`:
```
docs/
├── dst-api/
│   ├── README.md           # Quick reference index
│   ├── world-state.md      # Time, seasons, phase
│   ├── entities.md         # Prefabs, spawning, transforms
│   ├── components.md       # All component APIs
│   ├── events.md           # Event system, listeners
│   ├── networking.md       # Multiplayer, announcements
│   └── prefab-list.md      # All spawnable prefab names
├── patterns/
│   ├── multi-wave-event.md # How to do timed waves
│   ├── loot-tables.md      # Weighted random selection
│   ├── custom-prefab.md    # Creating new entities
│   └── quest-system.md     # Multi-step objectives
├── examples/
│   └── [code snippets]
└── external/
    └── links.md            # Links to wikis, forums, repos
```

## How To Use This System

### Adding a New Feature:
1. Check `docs/dst-api/` - does the API exist?
2. Check `docs/patterns/` - is there a template?
3. Check `docs/examples/` - working code?
4. If not found → Research → Document → Then implement

### When Researching:
- Add findings to appropriate `docs/` file
- Include working code examples
- Note gotchas and common errors
- Link to sources

## Code Organization

### Current Structure
```
DontStarveMod/
├── modinfo.lua          # Version, metadata
├── modmain.lua          # Entry point + ALL event logic (temporary)
├── scripts/
│   └── prefabs/
│       ├── mysterybox.lua
│       ├── cursedbox.lua
│       └── goldenbox.lua
└── docs/                # Knowledge base (NEW)
```

### Target Structure (Future)
```
DontStarveMod/
├── modinfo.lua
├── modmain.lua          # Slim entry (~100 lines)
├── scripts/
│   ├── core/            # Shared utilities
│   ├── events/          # Event definitions (data-driven)
│   ├── systems/         # Quest tracker, progression
│   └── prefabs/         # Entities
└── docs/                # Knowledge base
```

## Testing Strategy

### Before Uploading to Workshop:
1. **Syntax check**: `luac -p filename.lua`
2. **Console test**: Spawn items, trigger events manually
3. **Verify logs**: Check for `[Mystery Box]` messages

### Useful Console Commands:
```lua
-- Spawn boxes
c_spawn("mysterybox")
c_spawn("cursedbox")
c_spawn("goldenbox")

-- Check event system
print(MysteryBoxEventManager and "OK" or "NIL")
print("Events: " .. MysteryBoxEventManager:GetEventCount())

-- Force trigger
MysteryBoxEventManager:OnDayStart()
MysteryBoxEventManager:TriggerBoxEvent("cursed", ThePlayer)

-- Time control
c_skip(480)  -- Skip 1 day
TheWorld:PushEvent("ms_setphase", "day")  -- Force dawn
```

## Future Goals

### Phase 1: Stability (Current)
- [ ] Fix daily event triggers
- [ ] Verify all 21 events work
- [ ] Document what we have

### Phase 2: Organization
- [ ] Build docs/ knowledge base
- [ ] Refactor modmain.lua into modules
- [ ] Create reusable event templates

### Phase 3: Goal-Oriented Gameplay
- [ ] Quest chains (multi-step objectives)
- [ ] Progression system (team levels)
- [ ] Win conditions (actual endings)
- [ ] Custom prefabs (new items, mobs)

### Phase 4: Custom Content
- [ ] Custom animations
- [ ] New bosses
- [ ] New weapons/items
- [ ] Custom sounds

## Research Priorities

When building docs/, focus on:
1. **Spawning & Positioning** - How to place things in world
2. **Combat System** - Health, damage, targeting
3. **Animation System** - How sprites work, state graphs
4. **Component Reference** - All built-in components
5. **Prefab Catalog** - Every spawnable thing

## External Resources

- DST Wiki: https://dontstarve.wiki.gg/
- Klei Forums Modding: https://forums.kleientertainment.com/forums/forum/79-dont-starve-together-mods-and-tools/
- DST Game Scripts: https://github.com/penguin0616/dst_gamescripts
- API Docs: https://dst-api-docs.fandom.com/

## Remember

1. **Check docs first** before writing code
2. **Small tests** before big features
3. **Document what you learn** for next time
4. **GLOBAL in modmain, direct in prefabs**
5. **Version bump** before every Workshop upload
