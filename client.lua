--[[
    dps-carmenu client  (Qbox native: qbx registry export, ox_lib cache, lib.callback)
    F7 or /carmenu opens the fleet panel: a floating search bar with the grouped list
    under it. Search, grouping and card text are Lua (shared/search.lua) so the panel
    is a view and the logic stays testable.

    Performance: no CreateThread loops. Everything is event or callback driven; the
    only deferred work is a one-shot timer after a spawn. Model natives run only after
    a selection rests (the panel debounces) and the model is released right after.
]]

local isOpen = false
local startMode = 'browse'
local ALL = {}            -- rows: model, name, brand, category, type, price, pack, cls, make, dept, kind, photo, speed, seats
local BY_MODEL = {}
local BY_HASH = {}        -- model hash -> model name, so a live vehicle names itself
local wsVehicle = nil     -- the vehicle the workshop is working on, re-resolved on every call
local wsModel = nil       -- its model name, kept so the last-spawned fallback still works
local INFO = {}           -- model -> model-native info, read once per session
local HANDLING = {}       -- model -> last handling record read from a live vehicle
local lastSpawned = nil   -- { netId, model }
local serverData = nil    -- packs / classes / emergency / photos from the server, once per session

local KVP_RECENT, KVP_FAV = 'dps_carmenu_recent', 'dps_carmenu_fav'
local RECENT_MAX = 15

-- ── small helpers ──────────────────────────────────────────────────────────────

local function loadList(key)
    local raw = GetResourceKvpString(key)
    if not raw then return {} end
    local ok, t = pcall(json.decode, raw)
    if not ok or type(t) ~= 'table' then return {} end
    return t
end

local function saveList(key, t) SetResourceKvp(key, json.encode(t)) end

local function pushRecent(model)
    local list = loadList(KVP_RECENT)
    for i = #list, 1, -1 do if list[i] == model then table.remove(list, i) end end
    table.insert(list, 1, model)
    while #list > RECENT_MAX do table.remove(list) end
    saveList(KVP_RECENT, list)
    return list
end

local function favList() return loadList(KVP_FAV) end
local function isFav(model)
    for _, m in ipairs(favList()) do if m == model then return true end end
    return false
end

local function notify(description, kind)
    lib.notify({ title = 'DPS Fleet', description = description, type = kind or 'inform' })
end

local CLASS_NAMES = { [0] = 'Compacts', 'Sedans', 'SUVs', 'Coupes', 'Muscle', 'Sports Classics', 'Sports', 'Super', 'Motorcycles', 'Off-road',
    'Industrial', 'Utility', 'Vans', 'Cycles', 'Boats', 'Helicopters', 'Planes', 'Service', 'Emergency', 'Military', 'Commercial', 'Trains', 'Open Wheel' }

-- ── vehicle facts ──────────────────────────────────────────────────────────────

---Model-level facts. Streams the model briefly the first time; cached for the session.
local function readModelInfo(model)
    if INFO[model] then return INFO[model] end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        INFO[model] = { missing = true }
        return INFO[model]
    end
    local loaded = pcall(lib.requestModel, hash, 4000)
    local min, max = GetModelDimensions(hash)
    local info = {
        speed = math.floor(GetVehicleModelMaxSpeed(hash) * 3.6 + 0.5),
        accel = GetVehicleModelAcceleration(hash),
        brake = GetVehicleModelMaxBraking(hash),
        traction = GetVehicleModelMaxTraction(hash),
        seats = GetVehicleModelNumberOfSeats(hash),
        cls = CLASS_NAMES[GetVehicleClassFromName(hash)] or '-',
        make = GetMakeNameFromVehicleModel(hash),
        dims = { l = max.y - min.y, w = max.x - min.x, h = max.z - min.z },
    }
    if loaded then SetModelAsNoLongerNeeded(hash) end
    INFO[model] = info
    local row = BY_MODEL[model]
    if row then
        row.speed, row.seats = info.speed, info.seats
        if info.cls ~= '-' then row.cls = info.cls end
    end
    return info
end

