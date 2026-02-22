# Ralph Task: Build DST Modding Knowledge Base

## Goal
Create a comprehensive, organized reference for DST modding so future development is faster and works first time.

## IMPORTANT: Read CLAUDE.md First!
The project guidelines are in CLAUDE.md. Follow them.

## Rules
1. **Don't copy entire websites** - summarize and link
2. **Include working code examples** for every API
3. **Note gotchas and common errors**
4. **Organize by topic** not by source
5. **Test examples** if possible (note if untested)

## Sprint 7: Documentation & Research

### Phase 1: Core API Documentation
Research and document in `docs/dst-api/`:

- [ ] **world-state.md** - Complete time/season/phase API
  - All TheWorld.state properties
  - WatchWorldState patterns
  - How to detect day transitions
  - Season change hooks

- [ ] **entities.md** - Entity/Prefab system
  - SpawnPrefab details
  - Transform component
  - Entity lifecycle (creation, removal)
  - Tags system
  - How entities are networked (mastersim vs client)

- [ ] **components.md** - Full component reference
  - List ALL built-in components (from dst_gamescripts repo)
  - For each: purpose, key methods, example usage
  - Focus on: health, combat, inventory, locomotor, lootdropper

- [ ] **events.md** - Event system
  - ListenForEvent patterns
  - PushEvent usage
  - Common events (death, attacked, picked, etc.)
  - World events

- [ ] **networking.md** - Multiplayer specifics
  - mastersim vs client
  - Network components
  - RPC system (if relevant)
  - TheNet API

- [ ] **prefab-list.md** - Spawnable prefabs catalog
  - Mobs (spiders, hounds, bosses)
  - Items (weapons, armor, tools, food)
  - Resources (logs, rocks, gems)
  - Structures
  - Organize by category

### Phase 2: Animation & Custom Content
Research and document:

- [ ] **docs/dst-api/animations.md**
  - How DST animations work (Spriter format)
  - AnimState component
  - Banks and builds
  - PlayAnimation, PushAnimation
  - State graphs basics

- [ ] **docs/dst-api/stategraphs.md**
  - What are state graphs
  - How mobs use them
  - Creating custom behavior

- [ ] **docs/dst-api/brains.md**
  - AI behavior trees
  - How mobs decide what to do
  - Creating custom AI

### Phase 3: Patterns Library
Create reusable templates in `docs/patterns/`:

- [ ] **multi-wave-event.md** - Timed wave spawning
  - DoTaskInTime chains
  - Tracking spawned entities
  - Victory detection

- [ ] **loot-tables.md** - Weighted random selection
  - Weight calculation
  - Rarity tiers

- [ ] **custom-prefab.md** - Creating new entities
  - Full prefab file template
  - Common components to add
  - Assets declaration

- [ ] **boss-fight.md** - Boss encounter pattern
  - Prep phase, fight phase, reward phase
  - Health tracking
  - Multi-phase bosses

- [ ] **quest-system.md** - Multi-step objectives
  - State tracking
  - Progress persistence
  - Completion rewards

### Phase 4: External Resources
Update `docs/external/links.md`:

- [ ] Find and add best tutorial threads from Klei Forums
- [ ] Find good open-source mods on GitHub to study
- [ ] Add YouTube tutorial links
- [ ] Link to specific helpful wiki pages

## Research Sources

1. **DST Game Scripts Repo**: https://github.com/penguin0616/dst_gamescripts
   - `/scripts/prefabs/` - Study vanilla prefab patterns
   - `/scripts/components/` - All component implementations
   - `/scripts/stategraphs/` - Animation state machines

2. **DST API Docs**: https://dst-api-docs.fandom.com/

3. **Klei Forums**: https://forums.kleientertainment.com/forums/forum/79-dont-starve-together-mods-and-tools/

4. **DST Wiki**: https://dontstarve.wiki.gg/

## Output Format

For each doc file, use this structure:
```markdown
# Topic Name

## Overview
Brief explanation of what this is.

## Quick Reference
Table or bullet list of key APIs.

## Detailed API

### FunctionName
**Purpose**: What it does
**Parameters**:
- param1: description
**Returns**: what it returns
**Example**:
\`\`\`lua
code here
\`\`\`
**Gotchas**: Common mistakes

## Common Patterns
Reusable code snippets.

## See Also
Links to related docs.

## Sources
Where this info came from.
```

## Success Criteria
- [ ] Can look up any common DST API in docs/
- [ ] Each doc has working code examples
- [ ] Gotchas are documented (no more GLOBAL surprises)
- [ ] Prefab list is comprehensive and categorized
- [ ] Patterns are copy-paste ready
