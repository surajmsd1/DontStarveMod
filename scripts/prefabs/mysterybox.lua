-- Mystery Box Prefab
-- A placeable box that gives random rewards when activated

require "prefabutil"

local assets = {
    Asset("ANIM", "anim/treasure_chest.zip"),
}

-- Loot table with weighted rewards
local LOOT_TABLE = {
    -- Common items (weight 10)
    {"log", 10},
    {"rocks", 10},
    {"cutgrass", 10},
    {"twigs", 10},
    {"flint", 10},
    -- Uncommon items (weight 5)
    {"goldnugget", 5},
    {"silk", 5},
    {"rope", 5},
    {"boards", 5},
    {"cutstone", 5},
    -- Rare items (weight 2)
    {"gears", 2},
    {"redgem", 2},
    {"bluegem", 2},
    {"livinglog", 2},
    {"purplegem", 2},
    -- Very rare items (weight 1)
    {"greengem", 1},
    {"orangegem", 1},
    {"yellowgem", 1},
    {"thulecite", 1},
}

local function GetTotalWeight()
    local total = 0
    for _, entry in ipairs(LOOT_TABLE) do
        total = total + entry[2]
    end
    return total
end

local function SelectRandomReward()
    local total_weight = GetTotalWeight()
    local roll = math.random() * total_weight
    local cumulative = 0
    for _, entry in ipairs(LOOT_TABLE) do
        cumulative = cumulative + entry[2]
        if roll <= cumulative then
            return entry[1]
        end
    end
    return "log"
end

local function OnActivate(inst, doer)
    if inst.opened then
        return false
    end
    inst.opened = true
    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound("dontstarve/common/chest_open")

    local reward_prefab = SelectRandomReward()
    local reward = SpawnPrefab(reward_prefab)
    if reward then
        local x, y, z = inst.Transform:GetWorldPosition()
        reward.Transform:SetPosition(x, y + 0.5, z)
        if reward.Physics then
            local angle = math.random() * 2 * math.pi
            local speed = 2 + math.random() * 2
            reward.Physics:SetVel(speed * math.cos(angle), 5, speed * math.sin(angle))
        end
        print("[Mystery Box] Player " .. (doer.name or "unknown") .. " received: " .. reward_prefab)
        if doer and doer.components and doer.components.talker then
            doer.components.talker:Say("I got " .. reward_prefab .. "!")
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

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.opened = false

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
