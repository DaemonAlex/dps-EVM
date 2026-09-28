--[[
    dps-carmenu server  (Qbox native: qbx.spawnVehicle, qbx.getVehiclePlate, lib.callback)
    Access is the ace `dps.carmenu` (server.cfg grants it to group.admin and group.tester).
    Every callback re-checks the ace; client arguments are validated before use.
    Replace mode removes the vehicle the player sits in first (Damon: "remove anything").

    data/fleet_state.json  — copy of the fleet state file (registry-refresh.sh drops it in at start)
    data/emergency.json    — model -> { dept, kind } for the emergency fleet (committed)
]]

local PACKS, CLASSES, EMERGENCY = {}, {}, {}
-- model (lowercase) -> vehicles.meta game name. LVC keys siren assignments on the
-- game name, not the spawn name, so the workshop needs the pair (Task 6b).
local GAMES = {}
local PHOTOS = nil -- model -> url, filled on first open from jg-vehiclestudio

local function readJson(path)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)
    if not raw then return nil, 'missing' end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return nil, 'unreadable' end
    return data
end

CreateThread(function()
    local state, err = readJson('data/fleet_state.json')
    if not state then
        lib.print.warn(('data/fleet_state.json %s; packs show as vanilla (registry-refresh.sh copies it at start)'):format(err))
    else
        local n = 0
        for model, v in pairs(state) do
            if type(v) == 'table' then
                PACKS[model:lower()] = v.res or 'vanilla'
                if v.class then CLASSES[model:lower()] = tostring(v.class):gsub('^%l', string.upper) end
                if type(v.game) == 'string' and v.game ~= '' then GAMES[model:lower()] = v.game end
                n = n + 1
            end
        end
        lib.print.info(('fleet state loaded: %d models with pack info'):format(n))
    end
    local em, err2 = readJson('data/emergency.json')
    if not em then
        lib.print.warn(('data/emergency.json %s; emergency vehicles show without departments'):format(err2))
    else
        local n = 0
        for model, v in pairs(em) do
            if type(v) == 'table' and v.dept then EMERGENCY[model:lower()] = { dept = v.dept, kind = v.kind or 'Other' }; n = n + 1 end
        end
        lib.print.info(('emergency fleet: %d models with department and kind'):format(n))
    end
end)

