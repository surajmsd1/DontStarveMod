# Loot Tables Pattern

## Overview
Weighted random selection for item drops, event selection, and any probability-based system.

## Basic Weighted Selection

```lua
local LOOT_TABLE = {
    {item = "goldnugget", weight = 50},
    {item = "redgem", weight = 20},
    {item = "bluegem", weight = 20},
    {item = "purplegem", weight = 8},
    {item = "greengem", weight = 2},
}

local function SelectWeighted(lootTable)
    -- Calculate total weight
    local totalWeight = 0
    for _, entry in ipairs(lootTable) do
        totalWeight = totalWeight + entry.weight
    end

    -- Roll random number
    local roll = math.random() * totalWeight
    local cumulative = 0

    -- Find selected item
    for _, entry in ipairs(lootTable) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.item
        end
    end

    -- Fallback
    return lootTable[1].item
end

-- Usage
local selectedItem = SelectWeighted(LOOT_TABLE)
SpawnPrefab(selectedItem)
```

## Rarity Tier System

```lua
local RARITY = {
    COMMON = {name = "Common", weight = 60, color = "white"},
    UNCOMMON = {name = "Uncommon", weight = 25, color = "green"},
    RARE = {name = "Rare", weight = 10, color = "blue"},
    EPIC = {name = "Epic", weight = 4, color = "purple"},
    LEGENDARY = {name = "Legendary", weight = 1, color = "orange"},
}

local ITEMS_BY_RARITY = {
    [RARITY.COMMON] = {"goldnugget", "silk", "rope", "boards", "cutgrass"},
    [RARITY.UNCOMMON] = {"redgem", "bluegem", "gears", "transistor"},
    [RARITY.RARE] = {"purplegem", "livinglog", "thulecite_pieces"},
    [RARITY.EPIC] = {"yellowgem", "orangegem", "greengem", "thulecite"},
    [RARITY.LEGENDARY] = {"amulet", "armorruins", "ruinshat", "orangestaff"},
}

local function SelectRarity()
    local totalWeight = 0
    for _, rarity in pairs(RARITY) do
        totalWeight = totalWeight + rarity.weight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, rarity in pairs(RARITY) do
        cumulative = cumulative + rarity.weight
        if roll <= cumulative then
            return rarity
        end
    end

    return RARITY.COMMON
end

local function SelectFromRarity(rarity)
    local items = ITEMS_BY_RARITY[rarity]
    if not items or #items == 0 then
        return "goldnugget"
    end
    return items[math.random(#items)]
end

local function DropRandomLoot()
    local rarity = SelectRarity()
    local item = SelectFromRarity(rarity)
    print("Dropped " .. rarity.name .. " item: " .. item)
    return item
end
```

## Multiple Drops

```lua
local function DropMultiple(lootTable, count)
    local drops = {}
    for i = 1, count do
        local item = SelectWeighted(lootTable)
        table.insert(drops, item)
    end
    return drops
end

-- Usage
local items = DropMultiple(LOOT_TABLE, 5)
for _, item in ipairs(items) do
    SpawnNear(item, x, z, 5)
end
```

## Guaranteed + Random Drops

```lua
local DROP_CONFIG = {
    guaranteed = {"goldnugget", "goldnugget"},  -- Always drop these
    random = {
        {item = "redgem", weight = 30},
        {item = "bluegem", weight = 30},
        {item = "purplegem", weight = 10},
    },
    randomCount = 2,  -- Pick 2 random items
}

local function DropConfigured(config, x, z)
    -- Drop guaranteed items
    for _, item in ipairs(config.guaranteed or {}) do
        SpawnNear(item, x, z, 3)
    end

    -- Drop random items
    for i = 1, (config.randomCount or 1) do
        local item = SelectWeighted(config.random)
        SpawnNear(item, x, z, 5)
    end
end
```

## Conditional Loot

```lua
local function GetContextualLootTable(season, dayCount)
    local baseLoot = {
        {item = "goldnugget", weight = 50},
        {item = "silk", weight = 30},
    }

    -- Add seasonal items
    if season == "winter" then
        table.insert(baseLoot, {item = "ice", weight = 40})
        table.insert(baseLoot, {item = "bluegem", weight = 15})
    elseif season == "summer" then
        table.insert(baseLoot, {item = "redgem", weight = 15})
    end

    -- Better loot in late game
    if dayCount > 30 then
        table.insert(baseLoot, {item = "purplegem", weight = 10})
        table.insert(baseLoot, {item = "thulecite", weight = 5})
    end

    return baseLoot
end
```

