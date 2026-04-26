-- Boss & Seasonal Events for Mystery Box DnD Gamemaster Mod
-- Major encounters and seasonal-themed events

-- Get GLOBAL reference
local _G = GLOBAL or _G
local AllPlayers = _G.AllPlayers
local SpawnPrefab = _G.SpawnPrefab
local TheNet = _G.TheNet

local EventTypes = require("events/event_types")

-- LootSystem is loaded via pcall so the file still runs if the require
-- path changes. Falls back to the old hardcoded loot if missing.
local LootSystem = nil
local ok, result = pcall(function() return require "core/loot_system" end)
if ok then LootSystem = result end

local BossEvents = {}

-- Boss tiers
--   mini   = roughly solo-fightable with prep (treeguards, rook, spider queen)
--   bigbad = group fight or major prep (varg, ewecus, clay warg)
-- Each entry has:
--   prefab       — what to spawn
--   label        — how to name it in announcements ("A Varg has arrived!")
--   hint         — one-line warning shown 60s before arrival ("a beast is howling…")
--   reward_pack  — LootSystem pack name to drop on death
--   reward_hint  — vague description of the prize ("rumors of an ancient blade")
-- Mini = multi-spawn or relatively weaker single units. Reward drops once
-- at the last death (one shared chest, simple flow).
-- Big Bad = single scary unit. Reward is baked into the mob's lootdropper
-- so it ONLY drops on real death — if a Spider Queen burrows back into a
-- nest (no death event), the player gets nothing, as intended.
local BOSS_TIERS = {
    mini = {
        weight = 70,
        roster = {
            {prefab = "leif",             weight = 28, label = "Treeguard",
             hint = "the trees groan and creak…",
             reward_hint = "wood, gems, and maybe a curious tool"},
            {prefab = "leif_sparse",      weight = 18, label = "Lumpy Treeguard",
             hint = "a knotted oak shifts on its roots…",
             reward_hint = "wood, gems, and maybe a curious tool"},
            {prefab = "deciduousmonster", weight = 18, label = "Poison Birchnut Tree",
             hint = "leaves rustle with malice…",
             reward_hint = "wood, gems, and maybe a curious tool"},
            -- Knights spawn as a pack so the encounter has weight.
            {prefab = "knight",           weight = 18, label = "Clockwork Knights", count = 3,
             hint = "iron hooves clatter — a patrol approaches…",
             reward_hint = "gears, gems, and possibly a finer trinket"},
            -- Classic chess set: one of each clockwork. Mixed threats
            -- (charging knight + ranged bishop + bruiser rook).
            {prefab_list = {"knight", "rook", "bishop"}, weight = 18,
             label = "Clockwork Trio",
             hint = "the gears of three machines wind in unison…",
             reward_hint = "gears, gems, and possibly a finer trinket"},
        },
        reward_pack = "miniboss_reward",
    },
    bigbad = {
        weight = 30,
        roster = {
            {prefab = "varg",        weight = 25, label = "Varg",
             hint = "a beast is howling, and it's NOT alone…",
             reward_hint = "treasures worthy of a true hunter"},
            {prefab = "spat",        weight = 22, label = "Ewecus",
             hint = "something massive snorts in the distance…",
             reward_hint = "treasures worthy of a true hunter"},
            {prefab = "claywarg",    weight = 18, label = "Clay Warg",
             hint = "stone scrapes stone — something woke up…",
             reward_hint = "treasures worthy of a true hunter"},
            {prefab = "spiderqueen", weight = 18, label = "Spider Queen",
             hint = "the ground crawls with too many legs…",
             reward_hint = "silk, monstrous loot, and a hidden prize"},
            {prefab = "rook",        weight = 9,  label = "Clockwork Rook",
             hint = "distant gears grind in earnest…",
             reward_hint = "treasures worthy of a true hunter"},
            {prefab = "bishop",      weight = 8,  label = "Clockwork Bishop",
             hint = "a chime rings — arcane menace gathers…",
             reward_hint = "treasures worthy of a true hunter"},
        },
        reward_pack = "bigbad_reward",
    },
}

