# Objective Dashboard UI - Implementation Plan

## Overview

A persistent HUD widget that displays mission/objective progress. Acts as single source of truth for tracking team progress across all players.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                              │
│  MissionState (server-authoritative, network-synced)        │
│  - Current mission(s) data                                   │
│  - Objective progress                                        │
│  - Pushes events on changes                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ Events
┌─────────────────────────────────────────────────────────────┐
│                      UI LAYER                                │
│  ObjectiveDashboard (client-side widget)                    │
│  - Listens for mission events                                │
│  - Renders current state                                     │
│  - Handles collapse/close interactions                       │
└─────────────────────────────────────────────────────────────┘
```

## Files to Create

```
scripts/
├── core/
│   └── mission_state.lua      # Server-side mission tracking (Phase 2)
├── widgets/
│   ├── objectivedashboard.lua # Main container widget
│   ├── missionpanel.lua       # Single mission display (collapsible)
│   ├── objectiverow.lua       # Single objective row with progress bar
│   └── progressbar.lua        # Reusable progress bar widget
└── events/
    └── mission_events.lua     # Event definitions (Phase 2)
```

## Phase 1: UI Components (This PR)

### 1. ProgressBar Widget
`scripts/widgets/progressbar.lua`

Reusable horizontal progress bar.

```lua
ProgressBar(width, height)
  :SetProgress(0.0 - 1.0)
  :SetColors(fill_color, empty_color)
  :AnimateTo(target, duration)  -- smooth animation
```

### 2. ObjectiveRow Widget
`scripts/widgets/objectiverow.lua`

Single objective display row.

```lua
ObjectiveRow(objective_data)
  :SetProgress(current, target)
  :SetCompleted(bool)
  :SetText(text)

-- Layout:
-- [○/✓] Collect Grass    ████████░░ 16/20
```

### 3. MissionPanel Widget
`scripts/widgets/missionpanel.lua`

Collapsible panel for one mission.

```lua
MissionPanel(mission_data)
  :Update(mission_data)
  :Collapse() / :Expand()
  :SetStatus("active" | "complete" | "failed")
  :ShowClaimButton(bool)
  :OnClaim(callback)

-- Layout (expanded):
-- ┌─────────────────────────────┐
-- │ 🎯 Mission Name      [▼][X] │  <- collapse + close buttons
-- ├─────────────────────────────┤
-- │  ○ Objective 1    ████░░ 5/10│
-- │  ✓ Objective 2    ██████ 3/3 │
-- ├─────────────────────────────┤
-- │  Reward: Item1, Item2       │
-- │  [Claim Rewards]            │  <- only when complete
-- └─────────────────────────────┘

-- Layout (collapsed):
-- ┌─────────────────────────────┐
-- │ 🎯 Mission Name 2/3  [▲][X] │
-- └─────────────────────────────┘
```

### 4. ObjectiveDashboard Widget
`scripts/widgets/objectivedashboard.lua`

Main container added to HUD.

```lua
ObjectiveDashboard()
  :AddMission(mission_data) -> panel
  :RemoveMission(mission_id)
  :UpdateMission(mission_id, data)
  :GetMission(mission_id) -> panel
  :Hide() / :Show()
```

## Phase 2: Mission State System (Future PR)

### MissionState Manager
`scripts/core/mission_state.lua`

Server-authoritative mission tracking.

```lua
MissionState
  :StartMission(mission_def)
  :UpdateObjective(mission_id, objective_id, value)
  :CompleteMission(mission_id)
  :FailMission(mission_id)
  :GetCurrentMission() -> data

