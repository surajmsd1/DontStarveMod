# Prefab List - Spawnable Entities

## Overview
This is a categorized list of commonly used prefabs in DST that can be spawned with `SpawnPrefab("name")`.

## Quick Spawn
```lua
-- In modmain.lua
local entity = GLOBAL.SpawnPrefab("spider")

-- In prefab files
local entity = SpawnPrefab("spider")
```

---

## Hostile Mobs

### Basic Enemies
| Prefab | Description |
|--------|-------------|
| `spider` | Basic spider |
| `spider_warrior` | Warrior spider |
| `spider_hider` | Cave spider |
| `spider_spitter` | Spitting spider |
| `spider_dropper` | Dropping spider |
| `hound` | Basic hound |
| `firehound` | Fire hound (red) |
| `icehound` | Ice hound (blue) |
| `frog` | Frog |
| `mosquito` | Mosquito |
| `bee` | Bee (neutral) |
| `killerbee` | Killer bee |
| `tentacle` | Tentacle |

### Large Enemies
| Prefab | Description |
|--------|-------------|
| `leif` | Treeguard |
| `leif_sparse` | Thin Treeguard |
| `tallbird` | Tallbird |
| `merm` | Merm |
| `pigman` | Pig (neutral, befriendable) |
| `pigguard` | Pig Guard |
| `bunnyman` | Bunny (neutral) |
| `crawlinghorror` | Crawling Horror (shadow) |
| `terrorbeak` | Terrorbeak (shadow) |
| `walrus` | MacTusk |
| `little_walrus` | Wee MacTusk |

### Bosses
| Prefab | Description |
|--------|-------------|
| `deerclops` | Deerclops (winter boss) |
| `bearger` | Bearger (autumn boss) |
| `moose` | Moose/Goose (spring boss) |
| `dragonfly` | Dragonfly (summer boss) |
| `minotaur` | Ancient Guardian |
| `spiderqueen` | Spider Queen |
| `warg` | Varg (hound alpha) |
| `klaus` | Klaus |
| `antlion` | Antlion |
| `toadstool` | Toadstool |
| `stalker` | Ancient Fuelweaver |
| `crabking` | Crab King |
| `malbatross` | Malbatross |

---

## Passive Mobs

### Animals
| Prefab | Description |
|--------|-------------|
| `beefalo` | Beefalo |
| `babybeefalo` | Baby Beefalo |
| `koalefant_summer` | Koalefant |
| `rabbit` | Rabbit |
| `mole` | Mole |
| `penguin` | Pengull |
| `crow` | Crow |
| `robin` | Redbird |
| `robin_winter` | Snowbird |
| `butterfly` | Butterfly |
| `perd` | Gobbler (turkey) |
| `catcoon` | Catcoon |
| `carrat` | Carrat |

### Sea Creatures
| Prefab | Description |
|--------|-------------|
| `fish` | Fish (item) |
| `oceanfish_small_1` | Small ocean fish |
| `squid` | Squid |

---

## Items - Weapons

| Prefab | Description |
|--------|-------------|
| `spear` | Spear |
| `hambat` | Ham Bat |
| `tentaclespike` | Tentacle Spike |
| `nightsword` | Dark Sword |
| `glasscutter` | Glass Cutter |
| `ruins_bat` | Thulecite Club |
| `blowdart_pipe` | Blow Dart |
| `blowdart_fire` | Fire Dart |
| `blowdart_sleep` | Sleep Dart |
| `boomerang` | Boomerang |
| `icestaff` | Ice Staff |
| `firestaff` | Fire Staff |
| `telestaff` | Telelocator Staff |
| `orangestaff` | Lazy Explorer |
| `greenstaff` | Deconstruction Staff |
| `yellowstaff` | Star Caller Staff |
| `opalstaff` | Moon Caller Staff |

---

## Items - Armor

| Prefab | Description |
|--------|-------------|
| `armorgrass` | Grass Suit |
| `armorwood` | Log Suit |
| `armormarble` | Marble Suit |
| `armor_sanity` | Night Armor |
| `armorruins` | Thulecite Suit |
| `armorskeleton` | Bone Armor |
| `footballhat` | Football Helmet |
| `minerhat` | Miner Hat |
| `beehat` | Beekeeper Hat |
| `winterhat` | Winter Hat |
| `beefalohat` | Beefalo Hat |
| `walrushat` | Tam o' Shanter |
| `ruinshat` | Thulecite Crown |

---

## Items - Tools

| Prefab | Description |
|--------|-------------|
| `axe` | Axe |
| `goldenaxe` | Golden Axe |
| `pickaxe` | Pickaxe |
| `goldenpickaxe` | Golden Pickaxe |
| `shovel` | Shovel |
| `goldenshovel` | Golden Shovel |
| `hammer` | Hammer |
| `pitchfork` | Pitchfork |
| `bugnet` | Bug Net |
| `fishingrod` | Fishing Rod |
| `torch` | Torch |
| `lantern` | Lantern |
| `umbrella` | Umbrella |
| `heatrock` | Thermal Stone |
| `compass` | Compass |
| `featherfan` | Feather Fan |

---

## Items - Food (Raw)

| Prefab | Description |
|--------|-------------|
| `meat` | Meat |
| `smallmeat` | Morsel |
| `monstermeat` | Monster Meat |
| `fish` | Fish |
| `eel` | Eel |
| `berries` | Berries |
| `carrot` | Carrot |
| `corn` | Corn |
| `pumpkin` | Pumpkin |
| `eggplant` | Eggplant |
| `dragonfruit` | Dragon Fruit |
| `durian` | Durian |
| `pomegranate` | Pomegranate |
| `watermelon` | Watermelon |
| `honey` | Honey |
| `honeycomb` | Honeycomb |
| `butter` | Butter |
| `froglegs` | Frog Legs |
| `drumstick` | Drumstick |
| `bird_egg` | Egg |

