-- Lookout Tower Prefab
-- Click to enter scout mode: fast movement + map reveal
-- Exit via: SPACE key, max distance, or any interaction
--
-- =============================================================================
-- DST ACTIVATABLE COMPONENT - LESSONS LEARNED
-- =============================================================================
--
-- The activatable component requires the "inactive" TAG to show the activate action.
--
-- KEY INSIGHT: The component has BOTH a property AND a tag:
--   - inst.components.activatable.inactive (boolean property)
--   - inst:HasTag("inactive") (tag on entity)
--
-- When you set the PROPERTY, it automatically syncs the TAG:
--   inst.components.activatable.inactive = true  --> adds "inactive" tag
--   inst.components.activatable.inactive = false --> removes "inactive" tag
--
-- BUT setting the TAG directly does NOT update the property!
--   inst:AddTag("inactive")  --> tag added, but property still false = BROKEN
--
-- ALWAYS use the property, not the tag directly:
--   CORRECT: inst.components.activatable.inactive = true
--   WRONG:   inst:AddTag("inactive")
--
-- OnActivate return values:
--   return true  --> "activation succeeded" (no default message)
--   return false --> "activation failed" (shows "I can't do that")
--
-- For reusable activatables, set inactive = true at START of OnActivate
-- to re-enable it immediately for next use.
-- =============================================================================

require "prefabutil"

local assets = {
    Asset("ANIM", "anim/pig_house.zip"),
    Asset("ANIM", "anim/winona_spotlight.zip"),
}

-- Config
local SCOUT_SPEED = 30
local SCOUT_REVEAL_RADIUS = 50
local SCOUT_MAX_DISTANCE = 150
local SCOUT_COOLDOWN = 60  -- 1 minute

-- =============================================================================
-- SCOUT MODE
-- =============================================================================

local function GetExitFunction()
    return rawget(_G, "MysteryBox_ExitScoutMode")
end

local function EnterScoutMode(inst, doer)
    if not doer or not doer:HasTag("player") then
        return false
    end

    local ExitScoutMode = GetExitFunction()
    if not ExitScoutMode then
        print("[Lookout Tower] ERROR: ExitScoutMode not found")
        return false
    end

    -- Store state on player
    doer._scout_original_speed = doer.components.locomotor.runspeed
    doer._scout_tower = inst
    local tx, _, tz = inst.Transform:GetWorldPosition()
    doer._scout_tower_pos = {x = tx, z = tz}

    -- Apply effects
    doer.components.locomotor.runspeed = SCOUT_SPEED
    doer.components.locomotor.walkspeed = SCOUT_SPEED
    doer.AnimState:SetMultColour(0.3, 0.3, 0.3, 0.5)
    doer:AddTag("scouting")

    -- Fill the whole biome (not just outline) so towers near edges still
    -- reveal their entire home biome. Falls back to outline, then a circle.
    local RevealBiomeFill = rawget(_G, "MysteryBox_RevealBiomeFill")
    if RevealBiomeFill then
        RevealBiomeFill(doer, tx, tz)
    else
        local RevealBiomeOutline = rawget(_G, "MysteryBox_RevealBiomeOutline")
        if RevealBiomeOutline then
            RevealBiomeOutline(doer, tx, tz)
        end
    end

    -- Also reveal coastlines near the tower
    local RevealCoastlineNear = rawget(_G, "MysteryBox_RevealCoastlineNear")
    if RevealCoastlineNear then
        RevealCoastlineNear(doer, tx, tz, 180)  -- 180 unit radius
    end

    -- Periodic task: map reveal + distance check
    doer._scout_task = doer:DoPeriodicTask(0.2, function()
        if not doer:HasTag("scouting") then return end

        local x, _, z = doer.Transform:GetWorldPosition()

        -- Reveal map
        if doer.player_classified and doer.player_classified.MapExplorer then
            doer.player_classified.MapExplorer:RevealArea(x, 0, z, SCOUT_REVEAL_RADIUS)
        end

        -- Distance check
        local pos = doer._scout_tower_pos
        if pos then
            local dist = math.sqrt((x - pos.x)^2 + (z - pos.z)^2)
            if dist >= SCOUT_MAX_DISTANCE then
                ExitScoutMode(doer, "Too far! Dropping in!")
            end
        end
    end)

    -- Exit on interaction (but not tower clicks)
    doer._scout_action_listener = function(_, data)
        if not doer:HasTag("scouting") then return end

        -- Ignore tower activation
        if data and data.action then
            local target = data.action.target
            if target and target:HasTag("lookouttower") then
                return
            end
        end

        ExitScoutMode(doer, "Dropped in!")
    end
    doer:ListenForEvent("performaction", doer._scout_action_listener)

    -- Feedback
    if doer.components.talker then
        doer.components.talker:Say("Scout mode! SPACE to drop in.")
    end

    -- Mark tower in use
    inst.scout_active = true
    inst.scout_player = doer

    print("[Lookout Tower] Scout mode ON")
    return true
