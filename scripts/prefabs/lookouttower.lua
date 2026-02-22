-- Lookout Tower Prefab
-- A structure that enables Scout Mode for fast map exploration

require "prefabutil"

local assets = {
    Asset("ANIM", "anim/winona_spotlight.zip"),  -- Using spotlight tower as base
}

-- Scout mode constants
local SCOUT_SPEED = 50  -- 50x normal speed (~400 total)
local SCOUT_REVEAL_RADIUS = 30  -- Map reveal radius as player moves
local SCOUT_ZOOM_TARGET = 0.5  -- Zoom out factor (lower = more zoomed out)

-- Sound effects paths
local SOUNDS = {
    activate = "dontstarve/common/teleportato/teleportato_ready",
    ambient = "dontstarve/common/together/spot_light/spot_light_LP",
    drop_in = "dontstarve/common/teleportato/teleportato_pulled",
    whoosh = "dontstarve/common/teleportato/place_ring",
}

-- Enter scout mode
local function EnterScoutMode(inst, doer)
    if not doer or not doer:HasTag("player") then
        return false
    end

    -- Store original values
    doer._scout_original_speed = doer.components.locomotor.runspeed
    doer._scout_original_walkspeed = doer.components.locomotor.walkspeed
    doer._scout_original_pos = {doer.Transform:GetWorldPosition()}
    doer._scout_tower = inst

    -- Make invincible
    if doer.components.health then
        doer.components.health:SetInvincible(true)
    end

    -- Disable hunger/sanity drain
    if doer.components.hunger then
        doer._scout_hunger_rate = doer.components.hunger.hungerrate
        doer.components.hunger.hungerrate = 0
    end
    if doer.components.sanity then
        doer._scout_sanity_mode = doer.components.sanity.mode
        doer.components.sanity.mode = SANITY_MODE_INSANITY  -- Stop drain
    end

    -- Super speed
    doer.components.locomotor.runspeed = SCOUT_SPEED * 8
    doer.components.locomotor.walkspeed = SCOUT_SPEED * 8

    -- Visual: make mostly transparent (silhouette effect)
    doer.AnimState:SetMultColour(0.1, 0.1, 0.1, 0.3)

    -- Add scout tag for identification
    doer:AddTag("scouting")
    doer:AddTag("notarget")  -- Enemies ignore

    -- Disable combat
    if doer.components.combat then
        doer._scout_combat_enabled = true
        doer.components.combat:SetAttackPeriod(999999)
    end

    -- Start map reveal task
    doer._scout_reveal_task = doer:DoPeriodicTask(0.3, function()
        if doer.player_classified and doer.player_classified.MapExplorer then
            local x, y, z = doer.Transform:GetWorldPosition()
            doer.player_classified.MapExplorer:RevealArea(x, 0, z, SCOUT_REVEAL_RADIUS)
        end
    end)

    -- Play activation sound
    inst.SoundEmitter:PlaySound(SOUNDS.activate)
    inst.SoundEmitter:PlaySound(SOUNDS.whoosh)

    -- Announce
    if doer.components.talker then
        doer.components.talker:Say("Scout mode activated! Space to drop in.")
    end

    -- Play tower activation animation
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle_on", true)
    inst.SoundEmitter:PlaySound(SOUNDS.ambient, "loop")

    -- CLIENT-SIDE: Camera zoom and overlay (only for the local player)
    -- We'll trigger this via a net event that the client handles
    if doer.HUD then
        -- Create scout overlay widget
        local ScoutOverlay = require "widgets/scoutoverlay"
        doer._scout_overlay = doer.HUD.root:AddChild(ScoutOverlay(doer))

        -- Zoom out the camera
        if TheCamera then
            doer._scout_original_zoom = TheCamera.targetdistance or TheCamera.distance
            -- Use smooth zoom by setting target
            if TheCamera.SetDistance then
                TheCamera:SetDistance(doer._scout_original_zoom * 0.6)
            end
        end
    end

    -- Store state
    inst.scout_active = true
    inst.scout_player = doer

    print("[Lookout Tower] Scout mode ACTIVATED for " .. tostring(doer))
    return true
end

