--[[
    dps-fleet client/workshop.lua

    The EVM workshop, as data. Every ox_lib context menu from legacy/evm_client.lua
    is gone; each section is now a builder that reads the live vehicle and returns
    a flat list of option descriptors, and one apply function that performs the
    native the old menu performed. The panel (Task 5) renders the sheets.

      WorkshopClient.sheet(veh, sectionId)            -> { id, title, options } | nil
      WorkshopClient.apply(veh, sectionId, key, value) -> ok, message
      WorkshopClient.props / applyProps                -> GetVehicleProperties / ApplyVehicleProperties
      WorkshopClient.config / applyConfig              -> the preset_data shape
      WorkshopClient.persist(veh)                      -> vehiclemods:server:saveModifications

    Option kinds: toggle | pick | stepper | action | colour. Nothing here notifies;
    the message comes back through the return value so the panel owns the feedback.

    Performance: no threads. Builders touch natives only when a sheet is asked for,
    SetVehicleModKit runs once per apply, and the colour list is built once.

    Ported from legacy/evm_client.lua: liveries 336-499, custom liveries 502-726,
    performance 891-1050, extras 1053-1099, doors 1102-1176, windows 1182-1304,
    seats 1305-1457, tint 1506-1554, neon 1557-1730, colours 1733-1910,
    wheels 1913-2083, properties 2148-2362, presets 2989-3198,
    livery memory 3208-3233 and livery labels 3444-3510.
]]

WorkshopClient = WorkshopClient or {}

-- netId -> { file, dict, model } for vehicles wearing a custom YFT livery.
ActiveCustomLiveries = ActiveCustomLiveries or {}

local TEXTURE_LOAD_TIMEOUT = 300   -- 10 ms ticks, as EVM used
local loadedTextures = {}
local liveryLabelCache = {}

local SECTION_TITLE = {}
for _, section in ipairs(Workshop.SECTIONS) do SECTION_TITLE[section.id] = section.label end

local DOOR_LABELS = { [0] = 'Driver door', [1] = 'Passenger door', [2] = 'Rear driver door', [3] = 'Rear passenger door', [4] = 'Hood', [5] = 'Trunk' }
local SEAT_NAMES = { [-1] = 'Driver', [0] = 'Front passenger', [1] = 'Rear left', [2] = 'Rear right' }
local NEON_SIDES = { { key = 'left', index = 0, label = 'Left' }, { key = 'right', index = 1, label = 'Right' }, { key = 'front', index = 2, label = 'Front' }, { key = 'back', index = 3, label = 'Back' } }
local NEON_INDEX = { left = 0, right = 1, front = 2, back = 3 }

-- EVM's neon palette (legacy 1680-1693), unchanged.
local NEON_COLOURS = {
    { label = 'White', r = 255, g = 255, b = 255 },
    { label = 'Blue', r = 0, g = 0, b = 255 },
    { label = 'Electric blue', r = 0, g = 150, b = 255 },
    { label = 'Mint green', r = 50, g = 255, b = 155 },
    { label = 'Lime green', r = 0, g = 255, b = 0 },
    { label = 'Yellow', r = 255, g = 255, b = 0 },
    { label = 'Gold', r = 204, g = 204, b = 0 },
    { label = 'Orange', r = 255, g = 128, b = 0 },
    { label = 'Red', r = 255, g = 0, b = 0 },
    { label = 'Pony pink', r = 255, g = 0, b = 255 },
    { label = 'Hot pink', r = 255, g = 0, b = 150 },
    { label = 'Purple', r = 153, g = 0, b = 153 },
}

-- ── small helpers ──────────────────────────────────────────────────────────────

local function modelOf(veh)
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    if not name or name == '' then return '' end
    return name:lower()
end

---Server halves of the workshop (custom liveries, presets, repair quotes) land in
---Task 6. ox_lib rejects the await when a callback is not registered, which would
---throw inside the builder, so every call is wrapped: a failure, nil or false all
---read as "no data" and the sheet still renders.
local function serverCall(name, ...)
    local ok, res = pcall(lib.callback.await, name, false, ...)
    if not ok or res == nil or res == false then return nil end
    return res
end

---serverCall keeps only the first return value; a write callback answers
---ok, reason and the panel shows the reason, so that pair needs its own helper.
---@return any ok, any reason
local function serverCallPair(name, ...)
    local ran, ok, reason = pcall(lib.callback.await, name, false, ...)
    if not ran then return nil, nil end
    return ok, reason
end