-- Auto-pushes events:
-- "mission_started", "objective_updated", "mission_completed", etc.
```

### Mission Definitions
Data-driven mission templates (like event_data.lua).

```lua
MISSIONS = {
    gathering_basic = {
        name = "The Gathering",
        objectives = {
            {id = "grass", text = "Collect Grass", target = 20, track = "pickup:cutgrass"},
            {id = "twigs", text = "Collect Twigs", target = 20, track = "pickup:twigs"},
        },
        time_limit = 480,
        rewards = {"backpack", "torch"},
    },
}
```

## Data Structures

### Mission Data (what UI receives)
```lua
{
    id = "gathering_basic_1234",
    name = "The Gathering",
    description = "Gather basic resources",  -- optional

    time_limit = 480,      -- nil if no limit
    time_remaining = 285,  -- nil if no limit

    objectives = {
        {
            id = "grass",
            text = "Collect Grass",
            current = 16,
            target = 20,
            completed = false,
        },
        -- ...
    },

    rewards_text = "Backpack, Torch x2",  -- display string
    rewards = {"backpack", "torch", "torch"},  -- actual prefabs

    status = "active",  -- "active", "complete", "failed"
}
```

## Events (UI listens for these)

```lua
-- Mission lifecycle
"mission_started"    -> {mission_data}
"mission_updated"    -> {mission_id, mission_data}
"mission_completed"  -> {mission_id}
"mission_failed"     -> {mission_id, reason}
"mission_removed"    -> {mission_id}

-- Granular updates (optional, for animation)
"objective_progress" -> {mission_id, objective_id, current, target}
"objective_completed"-> {mission_id, objective_id}
"mission_timer"      -> {mission_id, time_remaining}
```

## HUD Integration

In `modmain.lua`:
```lua
-- Add dashboard to player HUD
AddClassPostConstruct("screens/playerhud", function(self)
    self.objectivedashboard = self.root:AddChild(ObjectiveDashboard())
    self.objectivedashboard:SetPosition(300, -100, 0)  -- top-right area
end)
```

## Testing Plan

### Phase 1 Testing (UI only)
Console commands to test UI without mission system:

```lua
-- Test adding a mission
TestMission = {
    id = "test1",
    name = "Test Mission",
    objectives = {
        {id = "a", text = "Do Thing A", current = 3, target = 10, completed = false},
        {id = "b", text = "Do Thing B", current = 5, target = 5, completed = true},
    },
    rewards_text = "Gold x5",
    status = "active",
}
ThePlayer.HUD.objectivedashboard:AddMission(TestMission)

-- Update progress
ThePlayer.HUD.objectivedashboard:UpdateMission("test1", {objectives = {...}})

-- Complete it
ThePlayer.HUD.objectivedashboard:UpdateMission("test1", {status = "complete"})
```

## Implementation Order

1. **progressbar.lua** - Base component, test standalone
2. **objectiverow.lua** - Uses ProgressBar, test standalone
3. **missionpanel.lua** - Uses ObjectiveRow, test with mock data
4. **objectivedashboard.lua** - Container, add to HUD
5. **Integration** - Wire up to modmain.lua
6. **Polish** - Animations, sounds, colors

## Style Constants

```lua
-- Colors (RGBA 0-1)
COLORS = {
    PANEL_BG = {0.1, 0.1, 0.1, 0.85},
    HEADER_BG = {0.15, 0.15, 0.15, 1},
    TEXT_NORMAL = {1, 1, 0.9, 1},       -- cream
    TEXT_COMPLETE = {0.4, 1, 0.4, 1},   -- green
    TEXT_FAILED = {1, 0.3, 0.3, 1},     -- red
    BAR_FILL = {0.9, 0.75, 0.2, 1},     -- gold
    BAR_EMPTY = {0.2, 0.2, 0.2, 1},     -- dark gray
    TIMER_LOW = {1, 0.2, 0.2, 1},       -- red for <30s
}

-- Sizes
SIZES = {
    PANEL_WIDTH = 300,
    ROW_HEIGHT = 30,
    BAR_HEIGHT = 12,
    PADDING = 10,
}
```

## Questions Resolved

- ✅ One mission at a time (but UI supports multiple, collapsible)
- ✅ Closable/collapsible per mission
- ✅ Rewards are informational display
- ✅ Optional claim button when complete
- ✅ This is display layer - reads from mission state
- ✅ Length adapts to objective count (gather = more rows)
