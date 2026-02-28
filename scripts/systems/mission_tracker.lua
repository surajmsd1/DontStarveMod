-- Mission Tracker System
-- Server-side shared progress tracking for multiplayer missions
-- All players contribute to the same mission goals

local MissionTracker = {}
MissionTracker.__index = MissionTracker

-- Mission objective types
MissionTracker.OBJECTIVE_TYPE = {
    COLLECT = "collect",       -- Collect N items (by prefab name)
    KILL = "kill",             -- Kill N entities (by prefab name)
    BOSS = "boss",             -- Kill a specific boss
    SURVIVE = "survive",       -- Survive N seconds
    BUILD = "build",           -- Build N structures
    CUSTOM = "custom",         -- Custom check function
}

-- Mission states
MissionTracker.STATE = {
    INACTIVE = "inactive",
    ACTIVE = "active",
    COMPLETED = "completed",
    FAILED = "failed",
}

function MissionTracker.Create(world)
    local self = setmetatable({}, MissionTracker)
    self.world = world
    self.missions = {}           -- id -> mission data
    self.active_missions = {}    -- ordered list of active mission ids
    self.completed_count = 0
    self.listeners = {}          -- event listeners to clean up
    self._on_update_fn = nil     -- callback when UI needs refresh
    return self
end

-- Register a callback for when mission data changes (triggers UI sync)
function MissionTracker:OnUpdate(fn)
    self._on_update_fn = fn
end

function MissionTracker:_NotifyUpdate(mission_id)
    if self._on_update_fn then
        self._on_update_fn(mission_id, self.missions[mission_id])
    end
end

-- Start a new mission from a mission definition
-- def = {
--   id = "unique_id",
--   name = "Display Name",
--   description = "What players need to do",
--   icon = "prefab_name" (optional, for display),
--   category = "challenge" | "boss" | "gather" | "explore",
--   time_limit = seconds or nil,
--   objectives = {
--     { type = "collect", target = "goldnugget", required = 10, label = "Gold Nuggets" },
--     { type = "kill", target = "spider", required = 20, label = "Spiders" },
--     { type = "boss", target = "deerclops", required = 1, label = "Deerclops" },
--   },
--   rewards = { loot_pack = "boss_loot" } or { items = {"redgem", "bluegem"} },
--   on_complete = function(tracker, mission) end,
--   on_fail = function(tracker, mission) end,
-- }
function MissionTracker:StartMission(def)
    if not def or not def.id then
        print("[MissionTracker] ERROR: Mission definition missing id")
        return false
    end

    if self.missions[def.id] and self.missions[def.id].state == MissionTracker.STATE.ACTIVE then
        print("[MissionTracker] Mission already active: " .. def.id)
        return false
    end

    local mission = {
        id = def.id,
        name = def.name or "Unknown Mission",
        description = def.description or "",
        icon = def.icon,
        category = def.category or "challenge",
        state = MissionTracker.STATE.ACTIVE,
        started_at = GetTime and GetTime() or 0,
        time_limit = def.time_limit,
        objectives = {},
        rewards = def.rewards,
        on_complete = def.on_complete,
        on_fail = def.on_fail,
        boss_entity = nil,  -- reference to spawned boss if any
    }

    -- Initialize objectives
    for i, obj_def in ipairs(def.objectives or {}) do
        table.insert(mission.objectives, {
            type = obj_def.type or MissionTracker.OBJECTIVE_TYPE.CUSTOM,
            target = obj_def.target,
            required = obj_def.required or 1,
            current = 0,
            label = obj_def.label or obj_def.target or "Objective " .. i,
            completed = false,
        })
    end

    self.missions[def.id] = mission
    table.insert(self.active_missions, def.id)

    -- Set up event listeners for this mission
    self:_SetupMissionListeners(mission)

    -- Set up time limit if specified
    if def.time_limit and def.time_limit > 0 then
        mission._timer_task = self.world:DoTaskInTime(def.time_limit, function()
            if mission.state == MissionTracker.STATE.ACTIVE then
                self:FailMission(def.id, "Time's up!")
            end
        end)
    end

    -- Announce
    if TheNet then
        TheNet:Announce("[Mission] " .. mission.name .. " has begun!")
        if mission.description ~= "" then
            TheNet:Announce(mission.description)
        end
    end

    self:_NotifyUpdate(def.id)
    print("[MissionTracker] Started mission: " .. def.id)
    return true
end