local colourChoiceCache
local function colourChoices()
    if colourChoiceCache then return colourChoiceCache end
    colourChoiceCache = {}
    for i = 0, 160 do
        local label = Workshop.COLOURS[i]
        if label then
            colourChoiceCache[#colourChoiceCache + 1] = { value = i, label = label, hex = Workshop.COLOUR_HEX[i] }
        end
    end
    return colourChoiceCache
end

local function indexedChoices(tbl, last)
    local out = {}
    for i = 0, last do
        local label = tbl[i]
        if label then out[#out + 1] = { value = i, label = label } end
    end
    return out
end

-- ── livery labels (legacy 3444-3510, verbatim behaviour) ───────────────────────

local EMERGENCY_LIVERY_PATTERNS = {
    [0] = 'Standard', [1] = 'LSPD', [2] = 'LSSD/BCSO', [3] = 'Highway Patrol', [4] = 'Unmarked',
    [5] = 'Slicktop', [6] = 'K9 Unit', [7] = 'Traffic', [8] = 'Supervisor',
}

local function GetLiveryLabel(veh, liveryIndex)
    local modelName = modelOf(veh)
    local cacheKey = modelName .. '_' .. liveryIndex
    if liveryLabelCache[cacheKey] then return liveryLabelCache[cacheKey] end

    local attempts = {
        ('%s_LIVERY_%d'):format(modelName:upper(), liveryIndex),
        ('%s_LIV%d'):format(modelName:upper(), liveryIndex),
        ('LIVERY_%s_%d'):format(modelName:upper(), liveryIndex),
    }
    for _, labelKey in ipairs(attempts) do
        local label = GetLabelText(labelKey)
        if label and label ~= 'NULL' and label ~= labelKey then
            liveryLabelCache[cacheKey] = label
            return label
        end
    end

    if GetVehicleClass(veh) == 18 then
        local pattern = EMERGENCY_LIVERY_PATTERNS[liveryIndex]
        if pattern then
            liveryLabelCache[cacheKey] = pattern
            return pattern
        end
    end

    local fallback = 'Livery ' .. liveryIndex
    liveryLabelCache[cacheKey] = fallback
    return fallback
end

local function GetEnhancedLiveryName(veh, liveryIndex)
    local label = GetLiveryLabel(veh, liveryIndex)
    if label:match('^Livery %d') then return label end
    return ('%s (#%d)'):format(label, liveryIndex)
end

-- ── livery memory (legacy 3208-3233) ──────────────────────────────────────────

local function SaveLiveryToMemory(veh)
    if not Config.AutoApplyLivery or not Config.AutoApplyLivery.enabled then return end
    if not veh or veh == 0 then return end

    local model = modelOf(veh)
    local liveryIndex = GetVehicleLivery(veh)
    local liveryMod = GetVehicleMod(veh, 48)

    local extras
    if Config.AutoApplyLivery.rememberExtras then
        extras = {}
        for i = 0, 20 do
            if DoesExtraExist(veh, i) then extras[tostring(i)] = IsVehicleExtraTurnedOn(veh, i) end
        end
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    local customLivery = ActiveCustomLiveries[netId]

    TriggerServerEvent('vehiclemods:server:saveLiveryMemory', model, liveryIndex, liveryMod, customLivery, extras)
end

-- ── vehicle properties (legacy 2148-2242, field names unchanged) ───────────────

---@param veh number
---@return table|nil
function WorkshopClient.props(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end

    local colorPrimary, colorSecondary = GetVehicleColours(veh)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(veh)

    local neonEnabled = {}
    for i = 0, 3 do neonEnabled[i] = IsVehicleNeonLightEnabled(veh, i) end
    local neonColor = { GetVehicleNeonLightsColour(veh) }

    local extras = {}
    for extraId = 0, 20 do
        if DoesExtraExist(veh, extraId) then extras[extraId] = IsVehicleExtraTurnedOn(veh, extraId) end
    end

    return {
        model = GetEntityModel(veh),
        plate = GetVehicleNumberPlateText(veh),
        plateIndex = GetVehicleNumberPlateTextIndex(veh),
        bodyHealth = GetVehicleBodyHealth(veh),
        engineHealth = GetVehicleEngineHealth(veh),
        tankHealth = GetVehiclePetrolTankHealth(veh),
        fuelLevel = GetVehicleFuelLevel(veh),
        dirtLevel = GetVehicleDirtLevel(veh),
        color1 = colorPrimary,
        color2 = colorSecondary,
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        wheels = GetVehicleWheelType(veh),
        windowTint = GetVehicleWindowTint(veh),
        neonEnabled = neonEnabled,
        neonColor = neonColor,
        extras = extras,
        tyreSmokeColor = { GetVehicleTyreSmokeColor(veh) },
        modSpoilers = GetVehicleMod(veh, 0),
        modFrontBumper = GetVehicleMod(veh, 1),
        modRearBumper = GetVehicleMod(veh, 2),
        modSideSkirt = GetVehicleMod(veh, 3),
        modExhaust = GetVehicleMod(veh, 4),
        modFrame = GetVehicleMod(veh, 5),
        modGrille = GetVehicleMod(veh, 6),
        modHood = GetVehicleMod(veh, 7),
        modFender = GetVehicleMod(veh, 8),
        modRightFender = GetVehicleMod(veh, 9),
        modRoof = GetVehicleMod(veh, 10),
        modEngine = GetVehicleMod(veh, 11),
        modBrakes = GetVehicleMod(veh, 12),
        modTransmission = GetVehicleMod(veh, 13),
        modHorns = GetVehicleMod(veh, 14),
        modSuspension = GetVehicleMod(veh, 15),
        modArmor = GetVehicleMod(veh, 16),
        modTurbo = IsToggleModOn(veh, 18),
        modSmokeEnabled = IsToggleModOn(veh, 20),
        modXenon = IsToggleModOn(veh, 22),
        modFrontWheels = GetVehicleMod(veh, 23),
        modBackWheels = GetVehicleMod(veh, 24),
        modPlateHolder = GetVehicleMod(veh, 25),
        modVanityPlate = GetVehicleMod(veh, 26),
        modTrimA = GetVehicleMod(veh, 27),
        modOrnaments = GetVehicleMod(veh, 28),
        modDashboard = GetVehicleMod(veh, 29),
        modDial = GetVehicleMod(veh, 30),
        modDoorSpeaker = GetVehicleMod(veh, 31),
        modSeats = GetVehicleMod(veh, 32),
        modSteeringWheel = GetVehicleMod(veh, 33),
        modShifterLeavers = GetVehicleMod(veh, 34),
        modAPlate = GetVehicleMod(veh, 35),
        modSpeakers = GetVehicleMod(veh, 36),
        modTrunk = GetVehicleMod(veh, 37),
        modHydrolic = GetVehicleMod(veh, 38),
        modEngineBlock = GetVehicleMod(veh, 39),
        modAirFilter = GetVehicleMod(veh, 40),
        modStruts = GetVehicleMod(veh, 41),
        modArchCover = GetVehicleMod(veh, 42),
        modAerials = GetVehicleMod(veh, 43),
        modTrimB = GetVehicleMod(veh, 44),
        modTank = GetVehicleMod(veh, 45),
        modWindows = GetVehicleMod(veh, 46),
        modLivery = GetVehicleMod(veh, 48),
        livery = GetVehicleLivery(veh),
    }
end

---Legacy ApplyVehicleProperties (2286-2362), verbatim behaviour.
---@param veh number
---@param props table
function WorkshopClient.applyProps(veh, props)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not props then return end

    SetVehicleModKit(veh, 0)

    if props.color1 and props.color2 then SetVehicleColours(veh, props.color1, props.color2) end
    if props.pearlescentColor and props.wheelColor then SetVehicleExtraColours(veh, props.pearlescentColor, props.wheelColor) end
    if props.windowTint then SetVehicleWindowTint(veh, props.windowTint) end
    if props.wheels then SetVehicleWheelType(veh, props.wheels) end

    local modTypes = {
        { prop = 'modEngine', id = 11 },
        { prop = 'modBrakes', id = 12 },
        { prop = 'modTransmission', id = 13 },
        { prop = 'modSuspension', id = 15 },
        { prop = 'modArmor', id = 16 },
        { prop = 'modFrontWheels', id = 23 },
        { prop = 'modLivery', id = 48 },
    }
    for _, mod in ipairs(modTypes) do
        if props[mod.prop] and props[mod.prop] ~= -1 then SetVehicleMod(veh, mod.id, props[mod.prop], false) end
    end

    if props.modTurbo ~= nil then ToggleVehicleMod(veh, 18, props.modTurbo) end
    if props.modXenon ~= nil then ToggleVehicleMod(veh, 22, props.modXenon) end

    if props.neonEnabled then
        for i = 0, 3 do
            if props.neonEnabled[i] ~= nil then SetVehicleNeonLightEnabled(veh, i, props.neonEnabled[i]) end
        end
    end
    if props.neonColor and props.neonColor[1] and props.neonColor[2] and props.neonColor[3] then
        SetVehicleNeonLightsColour(veh, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end

    if props.extras then
        for extraId, enabled in pairs(props.extras) do
            local id = tonumber(extraId)
            if id and DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, not enabled) end
        end
    end

    if props.livery and props.livery > -1 then SetVehicleLivery(veh, props.livery) end
end

-- ── preset payload (legacy 2989-3061; this is the vehicle_presets.preset_data shape) ──

---@param veh number
---@return table|nil
function WorkshopClient.config(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end

    SetVehicleModKit(veh, 0)

    local config = {
        livery = GetVehicleLivery(veh),
        liveryMod = GetVehicleMod(veh, 48),
        extras = {},
        colors = { primary = { GetVehicleColours(veh) }, extra = { GetVehicleExtraColours(veh) } },
        mods = {},
    }
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then config.extras[i] = IsVehicleExtraTurnedOn(veh, i) end
    end
    for i = 0, 16 do config.mods[i] = GetVehicleMod(veh, i) end
    return config
end

---@param veh number
---@param config table
function WorkshopClient.applyConfig(veh, config)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not config then return end

    SetVehicleModKit(veh, 0)

    if config.livery and config.livery >= 0 then SetVehicleLivery(veh, config.livery) end
    if config.liveryMod and config.liveryMod >= 0 then SetVehicleMod(veh, 48, config.liveryMod, false) end

    if config.extras then
        for i, state in pairs(config.extras) do
            local id = tonumber(i)
            if id and DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, not state) end
        end
    end

    if config.colors then
        if config.colors.primary then SetVehicleColours(veh, config.colors.primary[1], config.colors.primary[2]) end
        if config.colors.extra then SetVehicleExtraColours(veh, config.colors.extra[1], config.colors.extra[2]) end
    end

    if config.mods then
        for modType, modIndex in pairs(config.mods) do
            local slot = tonumber(modType)
            if slot and modIndex and modIndex >= 0 then SetVehicleMod(veh, slot, modIndex, false) end
        end
    end
end

---Writes the current cosmetic state back to vehicle_mods for this model.
---@param veh number
function WorkshopClient.persist(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local model = modelOf(veh)
    if model == '' then return end
    local props = WorkshopClient.props(veh)
    if not props then return end
    TriggerServerEvent('vehiclemods:server:saveModifications', model, props)
end

-- ── custom livery events (legacy 595-708; the event names are kept) ────────────

RegisterNetEvent('vehiclemods:client:setCustomLivery', function(netId, vehicleModelName, liveryFile)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not vehicleModelName or not liveryFile then return end

    local baseName = string.match(liveryFile, '([^/]+)%.yft$')
    if not baseName then baseName = liveryFile:gsub('%.yft', '') end
    local textureDict = vehicleModelName .. '_' .. baseName

    if not HasStreamedTextureDictLoaded(textureDict) then
        RequestStreamedTextureDict(textureDict)
        local timeout = 0
        while not HasStreamedTextureDictLoaded(textureDict) and timeout < TEXTURE_LOAD_TIMEOUT do
            Wait(10)
            timeout = timeout + 1
        end
        if not HasStreamedTextureDictLoaded(textureDict) then
            lib.print.error(('custom livery texture dict did not load: %s'):format(textureDict))
            return
        end
    end

    local key = NetworkGetNetworkIdFromEntity(veh)
    local previous = ActiveCustomLiveries[key]
    if previous and previous.dict and previous.dict ~= textureDict and HasStreamedTextureDictLoaded(previous.dict) then
        SetStreamedTextureDictAsNoLongerNeeded(previous.dict)
        loadedTextures[previous.dict] = nil
    end

    ActiveCustomLiveries[key] = { file = liveryFile, dict = textureDict, model = vehicleModelName }
    loadedTextures[textureDict] = GetGameTimer()

    -- The texture swap is what changes the look; the livery slot is only moved off
    -- stock so the vehicle uses the streamed sheet.
    if GetNumVehicleMods(veh, 48) > 0 then
        SetVehicleMod(veh, 48, 0, false)
    elseif GetVehicleLiveryCount(veh) > 0 then
        SetVehicleLivery(veh, 1)
    end
end)

RegisterNetEvent('vehiclemods:client:clearCustomLivery', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    local key = NetworkGetNetworkIdFromEntity(veh)
    local info = ActiveCustomLiveries[key]
    if not info then return end

    SetVehicleLivery(veh, 0)
    SetVehicleMod(veh, 48, -1, false)
    if info.dict and HasStreamedTextureDictLoaded(info.dict) then
        SetStreamedTextureDictAsNoLongerNeeded(info.dict)
        loadedTextures[info.dict] = nil
    end
    ActiveCustomLiveries[key] = nil
end)

-- ── sirens (Task 6b) ──────────────────────────────────────────────────────────
-- dps-fleet owns which tones a model is allowed; LVC (lvc, GPL-3) owns the sound.
-- The cache below is the whole assignment table, filled once at resource start
-- and patched by the server's broadcast. LVC's credited hook reads it through the
-- GetSirenAssignments export and merges it over its own SIRENS.lua table, so this
-- cache matters to every player, not only to the ones who may use the workshop.

local SIREN_CACHE = {}
-- model (lowercase) -> vehicles.meta game name, from the server's open payload.
local SIREN_GAMES = {}
-- LVC reads position 1 as the airhorn and 2.. as the cycle, so never fewer than two.
local SIREN_SLOT_MIN = 2
local sirenTestSound = nil

---LVC's hook and anything else client-side reads the assignments here.
exports('GetSirenAssignments', function() return SIREN_CACHE end)

---client.lua hands the registry game names over when the panel data arrives.
---@param games table|nil model (lowercase) -> game name
function WorkshopClient.setGames(games)
    if type(games) ~= 'table' then return end
    SIREN_GAMES = games
end

---@param assignments any siren key -> tone id list
---@return number keys accepted
local function cacheSirens(assignments)
    if type(assignments) ~= 'table' then return 0 end
    local n = 0
    for key, tones in pairs(assignments) do
        if type(key) == 'string' and Workshop.validTones(tones, #Workshop.SIREN_TONES) then
            SIREN_CACHE[key] = tones
            n = n + 1
        end
    end
    return n
end

RegisterNetEvent('dps-fleet:client:sirens', function(assignment)
    if type(assignment) ~= 'table' or type(assignment.key) ~= 'string' then return end
    if not Workshop.validTones(assignment.tones, #Workshop.SIREN_TONES) then return end
    SIREN_CACHE[assignment.key] = assignment.tones
end)

local function fillSirenCache()
    return cacheSirens(serverCall('dps-fleet:server:allSirens'))
end

-- One shot at resource start, never a loop: LVC asks for this table the moment a
-- player enters a siren vehicle. SetTimeout gives the await its own thread and
-- lets the server finish loading first; a client that joins mid-boot and gets
-- nothing is given one retry, then LVC simply keeps its own SIRENS.lua list.
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetTimeout(2000, function()
        if fillSirenCache() == 0 then SetTimeout(15000, fillSirenCache) end
    end)
end)

---The name LVC looks the assignment up by: GetDisplayNameFromVehicleModel on the
---live vehicle, case intact (modelOf lowercases it, which would miss the key).
---GTA keeps 11 characters of a game name, so this is already short.
---@param veh number
---@return string|nil
local function gameNameOf(veh)
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    if type(name) ~= 'string' or name == '' or name == 'CARNOTFOUND' then return nil end
    return name
end

---@param pos number
---@return string
local function sirenSlotLabel(pos)
    return pos == 1 and 'Airhorn' or ('Tone %d'):format(pos - 1)
end

-- Built once. The tone name alone is ambiguous (three packs ship a "Fire Wail"),
-- so the id LVC knows the tone by leads the label.
local sirenToneChoiceCache
local function sirenToneChoices()
    if sirenToneChoiceCache then return sirenToneChoiceCache end
    sirenToneChoiceCache = {}
    for id = 1, #Workshop.SIREN_TONES do
        sirenToneChoiceCache[id] = { value = id, label = ('%d · %s'):format(id, Workshop.SIREN_TONES[id]) }
    end
    return sirenToneChoiceCache
end

local sirenPresetChoiceCache
local function sirenPresetChoices()
    if sirenPresetChoiceCache then return sirenPresetChoiceCache end
    sirenPresetChoiceCache = {}
    for _, presetKey in ipairs(Workshop.SIREN_PRESET_ORDER) do
        local preset = Workshop.SIREN_PRESETS[presetKey]
        sirenPresetChoiceCache[#sirenPresetChoiceCache + 1] = {
            value = presetKey, label = ('%s — %d tones'):format(preset.label, #preset.tones),
        }
    end
    sirenPresetChoiceCache[#sirenPresetChoiceCache + 1] = { value = 'custom', label = 'Custom — the tones below' }
    return sirenPresetChoiceCache
end

---What the sheet and every apply work from. The server is the authority on both
---the key and the saved list; the cache answers if the call fails, and the LEO set
---is the starting point when nothing has ever been saved for this vehicle.
---@param model string lowercase model name
---@param gameName string|nil what the live vehicle calls itself
---@return table state { key, tones (a copy, safe to edit), saved, preset }
local function sirenState(model, gameName)
    local reply = serverCall('dps-fleet:server:sirens', model, gameName)
    local key = (type(reply) == 'table' and type(reply.key) == 'string' and reply.key)
        or Workshop.sirenKey(gameName or SIREN_GAMES[model], model)
    local tones
    if type(reply) == 'table' and Workshop.validTones(reply.tones, #Workshop.SIREN_TONES) then
        tones = reply.tones
        if key then SIREN_CACHE[key] = tones end
    elseif key and Workshop.validTones(SIREN_CACHE[key], #Workshop.SIREN_TONES) then
        tones = SIREN_CACHE[key]
    end
    local saved = tones ~= nil
    if not tones then tones = Workshop.SIREN_PRESETS.leo.tones end
    local copy = {}
    for i, id in ipairs(tones) do copy[i] = id end
    return { key = key or nil, tones = copy, saved = saved, preset = Workshop.sirenPresetOf(copy) }
end

---Two seconds of one tone, so a set can be heard before it is saved. One-shot
---timer, no loop; a second press stops the first sound.
---@param veh number
---@param id number
---@return boolean
local function playTone(veh, id)
    local audio = Workshop.SIREN_TONES_STRING[id]
    if not audio then return false end
    if sirenTestSound then
        StopSound(sirenTestSound)
        ReleaseSoundId(sirenTestSound)
        sirenTestSound = nil
    end
    local soundId = GetSoundId()
    sirenTestSound = soundId
    PlaySoundFromEntity(soundId, audio, veh, Workshop.SIREN_TONES_REF[id] or 0, false, 0)
    SetTimeout(2000, function()
        StopSound(soundId)
        ReleaseSoundId(soundId)
        if sirenTestSound == soundId then sirenTestSound = nil end
    end)
    return true
end

-- The sheet; SHEETS.sirens below points at it.
local function sheetSirens(veh)
    local model = modelOf(veh)
    local state = sirenState(model, gameNameOf(veh))
    if not state.key then
        return { { key = 'nokey', kind = 'action', value = false,
            label = 'This vehicle has no game name, so LVC has nothing to key siren tones to.' } }
    end

    local options = {}
    if not state.saved then
        options[#options + 1] = { key = 'unsaved', kind = 'action', value = false,
            label = 'No tones saved for this vehicle yet — LVC is using its own list. What follows is a starting point.' }
    end
    options[#options + 1] = { key = 'preset', label = ('Siren set for %s'):format(state.key), kind = 'pick',
        value = state.preset or 'custom', choices = sirenPresetChoices() }
    for pos, id in ipairs(state.tones) do
        options[#options + 1] = { key = 'slot:' .. pos, label = sirenSlotLabel(pos), kind = 'pick',
            value = id, choices = sirenToneChoices() }
        options[#options + 1] = { key = 'test:' .. pos, kind = 'action', value = true,
            label = ('Play %s — %s'):format(sirenSlotLabel(pos), Workshop.SIREN_TONES[id] or ('tone ' .. id)) }
    end
    options[#options + 1] = { key = 'add_slot', label = 'Add a tone', kind = 'action',
        value = #state.tones < Workshop.SIREN_SLOT_MAX }
    options[#options + 1] = { key = 'remove_slot', label = 'Remove the last tone', kind = 'action',
        value = #state.tones > SIREN_SLOT_MIN }
    return options
end

-- ── sheet builders ────────────────────────────────────────────────────────────
-- Each returns the options array for its section, read live off the vehicle.

local function sheetLiveries(veh)
    SetVehicleModKit(veh, 0)
    local count = GetVehicleLiveryCount(veh)
    local modCount = GetNumVehicleMods(veh, 48)
    if count < 0 then count = 0 end
    if modCount < 0 then modCount = 0 end

    local names = {}
    for i = 0, count - 1 do names[i] = GetEnhancedLiveryName(veh, i) end

    local choices = Workshop.liveryChoices(count, modCount, names)
    -- EVM's mod-livery list carried a "Default" entry at index -1; keep that way
    -- back to stock for vehicles whose liveries live in mod slot 48.
    if count == 0 and modCount > 0 then
        table.insert(choices, 1, { value = { src = 'mod', index = -1 }, label = 'Stock (no livery)' })
    end

    local currentMod = GetVehicleMod(veh, 48)
    local value
    if currentMod and currentMod >= 0 then
        value = { src = 'mod', index = currentMod }
    else
        value = { src = 'livery', index = GetVehicleLivery(veh) }
    end

    return { { key = 'livery', label = 'Livery', kind = 'pick', value = value, choices = choices } }
end

local function customLiveryList(model)
    local list = serverCall('dps-fleet:server:customLiveries', model)
    if type(list) ~= 'table' then
        -- Task 6 owns the server half; until it exists the config table is the source.
        list = Config.CustomLiveries and Config.CustomLiveries[model] or {}
    end
    return list
end

local function sheetCustomLiveries(veh)
    local model = modelOf(veh)
    local list = customLiveryList(model)

    local choices = {}
    for _, entry in ipairs(list) do
        if type(entry) == 'table' and entry.file then
            choices[#choices + 1] = { value = entry.file, label = entry.name or entry.file }
        end
    end
    choices[#choices + 1] = { value = 'none', label = 'Remove custom livery' }

    local active = ActiveCustomLiveries[NetworkGetNetworkIdFromEntity(veh)]
    local options = {
        { key = 'custom', label = 'Custom livery', kind = 'pick', value = active and active.file or 'none', choices = choices },
        { key = 'add', label = 'Add a custom livery', kind = 'action', value = true },
    }
    if #list > 0 then
        options[#options + 1] = { key = 'remove', label = 'Delete a saved livery', kind = 'action', value = true }
    end
    return options
end

local function sheetExtras(veh)
    local options = {}
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            options[#options + 1] = { key = 'extra:' .. i, label = 'Extra ' .. i, kind = 'toggle', value = IsVehicleExtraTurnedOn(veh, i) == true }
        end
    end
    return options
end

local function sheetPerformance(veh)
    SetVehicleModKit(veh, 0)
    local options = {}
    for _, slot in ipairs(Workshop.PERF_SLOTS) do
        local id, label = slot[1], slot[2]
        if slot.toggle then
            options[#options + 1] = { key = 'slot:' .. id, label = label, kind = 'toggle', value = IsToggleModOn(veh, id) == true }
        else
            local num = GetNumVehicleMods(veh, id)
            if num and num > 0 then
                options[#options + 1] = { key = 'slot:' .. id, label = label, kind = 'stepper', value = GetVehicleMod(veh, id), min = -1, max = num - 1 }
            end
        end
    end
    return options
end

local function sheetColours(veh)
    local primary, secondary = GetVehicleColours(veh)
    local pearlescent, wheelColour = GetVehicleExtraColours(veh)
    local choices = colourChoices()
    return {
        { key = 'primary', label = 'Primary', kind = 'colour', value = primary, choices = choices },
        { key = 'secondary', label = 'Secondary', kind = 'colour', value = secondary, choices = choices },
        { key = 'pearlescent', label = 'Pearlescent', kind = 'colour', value = pearlescent, choices = choices },
        { key = 'wheelcolour', label = 'Wheels', kind = 'colour', value = wheelColour, choices = choices },
    }
end

local function sheetWheels(veh)
    SetVehicleModKit(veh, 0)
    local options = {
        { key = 'type', label = 'Wheel type', kind = 'pick', value = GetVehicleWheelType(veh), choices = indexedChoices(Workshop.WHEEL_TYPES, 12) },
    }
    local num = GetNumVehicleMods(veh, 23)
    if num and num > 0 then
        options[#options + 1] = { key = 'wheel', label = 'Wheel style', kind = 'stepper', value = GetVehicleMod(veh, 23), min = -1, max = num - 1 }
    end
    options[#options + 1] = { key = 'custom', label = 'Custom (Benny\'s) wheels', kind = 'toggle', value = GetVehicleModVariation(veh, 23) == true }
    return options
end

local function sheetTint(veh)
    return { { key = 'tint', label = 'Window tint', kind = 'pick', value = GetVehicleWindowTint(veh), choices = indexedChoices(Workshop.TINTS, 6) } }
end

local function sheetNeon(veh)
    local options = {}
    for _, side in ipairs(NEON_SIDES) do
        options[#options + 1] = { key = side.key, label = side.label, kind = 'toggle', value = IsVehicleNeonLightEnabled(veh, side.index) == true }
    end
    local r, g, b = GetVehicleNeonLightsColour(veh)
    local choices = {}
    for _, c in ipairs(NEON_COLOURS) do
        choices[#choices + 1] = { value = { c.r, c.g, c.b }, label = c.label, hex = ('#%02x%02x%02x'):format(c.r, c.g, c.b) }
    end
    options[#options + 1] = { key = 'neoncolour', label = 'Neon colour', kind = 'colour', value = { r, g, b }, choices = choices }
    return options
end

local function sheetDoors(veh)
    local options = {}
    for i = 0, 5 do
        options[#options + 1] = { key = 'door:' .. i, label = DOOR_LABELS[i], kind = 'toggle', value = GetVehicleDoorAngleRatio(veh, i) > 0 }
    end
    options[#options + 1] = { key = 'all_open', label = 'Open everything', kind = 'action', value = true }
    options[#options + 1] = { key = 'all_shut', label = 'Shut everything', kind = 'action', value = true }
    return options
end

-- EVM's smash-window list (legacy 1260-1290): an extraction tool, kept.
local SMASH_WINDOWS = {
    { index = 0, label = 'front left' },
    { index = 1, label = 'front right' },
    { index = 2, label = 'rear left' },
    { index = 3, label = 'rear right' },
}
local SMASH_LABEL = {}
for _, w in ipairs(SMASH_WINDOWS) do SMASH_LABEL[w.index] = w.label end

local function sheetWindows(veh)
    local options = {
        { key = 'down_front', label = 'Front windows down', kind = 'action', value = true },
        { key = 'up_front', label = 'Front windows up', kind = 'action', value = true },
        { key = 'down_rear', label = 'Rear windows down', kind = 'action', value = true },
        { key = 'up_rear', label = 'Rear windows up', kind = 'action', value = true },
    }
    for _, w in ipairs(SMASH_WINDOWS) do
        options[#options + 1] = {
            key = 'smash:' .. w.index,
            label = ('Smash %s window'):format(w.label),
            kind = 'action',
            value = IsVehicleWindowIntact(veh, w.index) == true,
        }
    end
    return options
end

local function seatLabel(i)
    return SEAT_NAMES[i] or ('Seat %d'):format(i + 2)
end

local function sheetSeats(veh)
    local maxPassengers = GetVehicleMaxNumberOfPassengers(veh)
    local mySeat = cache.vehicle == veh and cache.seat or nil
    local options = {}
    for i = -1, maxPassengers - 1 do
        local occupant = GetPedInVehicleSeat(veh, i)
        local taken = occupant ~= 0 and occupant ~= cache.ped
        local label = seatLabel(i)
        if i == mySeat then
            label = label .. ' (you)'
        elseif taken then
            label = label .. (IsPedAPlayer(occupant) and ' (player aboard)' or ' (occupied)')
        end
        options[#options + 1] = { key = 'seat:' .. i, label = label, kind = 'action', value = not taken }
    end
    return options
end

local function presetName(preset)
    if type(preset) ~= 'table' then return nil end
    return preset.name or preset.preset_name
end

local function presetList(model)
    local list = serverCall('dps-fleet:server:presets', model)
    if type(list) ~= 'table' then return nil end
    return list
end

local function sheetPresets(veh)
    local options = { { key = 'save', label = 'Save this setup as a preset', kind = 'action', value = true } }
    local list = presetList(modelOf(veh))
    if not list then
        options[#options + 1] = { key = 'unavailable', label = 'Saved presets are not available yet.', kind = 'action', value = false }
        return options
    end
    for _, preset in ipairs(list) do
        local name = presetName(preset)
        if name then
            local suffix = preset.isJobPreset and ' [Fleet]' or ''
            options[#options + 1] = { key = 'load:' .. name, label = 'Apply ' .. name .. suffix, kind = 'action', value = true }
            if preset.isOwner ~= false then
                options[#options + 1] = { key = 'delete:' .. name, label = ('Delete "%s"'):format(name), kind = 'action', value = true }
            end
        end
    end
    return options
end

local REPAIR_LABELS = { emergency = 'Emergency patch-up', full = 'Full repair', field = 'Field repair' }

local function sheetRepair()
    local quote = serverCall('dps-fleet:server:repairQuote')
    local function label(kind)
        local text = REPAIR_LABELS[kind]
        local price = quote and tonumber(quote[kind])
        if not price then return text end
        if price <= 0 then return text .. ' — free' end
        return ('%s — $%d'):format(text, price)
    end
    return {
        { key = 'emergency', label = label('emergency'), kind = 'action', value = true },
        { key = 'full', label = label('full'), kind = 'action', value = true },
        { key = 'field', label = label('field'), kind = 'action', value = true },
        { key = 'report', label = 'Damage report', kind = 'action', value = true },
    }
end

local SHEETS = {
    liveries = sheetLiveries,
    customliveries = sheetCustomLiveries,
    extras = sheetExtras,
    performance = sheetPerformance,
    colours = sheetColours,
    wheels = sheetWheels,
    tint = sheetTint,
    neon = sheetNeon,
    doors = sheetDoors,
    windows = sheetWindows,
    seats = sheetSeats,
    presets = sheetPresets,
    sirens = sheetSirens,
    repair = sheetRepair,
}

---@param veh number
---@param sectionId string
---@return table|nil sheet { id, title, options }
function WorkshopClient.sheet(veh, sectionId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if type(sectionId) ~= 'string' then return nil end
    local builder = SHEETS[sectionId]
    if not builder then return nil end
    local options = builder(veh)
    if not options then return nil end
    return { id = sectionId, title = SECTION_TITLE[sectionId] or sectionId, options = options }
end

-- ── apply ─────────────────────────────────────────────────────────────────────

local APPLY = {}

function APPLY.liveries(veh, key, value)
    if key ~= 'livery' then return false, 'Unknown livery option.' end
    if type(value) ~= 'table' then return false, 'Pick a livery first.' end
    local index = tonumber(value.index)
    if not index then return false, 'Pick a livery first.' end
    if value.src == 'mod' then
        SetVehicleMod(veh, 48, index, false)
    else
        SetVehicleLivery(veh, index)
    end
    SaveLiveryToMemory(veh)
    WorkshopClient.persist(veh)
    return true, 'Livery applied.'
end

function APPLY.customliveries(veh, key, value)
    local model = modelOf(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)

    if key == 'custom' then
        if value == 'none' or value == nil then
            SetVehicleLivery(veh, 0)
            SetVehicleMod(veh, 48, -1, false)
            TriggerServerEvent('vehiclemods:server:clearCustomLivery', netId)
            SaveLiveryToMemory(veh)
            return true, 'Custom livery removed.'
        end
        if not Workshop.isSafeLiveryFile(value) then return false, 'That livery file path is not allowed.' end
        TriggerServerEvent('vehiclemods:server:applyCustomLivery', netId, model, value)
        return true, 'Custom livery applied.'
    end

    if key == 'add' then
        local input = lib.inputDialog('Add a custom livery', {
            { type = 'input', label = 'Livery name', required = true, max = Config.InputValidation and Config.InputValidation.maxNameLength or 32 },
            { type = 'input', label = 'YFT file path', required = true, placeholder = model .. '_livery1.yft' },
        })
        if not input or not input[1] or not input[2] then return false, 'Cancelled.' end
        if not Workshop.isSafeLiveryFile(input[2]) then return false, 'That livery file path is not allowed.' end
        TriggerServerEvent('vehiclemods:server:addCustomLivery', model, input[1], input[2])
        return true, ('Added "%s".'):format(input[1])
    end

    if key == 'remove' then
        local name = type(value) == 'string' and value or nil
        if not name then
            local list = customLiveryList(model)
            local options = {}
            for _, entry in ipairs(list) do
                if type(entry) == 'table' and entry.name then options[#options + 1] = { value = entry.name, label = entry.name } end
            end
            if #options == 0 then return false, 'Nothing saved to delete.' end
            local input = lib.inputDialog('Delete a custom livery', { { type = 'select', label = 'Livery', required = true, options = options } })
            if not input or not input[1] then return false, 'Cancelled.' end
            name = input[1]
        end
        TriggerServerEvent('vehiclemods:server:removeCustomLivery', model, name)
        return true, ('Deleted "%s".'):format(name)
    end

    return false, 'Unknown custom livery option.'
end

function APPLY.extras(veh, key, value)
    local id = tonumber(key:match('^extra:(%-?%d+)$'))
    if not id then return false, 'Unknown extra.' end
    if not DoesExtraExist(veh, id) then return false, 'This vehicle has no extra ' .. id .. '.' end
    -- SetVehicleExtra is inverted: false turns the extra ON.
    SetVehicleExtra(veh, id, not value)
    SaveLiveryToMemory(veh)
    WorkshopClient.persist(veh)
    return true, ('Extra %d %s.'):format(id, value and 'on' or 'off')
end

function APPLY.performance(veh, key, value)
    local slot = tonumber(key:match('^slot:(%d+)$'))
    if not slot then return false, 'Unknown upgrade.' end
    if slot == 18 then
        ToggleVehicleMod(veh, 18, value == true)
        WorkshopClient.persist(veh)
        return true, value and 'Turbo fitted.' or 'Turbo removed.'
    end
    local level = tonumber(value)
    if not level then return false, 'Pick a level.' end
    local num = GetNumVehicleMods(veh, slot)
    level = math.floor(level)
    if level < -1 then level = -1 end
    if level > num - 1 then level = num - 1 end
    SetVehicleMod(veh, slot, level, false)
    WorkshopClient.persist(veh)
    return true, level == -1 and 'Set to stock.' or ('Level %d fitted.'):format(level + 1)
end

function APPLY.colours(veh, key, value)
    local colour = tonumber(value)
    if not colour then return false, 'Pick a colour.' end
    if key == 'primary' then
        local _, secondary = GetVehicleColours(veh)
        SetVehicleColours(veh, colour, secondary)
    elseif key == 'secondary' then
        local primary = GetVehicleColours(veh)
        SetVehicleColours(veh, primary, colour)
    elseif key == 'pearlescent' then
        local _, wheelColour = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, colour, wheelColour)
    elseif key == 'wheelcolour' then
        local pearlescent = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, pearlescent, colour)
    else
        return false, 'Unknown colour option.'
    end
    WorkshopClient.persist(veh)
    return true, (Workshop.COLOURS[colour] or 'Colour') .. ' applied.'
end

function APPLY.wheels(veh, key, value)
    if key == 'type' then
        local wheelType = tonumber(value)
        if not wheelType then return false, 'Pick a wheel type.' end
        SetVehicleWheelType(veh, wheelType)
        WorkshopClient.persist(veh)
        return true, (Workshop.WHEEL_TYPES[wheelType] or 'Wheel type') .. ' wheels.'
    end

    if key == 'wheel' then
        local index = tonumber(value)
        if not index then return false, 'Pick a wheel style.' end
        local num = GetNumVehicleMods(veh, 23)
        index = math.floor(index)
        if index < -1 then index = -1 end
        if index > num - 1 then index = num - 1 end
        SetVehicleMod(veh, 23, index, GetVehicleModVariation(veh, 23))
        if GetVehicleClass(veh) == 8 then SetVehicleMod(veh, 24, index, GetVehicleModVariation(veh, 24)) end
        WorkshopClient.persist(veh)
        return true, index == -1 and 'Stock wheels.' or ('Wheel %d fitted.'):format(index + 1)
    end

    if key == 'custom' then
        local custom = value == true
        SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), custom)
        if GetVehicleClass(veh) == 8 then SetVehicleMod(veh, 24, GetVehicleMod(veh, 24), custom) end
        WorkshopClient.persist(veh)
        return true, custom and 'Custom wheels on.' or 'Custom wheels off.'
    end

    return false, 'Unknown wheel option.'
end

function APPLY.tint(veh, key, value)
    if key ~= 'tint' then return false, 'Unknown tint option.' end
    local tint = tonumber(value)
    if not tint then return false, 'Pick a tint.' end
    SetVehicleWindowTint(veh, tint)
    WorkshopClient.persist(veh)
    return true, (Workshop.TINTS[tint] or 'Tint') .. ' applied.'
end

function APPLY.neon(veh, key, value)
    local index = NEON_INDEX[key]
    if index then
        SetVehicleNeonLightEnabled(veh, index, value == true)
        WorkshopClient.persist(veh)
        return true, ('%s neon %s.'):format(key, value and 'on' or 'off')
    end
    if key == 'neoncolour' then
        if type(value) ~= 'table' then return false, 'Pick a neon colour.' end
        local r, g, b = tonumber(value[1]), tonumber(value[2]), tonumber(value[3])
        if not r or not g or not b then return false, 'Pick a neon colour.' end
        SetVehicleNeonLightsColour(veh, r, g, b)
        WorkshopClient.persist(veh)
        return true, 'Neon colour applied.'
    end
    return false, 'Unknown neon option.'
end

function APPLY.doors(veh, key, value)
    if key == 'all_open' then
        for i = 0, 5 do SetVehicleDoorOpen(veh, i, false, false) end
        return true, 'Everything open.'
    end
    if key == 'all_shut' then
        for i = 0, 5 do SetVehicleDoorShut(veh, i, false) end
        return true, 'Everything shut.'
    end
    local id = tonumber(key:match('^door:(%d+)$'))
    if not id or id > 5 then return false, 'Unknown door.' end
    if value then
        SetVehicleDoorOpen(veh, id, false, false)
    else
        SetVehicleDoorShut(veh, id, false)
    end
    return true, ('%s %s.'):format(DOOR_LABELS[id], value and 'open' or 'shut')
end

local WINDOW_ACTIONS = {
    down_front = { roll = 'down', windows = { 0, 1 }, message = 'Front windows down.' },
    up_front = { roll = 'up', windows = { 0, 1 }, message = 'Front windows up.' },
    down_rear = { roll = 'down', windows = { 2, 3 }, message = 'Rear windows down.' },
    up_rear = { roll = 'up', windows = { 2, 3 }, message = 'Rear windows up.' },
}

function APPLY.windows(veh, key)
    local smash = tonumber(key:match('^smash:(%d+)$'))
    if smash then
        if not SMASH_LABEL[smash] then return false, 'Unknown window.' end
        if IsVehicleWindowIntact(veh, smash) == false then return false, 'That window is already broken.' end
        SmashVehicleWindow(veh, smash)
        return true, ('Smashed the %s window.'):format(SMASH_LABEL[smash])
    end

    local action = WINDOW_ACTIONS[key]
    if not action then return false, 'Unknown window option.' end
    for _, index in ipairs(action.windows) do
        if action.roll == 'down' then RollDownWindow(veh, index) else RollUpWindow(veh, index) end
    end
    return true, action.message
end

function APPLY.seats(veh, key)
    local index = tonumber(key:match('^seat:(%-?%d+)$'))
    if not index then return false, 'Unknown seat.' end
    if not cache.ped then return false, 'No ped.' end

    local occupant = GetPedInVehicleSeat(veh, index)
    if occupant ~= 0 and occupant ~= cache.ped then
        -- EVM's passenger management: clearing the seat is what makes it available.
        TaskLeaveVehicle(occupant, veh, 16)
        return true, ('Cleared the %s seat.'):format(seatLabel(index):lower())
    end

    SetPedIntoVehicle(cache.ped, veh, index)
    return true, ('Moved to %s.'):format(seatLabel(index):lower())
end

function APPLY.presets(veh, key, value)
    local model = modelOf(veh)

    if key == 'save' then
        local input = lib.inputDialog('Save a preset', {
            { type = 'input', label = 'Preset name', required = true, max = 50 },
            { type = 'checkbox', label = 'Share with the job (fleet preset)' },
        })
        if not input or not input[1] then return false, 'Cancelled.' end
        local config = WorkshopClient.config(veh)
        if not config then return false, 'Could not read this vehicle.' end
        TriggerServerEvent('vehiclemods:server:savePreset', input[1], model, config, input[2] == true)
        return true, ('Saving "%s".'):format(input[1])
    end

    local loadName = key:match('^load:(.+)$')
    if loadName then
        local list = presetList(model)
        if not list then return false, 'Presets are not available yet.' end
        for _, preset in ipairs(list) do
            if presetName(preset) == loadName then
                if not preset.data then return false, 'That preset has no data.' end
                WorkshopClient.applyConfig(veh, preset.data)
                WorkshopClient.persist(veh)
                return true, ('Applied "%s".'):format(loadName)
            end
        end
        return false, ('No preset called "%s".'):format(loadName)
    end

    local deleteName = key:match('^delete:(.+)$')
    if deleteName then
        TriggerServerEvent('vehiclemods:server:deletePreset', deleteName, model)
        return true, ('Deleting "%s".'):format(deleteName)
    end

    if key == 'unavailable' then return false, 'Presets are not available yet.' end
    return false, 'Unknown preset option.'
end

function APPLY.sirens(veh, key, value)
    if key == 'nokey' or key == 'unsaved' then return false, 'Nothing to change here.' end

    local model = modelOf(veh)
    local gameName = gameNameOf(veh)
    local state = sirenState(model, gameName)
    if not state.key then return false, 'This vehicle has no game name to key siren tones to.' end

    -- Every change writes the whole list: the row is the assignment, not a diff.
    local function save(list, message)
        if not Workshop.validTones(list, #Workshop.SIREN_TONES) then return false, 'That tone list is not valid.' end
        local ok, why = serverCallPair('dps-fleet:server:setSirens', model, list, gameName)
        if ok ~= true then return false, type(why) == 'string' and why or 'Could not save those tones.' end
        -- The server broadcast reaches us too, but the panel rebuilds the sheet the
        -- moment this returns, so the cache is set here as well.
        SIREN_CACHE[state.key] = list
        return true, message
    end

    if key == 'preset' then
        if value == 'custom' then return false, 'Pick a set, or change the tones below.' end
        local preset = type(value) == 'string' and Workshop.SIREN_PRESETS[value] or nil
        if not preset then return false, 'Pick a siren set.' end
        local list = {}
        for i, id in ipairs(preset.tones) do list[i] = id end
        return save(list, ('%s tones saved for %s.'):format(preset.label, state.key))
    end

    local slot = tonumber(key:match('^slot:(%d+)$'))
    if slot then
        if not state.tones[slot] then return false, 'That slot is gone — reopen the sheet.' end
        local id = tonumber(value)
        id = id and math.floor(id) or nil
        if not id or not Workshop.SIREN_TONES[id] then return false, 'Pick a tone.' end
        local list = state.tones
        list[slot] = id
        return save(list, ('%s set to %s.'):format(sirenSlotLabel(slot), Workshop.SIREN_TONES[id]))
    end

    local testSlot = tonumber(key:match('^test:(%d+)$'))
    if testSlot then
        local id = state.tones[testSlot]
        if not id then return false, 'There is nothing in that slot.' end
        if not playTone(veh, id) then return false, 'That tone has no sound to play.' end
        return true, ('Playing %s for two seconds.'):format(Workshop.SIREN_TONES[id] or ('tone ' .. id))
    end

    if key == 'add_slot' then
        local list = state.tones
        if #list >= Workshop.SIREN_SLOT_MAX then
            return false, ('LVC takes at most %d tones.'):format(Workshop.SIREN_SLOT_MAX)
        end
        -- Starts as a copy of the last tone: something valid to save, and obviously
        -- the one to change next.
        list[#list + 1] = list[#list]
        return save(list, 'Tone added — pick what it should be.')
    end

    if key == 'remove_slot' then
        local list = state.tones
        if #list <= SIREN_SLOT_MIN then return false, 'A siren keeps the airhorn and at least one tone.' end
        list[#list] = nil
        return save(list, 'Last tone removed.')
    end

    return false, 'Unknown siren option.'
end

function APPLY.repair(veh, key)
    if not RepairClient or not RepairClient.run then return false, 'Repairs not installed yet.' end

    if key == 'report' then
        if not RepairClient.report then return false, 'Repairs not installed yet.' end
        local report = RepairClient.report(veh)
        if not report then return false, 'Could not read the damage.' end
        local lines = Workshop.describeDamage(report)
        return true, table.concat(lines, ' · ')
    end

    if key ~= 'emergency' and key ~= 'full' and key ~= 'field' then return false, 'Unknown repair option.' end
    local ok, message = RepairClient.run(veh, key)
    if ok ~= true then return false, message or 'Repair did not run.' end
    return true, message
end

---@param veh number
---@param sectionId string
---@param key string
---@param value any
---@return boolean ok, string|nil message
function WorkshopClient.apply(veh, sectionId, key, value)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'No vehicle.' end
    if type(sectionId) ~= 'string' or type(key) ~= 'string' then return false, 'Nothing to apply.' end
    local fn = APPLY[sectionId]
    if not fn then return false, 'That section cannot be changed here.' end
    -- Once per apply, before any SetVehicleMod.
    SetVehicleModKit(veh, 0)
    local ok, message = fn(veh, key, value)
    return ok == true, message
end

-- Later tasks (panel wiring, sirens, repairs) reuse these.
WorkshopClient.liveryLabel = GetLiveryLabel
WorkshopClient.enhancedLiveryName = GetEnhancedLiveryName
WorkshopClient.saveLiveryToMemory = SaveLiveryToMemory

-- ── the vehicle the panel works on ────────────────────────────────────────────
-- ox_target (Task 8) sets the vehicle it was used on; the panel prefers it over
-- the one we sit in. A stale entity clears itself so nothing ever hands a dead
-- handle to a native.

local explicitVehicle = nil

---@param entity number
function WorkshopClient.setVehicle(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    explicitVehicle = entity
end

function WorkshopClient.clearVehicle()
    explicitVehicle = nil
end

---@return number|nil
function WorkshopClient.vehicle()
    if not explicitVehicle then return nil end
    if not DoesEntityExist(explicitVehicle) then
        explicitVehicle = nil
        return nil
    end
    return explicitVehicle
end
