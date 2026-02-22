# World State API

## Overview
TheWorld.state contains all time, season, and environmental data in DST. This is your primary source for detecting day/night cycles, seasons, and weather conditions.

## Quick Reference

| Property | Type | Description |
|----------|------|-------------|
| `cycles` | number | Current day count (starts at 0) |
| `phase` | string | "day", "dusk", or "night" |
| `season` | string | "autumn", "winter", "spring", "summer" |
| `isday` | boolean | True during day phase |
| `isdusk` | boolean | True during dusk phase |
| `isnight` | boolean | True during night phase |
| `isautumn` | boolean | True during autumn |
| `iswinter` | boolean | True during winter |
| `isspring` | boolean | True during spring |
| `issummer` | boolean | True during summer |
| `temperature` | number | Current world temperature |
| `moisture` | number | Current moisture level (rain) |
| `wetness` | number | How wet things are |
| `snowlevel` | number | Snow accumulation (0-1) |
| `remainingdaysinseason` | number | Days until season changes |
| `moonphase` | string | Current moon phase |
| `isfullmoon` | boolean | True during full moon |
| `isnewmoon` | boolean | True during new moon |

## Detailed API

### Accessing World State

**In modmain.lua:**
```lua
-- Must use GLOBAL prefix
local day = GLOBAL.TheWorld.state.cycles
local phase = GLOBAL.TheWorld.state.phase
local season = GLOBAL.TheWorld.state.season
```

**In prefab files:**
```lua
-- Direct access works
local day = TheWorld.state.cycles
local phase = TheWorld.state.phase
```

**Gotchas:**
- Always check `TheWorld.ismastersim` before server-only logic
- `cycles` starts at 0, not 1 (Day 1 = cycles 0)

### Watching for Changes

The most reliable way to detect state changes is `WatchWorldState`:

```lua
-- Watch for phase changes (day/dusk/night)
world:WatchWorldState("phase", function(world, phase)
    if phase == "day" then
        print("Dawn! New day starting.")
    elseif phase == "dusk" then
        print("Dusk is falling...")
    elseif phase == "night" then
        print("Night has come!")
    end
end)

-- Watch for season changes
world:WatchWorldState("season", function(world, season)
    print("Season changed to: " .. season)
end)

-- Watch for cycle changes (new day)
world:WatchWorldState("cycles", function(world, cycles)
    print("Day " .. (cycles + 1) .. " has begun!")
end)
```

**Complete hook example from modmain.lua:**
```lua
AddPrefabPostInit("world", function(world)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    -- Watch phase changes
    world:WatchWorldState("phase", function(world, phase)
        if phase == "day" then
            -- Trigger daily event
            MyEventManager:OnDayStart()
        end
    end)

    -- Watch season changes
    world:WatchWorldState("season", function(world, season)
        MyEventManager:OnSeasonChange(season)
    end)
end)
```

### Detecting Day Transitions

**Pattern: Track last phase to detect dawn**
```lua
local lastPhase = nil

world:WatchWorldState("phase", function(world, phase)
    if phase == "day" and lastPhase ~= "day" then
        -- This is dawn - night just ended
        OnDawnEvent()
    end
    lastPhase = phase
end)
```

**Why this pattern?**
The watcher fires whenever phase changes. Without tracking lastPhase, you might miss edge cases or trigger multiple times.

### Season Information

```lua
-- Get current season
local season = TheWorld.state.season  -- "autumn", "winter", "spring", "summer"

-- Get remaining days
local daysLeft = TheWorld.state.remainingdaysinseason

-- Boolean checks
if TheWorld.state.iswinter then
    -- Winter-specific logic
end
```

**Season order:** autumn → winter → spring → summer → autumn...

### Moon Phases

```lua
local moonphase = TheWorld.state.moonphase

-- Full moon check (important for werepigs!)
if TheWorld.state.isfullmoon then
    print("Full moon tonight!")
end

-- New moon check
if TheWorld.state.isnewmoon then
    print("New moon - extra dark!")
end
```

