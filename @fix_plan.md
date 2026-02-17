# Ralph Fix Plan - Mystery Box: DnD Gamemaster Mod

## Current Issue
Mod crashes instantly on load with no visible error messages. Need proper logging and DST coding standards.

## Sprint 5: Fix Crash & Add Logging

### Critical - Fix Instant Crash
- [x] Research DST mod coding standards (GLOBAL namespace, require patterns, env setup)
- [x] Research how other popular DST mods structure their code (check Workshop examples)
- [x] Fix all GLOBAL namespace issues across all Lua files
- [x] Ensure require() works properly for scripts/events/*.lua modules (MOVED TO INLINE)
- [ ] Test that mod loads without crashing (HUMAN REQUIRED)

### High Priority - Implement File Logging
- [x] Research DST file I/O capabilities (DST mods use print() to client_log.txt)
- [x] Create logging function with prefix (moved inline to modmain.lua)
- [x] Wrap all module loads in pcall() with error logging
- [ ] Add startup diagnostics (log DST version, mod version) - optional

### Medium Priority - Code Quality
- [x] Add proper error handling with pcall() around risky operations
- [x] Validate all prefab spawns before using them
- [x] Add nil checks for player/world references
- [x] Ensure all event Execute functions have try/catch style error handling

## Testing Commands
```lua
-- Spawn boxes for testing
c_spawn("mysterybox")
c_spawn("cursedbox")
c_spawn("goldenbox")

-- Check if mod loaded
print(GLOBAL.MysteryBoxEventManager and "Event Manager OK" or "Event Manager FAILED")
```

## Log File Location
Logs will be written to: `[DST User Data]/client_log.txt` or custom mod log file

## Notes
- DST mods run in a sandboxed Lua environment
- GLOBAL prefix required for all game APIs
- Prefab files have different env than modmain.lua
- Use env setup pattern: `GLOBAL.setfenv(1, GLOBAL)` in prefabs