---

## Items - Food (Cooked)

| Prefab | Description |
|--------|-------------|
| `cookedmeat` | Cooked Meat |
| `cookedsmallmeat` | Cooked Morsel |
| `cookedmonstermeat` | Cooked Monster Meat |
| `cookedfish` | Cooked Fish |
| `berries_cooked` | Roasted Berries |
| `carrot_cooked` | Roasted Carrot |
| `corn_cooked` | Popcorn |
| `pumpkin_cooked` | Cooked Pumpkin |
| `dragonfruit_cooked` | Cooked Dragon Fruit |

---

## Items - Resources

### Basic Materials
| Prefab | Description |
|--------|-------------|
| `log` | Log |
| `boards` | Boards |
| `livinglog` | Living Log |
| `twigs` | Twigs |
| `cutgrass` | Cut Grass |
| `rope` | Rope |
| `rocks` | Rocks |
| `flint` | Flint |
| `nitre` | Nitre |
| `goldnugget` | Gold Nugget |
| `moonrocknugget` | Moon Rock |
| `marble` | Marble |
| `ice` | Ice |

### Animal Products
| Prefab | Description |
|--------|-------------|
| `silk` | Silk |
| `spidergland` | Spider Gland |
| `beefalowool` | Beefalo Wool |
| `pigskin` | Pig Skin |
| `feather_crow` | Crow Feather |
| `feather_robin` | Crimson Feather |
| `feather_robin_winter` | Azure Feather |
| `houndstooth` | Hound's Tooth |
| `stinger` | Stinger |
| `horn` | Beefalo Horn |

### Gems
| Prefab | Description |
|--------|-------------|
| `redgem` | Red Gem |
| `bluegem` | Blue Gem |
| `purplegem` | Purple Gem |
| `yellowgem` | Yellow Gem |
| `orangegem` | Orange Gem |
| `greengem` | Green Gem |
| `opalpreciousgem` | Opal Gem |

### Special
| Prefab | Description |
|--------|-------------|
| `nightmarefuel` | Nightmare Fuel |
| `gears` | Gears |
| `transistor` | Transistor |
| `papyrus` | Papyrus |
| `thulecite` | Thulecite |
| `thulecite_pieces` | Thulecite Fragments |
| `ancientorb` | Ancient Orb |

---

## Items - Magic

### Amulets
| Prefab | Description |
|--------|-------------|
| `amulet` | Life Giving Amulet (red) |
| `blueamulet` | Chilled Amulet |
| `purpleamulet` | Nightmare Amulet |
| `yellowamulet` | Magiluminescence |
| `orangeamulet` | Lazy Forager |
| `greenamulet` | Construction Amulet |

---

## Structures

### Crafting Stations
| Prefab | Description |
|--------|-------------|
| `firepit` | Fire Pit |
| `campfire` | Campfire |
| `coldfire` | Endothermic Fire |
| `researchlab` | Science Machine |
| `researchlab2` | Alchemy Engine |
| `shadow_container` | Shadow Manipulator |
| `crockpot` | Crock Pot |
| `icebox` | Ice Box |
| `treasurechest` | Chest |

### Plants
| Prefab | Description |
|--------|-------------|
| `pinecone` | Pine Cone |
| `acorn` | Birchnut |
| `dug_berrybush` | Dug Berry Bush |
| `dug_grass` | Dug Grass |
| `dug_sapling` | Dug Sapling |
| `flower` | Flower |

---

## Effects & Misc

| Prefab | Description |
|--------|-------------|
| `lightning` | Lightning strike |
| `explode_small` | Small explosion effect |
| `firework_rocket` | Firework |
| `groundpound_fx` | Ground pound effect |
| `splash` | Water splash |

---

## Spawn Examples

### Combat Arena
```lua
-- Spawn wave of enemies
for i = 1, 10 do SpawnNear("spider", x, z, 10) end
for i = 1, 5 do SpawnNear("hound", x, z, 15) end
SpawnNear("leif", x, z, 20)
```

### Treasure Drop
```lua
-- Spawn mixed loot
local loot = {
    "goldnugget", "goldnugget", "goldnugget",
    "redgem", "bluegem", "purplegem",
    "silk", "silk", "rope",
}
for _, item in ipairs(loot) do
    SpawnNear(item, x, z, 5)
end
```

### Food Supply
```lua
-- Emergency food kit
SpawnNear("cookedmeat", x, z, 3)
SpawnNear("cookedmeat", x, z, 3)
SpawnNear("cookedmeat", x, z, 3)
SpawnNear("honey", x, z, 3)
SpawnNear("berries_cooked", x, z, 3)
```

### Combat Gear
```lua
-- Gear up!
SpawnNear("spear", x, z, 2)
SpawnNear("armorwood", x, z, 2)
SpawnNear("footballhat", x, z, 2)
SpawnNear("torch", x, z, 2)
SpawnNear("healingsalve", x, z, 2)
```

---

## Notes

- All prefab names are lowercase
- Some prefabs have variants (e.g., `spider_warrior`)
- Spawned entities may need additional setup (health, target)
- Check DST game scripts for complete list: `scripts/prefabs/`

## See Also

- [entities.md](entities.md) - Spawning patterns
- [components.md](components.md) - Entity components

## Sources

- DST Game Scripts: `scripts/prefabs/*.lua`
- DST Wiki: https://dontstarve.wiki.gg/
