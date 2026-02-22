# DST API Quick Reference

## How To Use This
1. Search for what you need
2. If not here, check external links
3. Add what you learn back here

---

## World & Time

| API | Returns | Example |
|-----|---------|---------|
| `TheWorld.state.cycles` | Current day (0, 1, 2...) | `if TheWorld.state.cycles > 10 then` |
| `TheWorld.state.phase` | "day", "dusk", "night" | `if TheWorld.state.phase == "day"` |
| `TheWorld.state.season` | "autumn", "winter", "spring", "summer" | |
| `TheWorld.state.isday` | boolean | |
| `TheWorld.state.isnight` | boolean | |
| `TheWorld.ismastersim` | true if server | Always check before server logic |

**Watch for changes:**
```lua
world:WatchWorldState("phase", function(world, phase)
    print("Phase changed to: " .. phase)
end)
```

→ See [world-state.md](world-state.md) for details

---

## Spawning Entities

| API | What it does |
|-----|--------------|
| `SpawnPrefab("name")` | Create entity, returns it or nil |
| `entity.Transform:SetPosition(x, y, z)` | Move entity (y is usually 0) |
| `entity:Remove()` | Delete entity |

**Pattern:**
```lua
local spider = SpawnPrefab("spider")
if spider then
    spider.Transform:SetPosition(x, 0, z)
end
```

→ See [entities.md](entities.md) for details
→ See [prefab-list.md](prefab-list.md) for all prefab names

---

## Players

| API | What it does |
|-----|--------------|
| `AllPlayers` | Table of all players |
| `ThePlayer` | Local player (client only) |
| `player.Transform:GetWorldPosition()` | Returns x, y, z |
| `player.components.talker:Say("text")` | Speech bubble |
| `player.components.inventory:GiveItem(item)` | Add to inventory |

---

## Announcements

```lua
-- Show message to ALL players
TheNet:Announce("MESSAGE HERE")
```

---

## Delayed Execution

```lua
-- Run after X seconds
world:DoTaskInTime(5, function()
    print("5 seconds passed!")
end)

-- Run every X seconds
world:DoPeriodicTask(10, function()
    print("Every 10 seconds")
end)
```

---

## Events

```lua
-- Listen for event
inst:ListenForEvent("death", function(inst, data)
    print("Entity died!")
end)

-- Trigger event
inst:PushEvent("eventname", {data = value})

-- World events
TheWorld:PushEvent("ms_setphase", "day")
```

→ See [events.md](events.md) for details

---

## Components (Common)

| Component | Purpose | Key Methods |
|-----------|---------|-------------|
| `health` | HP | `:SetMaxHealth()`, `:DoDelta()`, `:Kill()` |
| `combat` | Fighting | `:SetTarget()`, `:GetAttacked()` |
| `inventory` | Hold items | `:GiveItem()`, `:DropItem()` |
| `locomotor` | Movement | `:SetExternalSpeedMultiplier()` |
| `talker` | Speech | `:Say("text")` |
| `activatable` | Clickable | `.OnActivate = function(inst, doer)` |
| `inspectable` | Examine | Shows description |
| `lootdropper` | Drop items | `:SpawnLootPrefab()` |

→ See [components.md](components.md) for full reference

---

## File Index

- [world-state.md](world-state.md) - Time, seasons, phase detection
- [entities.md](entities.md) - Spawning, transforms, removal
- [components.md](components.md) - Full component API reference
- [events.md](events.md) - Event system, listeners
- [networking.md](networking.md) - Multiplayer, client/server
- [prefab-list.md](prefab-list.md) - All spawnable prefab names
