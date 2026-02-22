# Brains (AI Behavior Trees)

## Overview
Brains are behavior trees that control high-level AI decisions. They determine what an entity does: who to attack, where to go, when to flee. The brain sends commands to the state graph, which handles animations.

## Quick Reference

| Class | Purpose |
|-------|---------|
| `Brain` | Base class for AI |
| `BrainManager` | Runs all brains |
| `PriorityNode` | Run first valid child |
| `SequenceNode` | Run children in order |
| `ParallelNode` | Run children simultaneously |
| `ConditionNode` | Check condition |
| `ActionNode` | Execute action |

## Core Concepts

### Brain vs StateGraph
- **Brain**: Decides WHAT to do (attack player, go home, eat food)
- **StateGraph**: Handles HOW to do it (play attack animation, walk cycle)

The Brain is the "thinking" layer. It evaluates the world and picks actions. Those actions trigger state graph transitions.

### Behavior Tree Basics
Behavior trees work through node types:
1. **Root**: Entry point
2. **Composite**: Contains children (Priority, Sequence, Parallel)
3. **Decorator**: Modifies a child (LoopNode, FailIfRunning)
4. **Leaf**: Actual actions (ChaseAndAttack, Wander)

## Basic Structure

```lua
require "behaviours/wander"
require "behaviours/chaseandattack"
require "behaviours/panic"
require "behaviours/follow"

local MyBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function MyBrain:OnStart()
    local root = PriorityNode({
        -- Panic if on fire
        WhileNode(function() return self.inst.components.health.takingfiredamage end,
            "OnFire", Panic(self.inst)),

        -- Attack if has target
        ChaseAndAttack(self.inst, 10),

        -- Otherwise wander
        Wander(self.inst),
    }, 0.25)

    self.bt = BT(self.inst, root)
end

return MyBrain
```

## Node Types

### PriorityNode
**Purpose**: Run the first child that succeeds (like if-else)
**Usage**: Main decision making
```lua
PriorityNode({
    -- First, try to flee if low health
    WhileNode(function() return self.inst.components.health:GetPercent() < 0.2 end,
        "LowHealth", RunAway(self.inst, "player", 15, 20)),

    -- Second, try to attack
    ChaseAndAttack(self.inst),

    -- Third, wander around
    Wander(self.inst),
}, 0.25)  -- Check interval in seconds
```

### SequenceNode
**Purpose**: Run children in order, stop on first failure
**Usage**: Multi-step actions
```lua
SequenceNode({
    -- Step 1: Go to food
    GoToEntity(self.inst, function() return FindFood() end),

    -- Step 2: Pick it up
    DoAction(self.inst, function() return PickupAction() end),

    -- Step 3: Eat it
    DoAction(self.inst, function() return EatAction() end),
})
```

### ParallelNode
**Purpose**: Run all children simultaneously
**Usage**: Concurrent behaviors
```lua
ParallelNode({
    -- Keep following leader
    Follow(self.inst, GetLeader, 3, 6, 10),

    -- While checking for danger
    WhileNode(function() return IsDangerNearby() end,
        "Danger", AlertBehavior(self.inst)),
})
```

### WhileNode
**Purpose**: Run child while condition is true
**Parameters**: condition_fn, name, child_node
```lua
WhileNode(
    function() return self.inst.components.combat.target ~= nil end,
    "HasTarget",
    ChaseAndAttack(self.inst)
)
```

### IfNode
**Purpose**: Run child if condition true, otherwise fail
```lua
IfNode(
    function() return TheWorld.state.isday end,
    "IsDay",
    Wander(self.inst)
)
```

### LoopNode
**Purpose**: Repeat child behavior
```lua
LoopNode({
    DoAction(self.inst, PatrolAction),
})
```

### FailIfRunning
**Purpose**: Convert RUNNING to FAILED
**Usage**: Prevents blocking
```lua
FailIfRunning(
    ChaseAndAttack(self.inst)
)
```

### ActionNode
**Purpose**: Execute a single action
```lua
ActionNode(function()
    self.inst.components.combat:SetTarget(enemy)
    return SUCCESS
end)
```

## Built-in Behaviors

### ChaseAndAttack
**Purpose**: Chase and attack target
**Location**: `behaviours/chaseandattack.lua`
```lua
local ChaseAndAttack = require "behaviours/chaseandattack"

ChaseAndAttack(self.inst, max_chase_time, give_up_dist, max_attacks)
-- max_chase_time: seconds before giving up (default 10)
-- give_up_dist: distance to lose interest
-- max_attacks: attacks before pausing
```

