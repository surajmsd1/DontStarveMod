# State Graphs (SGS)

## Overview
State graphs are finite state machines that control entity behavior and animations. They define what states an entity can be in (idle, attacking, sleeping) and how it transitions between them.

## Quick Reference

| Function | Purpose |
|----------|---------|
| `StateGraph(name, states, events, defaultstate)` | Create state graph |
| `inst.sg:GoToState(state, data)` | Transition to state |
| `inst.sg:HasStateTag(tag)` | Check if current state has tag |
| `inst.sg.currentstate.name` | Get current state name |
| `inst:PushEvent(event)` | Trigger event handler |

## Core Concepts

### What is a State Graph?
A state graph defines:
1. **States**: Named conditions (idle, run, attack, death)
2. **Transitions**: How to move between states (via events or timelines)
3. **Actions**: What happens in each state (play animations, deal damage)

### State Graph vs Brain
- **StateGraph**: Controls animations and immediate actions (attack swing, walk cycle)
- **Brain**: High-level AI decisions (what to attack, where to go)

The Brain tells the entity "attack that target", the StateGraph handles the animation and damage timing.

## Basic Structure

```lua
local states = {
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle", true)
        end,
    },

    State{
        name = "attack",
        tags = {"attack", "busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("attack")
            inst.components.combat:StartAttack()
        end,

        timeline = {
            TimeEvent(12*FRAMES, function(inst)
                inst.components.combat:DoAttack()
            end),
        },

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

local events = {
    EventHandler("attacked", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("hit")
        end
    end),
}

return StateGraph("myentity", states, events, "idle")
```

## Detailed API

### State Definition
```lua
State{
    name = "statename",           -- Required: unique identifier
    tags = {"tag1", "tag2"},      -- Optional: state tags for checks

    onenter = function(inst)      -- Called when entering state
        -- Setup code
    end,

    onexit = function(inst)       -- Called when leaving state
        -- Cleanup code
    end,

    onupdate = function(inst)     -- Called every frame while in state
        -- Per-frame logic
    end,

    timeline = {                  -- Timed events during state
        TimeEvent(frames, fn),
        TimeEvent(frames, fn),
    },

    events = {                    -- Event handlers while in this state
        EventHandler("event", fn),
    },
}
```

### TimeEvent
**Purpose**: Execute function at specific frame during animation
**Parameters**:
- frames: number - Frame count (use `FRAMES` constant: 30 FRAMES = 1 second)
- fn: function(inst) - Function to execute
**Example**:
```lua
timeline = {
    TimeEvent(8*FRAMES, function(inst)
        -- 8 frames into animation (~0.27 seconds)
        inst.SoundEmitter:PlaySound("dontstarve/creatures/spider/attack")
    end),
    TimeEvent(15*FRAMES, function(inst)
        -- Deal damage at frame 15
        inst.components.combat:DoAttack()
    end),
}
```

### EventHandler
**Purpose**: Respond to events while in a state
**Parameters**:
- event: string - Event name
- fn: function(inst, data) - Handler function
**Example**:
```lua
events = {
    EventHandler("animover", function(inst)
        inst.sg:GoToState("idle")
    end),
    EventHandler("attacked", function(inst, data)
        if data.attacker then
            inst.sg:GoToState("hit")
        end
    end),
}
```

### GoToState
**Purpose**: Transition to a different state
**Parameters**:
- state: string - Target state name
- data: any (optional) - Data to pass to onenter
**Example**:
```lua
inst.sg:GoToState("attack")

-- With data
inst.sg:GoToState("attack", {target = enemy})

-- Access in onenter
onenter = function(inst, data)
    if data and data.target then
        inst:FacePoint(data.target:GetPosition())
    end
end
```

### HasStateTag
**Purpose**: Check if current state has a specific tag
**Parameters**:
- tag: string - Tag to check
**Returns**: boolean
**Example**:
```lua
if not inst.sg:HasStateTag("busy") then
    inst.sg:GoToState("action")
end

-- Common tags:
-- "idle" - entity is idle
-- "moving" - entity is moving
-- "busy" - cannot be interrupted
-- "attack" - attacking
-- "canrotate" - can turn to face targets
```

## Common Patterns

### Basic Creature State Graph
```lua
require("stategraphs/commonstates")

local states = {
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle", true)
        end,
    },

    State{
        name = "run",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run", true)
        end,
    },

    State{
        name = "attack",
        tags = {"attack", "busy"},

        onenter = function(inst)
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("attack")
        end,

        timeline = {
            TimeEvent(12*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/spider/attack")
                inst.components.combat:DoAttack()
            end),
        },

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hit")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("death")
            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,

        events = {
            EventHandler("animover", function(inst)
                inst:Remove()
            end),
        },
    },
}

local events = {
    EventHandler("attacked", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("hit")
        end
    end),

    EventHandler("death", function(inst)
        inst.sg:GoToState("death")
    end),

    EventHandler("locomote", function(inst)
        if not inst.sg:HasStateTag("busy") then
            local is_moving = inst.components.locomotor:WantsToMoveForward()
            if is_moving then
                if not inst.sg:HasStateTag("moving") then
                    inst.sg:GoToState("run")
                end
            else
                if not inst.sg:HasStateTag("idle") then
                    inst.sg:GoToState("idle")
                end
            end
        end
    end),

    EventHandler("doattack", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("attack")
        end
    end),
}

return StateGraph("myentity", states, events, "idle")
```

