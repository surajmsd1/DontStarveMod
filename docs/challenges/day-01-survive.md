# Challenge: Survive the Night

## Metadata

| Field | Value |
|-------|-------|
| **ID** | `survive` |
| **Day** | 1 |
| **Duration** | Until dawn of Day 2 |
| **Type** | Directed |
| **Scope** | AllPlayers |

---

## Purpose

### Why This Challenge?

This is the first moment of the game. New players spawn with nothing and have approximately 8 real-time minutes before darkness kills them. Without guidance, many players wander aimlessly, fail to gather materials, and die to Charlie on their first night. This challenge creates immediate urgency and teaches the most fundamental survival loop: gather → craft → light → survive.

### What It Teaches

- Night = death without light
- Basic gathering (grass, twigs, flint)
- Torch crafting (2 grass + 2 twigs)
- Campfire as backup (2 logs + 3 grass)
- Time pressure creates action

### Design Goals

| Goal | Achieved |
|------|:--------:|
| Provides clear direction | ✅ |
| Boss/combat encounter | ❌ |
| Learning experience | ✅ |
| Gateway to optional content | ❌ |
| Creates urgency/tension | ✅ |
| Rewards exploration | ❌ |
| Teaches multiplayer cooperation | ✅ |

---

## The Challenge

### Trigger Condition

- Immediately on game start (Day 1, any player spawns)
- Triggers once per world

### Announcement Text

```
NIGHT COMES IN 8 MINUTES.

You need light to survive.

Gather grass and twigs. Craft a torch.
```

### Objectives

| # | Objective | Target | Shared | Required |
|---|-----------|--------|:------:|:--------:|
| 1 | Collect Grass | 10 | ✅ | ✅ |
| 2 | Collect Twigs | 10 | ✅ | ✅ |
| 3 | Collect Flint | 5 | ✅ | ✅ |
| 4 | Survive until dawn | 1 night | ✅ | ✅ |

### Tips Shown During Challenge

| Trigger | Tip Text |
|---------|----------|
| On start | "Pick up EVERYTHING you walk past. Grass, twigs, flint." |
| 50% objectives done | "Good progress. Keep gathering." |
| 4 min before night (dusk) | "⚠️ DUSK APPROACHING. Do you have torch materials?" |
| 2 min before night | "⚠️ NIGHT IN 2 MINUTES. Craft a torch: 2 Grass + 2 Twigs" |
| 10 sec before night | "🔥 MAKE A TORCH NOW! Night is here!" |
| Night begins, no light | "🔥 CRAFT A TORCH NOW! You're dying!" |
| Player near fire | "Stay near the light. Dawn is coming." |
| Dawn arrives | "You survived. Health check incoming..." |

### Failure Conditions

- All players die before dawn
- Challenge resets on respawn (can retry immediately)

---

## Rewards

### On Completion

**Health-Based Tiered Rewards:**

| Health % | Tier | Items | Message |
|----------|------|-------|---------|
| 100% | Perfect | 2 Torches + 1 Flint + "Untouched" title | "Perfect! Not a scratch." |
| 75-99% | Great | 2 Torches + 1 Flint | "Well done. Minor scratches." |
| 50-74% | Good | 1 Torch | "You made it, but barely." |
| 25-49% | Close | Nothing | "That was too close. Be more careful." |
| 1-24% | Barely | Nothing | "You almost died. Learn from this." |

**Unlocks:**
- Challenge `night_torch` completes (sub-challenge)
- Challenge `tools` (Day 2) begins

**Announcements:**
```
DAWN BREAKS.

You survived your first night.

[Tier-specific message]
```

### On Failure

- Players respawn at portal
- Challenge restarts automatically
- No penalty, just try again
- Tip on respawn: "Gather faster this time. Night waits for no one."

---

## Sub-Challenge: Night Torch Reminder

### Trigger
- 10 seconds before night phase begins

### Check
- Does player have torch in inventory?
- Does player have torch equipped?
- Is player near a fire?

### If No Light Source Ready
```
⚠️ 10 SECONDS UNTIL DARKNESS!

You have no light! Craft a TORCH now!
2 Grass + 2 Twigs = Torch

[Flash crafting menu highlight on torch recipe]
```

### If Light Source Ready
```
Night approaches. You're prepared.
```

---

## Implementation

### Setup (On Challenge Start)