---A live vehicle of this model: the one we sit in (ox_lib cache), else the last one we spawned.
local function liveVehicle(model)
    local hash = joaat(model)
    local veh = cache.vehicle
    if veh and veh ~= 0 and GetEntityModel(veh) == hash then return veh end
    if not lastSpawned or lastSpawned.model ~= model then return nil end
    if not NetworkDoesNetworkIdExist(lastSpawned.netId) then return nil end
    local e = NetworkGetEntityFromNetworkId(lastSpawned.netId)
    if e == 0 or not DoesEntityExist(e) then return nil end
    return e
end

local function readHandling(model)
    local veh = liveVehicle(model)
    if not veh then return HANDLING[model] end
    local rec = {}
    for _, f in ipairs(HandlingFields.floats) do rec[f] = GetVehicleHandlingFloat(veh, 'CHandlingData', f) end
    for _, f in ipairs(HandlingFields.ints) do rec[f] = GetVehicleHandlingInt(veh, 'CHandlingData', f) end
    for _, f in ipairs(HandlingFields.vectors) do
        local v = GetVehicleHandlingVector(veh, 'CHandlingData', f)
        rec[f] = { x = v.x, y = v.y, z = v.z }
    end
    HANDLING[model] = rec
    return rec
end

local function cardInfo(model)
    local row = BY_MODEL[model]
    if not row then return nil end
    local out = {}
    for k, v in pairs(row) do out[k] = v end
    for k, v in pairs(readModelInfo(model)) do out[k] = v end
    out.handling = readHandling(model)
    return out
end

-- ── rows ───────────────────────────────────────────────────────────────────────

local function buildRows(data)
    ALL, BY_MODEL, BY_HASH = {}, {}, {}
    local packs, classes, emergency, photos = data.packs or {}, data.classes or {}, data.emergency or {}, data.photos or {}
    local registry = exports.qbx_core:GetVehiclesByName()
    if type(registry) ~= 'table' then return end
    for model, v in pairs(registry) do
        local em = emergency[model]
        local row = {
            model = model, name = v.name or model, brand = v.brand or '', category = v.category or 'other',
            type = v.type or '-', price = tonumber(v.price) or 0, pack = packs[model] or 'vanilla', cls = classes[model] or '-', make = '',
            photo = photos[model],
        }
        if row.category == 'emergency' then
            row.dept = em and em.dept or 'none'
            row.kind = em and em.kind or 'Other'
        end
        ALL[#ALL + 1] = row
        BY_MODEL[model] = row
        BY_HASH[joaat(model)] = model
    end
end

-- ── open / close ───────────────────────────────────────────────────────────────

local function closePanel()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openPanel(mode)
    if isOpen then return end
    startMode = mode or 'browse'
    -- Static tables travel once per session; later opens only re-check access.
    local ok, data = lib.callback.await('dps-fleet:server:open', false, serverData ~= nil)
    if not ok then
        notify('You do not have access to the fleet browser.', 'error')
        return
    end
    if data then serverData = data end
    if not serverData then serverData = {} end
    buildRows(serverData)
    if #ALL == 0 then
        notify('The vehicle registry is empty; nothing to show.', 'error')
        return
    end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        vehicles = ALL,
        total = #ALL,
        recent = loadList(KVP_RECENT),
        favorites = favList(),
        deptNames = Groups.DEPT_NAME,
        deptCodes = Groups.DEPT_CODE,
        categoryLabels = Groups.CATEGORY_LABEL,
        mode = startMode,
    })
end

local function toggle(mode)
    if isOpen then closePanel() else openPanel(mode) end
end
RegisterCommand('fleet', function() toggle('browse') end, false)
RegisterCommand('carmenu', function() toggle('browse') end, false)   -- alias kept for muscle memory
RegisterCommand('evm', function() toggle('workshop') end, false)     -- alias: opens the workshop side
RegisterKeyMapping('fleet', 'DPS Fleet: open the vehicle browser', 'keyboard', 'F7')
TriggerEvent('chat:addSuggestion', '/fleet', 'Open the DPS fleet panel (browse and workshop)')

-- ── NUI callbacks ──────────────────────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb({ ok = true })
end)

RegisterNUICallback('sections', function(req, cb)
    if type(req) ~= 'table' then cb({ sections = {} }) return end
    local sections = Search.sections(ALL, req.q, { chip = req.chip or 'all', recent = loadList(KVP_RECENT), favorites = favList() })
    cb({ sections = sections })
end)

