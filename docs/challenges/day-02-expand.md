# Challenge: Expand

## Metadata

| Field | Value |
|-------|-------|
| **ID** | `expand` |
| **Day** | 2 |
| **Duration** | Until objectives complete (no time limit) |
| **Type** | Directed |
| **Scope** | AllPlayers |

---

## Purpose

### Why This Challenge?

After surviving night 1, new players often make a critical mistake: they build a base immediately at spawn. Spawn locations are usually terrible - no resources, no allies, bad biome. This challenge forces exploration BEFORE settling. It also introduces the tower system, which is the core navigation mechanic of the mod.

### What It Teaches

- Don't build where you spawn
- Explore to find good locations
- Towers exist and are important
- Mystery Boxes unlock towers
- The world has multiple biomes worth discovering

### Design Goals

| Goal | Achieved |
|------|:--------:|
| Provides clear direction | ✅ |
| Boss/combat encounter | ❌ |
| Learning experience | ✅ |
| Gateway to optional content | ✅ |
| Creates urgency/tension | ❌ |
| Rewards exploration | ✅ |
| Teaches multiplayer cooperation | ✅ |

---

## The Challenge

### Trigger Condition

- Day 2 begins
- `survive` challenge completed

### Announcement Text

```
YOU SURVIVED.

Now explore. Don't build a base yet.

Find the Lookout Tower. It will help you see the world.
```

### Objectives

| # | Objective | Target | Shared | Required |
|---|-----------|--------|:------:|:--------:|
| 1 | Discover new biome | 2 | ✅ | ✅ |
| 2 | Find the Lookout Tower | 1 | ✅ | ✅ |
| 3 | Find the Mystery Box | 1 | ✅ | ❌ |

### Tips Shown During Challenge

| Trigger | Tip Text |
|---------|----------|
| On start | "Keep moving. Pick up resources as you walk." |
| First biome discovered | "New biome! Different biomes have different resources." |
| Second biome discovered | "Good exploring. Now find the tower." |
| Player near tower (100 units) | "The tower is close. Look for a tall structure." |
| Tower found | "This tower is dormant. A Mystery Box nearby may wake it." |
| Box found | "Mystery Boxes contain loot AND unlock nearby towers." |
| Evening Day 2 | "Night approaches. Make sure you have light!" |

### Failure Conditions

- None (no time limit)
- If player dies, challenge continues on respawn

---

## Rewards

### On Completion

**Items:**
- None

**Unlocks:**
- Nearest tower marked on minimap (if not found naturally)
- Mystery Box marked on minimap (if not found naturally)
- Challenge `tools` (Day 3)

**Announcements:**
```
THE WORLD OPENS.

You've found a tower and glimpsed what's out there.

Tomorrow: craft proper tools.
```

### On Failure

- Cannot fail, just takes longer

---

## Implementation

### Setup (On Challenge Start)

- Find nearest Lookout Tower to spawn point
- Mark tower on minimap with "?" icon (unknown location)
- Spawn Mystery Box halfway between spawn and tower (if not already present)
- Mark box on minimap with chest icon
- Track biome discoveries

### Tracking Logic

**Objective 1: Discover New Biomes**
- Event: Player enters biome (check ground turf type)
- Condition: Biome type not previously visited
- Increment: +1 per new biome type
- Note: Biome types include forest, savanna, swamp, desert, rocky, marsh, etc.

**Objective 2: Find Tower**
- Event: Player proximity check
- Condition: Any player within 10 units of Lookout Tower
- Complete: First time a player gets close

**Objective 3: Find Mystery Box (Optional)**
- Event: Player proximity check
- Condition: Any player within 10 units of Mystery Box
- Complete: First time a player gets close
- Note: Optional, but helps teach the box→tower connection

### Completion Logic

- Mark challenge complete when objectives 1 and 2 done
- Objective 3 (box) is bonus, not required
- Queue Day 3 challenge (`tools`)
- If player didn't find tower/box naturally, reveal on map

### Multiplayer Behavior

**Shared Objectives:**
- Any player discovering a biome counts
- Any player finding tower/box counts
- First to find something = found for everyone

**Rewards:**
- Map markers visible to all players

### Edge Cases

| Situation | Handling |
|-----------|----------|
| Player already explored on Day 1 | Count previous discoveries |
| Tower very far from spawn | Mark on map after Day 2 evening |
| No Mystery Box nearby | Spawn one at reasonable distance |
| Player ignores challenge | Gentle reminder each morning |

---

## Testing

### Console Commands

```lua
-- Start challenge
StartChallenge("expand")

-- Complete objectives
CompleteObjective("expand", 1)  -- biomes
CompleteObjective("expand", 2)  -- tower
CompleteObjective("expand", 3)  -- box

-- Teleport to nearest tower
c_goto("lookouttower")

-- Teleport to mystery box
c_goto("mysterybox")

-- Check biomes visited
PrintBiomesDiscovered()
```

### Test Scenarios

| # | Scenario | Expected Result |
|---|----------|-----------------|
| 1 | Walk to two biomes + tower | Challenge completes |
| 2 | Find box but not tower | Objective 3 done, 2 still pending |
| 3 | Stay at spawn all day | No progress, reminder shown |
| 4 | One player finds tower | All players get credit |

### Success Criteria

- [ ] Challenge starts on Day 2
- [ ] Biome discovery tracks correctly
- [ ] Tower proximity detected
- [ ] Box proximity detected
- [ ] Map markers appear for undiscovered objectives
- [ ] Works in multiplayer (shared discovery)
- [ ] Optional objective works correctly

---

## Dependencies

### Requires Before

- `survive` (Day 1)

### Unlocks After

- `tools` (Day 3)
- Tower system introduction

### Systems Used

- [x] Objective Dashboard UI
- [x] Announcement System
- [x] Minimap Markers
- [ ] Arena System
- [ ] Loot System
- [x] Tower System
- [ ] Boss Encounter System

---

## Notes

This challenge has NO time limit intentionally. After the pressure of Day 1, players need a breather. Let them explore at their own pace.

The Mystery Box objective is OPTIONAL because we don't want to force box opening yet - that comes with the tower challenge on Day 5. Here we just want them to see that boxes and towers exist near each other.

The biome discovery teaches players that the world is varied. A player who only stays in forest never learns about swamp reeds, desert cacti, or savanna beefalo.

If players are struggling to find the tower by evening, we mark it on the map. No punishment for exploration failure - just help them along.