**Step 1: Initialize Challenge State**
```
- Set challenge_active = true
- Set grass_collected = 0
- Set twigs_collected = 0
- Set flint_collected = 0
- Set night_survived = false
- Record start_time
```

**Step 2: Register Event Listeners**
```
- Listen for "onpickup" events (grass, twigs, flint)
- Listen for "ms_setphase" events (dusk, night, day)
- Listen for "death" events (player died)
```

**Step 3: Show UI**
```
- Display objective dashboard
- Show countdown to night (calculate from world time)
```

### Tracking Logic

**Objective 1: Collect Grass**
```
Event: Player picks up "cutgrass" prefab
Action:
  1. Increment grass_collected += 1
  2. Update UI progress bar (grass_collected / 10)
  3. If grass_collected >= 10, mark objective complete
  4. Play subtle "tick" sound on progress
```

**Objective 2: Collect Twigs**
```
Event: Player picks up "twigs" prefab
Action:
  1. Increment twigs_collected += 1
  2. Update UI progress bar (twigs_collected / 10)
  3. If twigs_collected >= 10, mark objective complete
  4. Play subtle "tick" sound on progress
```

**Objective 3: Collect Flint**
```
Event: Player picks up "flint" prefab
Action:
  1. Increment flint_collected += 1
  2. Update UI progress bar (flint_collected / 5)
  3. If flint_collected >= 5, mark objective complete
  4. Play subtle "tick" sound on progress
```

**Objective 4: Survive Until Dawn**
```
Event: World phase changes to "day" on Day 2
Condition: At least one player is alive
Action:
  1. Mark objective complete
  2. Calculate health percentage of all alive players
  3. Use LOWEST health player for tier calculation
  4. Trigger reward distribution
```

### Night Warning Implementation

**Dusk Warning (4 min before night)**
```
Event: World phase changes to "dusk"
Action: Show tip "DUSK APPROACHING..."
```

**2 Minute Warning**
```
Event: Periodic check, 2 min before night
Action: Show tip "NIGHT IN 2 MINUTES..."
```

**10 Second Warning (Critical)**
```
Event: Periodic check, 10 sec before night
Check:
  1. For each player:
     - Has "torch" in inventory?
     - Has "torch" equipped?
     - Within 5 units of fire/firepit/campfire?
  2. If ANY check passes: Show "You're prepared"
  3. If ALL checks fail: Show PANIC warning, flash torch recipe
```

**Night Begins, No Light**
```
Event: World phase = "night" AND player taking darkness damage
Action: Show "CRAFT A TORCH NOW!" every 2 seconds until they have light
```

### Reward Distribution

```
On dawn of Day 2:
  1. Get all alive players
  2. Calculate lowest health percentage among them
  3. Determine reward tier
  4. For each alive player:
     - Spawn reward items at their feet
     - Show tier message
  5. Mark challenge complete
  6. Start Day 2 challenge
```

### Multiplayer Behavior

**Resource Collection:**
- ANY player picking up grass/twigs/flint adds to team total
- Progress bar shows team progress, not individual

**Survival:**
- Challenge succeeds if ANY player survives
- Health tier based on LOWEST health survivor (team is as strong as weakest link)

**Rewards:**
- All surviving players get same reward tier
- Dead players get nothing (incentive to help each other)

### Edge Cases

| Situation | Handling |
|-----------|----------|
| Player already has materials from wandering | Counts toward objectives on pickup, not retroactively |
| Player picks up 20 grass | Only counts 10, extra doesn't matter |
| Player dies, others survive | Challenge continues, dead player misses reward |
| All players die | Challenge fails, restarts on ANY respawn |
| Player joins mid-challenge | Sees current progress, can contribute |
| Player disconnects | Progress preserved, reconnect continues |
| It's already Day 2+ | Skip this challenge |

---

## Testing

### Implementation Checklist

**UI Testing:**
- [ ] Objective dashboard appears on game start
- [ ] Progress bars start at 0
- [ ] Progress bars update when picking up items
- [ ] Progress bars animate smoothly (not jumpy)
- [ ] Completed objectives show checkmark
- [ ] Timer/countdown to night displays correctly

