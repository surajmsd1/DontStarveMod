# Components API Reference

## Overview
Components are modular pieces of functionality that can be attached to entities. An entity's behavior is defined by which components it has and how they're configured.

## Quick Reference

| Component | Purpose | Common Methods |
|-----------|---------|----------------|
| `health` | Hit points | `SetMaxHealth()`, `DoDelta()`, `Kill()` |
| `combat` | Fighting | `SetTarget()`, `GetAttacked()`, `DoAttack()` |
| `inventory` | Hold items | `GiveItem()`, `DropItem()`, `Has()` |
| `locomotor` | Movement | `SetExternalSpeedMultiplier()`, `GoToPoint()` |
| `talker` | Speech bubbles | `Say()` |
| `inspectable` | Examine text | Sets description |
| `activatable` | Clickable | `OnActivate` callback |
| `lootdropper` | Drop items | `SpawnLootPrefab()`, `SetLoot()` |
| `workable` | Can be mined/chopped | `SetWorkAction()`, `SetOnFinishCallback()` |
| `container` | Storage | `Open()`, `Close()`, `GiveItem()` |

## Adding Components

```lua
-- In prefab fn()
inst:AddComponent("health")
inst.components.health:SetMaxHealth(100)

inst:AddComponent("combat")
inst.components.combat:SetDefaultDamage(10)
```

## Health Component

Manages hit points and death.

### Key Properties
- `maxhealth` - Maximum HP
- `currenthealth` - Current HP
- `invincible` - Can't take damage if true
- `fire_damage_scale` - Fire damage multiplier

### Methods

**SetMaxHealth(amount)**
```lua
inst.components.health:SetMaxHealth(200)
```

**DoDelta(amount, overtime, cause, ignore_invincible)**
```lua
-- Deal 50 damage
inst.components.health:DoDelta(-50)

-- Heal 25
inst.components.health:DoDelta(25)

-- Damage that ignores invincibility
inst.components.health:DoDelta(-50, false, nil, true)
```

**Kill()**
```lua
inst.components.health:Kill()
```

**SetPercent(percent)**
```lua
inst.components.health:SetPercent(0.5)  -- Set to 50% health
```

**GetPercent()**
```lua
local healthPercent = inst.components.health:GetPercent()
if healthPercent < 0.25 then
    print("Low health!")
end
```

**SetInvincible(invincible)**
```lua
inst.components.health:SetInvincible(true)  -- Can't be damaged
```

### Events
```lua
-- Listen for death
inst:ListenForEvent("death", function(inst)
    print("Entity died!")
end)

-- Listen for health change
inst:ListenForEvent("healthdelta", function(inst, data)
    print("Health changed by: " .. data.amount)
end)
```

## Combat Component

Handles attacking and being attacked.

### Key Properties
- `damage` - Base damage dealt
- `attackrange` - How far attacks reach
- `hitrange` - How far hits register
- `areahitrange` - Area damage radius
- `target` - Current combat target

### Methods

**SetDefaultDamage(damage)**
```lua
inst.components.combat:SetDefaultDamage(50)
```

**SetAttackPeriod(period)**
```lua
inst.components.combat:SetAttackPeriod(2)  -- Attack every 2 seconds
```

**SetRange(attack, hit)**
```lua
inst.components.combat:SetRange(3, 4)  -- Attack range 3, hit range 4
```

**SetTarget(target)**
```lua
inst.components.combat:SetTarget(player)
```

**DropTarget()**
```lua
inst.components.combat:DropTarget()  -- Stop attacking
```

**GetAttacked(attacker, damage)**
```lua
-- Make entity take damage from attacker
inst.components.combat:GetAttacked(attacker, 25)
```

**DoAttack(target)**
```lua
inst.components.combat:DoAttack(target)
```

**CanTarget(target)**
```lua
if inst.components.combat:CanTarget(player) then
    inst.components.combat:SetTarget(player)
end
```

