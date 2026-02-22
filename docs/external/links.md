# External DST Modding Resources

## Official & Community Wikis
- **DST Wiki**: https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together
- **Modding Portal**: https://dontstarve.wiki.gg/wiki/Guides/Modding_Guide
- **Prefab List**: https://dontstarve.wiki.gg/wiki/Prefab (all spawnable names)

## API Documentation
- **DST API Docs (Fandom)**: https://dst-api-docs.fandom.com/wiki/Main_Page
- **Component Reference**: https://dst-api-docs.fandom.com/wiki/Category:Components
- **Events List**: https://dst-api-docs.fandom.com/wiki/Category:Events

## Source Code References
- **DST Game Scripts (GitHub)**: https://github.com/penguin0616/dst_gamescripts
  - `/scripts/prefabs/` - All vanilla prefab definitions
  - `/scripts/components/` - All component implementations
  - `/scripts/stategraphs/` - Animation state machines
  - `/scripts/brains/` - AI behavior trees
  - `/scripts/widgets/` - UI components

## Forums & Community
- **Klei Forums - Mods & Tools**: https://forums.kleientertainment.com/forums/forum/79-dont-starve-together-mods-and-tools/
- **Klei Forums - Tutorials**: https://forums.kleientertainment.com/forums/forum/80-tutorials-and-guides/
- **Steam Workshop**: https://steamcommunity.com/app/322330/workshop/
- **Reddit r/dontstarve**: https://www.reddit.com/r/dontstarve/

## Useful Workshop Mods (Code Reference)

### Popular Open-Source Mods
- **Geometric Placement**: Good UI/input example
- **Combined Status**: HUD customization patterns
- **Global Positions**: Networking examples
- **Show Me**: Entity inspection patterns

### GitHub Repositories
- https://github.com/rezecib/Combined-Status - Status display mod
- https://github.com/penguin0616/Insight - Entity info mod

## Animation & Art
- **Spriter Pro**: Animation tool used by Klei ($60, creates .scml files)
- **ktools**: https://github.com/nsimplex/ktools - Convert Klei formats
- **TEX/Build format**: DST's proprietary asset format
  - .tex = Texture atlas
  - .zip = Animation build (contains anim.bin, build.bin, atlas textures)

## Key Forum Threads

### Getting Started
- "How to Make a DST Mod (Step by Step)":
  https://forums.kleientertainment.com/forums/topic/15856-tutorial-how-to-make-a-mod-1-my-first-mod/

### Common Problems
- "GLOBAL vs local namespace": Understanding mod environment
- "mastersim explained": Server vs client code
- "Why won't my prefab spawn?": Common prefab issues

### Advanced Topics
- "Custom animations tutorial": Creating .scml files
- "Networking and NetVars": Multiplayer sync

## YouTube Tutorials

### Beginner
- Search: "Don't Starve Together modding tutorial"
- Search: "DST custom item mod"

### Intermediate
- Search: "DST custom character mod"
- Search: "DST custom creature mod"

### Animation
- Search: "Spriter DST animation"
- Search: "DST custom animation import"

## Quick Reference Cards

### GLOBAL Namespace (modmain.lua)
```lua
GLOBAL.SpawnPrefab("spider")
GLOBAL.TheNet:Announce("msg")
GLOBAL.AllPlayers
GLOBAL.TheWorld
GLOBAL.GetTime()
GLOBAL.pcall(fn)
```

### Prefab Environment (scripts/prefabs/*.lua)
```lua
-- These work directly:
SpawnPrefab("spider")
CreateEntity()
TheWorld.ismastersim
Asset("ANIM", "anim/file.zip")
Prefab("name", fn, assets)

-- Access modmain globals:
if rawget(_G, "MyGlobal") then
    _G.MyGlobal:DoThing()
end
```

### Common Console Commands
```lua
c_spawn("prefabname")        -- Spawn at cursor
c_give("prefabname")         -- Add to inventory
c_skip(480)                  -- Skip 1 day (480 seconds)
c_reset()                    -- Reload to last save
c_godmode()                  -- Toggle godmode
TheWorld:PushEvent("ms_setphase", "day")  -- Force daytime
```

## Our Internal Docs

See `docs/dst-api/` for detailed API reference:
- [world-state.md](../dst-api/world-state.md) - Time, seasons, phases
- [entities.md](../dst-api/entities.md) - Spawning, transforms
- [components.md](../dst-api/components.md) - Component reference
- [events.md](../dst-api/events.md) - Event system
- [networking.md](../dst-api/networking.md) - Multiplayer
- [prefab-list.md](../dst-api/prefab-list.md) - Spawnable prefabs

See `docs/patterns/` for reusable code:
- [multi-wave-event.md](../patterns/multi-wave-event.md) - Wave spawning
- [loot-tables.md](../patterns/loot-tables.md) - Random loot
- [custom-prefab.md](../patterns/custom-prefab.md) - Creating entities
- [boss-fight.md](../patterns/boss-fight.md) - Boss encounters
- [quest-system.md](../patterns/quest-system.md) - Quest tracking
