# Mission Tracking UI System

## Overview

The Mission Tracking system provides a shared, multiplayer-aware goal tracker with a collapsible HUD panel. All players see the same missions and contribute to the same objectives. The UI auto-updates with progress, timers, and boss health bars.

## Architecture

```
Server Side                          Client Side
+-----------------------+            +------------------+
| MissionTracker        |   RPC      | MissionPanel     |
| (scripts/systems/     | --------> | (scripts/widgets/ |
|  mission_tracker.lua) |  JSON     |  missionpanel.lua)|
+-----------------------+            +------------------+
         |                                    |
         v                                    v
+-----------------------+            Shows on player HUD
| MissionDefs           |            (top-right corner)
| (scripts/systems/     |            Collapsible with
|  mission_defs.lua)    |            click on header
+-----------------------+
```

### Data Flow
1. **Server** creates `MissionTracker` during world init
2. Event listeners track item pickups, kills, and building across ALL players
3. When progress changes, server serializes mission state to JSON
4. JSON is broadcast to all clients via `SendModRPCToClient`
5. **Client** `MissionPanel` widget rebuilds its display from the JSON data
6. Periodic sync (1s interval) keeps timers and boss health updated

## Quick Start

### Starting a Mission from Console

```lua
-- Start a specific mission by ID
MysteryBoxStartMission("spider_hunt")
MysteryBoxStartMission("deerclops_hunt")
MysteryBoxStartMission("gold_rush")

-- Start a random mission
MysteryBoxStartRandomMission()

-- Start a random mission of a specific category
MysteryBoxStartRandomMission("boss")      -- Boss fight
MysteryBoxStartRandomMission("challenge") -- Combat challenge
MysteryBoxStartRandomMission("gather")    -- Resource gathering
```

### Starting a Mission from an Event

```lua
-- In an event executor or box activation:
local function ExecuteMyEvent(data, world, target)
    -- Start a mission alongside the event
    if GLOBAL.MysteryBoxStartMission then
        GLOBAL.MysteryBoxStartMission("hound_defense")
    end
end
```

### Starting a Mission from a Prefab

```lua
-- From a prefab file (scripts/prefabs/*.lua):
if rawget(_G, "MysteryBoxStartMission") then
    _G.MysteryBoxStartMission("spider_hunt")
end
```

## Creating Custom Missions

### Mission Definition Format

Missions are defined as Lua tables in `scripts/systems/mission_defs.lua`:

```lua
MissionDefs.my_mission = {
    -- Required fields
    id = "my_mission",              -- Unique identifier
    name = "My Mission",            -- Display name in UI

    -- Optional fields
    description = "Do the thing!",  -- Shown in announcements
    icon = "prefab_name",           -- For future icon display
    category = "challenge",         -- "challenge" | "boss" | "gather" | "explore"
    time_limit = 480,               -- Seconds, or nil for no limit

    -- Objectives (at least one required)
    objectives = {
        { type = "collect", target = "goldnugget", required = 10, label = "Gold Nuggets" },
        { type = "kill",    target = "spider",     required = 15, label = "Spiders" },
        { type = "boss",    target = "deerclops",  required = 1,  label = "Deerclops" },
        { type = "build",   target = "wall_stone", required = 5,  label = "Stone Walls" },
    },

    -- Rewards (pick one format)
    rewards = { loot_pack = "boss_loot" },
    -- OR
    rewards = { items = {"redgem", "bluegem", "purplegem"} },

    -- Optional: Spawn boss on mission start
    on_start_spawn = {
        prefab = "deerclops",
        count = 1,                  -- defaults to 1
        announce = "A Deerclops appears!",
    },

    -- Optional callbacks
    on_complete = function(tracker, mission)
        -- Custom logic when mission completes
    end,
    on_fail = function(tracker, mission)
        -- Custom logic when mission fails (timeout)
    end,
}
```

### Objective Types

| Type      | Tracks                          | `target` value     |
|-----------|---------------------------------|--------------------|
| `collect` | Item pickups (all players)      | Prefab name        |
| `kill`    | Entity kills (all players)      | Prefab name        |
| `boss`    | Boss kills (entity_death event) | Prefab name        |
| `build`   | Structure placement             | Prefab name        |
| `custom`  | Manual progress via API         | Any identifier     |

### Multi-Objective Missions

Missions can have multiple objectives. All must be completed for the mission to succeed:

```lua
MissionDefs.survival_challenge = {
    id = "survival_challenge",
    name = "Survival Challenge",
    category = "challenge",
    time_limit = 960,
    objectives = {
        { type = "collect", target = "meat",       required = 10, label = "Meat" },
        { type = "kill",    target = "spider",     required = 10, label = "Spiders" },
        { type = "collect", target = "goldnugget", required = 5,  label = "Gold" },
    },
    rewards = { loot_pack = "legendary_cache" },
}
```

