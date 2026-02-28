-- Mystery Box Prefab
-- A placeable box that gives random rewards when activated

require "prefabutil"

-- Try to load the LootSystem (safe require)
local LootSystem = nil
local ok, result = pcall(function() return require "core/loot_system" end)
if ok then
    LootSystem = result
    print("[Mystery Box] LootSystem loaded")
else
    print("[Mystery Box] LootSystem not found, using fallback")
end

local assets = {}

local function OnActivate(inst, doer)
    -- Use network-synced state
    if inst._opened:value() then
        return false
    end
    inst._opened:set(true)
    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound("dontstarve/common/chest_open")

    local x, y, z = inst.Transform:GetWorldPosition()

    -- Use LootSystem if available, otherwise fallback
    if LootSystem then
        LootSystem.DropPack("starter_kit", x, y, z, {radius = 3, velocity = 5})
        if doer and doer.components and doer.components.talker then
            doer.components.talker:Say("Loot!")
        end
    else
        -- Fallback: spawn a single goldnugget
        local reward = SpawnPrefab("goldnugget")
        if reward then
            reward.Transform:SetPosition(x, y + 0.5, z)
            if reward.Physics then
                reward.Physics:SetVel(0, 5, 0)
            end
        end
    end

    inst:DoTaskInTime(1.0, function()
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

    inst.AnimState:SetBank("chest")
    inst.AnimState:SetBuild("treasure_chest")
    inst.AnimState:PlayAnimation("closed")

    inst:AddTag("structure")
    inst:AddTag("mysterybox")

    -- Network sync for opened state
    inst._opened = net_bool(inst.GUID, "mysterybox.opened", "openeddirty")

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

    inst:AddComponent("lootdropper")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "treasurechest"
    inst.components.inventoryitem.atlasname = "images/inventoryimages.xml"

    return inst
end

return Prefab("mysterybox", fn, assets)
