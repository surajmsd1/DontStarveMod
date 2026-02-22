-- Test utilities for Mystery Box Mod
-- Paste these into DST console (~) to test features

-- ============================================
-- BASIC CHECKS
-- ============================================

-- Check if mod loaded
-- print(MysteryBoxEventManager and "MOD OK" or "MOD FAILED")

-- Check event count
-- print("Events: " .. (MysteryBoxEventManager and MysteryBoxEventManager:GetEventCount() or 0))

-- ============================================
-- SPAWN TESTS
-- ============================================

-- Spawn boxes near player
-- c_spawn("mysterybox")
-- c_spawn("cursedbox")
-- c_spawn("goldenbox")

-- ============================================
-- EVENT TESTS
-- ============================================

-- Force daily event
-- MysteryBoxEventManager:OnDayStart()

-- Test specific box type
-- MysteryBoxEventManager:TriggerBoxEvent("cursed", ThePlayer)
-- MysteryBoxEventManager:TriggerBoxEvent("golden", ThePlayer)

-- ============================================
-- TIME CONTROL
-- ============================================

-- Skip to next day
-- c_skip(480)

-- Force dawn (triggers daily event)
-- TheWorld:PushEvent("ms_setphase", "day")

-- Check current time
-- print("Day: " .. TheWorld.state.cycles .. " Phase: " .. TheWorld.state.phase)

-- ============================================
-- DEBUG INFO
-- ============================================

-- List all registered events
--[[
if MysteryBoxEventManager then
    for id, event in pairs(MysteryBoxEventManager.events) do
        print(id .. " - " .. event.name .. " [" .. tostring(event.category) .. "]")
    end
end
]]

-- Check event categories
--[[
if MysteryBoxEventManager then
    print("REWARD: " .. MysteryBoxEventManager:GetCategoryEventCount("reward"))
    print("CHALLENGE: " .. MysteryBoxEventManager:GetCategoryEventCount("challenge"))
    print("BOSS: " .. MysteryBoxEventManager:GetCategoryEventCount("boss"))
    print("SOCIAL: " .. MysteryBoxEventManager:GetCategoryEventCount("social"))
end
]]

-- ============================================
-- QUICK TEST SEQUENCE
-- Copy this whole block to run full test:
-- ============================================
--[[
print("=== MYSTERY BOX TEST ===")
print("Manager: " .. (MysteryBoxEventManager and "OK" or "FAILED"))
if MysteryBoxEventManager then
    print("Events: " .. MysteryBoxEventManager:GetEventCount())
    print("Testing cursed box event...")
    MysteryBoxEventManager:TriggerBoxEvent("cursed", ThePlayer)
end
print("=== TEST COMPLETE ===")
]]