-- Set up automatic event listeners for tracking objectives
function MissionTracker:_SetupMissionListeners(mission)
    for i, obj in ipairs(mission.objectives) do
        if obj.type == MissionTracker.OBJECTIVE_TYPE.KILL
           or obj.type == MissionTracker.OBJECTIVE_TYPE.BOSS then
            -- Listen for entity deaths globally
            local fn = function(world, data)
                if mission.state ~= MissionTracker.STATE.ACTIVE then return end
                if data and data.inst and data.inst.prefab == obj.target then
                    self:AddProgress(mission.id, i, 1)
                end
            end
            self.world:ListenForEvent("entity_death", fn)
            table.insert(self.listeners, { source = self.world, event = "entity_death", fn = fn })
        end
    end
end

-- Manually add progress to a specific objective
function MissionTracker:AddProgress(mission_id, objective_index, amount)
    local mission = self.missions[mission_id]
    if not mission or mission.state ~= MissionTracker.STATE.ACTIVE then return end

    local obj = mission.objectives[objective_index]
    if not obj or obj.completed then return end

    obj.current = math.min(obj.current + (amount or 1), obj.required)

    if obj.current >= obj.required then
        obj.completed = true
        if TheNet then
            TheNet:Announce("[Mission] " .. obj.label .. " complete!")
        end
    end

    -- Check if all objectives complete
    local all_done = true
    for _, o in ipairs(mission.objectives) do
        if not o.completed then
            all_done = false
            break
        end
    end

    if all_done then
        self:CompleteMission(mission_id)
    else
        self:_NotifyUpdate(mission_id)
    end
end

-- Track an item pickup for collect-type objectives across all active missions
function MissionTracker:OnItemCollected(prefab, amount)
    for _, mission_id in ipairs(self.active_missions) do
        local mission = self.missions[mission_id]
        if mission and mission.state == MissionTracker.STATE.ACTIVE then
            for i, obj in ipairs(mission.objectives) do
                if obj.type == MissionTracker.OBJECTIVE_TYPE.COLLECT
                   and obj.target == prefab
                   and not obj.completed then
                    self:AddProgress(mission_id, i, amount or 1)
                end
            end
        end
    end
end

-- Track a kill for kill-type objectives
function MissionTracker:OnEntityKilled(prefab)
    for _, mission_id in ipairs(self.active_missions) do
        local mission = self.missions[mission_id]
        if mission and mission.state == MissionTracker.STATE.ACTIVE then
            for i, obj in ipairs(mission.objectives) do
                if (obj.type == MissionTracker.OBJECTIVE_TYPE.KILL
                    or obj.type == MissionTracker.OBJECTIVE_TYPE.BOSS)
                   and obj.target == prefab
                   and not obj.completed then
                    self:AddProgress(mission_id, i, 1)
                end
            end
        end
    end
end

-- Track a structure built
function MissionTracker:OnStructureBuilt(prefab)
    for _, mission_id in ipairs(self.active_missions) do
        local mission = self.missions[mission_id]
        if mission and mission.state == MissionTracker.STATE.ACTIVE then
            for i, obj in ipairs(mission.objectives) do
                if obj.type == MissionTracker.OBJECTIVE_TYPE.BUILD
                   and obj.target == prefab
                   and not obj.completed then
                    self:AddProgress(mission_id, i, 1)
                end
            end
        end
    end
end

-- Store a reference to a spawned boss entity for UI display
function MissionTracker:SetBossEntity(mission_id, entity)
    local mission = self.missions[mission_id]
    if mission then
        mission.boss_entity = entity
        self:_NotifyUpdate(mission_id)
    end
end

function MissionTracker:CompleteMission(mission_id)
    local mission = self.missions[mission_id]
    if not mission or mission.state ~= MissionTracker.STATE.ACTIVE then return end

    mission.state = MissionTracker.STATE.COMPLETED
    mission.completed_at = GetTime and GetTime() or 0
    self.completed_count = self.completed_count + 1

    -- Cancel timer
    if mission._timer_task then
        mission._timer_task:Cancel()
        mission._timer_task = nil
    end

    -- Announce
    if TheNet then
        TheNet:Announce("[Mission Complete] " .. mission.name .. "!")
    end

    -- Give rewards
    if mission.rewards then
        self:_GiveRewards(mission)
    end

    -- Callback
    if mission.on_complete then
        local ok, err = pcall(mission.on_complete, self, mission)
        if not ok then
            print("[MissionTracker] ERROR in on_complete: " .. tostring(err))
        end
    end

    -- Remove from active list
    for i, id in ipairs(self.active_missions) do
        if id == mission_id then
            table.remove(self.active_missions, i)
            break
        end
    end

    self:_NotifyUpdate(mission_id)