RegisterNUICallback('info', function(req, cb)
    local model = type(req) == 'table' and req.model or nil
    if not model or not BY_MODEL[model] then cb({ ok = false }) return end
    cb({ ok = true, info = readModelInfo(model), handling = readHandling(model), row = BY_MODEL[model], favorite = isFav(model) })
end)

RegisterNUICallback('spawn', function(req, cb)
    local model = type(req) == 'table' and req.model or nil
    if not model or not BY_MODEL[model] then cb({ ok = false, reason = 'Unknown vehicle.' }) return end
    local mode = req.mode == 'beside' and 'beside' or 'replace'
    local beside
    if mode == 'beside' then
        local base = cache.vehicle or cache.ped
        local len = 5.0
        if cache.vehicle then
            local min, max = GetModelDimensions(GetEntityModel(cache.vehicle))
            len = (max.x - min.x) + 3.0
        end
        local p = GetOffsetFromEntityInWorldCoords(base, len, 0.0, 0.0)
        beside = { x = p.x, y = p.y, z = p.z, w = GetEntityHeading(base) }
    end
    local ok, plate, netId = lib.callback.await('dps-fleet:server:spawn', false, model, mode, beside)
    if not ok then
        cb({ ok = false, reason = plate or 'Spawn failed.' })
        return
    end
    lastSpawned = { netId = netId, model = model }
    if plate and GetResourceState('wasabi_carlock') == 'started' then
        pcall(function() exports.wasabi_carlock:GiveKey(plate) end)
    end
    local recent = pushRecent(model)
    -- the vehicle exists now: read its handling once it has settled
    SetTimeout(250, function() readHandling(model) end)
    cb({ ok = true, plate = plate, recent = recent })
end)

RegisterNUICallback('favorite', function(req, cb)
    local model = type(req) == 'table' and req.model or nil
    if not model or not BY_MODEL[model] then cb({ ok = false }) return end
    local list = favList()
    local found
    for i, m in ipairs(list) do if m == model then found = i end end
    if found then table.remove(list, found) else table.insert(list, 1, model) end
    saveList(KVP_FAV, list)
    cb({ ok = true, favorites = list, on = found == nil })
end)

RegisterNUICallback('card', function(req, cb)
    local info = cardInfo(type(req) == 'table' and req.model or nil)
    if not info then cb({ ok = false, reason = 'Unknown vehicle.' }) return end
    cb({ ok = true, text = Card.format(info) })
end)

RegisterNUICallback('handlingText', function(req, cb)
    local model = type(req) == 'table' and req.model or nil
    if not model then cb({ ok = false, reason = 'Unknown vehicle.' }) return end
    local rec = readHandling(model)
    if not rec then cb({ ok = false, reason = 'Spawn it or sit in it first.' }) return end
    cb({ ok = true, text = Card.handling(rec, HandlingFields, model) })
end)

RegisterNUICallback('delete', function(_, cb)
    local veh = cache.vehicle
    if (not veh or veh == 0) and lastSpawned and NetworkDoesNetworkIdExist(lastSpawned.netId) then
        veh = NetworkGetEntityFromNetworkId(lastSpawned.netId)
    end
    if not veh or veh == 0 or not DoesEntityExist(veh) then cb({ ok = false, reason = 'Nothing to remove.' }) return end
    local ok = lib.callback.await('dps-fleet:server:delete', false, NetworkGetNetworkIdFromEntity(veh))
    cb({ ok = ok == true, reason = ok and nil or 'Could not remove it.' })
end)

-- ── workshop mode ──────────────────────────────────────────────────────────────
-- The panel renders the sheets client/workshop.lua builds; this part only resolves
-- the vehicle, checks access once on open, and hands sheets back.

---Undercover for the neon rule means "listed in Config.UndercoverNeon", the only
---definition this resource has.
local function isUndercoverModel(model)
    local uc = Config.UndercoverNeon
    if not uc or not uc.enabled or type(model) ~= 'string' then return false end
    for _, allowed in ipairs(uc.allowedVehicles or {}) do
        if allowed == model then return true end
    end
    return false
end

---Explicit entity (ox_target, Task 8) > the vehicle we sit in > the last one we
---spawned of this model. Re-run before every workshop call so a deleted vehicle
---is caught instead of handed to a native.
local function resolveWorkshopVehicle(model)
    local explicit = WorkshopClient and WorkshopClient.vehicle and WorkshopClient.vehicle() or nil
    if explicit then return explicit end
    local veh = cache.vehicle
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
    if type(model) == 'string' then return liveVehicle(model) end
    return nil