-- Exit scout mode (drop in at current location)
local function ExitScoutMode(doer, teleport_back)
    if not doer or not doer:HasTag("scouting") then
        return false
    end

    local tower = doer._scout_tower

    -- Stop map reveal task
    if doer._scout_reveal_task then
        doer._scout_reveal_task:Cancel()
        doer._scout_reveal_task = nil
    end

    -- Restore speed
    doer.components.locomotor.runspeed = doer._scout_original_speed or 8
    doer.components.locomotor.walkspeed = doer._scout_original_walkspeed or 4

    -- Restore health
    if doer.components.health then
        doer.components.health:SetInvincible(false)
    end

    -- Restore hunger/sanity
    if doer.components.hunger and doer._scout_hunger_rate then
        doer.components.hunger.hungerrate = doer._scout_hunger_rate
    end
    if doer.components.sanity and doer._scout_sanity_mode then
        doer.components.sanity.mode = doer._scout_sanity_mode
    end

    -- Restore combat
    if doer.components.combat and doer._scout_combat_enabled then
        doer.components.combat:SetAttackPeriod(0.5)
    end

    -- Restore visual
    doer.AnimState:SetMultColour(1, 1, 1, 1)

    -- Remove tags
    doer:RemoveTag("scouting")
    doer:RemoveTag("notarget")

    -- CLIENT-SIDE: Remove overlay and restore camera
    if doer._scout_overlay then
        doer._scout_overlay:Kill()
        doer._scout_overlay = nil
    end
    if doer._scout_original_zoom and TheCamera and TheCamera.SetDistance then
        TheCamera:SetDistance(doer._scout_original_zoom)
        doer._scout_original_zoom = nil
    end

    -- Play drop-in sound
    if doer.SoundEmitter then
        doer.SoundEmitter:PlaySound(SOUNDS.drop_in)
    end

    -- Teleport back to tower if requested
    if teleport_back and doer._scout_original_pos then
        doer.Transform:SetPosition(unpack(doer._scout_original_pos))
    end

    -- Clear stored values
    doer._scout_original_speed = nil
    doer._scout_original_walkspeed = nil
    doer._scout_original_pos = nil
    doer._scout_tower = nil
    doer._scout_hunger_rate = nil
    doer._scout_sanity_mode = nil
    doer._scout_combat_enabled = nil

    -- Announce
    if doer.components.talker then
        if teleport_back then
            doer.components.talker:Say("Returned to tower.")
        else
            doer.components.talker:Say("Dropped in!")
        end
    end

    -- Deactivate tower
    if tower and tower:IsValid() then
        tower.AnimState:PlayAnimation("idle_off", true)
        tower.SoundEmitter:KillSound("loop")
        tower.scout_active = false
        tower.scout_player = nil
    end

    print("[Lookout Tower] Scout mode DEACTIVATED for " .. tostring(doer))
    return true
end

-- When player activates the tower
local function OnActivate(inst, doer)
    if inst.scout_active then
        -- Tower already active - maybe by another player or re-clicking
        if inst.scout_player == doer then
            -- Same player, exit and return to tower
            ExitScoutMode(doer, true)
        else
            -- Different player or issue
            if doer.components.talker then
                doer.components.talker:Say("Tower is already in use!")
            end
        end
        return false
    end

    return EnterScoutMode(inst, doer)
end

-- Unlock the tower (called when chest opened in this branch)
local function UnlockTower(inst)
    if inst.is_locked then
        inst.is_locked = false
        inst.AnimState:SetMultColour(1, 0.9, 0.5, 1)  -- Golden
        inst.SoundEmitter:PlaySound("dontstarve/common/together/celestial_orb/active")
        print("[Lookout Tower] Tower UNLOCKED at branch " .. tostring(inst._branch_id))
    end
end

-- Prefab constructor
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    -- Physics - make it solid
    MakeObstaclePhysics(inst, 0.5)

    -- Use spotlight tower animation (tall structure)
    inst.AnimState:SetBank("winona_spotlight")
    inst.AnimState:SetBuild("winona_spotlight")
    inst.AnimState:PlayAnimation("idle_off", true)

    -- Golden tint to make it special (will be grey if locked)
    inst.AnimState:SetMultColour(1, 0.9, 0.5, 1)

    -- Tags
    inst:AddTag("structure")
    inst:AddTag("lookouttower")

    -- Minimap icon
    inst.MiniMapEntity:SetIcon("firepit.png")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- Server-side state
    inst.scout_active = false
    inst.scout_player = nil
    inst.is_locked = false  -- Crafted towers start unlocked
    inst._branch_id = nil   -- Set by auto-spawn system

    -- Unlock function (exposed for modmain to call)
    inst.Unlock = UnlockTower

    -- Components
    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = function(inst)
        if inst.is_locked then
            return "This tower is dormant. Open a Mystery Box in this area to activate it."
        end
        if inst.scout_active then
            return "The tower hums with energy... Someone is scouting."
        end
        return "A tall tower for surveying the land. Activate to enter scout mode."
    end

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = function(tower, doer)
        -- Check if locked
        if tower.is_locked then
            if doer.components.talker then
                doer.components.talker:Say("The tower is dormant... I need to find a chest first.")
            end
            return false
        end
        return OnActivate(tower, doer)
    end
    inst.components.activatable.quickaction = true

    -- Can be hammered
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(function(inst, worker)
        -- End scout mode if active
        if inst.scout_active and inst.scout_player then
            ExitScoutMode(inst.scout_player, true)
        end
        -- Drop materials
        local x, y, z = inst.Transform:GetWorldPosition()
        for i = 1, 3 do
            local boards = SpawnPrefab("boards")
            if boards then
                boards.Transform:SetPosition(x + math.random() - 0.5, 0, z + math.random() - 0.5)
            end
        end
        for i = 1, 2 do
            local gold = SpawnPrefab("goldnugget")
            if gold then
                gold.Transform:SetPosition(x + math.random() - 0.5, 0, z + math.random() - 0.5)
            end
        end
        inst:Remove()
    end)

    return inst
end

return Prefab("lookouttower", fn, assets)
