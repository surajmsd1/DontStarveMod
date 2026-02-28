-- Lookout Tower Prefab
-- A structure that enables Scout Mode for fast map exploration

require "prefabutil"

local assets = {
    Asset("ANIM", "anim/winona_spotlight.zip"),
}

-- Scout mode constants
local SCOUT_SPEED = 50  -- 50x normal speed (~400 total)
local SCOUT_REVEAL_RADIUS = 30  -- Map reveal radius as player moves

-- Sound effects paths
local SOUNDS = {
    activate = "dontstarve/common/teleportato/teleportato_ready",
    ambient = "dontstarve/common/together/spot_light/spot_light_LP",
    drop_in = "dontstarve/common/teleportato/teleportato_pulled",
    whoosh = "dontstarve/common/teleportato/place_ring",
    unlock = "dontstarve/common/together/celestial_orb/active",
}

-- Forward declarations
local ExitScoutMode
local ForceReleaseScoutMode

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
        doer.components.sanity.mode = SANITY_MODE_INSANITY
    end

    -- Super speed
    doer.components.locomotor.runspeed = SCOUT_SPEED * 8
    doer.components.locomotor.walkspeed = SCOUT_SPEED * 8

    -- Visual: make mostly transparent (silhouette effect)
    doer.AnimState:SetMultColour(0.1, 0.1, 0.1, 0.3)

    -- Add scout tag for identification
    doer:AddTag("scouting")
    doer:AddTag("notarget")

    -- Disable combat
    if doer.components.combat then
        doer._scout_combat_enabled = true
        doer.components.combat:SetAttackPeriod(999999)
    end

    -- Start map reveal task
    doer._scout_reveal_task = doer:DoPeriodicTask(0.3, function()
        if doer:IsValid() and doer.player_classified and doer.player_classified.MapExplorer then
            local x, y, z = doer.Transform:GetWorldPosition()
            doer.player_classified.MapExplorer:RevealArea(x, 0, z, SCOUT_REVEAL_RADIUS)
        end
    end)

    -- CLEANUP HANDLER: Player death while scouting
    doer._scout_death_handler = function(player)
        print("[Lookout Tower] Scouting player died, cleaning up...")
        ExitScoutMode(doer, true)
    end
    doer:ListenForEvent("death", doer._scout_death_handler)

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
    if doer.HUD then
        local ScoutOverlay = require "widgets/scoutoverlay"
        doer._scout_overlay = doer.HUD.root:AddChild(ScoutOverlay(doer))

        if TheCamera then
            doer._scout_original_zoom = TheCamera.targetdistance or TheCamera.distance
            if TheCamera.SetDistance then
                TheCamera:SetDistance(doer._scout_original_zoom * 0.6)
            end
        end
    end

    -- Store state (server-side)
    inst.scout_player = doer

    -- Set network-synced state
    inst._net_scout_active:set(true)

    print("[Lookout Tower] Scout mode ACTIVATED for " .. tostring(doer))
    return true
end

-- Exit scout mode (drop in at current location)
ExitScoutMode = function(doer, teleport_back)
    if not doer or not doer:HasTag("scouting") then
        return false
    end

    local tower = doer._scout_tower

    -- Stop map reveal task
    if doer._scout_reveal_task then
        doer._scout_reveal_task:Cancel()
        doer._scout_reveal_task = nil
    end

    -- Remove death listener
    if doer._scout_death_handler then
        doer:RemoveEventCallback("death", doer._scout_death_handler)
        doer._scout_death_handler = nil
    end

    -- Restore speed
    if doer.components and doer.components.locomotor then
        doer.components.locomotor.runspeed = doer._scout_original_speed or 8
        doer.components.locomotor.walkspeed = doer._scout_original_walkspeed or 4
    end

    -- Restore health
    if doer.components and doer.components.health then
        doer.components.health:SetInvincible(false)
    end

    -- Restore hunger/sanity
    if doer.components and doer.components.hunger and doer._scout_hunger_rate then
        doer.components.hunger.hungerrate = doer._scout_hunger_rate
    end
    if doer.components and doer.components.sanity and doer._scout_sanity_mode then
        doer.components.sanity.mode = doer._scout_sanity_mode
    end

    -- Restore combat
    if doer.components and doer.components.combat and doer._scout_combat_enabled then
        doer.components.combat:SetAttackPeriod(0.5)
    end

    -- Restore visual
    if doer.AnimState then
        doer.AnimState:SetMultColour(1, 1, 1, 1)
    end

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
    if doer.components and doer.components.talker then
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
        tower.scout_player = nil
        tower._net_scout_active:set(false)
    end

    print("[Lookout Tower] Scout mode DEACTIVATED for " .. tostring(doer))
    return true
end

-- Force release scout mode (for disconnect/removal)
ForceReleaseScoutMode = function(inst)
    local player = inst.scout_player

    if player and player:IsValid() then
        ExitScoutMode(player, true)
    else
        -- Player already gone, just reset tower state
        inst.AnimState:PlayAnimation("idle_off", true)
        inst.SoundEmitter:KillSound("loop")
        inst.scout_player = nil
        inst._net_scout_active:set(false)
        print("[Lookout Tower] Force released (player gone)")
    end
end

