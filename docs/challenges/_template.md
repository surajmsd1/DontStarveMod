# Challenge: [NAME]

## Metadata

| Field | Value |
|-------|-------|
| **ID** | `challenge_id` |
| **Day** | [Exact day OR range, e.g., "12-14"] |
| **Duration** | [Time limit in seconds, or "None"] |
| **Type** | [Directed / Random / Boss / Optional] |
| **Scope** | [AllPlayers / Individual / FirstToComplete] |

---

## Purpose

### Why This Challenge?

[2-3 sentences explaining why this challenge exists at this point in the progression. What problem does it solve? What would happen without it?]

### What It Teaches

- [Primary mechanic or skill]
- [Secondary knowledge gained]
- [Any other learnings]

### Design Goals

| Goal | Achieved |
|------|:--------:|
| Provides clear direction | ⬜ |
| Boss/combat encounter | ⬜ |
| Learning experience | ⬜ |
| Gateway to optional content | ⬜ |
| Creates urgency/tension | ⬜ |
| Rewards exploration | ⬜ |
| Teaches multiplayer cooperation | ⬜ |

---

## The Challenge

### Trigger Condition

[What starts this challenge?]
- Day X begins
- Previous challenge completed
- Player enters area
- Item picked up
- etc.

### Announcement Text

```
[Exact text shown to all players when challenge starts]
```

### Objectives

| # | Objective | Target | Shared | Required |
|---|-----------|--------|:------:|:--------:|
| 1 | [Description] | [Count] | ✅/❌ | ✅/❌ |
| 2 | [Description] | [Count] | ✅/❌ | ✅/❌ |

### Tips Shown During Challenge

| Trigger | Tip Text |
|---------|----------|
| On start | "[Tip shown immediately]" |
| After 2 min | "[Tip shown after delay]" |
| On objective 1 complete | "[Tip for next step]" |
| On low health | "[Combat tip]" |

### Failure Conditions

- [What causes failure - time runs out, all players die, etc.]
- [Or "None - challenge stays active until complete"]

---

## Rewards

### On Completion

**Items:**
- [Item 1]
- [Item 2]

**Unlocks:**
- [Recipe unlocked]
- [Feature unlocked]
- [Next challenge unlocked]

**Announcements:**
```
[Victory message shown to players]
```

### On Failure

- [What happens - retry available? Penalty?]
- [When can they retry?]

---

## Implementation

### Setup (On Challenge Start)

[Describe what needs to happen when this challenge begins]

- Spawn [what] at [where]
- Mark [what] on minimap
- Set [state variable]
- Play [sound/announcement]

### Tracking Logic

[How does the game know when objectives are completed?]

**Objective 1: [Name]**
- Event to listen for: `[DST event name]`
- Condition: [What makes it count]
- Increment: [When to add progress]

**Objective 2: [Name]**
- Event to listen for: `[DST event name]`
- Condition: [What makes it count]
- Increment: [When to add progress]

### Completion Logic

[What happens when all objectives are done?]

- Remove [spawned things]
- Grant [rewards]
- Trigger [next challenge]
- Save [progress]

### Multiplayer Behavior

**Shared Objectives:**
- [How team progress works]
- [Who gets credit for what]

**Rewards:**
- [Does everyone get rewards?]
- [Or just contributors?]

### Edge Cases

| Situation | Handling |
|-----------|----------|
| Player already has required item | [Auto-complete? Skip?] |
| Player dies during challenge | [Reset? Continue?] |
| Player disconnects | [Pause? Continue?] |
| New player joins mid-challenge | [See progress? Start fresh?] |
| Challenge target already dead | [Spawn new? Skip?] |

---

## Testing

### Console Commands

```lua
-- Start this challenge manually
StartChallenge("challenge_id")

-- Complete specific objective
CompleteObjective("challenge_id", 1)

-- Fail the challenge
FailChallenge("challenge_id")

-- Check current state
PrintChallengeState("challenge_id")

-- Skip to the day this triggers
c_skip([days_to_skip])

-- Spawn required items/mobs for testing
c_spawn("[prefab_name]")
```

### Test Scenarios

| # | Scenario | Expected Result |
|---|----------|-----------------|
| 1 | [Normal completion path] | [What should happen] |
| 2 | [Edge case] | [What should happen] |
| 3 | [Multiplayer scenario] | [What should happen] |
| 4 | [Failure scenario] | [What should happen] |

### Success Criteria

- [ ] Challenge starts at correct time
- [ ] All objectives track correctly
- [ ] Tips appear at right moments
- [ ] Rewards granted on completion
- [ ] Next challenge unlocks
- [ ] Works in multiplayer
- [ ] Handles edge cases gracefully

---

## Dependencies

### Requires Before

- [Previous challenge ID that must be complete]
- [Or "None - starts automatically on day X"]

### Unlocks After

- [Next challenge ID]
- [Features unlocked]
- [Recipes unlocked]

### Systems Used

- [ ] Objective Dashboard UI
- [ ] Announcement System
- [ ] Minimap Markers
- [ ] Arena System
- [ ] Loot System
- [ ] Tower System
- [ ] Boss Encounter System

---

## Notes

[Any additional context, design decisions, or implementation notes]