local function WeightedPick(entries)
    local total = 0
    for _, entry in ipairs(entries) do total = total + entry.weight end
    local roll = math.random() * total
    local acc = 0
    for _, entry in ipairs(entries) do
        acc = acc + entry.weight
        if roll <= acc then return entry end
    end
    return entries[1]
end

-- Pick a tier first, then a boss inside the tier. Returns the boss entry
-- with its tier name and the tier's reward_pack glued on for convenience.
local function PickBoss()
    local tierEntries = {
        {weight = BOSS_TIERS.mini.weight,   tier = "mini"},
        {weight = BOSS_TIERS.bigbad.weight, tier = "bigbad"},
    }
    local tierPick = WeightedPick(tierEntries)
    local tier = BOSS_TIERS[tierPick.tier]
    local boss = WeightedPick(tier.roster)
    return {
        prefab = boss.prefab,
        label = boss.label,
        hint = boss.hint,
        reward_hint = boss.reward_hint,
        reward_pack = tier.reward_pack,
        tier = tierPick.tier,
    }
end

-- Module-local "boss event in progress" guard. Daily/seasonal events check
-- this and skip when set so the player isn't piled-on. Cleared on death or
-- after a generous timeout if the boss never dies / despawns.
local active_boss_event = false
function BossEvents.IsBossActive() return active_boss_event end
local function SetBossActive(on) active_boss_event = on end

-- Try to send a colored on-screen warning. DST's `TheNet:Announce` is plain
-- text only; some clients support a custom announcement variant with a
-- color tint. We try the fancier path first and fall back to plain
-- announce, prefixing red-tier warnings with attention markers so players
-- see them stand out even without color.
local function AnnounceWarning(message, isRed)
    local prefix = isRed and "\xE2\x98\xA0 DANGER \xE2\x98\xA0  " or ""
    local fullMsg = prefix .. message
    -- Try color-capable announcement APIs that some DST builds expose.
    if TheNet then
        if isRed and TheNet.AnnounceColourFormatted then
            -- (msg, instance, b_local, type, icon, colour)
            local okCall = pcall(TheNet.AnnounceColourFormatted, TheNet,
                fullMsg, nil, false, "default", nil, {1, 0.2, 0.2, 1})
            if okCall then return end
        end
        if TheNet.Announce then
            TheNet:Announce(fullMsg)
        end
    end
end