end

-- =============================================================================
-- ACTIVATION
-- =============================================================================

local function OnActivate(inst, doer)
    print("[Lookout Tower] OnActivate called")

    -- Re-enable via the component property (this also adds the tag)
    inst.components.activatable.inactive = true

    -- Auto-discover this tower when activated (goes through shared network
    -- so it's saved and broadcast to all clients)
    local Discover = rawget(_G, "MysteryBox_DiscoverTowerServer")
    if Discover then
        Discover(inst)
    elseif not inst:HasTag("tower_discovered") then
        inst:AddTag("tower_discovered")
    end

    -- Check cooldown
    if inst.cooldown_until and GetTime() < inst.cooldown_until then
        local remaining = math.ceil(inst.cooldown_until - GetTime())
        local mins = math.floor(remaining / 60)
        local secs = remaining % 60
        print("[Lookout Tower] On cooldown, remaining: " .. remaining)
        -- Use delayed say to override the default "I can't" message
        if doer.components.talker then
            doer:DoTaskInTime(0, function()
                doer.components.talker:Say(string.format("Tower recharging... %d:%02d", mins, secs))
            end)
        end
        return true  -- Return true to prevent "I can't do that" message
    end

    if inst.scout_active and inst.scout_player then
        -- Exit scout mode
        local ExitScoutMode = GetExitFunction()
        if ExitScoutMode then
            ExitScoutMode(inst.scout_player, "Dropped in!")
        end
    else
        -- Enter scout mode
        EnterScoutMode(inst, doer)
    end
    return false
end

-- =============================================================================
-- PREFAB
-- =============================================================================

local function fn()
    local inst = CreateEntity()

    -- Common setup
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    -- Minimap
    inst.MiniMapEntity:SetIcon("winona_spotlight.png")
    inst.MiniMapEntity:SetPriority(5)

    -- Visual: blue-tinted pig house
    inst.AnimState:SetBank("pig_house")
    inst.AnimState:SetBuild("pig_house")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetMultColour(0.7, 0.9, 1, 1)

    -- Spotlight decoration
    inst.spotlight = CreateEntity()
    inst.spotlight.entity:AddTransform()
    inst.spotlight.entity:AddAnimState()
    inst.spotlight.AnimState:SetBank("winona_spotlight")
    inst.spotlight.AnimState:SetBuild("winona_spotlight")
    inst.spotlight.AnimState:PlayAnimation("idle", true)
    inst.spotlight.AnimState:SetMultColour(1, 0.9, 0.5, 1)
    inst.spotlight.entity:SetParent(inst.entity)
    inst.spotlight.Transform:SetPosition(0, 3, 0)

    -- Tags
    inst:AddTag("structure")
    inst:AddTag("lookouttower")
    inst:AddTag("inactive")  -- Required for activatable component to work

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Server state
    inst.scout_active = false
    inst.scout_player = nil
    inst.cooldown_until = nil

    -- Auto-name if not named by the biome spawner after a short delay
    inst:DoTaskInTime(2, function()
        if not inst.tower_display_name then
            local NameTower = rawget(_G, "MysteryBox_NameTower")
            if NameTower then
                local name = NameTower(inst, nil)
                print("[Lookout Tower] Auto-named: " .. name)
            end
        end
    end)

    -- Cooldown visual update
    inst:DoPeriodicTask(1, function()
        if inst.cooldown_until then
            local remaining = inst.cooldown_until - GetTime()
            if remaining > 0 then
                -- Red tint during cooldown
                inst.spotlight.AnimState:SetMultColour(1, 0.3, 0.3, 1)
            else
                -- Golden when ready
                inst.spotlight.AnimState:SetMultColour(1, 0.9, 0.5, 1)
                inst.cooldown_until = nil
            end
        end
    end)

    -- Components
    inst:AddComponent("inspectable")

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = OnActivate
    inst.components.activatable.quickaction = true

    return inst
end

return Prefab("lookouttower", fn, assets)
