--[[
    dps-carmenu server  (Qbox native: qbx.spawnVehicle, qbx.getVehiclePlate, lib.callback)
    Access is the ace `dps.carmenu` (server.cfg grants it to group.admin and group.tester).
    Every callback re-checks the ace; client arguments are validated before use.
    Replace mode removes the vehicle the player sits in first (Damon: "remove anything").

    data/fleet_state.json  — copy of the fleet state file (registry-refresh.sh drops it in at start)
    data/emergency.json    — model -> { dept, kind } for the emergency fleet (committed)
]]

local PACKS, CLASSES, EMERGENCY = {}, {}, {}
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

---Whether a player may open the workshop (EVM) panel.
---@param src number
---@return boolean ok, string|nil reason
local function canWorkshop(src)
    local jobName = playerJob(src)
    return Access.canWorkshop(jobName, IsPlayerAceAllowed(src, 'command'), Config)
end

lib.callback.register('dps-fleet:server:workshopAccess', function(source)
    local ok, why = canWorkshop(source)
    return ok, why
end)

lib.callback.register('dps-fleet:server:open', function(source, alreadyHasData)
    if not allowed(source) then return false end
    if alreadyHasData then return true end
    return true, { packs = PACKS, classes = CLASSES, emergency = EMERGENCY, photos = loadPhotos() }
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
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 30.0 then return false end
    removeVehicle(veh)
    return true
end)
