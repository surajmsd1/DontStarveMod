# Challenge System Documentation

## Overview

The challenge system provides directed gameplay for Don't Starve Together, guiding players through the first 35 days (Autumn + Winter) with structured objectives, escalating threats, and meaningful rewards.

Every day has something to do. No more "what now?" moments.

---

## Timeline

### Autumn (Days 1-20)

| Day | ID | Challenge | Type | Purpose |
|-----|----|-----------|------|---------|
| 1 | `survive` | Survive the Night | Directed | Learn night = death without light |
| 2 | `expand` | Expand | Directed | Learn exploration, find first tower |
| 3 | `tools` | Tools | Directed | Learn crafting basics |
| 4 | `think` | Think | Directed | Science Machine unlocks the game |
| 5 | `first_tower` | First Tower | Directed | Learn scout mode |
| 6 | `explore_peninsulas` | Explore Before Settling | Directed | Force exploration before base |
| 7 | `home` | Home | Directed | Establish permanent base |
| 8 | `hound_warning` | Hound Warning | Directed | Create urgency, player choice |
| 9 | `battle_ready` | Battle Ready | Directed | Learn armor + weapons |
| 10 | `first_blood` | First Blood | Boss | First real combat test |
| 11 | `sustainable_food` | Sustainable Food | Directed | Learn crock pot, drying rack |
| 12-14 | `the_hunt` | The Hunt | Boss | First mini-boss (Spider Queen/Treeguard) |
| 14-15 | `second_tower` | Second Tower | Directed | Expand territory |
| 16 | `hounds_return` | Hounds Return | Boss | Harder hound wave with fire hound |
| 17-18 | `third_tower` | Third Tower | Directed | Complete exploration |
| 18-19 | `bearger_warning` | Bearger Warning | Directed | Build tension for first giant |
| 20 | `bearger` | Bearger | Boss | First seasonal giant |

### Winter (Days 21-35)

| Day | ID | Challenge | Type | Purpose |
|-----|----|-----------|------|---------|
| 21 | `winter_begins` | Winter Begins | Directed | Learn cold mechanics |
| 22-24 | `walrus_hunt` | Walrus Hunt | Directed | Hunting gameplay, rare loot |
| 25-27 | `ice_hounds` | Ice Hounds | Boss | Combat variant, freeze mechanic |
| 28-31 | `deerclops_warning` | Deerclops Warning | Directed | Build dread over 4 days |
| 32-33 | `deerclops` | Deerclops | Boss | Winter climax boss |

---

## Random Event Pool

These trigger 1-2 per week, adding variety between playthroughs.

### Autumn Pool

| ID | Event | Frequency | Purpose |
|----|-------|-----------|---------|
| `gobbler_swarm` | Gobbler Swarm | 1/week | Comedy, free drumsticks |
| `spider_migration` | Spider Migration | 1/week | Threat, free silk |
| `pig_festival` | Pig Festival | 1/week | Friendly, free gifts |
| `meteor_shower` | Meteor Shower | 1/week | Resources from sky |
| `butterfly_storm` | Butterfly Storm | 1/week | Free food |
| `mushroom_bloom` | Mushroom Bloom | 1/week | Teaching, sanity food |

### Winter Pool

| ID | Event | Frequency | Purpose |
|----|-------|-----------|---------|
| `blizzard` | Blizzard | 1/week | Survival pressure |
| `aurora` | Aurora Borealis | 1/week | Beauty, sanity boost |
| `pengull_parade` | Pengull Parade | 1/week | Comedy, eggs |
| `frozen_bounty` | Frozen Bounty | 1/week | Free frozen meat |
| `warm_pocket` | Warm Pocket | 1/week | Safe zone appears |

---

## Optional Discoveries

Found through exploration, not required for progression.

| ID | Location | Challenge | Reward |
|----|----------|-----------|--------|
| `pig_ally` | Pig Village | Befriend pigs | Pig helpers |
| `beefalo_rancher` | Savanna | Find beefalo | Beefalo hat, manure |
| `grave_robber` | Graveyard | Dig 5 graves | Random loot |
| `swamp_explorer` | Swamp | Survive 2 min | Tentacle spike |
| `underground` | Cave entrance | Enter caves | Light sources |

---

## Challenge Types

### Directed
- Happen at specific times
- Core progression path
- Cannot be skipped
- Always provide clear objectives

### Random
- Drawn from seasonal pool
- 1-2 per week
- Different each playthrough
- Add surprise and variety