-- Open tower teleport menu (client-side)
local function OpenTeleportMenu(inst, doer)
    if not doer.HUD then return end

    -- Get unlocked towers from global function
    local GetUnlockedTowers = rawget(_G, "MysteryBoxGetUnlockedTowers")
    local TeleportToTower = rawget(_G, "MysteryBoxTeleportToTower")

    if not GetUnlockedTowers or not TeleportToTower then
        print("[Lookout Tower] ERROR: Teleport functions not available")
        return
    end

    local towers = GetUnlockedTowers(inst)

    if #towers < 2 then
        if doer.components.talker then
            doer.components.talker:Say("No other towers unlocked yet!")
        end
        return
    end

    -- Create and show the selection UI
    local TowerSelect = require "widgets/towerselect"
    doer._tower_select_ui = doer.HUD.root:AddChild(TowerSelect(
        doer,
        towers,
        function(selected)  -- On select callback
            if selected and selected.tower then
                TeleportToTower(doer, selected.tower)
            end
            doer._tower_select_ui = nil
        end,
        function()  -- On cancel callback
            doer._tower_select_ui = nil
        end
    ))
end

-- When player activates the tower
local function OnActivate(inst, doer)
    -- Use network-synced state for check
    if inst._net_scout_active:value() then
        if inst.scout_player == doer then
            ExitScoutMode(doer, true)
        else
            if doer.components.talker then
                doer.components.talker:Say("Tower is already in use!")
            end
        end
        return false
    end

    -- Check if player is holding SHIFT for teleport menu
    if TheInput:IsKeyDown(KEY_SHIFT) then
        OpenTeleportMenu(inst, doer)
        return true
    end

    return EnterScoutMode(inst, doer)
end

-- Unlock the tower (called when chest opened in this branch)
local function UnlockTower(inst)
    if inst._net_is_locked:value() then
        inst._net_is_locked:set(false)
        inst.SoundEmitter:PlaySound(SOUNDS.unlock)
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

    -- Default golden tint (will change based on network state)
    inst.AnimState:SetMultColour(1, 0.9, 0.5, 1)

    -- Tags
    inst:AddTag("structure")
    inst:AddTag("lookouttower")

    -- Minimap icon
    inst.MiniMapEntity:SetIcon("firepit.png")

    -- NETWORK VARIABLES (before SetPristine)
    inst._net_scout_active = net_bool(inst.GUID, "lookouttower.scout_active", "scoutactivedirty")
    inst._net_is_locked = net_bool(inst.GUID, "lookouttower.is_locked", "islockeddirty")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        -- CLIENT: Apply initial state after short delay (for late joiners)
        inst:DoTaskInTime(0, function()
            if inst._net_is_locked:value() then
                inst.AnimState:SetMultColour(0.4, 0.4, 0.4, 1)
            else
                inst.AnimState:SetMultColour(1, 0.9, 0.5, 1)
            end

            if inst._net_scout_active:value() then
                inst.AnimState:PlayAnimation("idle_on", true)
            end
        end)

        -- CLIENT: React to scout active changes
        inst:ListenForEvent("scoutactivedirty", function()
            if inst._net_scout_active:value() then
                inst.AnimState:PlayAnimation("place")
                inst.AnimState:PushAnimation("idle_on", true)
            else
                inst.AnimState:PlayAnimation("idle_off", true)
            end
        end)

        -- CLIENT: React to locked state changes
        inst:ListenForEvent("islockeddirty", function()
            if inst._net_is_locked:value() then
                inst.AnimState:SetMultColour(0.4, 0.4, 0.4, 1)
            else
                inst.AnimState:SetMultColour(1, 0.9, 0.5, 1)
                inst.SoundEmitter:PlaySound(SOUNDS.unlock)
            end
        end)

        return inst
    end

    -- SERVER SIDE --

    -- Server-side state
    inst.scout_player = nil
    inst._branch_id = nil

    -- Initialize network state
    inst._net_scout_active:set(false)
    inst._net_is_locked:set(false)  -- Crafted towers start unlocked

    -- Unlock function (exposed for modmain to call)
    inst.Unlock = UnlockTower

    -- Set locked state (for auto-spawned towers)
    inst.SetLocked = function(self, locked)
        self._net_is_locked:set(locked)
    end

    -- CLEANUP: Listen for player disconnect
    inst._disconnect_handler = function(world, player)
        if inst.scout_player and inst.scout_player == player then
            print("[Lookout Tower] Scouting player disconnected")
            ForceReleaseScoutMode(inst)
        end
    end
    TheWorld:ListenForEvent("ms_playerleft", inst._disconnect_handler)

    -- Clean up disconnect listener when tower is removed
    inst:ListenForEvent("onremove", function()
        if inst._disconnect_handler then
            TheWorld:RemoveEventCallback("ms_playerleft", inst._disconnect_handler)
        end
        -- Also release scout mode if someone was using it
        if inst.scout_player and inst.scout_player:IsValid() then
            ExitScoutMode(inst.scout_player, true)
        end
    end)

    -- Components
    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = function(tower)
        if tower._net_is_locked:value() then
            return "This tower is dormant. Open a Mystery Box in this area to activate it."
        end
        if tower._net_scout_active:value() then
            return "The tower hums with energy... Someone is scouting."
        end
        return "Activate to scout. Hold SHIFT + activate to teleport to another tower."
    end

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = function(tower, doer)
        if tower._net_is_locked:value() then
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
    inst.components.workable:SetOnFinishCallback(function(tower, worker)
        -- End scout mode if active
        if tower._net_scout_active:value() and tower.scout_player then
            ExitScoutMode(tower.scout_player, true)
        end
        -- Drop materials
        local x, y, z = tower.Transform:GetWorldPosition()
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
        tower:Remove()
    end)

    return inst
end

return Prefab("lookouttower", fn, assets)
