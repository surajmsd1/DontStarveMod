-- Cursed Mystery Box Prefab
-- A dangerous box that guarantees challenge/danger events but with better rewards

require "prefabutil"

-- Try to load the LootSystem (safe require)
local LootSystem = nil
local ok, result = pcall(function() return require "core/loot_system" end)
if ok then LootSystem = result end

local assets = {}

local function OnActivate(inst, doer)
    -- Use network-synced state
    if inst._opened:value() then
        return false
    end
    inst._opened:set(true)

    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound("dontstarve/common/nightmareportal_1")

    -- Trigger cursed box event through event manager (spawns enemies)
    if rawget(_G, "MysteryBoxEventManager") then
        _G.MysteryBoxEventManager:TriggerBoxEvent("cursed", doer)
    end


    if doer and doer.components and doer.components.talker then
        doer.components.talker:Say("This feels... dangerous!")
    end

    -- Start Day One objective
    print("[Cursed Box] Checking for StartDayOneObjective...")
    if rawget(_G, "StartDayOneObjective") then
        print("[Cursed Box] Found! Calling StartDayOneObjective")
        _G.StartDayOneObjective(doer)
    else
        print("[Cursed Box] StartDayOneObjective NOT FOUND in _G")
    end

    -- Drop loot after delay
    inst:DoTaskInTime(3.0, function()
        local x, y, z = inst.Transform:GetWorldPosition()
        if LootSystem then
            LootSystem.DropPack("cursed_box", x, y, z, {radius = 3, velocity = 5})
        else
            -- Fallback
            for _, item in ipairs({"goldnugget", "goldnugget", "purplegem"}) do
                local loot = SpawnPrefab(item)
                if loot then
                    local angle = math.random() * 2 * math.pi
                    loot.Transform:SetPosition(x + math.cos(angle) * 2, 0, z + math.sin(angle) * 2)
                end
            end
        end
        inst:Remove()
    end)

    return true
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    -- Use Pandora's chest (ruins style) for cursed boxes
    inst.AnimState:SetBank("pandoras_chest")
    inst.AnimState:SetBuild("pandoras_chest")
    inst.AnimState:PlayAnimation("closed")
    -- Purple tint for cursed
    inst.AnimState:SetMultColour(0.7, 0.3, 0.7, 1)

    inst:AddTag("structure")
    inst:AddTag("cursedbox")

    -- Network sync for opened state
    inst._opened = net_bool(inst.GUID, "cursedbox.opened", "openeddirty")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        -- CLIENT: animate when opened
        inst:ListenForEvent("openeddirty", function()
            if inst._opened:value() then
                inst.AnimState:PlayAnimation("open")
            end
        end)
        return inst
    end

    -- SERVER: initialize state
    inst._opened:set(false)

    inst:AddComponent("inspectable")

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = OnActivate
    inst.components.activatable.quickaction = true

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "treasurechest"
    inst.components.inventoryitem.atlasname = "images/inventoryimages.xml"

    return inst
end

return Prefab("cursedbox", fn, assets)
