-- Golden Mystery Box Prefab
-- A blessed box that guarantees reward/social events only - no danger!

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
    inst.SoundEmitter:PlaySound("dontstarve/common/chest_open")
    inst.SoundEmitter:PlaySound("dontstarve/common/together/chest_retune_open")

    -- Trigger golden box event through event manager (spawns friendly stuff)
    if rawget(_G, "MysteryBoxEventManager") then
        _G.MysteryBoxEventManager:TriggerBoxEvent("golden", doer)
    end


    if doer and doer.components and doer.components.talker then
        doer.components.talker:Say("It's glowing with good fortune!")
    end

    -- Drop loot after delay
    inst:DoTaskInTime(3.0, function()
        local x, y, z = inst.Transform:GetWorldPosition()
        if LootSystem then
            LootSystem.DropPack("golden_box", x, y, z, {radius = 3, velocity = 5})
        else
            -- Fallback
            for _, item in ipairs({"goldnugget", "goldnugget", "goldnugget", "silk", "honey"}) do
                local loot = SpawnPrefab(item)
                if loot then
                    local angle = math.random() * 2 * math.pi
                    loot.Transform:SetPosition(x + math.cos(angle) * 2, 0, z + math.sin(angle) * 2)
                    if loot.Physics then
                        loot.Physics:SetVel(math.cos(angle) * 3, 5, math.sin(angle) * 3)
                    end
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

    -- Use gift box visual for golden boxes
    inst.AnimState:SetBank("gift")
    inst.AnimState:SetBuild("gift")
    inst.AnimState:PlayAnimation("idle")
    -- Golden shimmer
    inst.AnimState:SetMultColour(1, 0.95, 0.5, 1)

    inst:AddTag("structure")
    inst:AddTag("goldenbox")

    -- Network sync for opened state
    inst._opened = net_bool(inst.GUID, "goldenbox.opened", "openeddirty")

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

return Prefab("goldenbox", fn, assets)
