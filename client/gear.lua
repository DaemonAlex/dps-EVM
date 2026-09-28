--[[
    dps-fleet client/gear.lua — trunk gear

    Credit: Vehiclegear by Lapertaja (https://github.com/Lapertaja/Vehiclegear),
    CC BY-NC-SA 4.0 — the full licence is in docs/licenses/vehiclegear.txt. The DPS
    fork (1.1.5-dps1) is by DaemonAlex; this file folds that fork into dps-fleet.

    Aim at the trunk of an emergency vehicle and take that department's kit out of
    it: LEO gets vest/reflective/helmet, SWAT gets heavy armour, fire gets turnout
    gear and a fire helmet, medical gets a reflective vest and a medical bag
    (Config.TrunkGear.DeptGear). What a model carries and which job may take it is
    Gear.* in shared/workshop.lua, so the rule is tested, not re-written here.

    Differences from the fork it replaces:
      * the vehicle list comes from data/emergency.json (AutoVehicles) and the job
        list from the workshop job set (AutoJobs) — no hand list to keep in step;
      * one data-driven option per Config.TrunkGear.Gear entry instead of four
        copies of the same handler, and one "remove" option per slot;
      * the trunk item moves server-side only (server.lua's trunk gear block),
        which re-checks job, department, gear key and the vehicle the player
        claims, and counts what each player has out so nothing can be duplicated.

    Performance: the target options are registered once at start; canInteract is a
    hash lookup in GEAR_BY_HASH plus a table lookup. No threads, no loops.
]]

local FEMALE_PED = joaat('mp_f_freemode_01')

local GEAR_BY_HASH = {}   -- model hash (unsigned) -> { model, dept, gear, set }
local JOB_SET = {}        -- job name -> true, the workshop set as the server derived it
local JOB_LIST = {}       -- the same names as an array, for ox_target's groups filter
local worn = {}           -- slot name -> { key, original = { drawable, texture } | nil, armour }
local registered = false
local haveIndex = false

GearClient = GearClient or {}

-- ── small helpers ─────────────────────────────────────────────────────────────

local function cfg() return Config.TrunkGear end

local function text(key)
    local tg = cfg()
    return (tg and tg.Translation and tg.Translation[key]) or 'That did not work.'
end

local function notify(description, kind)
    local tg = cfg()
    lib.notify({
        title = (tg and tg.Translation and tg.Translation.notifyTitle) or 'Gear system',
        description = description,
        type = kind or 'inform',
        duration = ((tg and tonumber(tg.NotifyDuration)) or 5) * 1000,
    })
end

---@param key string
---@return table|nil definition
local function gearDef(key)
    local tg = cfg()
    local def = tg and type(tg.Gear) == 'table' and tg.Gear[key] or nil
    return type(def) == 'table' and def or nil
end

---The drawable/texture pair for this piece on MY ped's gender; nil when the piece
---changes no clothing (item-only gear, or a gender pair left false).
---@param def table
---@return number|nil drawable, number texture
local function gearNumbers(def)
    local pair = (GetEntityModel(cache.ped) == FEMALE_PED) and def.female or def.male
    if type(pair) ~= 'table' then return nil, 0 end
    return pair[1], pair[2] or 0
end

---@return string|nil jobName
local function jobName()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    return job and job.name or nil
end

---@param entity number
---@return table|nil entry
local function entryFor(entity)
    return GEAR_BY_HASH[GetEntityModel(entity) % 0x100000000]
end

---Ped turned to the trunk before anything happens (upstream behaviour kept).
---@param entity number
---@param maxAngle number|nil
---@return boolean looking
local function isLookingAt(entity, maxAngle)
    local pedCoords = GetEntityCoords(cache.ped)
    local entityCoords = GetEntityCoords(entity)
    local toEntity = entityCoords - pedCoords
    local len = #(toEntity)
    if len <= 0.0 then return true end
    toEntity = toEntity / len
    local forward = GetEntityForwardVector(cache.ped)
    local dot = forward.x * toEntity.x + forward.y * toEntity.y + forward.z * toEntity.z
    return math.deg(math.acos(math.max(-1.0, math.min(1.0, dot)))) < (maxAngle or 30.0)
end

---@param entity number
local function faceTrunk(entity)
    TaskTurnPedToFaceEntity(cache.ped, entity, 1000)
    local waited = 0
    while waited < 1200 and DoesEntityExist(entity) and not isLookingAt(entity) do
        Wait(50)
        waited = waited + 50
    end
    Wait(100)
end

---The trunk is opened for the progress circle and shut again after, unless it was
---already open when we arrived.
---@param label string
---@param entity number
---@return boolean completed
local function runBar(label, entity)
    local tg = cfg()
    local door, wasOpen = 5, false
    if DoesEntityExist(entity) then
        local angle = GetVehicleDoorAngleRatio(entity, door)
        wasOpen = angle ~= nil and angle > 0.1
        if not wasOpen then SetVehicleDoorOpen(entity, door, false, false) end
    end

    local completed = lib.progressCircle({
        duration = (tg and tonumber(tg.Duration)) or 3500,
        label = label,
        useWhileDead = false,
        allowCuffed = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'mp_car_bomb', clip = 'car_bomb_mechanic' },
        position = 'bottom',
    })

    if DoesEntityExist(entity) and not wasOpen then SetVehicleDoorShut(entity, door, false) end
    if completed and tg and tg.Sound and tg.Sound.Enable then
        PlaySoundFrontend(-1, tg.Sound.Name, tg.Sound.Set, true)
    end
    return completed == true
end

-- ── wearing and taking off ────────────────────────────────────────────────────

---@param key string
---@param def table
local function wear(key, def)
    local armour = tonumber(def.armour) or 0
    if armour > 0 then SetPedArmour(cache.ped, math.min(GetPedArmour(cache.ped) + armour, 100)) end

    local slotName = def.slot
    local slot = slotName and Gear.SLOTS[slotName] or nil
    if not slot then return end   -- item-only gear: nothing is worn, nothing to remember

    local drawable, texture = gearNumbers(def)
    local original
    if slot.kind == 'prop' then
        local prop = GetPedPropIndex(cache.ped, slot.index)
        if prop ~= -1 then
            original = { drawable = prop, texture = GetPedPropTextureIndex(cache.ped, slot.index) }
        end
        ClearPedProp(cache.ped, slot.index)
        if drawable then SetPedPropIndex(cache.ped, slot.index, drawable, texture, true) end
    else
        original = { drawable = GetPedDrawableVariation(cache.ped, slot.index), texture = GetPedTextureVariation(cache.ped, slot.index) }
        if drawable then SetPedComponentVariation(cache.ped, slot.index, drawable, texture, 1) end
    end
    worn[slotName] = { key = key, original = original, armour = armour }
end

---@param slotName string
local function takeOff(slotName)
    local piece = worn[slotName]
    local slot = Gear.SLOTS[slotName]
    if not piece or not slot then return end

    if piece.armour > 0 then SetPedArmour(cache.ped, math.max(GetPedArmour(cache.ped) - piece.armour, 0)) end
    if slot.kind == 'prop' then
        ClearPedProp(cache.ped, slot.index)
        if piece.original then SetPedPropIndex(cache.ped, slot.index, piece.original.drawable, piece.original.texture, true) end
    elseif piece.original then
        SetPedComponentVariation(cache.ped, slot.index, piece.original.drawable, piece.original.texture, 1)
    end
    worn[slotName] = nil
end

-- ── the two interactions ──────────────────────────────────────────────────────

---@param key string
---@param entity number
---@return boolean
local function canTake(key, entity)
    local tg = cfg()
    if not tg or tg.enabled == false then return false end
    if not haveIndex then return false end
    local def = gearDef(key)
    if not def then return false end

    local entry = entryFor(entity)
    if not entry or not entry.set[key] then return false end
    if def.slot and worn[def.slot] then return false end

    local job = jobName()
    if not Gear.jobAllowed(job, Config, JOB_SET) then return false end
    if not Gear.deptAllowed(job, entry.dept, Config) then return false end
    if tg.RequireUnlocked and GetVehicleDoorLockStatus(entity) ~= 1 then return false end
    return true
end

---@param key string
---@param entity number
local function take(key, entity)
    local def = gearDef(key)
    if not def or not entity or not DoesEntityExist(entity) then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then return end

    -- asked before the animation so a player does not work for nothing
    local ok, reason = lib.callback.await('dps-fleet:server:gearCheck', false, netId, key)
    if not ok then return notify(reason or text('not_in_trunk'), 'error') end

    faceTrunk(entity)
    if not runBar(def.busy or def.label or '…', entity) then return end
    if not DoesEntityExist(entity) then return notify(text('failed'), 'error') end

    -- the item only moves now, and only the server moves it
    local taken, why = lib.callback.await('dps-fleet:server:gearTake', false, netId, key)
    if not taken then return notify(why or text('failed'), 'error') end

    wear(key, def)
    notify(def.done or def.label or text('failed'), 'inform')
end

---@param slotName string
---@param entity number
---@return boolean
local function canRemove(slotName, entity)
    local tg = cfg()
    if not tg or tg.enabled == false then return false end
    if not worn[slotName] then return false end

    -- the same gate the server puts on putting it back, so the option is only
    -- offered where it will actually work
    local entry = entryFor(entity)
    if not entry then return false end
    local job = jobName()
    if not Gear.jobAllowed(job, Config, JOB_SET) then return false end
    return Gear.deptAllowed(job, entry.dept, Config)
end

---@param slotName string
---@param entity number
local function remove(slotName, entity)
    local piece = worn[slotName]
    local tg = cfg()
    if not piece or not entity or not DoesEntityExist(entity) then return end
    local slotText = (tg and tg.Slots and tg.Slots[slotName]) or {}

    faceTrunk(entity)
    if not runBar(slotText.busy or slotText.label or '…', entity) then return end
    if not worn[slotName] then return end   -- gone while the bar ran

    local netId = DoesEntityExist(entity) and NetworkGetNetworkIdFromEntity(entity) or nil
    local stowed, why = true, nil
    if netId and netId ~= 0 then
        stowed, why = lib.callback.await('dps-fleet:server:gearStow', false, netId, piece.key)
    else
        stowed = false
    end

    -- the gear stays on when the item could not go back: the item was taken out of
    -- a trunk, so losing it here would lose it for good — try again at a trunk.
    if not stowed then return notify(why or text('not_returned'), 'error') end

    takeOff(slotName)
    notify(slotText.done or text('failed'), 'inform')
end

-- ── ox_target ─────────────────────────────────────────────────────────────────

---One option per gear piece plus one "remove" per slot, built once. The groups
---filter is the workshop job set (ox_target drops the option for anyone else);
---canInteract still re-checks job and department, because groups cannot know
---which department's vehicle is being aimed at.
---@return table options
local function buildOptions()
    local tg = cfg()
    local options = {}
    local groups = #JOB_LIST > 0 and JOB_LIST or nil

    for _, key in ipairs((tg and tg.GearOrder) or {}) do
        local def = gearDef(key)
        if def then
            options[#options + 1] = {
                name = 'dps_fleet_trunk_gear_' .. key,
                icon = def.icon or 'fa-solid fa-box-open',
                label = def.label or key,
                bones = { 'boot', 'trunk', 'handlebars' },
                distance = 1.0,
                groups = groups,
                canInteract = function(entity) return canTake(key, entity) end,
                onSelect = function(data) take(key, data.entity) end,
            }
        end
    end

    for _, slotName in ipairs((tg and tg.SlotOrder) or {}) do
        local slotText = tg and tg.Slots and tg.Slots[slotName] or nil
        if slotText and Gear.SLOTS[slotName] then
            options[#options + 1] = {
                name = 'dps_fleet_trunk_gear_remove_' .. slotName,
                icon = slotText.icon or 'fa-solid fa-box-open',
                label = slotText.label or ('Remove ' .. slotName),
                bones = { 'boot', 'trunk', 'handlebars' },
                distance = 1.0,
                canInteract = function(entity) return canRemove(slotName, entity) end,
                onSelect = function(data) remove(slotName, data.entity) end,
            }
        end
    end

    return options
end

local function register()
    if registered or not haveIndex then return end
    local tg = cfg()
    if not tg or tg.enabled == false then return end
    if GetResourceState('ox_target') ~= 'started' then return end
    local options = buildOptions()
    if #options == 0 then return end
    registered = true
    exports.ox_target:addGlobalVehicle(options)
end

-- ── the emergency index ───────────────────────────────────────────────────────

---@param emergency table|nil model -> { dept, kind }
---@param jobs table|nil array of job names
local function useIndex(emergency, jobs)
    if type(emergency) ~= 'table' or next(emergency) == nil then return false end

    if type(jobs) == 'table' then
        JOB_SET, JOB_LIST = {}, {}
        for _, name in ipairs(jobs) do
            if type(name) == 'string' and name ~= '' then
                JOB_SET[name] = true
                JOB_LIST[#JOB_LIST + 1] = name
            end
        end
    end

    GEAR_BY_HASH = {}
    local n = 0
    for model, entry in pairs(Gear.buildIndex(Config, emergency)) do
        GEAR_BY_HASH[joaat(model) % 0x100000000] = entry
        n = n + 1
    end
    haveIndex = n > 0
    if haveIndex then register() end
    return haveIndex
end

---The panel's own copy of data/emergency.json (client.lua's serverData), used when
---the start-up callback found nothing — a client that joined mid-boot.
---@param emergency table|nil
function GearClient.setEmergency(emergency)
    if haveIndex then return end
    useIndex(emergency, nil)
end

---One shot at resource start, never a loop: the department map and the workshop job
---set, both small. A client that joins before the server has read the files gets
---one retry, and the next panel open fills it through GearClient.setEmergency.
local function loadIndex()
    local emergency, jobs = lib.callback.await('dps-fleet:server:emergencyIndex', false)
    return useIndex(emergency, jobs)
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        SetTimeout(2000, function()
            if not loadIndex() then SetTimeout(15000, loadIndex) end
        end)
    elseif resource == 'ox_target' then
        registered = false   -- ox_target dropped every global option when it stopped
        register()
    end
end)

-- Job and worn gear are per-character: a logout leaves nothing behind (the ped is
-- rebuilt on the next spawn, so only our memory needs clearing).
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    worn = {}
end)