### Events
```lua
-- Listen for attacks received
inst:ListenForEvent("attacked", function(inst, data)
    print("Attacked by: " .. tostring(data.attacker))
    print("Damage: " .. data.damage)
end)

-- Listen for kills
inst:ListenForEvent("killed", function(inst, data)
    print("Killed: " .. tostring(data.victim))
end)
```

## Inventory Component

Allows entity to hold items.

### Methods

**GiveItem(item, slot)**
```lua
local sword = SpawnPrefab("spear")
inst.components.inventory:GiveItem(sword)
```

**DropItem(item)**
```lua
inst.components.inventory:DropItem(item)
```

**DropEverything()**
```lua
inst.components.inventory:DropEverything()
```

**Has(prefab, amount)**
```lua
if inst.components.inventory:Has("goldnugget", 5) then
    print("Player has 5+ gold")
end
```

**GetItemBySlot(slot)**
```lua
local item = inst.components.inventory:GetItemBySlot(1)
```

**FindItem(fn)**
```lua
local sword = inst.components.inventory:FindItem(function(item)
    return item.prefab == "spear"
end)
```

**ConsumeByName(prefab, amount)**
```lua
inst.components.inventory:ConsumeByName("goldnugget", 5)
```

## Locomotor Component

Controls movement.

### Methods

**SetExternalSpeedMultiplier(source, mult)**
```lua
-- Slow entity to 50% speed
inst.components.locomotor:SetExternalSpeedMultiplier(inst, "mymod", 0.5)

-- Remove speed modifier
inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "mymod")
```

**GoToPoint(point)**
```lua
inst.components.locomotor:GoToPoint(Vector3(x, 0, z))
```

**GoToEntity(entity)**
```lua
inst.components.locomotor:GoToEntity(target)
```

**Stop()**
```lua
inst.components.locomotor:Stop()
```

**SetRunSpeed(speed)**
```lua
inst.components.locomotor:SetRunSpeed(6)
```

**SetWalkSpeed(speed)**
```lua
inst.components.locomotor:SetWalkSpeed(3)
```

## Talker Component

Shows speech bubbles.

### Methods

**Say(text, time, noanim, force)**
```lua
inst.components.talker:Say("Hello!")
inst.components.talker:Say("This lasts 5 seconds", 5)
```

**ShutUp()**
```lua
inst.components.talker:ShutUp()
```

## Activatable Component

Makes entity clickable/activatable.

### Setup
```lua
inst:AddComponent("activatable")
inst.components.activatable.OnActivate = function(inst, doer)
    print(tostring(doer) .. " activated " .. tostring(inst))
    return true  -- Activation succeeded
end
inst.components.activatable.quickaction = true  -- One-click activate
```

### Properties
- `OnActivate` - Function called when activated
- `quickaction` - If true, single click activates
- `inactive` - If true, can't be activated

## Inspectable Component

Shows examine text.

### Setup
```lua
inst:AddComponent("inspectable")
inst.components.inspectable.descriptionfn = function(inst, viewer)
    if inst:HasTag("burnt") then
        return "It's all burnt up!"
    end
    return "A mysterious object."
end
```

## LootDropper Component

Drops items on death/destruction.

### Methods

**SetLoot(loot_table)**
```lua
inst.components.lootdropper:SetLoot({"meat", "meat", "monstermeat"})
```

**AddRandomLoot(prefab, weight)**
```lua
inst.components.lootdropper:AddRandomLoot("goldnugget", 1)
inst.components.lootdropper:AddRandomLoot("redgem", 0.1)
```

**SpawnLootPrefab(prefab)**
```lua
inst.components.lootdropper:SpawnLootPrefab("goldnugget")
```

**DropLoot()**
```lua
inst.components.lootdropper:DropLoot()
```

### Random Loot Pattern
```lua
inst:AddComponent("lootdropper")
inst.components.lootdropper:AddRandomLoot("meat", 1)
inst.components.lootdropper:AddRandomLoot("goldnugget", 0.3)
inst.components.lootdropper:AddRandomLoot("redgem", 0.05)
inst.components.lootdropper.numrandomloot = 2
```

## Container Component

Makes entity a storage container.