### Using Common States
DST provides reusable state templates:
```lua
require("stategraphs/commonstates")

local states = {
    -- Add common states
}

-- Add standard locomotion
CommonStates.AddWalkStates(states)
CommonStates.AddRunStates(states)
CommonStates.AddIdleState(states)
CommonStates.AddFrozenStates(states)
CommonStates.AddSleepStates(states)
```

### Multi-Hit Attack
```lua
State{
    name = "multihit",
    tags = {"attack", "busy"},

    onenter = function(inst)
        inst.AnimState:PlayAnimation("multihit")
        inst.sg.statemem.hitcount = 0
    end,

    timeline = {
        TimeEvent(5*FRAMES, function(inst)
            inst.components.combat:DoAttack()
            inst.sg.statemem.hitcount = inst.sg.statemem.hitcount + 1
        end),
        TimeEvent(12*FRAMES, function(inst)
            inst.components.combat:DoAttack()
            inst.sg.statemem.hitcount = inst.sg.statemem.hitcount + 1
        end),
        TimeEvent(19*FRAMES, function(inst)
            inst.components.combat:DoAttack()
            inst.sg.statemem.hitcount = inst.sg.statemem.hitcount + 1
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            print("Hit " .. inst.sg.statemem.hitcount .. " times!")
            inst.sg:GoToState("idle")
        end),
    },
}
```

### State with Cooldown
```lua
State{
    name = "special_attack",
    tags = {"attack", "busy"},

    onenter = function(inst)
        inst.AnimState:PlayAnimation("special")
        inst.sg.statemem.can_special = false
    end,

    onexit = function(inst)
        -- Start cooldown
        inst:DoTaskInTime(5, function()
            inst.sg.statemem.can_special = true
        end)
    end,

    -- ...
}

-- Check cooldown before entering
EventHandler("dospecialattack", function(inst)
    if inst.sg.statemem.can_special ~= false then
        inst.sg:GoToState("special_attack")
    end
end)
```

### AOE Attack with Warning
```lua
State{
    name = "groundpound",
    tags = {"attack", "busy"},

    onenter = function(inst)
        inst.AnimState:PlayAnimation("groundpound_pre")
    end,

    timeline = {
        TimeEvent(30*FRAMES, function(inst)
            -- Shake screen
            ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.02, 1)
        end),
        TimeEvent(35*FRAMES, function(inst)
            -- Deal AOE damage
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, 8, {"_combat"}, {"INLIMBO"})
            for _, ent in ipairs(ents) do
                if ent ~= inst and ent.components.combat then
                    ent.components.combat:GetAttacked(inst, 50)
                end
            end
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            inst.sg:GoToState("idle")
        end),
    },
}
```

## Setting Up State Graph

### In Prefab File
```lua
local function fn()
    local inst = CreateEntity()

    -- ... entity setup ...

    inst.entity:AddSoundEmitter()  -- Required for sounds in SG

    -- Set state graph
    inst:SetStateGraph("SGmyentity")

    -- Initial state
    inst.sg:GoToState("idle")

    return inst
end
```

### File Location
State graphs go in `scripts/stategraphs/`:
```
scripts/
└── stategraphs/
    └── SGmyentity.lua
```

### File Structure
```lua
-- scripts/stategraphs/SGmyentity.lua
require("stategraphs/commonstates")

local states = {
    -- State definitions
}

local events = {
    -- Event handlers
}

return StateGraph("myentity", states, events, "idle")
```

## State Tags Reference

| Tag | Meaning |
|-----|---------|
| `idle` | Entity is idle, ready for action |
| `moving` | Entity is walking/running |
| `busy` | Cannot be interrupted |
| `attack` | Currently attacking |
| `canrotate` | Can turn to face targets |
| `sleeping` | Currently asleep |
| `frozen` | Frozen by ice |
| `doing` | Performing an action |
| `nopredict` | Client shouldn't predict |

## Gotchas

1. **FRAMES constant**: Use `FRAMES` for timing. 30 FRAMES = 1 second. `TimeEvent(15*FRAMES, fn)` = 0.5 seconds.

2. **State memory**: Use `inst.sg.statemem` for per-state temporary data. It's cleared on state exit.

3. **Event priority**: State-level events override global events. If a state handles "attacked", global handler won't fire.

4. **Animation sync**: State graph should match animation length. Use `animover` event to transition after animation ends.

5. **Physics**: Remember to stop physics (`inst.Physics:Stop()`) in non-moving states.

6. **Busy tag**: Use "busy" tag to prevent interruption during important actions.

## See Also

- [animations.md](animations.md) - AnimState component
- [brains.md](brains.md) - AI behavior trees
- [entities.md](entities.md) - Creating entities

## Sources

- DST Game Scripts: `scripts/stategraphs/*.lua`
- Common States: `scripts/stategraphs/commonstates.lua`
- Example: `scripts/stategraphs/SGspider.lua`
