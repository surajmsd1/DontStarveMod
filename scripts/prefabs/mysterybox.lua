-- Mystery Box Prefab
-- A placeable box that gives random rewards when activated

local BoxFactory = require "prefabs/box_factory"
local LootSystem = require "core/loot_system"

-- Custom activation: spawn loot pack
local function OnActivateCustom(inst, doer)
    local x, y, z = inst.Transform:GetWorldPosition()

    -- Use the new loot system
    local result = LootSystem.BuildLootList("mystery_common")
    LootSystem.SpawnLoot(result.items, x, y, z, {
        velocity = 4,
        height = 0.5,
    })

    print("[Mystery Box] Player " .. (doer.name or "unknown") .. " received " .. #result.items .. " items")

    if doer and doer.components and doer.components.talker then
        doer.components.talker:Say("Loot!")
    end
end

return BoxFactory.Create({
    name = "mysterybox",
    tag = "mysterybox",
    onActivateCustom = OnActivateCustom,
    removeDelay = 1.0,
})