## Event Selection

```lua
local EVENTS = {
    {id = "spider_ambush", weight = 60, category = "challenge"},
    {id = "hound_wave", weight = 40, category = "challenge"},
    {id = "loot_explosion", weight = 30, category = "reward"},
    {id = "arena_challenge", weight = 10, category = "challenge"},
    {id = "giant_awakens", weight = 5, category = "boss"},
}

local function SelectEvent(filterCategory)
    local filtered = {}

    for _, event in ipairs(EVENTS) do
        if not filterCategory or event.category == filterCategory then
            table.insert(filtered, event)
        end
    end

    if #filtered == 0 then
        return EVENTS[1]
    end

    return SelectWeighted(filtered)
end

-- Select any event
local event = SelectEvent()

-- Select only challenge events
local challengeEvent = SelectEvent("challenge")
```

## Streak Bonus System

```lua
local LootManager = {
    streak = 0,
    lastDropDay = -1,
}

function LootManager:OnDrop(currentDay)
    if currentDay == self.lastDropDay + 1 then
        self.streak = self.streak + 1
    else
        self.streak = 0
    end
    self.lastDropDay = currentDay

    return self:GetBonusMultiplier()
end

function LootManager:GetBonusMultiplier()
    -- Max 2x at 7 day streak
    return 1 + math.min(self.streak, 7) * 0.15
end

function LootManager:DropWithBonus(lootTable, count, x, z)
    local multiplier = self:GetBonusMultiplier()
    local adjustedCount = math.ceil(count * multiplier)

    print("Streak: " .. self.streak .. ", Multiplier: " .. multiplier)
    print("Dropping " .. adjustedCount .. " items (base: " .. count .. ")")

    for i = 1, adjustedCount do
        local item = SelectWeighted(lootTable)
        SpawnNear(item, x, z, 5)
    end
end
```

## Probability Utilities

```lua
-- Check if something should happen
local function Chance(percent)
    return math.random() * 100 < percent
end

-- Usage
if Chance(25) then  -- 25% chance
    SpawnRareItem()
end

-- Roll dice
local function RollDice(sides)
    return math.random(1, sides)
end

-- D20 roll
local roll = RollDice(20)
if roll == 20 then
    print("Critical success!")
end
```

## Full Example: Mystery Box Loot

```lua
local MysteryBoxLoot = {}

MysteryBoxLoot.RARITY = {
    COMMON = {weight = 60},
    UNCOMMON = {weight = 25},
    RARE = {weight = 10},
    LEGENDARY = {weight = 5},
}

MysteryBoxLoot.TABLE = {
    -- Common items
    {prefab = "goldnugget", weight = 15, rarity = "COMMON"},
    {prefab = "silk", weight = 12, rarity = "COMMON"},
    {prefab = "rope", weight = 10, rarity = "COMMON"},
    {prefab = "boards", weight = 10, rarity = "COMMON"},
    {prefab = "cutgrass", weight = 8, rarity = "COMMON"},
    {prefab = "twigs", weight = 5, rarity = "COMMON"},

    -- Uncommon items
    {prefab = "redgem", weight = 8, rarity = "UNCOMMON"},
    {prefab = "bluegem", weight = 8, rarity = "UNCOMMON"},
    {prefab = "gears", weight = 5, rarity = "UNCOMMON"},
    {prefab = "spear", weight = 4, rarity = "UNCOMMON"},

    -- Rare items
    {prefab = "purplegem", weight = 4, rarity = "RARE"},
    {prefab = "livinglog", weight = 3, rarity = "RARE"},
    {prefab = "thulecite_pieces", weight = 3, rarity = "RARE"},

    -- Legendary items
    {prefab = "amulet", weight = 2, rarity = "LEGENDARY"},
    {prefab = "orangestaff", weight = 1, rarity = "LEGENDARY"},
    {prefab = "armorruins", weight = 1, rarity = "LEGENDARY"},
    {prefab = "ruinshat", weight = 1, rarity = "LEGENDARY"},
}

function MysteryBoxLoot:SelectItem()
    return SelectWeighted(self.TABLE)
end

function MysteryBoxLoot:DropItems(count, x, z)
    for i = 1, count do
        local item = self:SelectItem()
        SpawnNear(item.prefab, x, z, 3)
    end
end

-- Usage
MysteryBoxLoot:DropItems(5, playerX, playerZ)
```

## See Also

- [entities.md](../dst-api/entities.md) - Spawning items
- [multi-wave-event.md](multi-wave-event.md) - Using loot in events