end

function MissionTracker:FailMission(mission_id, reason)
    local mission = self.missions[mission_id]
    if not mission or mission.state ~= MissionTracker.STATE.ACTIVE then return end

    mission.state = MissionTracker.STATE.FAILED

    -- Cancel timer
    if mission._timer_task then
        mission._timer_task:Cancel()
        mission._timer_task = nil
    end

    if TheNet then
        TheNet:Announce("[Mission Failed] " .. mission.name .. (reason and (" - " .. reason) or ""))
    end

    if mission.on_fail then
        local ok, err = pcall(mission.on_fail, self, mission)
        if not ok then
            print("[MissionTracker] ERROR in on_fail: " .. tostring(err))
        end
    end

    -- Remove from active list
    for i, id in ipairs(self.active_missions) do
        if id == mission_id then
            table.remove(self.active_missions, i)
            break
        end
    end

    self:_NotifyUpdate(mission_id)
end

function MissionTracker:_GiveRewards(mission)
    local LootSystem = require "core/loot_system"

    -- Find a central player position for loot drop
    local players = AllPlayers or {}
    if #players == 0 then return end

    local player = players[1]
    local x, y, z = player.Transform:GetWorldPosition()

    if mission.rewards.loot_pack then
        LootSystem.DropPack(mission.rewards.loot_pack, x, y, z, { velocity = 8 })
    elseif mission.rewards.items then
        for _, prefab in ipairs(mission.rewards.items) do
            local item = SpawnPrefab(prefab)
            if item then
                local angle = math.random() * 2 * math.pi
                item.Transform:SetPosition(x + math.cos(angle) * 3, y + 1, z + math.sin(angle) * 3)
                if item.Physics then
                    item.Physics:SetVel(math.cos(angle) * 3, 8, math.sin(angle) * 3)
                end
            end
        end
    end
end

-- Get serializable snapshot of all active missions for UI sync
function MissionTracker:GetMissionSnapshot()
    local snapshot = {}
    for _, mission_id in ipairs(self.active_missions) do
        local m = self.missions[mission_id]
        if m and m.state == MissionTracker.STATE.ACTIVE then
            local objectives = {}
            for _, obj in ipairs(m.objectives) do
                table.insert(objectives, {
                    type = obj.type,
                    target = obj.target,
                    label = obj.label,
                    current = obj.current,
                    required = obj.required,
                    completed = obj.completed,
                })
            end

            local time_remaining = nil
            if m.time_limit then
                local elapsed = (GetTime and GetTime() or 0) - m.started_at
                time_remaining = math.max(0, m.time_limit - elapsed)
            end

            local boss_health = nil
            if m.boss_entity and m.boss_entity:IsValid()
               and m.boss_entity.components and m.boss_entity.components.health then
                boss_health = {
                    current = m.boss_entity.components.health.currenthealth,
                    max = m.boss_entity.components.health.maxhealth,
                }
            end

            table.insert(snapshot, {
                id = m.id,
                name = m.name,
                description = m.description,
                icon = m.icon,
                category = m.category,
                objectives = objectives,
                time_remaining = time_remaining,
                boss_health = boss_health,
            })
        end
    end
    return snapshot
end

-- Get recently completed/failed missions (last 2 minutes)
function MissionTracker:GetRecentFinished()
    local recent = {}
    local now = GetTime and GetTime() or 0
    for _, m in pairs(self.missions) do
        if (m.state == MissionTracker.STATE.COMPLETED or m.state == MissionTracker.STATE.FAILED)
           and m.completed_at and (now - m.completed_at) < 120 then
            table.insert(recent, {
                id = m.id,
                name = m.name,
                state = m.state,
            })
        end
    end
    return recent
end

-- Clean up all listeners
function MissionTracker:Cleanup()
    for _, listener in ipairs(self.listeners) do
        if listener.source and listener.source:IsValid() then
            listener.source:RemoveEventCallback(listener.event, listener.fn)
        end
    end
    self.listeners = {}

    -- Cancel any active timers
    for _, m in pairs(self.missions) do
        if m._timer_task then
            m._timer_task:Cancel()
            m._timer_task = nil
        end
    end
end

return MissionTracker