### Weather & Temperature

```lua
-- Temperature
local temp = TheWorld.state.temperature

-- Moisture/rain
local moisture = TheWorld.state.moisture  -- How much rain is in the air
local wetness = TheWorld.state.wetness    -- How wet things are

-- Snow level (winter)
local snow = TheWorld.state.snowlevel  -- 0 to 1

-- Force weather changes (server-side)
TheWorld:PushEvent("ms_forceprecipitation", true)  -- Start rain
TheWorld:PushEvent("ms_forceprecipitation", false) -- Stop rain
```

## Common Patterns

### Daily Event System
```lua
local EventManager = {
    lastDayProcessed = -1
}

function EventManager:OnDayStart()
    local currentDay = TheWorld.state.cycles

    -- Don't process same day twice
    if currentDay <= self.lastDayProcessed then
        return
    end
    self.lastDayProcessed = currentDay

    print("Day " .. (currentDay + 1) .. " event triggering!")
    -- Your daily logic here
end
```

### Season-Specific Events
```lua
local SEASON_EVENTS = {
    autumn = {"harvest_festival", "leaf_storm"},
    winter = {"blizzard_challenge", "ice_fishing"},
    spring = {"frog_rain", "flower_bloom"},
    summer = {"heat_wave", "wildfire_warning"},
}

function TriggerSeasonalEvent(season)
    local events = SEASON_EVENTS[season]
    if events then
        local event = events[math.random(#events)]
        ExecuteEvent(event)
    end
end
```

### Week Tracking
```lua
function GetCurrentWeek()
    return math.floor(TheWorld.state.cycles / 7)
end

-- Check if it's day 7, 14, 21, etc.
function IsWeekMilestone()
    return (TheWorld.state.cycles + 1) % 7 == 0
end
```

## World Events (ms_ prefixed)

You can push events to change world state:

| Event | Description | Example |
|-------|-------------|---------|
| `ms_setphase` | Force time change | `TheWorld:PushEvent("ms_setphase", "day")` |
| `ms_setseason` | Force season | `TheWorld:PushEvent("ms_setseason", "winter")` |
| `ms_forceprecipitation` | Start/stop rain | `TheWorld:PushEvent("ms_forceprecipitation", true)` |
| `ms_setmoonphase` | Change moon | `TheWorld:PushEvent("ms_setmoonphase", "full")` |

**Warning:** These are typically for testing/admin commands. Use sparingly in mods.

## Console Commands for Testing

```lua
-- Skip to next day
c_skip(480)  -- 480 seconds = 1 full day

-- Force time of day
TheWorld:PushEvent("ms_setphase", "day")
TheWorld:PushEvent("ms_setphase", "dusk")
TheWorld:PushEvent("ms_setphase", "night")

-- Force season
TheWorld:PushEvent("ms_setseason", "winter")

-- Check current state
print("Day:", TheWorld.state.cycles + 1)
print("Phase:", TheWorld.state.phase)
print("Season:", TheWorld.state.season)
```

## Gotchas & Common Mistakes

1. **Forgetting GLOBAL in modmain.lua**
   ```lua
   -- WRONG
   local day = TheWorld.state.cycles

   -- CORRECT
   local day = GLOBAL.TheWorld.state.cycles
   ```

2. **Day counting starts at 0**
   - `cycles = 0` means Day 1
   - Display: `print("Day " .. (cycles + 1))`

3. **Not checking ismastersim**
   ```lua
   -- Always check for server-side code
   if not TheWorld.ismastersim then
       return
   end
   ```

4. **WatchWorldState callback signature**
   - First argument is `world`, second is the new value
   - `function(world, newValue)` NOT `function(newValue)`

## See Also

- [events.md](events.md) - Full event system documentation
- [networking.md](networking.md) - Client vs server logic

## Sources

- DST Game Scripts: `scripts/components/worldstate.lua`
- DST Game Scripts: `scripts/prefabs/world.lua`
- Klei Forums modding guides