---Photo URLs from jg-vehiclestudio (the dealership uses the same export). Once per server run.
local function loadPhotos()
    if PHOTOS then return PHOTOS end
    PHOTOS = {}
    if GetResourceState('jg-vehiclestudio') ~= 'started' then
        lib.print.warn('jg-vehiclestudio not running; no vehicle photos')
        return PHOTOS
    end
    local registry = exports.qbx_core:GetVehiclesByName()
    if type(registry) ~= 'table' then return PHOTOS end
    local codes = {}
    for model in pairs(registry) do codes[#codes + 1] = model end
    local ok, images = pcall(function() return exports['jg-vehiclestudio']:getImages(codes, 'default') end)
    if not ok or type(images) ~= 'table' then
        lib.print.warn(('jg-vehiclestudio getImages failed: %s'):format(tostring(images)))
        return PHOTOS
    end
    -- accept either { model = url }, { model = { url = ... } } or a list of { spawnCode/spawn_code, url/image }
    local n = 0
    for k, v in pairs(images) do
        local model, url
        if type(v) == 'string' then model, url = k, v
        elseif type(v) == 'table' then
            model = type(k) == 'string' and k or (v.spawnCode or v.spawn_code or v.model)
            url = v.url or v.image or v.src
        end
        if type(model) == 'string' and type(url) == 'string' and url ~= '' then PHOTOS[model:lower()] = url; n = n + 1 end
    end
    lib.print.info(('vehicle photos: %d of %d models'):format(n, #codes))
    return PHOTOS
end

local function allowed(src) return IsPlayerAceAllowed(src, 'dps.fleet') end

---Job name and grade level for a connected player, or nil if not loaded.
---@param src number
---@return string|nil jobName, number grade
local function playerJob(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end
    local job = player.PlayerData and player.PlayerData.job
    if not job then return nil end
    return job.name, (job.grade and job.grade.level) or 0
end

-- Job names allowed in the workshop. Derived once at start from qbx_core when
-- Config.AutoJobs is on, else from Config.JobMappings (see the workshop block below).
local WORKSHOP_JOBS = {}

---The workshop job set as derived at start.
---@return table<string, boolean>
local function workshopJobSet() return WORKSHOP_JOBS end

---Whether a player may open the workshop (EVM) panel.
---@param src number
---@return boolean ok, string|nil reason
local function canWorkshop(src)
    local jobName = playerJob(src)
    return Access.canWorkshopSet(jobName, IsPlayerAceAllowed(src, 'command'), workshopJobSet(),
        Config.EnableJobRestrictions ~= false)
end

lib.callback.register('dps-fleet:server:workshopAccess', function(source)
    local ok, why = canWorkshop(source)
    return ok, why
end)

lib.callback.register('dps-fleet:server:open', function(source, alreadyHasData)
    if not allowed(source) then return false end
    if alreadyHasData then return true end
    return true, { packs = PACKS, classes = CLASSES, emergency = EMERGENCY, games = GAMES, photos = loadPhotos() }
end)

local function registryHas(model)
    local reg = exports.qbx_core:GetVehiclesByName()
    return type(reg) == 'table' and reg[model] ~= nil
end

local function removeVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    DeleteEntity(veh)
end

lib.callback.register('dps-fleet:server:spawn', function(source, model, mode, beside)
    if not allowed(source) then return false, 'No access.' end
    if type(model) ~= 'string' or #model > 40 or not registryHas(model) then return false, 'Unknown vehicle.' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'No player ped.' end

    local spawnSource, warp = ped, true
    if mode == 'beside' then
        if type(beside) ~= 'table' or type(beside.x) ~= 'number' or type(beside.y) ~= 'number' or type(beside.z) ~= 'number' then
            return false, 'Bad spawn point.'
        end
        -- the client may only ask for a spot near itself
        if #(GetEntityCoords(ped) - vector3(beside.x, beside.y, beside.z)) > 25.0 then return false, 'Spawn point too far away.' end
        spawnSource = vector4(beside.x + 0.0, beside.y + 0.0, beside.z + 0.0, (tonumber(beside.w) or 0.0) + 0.0)
        warp = false
    else
        local current = GetVehiclePedIsIn(ped, false)
        if current ~= 0 then
            local c, h = GetEntityCoords(current), GetEntityHeading(current)
            removeVehicle(current)
            spawnSource = vector4(c.x, c.y, c.z, h)
            warp = ped -- qbx.spawnVehicle warps this ped when spawnSource is a coordinate
        end
    end

    local started = GetGameTimer()
    local ok, netId = pcall(function()
        local id = qbx.spawnVehicle({ model = model, spawnSource = spawnSource, warp = warp })
        return id
    end)
    if not ok or type(netId) ~= 'number' then
        lib.print.warn(('spawn failed for %s (src %s, %s): %s'):format(model, source, mode, tostring(netId)))
        return false, 'Spawn failed.'
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    local plate = veh ~= 0 and qbx.getVehiclePlate(veh) or nil
    lib.print.info(('spawned %s plate %s for src %s (%s) in %d ms'):format(model, tostring(plate), source, mode, GetGameTimer() - started))
    return true, plate, netId
end)

lib.callback.register('dps-fleet:server:delete', function(source, netId)
    if not allowed(source) then return false end
    if type(netId) ~= 'number' then return false end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not IsEntityAVehicle(veh) then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 30.0 then return false end
    removeVehicle(veh)
    return true
end)

-- ── workshop ──────────────────────────────────────────────────────────────────
--[[
    Server half of the workshop, ported from legacy/evm_server.lua (tables 384-470,
    custom liveries and saved setups 494-760, field repair 879-990, presets and
    livery memory 994-1230, repair charging 1436-1460). The vendor multi-framework
    branches and the framework detector are gone: qbx_core and ox_inventory only.

    Legacy event names are kept so the client halves need no rename; the old
    request/reply event pairs are replaced by ox_lib callbacks. Every handler
    re-checks canWorkshop(source), validates its arguments and — where a netId is
    involved — proves the caller is standing at that vehicle.

    Every vehicle_model is stored lowercase and matched with LOWER(vehicle_model),
    so rows written by the legacy resource in mixed case still resolve.
]]

local MAX_LIVERIES_PER_MODEL = 20
local MAX_PROPS_BYTES = 65535
local REPAIR_KINDS = { full = true, emergency = true, field = true }

-- model (lowercase) -> { { name = string, file = string }, ... }. Seeded from
-- Config.CustomLiveries and the custom_liveries table at start, then kept in step
-- with every add/remove so the callback answers without touching the database.
local CUSTOM_LIVERIES = {}

-- src -> os.time() of the last completed field repair. Plain table, no timers.
local fieldRepairCooldowns = {}

-- src -> true while a check-then-write is in flight. Two fast clicks would
-- otherwise both pass the limit/duplicate check before either row lands.
local busy = {}

---@param src number
---@param title string
---@param description string
---@param kind string|nil ox_lib notify type
local function notify(src, title, description, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = description, type = kind or 'inform', duration = 5000,
    })
end

---A guarded MySQL await: the database going away must not kill a handler.
---Logs one warn line naming the handler so the console points straight at it.
---@param what string handler name for the log line
---@param fn function MySQL.<method>.await
---@param ... any query, parameters
---@return boolean ok, any result
local function db(what, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        lib.print.warn(('%s: database error — %s'):format(what, tostring(result)))
        return false, nil
    end
    return true, result
end

---The one wording every write path uses when the database refuses.
---@param src number
local function dbFailed(src)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Workshop', description = 'Could not save that right now.', type = 'error',
    })
end

---Runs a check-then-write section under the per-player lock, so the lock is
---released whether the body returns, refuses or throws.
---@param src number
---@param what string handler name for the log line
---@param body function
local function underLock(src, what, body)
    if busy[src] then
        return notify(src, 'Workshop', 'Hold on — the last change is still saving.', 'error')
    end
    busy[src] = true
    local ran, err = pcall(body)
    busy[src] = nil
    if not ran then
        lib.print.warn(('%s: failed — %s'):format(what, tostring(err)))
        dbFailed(src)
    end
end

---Model hashes: the natives and joaat disagree on sign for hashes above 2^31,
---so both sides are normalised to unsigned 32-bit before comparing.
---@param veh number
---@param modelName string
---@return boolean
local function vehicleIsModel(veh, modelName)
    return (GetEntityModel(veh) % 0x100000000) == (joaat(modelName) % 0x100000000)
end

---@param model any
---@return string|nil lowercased model name
local function validModel(model)
    if type(model) ~= 'string' then return nil end
    if #model == 0 or #model > 64 then return nil end
    return model:lower()
end

---Config.InputValidation applied to a preset or livery name (legacy Config.ValidateName).
---@param name any
---@return string|nil trimmed, string|nil reason
local function validName(name)
    local iv = Config.InputValidation or {}
    if type(name) ~= 'string' then return nil, 'Invalid name.' end
    local trimmed = name:match('^%s*(.-)%s*$') or ''
    if #trimmed < math.max(iv.minNameLength or 1, 1) then return nil, 'That name is too short.' end
    local maxLen = iv.maxNameLength or 32
    if #trimmed > maxLen then return nil, ('That name is too long (max %d characters).'):format(maxLen) end
    if iv.blockSpecialChars and iv.allowedCharacters and not trimmed:match(iv.allowedCharacters) then
        return nil, 'That name has characters that are not allowed.'
    end
    return trimmed
end

---@param src number
---@return string|nil citizenid
local function citizenidOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

---@param value any a JSON column as oxmysql hands it back
---@return table|nil
local function decodeJson(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return nil end
    local ok, data = pcall(json.decode, value)
    if not ok or type(data) ~= 'table' then return nil end
    return data
end

---A client-supplied netId must map to a vehicle the caller is standing next to
---(legacy ResolveCallerVehicle: stops a client mutating someone else's vehicle).
---@param src number
---@param netId any
---@return number|nil entity
local function resolveCallerVehicle(src, netId)
    if type(netId) ~= 'number' then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not IsEntityAVehicle(veh) then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 10.0 then return nil end
    return veh
end

---@param model string lowercased
---@return table list
local function liveriesFor(model)
    local list = CUSTOM_LIVERIES[model]
    if not list then list = {}; CUSTOM_LIVERIES[model] = list end
    return list
end

-----------------------------------------------------------------------
-- start-up: job set, aces, tables, custom liveries (one thread, then it ends)
-----------------------------------------------------------------------

---Config.JobMappings fallback: every name in every group.
---@return table<string, boolean>
local function jobsFromMappings()
    local set = {}
    for _, names in pairs(Config.JobMappings or {}) do
        for _, name in ipairs(names) do set[name] = true end
    end
    return set
end

local function deriveWorkshopJobs()
    local set, origin
    if Config.AutoJobs then
        local ok, jobs = pcall(function() return exports.qbx_core:GetJobs() end)
        if ok and type(jobs) == 'table' then
            set, origin = {}, 'qbx_core types leo+ems'
            for name, job in pairs(jobs) do
                local kind = type(job) == 'table' and job.type or nil
                if kind == 'leo' or kind == 'ems' then set[name] = true end
            end
            for _, name in ipairs(Config.ExtraWorkshopJobs or {}) do set[name] = true end
        else
            lib.print.warn('qbx_core GetJobs unavailable; workshop jobs fall back to Config.JobMappings')
            set, origin = jobsFromMappings(), 'Config.JobMappings (GetJobs failed)'
        end
    else
        set, origin = jobsFromMappings(), 'Config.JobMappings'
    end

    local names = {}
    for name in pairs(set) do names[#names + 1] = name end
    table.sort(names)
    WORKSHOP_JOBS = set
    lib.print.info(('workshop jobs from %s: %d — %s'):format(origin, #names, table.concat(names, ' ')))
end

local function grantAces()
    if not Config.AutoAces then return end
    local granted = {}
    for _, group in ipairs({ 'group.admin', 'group.tester' }) do
        if IsPrincipalAceAllowed(group, 'dps.fleet') then
            granted[#granted + 1] = group .. '=already'
        else
            ExecuteCommand(('add_ace %s dps.fleet allow'):format(group))
            granted[#granted + 1] = group .. '=granted'
        end
    end
    lib.print.info(('dps.fleet ace: %s'):format(table.concat(granted, ' ')))
end

local WORKSHOP_TABLES = {
    custom_liveries = [[
        CREATE TABLE IF NOT EXISTS custom_liveries (
            id INT NOT NULL AUTO_INCREMENT,
            vehicle_model VARCHAR(255) NOT NULL,
            livery_name VARCHAR(255) NOT NULL,
            livery_file VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        )
    ]],
    vehicle_mods = [[
        CREATE TABLE IF NOT EXISTS vehicle_mods (
            id INT NOT NULL AUTO_INCREMENT,
            vehicle_model VARCHAR(255) NOT NULL,
            extras TEXT,
            player_id VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY vehicle_model_unique (vehicle_model)
        )
    ]],
    vehicle_presets = [[
        CREATE TABLE IF NOT EXISTS vehicle_presets (
            id INT NOT NULL AUTO_INCREMENT,
            preset_name VARCHAR(100) NOT NULL,
            vehicle_model VARCHAR(255) NOT NULL,
            owner_identifier VARCHAR(255) NOT NULL,
            job_preset VARCHAR(50) DEFAULT NULL,
            preset_data JSON NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY unique_preset (owner_identifier, preset_name, vehicle_model),
            INDEX idx_job_preset (job_preset)
        )
    ]],
    player_livery_memory = [[
        CREATE TABLE IF NOT EXISTS player_livery_memory (
            id INT NOT NULL AUTO_INCREMENT,
            identifier VARCHAR(255) NOT NULL,
            vehicle_model VARCHAR(255) NOT NULL,
            livery_index INT DEFAULT -1,
            livery_mod INT DEFAULT -1,
            custom_livery VARCHAR(255) DEFAULT NULL,
            extras JSON DEFAULT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY unique_memory (identifier, vehicle_model)
        )
    ]],
    -- Task 6b: which LVC tones a siren key is allowed. Keyed on the siren key
    -- (the game name cut to the 11 characters GTA keeps), not the spawn name, so
    -- every spawn code sharing one yft shares one row — the way LVC reads it.
    fleet_siren_assignments = [[
        CREATE TABLE IF NOT EXISTS fleet_siren_assignments (
            -- utf8mb4_bin: siren keys are case-sensitive in LVC, and the default
            -- collation would make FIRETRUK and firetruk the same primary key.
            siren_key VARCHAR(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
            model VARCHAR(64),
            tones JSON NOT NULL,
            updated_by VARCHAR(64),
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (siren_key)
        )
    ]],
}
local WORKSHOP_TABLE_ORDER = { 'custom_liveries', 'vehicle_mods', 'vehicle_presets', 'player_livery_memory', 'fleet_siren_assignments' }

local function ensureTables()
    local made, failed = {}, {}
    for _, name in ipairs(WORKSHOP_TABLE_ORDER) do
        local ok = db('ensureTables ' .. name, MySQL.query.await, WORKSHOP_TABLES[name])
        if ok then made[#made + 1] = name else failed[#failed + 1] = name end
    end
    -- One custom livery name per model is a database rule, not a race: with this key
    -- INSERT IGNORE in addCustomLivery reports affectedRows 0 instead of a second row.
    -- MariaDB syntax; it fails harmlessly if the table already holds duplicates.
    local keyOk = db('ensureTables uq_model_livery', MySQL.query.await,
        'ALTER TABLE custom_liveries ADD UNIQUE KEY IF NOT EXISTS uq_model_livery (vehicle_model, livery_name)')
    if not keyOk then failed[#failed + 1] = 'uq_model_livery' end
    lib.print.info(('workshop tables ready: %s (uq_model_livery %s)'):format(
        table.concat(made, ' '), keyOk and 'ok' or 'FAILED'))
    if not keyOk then
        lib.print.warn('uq_model_livery is missing: duplicate custom livery names are only caught in memory, not by the database')
    end
    if #failed > 0 then lib.print.warn(('workshop tables FAILED: %s'):format(table.concat(failed, ' '))) end
    return #failed == 0
end

local function loadCustomLiveries()
    local seeded = 0
    for model, list in pairs(Config.CustomLiveries or {}) do
        if type(list) == 'table' then
            local target = liveriesFor(tostring(model):lower())
            for _, entry in ipairs(list) do
                if type(entry) == 'table' and entry.file then
                    target[#target + 1] = { name = entry.name or entry.file, file = entry.file }
                    seeded = seeded + 1
                end
            end
        end
    end

    local ok, rows = db('loadCustomLiveries', MySQL.query.await,
        'SELECT vehicle_model, livery_name, livery_file FROM custom_liveries')
    if not ok then
        lib.print.info(('custom liveries: %d from config, database unavailable'):format(seeded))
        return
    end
    local loaded = 0
    for _, row in ipairs(rows or {}) do
        local model = validModel(row.vehicle_model)
        if model and row.livery_file then
            local target = liveriesFor(model)
            target[#target + 1] = { name = row.livery_name or row.livery_file, file = row.livery_file }
            loaded = loaded + 1
        end
    end
    lib.print.info(('custom liveries: %d from config, %d from the database'):format(seeded, loaded))
end

-----------------------------------------------------------------------
-- sirens (Task 6b)
--
-- dps-fleet owns the assignment, LVC owns the sound. The workshop writes a tone
-- list per siren key; the whole table is cached here, handed to every client at
-- their resource start and patched by a broadcast on every write, and LVC's
-- credited hook (lvc/UTIL/cl_utils.lua) merges it over its own SIRENS.lua table.
-----------------------------------------------------------------------

-- siren key -> tone id list, the live cache. Filled at start, patched on write.
local SIREN_BY_KEY = {}
-- The copy handed out to callbacks and the export, so nothing outside can edit
-- the cache. Rebuilt on the first read after a change, never per call.
local sirenSnapshot = nil

---@return table<string, number[]>
local function sirenAssignments()
    if sirenSnapshot then return sirenSnapshot end
    local out = {}
    for key, tones in pairs(SIREN_BY_KEY) do
        local copy = {}
        for i, id in ipairs(tones) do copy[i] = id end
        out[key] = copy
    end
    sirenSnapshot = out
    return out
end

local function loadSirenAssignments()
    local ok, rows = db('loadSirenAssignments', MySQL.query.await,
        'SELECT siren_key, tones FROM fleet_siren_assignments')
    if not ok then
        lib.print.warn('siren assignments: database unavailable; LVC keeps its SIRENS.lua table')
        return
    end
    local loaded, rejected = 0, 0
    for _, row in ipairs(rows or {}) do
        local tones = decodeJson(row.tones)
        if type(row.siren_key) == 'string' and Workshop.validTones(tones, #Workshop.SIREN_TONES) then
            SIREN_BY_KEY[row.siren_key] = tones
            loaded = loaded + 1
        else
            rejected = rejected + 1
        end
    end
    sirenSnapshot = nil
    lib.print.info(('siren assignments: %d keys loaded, %d rows rejected (of %d tones)'):format(
        loaded, rejected, #Workshop.SIREN_TONES))
end

---A game name as read off a live vehicle. GTA keeps 11 characters of it, so the
---client can only ever send a short, plain token; anything else is refused.
---@param name any
---@return string|nil
local function validGameName(name)
    if type(name) ~= 'string' then return nil end
    if #name < 1 or #name > 64 then return nil end
    if not name:match('^[%w_%-%.]+$') then return nil end
    return name
end

---The siren key for a model. GetDisplayNameFromVehicleModel is what LVC looks the
---assignment up by, so the name the client read off the live vehicle wins; the
---registry game name from data/fleet_state.json answers when there is none (that
---file is keyed on the spawn name and does not cover every model), and the spawn
---name itself is the last resort.
---@param model string lowercased model name
---@param gameName any what the client read off the vehicle, unvalidated
---@return string|nil
local function sirenKeyFor(model, gameName)
    return Workshop.sirenKey(validGameName(gameName) or GAMES[model], model)
end

-- The sheet asks for one model: its key, what is saved for it and which preset
-- that is. nil tones mean nothing is saved and LVC still uses SIRENS.lua.
lib.callback.register('dps-fleet:server:sirens', function(source, modelName, gameName)
    if not canWorkshop(source) then return false end
    local model = validModel(modelName)
    if not model then return false end
    local key = sirenKeyFor(model, gameName)
    if not key then return false end
    local tones = sirenAssignments()[key]
    return { key = key, model = model, tones = tones, preset = tones and Workshop.sirenPresetOf(tones) or nil }
end)

-- Every client caches the whole table for LVC, so this one is not workshop-gated:
-- a player with no workshop access still drives vehicles whose tones were set.
lib.callback.register('dps-fleet:server:allSirens', function()
    return sirenAssignments()
end)

lib.callback.register('dps-fleet:server:setSirens', function(source, modelName, tones, gameName)
    local src = source
    if not canWorkshop(src) then return false, 'You may not change siren tones.' end
    local model = validModel(modelName)
    if not model then return false, 'That vehicle model is not valid.' end
    if not Workshop.validTones(tones, #Workshop.SIREN_TONES) then
        return false, ('Siren tones must be 1 to %d whole numbers between 1 and %d.'):format(
            Workshop.SIREN_SLOT_MAX, #Workshop.SIREN_TONES)
    end
    local key = sirenKeyFor(model, gameName)
    if not key then return false, 'That vehicle has no siren key.' end
    local citizenid = citizenidOf(src)

    -- Never store the client's table: rebuild it as plain integers.
    local list = {}
    for i, id in ipairs(tones) do list[i] = math.floor(id) end
    local encoded = json.encode(list)

    -- underLock owns the pcall and the per-player lock, so the result comes back
    -- through this flag; the panel shows the message, db() logs the reason.
    local saved = false
    underLock(src, 'setSirens', function()
        local ok = db('setSirens', MySQL.insert.await, [[
            INSERT INTO fleet_siren_assignments (siren_key, model, tones, updated_by)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE tones = VALUES(tones), model = VALUES(model), updated_by = VALUES(updated_by)
        ]], { key, model, encoded, citizenid })
        if not ok then return end
        SIREN_BY_KEY[key] = list
        sirenSnapshot = nil
        TriggerClientEvent('dps-fleet:client:sirens', -1, { key = key, tones = list })
        saved = true
        lib.print.info(('siren tones for %s (key %s) set to %s by %s (src %s)'):format(
            model, key, table.concat(list, ','), citizenid or 'unknown', src))
    end)
    if not saved then return false, 'Could not save those tones right now.' end
    return true
end)

---Server-side reader for other resources (dispatch, MDT, a future fleet report).
---Returns a copy: the cache is ours.
exports('GetSirenAssignments', function() return sirenAssignments() end)

CreateThread(function()
    while GetResourceState('qbx_core') ~= 'started' do Wait(200) end
    deriveWorkshopJobs()
    grantAces()
    MySQL.ready.await() -- the resource being started is not enough: this waits for the connection too
    if ensureTables() then
        loadCustomLiveries()
        loadSirenAssignments()
    end
end)

-----------------------------------------------------------------------
-- custom liveries (legacy 494-560, 571-745)
-----------------------------------------------------------------------

RegisterNetEvent('vehiclemods:server:applyCustomLivery', function(netId, modelName, liveryFile)
    local src = source
    if not canWorkshop(src) then return notify(src, 'Access denied', 'You may not modify vehicles.', 'error') end
    local model = validModel(modelName)
    if not model then return notify(src, 'Custom livery', 'That vehicle model is not valid.', 'error') end
    local veh = resolveCallerVehicle(src, netId)
    if not veh then
        return notify(src, 'Custom livery', 'That vehicle is not in reach.', 'error')
    end
    if not vehicleIsModel(veh, model) then
        return notify(src, 'Custom livery', 'That livery belongs to a different vehicle.', 'error')
    end
    if not Workshop.isSafeLiveryFile(liveryFile) then
        return notify(src, 'Custom livery', 'That livery file is not allowed.', 'error')
    end
    TriggerClientEvent('vehiclemods:client:setCustomLivery', -1, netId, modelName, liveryFile)
    lib.print.info(('custom livery %s applied to %s (netId %s) by src %s'):format(liveryFile, model, netId, src))
end)

RegisterNetEvent('vehiclemods:server:clearCustomLivery', function(netId)
    local src = source
    if not canWorkshop(src) then return notify(src, 'Access denied', 'You may not modify vehicles.', 'error') end
    if not resolveCallerVehicle(src, netId) then
        return notify(src, 'Custom livery', 'That vehicle is not in reach.', 'error')
    end
    TriggerClientEvent('vehiclemods:client:clearCustomLivery', -1, netId)
    lib.print.info(('custom livery cleared from netId %s by src %s'):format(netId, src))
end)

RegisterNetEvent('vehiclemods:server:addCustomLivery', function(modelName, liveryName, liveryFile)
    local src = source
    if not canWorkshop(src) then return notify(src, 'Access denied', 'You may not add liveries.', 'error') end
    local model = validModel(modelName)
    if not model then return notify(src, 'Custom livery', 'That vehicle model is not valid.', 'error') end
    local name, nameWhy = validName(liveryName)
    if not name then return notify(src, 'Custom livery', nameWhy, 'error') end
    if type(liveryFile) ~= 'string' then return notify(src, 'Custom livery', 'That livery file is not allowed.', 'error') end
    if not liveryFile:match('%.yft$') then liveryFile = liveryFile .. '.yft' end
    if not Workshop.isSafeLiveryFile(liveryFile) then
        return notify(src, 'Custom livery', 'That livery file is not allowed.', 'error')
    end

    underLock(src, 'addCustomLivery', function()
        local list = liveriesFor(model)
        if #list >= MAX_LIVERIES_PER_MODEL then
            return notify(src, 'Custom livery', ('%s already has the maximum of %d custom liveries.'):format(model, MAX_LIVERIES_PER_MODEL), 'error')
        end
        for _, entry in ipairs(list) do
            if entry.name == name then
                return notify(src, 'Custom livery', ('%s already has a livery called "%s".'):format(model, name), 'error')
            end
        end

        -- INSERT IGNORE + the unique key: the database, not this check, decides.
        local ok, affected = db('addCustomLivery', MySQL.update.await,
            'INSERT IGNORE INTO custom_liveries (vehicle_model, livery_name, livery_file) VALUES (?, ?, ?)',
            { model, name, liveryFile })
        if not ok then return dbFailed(src) end
        if (tonumber(affected) or 0) == 0 then
            return notify(src, 'Custom livery', ('%s already has a livery called "%s".'):format(model, name), 'error')
        end

        list[#list + 1] = { name = name, file = liveryFile }
        notify(src, 'Custom livery added', ('"%s" added for %s.'):format(name, model), 'success')
        lib.print.info(('custom livery "%s" (%s) added for %s by src %s'):format(name, liveryFile, model, src))
    end)
end)

RegisterNetEvent('vehiclemods:server:removeCustomLivery', function(modelName, liveryName)
    local src = source
    if not canWorkshop(src) then return notify(src, 'Access denied', 'You may not remove liveries.', 'error') end
    local model = validModel(modelName)
    if not model then return notify(src, 'Custom livery', 'That vehicle model is not valid.', 'error') end
    if type(liveryName) ~= 'string' or #liveryName == 0 or #liveryName > 255 then
        return notify(src, 'Custom livery', 'That livery name is not valid.', 'error')
    end

    underLock(src, 'removeCustomLivery', function()
        local function indexOf()
            for i, entry in ipairs(liveriesFor(model)) do
                if entry.name == liveryName then return i end
            end
            return nil
        end

        if not indexOf() then
            return notify(src, 'Custom livery', ('%s has no livery called "%s".'):format(model, liveryName), 'error')
        end

        -- the row goes first: a failed DELETE must not leave the store out of step
        local ok = db('removeCustomLivery', MySQL.query.await,
            'DELETE FROM custom_liveries WHERE LOWER(vehicle_model) = ? AND livery_name = ?', { model, liveryName })
        if not ok then return dbFailed(src) end

        -- the DELETE yields, so the index found before it is stale: look the entry up
        -- again rather than removing whatever now sits at the old position
        local at = indexOf()
        if at then table.remove(liveriesFor(model), at) end
        notify(src, 'Custom livery removed', ('"%s" removed from %s.'):format(liveryName, model), 'success')
        lib.print.info(('custom livery "%s" removed from %s by src %s'):format(liveryName, model, src))
    end)
end)

lib.callback.register('dps-fleet:server:customLiveries', function(source, modelName)
    if not canWorkshop(source) then return false end
    local model = validModel(modelName)
    if not model then return false end
    return CUSTOM_LIVERIES[model] or {}
end)

-----------------------------------------------------------------------
-- saved vehicle setups (legacy 538-568, 636-665)
-----------------------------------------------------------------------

RegisterNetEvent('vehiclemods:server:saveModifications', function(modelName, props)
    local src = source
    if not canWorkshop(src) then return end
    local model = validModel(modelName)
    if not model then return end
    if type(props) ~= 'table' then return end
    local encoded = json.encode(props)
    if type(encoded) ~= 'string' or #encoded > MAX_PROPS_BYTES then
        return notify(src, 'Vehicle setup', 'That setup is too large to save.', 'error')
    end

    local ok = db('saveModifications', MySQL.query.await, [[
        INSERT INTO vehicle_mods (vehicle_model, extras, player_id) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE extras = VALUES(extras), player_id = VALUES(player_id)
    ]], { model, encoded, tostring(citizenidOf(src) or src) })
    if not ok then return dbFailed(src) end
    lib.print.info(('vehicle_mods saved for %s by src %s (%d bytes)'):format(model, src, #encoded))
end)

lib.callback.register('dps-fleet:server:vehicleConfig', function(source, modelName)
    if not canWorkshop(source) then return false end
    local model = validModel(modelName)
    if not model then return false end
    local ok, row = db('vehicleConfig', MySQL.single.await,
        'SELECT extras FROM vehicle_mods WHERE LOWER(vehicle_model) = ? LIMIT 1', { model })
    if not ok or not row then return false end
    return decodeJson(row.extras) or false
end)

-----------------------------------------------------------------------
-- presets (legacy 985-1175)
-- personal presets belong to a citizenid, job presets to a job name.
-----------------------------------------------------------------------

RegisterNetEvent('vehiclemods:server:savePreset', function(presetName, modelName, presetData, isJob)
    local src = source
    if not canWorkshop(src) then return end
    local model = validModel(modelName)
    if not model then return end
    local name, nameWhy = validName(presetName)
    if not name then return notify(src, 'Preset', nameWhy, 'error') end
    if type(presetData) ~= 'table' then return notify(src, 'Preset', 'There is nothing to save.', 'error') end

    local encoded = json.encode(presetData)
    local maxBytes = (Config.Presets and Config.Presets.maxPresetBytes) or 16384
    if type(encoded) ~= 'string' or #encoded > maxBytes then
        return notify(src, 'Preset', 'That preset is too large.', 'error')
    end

    local identifier = citizenidOf(src)
    if not identifier then return notify(src, 'Preset', 'Your character is not loaded yet.', 'error') end
    local jobName, grade = playerJob(src)

    local kind = isJob == true and 'job' or 'personal'
    local jobPreset
    if kind == 'job' then
        if not jobName then return notify(src, 'Preset', 'You have no job to share a preset with.', 'error') end
        jobPreset = jobName
    end

    underLock(src, 'savePreset', function()
        local countOk, countRow
        if kind == 'job' then
            countOk, countRow = db('savePreset count', MySQL.single.await,
                'SELECT COUNT(*) AS n FROM vehicle_presets WHERE job_preset = ?', { jobPreset })
        else
            countOk, countRow = db('savePreset count', MySQL.single.await,
                'SELECT COUNT(*) AS n FROM vehicle_presets WHERE owner_identifier = ? AND job_preset IS NULL', { identifier })
        end
        if not countOk then return dbFailed(src) end
        local count = countRow and tonumber(countRow.n) or 0

        local allowed, why = Workshop.presetAllowed(kind, count, grade or 0, Config)
        if not allowed then return notify(src, 'Preset', why or 'That preset is not allowed.', 'error') end

        -- NULLIF keeps job_preset NULL for a personal preset without binding a nil
        -- in the middle of the parameter list (oxmysql leaves a hole there).
        local ok = db('savePreset', MySQL.query.await, [[
            INSERT INTO vehicle_presets (preset_name, vehicle_model, owner_identifier, job_preset, preset_data)
            VALUES (?, ?, ?, NULLIF(?, ''), ?)
            ON DUPLICATE KEY UPDATE preset_data = VALUES(preset_data), job_preset = VALUES(job_preset),
                updated_at = CURRENT_TIMESTAMP
        ]], { name, model, identifier, jobPreset or '', encoded })
        if not ok then return dbFailed(src) end
        notify(src, 'Preset saved', ('"%s" saved for %s.'):format(name, model), 'success')
        lib.print.info(('%s preset "%s" saved for %s by %s (src %s, %d bytes)'):format(kind, name, model, identifier, src, #encoded))
    end)
end)

lib.callback.register('dps-fleet:server:presets', function(source, modelName)
    if not canWorkshop(source) then return false end
    local model = validModel(modelName)
    if not model then return false end
    local identifier = citizenidOf(source)
    if not identifier then return false end
    local jobName = playerJob(source)

    local ok, rows = db('presets', MySQL.query.await, [[
        SELECT preset_name, preset_data, job_preset, owner_identifier
        FROM vehicle_presets
        WHERE LOWER(vehicle_model) = ? AND (owner_identifier = ? OR job_preset = ?)
        ORDER BY job_preset IS NOT NULL DESC, preset_name ASC
    ]], { model, identifier, jobName or '' })
    if not ok then return false end

    local out = {}
    for _, row in ipairs(rows or {}) do
        local isJob = row.job_preset ~= nil
        out[#out + 1] = {
            name = row.preset_name,
            data = decodeJson(row.preset_data),
            isJob = isJob,
            isJobPreset = isJob, -- client/workshop.lua reads isJobPreset for the [Fleet] tag
            isOwner = row.owner_identifier == identifier,
        }
    end
    return out
end)

RegisterNetEvent('vehiclemods:server:deletePreset', function(presetName, modelName)
    local src = source
    if not canWorkshop(src) then return end
    local model = validModel(modelName)
    if not model then return end
    if type(presetName) ~= 'string' or #presetName == 0 or #presetName > 100 then
        return notify(src, 'Preset', 'That preset name is not valid.', 'error')
    end
    local identifier = citizenidOf(src)
    if not identifier then return notify(src, 'Preset', 'Your character is not loaded yet.', 'error') end
    local jobName, grade = playerJob(src)

    local found, row = db('deletePreset lookup', MySQL.single.await, [[
        SELECT id, owner_identifier, job_preset FROM vehicle_presets
        WHERE preset_name = ? AND LOWER(vehicle_model) = ? AND (owner_identifier = ? OR job_preset = ?)
        LIMIT 1
    ]], { presetName, model, identifier, jobName or '' })
    if not found then return dbFailed(src) end
    if not row then
        return notify(src, 'Preset', ('%s has no preset called "%s".'):format(model, presetName), 'error')
    end

    local minGrade = (Config.Presets and Config.Presets.minGradeForJobPresets) or 0
    local isOwner = row.owner_identifier == identifier
    local canDeleteJobPreset = row.job_preset ~= nil and row.job_preset == jobName and (grade or 0) >= minGrade
    if not (isOwner or canDeleteJobPreset) then
        return notify(src, 'Preset', ('Only the owner or grade %d and above can delete that preset.'):format(minGrade), 'error')
    end

    local ok = db('deletePreset', MySQL.query.await, 'DELETE FROM vehicle_presets WHERE id = ?', { row.id })
    if not ok then return dbFailed(src) end
    notify(src, 'Preset deleted', ('"%s" deleted.'):format(presetName), 'success')
    lib.print.info(('preset "%s" (%s) deleted by %s (src %s)'):format(presetName, model, identifier, src))
end)

-----------------------------------------------------------------------
-- livery memory (legacy 1177-1245)
-----------------------------------------------------------------------

RegisterNetEvent('vehiclemods:server:saveLiveryMemory', function(modelName, liveryIndex, liveryMod, customLivery, extras)
    local src = source
    if not canWorkshop(src) then return end
    local cfg = Config.AutoApplyLivery
    if not cfg or not cfg.enabled then return end
    local model = validModel(modelName)
    if not model then return end
    local identifier = citizenidOf(src)
    if not identifier then return end

    -- the client sends the whole ActiveCustomLiveries entry here; keep the file only
    if type(customLivery) == 'table' then customLivery = customLivery.file end
    if type(customLivery) ~= 'string' or not Workshop.isSafeLiveryFile(customLivery) then customLivery = nil end
    local extrasJson = type(extras) == 'table' and json.encode(extras) or nil

    local ok = db('saveLiveryMemory', MySQL.query.await, [[
        INSERT INTO player_livery_memory (identifier, vehicle_model, livery_index, livery_mod, custom_livery, extras)
        VALUES (?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''))
        ON DUPLICATE KEY UPDATE
            livery_index = VALUES(livery_index),
            livery_mod = VALUES(livery_mod),
            custom_livery = VALUES(custom_livery),
            extras = VALUES(extras),
            updated_at = CURRENT_TIMESTAMP
    ]], { identifier, model, tonumber(liveryIndex) or -1, tonumber(liveryMod) or -1,
          customLivery or '', extrasJson or '' })
    if not ok then return dbFailed(src) end
    lib.print.info(('livery memory saved for %s on %s (livery %s, mod %s, custom %s)'):format(
        identifier, model, tostring(tonumber(liveryIndex) or -1), tostring(tonumber(liveryMod) or -1), customLivery or 'none'))
end)

lib.callback.register('dps-fleet:server:liveryMemory', function(source, modelName)
    if not canWorkshop(source) then return false end
    local cfg = Config.AutoApplyLivery
    if not cfg or not cfg.enabled then return false end
    local model = validModel(modelName)
    if not model then return false end
    local identifier = citizenidOf(source)
    if not identifier then return false end

    local ok, row = db('liveryMemory', MySQL.single.await, [[
        SELECT livery_index, livery_mod, custom_livery, extras FROM player_livery_memory
        WHERE identifier = ? AND LOWER(vehicle_model) = ?
    ]], { identifier, model })
    if not ok or not row then return false end
    return {
        liveryIndex = tonumber(row.livery_index) or -1,
        liveryMod = tonumber(row.livery_mod) or -1,
        customLivery = row.custom_livery,
        extras = decodeJson(row.extras),
    }
end)

-----------------------------------------------------------------------
-- repairs (legacy 879-990 field repair, 1436-1460 charging)
-- The price is always derived server-side from Config; the client never sends one.
-----------------------------------------------------------------------

lib.callback.register('dps-fleet:server:repairQuote', function(source)
    if not canWorkshop(source) then return false end
    local jobName = playerJob(source)
    return {
        emergency = Workshop.repairPrice('emergency', jobName, Config),
        full = Workshop.repairPrice('full', jobName, Config),
        field = Workshop.repairPrice('field', jobName, Config),
    }
end)

---@param src number
---@param kind string 'full'|'emergency'|'field'
---@return boolean ok, string|nil reason
local function chargeRepair(src, kind)
    if not REPAIR_KINDS[kind] then return false, 'That repair type does not exist.' end
    local rc = Config.RepairCosts
    if not rc or rc.enabled == false then return true end

    local jobName = playerJob(src)
    local price = Workshop.repairPrice(kind, jobName, Config)
    if price <= 0 then
        lib.print.info(('%s repair free for src %s (job %s)'):format(kind, src, jobName or 'none'))
        return true
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Your character is not loaded yet.' end
    local bank = tonumber(player.Functions.GetMoney('bank')) or 0
    local cash = tonumber(player.Functions.GetMoney('cash')) or 0

    local plan = Workshop.chargePlan(price, bank, cash, rc.chargeFrom or 'bank')
    if not plan then return false, ('Not enough money — $%d needed.'):format(price) end
    if plan.amount > 0 and not player.Functions.RemoveMoney(plan.account, plan.amount, 'fleet-repair') then
        return false, 'The payment did not go through.'
    end
    notify(src, 'Repair payment', ('$%d charged from %s.'):format(plan.amount, plan.account), 'success')
    lib.print.info(('%s repair charged $%d from %s for src %s (job %s)'):format(kind, plan.amount, plan.account, src, jobName or 'none'))
    return true
end

lib.callback.register('dps-fleet:server:chargeRepair', function(source, kind)
    if not canWorkshop(source) then return false, 'You may not repair vehicles here.' end
    return chargeRepair(source, kind)
end)

lib.callback.register('dps-fleet:server:fieldRepair', function(source)
    local src = source
    if not canWorkshop(src) then return false, 'You may not repair vehicles here.' end
    local cfg = Config.FieldRepair
    if not cfg or not cfg.enabled then return false, 'Field repair is switched off.' end

    local now = os.time()
    local cooldown = math.floor((tonumber(cfg.cooldown) or 0) / 1000)
    local last = fieldRepairCooldowns[src]
    if last and (now - last) < cooldown then
        return false, ('Field repair is on cooldown for another %d seconds.'):format(cooldown - (now - last))
    end

    local jobName, grade = playerJob(src)
    local jobs = cfg.allowedJobs or {}
    if #jobs > 0 then
        local jobOk = false
        for _, name in ipairs(jobs) do
            if name == jobName then jobOk = true; break end
        end
        if not jobOk then return false, 'Your job does not do field repairs.' end
    end
    local minGrade = tonumber(cfg.minGrade) or 0
    if minGrade > 0 and (grade or 0) < minGrade then
        return false, ('Field repair needs job grade %d or higher.'):format(minGrade)
    end

    local item
    if cfg.requireItem then
        if GetResourceState('ox_inventory') ~= 'started' then return false, 'The inventory is not running.' end
        for _, name in ipairs(cfg.alternativeItems or { cfg.itemName }) do
            local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', name) end)
            if ok and (tonumber(count) or 0) > 0 then item = name; break end
        end
        if not item then return false, 'You need a repair kit for that.' end
    end

    local paid, why = chargeRepair(src, 'field')
    if not paid then return false, why or 'The payment did not go through.' end

    if item and cfg.consumeItem then exports.ox_inventory:RemoveItem(src, item, 1) end
    fieldRepairCooldowns[src] = now
    lib.print.info(('field repair approved for src %s (job %s, grade %s, kit %s)'):format(
        src, jobName or 'none', tostring(grade or 0), item or 'none'))
    return true
end)

AddEventHandler('playerDropped', function()
    fieldRepairCooldowns[source] = nil
    busy[source] = nil
end)
