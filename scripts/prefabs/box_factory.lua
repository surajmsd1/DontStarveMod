-- Mystery Box Mod - Box Factory
-- Factory pattern for creating box prefabs with shared behavior

require "prefabutil"

local BoxFactory = {}

-- =============================================================================
-- BOX VISUAL PRESETS
-- Different visual styles using existing DST animations
-- =============================================================================
BoxFactory.VISUALS = {
    -- Standard treasure chest (default)
    treasure = {
        bank = "chest",
        build = "treasure_chest",
        anim_closed = "closed",
        anim_open = "open",
        anim_file = "anim/treasure_chest.zip",
    },
    -- Pandora's/Ornate chest (ruins style - purple/fancy)
    pandora = {
        bank = "pandoras_chest",
        build = "pandoras_chest",
        anim_closed = "closed",
        anim_open = "open",
        anim_file = "anim/pandoras_chest.zip",
    },
    -- Gift box (present style)
    gift = {
        bank = "gift",
        build = "gift",
        anim_closed = "idle",
        anim_open = "open",
        anim_file = "anim/gift.zip",
    },
    -- Scaled/Dragonfly chest
    scaled = {
        bank = "dragonfly_chest",
        build = "dragonfly_chest",
        anim_closed = "closed",
        anim_open = "open",
        anim_file = "anim/dragonfly_chest.zip",
    },
    -- Hutch (walking chest - just for fun)
    hutch = {
        bank = "hutch",
        build = "hutch",
        anim_closed = "idle_loop",
        anim_open = "open",
        anim_file = "anim/hutch.zip",
    },
}

-- Default configuration for all boxes
local DEFAULTS = {
    bank = "chest",
    build = "treasure_chest",
    anim_closed = "closed",
    anim_open = "open",
    icon = "chest.png",
    open_sound = "dontstarve/common/chest_open",
    remove_delay = 1.0,
}

-- Create a box prefab with the given configuration
-- config = {
--   name: string (prefab name)
--   tag: string (identifying tag)
--   visual: string (key from VISUALS table) or nil for default
--   tint: {r, g, b, a} or nil
--   boxType: "normal" | "cursed" | "golden" (for event manager)
--   openSound: string (sound path)
--   bonusLoot: table of prefab names or nil
--   bonusDelay: number (seconds before bonus loot)
--   message: string (talker message)
--   onActivateCustom: function(inst, doer) or nil (for custom logic like mysterybox)
-- }
function BoxFactory.Create(config)
    -- Get visual preset if specified
    local visual = config.visual and BoxFactory.VISUALS[config.visual] or nil

    local assets = {
        Asset("ANIM", visual and visual.anim_file or "anim/treasure_chest.zip"),
    }

    local function fn()
        local inst = CreateEntity()

        -- Standard entity setup
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        -- Animation setup (use visual preset if available)
        local bank = (visual and visual.bank) or config.bank or DEFAULTS.bank
        local build = (visual and visual.build) or config.build or DEFAULTS.build
        local anim_closed = (visual and visual.anim_closed) or config.anim_closed or DEFAULTS.anim_closed

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim_closed)

        -- Color tint
        if config.tint then
            inst.AnimState:SetMultColour(config.tint[1], config.tint[2], config.tint[3], config.tint[4] or 1)
        end

        -- Minimap (always visible)
        inst.MiniMapEntity:SetIcon(config.icon or DEFAULTS.icon)
        inst.MiniMapEntity:SetPriority(10)

        -- Tags
        inst:AddTag("structure")
        inst:AddTag(config.tag or config.name)

        -- NETWORK VARIABLE: Sync opened state to all clients
        inst._opened = net_bool(inst.GUID, config.name .. ".opened", "openeddirty")

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            -- CLIENT: Listen for state changes to update animation
            local anim_open = (visual and visual.anim_open) or config.anim_open or DEFAULTS.anim_open
            inst:ListenForEvent("openeddirty", function()
                if inst._opened:value() then
                    inst.AnimState:PlayAnimation(anim_open)
                end
            end)
            return inst
        end

        -- SERVER SIDE --

        -- Components
        inst:AddComponent("inspectable")

        inst:AddComponent("activatable")
        inst.components.activatable.OnActivate = function(box, doer)
            -- Check network-synced opened state
            if inst._opened:value() then
                return false
            end

            -- Set opened state (syncs to all clients)
            inst._opened:set(true)

            -- Play animation and sound
            local anim_open = (visual and visual.anim_open) or config.anim_open or DEFAULTS.anim_open
            inst.AnimState:PlayAnimation(anim_open)
            inst.SoundEmitter:PlaySound(config.openSound or DEFAULTS.open_sound)

            -- Trigger tower unlock for this branch
            if rawget(_G, "MysteryBoxOnChestOpened") then
                _G.MysteryBoxOnChestOpened(doer)
            end

            -- Custom activation logic (like mysterybox loot selection)
            if config.onActivateCustom then
                config.onActivateCustom(inst, doer)
            else
                -- Default: trigger event through event manager
                if rawget(_G, "MysteryBoxEventManager") and config.boxType then
                    _G.MysteryBoxEventManager:TriggerBoxEvent(config.boxType, doer)
                end
            end

            -- Player message
            if config.message and doer and doer.components and doer.components.talker then
                doer.components.talker:Say(config.message)
            end

            -- Bonus loot after delay
            if config.bonusLoot then
                inst:DoTaskInTime(config.bonusDelay or 3.0, function()
                    if inst:IsValid() then
                        local x, y, z = inst.Transform:GetWorldPosition()
                        for _, item in ipairs(config.bonusLoot) do
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
                    end
                end)
            else
                -- Remove after short delay
                inst:DoTaskInTime(config.removeDelay or DEFAULTS.remove_delay, function()
                    if inst:IsValid() then
                        inst:Remove()
                    end
                end)
            end

            return true
        end
        inst.components.activatable.quickaction = true

        inst:AddComponent("lootdropper")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = "treasurechest"
        inst.components.inventoryitem.atlasname = "images/inventoryimages.xml"

        return inst
    end

    return Prefab(config.name, fn, assets)
end

return BoxFactory
