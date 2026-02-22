# Animations & AnimState API

## Overview
DST uses a custom animation system built on the Spriter format (.scml files). Animations are controlled through the `AnimState` component, which manages what visual state an entity displays.

## Quick Reference

| Function | Purpose |
|----------|---------|
| `inst.AnimState:SetBank(bank)` | Set animation bank (collection of anims) |
| `inst.AnimState:SetBuild(build)` | Set visual appearance/skin |
| `inst.AnimState:PlayAnimation(anim)` | Play animation once |
| `inst.AnimState:PushAnimation(anim, loop)` | Queue animation after current |
| `inst.AnimState:IsCurrentAnimation(anim)` | Check current animation |
| `inst.AnimState:IsSymbolPresent(sym)` | Check if symbol exists |
| `inst.AnimState:Hide(layer)` | Hide a layer |
| `inst.AnimState:Show(layer)` | Show a layer |
| `inst.AnimState:OverrideSymbol(sym, build, newsym)` | Replace a symbol |

## Core Concepts

### Banks vs Builds
- **Bank**: The animation data (keyframes, timing, skeleton)
- **Build**: The visual appearance (textures, colors)

Multiple builds can share the same bank. For example, all spiders use the `spider` bank but different builds for warrior vs regular.

```lua
-- Spider uses spider bank and spider build
inst.AnimState:SetBank("spider")
inst.AnimState:SetBuild("spider")

-- Spider warrior uses same bank, different build
inst.AnimState:SetBank("spider")
inst.AnimState:SetBuild("spider_warrior")
```

### Animation Files Structure
DST animations are compiled into:
- `.zip` files containing:
  - `anim.bin` - Animation keyframes
  - `build.bin` - Symbol/layer data
  - `atlas-*.tex` - Texture atlases

### Asset Declaration
```lua
local assets = {
    Asset("ANIM", "anim/myentity.zip"),      -- Animation + build
    Asset("ANIM", "anim/myentity_skin.zip"), -- Optional alternate build
}
```

## Detailed API

### SetBank
**Purpose**: Sets the animation bank (defines available animations)
**Parameters**:
- bank: string - Bank name
**Example**:
```lua
inst.AnimState:SetBank("spider")
```

### SetBuild
**Purpose**: Sets the visual appearance
**Parameters**:
- build: string - Build name
**Example**:
```lua
inst.AnimState:SetBuild("spider")
```

### PlayAnimation
**Purpose**: Immediately plays an animation
**Parameters**:
- anim: string - Animation name
- loop: boolean (optional) - Loop the animation (default: false)
**Example**:
```lua
-- Play once
inst.AnimState:PlayAnimation("idle")

-- Loop continuously
inst.AnimState:PlayAnimation("idle_loop", true)
```

### PushAnimation
**Purpose**: Queue animation to play after current finishes
**Parameters**:
- anim: string - Animation name
- loop: boolean - Whether to loop
**Example**:
```lua
-- Play attack, then return to idle loop
inst.AnimState:PlayAnimation("attack")
inst.AnimState:PushAnimation("idle_loop", true)
```

### GetCurrentAnimationLength
**Purpose**: Get duration of current animation in seconds
**Returns**: number - Duration in seconds
**Example**:
```lua
local duration = inst.AnimState:GetCurrentAnimationLength()
inst:DoTaskInTime(duration, function()
    print("Animation finished!")
end)
```

### IsCurrentAnimation
**Purpose**: Check if specific animation is playing
**Parameters**:
- anim: string - Animation name
**Returns**: boolean
**Example**:
```lua
if inst.AnimState:IsCurrentAnimation("attack") then
    -- Currently attacking
end
```

### Hide / Show
**Purpose**: Toggle visibility of animation layers
**Parameters**:
- layer: string - Layer name
**Example**:
```lua
-- Hide the hat layer
inst.AnimState:Hide("HAT")

-- Show the hat layer
inst.AnimState:Show("HAT")
```

### OverrideSymbol
**Purpose**: Replace a symbol with one from another build
**Parameters**:
- original_symbol: string - Symbol to replace
- source_build: string - Build containing replacement
- source_symbol: string - Symbol from that build
**Example**:
```lua
-- Give a creature a different face
inst.AnimState:OverrideSymbol("face", "wilson", "face_happy")

-- Equip item visually
inst.AnimState:OverrideSymbol("swap_object", "swap_spear", "swap_spear")
```

### ClearOverrideSymbol
**Purpose**: Remove a symbol override
**Parameters**:
- symbol: string - Symbol to clear
**Example**:
```lua
inst.AnimState:ClearOverrideSymbol("swap_object")
```

### SetMultColour
**Purpose**: Tint the entire entity
**Parameters**:
- r, g, b, a: numbers (0-1) - RGBA values
**Example**:
```lua
-- Make entity red
inst.AnimState:SetMultColour(1, 0.5, 0.5, 1)

-- Make transparent
inst.AnimState:SetMultColour(1, 1, 1, 0.5)

-- Normal color
inst.AnimState:SetMultColour(1, 1, 1, 1)
```

### SetAddColour
**Purpose**: Add color (glow effect)
**Parameters**:
- r, g, b, a: numbers - RGBA values to add
**Example**:
```lua
-- Red glow
inst.AnimState:SetAddColour(0.3, 0, 0, 0)
```

