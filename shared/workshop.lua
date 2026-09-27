--[[
    dps-fleet shared/workshop.lua
    EVM workshop access. Pure data/logic; shared by client, server and tests.
]]
Workshop = Workshop or {}
Access = Access or {}

local jobSetCache, jobSetSource = nil, nil
local function jobSet(cfg)
    if jobSetCache and jobSetSource == cfg.JobMappings then return jobSetCache end
    local set = {}
    for _, names in pairs(cfg.JobMappings or {}) do
        for _, n in ipairs(names) do set[n] = true end
    end
    jobSetCache, jobSetSource = set, cfg.JobMappings
    return set
end

---@param jobName string|nil
---@param isAdmin boolean
---@param cfg table
---@return boolean ok, string|nil reason
function Access.canWorkshop(jobName, isAdmin, cfg)
    if cfg.EnableJobRestrictions == false then return true end
    if not jobName then return false, 'Your character is not loaded yet.' end
    if isAdmin then return true end
    if jobSet(cfg)[jobName] then return true end
    return false, 'Your job does not permit vehicle modifications.'
end
