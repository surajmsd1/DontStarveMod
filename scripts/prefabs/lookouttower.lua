-- Lookout Tower Prefab
-- Activate for scout mode: super speed + map reveal

require "prefabutil"

local assets = {
    Asset("ANIM", "anim/pig_house.zip"),
    Asset("ANIM", "anim/winona_spotlight.zip"),
}

local SCOUT_SPEED = 35  -- Reduced for better control
local SCOUT_REVEAL_RADIUS = 30

local function EnterScoutMode(inst, doer)
    if not doer or not doer:HasTag("player") then
        return false
    end

    -- Store originals
    doer._scout_original_speed = doer.components.locomotor.runspeed
    doer._scout_tower = inst

    -- Super speed (normal is ~6, this is ~6x faster)
    doer.components.locomotor.runspeed = SCOUT_SPEED
    doer.components.locomotor.walkspeed = SCOUT_SPEED

    -- Make transparent
    doer.AnimState:SetMultColour(0.3, 0.3, 0.3, 0.5)

    -- Add tag
    doer:AddTag("scouting")

    -- Exit on interaction (pickup, attack, etc)
    doer._scout_pickup_listener = function() ExitScoutMode(doer, false) end
    doer:ListenForEvent("itemget", doer._scout_pickup_listener)
    doer:ListenForEvent("performaction", doer._scout_pickup_listener)

    -- Trigger overlay on client
    if doer.HUD then
        doer:PushEvent("enterscoutmode")
    end

    -- Map reveal
    doer._scout_reveal_task = doer:DoPeriodicTask(0.3, function()
        if doer.player_classified and doer.player_classified.MapExplorer then
            local x, y, z = doer.Transform:GetWorldPosition()
            doer.player_classified.MapExplorer:RevealArea(x, 0, z, SCOUT_REVEAL_RADIUS)
        end
    end)

    if doer.components.talker then
        doer.components.talker:Say("Scout mode! SPACE to drop in.")
    end

    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("idle", true)
    inst.scout_active = true
    inst.scout_player = doer

    print("[Lookout Tower] Scout mode ON")
    return true
end

local function ExitScoutMode(doer, teleport_back)
    if not doer or not doer:HasTag("scouting") then
        return false
    end

    local tower = doer._scout_tower

    if doer._scout_reveal_task then
        doer._scout_reveal_task:Cancel()
        doer._scout_reveal_task = nil
    end

    -- Remove event listeners
    if doer._scout_pickup_listener then
        doer:RemoveEventCallback("itemget", doer._scout_pickup_listener)
        doer:RemoveEventCallback("performaction", doer._scout_pickup_listener)
        doer._scout_pickup_listener = nil
    end

    -- Trigger overlay removal on client
    if doer.HUD then
        doer:PushEvent("exitscoutmode")
    end

    doer.components.locomotor.runspeed = doer._scout_original_speed or 8
    doer.components.locomotor.walkspeed = 4
    doer.AnimState:SetMultColour(1, 1, 1, 1)
    doer:RemoveTag("scouting")

    if doer.components.talker then
        doer.components.talker:Say("Dropped in!")
    end

    if tower and tower:IsValid() then
        tower.AnimState:PlayAnimation("idle")
        tower.scout_active = false
        tower.scout_player = nil
        -- Re-enable activation
        if tower.components.activatable then
            tower.components.activatable.inactive = false
        end
    end

    doer._scout_original_speed = nil
    doer._scout_tower = nil

    print("[Lookout Tower] Scout mode OFF")
    return true
end

-- Global for SPACE key (stored on _G in prefab context)
rawset(_G, "LookoutTowerExitScout", ExitScoutMode)

local function OnActivate(inst, doer)
    if inst.scout_active then
        if inst.scout_player == doer then
            ExitScoutMode(doer, true)
        end
    else
        EnterScoutMode(inst, doer)
    end
    -- Always return false so it stays activatable
    return false
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    -- Use pig house as base
    inst.AnimState:SetBank("pig_house")
    inst.AnimState:SetBuild("pig_house")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetMultColour(0.7, 0.9, 1, 1)  -- Light blue tint

    -- Add spotlight decoration on top
    inst.spotlight = CreateEntity()
    inst.spotlight.entity:AddTransform()
    inst.spotlight.entity:AddAnimState()
    inst.spotlight.AnimState:SetBank("winona_spotlight")
    inst.spotlight.AnimState:SetBuild("winona_spotlight")
    inst.spotlight.AnimState:PlayAnimation("idle", true)
    inst.spotlight.AnimState:SetMultColour(1, 0.9, 0.5, 1)  -- Golden
    inst.spotlight.entity:SetParent(inst.entity)
    inst.spotlight.Transform:SetPosition(0, 3, 0)  -- Offset up

    inst:AddTag("structure")
    inst:AddTag("lookouttower")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scout_active = false
    inst.scout_player = nil

    inst:AddComponent("inspectable")

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = OnActivate
    inst.components.activatable.quickaction = true

    print("[Lookout Tower] SPAWNED!")
    return inst
end

return Prefab("lookouttower", fn, assets)