end

local function wsResolve(model)
    wsVehicle = resolveWorkshopVehicle(model)
    return wsVehicle
end

local function wsSections()
    return Workshop.enabledSections(Config, wsModel, isUndercoverModel(wsModel))
end

local function sectionAllowed(id)
    for _, section in ipairs(wsSections()) do
        if section.id == id then return true end
    end
    return false
end

local NOT_WIRED = { sirens = 'Siren tones are not wired up yet.' }

---The colour swatches, keyed by string so the index-0 entry survives the trip to
---the NUI (a 0-based Lua table is not an array and must not become one).
local COLOUR_HEX_NUI
local function colourHexMap()
    if COLOUR_HEX_NUI then return COLOUR_HEX_NUI end
    COLOUR_HEX_NUI = {}
    for index, hex in pairs(Workshop.COLOUR_HEX or {}) do COLOUR_HEX_NUI[tostring(index)] = hex end
    return COLOUR_HEX_NUI
end

RegisterNUICallback('ws:open', function(req, cb)
    local model = nil
    if type(req) == 'table' and type(req.model) == 'string' and #req.model <= 40 then model = req.model end
    local veh = wsResolve(model)
    if not veh then cb({ ok = false, reason = 'Sit in a vehicle or target one.' }) return end
    wsModel = BY_HASH[GetEntityModel(veh)]

    local ok, why = lib.callback.await('dps-fleet:server:workshopAccess', false)
    if not ok then
        local reason = type(why) == 'string' and why or 'You cannot use the workshop.'
        notify(reason, 'error')
        cb({ ok = false, reason = reason })
        return
    end

    local row = wsModel and BY_MODEL[wsModel] or nil
    local plate = GetVehicleNumberPlateText(veh)
    cb({
        ok = true,
        vehicle = {
            model = wsModel or '-',
            name = row and ((row.brand ~= '' and row.brand .. ' ' or '') .. row.name) or 'This vehicle',
            plate = type(plate) == 'string' and plate:gsub('%s+$', '') or nil,
        },
        sections = wsSections(),
        colourHex = colourHexMap(),
    })
end)

RegisterNUICallback('ws:sheet', function(req, cb)
    local section = type(req) == 'table' and req.section or nil
    if type(section) ~= 'string' or #section > 40 then cb({ ok = false, reason = 'Unknown section.' }) return end
    if not sectionAllowed(section) then cb({ ok = false, reason = 'That section is switched off.' }) return end
    local veh = wsResolve(wsModel)
    if not veh then cb({ ok = false, gone = true, reason = 'That vehicle is gone.' }) return end
    local sheet = WorkshopClient.sheet(veh, section)
    if not sheet then cb({ ok = false, reason = NOT_WIRED[section] or 'Nothing to change here.' }) return end
    cb({ ok = true, sheet = sheet })
end)

RegisterNUICallback('ws:apply', function(req, cb)
    if type(req) ~= 'table' then cb({ ok = false, reason = 'Nothing to apply.' }) return end
    local section, key, value = req.section, req.key, req.value
    if type(section) ~= 'string' or #section > 40 then cb({ ok = false, reason = 'Unknown section.' }) return end
    if type(key) ~= 'string' or #key > 80 then cb({ ok = false, reason = 'Nothing to apply.' }) return end
    local kind = type(value)
    if kind ~= 'nil' and kind ~= 'boolean' and kind ~= 'number' and kind ~= 'string' and kind ~= 'table' then
        cb({ ok = false, reason = 'That value makes no sense.' })
        return
    end
    if not sectionAllowed(section) then cb({ ok = false, reason = 'That section is switched off.' }) return end
    local veh = wsResolve(wsModel)
    if not veh then cb({ ok = false, gone = true, reason = 'That vehicle is gone.' }) return end

    local ok, message = WorkshopClient.apply(veh, section, key, value)
    -- an apply may open an ox_lib dialog, which drops NUI focus on the way out
    if isOpen then SetNuiFocus(true, true) end
    local sheet = DoesEntityExist(veh) and WorkshopClient.sheet(veh, section) or nil
    cb({ ok = ok, message = message, sheet = sheet })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
