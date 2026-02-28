-- Golden Mystery Box Prefab
-- A blessed box that triggers reward/social events only - no danger!

local BoxFactory = require "prefabs/box_factory"
local LootSystem = require "core/loot_system"

-- Custom activation: spawn golden loot pack
local function OnActivateCustom(inst, doer)
    local x, y, z = inst.Transform:GetWorldPosition()

    -- Use the golden box loot pack
    local result = LootSystem.BuildLootList("golden_box")
    LootSystem.SpawnLoot(result.items, x, y, z, {
        velocity = 4,
        height = 0.5,
        delay = 0.08,  -- Quick staggered spawn
    })

    print("[Golden Box] Player " .. (doer.name or "unknown") .. " received " .. #result.items .. " items")
end

return BoxFactory.Create({
    name = "goldenbox",
    tag = "goldenbox",
    visual = "gift",  -- Present/gift box style
    tint = {1, 0.85, 0.4, 1},  -- Golden tint
    boxType = "golden",
    openSound = "dontstarve/common/chest_open",
    onActivateCustom = OnActivateCustom,
    message = "It's glowing with good fortune!",
    removeDelay = 2.0,
})
