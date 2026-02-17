-- Golden Mystery Box Prefab
-- A blessed box that guarantees reward/social events only - no danger!

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
    inst.SoundEmitter:PlaySound("dontstarve/common/chest_open")
    inst.SoundEmitter:PlaySound("dontstarve/common/together/chest_retune_open")

    -- Trigger golden box event through event manager
    if rawget(_G, "MysteryBoxEventManager") then
        _G.MysteryBoxEventManager:TriggerBoxEvent("golden", doer)
    end

    if doer and doer.components and doer.components.talker then
        doer.components.talker:Say("It's glowing with good fortune!")
    end

    inst:DoTaskInTime(3.0, function()
        local x, y, z = inst.Transform:GetWorldPosition()
        local bonusLoot = {"goldnugget", "goldnugget", "goldnugget", "silk", "honey"}
        for _, item in ipairs(bonusLoot) do
            local loot = SpawnPrefab(item)
            if loot then
                local angle = math.random() * 2 * math.pi
                loot.Transform:SetPosition(x + math.cos(angle) * 2, 0, z + math.sin(angle) * 2)
                if loot.Physics then
                    loot.Physics:SetVel(math.cos(angle) * 3, 5, math.sin(angle) * 3)
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

    inst.AnimState:SetBank("chest")
    inst.AnimState:SetBuild("treasure_chest")
    inst.AnimState:PlayAnimation("closed")
    inst.AnimState:SetMultColour(1, 0.9, 0.3, 1)

    inst:AddTag("structure")
    inst:AddTag("goldenbox")

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

return Prefab("goldenbox", fn, assets)
