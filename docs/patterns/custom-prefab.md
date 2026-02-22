# Custom Prefab Pattern

## Overview
This pattern shows how to create custom entities (prefabs) for DST mods, including items, structures, and creatures.

## Basic Prefab Template

**File: `scripts/prefabs/myitem.lua`**

```lua
require "prefabutil"

-- Assets required for this prefab
local assets = {
    Asset("ANIM", "anim/myitem.zip"),
    -- Asset("IMAGE", "images/inventoryimages/myitem.tex"),
    -- Asset("ATLAS", "images/inventoryimages/myitem.xml"),
}

-- Optional: prefabs this one can spawn
local prefabs = {
    "goldnugget",  -- If this prefab spawns gold
}

local function fn()
    -- Create the entity
    local inst = CreateEntity()

    -- ========================================
    -- SHARED CODE (runs on server AND client)
    -- ========================================

    -- Required entity components
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    -- Physics for pickup
    MakeInventoryPhysics(inst)

    -- Animation setup
    inst.AnimState:SetBank("myitem")
    inst.AnimState:SetBuild("myitem")
    inst.AnimState:PlayAnimation("idle")

    -- Tags
    inst:AddTag("myitem")

    -- ========================================
    -- NETWORK SYNC POINT
    -- ========================================
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- ========================================
    -- SERVER ONLY CODE (below SetPristine)
    -- ========================================

    -- Make it inspectable
    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = function(inst)
        return "A mysterious item."
    end

    -- Make it an inventory item
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "myitem"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/myitem.xml"

    return inst
end

return Prefab("myitem", fn, assets, prefabs)
```

## Activatable Structure (Like Mystery Box)

```lua
require "prefabutil"

local assets = {
    Asset("ANIM", "anim/treasure_chest.zip"),
}

local function OnActivate(inst, doer)
    if inst.opened then
        return false
    end
    inst.opened = true

    -- Play animation
    inst.AnimState:PlayAnimation("open")

    -- Play sound
    inst.SoundEmitter:PlaySound("dontstarve/common/chest_open")

    -- Do something when activated
    if doer.components.talker then
        doer.components.talker:Say("I opened it!")
    end

    -- Spawn loot
    local x, y, z = inst.Transform:GetWorldPosition()
    local loot = SpawnPrefab("goldnugget")
    if loot then
        loot.Transform:SetPosition(x, 0, z)
    end

    -- Remove after delay
    inst:DoTaskInTime(2.0, function()
        inst:Remove()
    end)

    return true
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("chest")
    inst.AnimState:SetBuild("treasure_chest")
    inst.AnimState:PlayAnimation("closed")

    inst:AddTag("structure")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.opened = false

    inst:AddComponent("inspectable")

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = OnActivate
    inst.components.activatable.quickaction = true

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "treasurechest"
    inst.components.inventoryitem.atlasname = "images/inventoryimages.xml"

    return inst
end

return Prefab("mybox", fn, assets)
```

## Hostile Creature

```lua
require "prefabutil"

local assets = {
    Asset("ANIM", "anim/spider_build.zip"),
    Asset("ANIM", "anim/spider.zip"),
}

local brain = require "brains/spiderbrain"

local function OnAttacked(inst, data)
    if data.attacker then
        inst.components.combat:SetTarget(data.attacker)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddPhysics()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 10, 0.5)

    inst.AnimState:SetBank("spider")
    inst.AnimState:SetBuild("spider_build")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("scarytoprey")
    inst:AddTag("spider")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Health
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(100)

    -- Combat
    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(20)
    inst.components.combat:SetAttackPeriod(3)
    inst.components.combat:SetRange(2)
    inst.components.combat.hiteffectsymbol = "body"

    -- Movement
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 3
    inst.components.locomotor.runspeed = 6

    -- Loot drops
    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLoot({"monstermeat", "silk"})

    -- AI brain
    inst:SetBrain(brain)

    -- React to attacks
    inst:ListenForEvent("attacked", OnAttacked)

    return inst
end

return Prefab("mycreature", fn, assets)
```

## Using Existing Animations

If you don't have custom art, use existing game animations:

```lua
-- Use treasure chest
inst.AnimState:SetBank("chest")
inst.AnimState:SetBuild("treasure_chest")

-- Use spider
inst.AnimState:SetBank("spider")
inst.AnimState:SetBuild("spider_build")

-- Use pig
inst.AnimState:SetBank("pigman")
inst.AnimState:SetBuild("pig_build")

-- Tint the color to make it different
inst.AnimState:SetMultColour(1, 0.5, 0.5, 1)  -- Reddish
inst.AnimState:SetMultColour(0.5, 0.5, 1, 1)  -- Blueish
inst.AnimState:SetMultColour(1, 0.9, 0.3, 1)  -- Golden
```

## Registering Prefabs

**In `modmain.lua`:**
```lua
-- Register prefab files
PrefabFiles = {
    "myitem",
    "mybox",
    "mycreature",
}
```

## Common Components Checklist

### For Items
- `inspectable` - Examine text
- `inventoryitem` - Can be picked up
- `stackable` - Can stack (for resources)
- `fuel` - Can be used as fuel
- `edible` - Can be eaten

### For Structures
- `inspectable` - Examine text
- `workable` - Can be hammered/mined
- `container` - Has storage slots
- `activatable` - Can be clicked to use
- `burnable` - Can catch fire

### For Creatures
- `health` - Hit points
- `combat` - Can fight
- `locomotor` - Can move
- `lootdropper` - Drops items on death
- `sanityaura` - Affects player sanity

## Accessing Mod Globals from Prefabs

```lua
-- In prefab file, access modmain globals:
if rawget(_G, "MyModGlobal") then
    _G.MyModGlobal:DoSomething()
end

-- Safer pattern with fallback:
local function GetEventManager()
    if rawget(_G, "MysteryBoxEventManager") then
        return _G.MysteryBoxEventManager
    end
    return nil
end
```

## Common Issues

1. **"attempt to index nil value"**
   - Usually missing `TheWorld.ismastersim` check
   - Component doesn't exist on client

2. **Animation not playing**
   - Wrong bank/build name
   - Missing asset declaration

3. **Can't pick up item**
   - Missing `inventoryitem` component
   - Missing `MakeInventoryPhysics`

4. **Prefab not spawning**
   - Not in `PrefabFiles` list
   - Lua syntax error in file
   - Missing `return Prefab(...)` at end

## See Also

- [entities.md](../dst-api/entities.md) - Entity basics
- [components.md](../dst-api/components.md) - Component reference
- [networking.md](../dst-api/networking.md) - Client/server split
