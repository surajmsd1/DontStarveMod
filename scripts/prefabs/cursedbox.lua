-- Cursed Mystery Box Prefab
-- A dangerous box that guarantees challenge/danger events but with better rewards

require "prefabutil"

local assets = {
    Asset("ANIM", "anim/treasure_chest.zip"),
}

local function OnActivate(inst, doer)
    if inst.opened then
        return false
    end
    inst.opened = true

    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound("dontstarve/common/nightmareportal_1")

    -- Trigger cursed box event through event manager
    if rawget(_G, "MysteryBoxEventManager") then
        _G.MysteryBoxEventManager:TriggerBoxEvent("cursed", doer)
    end

    if doer and doer.components and doer.components.talker then
        doer.components.talker:Say("This feels... dangerous!")
    end

    inst:DoTaskInTime(3.0, function()
        local x, y, z = inst.Transform:GetWorldPosition()
        local bonusLoot = {"goldnugget", "goldnugget", "purplegem"}
        for _, item in ipairs(bonusLoot) do
            local loot = SpawnPrefab(item)
            if loot then
                local angle = math.random() * 2 * math.pi
                loot.Transform:SetPosition(x + math.cos(angle) * 2, 0, z + math.sin(angle) * 2)
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

    inst.AnimState:SetBank("chest")
    inst.AnimState:SetBuild("treasure_chest")
    inst.AnimState:PlayAnimation("closed")
    inst.AnimState:SetMultColour(0.5, 0.2, 0.5, 1)

    inst:AddTag("structure")
    inst:AddTag("cursedbox")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.opened = false

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