**Resource Tracking:**
- [ ] Picking up 1 grass increments grass counter by 1
- [ ] Picking up 1 twig increments twig counter by 1
- [ ] Picking up 1 flint increments flint counter by 1
- [ ] Counter stops at target (no over-counting display)
- [ ] Team total is shared (Player A picks grass, Player B sees progress)

**Night Warnings:**
- [ ] Dusk warning appears at correct time
- [ ] 2-minute warning appears at correct time
- [ ] 10-second warning appears at correct time
- [ ] 10-second check correctly detects torch in inventory
- [ ] 10-second check correctly detects torch equipped
- [ ] 10-second check correctly detects nearby fire
- [ ] Panic warning appears if no light source

**Rewards:**
- [ ] 100% health gives 2 torches + 1 flint + title
- [ ] 75-99% health gives 2 torches + 1 flint
- [ ] 50-74% health gives 1 torch
- [ ] 25-49% health gives nothing + warning message
- [ ] 1-24% health gives nothing + stern warning
- [ ] Items spawn at player feet
- [ ] Message displays correctly

**Failure/Reset:**
- [ ] All players dying triggers failure
- [ ] Failure message displays
- [ ] Challenge resets on respawn
- [ ] Progress resets to 0 on retry

**Multiplayer:**
- [ ] Player A picks grass, Player B sees counter increase
- [ ] Player A survives at 50% health, Player B at 100% = tier uses 50%
- [ ] Player A dies, Player B survives = Player B gets reward, A gets nothing

### Console Commands

```lua
-- Start this challenge manually
StartChallenge("survive")

-- Check current progress
PrintChallengeState("survive")
-- Output: grass: 5/10, twigs: 3/10, flint: 2/5, night_survived: false

-- Manually add progress (for testing)
AddChallengeProgress("survive", "grass", 5)

-- Complete objective instantly
CompleteObjective("survive", 1)  -- grass
CompleteObjective("survive", 2)  -- twigs
CompleteObjective("survive", 3)  -- flint

-- Skip to dusk (test warnings)
TheWorld:PushEvent("ms_setphase", "dusk")

-- Skip to night (test survival)
TheWorld:PushEvent("ms_setphase", "night")

-- Skip to dawn (complete challenge)
c_skip(1)

-- Set player health (test reward tiers)
c_sethealth(1.0)   -- 100%
c_sethealth(0.75)  -- 75%
c_sethealth(0.5)   -- 50%
c_sethealth(0.25)  -- 25%

-- Give player torch (test 10-sec check)
c_give("torch")

-- Spawn campfire nearby (test 10-sec check)
c_spawn("campfire")
```

### Test Scenarios

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| 1 | Perfect run | Gather all, survive at 100% | Get best rewards + title |
| 2 | Sloppy run | Gather all, survive at 60% | Get 1 torch only |
| 3 | Near death | Gather all, survive at 10% | No reward, warning message |
| 4 | Death | Die to Charlie | Challenge fails, restarts |
| 5 | No torch warning | Have no torch at 10 sec | Panic warning appears |
| 6 | Torch ready | Have torch at 10 sec | "You're prepared" message |
| 7 | Fire ready | Near campfire at 10 sec | "You're prepared" message |
| 8 | Multiplayer gather | P1 gets grass, P2 gets twigs | Both see shared progress |
| 9 | Multiplayer health | P1 at 100%, P2 at 30% | Both get 30% tier reward |

---

## Dependencies

### Requires Before

- None (first challenge)

### Unlocks After

- `tools` (Day 2 challenge)

### Systems Used

- [x] Objective Dashboard UI
- [x] Announcement System
- [x] Tip System (timed tips)
- [ ] Minimap Markers
- [ ] Arena System
- [x] Loot System (reward spawning)
- [ ] Tower System
- [ ] Boss Encounter System

---

## Notes

**Why health-based rewards?**
This teaches that survival quality matters. Getting through the night at 10% health means you did something wrong. Getting through untouched means you prepared well. The reward difference reinforces this.

**Why team uses lowest health?**
Prevents one player from hiding safely while others struggle. The team is only as strong as its weakest survivor. This encourages helping each other.

**Why the 10-second torch check?**
This is the critical teaching moment. Many players die because they don't realize how fast night comes. The 10-second warning + panic mode if no torch creates a memorable "oh shit" moment that they won't forget.

**Why no big rewards?**
Day 1 is about learning, not getting stuff. Torches are useful but not game-changing. The real reward is survival knowledge.