### Wander
**Purpose**: Randomly walk around
**Location**: `behaviours/wander.lua`
```lua
local Wander = require "behaviours/wander"

Wander(self.inst, home_fn, max_dist, times)
-- home_fn: function returning home position
-- max_dist: max wander distance from home
-- times: table of time ranges
```

### Follow
**Purpose**: Follow a target entity
**Location**: `behaviours/follow.lua`
```lua
local Follow = require "behaviours/follow"

Follow(self.inst, target_fn, min_dist, target_dist, max_dist)
-- target_fn: function returning target
-- min_dist: stop following closer than this
-- target_dist: ideal distance
-- max_dist: start following farther than this
```

### RunAway
**Purpose**: Flee from threats
**Location**: `behaviours/runaway.lua`
```lua
local RunAway = require "behaviours/runaway"

RunAway(self.inst, fn_or_tag, run_dist, stop_dist, fn_or_tags)
-- fn_or_tag: function or tag to flee from
-- run_dist: start fleeing at this distance
-- stop_dist: stop fleeing at this distance
```

### Panic
**Purpose**: Run randomly in fear
**Location**: `behaviours/panic.lua`
```lua
local Panic = require "behaviours/panic"

Panic(self.inst)
```

### StandStill
**Purpose**: Do nothing
**Location**: `behaviours/standstill.lua`
```lua
local StandStill = require "behaviours/standstill"

StandStill(self.inst)
```

### Leash
**Purpose**: Stay within range of home
**Location**: `behaviours/leash.lua`
```lua
local Leash = require "behaviours/leash"

Leash(self.inst, home_fn, max_dist, return_dist)
-- home_fn: function returning home position
-- max_dist: max distance from home
-- return_dist: distance to return to
```

### FaceEntity
**Purpose**: Turn to face target
**Location**: `behaviours/faceentity.lua`
```lua
local FaceEntity = require "behaviours/faceentity"

FaceEntity(self.inst, get_target_fn, keep_facing_fn)
```

### DoAction
**Purpose**: Execute a BufferedAction
**Location**: `behaviours/doaction.lua`
```lua
local DoAction = require "behaviours/doaction"

DoAction(self.inst, action_fn, run, try_instant)
-- action_fn: returns BufferedAction or nil
-- run: run vs walk to target
-- try_instant: try to do instantly
```

## Common Patterns

### Basic Hostile Creature
```lua
require "behaviours/wander"
require "behaviours/chaseandattack"
require "behaviours/panic"

local HostileBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetHome(inst)
    return inst.components.knownlocations:GetLocation("home")
end

function HostileBrain:OnStart()
    local root = PriorityNode({
        -- Panic when on fire
        WhileNode(function()
            return self.inst.components.health.takingfiredamage
        end, "OnFire", Panic(self.inst)),

        -- Attack enemies
        ChaseAndAttack(self.inst, 10),

        -- Stay near home
        Leash(self.inst, GetHome, 15, 10),

        -- Wander when idle
        Wander(self.inst, GetHome, 10),
    }, 0.25)

    self.bt = BT(self.inst, root)
end

return HostileBrain
```

### Creature with Day/Night Behavior
```lua
local function IsDaytime()
    return TheWorld.state.isday
end

local function IsNighttime()
    return TheWorld.state.isnight
end

function DayNightBrain:OnStart()
    local root = PriorityNode({
        -- Day behavior: wander and forage
        WhileNode(IsDaytime, "Day",
            PriorityNode({
                ChaseAndAttack(self.inst, 8),
                Wander(self.inst, GetHome, 20),
            }, 0.5)),

        -- Night behavior: go home and sleep
        WhileNode(IsNighttime, "Night",
            PriorityNode({
                GoHomeAction(self.inst),
                StandStill(self.inst),
            }, 0.5)),

        -- Default
        Wander(self.inst),
    }, 0.25)

    self.bt = BT(self.inst, root)
end
```

### Follower Brain
```lua
local function GetLeader(inst)
    return inst.components.follower and inst.components.follower.leader
end

function FollowerBrain:OnStart()
    local root = PriorityNode({
        -- Protect leader
        WhileNode(function()
            local leader = GetLeader(self.inst)
            return leader and leader.components.combat.target
        end, "ProtectLeader",
            ChaseAndAttack(self.inst, 8)),

        -- Follow leader
        Follow(self.inst, GetLeader, 2, 4, 8),

        -- Idle when leader stops
        StandStill(self.inst),
    }, 0.25)

    self.bt = BT(self.inst, root)
end
```