-- Helper: Find a random player and their position
local function GetRandomPlayerPosition()
    local players = {}
    for _, v in ipairs(AllPlayers) do
        table.insert(players, v)
    end

    if #players == 0 then
        return nil, 0, 0, 0
    end

    local player = players[math.random(#players)]
    local x, y, z = player.Transform:GetWorldPosition()
    return player, x, y, z
end

-- Helper: Spawn multiple entities around a position
local function SpawnEntitiesAround(prefab, count, x, z, radius)
    local spawned = {}
    for i = 1, count do
        local entity = SpawnPrefab(prefab)
        if entity then
            local angle = math.random() * 2 * math.pi
            local dist = math.random() * radius
            local px = x + math.cos(angle) * dist
            local pz = z + math.sin(angle) * dist
            entity.Transform:SetPosition(px, 0, pz)
            table.insert(spawned, entity)
        end
    end
    return spawned
end

-- Helper: Drop loot near position
local function DropLootNear(lootTable, x, z, radius)
    for _, item in ipairs(lootTable) do
        local loot = SpawnPrefab(item)
        if loot then
            local angle = math.random() * 2 * math.pi
            local dist = math.random() * radius
            loot.Transform:SetPosition(x + math.cos(angle) * dist, 0, z + math.sin(angle) * dist)
        end
    end
end

-- Helper: skip an event when a boss encounter is in progress so daily/
-- seasonal events don't pile on top of a hostile boss spawn.
local function SkipIfBossActive(eventName)
    if active_boss_event then
        print("[Mystery Box] " .. eventName .. " skipped — boss event active.")
        return true
    end
    return false
end

-- Helper: Find a random walkable position in the world
local function GetRandomWorldPosition()
    -- Get a random position within a reasonable range of existing players
    local player, px, py, pz = GetRandomPlayerPosition()
    if not player then
        return 0, 0, 0
    end

    -- Random offset from player (50-100 units away)
    local angle = math.random() * 2 * math.pi
    local dist = 50 + math.random() * 50
    local x = px + math.cos(angle) * dist
    local z = pz + math.sin(angle) * dist

    return x, 0, z
end

--------------------------------------------------------------------------------
-- MINI-BOSS WARNING EVENT
-- Announces an incoming boss, gives players time to prepare, spawns supplies
--------------------------------------------------------------------------------
BossEvents.MiniBossWarning = EventTypes.CreateEvent({
    id = "miniboss_warning",
    name = "Mini-Boss Incoming!",
    description = "A powerful creature approaches! Prepare yourself - supplies incoming!",
    category = EventTypes.CATEGORY.BOSS,
    rarity = EventTypes.RARITY.RARE,
    trigger = EventTypes.TRIGGER.WEEKLY,

    GetAnnouncement = function()
        return "DANGER! A powerful creature stirs... You have 60 seconds to prepare!"
    end,

    Execute = function(world, target)
        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Don't stack boss events on top of each other.
        if active_boss_event then
            print("[Mystery Box] Skipping mini-boss warning — boss event already active.")
            return false
        end

        -- Pick the boss now so the warning can name it (or at least tease it).
        local pick = PickBoss()
        local isBigBad = pick.tier == "bigbad"

        SetBossActive(true)

        -- Combat supplies for everyone — bigger pack for big bads.
        local supplies = isBigBad
            and {"spear", "spear", "armorwood", "armorwood", "footballhat",
                 "healingsalve", "healingsalve", "healingsalve", "honey"}
             or {"spear", "armorwood", "footballhat", "healingsalve", "healingsalve"}
        for _, p in ipairs(AllPlayers) do
            if p and p.Transform then
                local px, py, pz = p.Transform:GetWorldPosition()
                DropLootNear(supplies, px, pz, 5)
            end
        end

        -- Warning announcement. Includes the hint about what's coming and
        -- a tease about the reward, but does NOT name the prefab outright —
        -- players still get the surprise of seeing it appear.
        local rewardLine = "Whatever it guards, " .. pick.reward_hint .. "."
        if isBigBad then
            AnnounceWarning("Something terrible stirs — " .. pick.hint, true)
            AnnounceWarning(rewardLine .. " You have 60 seconds.", true)
        else
            AnnounceWarning("A creature approaches — " .. pick.hint, false)
            AnnounceWarning(rewardLine .. " You have 60 seconds.", false)
        end

        -- Schedule the boss spawn after 60 seconds
        world:DoTaskInTime(60, function()
            -- Announce arrival with the proper name now
            local arriveMsg = isBigBad
                and ("\xE2\x98\xA0 " .. pick.label .. " has arrived! \xE2\x98\xA0")
                or  ("A " .. pick.label .. " has arrived!")
            AnnounceWarning(arriveMsg, isBigBad)

            local targetPlayer, tx, ty, tz = GetRandomPlayerPosition()
            if not targetPlayer then
                SetBossActive(false)
                return
            end

            -- Spawn the boss(es). Three forms supported:
            --   prefab + count       → multiple of the same (e.g. knights)
            --   prefab_list          → one of each in the list (e.g. trio)
            --   prefab               → single boss
            local spawned = {}
            local function placeAndTag(boss, idx)
                if not boss then return end
                local angle = idx * (math.pi * 2 / 6)
                local offsetX = math.cos(angle) * 3
                local offsetZ = math.sin(angle) * 3
                boss.Transform:SetPosition(tx + 15 + offsetX, 0, tz + 15 + offsetZ)
                boss:AddTag("mod_miniboss_reward")
                table.insert(spawned, boss)
            end

            if pick.prefab_list then
                for i, prefab in ipairs(pick.prefab_list) do
                    placeAndTag(SpawnPrefab(prefab), i)
                end
            elseif pick.count and pick.count > 1 then
                for i = 1, pick.count do
                    placeAndTag(SpawnPrefab(pick.prefab), i)
                end
            else
                placeAndTag(SpawnPrefab(pick.prefab), 0)
            end

            print(string.format("[Mystery Box] Boss spawned: %s (%s tier, %d entities)",
                pick.label, pick.tier, #spawned))

            if #spawned == 0 then
                SetBossActive(false)
                return
            end

            -- Reward delivery differs by tier:
            --
            -- BIG BADS (single scary unit): bake the reward into the mob's
            -- own lootdropper. The engine drops it ONLY on real death — if
            -- a Spider Queen burrows back into a nest (no death event), the
            -- player gets nothing, which is the intended "you didn't beat
            -- it" outcome. Each big bad also gets perma-aggro so it can't
            -- be cheesed by running out of leash range.
            --
            -- MINI (multi-spawn / weaker): drop one shared chest at the
            -- last death via a simple listener. Simpler, fewer moving parts.
            local rewardPack = pick.reward_pack

            if isBigBad then
                local boss = spawned[1]
                -- Bake reward into lootdropper. Built once now so weighted
                -- bonus rolls happen at spawn (deterministic per-encounter)
                -- and the engine handles drop-on-death automatically.
                if LootSystem and boss.components and boss.components.lootdropper then
                    local result = LootSystem.BuildLootList(rewardPack)
                    boss.components.lootdropper:SetLoot(result.items or {})
                end

                -- Perma-aggro: never drop target, never wander home. Done by
                -- removing the home location and overriding the keep-target
                -- predicate. Works across mob types because both are
                -- standard combat/knownlocations component APIs.
                if boss.components and boss.components.knownlocations then
                    boss.components.knownlocations:ForgetLocation("home")
                end
                if boss.components and boss.components.combat then
                    boss.components.combat:SetKeepTargetFunction(function(_, target)
                        return target ~= nil and target:IsValid()
                            and target.components and target.components.health
                            and not target.components.health:IsDead()
                    end)
                end

                -- Single death listener just for cleanup (active flag +
                -- victory announce). Loot itself comes from lootdropper.
                boss:ListenForEvent("death", function(inst)
                    AnnounceWarning("Victory! The " .. pick.label .. " falls.", true)
                    SetBossActive(false)
                end)
            else
                -- Mini tier: one shared chest dropped at last death.
                local remaining = #spawned
                for _, boss in ipairs(spawned) do
                    boss:ListenForEvent("death", function(inst)
                        remaining = remaining - 1
                        if remaining <= 0 then
                            local dx, dy, dz = inst.Transform:GetWorldPosition()
                            AnnounceWarning("Victory! The " .. pick.label .. " falls.",
                                false)
                            if LootSystem then
                                LootSystem.DropPack(rewardPack, dx, 0, dz, {radius = 4})
                            else
                                local treasure = {"goldnugget", "goldnugget", "goldnugget",
                                                  "redgem", "bluegem", "gears"}
                                DropLootNear(treasure, dx, dz, 3)
                            end
                            SetBossActive(false)
                        end
                    end)
                end
            end

            -- Safety net: if the encounter is never resolved (boss flees,
            -- despawns, players abandon it), clear the flag after 12 minutes
            -- so future events aren't permanently blocked.
            world:DoTaskInTime(720, function()
                if active_boss_event then
                    print("[Mystery Box] Boss event timeout — clearing active flag.")
                    SetBossActive(false)
                end
            end)
        end)

        print(string.format("[Mystery Box] %s Warning! %s incoming in 60s.",
            isBigBad and "BIG BAD" or "Mini-Boss", pick.label))
        return true
    end,
})

--------------------------------------------------------------------------------
-- TREASURE HUNT EVENT
-- Spawns a mystery box at a random location, announces coordinates to all
--------------------------------------------------------------------------------
BossEvents.TreasureHunt = EventTypes.CreateEvent({
    id = "treasure_hunt",
    name = "Treasure Hunt!",
    description = "A valuable treasure has appeared somewhere in the world!",
    category = EventTypes.CATEGORY.REWARD,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.DAILY,

    GetAnnouncement = function()
        return "TREASURE HUNT! A mystery box has appeared somewhere in the wilderness!"
    end,

    Execute = function(world, target)
        if SkipIfBossActive("Treasure Hunt") then return false end

        -- Find a random location away from players
        local x, y, z = GetRandomWorldPosition()

        -- Spawn a mystery box
        local box = SpawnPrefab("mysterybox")
        if box then
            box.Transform:SetPosition(x, 0, z)

            -- Bonus loot scattered around the box. Uses the weighted
            -- treasure_hunt_bonus pack: mostly normal good stuff (gold,
            -- gems, healing, building mats) with rare standout rolls
            -- (cane, magiluminescence, piggyback) to keep the hunt exciting.
            if LootSystem then
                LootSystem.DropPack("treasure_hunt_bonus", x, 0, z, {radius = 5})
            else
                local bonusLoot = {"goldnugget", "goldnugget", "purplegem", "thulecite"}
                DropLootNear(bonusLoot, x, z, 5)
            end

            -- Announce approximate direction to players
            local player, px, py, pz = GetRandomPlayerPosition()
            if player then
                local dx = x - px
                local dz = z - pz
                local direction = ""

                if math.abs(dx) > math.abs(dz) then
                    direction = dx > 0 and "EAST" or "WEST"
                else
                    direction = dz > 0 and "NORTH" or "SOUTH"
                end

                local distance = math.sqrt(dx * dx + dz * dz)
                local distDesc = distance > 100 and "far" or "nearby"

                if TheNet and TheNet.Announce then
                    TheNet:Announce("The treasure lies " .. distDesc .. " to the " .. direction .. "!")
                end
            end

            print("[Mystery Box] Treasure Hunt box spawned at: " .. x .. ", " .. z)
            return true
        end

        return false
    end,
})

--------------------------------------------------------------------------------
-- SEASONAL EVENTS
--------------------------------------------------------------------------------

-- AUTUMN: Harvest Festival - spawn tons of food
BossEvents.HarvestFestival = EventTypes.CreateEvent({
    id = "harvest_festival",
    name = "Harvest Festival!",
    description = "The spirits celebrate autumn with a bounty of food!",
    category = EventTypes.CATEGORY.REWARD,
    rarity = EventTypes.RARITY.COMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "HARVEST FESTIVAL! Food rains from the sky!"
    end,

    Execute = function(world, target)
        if SkipIfBossActive("Harvest Festival") then return false end

        -- Only trigger in autumn
        local season = world.state and world.state.season or "autumn"
        if season ~= "autumn" then
            print("[Mystery Box] Harvest Festival skipped - not autumn")
            return false
        end

        -- Spawn food + a small chance at something interesting near each player.
        local interesting = {
            {"crockpot", 6}, {"birdcage", 3}, {"farmplot", 6},
            {"backpack", 6}, {"bushhat", 4}, {"goldnugget", 10},
        }
        for _, player in ipairs(AllPlayers) do
            local x, y, z = player.Transform:GetWorldPosition()
            local food = {
                "carrot", "carrot", "carrot",
                "corn", "corn",
                "pumpkin", "pumpkin",
                "berries", "berries", "berries",
                "honey", "honey",
            }
            DropLootNear(food, x, z, 8)
            -- One bonus roll per player to keep it harvest-themed but not OP.
            if LootSystem then
                local pick = LootSystem.RollWeighted(interesting)
                if pick then DropLootNear({pick}, x, z, 4) end
            end
        end

        print("[Mystery Box] Harvest Festival triggered!")
        return true
    end,
})

-- WINTER: Frostbite Challenge - spawn warm gear + ice enemies
BossEvents.FrostbiteChallenge = EventTypes.CreateEvent({
    id = "frostbite_challenge",
    name = "Frostbite Challenge!",
    description = "Winter's wrath arrives early! Warm gear and icy foes appear!",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "WINTER'S WRATH! Ice hounds approach, but warm gear awaits!"
    end,

    Execute = function(world, target)
        if SkipIfBossActive("Frostbite Challenge") then return false end

        -- Only trigger in winter
        local season = world.state and world.state.season or "autumn"
        if season ~= "winter" then
            print("[Mystery Box] Frostbite Challenge skipped - not winter")
            return false
        end

        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn ice hounds
        SpawnEntitiesAround("icehound", 4, x, z, 12)

        -- Warm gear + one weighted bonus roll for something properly useful
        -- in the deep cold. Walking cane (speed = warmth uptime) is the
        -- showpiece prize but rare; thermal stone / puffy vest more common.
        local warmGear = {"beefalohat", "winterhat", "heatrock", "torch", "torch"}
        DropLootNear(warmGear, x, z, 6)
        if LootSystem then
            local bonus = LootSystem.RollWeighted({
                {"heatrock", 18}, {"winterhat", 12}, {"beefalohat", 10},
                {"puffyvest", 6}, {"icestaff", 5},
                {"magiluminescence", 3}, {"cane", 2},
            })
            if bonus then DropLootNear({bonus}, x, z, 4) end
        end

        print("[Mystery Box] Frostbite Challenge triggered!")
        return true
    end,
})

-- SPRING: Frog Rain - spawn frogs + rain gear
BossEvents.FrogRain = EventTypes.CreateEvent({
    id = "frog_rain",
    name = "Frog Rain!",
    description = "It's raining frogs! And also... useful items!",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.COMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "IT'S RAINING FROGS! Quick, grab the loot!"
    end,

    Execute = function(world, target)
        if SkipIfBossActive("Frog Rain") then return false end

        -- Only trigger in spring
        local season = world.state and world.state.season or "autumn"
        if season ~= "spring" then
            print("[Mystery Box] Frog Rain skipped - not spring")
            return false
        end

        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn frogs
        SpawnEntitiesAround("frog", 15, x, z, 15)

        -- Rain gear + weighted bonus. Eyebrella is the dream pull.
        local gear = {"umbrella", "raincoat", "spear", "spear"}
        DropLootNear(gear, x, z, 5)
        if LootSystem then
            local bonus = LootSystem.RollWeighted({
                {"umbrella", 18}, {"raincoat", 12}, {"strawhat", 10},
                {"trunkvest_summer", 4}, {"goggleshat", 4},
                {"eyebrellahat", 2}, {"cane", 2},
            })
            if bonus then DropLootNear({bonus}, x, z, 4) end
        end

        -- Trigger rain
        if world:HasTag("forest") then
            world:PushEvent("ms_forceprecipitation", true)
        end

        print("[Mystery Box] Frog Rain triggered!")
        return true
    end,
})

-- SUMMER: Heat Wave - spawn cooling items + fire hounds
BossEvents.HeatWave = EventTypes.CreateEvent({
    id = "heat_wave",
    name = "Heat Wave!",
    description = "Scorching heat brings fire hounds! But also ice and cooling gear!",
    category = EventTypes.CATEGORY.CHALLENGE,
    rarity = EventTypes.RARITY.UNCOMMON,
    trigger = EventTypes.TRIGGER.SEASONAL,

    GetAnnouncement = function()
        return "HEAT WAVE! Fire hounds approach! Grab the ice!"
    end,

    Execute = function(world, target)
        if SkipIfBossActive("Heat Wave") then return false end

        -- Only trigger in summer
        local season = world.state and world.state.season or "autumn"
        if season ~= "summer" then
            print("[Mystery Box] Heat Wave skipped - not summer")
            return false
        end

        local player, x, y, z = GetRandomPlayerPosition()
        if not player then return false end

        -- Spawn fire hounds
        SpawnEntitiesAround("firehound", 3, x, z, 12)

        -- Cooling gear + weighted bonus. Whirly fan is fun + thematic;
        -- thermal stone cold-charged is a real summer survival prize.
        local coolGear = {"icehat", "ice", "ice", "ice", "watermelon", "watermelon"}
        DropLootNear(coolGear, x, z, 6)
        if LootSystem then
            local bonus = LootSystem.RollWeighted({
                {"icehat", 14}, {"strawhat", 12}, {"watermelonhat", 10},
                {"whirlyfan", 8}, {"icestaff", 5}, {"goggleshat", 5},
                {"eyebrellahat", 3}, {"cane", 2},
            })
            if bonus then DropLootNear({bonus}, x, z, 4) end
        end

        print("[Mystery Box] Heat Wave triggered!")
        return true
    end,
})

-- Function to register all boss events with the event manager
function BossEvents.RegisterAll(eventManager)
    eventManager:RegisterEvent(BossEvents.MiniBossWarning)
    eventManager:RegisterEvent(BossEvents.TreasureHunt)
    eventManager:RegisterEvent(BossEvents.HarvestFestival)
    eventManager:RegisterEvent(BossEvents.FrostbiteChallenge)
    eventManager:RegisterEvent(BossEvents.FrogRain)
    eventManager:RegisterEvent(BossEvents.HeatWave)

    print("[Mystery Box] Registered 6 boss/seasonal events")
end

return BossEvents
