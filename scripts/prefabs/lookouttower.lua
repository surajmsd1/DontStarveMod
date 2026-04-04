-- Lookout Tower Prefab (SIMPLIFIED)
-- Click to enter scout mode: fast movement + map reveal
-- SPACE to drop in, or go too far, or interact with anything

require "prefabutil"

local assets = {
    Asset("ANIM", "anim/pig_house.zip"),
    Asset("ANIM", "anim/winona_spotlight.zip"),
}

-- Constants
local SCOUT_SPEED = 35
local SCOUT_REVEAL_RADIUS = 30
local SCOUT_MAX_DISTANCE = 150

-- =============================================================================
-- ENTER SCOUT MODE (runs on server)
-- =============================================================================
local function EnterScoutMode(inst, doer)
    if not doer or not doer:HasTag("player") then
        return false
    end

    print("[Lookout Tower] Entering scout mode")

    -- Store original speed
    doer._scout_original_speed = doer.components.locomotor.runspeed
    doer._scout_tower = inst

    -- Store tower position for distance check
    local tx, ty, tz = inst.Transform:GetWorldPosition()
    doer._scout_tower_pos = {x = tx, z = tz}

    -- Apply scout speed
    doer.components.locomotor.runspeed = SCOUT_SPEED
    doer.components.locomotor.walkspeed = SCOUT_SPEED

    -- Make semi-transparent
    doer.AnimState:SetMultColour(0.3, 0.3, 0.3, 0.5)

    -- Add tag (this syncs to client and triggers overlay)
    doer:AddTag("scouting")

    -- Get the exit function from modmain
    local ExitScoutMode = rawget(_G, "MysteryBox_ExitScoutMode")

    -- Single periodic task: reveal map + check distance + check interactions
    doer._scout_task = doer:DoPeriodicTask(0.2, function()
        if not doer:HasTag("scouting") then
            return  -- Already exited
        end

        local x, y, z = doer.Transform:GetWorldPosition()

        -- Reveal map
        if doer.player_classified and doer.player_classified.MapExplorer then
            doer.player_classified.MapExplorer:RevealArea(x, 0, z, SCOUT_REVEAL_RADIUS)
        end

        -- Check distance from tower
        if doer._scout_tower_pos then
            local dx = x - doer._scout_tower_pos.x
            local dz = z - doer._scout_tower_pos.z
            local dist = math.sqrt(dx * dx + dz * dz)

            -- Force drop-in if too far
            if dist >= SCOUT_MAX_DISTANCE then
                if ExitScoutMode then
                    ExitScoutMode(doer, "Too far! Dropping in!")
                end
            end
        end
    end)

    -- Exit on any interaction (pickup, attack, chop, etc)
    -- Store the listener so we can remove it later
    doer._scout_action_listener = function(player, data)
        -- Ignore if it's activating a lookout tower (that's how we exit intentionally)
        if data and data.action and data.action.action == GLOBAL.ACTIONS.ACTIVATE then
            local target = data.action.target
            if target and target:HasTag("lookouttower") then
                return  -- Don't exit for tower clicks
            end
        end
        if doer:HasTag("scouting") and ExitScoutMode then
            ExitScoutMode(doer, "Dropped in!")
        end
    end
    doer:ListenForEvent("performaction", doer._scout_action_listener)

    -- Tell player the controls
    if doer.components.talker then
        doer.components.talker:Say("Scout mode! SPACE to drop in.")
    end

    -- Mark tower as in use
    inst.scout_active = true
    inst.scout_player = doer

    print("[Lookout Tower] Scout mode ON")
    return true
end

-- =============================================================================
-- TOWER ACTIVATION (click handler)
-- =============================================================================
local function OnActivate(inst, doer)
    print("[Lookout Tower] OnActivate called - scout_active=" .. tostring(inst.scout_active))
    if inst.scout_active then
        -- Already scouting - clicking tower exits
        local ExitScoutMode = rawget(_G, "MysteryBox_ExitScoutMode")
        if ExitScoutMode and inst.scout_player then
            ExitScoutMode(inst.scout_player, "Dropped in!")
        end
    else
        -- Start scouting
        EnterScoutMode(inst, doer)
    end

    -- Force re-enable after a tiny delay
    inst:DoTaskInTime(0.1, function()
        if inst.components.activatable then
            inst.components.activatable.inactive = false
            print("[Lookout Tower] Re-enabled activatable")
        end
    end)

    return false  -- Keep tower activatable
end

-- =============================================================================
-- PREFAB DEFINITION
-- =============================================================================
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    -- Map icon
    inst.MiniMapEntity:SetIcon("winona_spotlight.png")
    inst.MiniMapEntity:SetPriority(5)

    -- Visual: pig house with blue tint
    inst.AnimState:SetBank("pig_house")
    inst.AnimState:SetBuild("pig_house")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetMultColour(0.7, 0.9, 1, 1)

    -- Spotlight on top
    inst.spotlight = CreateEntity()
    inst.spotlight.entity:AddTransform()
    inst.spotlight.entity:AddAnimState()
    inst.spotlight.AnimState:SetBank("winona_spotlight")
    inst.spotlight.AnimState:SetBuild("winona_spotlight")
    inst.spotlight.AnimState:PlayAnimation("idle", true)
    inst.spotlight.AnimState:SetMultColour(1, 0.9, 0.5, 1)
    inst.spotlight.entity:SetParent(inst.entity)
    inst.spotlight.Transform:SetPosition(0, 3, 0)

    inst:AddTag("structure")
    inst:AddTag("lookouttower")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Server-only state
    inst.scout_active = false
    inst.scout_player = nil

    inst:AddComponent("inspectable")

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = OnActivate
    inst.components.activatable.quickaction = true
    inst.components.activatable.standingaction = true  -- Can activate while standing
    inst.components.activatable.inactive = false

    -- Always allow activation
    inst.components.activatable.CanActivate = function()
        return true
    end

    print("[Lookout Tower] Spawned")
    return inst
end

return Prefab("lookouttower", fn, assets)