### SetScale
**Purpose**: Scale the animation
**Parameters**:
- x, y, z: numbers - Scale factors
**Example**:
```lua
-- Double size
inst.AnimState:SetScale(2, 2, 2)

-- Half size
inst.AnimState:SetScale(0.5, 0.5, 0.5)

-- Flip horizontally
inst.AnimState:SetScale(-1, 1, 1)
```

### SetOrientation
**Purpose**: Set how animation faces camera
**Parameters**:
- orientation: ANIM_ORIENTATION constant
**Example**:
```lua
-- Face camera (default for most entities)
inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

-- Billboard (always faces camera)
inst.AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)
```

### SetLayer
**Purpose**: Set rendering layer
**Parameters**:
- layer: LAYER constant
**Example**:
```lua
inst.AnimState:SetLayer(LAYER_BACKGROUND)
inst.AnimState:SetLayer(LAYER_WORLD)
inst.AnimState:SetLayer(LAYER_FRONTEND)
```

### SetSortOrder
**Purpose**: Set render order within layer
**Parameters**:
- order: number
**Example**:
```lua
inst.AnimState:SetSortOrder(3)  -- Render on top of order 2
```

## Common Patterns

### Basic Entity Setup
```lua
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("mybank")
    inst.AnimState:SetBuild("mybuild")
    inst.AnimState:PlayAnimation("idle", true)

    return inst
end
```

### Animation Event Callback
```lua
-- Listen for animation events (defined in Spriter)
inst:ListenForEvent("animover", function(inst)
    -- Animation finished
    inst.AnimState:PlayAnimation("idle", true)
end)

-- Listen for animation frame events
inst:ListenForEvent("animqueueover", function(inst)
    -- All queued animations finished
end)
```

### Dynamic Appearance Changes
```lua
local function UpdateAppearance(inst, isAngry)
    if isAngry then
        inst.AnimState:SetMultColour(1, 0.6, 0.6, 1)
        inst.AnimState:PlayAnimation("angry_idle", true)
    else
        inst.AnimState:SetMultColour(1, 1, 1, 1)
        inst.AnimState:PlayAnimation("idle", true)
    end
end
```

### Equipment Visuals
```lua
local function OnEquip(inst, owner)
    -- Show equipped item on character
    owner.AnimState:OverrideSymbol("swap_object", "swap_axe", "swap_axe")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_object")
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end
```

### Flashing Effect
```lua
local function Flash(inst)
    inst.AnimState:SetMultColour(1, 1, 1, 1)

    inst:DoTaskInTime(0.1, function()
        inst.AnimState:SetMultColour(1, 0, 0, 1)
    end)
    inst:DoTaskInTime(0.2, function()
        inst.AnimState:SetMultColour(1, 1, 1, 1)
    end)
end
```

### Using Existing Animations
To use vanilla DST animations without creating custom art:
```lua
-- Use chest animation
inst.AnimState:SetBank("treasurechest")
inst.AnimState:SetBuild("treasurechest")

-- Use spider animation
inst.AnimState:SetBank("spider")
inst.AnimState:SetBuild("spider")

-- Use item animation on ground
inst.AnimState:SetBank("redgem")
inst.AnimState:SetBuild("redgem")
```

### Finding Vanilla Animation Names
Check the DST game scripts repository:
- `scripts/prefabs/*.lua` - See what banks/builds prefabs use
- Animation names are typically: `idle`, `run`, `attack`, `death`, `hit`, `taunt`

## Common Animation Names

Most mobs have these standard animations:
| Animation | Description |
|-----------|-------------|
| `idle` / `idle_loop` | Standing still |
| `run` / `walk` | Movement |
| `attack` | Attack animation |
| `hit` | Taking damage |
| `death` | Dying |
| `taunt` | Challenge/aggro |
| `sleep` / `sleep_loop` | Sleeping |
| `eat` / `eat_loop` | Eating |

Items typically have:
| Animation | Description |
|-----------|-------------|
| `idle` | Default state |
| `open` / `close` | For containers |
| `place` | Being placed |

## Gotchas

1. **Bank/Build mismatch**: Bank and build must be compatible. Using incompatible combinations causes invisible entities.

2. **Missing animations**: If you play an animation that doesn't exist, entity becomes invisible. Always check animation exists.

3. **Loop parameter**: `PlayAnimation("anim")` plays once. Use `PlayAnimation("anim", true)` or queue a looping animation.

4. **Animation events**: `animover` fires when PlayAnimation finishes, `animqueueover` fires when PushAnimation queue empties.

5. **Scale affects hitbox**: AnimState:SetScale() only affects visuals, not collision. Use physics component for actual size.

6. **Client vs Server**: AnimState changes are visual only and automatically sync to clients.

## Creating Custom Animations

Custom animations require:
1. **Spriter Pro** ($60) - Animation software
2. **ktools** - Convert to DST format
3. Understanding of DST's bone/symbol system

For most mods, reuse existing vanilla animations instead.

### Animation File Workflow
1. Create .scml file in Spriter
2. Export to DST format using ktools autocompiler
3. Place .zip in `anim/` folder
4. Declare with `Asset("ANIM", "anim/myfile.zip")`

## See Also

- [stategraphs.md](stategraphs.md) - State machine controlling animations
- [entities.md](entities.md) - Creating entities
- [custom-prefab.md](../patterns/custom-prefab.md) - Full prefab examples

## Sources

- DST Game Scripts: `scripts/prefabs/*.lua`
- DST API Docs: https://dst-api-docs.fandom.com/wiki/AnimState
- Klei Forums: Animation tutorials