### Multi-Phase Boss
```lua
local function GetPhase(inst)
    local health_pct = inst.components.health:GetPercent()
    if health_pct > 0.66 then return 1
    elseif health_pct > 0.33 then return 2
    else return 3 end
end

function BossBrain:OnStart()
    local root = PriorityNode({
        -- Phase 1: Basic attacks
        WhileNode(function() return GetPhase(self.inst) == 1 end,
            "Phase1", ChaseAndAttack(self.inst, 15)),

        -- Phase 2: More aggressive
        WhileNode(function() return GetPhase(self.inst) == 2 end,
            "Phase2", PriorityNode({
                SpecialAttack(self.inst),
                ChaseAndAttack(self.inst, 20),
            }, 0.1)),

        -- Phase 3: Enraged
        WhileNode(function() return GetPhase(self.inst) == 3 end,
            "Phase3", PriorityNode({
                EnragedAttack(self.inst),
                SummonMinions(self.inst),
                ChaseAndAttack(self.inst, 30),
            }, 0.1)),
    }, 0.25)

    self.bt = BT(self.inst, root)
end
```

## Setting Up Brain

### In Prefab File
```lua
local brain = require "brains/mybrain"

local function fn()
    local inst = CreateEntity()

    -- ... entity setup ...

    if not TheWorld.ismastersim then
        return inst
    end

    -- Set brain (server only)
    inst:SetBrain(brain)

    return inst
end
```

### File Location
Brains go in `scripts/brains/`:
```
scripts/
└── brains/
    └── mybrain.lua
```

### Brain File Template
```lua
-- scripts/brains/mybrain.lua
require "behaviours/wander"
require "behaviours/chaseandattack"
require "behaviours/follow"
require "behaviours/runaway"

local MyBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function MyBrain:OnStart()
    local root = PriorityNode({
        -- Behaviors here
    }, 0.25)

    self.bt = BT(self.inst, root)
end

function MyBrain:OnStop()
    -- Cleanup if needed
end

return MyBrain
```

## Custom Behaviors

### Creating Custom Action Behavior
```lua
local MyAction = Class(BehaviourNode, function(self, inst, action_fn)
    BehaviourNode._ctor(self, "MyAction")
    self.inst = inst
    self.action_fn = action_fn
end)

function MyAction:Visit()
    if self.status == READY then
        local action = self.action_fn(self.inst)
        if action then
            self.inst.components.locomotor:GoToPoint(action.target)
            self.status = RUNNING
        else
            self.status = FAILED
        end
    elseif self.status == RUNNING then
        if self.inst.components.locomotor:IsAtDestination() then
            self.status = SUCCESS
        end
    end
end

return MyAction
```

## Return Values

Behavior nodes return status:
| Status | Meaning |
|--------|---------|
| `SUCCESS` | Completed successfully |
| `FAILED` | Could not complete |
| `RUNNING` | Still in progress |
| `READY` | Not started |

## Gotchas

1. **Server only**: Brains run on server only. Check `TheWorld.ismastersim` before setting brain.

2. **Check interval**: PriorityNode second argument is check interval. Lower = more responsive but more CPU.

3. **Requires**: Remember to `require` behavior files: `require "behaviours/wander"`.

4. **Target finding**: Brain doesn't find targets automatically. Use `combat:SetTarget()` or retarget callbacks.

5. **Stuck prevention**: Include Wander or similar fallback to prevent AI getting stuck.

6. **State graph sync**: Brain sends events, state graph handles them. Make sure SG has handlers.

## Debugging

```lua
-- In game console
c_select()  -- Select entity under mouse
print(c_sel().brain)  -- Print brain
print(c_sel().brain.bt.root.status)  -- Print root status

-- In brain code
function MyBrain:OnStart()
    print("Brain started for " .. tostring(self.inst))
end
```

## See Also

- [stategraphs.md](stategraphs.md) - State machines
- [entities.md](entities.md) - Creating entities
- [components.md](components.md) - Combat, locomotor

## Sources

- DST Game Scripts: `scripts/brains/*.lua`
- Behavior base: `scripts/behaviours/*.lua`
- Example: `scripts/brains/spiderbrain.lua`