### Boss Missions with Health Bar

When a mission has `on_start_spawn`, the boss entity is tracked and its health is displayed as a red progress bar in the UI:

```lua
MissionDefs.boss_fight = {
    id = "boss_fight",
    name = "Slay the Beast",
    category = "boss",
    objectives = {
        { type = "boss", target = "deerclops", required = 1, label = "Deerclops" },
    },
    on_start_spawn = {
        prefab = "deerclops",
        announce = "A terrible creature emerges!",
    },
    rewards = { loot_pack = "boss_loot" },
}
```

### Timed Missions

Add `time_limit` (in seconds) to create urgency. The timer shows in the UI header, turning orange when under 60 seconds:

```lua
MissionDefs.timed_gather = {
    id = "timed_gather",
    name = "Speed Gathering",
    time_limit = 300,  -- 5 minutes
    objectives = { ... },
}
```

## Advanced: Manual Progress

For custom objective types or special tracking logic:

```lua
-- Get the tracker instance
local tracker = _G.MysteryBoxMissionTracker
-- or in modmain: MissionTrackerInstance

-- Add progress to a specific objective
-- Args: mission_id, objective_index (1-based), amount
tracker:AddProgress("my_mission", 1, 5)

-- Complete or fail a mission manually
tracker:CompleteMission("my_mission")
tracker:FailMission("my_mission", "Custom reason")

-- Set a boss entity for health tracking
local boss = SpawnPrefab("deerclops")
tracker:SetBossEntity("my_mission", boss)
```

## UI Details

### Panel Layout

```
+------------------------------+
| * MISSIONS          2 active v|  <- Header (click to collapse)
+------------------------------+
| Spider Extermination         |  <- Mission name (colored by category)
|  - Spiders         12/15    |  <- Objective with progress bar
|    [========----]            |
|  - Spider Warriors  3/5     |
|    [=====-------]            |
|                              |
| Deerclops Hunt        2:45  |  <- Timed mission with countdown
|  - Deerclops         0/1    |
|    [-------------]           |
|  BOSS HP     2400/4000      |  <- Boss health bar (red)
|    [========------]          |
|                              |
| + Gold Rush - Complete!      |  <- Recently finished (green)
+------------------------------+
```

### Category Colors
- **Challenge**: Gold/amber
- **Boss**: Red
- **Gather**: Green
- **Explore**: Blue

### Collapsible
Click the header bar to collapse/expand. The header always shows "X active" count even when collapsed.

## Multiplayer Behavior

- All players see the **same mission state** - progress is shared
- Any player picking up items, killing enemies, or building contributes
- New players joining mid-mission receive current state automatically
- Rewards drop at the position of the first player in the player list
- Mission announcements go to all players via `TheNet:Announce`

## Available Mission IDs

### Gathering
- `resource_drive` - Logs, rocks, grass
- `gold_rush` - Timed gold collection
- `silk_harvest` - Spider drops
- `gem_collector` - Timed gem collection
- `fortify_camp` - Build walls and firepit
- `farm_setup` - Build farms and birdcage

### Combat
- `spider_hunt` - Kill spiders and warriors
- `hound_defense` - Timed hound wave
- `shadow_purge` - Kill nightmare creatures
- `pig_war` - Timed werepig hunt

### Boss
- `deerclops_hunt` - Spawns and tracks Deerclops
- `bearger_hunt` - Spawns and tracks Bearger
- `treeguard_stand` - Spawns 3 Treeguards
- `spider_queen_hunt` - Timed Spider Queen fight

### Mixed
- `survival_challenge` - Collect + kill + gather
- `arcane_research` - Gather nightmare fuel + kill horrors

## Integration with Event System

To trigger missions from daily/weekly events, add mission-triggering events to `event_data.lua`:

```lua
-- In event_data.lua, add a new event type:
SIMPLE_EVENTS.mission_spider_hunt = {
    name = "Spider Infestation",
    category = "challenge",
    rarity = EVENT_RARITY.UNCOMMON,
    trigger = EVENT_TRIGGER.DAILY,
    announcement = "Spiders are overrunning the land!",
    -- No spawns - the mission handles tracking
}

-- In modmain.lua, modify the event executor:
-- After the event fires, also start the mission
```

Or create a new "mission event" executor pattern:

```lua
-- Generic mission event executor
local function ExecuteMissionEvent(data, world, target)
    if MysteryBoxStartMission then
        MysteryBoxStartMission(data.mission_id)
    end
end
```

## Files Reference

| File | Purpose |
|------|---------|
| `scripts/systems/mission_tracker.lua` | Server-side progress tracking engine |
| `scripts/systems/mission_defs.lua` | Mission definition data |
| `scripts/widgets/missionpanel.lua` | Client-side HUD widget |
| `modmain.lua` (bottom section) | Integration, networking, hooks |