### Methods

**Open(doer)**
```lua
inst.components.container:Open(player)
```

**Close()**
```lua
inst.components.container:Close()
```

**GiveItem(item)**
```lua
inst.components.container:GiveItem(item)
```

**IsFull()**
```lua
if inst.components.container:IsFull() then
    print("Container is full!")
end
```

**IsEmpty()**
```lua
if inst.components.container:IsEmpty() then
    print("Container is empty")
end
```

## Workable Component

Makes entity mineable/choppable/hammerable.

### Setup
```lua
inst:AddComponent("workable")
inst.components.workable:SetWorkAction(ACTIONS.CHOP)
inst.components.workable:SetWorkLeft(10)  -- 10 chops to destroy
inst.components.workable:SetOnFinishCallback(function(inst, worker)
    inst.components.lootdropper:DropLoot()
    inst:Remove()
end)
```

### Work Actions
- `ACTIONS.CHOP` - Axe
- `ACTIONS.MINE` - Pickaxe
- `ACTIONS.HAMMER` - Hammer
- `ACTIONS.DIG` - Shovel

## Timer Component

Schedule delayed actions.

### Methods

**StartTimer(name, time)**
```lua
inst.components.timer:StartTimer("respawn", 60)
```

**StopTimer(name)**
```lua
inst.components.timer:StopTimer("respawn")
```

**TimerExists(name)**
```lua
if inst.components.timer:TimerExists("respawn") then
    print("Respawn timer running")
end
```

### Events
```lua
inst:ListenForEvent("timerdone", function(inst, data)
    if data.name == "respawn" then
        -- Respawn logic
    end
end)
```

## Sanity Component

Player sanity (not commonly used for mobs).

### Methods
```lua
inst.components.sanity:DoDelta(-10)  -- Lose 10 sanity
inst.components.sanity:SetPercent(0.5)  -- Set to 50%
```

## Hunger Component

Player hunger.

### Methods
```lua
inst.components.hunger:DoDelta(-25)  -- Lose 25 hunger
inst.components.hunger:SetPercent(1)  -- Full hunger
```

## Common Patterns

### Full Combat Entity
```lua
inst:AddComponent("health")
inst.components.health:SetMaxHealth(200)

inst:AddComponent("combat")
inst.components.combat:SetDefaultDamage(25)
inst.components.combat:SetAttackPeriod(3)
inst.components.combat:SetRange(2, 3)

inst:AddComponent("lootdropper")
inst.components.lootdropper:SetLoot({"meat", "meat"})

inst:ListenForEvent("death", function(inst)
    inst.components.lootdropper:DropLoot()
end)
```

### Collectible Item
```lua
inst:AddComponent("inspectable")
inst:AddComponent("inventoryitem")
inst.components.inventoryitem.imagename = "goldnugget"
inst.components.inventoryitem.atlasname = "images/inventoryimages.xml"
```

### Activatable Structure
```lua
inst:AddComponent("inspectable")
inst:AddComponent("activatable")
inst.components.activatable.OnActivate = function(inst, doer)
    -- Do something when activated
    if doer.components.talker then
        doer.components.talker:Say("Activated!")
    end
    return true
end
inst.components.activatable.quickaction = true
```

## Gotchas

1. **Check component exists before using**
   ```lua
   -- WRONG - crashes if no combat component
   inst.components.combat:SetTarget(player)

   -- CORRECT
   if inst.components.combat then
       inst.components.combat:SetTarget(player)
   end
   ```

2. **Components are server-only (mostly)**
   - Add components AFTER `SetPristine()` check
   - Clients don't have access to most component data

3. **Use component methods, not direct property access**
   ```lua
   -- WRONG
   inst.components.health.currenthealth = 50

   -- CORRECT
   inst.components.health:SetPercent(0.5)
   ```

## See Also

- [entities.md](entities.md) - Entity creation
- [events.md](events.md) - Component events
- [prefab-list.md](prefab-list.md) - Prefab examples

## Sources

- DST Game Scripts: `scripts/components/*.lua`