### Boss
- Checkpoint encounters
- Must defeat to continue
- Cannot flee (arena boundary)
- Major rewards

### Optional
- Found through exploration
- Extra rewards for curious players
- Not required for progression
- Teach advanced mechanics

---

## Scope Types

### AllPlayers (Team Progress)
- Objectives shared across team
- Anyone's contribution counts
- "Collect 20 grass" = team total, not each
- One completion unlocks for everyone

### Individual
- Each player tracks separately
- Each player gets own reward
- Used for personal milestones

### FirstToComplete
- Race condition
- First player gets bonus reward
- Others still complete normally

---

## Challenge Document Template

Each challenge has its own file following `_template.md` structure:

```
docs/challenges/
├── README.md              (this file)
├── _template.md           (copy for new challenges)
├── day-01-survive.md
├── day-02-expand.md
├── ...
└── events/
    ├── random-gobbler-swarm.md
    └── ...
```

---

## Implementation Status

| Challenge | Documented | Implemented | Tested |
|-----------|:----------:|:-----------:|:------:|
| day-01-survive | ⬜ | ⬜ | ⬜ |
| day-02-expand | ⬜ | ⬜ | ⬜ |
| day-03-tools | ⬜ | ⬜ | ⬜ |
| day-04-think | ⬜ | ⬜ | ⬜ |
| day-05-first-tower | ⬜ | ⬜ | ⬜ |
| day-06-explore-peninsulas | ⬜ | ⬜ | ⬜ |
| day-07-home | ⬜ | ⬜ | ⬜ |
| day-08-hound-warning | ⬜ | ⬜ | ⬜ |
| day-09-battle-ready | ⬜ | ⬜ | ⬜ |
| day-10-first-blood | ⬜ | ⬜ | ⬜ |
| day-11-sustainable-food | ⬜ | ⬜ | ⬜ |
| day-12-the-hunt | ⬜ | ⬜ | ⬜ |
| day-14-second-tower | ⬜ | ⬜ | ⬜ |
| day-16-hounds-return | ⬜ | ⬜ | ⬜ |
| day-17-third-tower | ⬜ | ⬜ | ⬜ |
| day-18-bearger-warning | ⬜ | ⬜ | ⬜ |
| day-20-bearger | ⬜ | ⬜ | ⬜ |
| day-21-winter-begins | ⬜ | ⬜ | ⬜ |
| day-22-walrus-hunt | ⬜ | ⬜ | ⬜ |
| day-25-ice-hounds | ⬜ | ⬜ | ⬜ |
| day-28-deerclops-warning | ⬜ | ⬜ | ⬜ |
| day-32-deerclops | ⬜ | ⬜ | ⬜ |

---

## Design Principles

### Every Day Has Something
- Never more than 1-2 days without an objective
- Always building toward something
- Clear "what to do next"

### Teach Through Play
- Mechanics introduced through challenges
- Tips appear at right moments
- Failure teaches, doesn't punish harshly

### Escalating Pressure
- Day 1: survive night
- Day 10: survive hounds
- Day 20: survive Bearger
- Day 33: survive Deerclops

### Exploration Before Settlement
- Can't build Fire Pit until 3 peninsulas explored
- Prevents bad base locations
- Uses tower scout system

### Player Agency
- Hound timing choice (now, later, harder)
- Mini-boss choice (Spider Queen or Treeguard)
- Optional content available
- Multiple paths through random events

---

## Quick Reference

### Checkpoint Bosses

| Day | Boss | Difficulty | Must Kill |
|-----|------|------------|-----------|
| 10 | Hound Wave (4-6) | ★★☆☆☆ | Yes |
| 12-14 | Spider Queen OR Treeguard | ★★☆☆☆ | Yes |
| 16 | Hound Wave + Fire Hound | ★★★☆☆ | Yes |
| 20 | Bearger | ★★★☆☆ | Yes |
| 25-27 | Ice Hound Wave | ★★★☆☆ | Yes |
| 32-33 | Deerclops | ★★★★☆ | Yes |

### Key Unlocks

| Challenge | Unlocks |
|-----------|---------|
| First Tower | Scout mode tutorial |
| Explore Peninsulas | Fire Pit (base building) |
| Bearger | Belt of Hunger recipe |
| Deerclops | Eyebrella recipe |

### Rewards Philosophy

- **Early game:** Notes and hints, not items
- **Mid game:** Useful tools earned through challenge
- **Boss kills:** Unique recipes and trophies
- **Never:** Overpowered handouts that skip gameplay
