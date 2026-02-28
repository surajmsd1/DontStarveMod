-- Cursed Mystery Box Prefab
-- A dangerous box that triggers challenge/boss events with better rewards

local BoxFactory = require "prefabs/box_factory"
local LootSystem = require "core/loot_system"

-- Custom activation: spawn cursed loot pack
local function OnActivateCustom(inst, doer)
    local x, y, z = inst.Transform:GetWorldPosition()

    -- Use the cursed box loot pack
    local result = LootSystem.BuildLootList("cursed_box")
    LootSystem.SpawnLoot(result.items, x, y, z, {
        velocity = 5,
        height = 0.5,
        delay = 0.1,  -- Dramatic staggered spawn
    })

    print("[Cursed Box] Player " .. (doer.name or "unknown") .. " received " .. #result.items .. " items")
end

return BoxFactory.Create({
    name = "cursedbox",
    tag = "cursedbox",
    tint = {0.5, 0.2, 0.5, 1},  -- Purple
    boxType = "cursed",
    openSound = "dontstarve/common/nightmareportal_1",
    onActivateCustom = OnActivateCustom,
    message = "This feels... dangerous!",
    removeDelay = 2.0,
})
