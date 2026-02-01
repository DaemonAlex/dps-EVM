-- Vehicle Modification System - Multi-Framework Edition
-- Server-side script

if not Config then
    print("^1ERROR:^0 Config is not loaded! Check fxmanifest.lua.")
    return
end

-- Framework variables
local ESX = nil
local QBCore = nil
local currentFramework = nil
local frameworkObject = nil

-----------------------------------------------------------
-- VERSION CHECKER (v2.1.0+)
-- Checks for updates on resource start via raw.githubusercontent.com
-- Only notifies admins via ACE permissions
-----------------------------------------------------------
local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
local githubRepo = "DaemonAlex/EmergencyVehicleMenu"
local updateAvailable = false
local latestVersionCached = nil

local function CompareVersions(current, latest)
    -- Parse semantic versions (handles formats like "2.1.0" or "2.1.0-DSRP")
    local function parseVersion(v)
        local major, minor, patch = v:match("^(%d+)%.(%d+)%.(%d+)")
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
    end

    local curMajor, curMinor, curPatch = parseVersion(current)
    local latMajor, latMinor, latPatch = parseVersion(latest)

    if latMajor > curMajor then return true end
    if latMajor == curMajor and latMinor > curMinor then return true end
    if latMajor == curMajor and latMinor == curMinor and latPatch > curPatch then return true end

    return false
end

local function CheckVersion()
    local url = ('https://raw.githubusercontent.com/%s/main/fxmanifest.lua'):format(githubRepo)

    PerformHttpRequest(url, function(status, text, headers)
        if status ~= 200 then
            if Config.Debug then
                print(("^3[VERSION-CHECK]:^0 Failed to check for updates (HTTP %d)"):format(status))
            end
            return
        end

        -- Extract version from fxmanifest.lua content
        local latestVersion = text:match("version ['\"]([%d%.]+)")

        if not latestVersion then
            if Config.Debug then
                print("^3[VERSION-CHECK]:^0 Could not parse version from GitHub")
            end
            return
        end

        latestVersionCached = latestVersion

        if CompareVersions(currentVersion, latestVersion) then
            updateAvailable = true
            print("^3╔══════════════════════════════════════════════════════════╗^0")
            print("^3║^1  [EmergencyVehicleMenu] UPDATE AVAILABLE!               ^3║^0")
            print(("^3║^0  Current: ^1%s^0 | Latest: ^2%s^0                       ^3║^0"):format(
                currentVersion:sub(1, 10), latestVersion:sub(1, 10)))
            print(("^3║^5  https://github.com/%s  ^3║^0"):format(githubRepo))
            print("^3╚══════════════════════════════════════════════════════════╝^0")
        else
            print(("^2[VERSION-CHECK]:^0 EmergencyVehicleMenu v%s is up to date"):format(currentVersion))
        end
    end, 'GET')
end

-- Notify admin when they join if update is available
local function NotifyAdminOfUpdate(playerId)
    if not updateAvailable then return end

    -- Check if player has admin ACE permission
    if not IsPlayerAceAllowed(playerId, 'command') then return end

    -- Delay notification slightly so it doesn't get lost in join spam
    SetTimeout(5000, function()
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'EmergencyVehicleMenu Update',
            description = ('v%s available (current: %s)'):format(
                latestVersionCached or "?.?.?",
                currentVersion
            ),
            type = 'warning',
            duration = 10000,
            icon = 'download'
        })
    end)
end

-- Check version on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CheckVersion()
end)

-- Notify admins when they join
AddEventHandler('playerJoining', function()
    local src = source
    NotifyAdminOfUpdate(src)
end)

-- Initialize framework
CreateThread(function()
    Wait(1000) -- Wait for resources to load
    
    -- Initialize auto-configuration
    Config.Initialize()
    
    currentFramework = Config.Framework
    
    if currentFramework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
        frameworkObject = ESX
        print("^2INFO:^0 ESX framework initialized on server")
    elseif currentFramework == 'qbcore' then
        if GetResourceState('qb-core') == 'started' then
            QBCore = exports['qb-core']:GetCoreObject()
        elseif GetResourceState('qbx_core') == 'started' then
            QBCore = exports['qbx_core']:GetCoreObject()
        end
        frameworkObject = QBCore
        print("^2INFO:^0 QBCore framework initialized on server")
    elseif currentFramework == 'qbox' then
        -- QBox uses qbx_core resource
        frameworkObject = exports['qbx_core']:GetCoreObject()
        print("^2INFO:^0 QBox framework initialized on server")
    else
        print("^2INFO:^0 Running in standalone mode")
    end
    
    -- Initialize job cache cleanup if caching is enabled
    if Config.CacheJobInfo then
        CreateThread(function()
            while true do
                Wait(Config.JobCacheTimeout or 300000) -- Default 5 minutes
                Config.CleanJobCache()
            end
        end)

        if Config.Debug then
            print("^2[AUTO-CONFIG]:^0 Job cache cleanup initialized")
        end
    end

    -- Event-driven job cache invalidation
    -- Listen for job changes instead of constant polling
    SetupJobChangeListeners(currentFramework)
end)

-----------------------------------------------------------
-- EVENT-DRIVEN JOB CACHE INVALIDATION
-- Instead of constant polling, we listen for job changes
-- and invalidate cache only when necessary
-----------------------------------------------------------
function InvalidatePlayerJobCache(playerId)
    if not playerId then return end

    -- Clear all cache entries for this player
    local keysToRemove = {}
    for key, _ in pairs(Config.JobCache) do
        if string.find(key, "^" .. tostring(playerId) .. ":") then
            table.insert(keysToRemove, key)
        end
    end

    for _, key in ipairs(keysToRemove) do
        Config.JobCache[key] = nil
        -- Also clear from ox_lib cache if available
        if lib and lib.cache then
            lib.cache.set('job_' .. key, nil, 0)
        end
    end

    if Config.Debug then
        print(("^2[JOB-CACHE]:^0 Invalidated cache for player %s (event-driven)"):format(playerId))
    end
end

function SetupJobChangeListeners(framework)
    if framework == 'esx' then
        -- ESX job change event
        RegisterNetEvent('esx:setJob')
        AddEventHandler('esx:setJob', function(job, lastJob)
            local src = source
            InvalidatePlayerJobCache(src)

            if Config.Debug then
                print(("^2[JOB-CACHE]:^0 ESX job change: Player %s | %s -> %s"):format(
                    src, lastJob and lastJob.name or "none", job.name
                ))
            end
        end)
        print("^2[JOB-CACHE]:^0 ESX job change listener registered")

    elseif framework == 'qbcore' then
        -- QBCore job change event
        RegisterNetEvent('QBCore:Server:OnJobUpdate')
        AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
            InvalidatePlayerJobCache(source)

            if Config.Debug then
                print(("^2[JOB-CACHE]:^0 QBCore job change: Player %s | New job: %s"):format(
                    source, job.name
                ))
            end
        end)

        -- Also listen for player data updates
        RegisterNetEvent('QBCore:Server:PlayerDataUpdate')
        AddEventHandler('QBCore:Server:PlayerDataUpdate', function(source, key, value)
            if key == 'job' then
                InvalidatePlayerJobCache(source)
            end
        end)
        print("^2[JOB-CACHE]:^0 QBCore job change listeners registered")

    elseif framework == 'qbox' then
        -- QBox uses similar events to QBCore
        RegisterNetEvent('QBCore:Server:OnJobUpdate')
        AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
            InvalidatePlayerJobCache(source)

            if Config.Debug then
                print(("^2[JOB-CACHE]:^0 QBox job change: Player %s | New job: %s"):format(
                    source, job.name
                ))
            end
        end)

        -- QBox-specific event
        RegisterNetEvent('qbx_core:server:onJobUpdate')
        AddEventHandler('qbx_core:server:onJobUpdate', function(source, job)
            InvalidatePlayerJobCache(source)
        end)
        print("^2[JOB-CACHE]:^0 QBox job change listeners registered")
    end

    -- Universal: Invalidate cache when player disconnects
    AddEventHandler('playerDropped', function(reason)
        local src = source
        InvalidatePlayerJobCache(src)
    end)

    print("^2[JOB-CACHE]:^0 Event-driven job cache invalidation active")
end

-- Initialize database
local ox_mysql = exports['oxmysql']

CreateThread(function()
    Wait(1000) -- Wait for oxmysql to initialize

    -- Create database tables if they don't exist
    ox_mysql:execute([[
        CREATE TABLE IF NOT EXISTS custom_liveries (
            id INT NOT NULL AUTO_INCREMENT,
            vehicle_model VARCHAR(255) NOT NULL,
            livery_name VARCHAR(255) NOT NULL,
            livery_file VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        )
    ]], {}, function(result)
        if result then
            print("^2INFO:^0 custom_liveries table created or already exists.")
        else
            print("^1ERROR:^0 Failed to create custom_liveries table.")
        end
    end)

    -- Create vehicle_mods table if it doesn't exist
    ox_mysql:execute([[
        CREATE TABLE IF NOT EXISTS vehicle_mods (
            id INT NOT NULL AUTO_INCREMENT,
            vehicle_model VARCHAR(255) NOT NULL,
            extras TEXT,
            player_id VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY vehicle_model_unique (vehicle_model)
        )
    ]], {}, function(result)
        if result then
            print("^2INFO:^0 vehicle_mods table created or already exists.")
        else
            print("^1ERROR:^0 Failed to create vehicle_mods table.")
        end
    end)

    -- Create vehicle_presets table for fleet standardization (v2.1.0+)
    ox_mysql:execute([[
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
    ]], {}, function(result)
        if result then
            print("^2INFO:^0 vehicle_presets table created or already exists.")
        else
            print("^1ERROR:^0 Failed to create vehicle_presets table.")
        end
    end)

    -- Create player_livery_memory table for auto-apply (v2.1.0+)
    ox_mysql:execute([[
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
    ]], {}, function(result)
        if result then
            print("^2INFO:^0 player_livery_memory table created or already exists.")
        else
            print("^1ERROR:^0 Failed to create player_livery_memory table.")
        end
    end)

    -- Load custom liveries from database
    ox_mysql:execute("SELECT vehicle_model, livery_name, livery_file FROM custom_liveries", {}, function(result)
        if result and #result > 0 then
            for _, livery in ipairs(result) do
                if not Config.CustomLiveries[livery.vehicle_model] then
                    Config.CustomLiveries[livery.vehicle_model] = {}
                end
                
                table.insert(Config.CustomLiveries[livery.vehicle_model], {
                    name = livery.livery_name,
                    file = livery.livery_file
                })
            end
            
            print("^2INFO:^0 Loaded " .. #result .. " custom liveries from database.")
        else
            print("^3INFO:^0 No custom liveries found in database.")
        end
    end)
    
    print("^2INFO:^0 Vehicle Modification System initialized successfully.")
end)

-- Apply a custom livery to a vehicle
AddEventHandler('vehiclemods:server:applyCustomLivery', function(netId, vehicleModelName, liveryFile)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if not vehicle or not DoesEntityExist(vehicle) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Vehicle not found.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    TriggerClientEvent('vehiclemods:client:setCustomLivery', -1, netId, vehicleModelName, liveryFile)
    
    if Config.Debug then
        print("^2DEBUG:^0 Applied custom livery " .. vehicleModelName .. "/" .. liveryFile .. " to vehicle with netId " .. netId)
    end
end)

-- Clear custom livery from a vehicle
RegisterNetEvent('vehiclemods:server:clearCustomLivery')
AddEventHandler('vehiclemods:server:clearCustomLivery', function(netId)
    -- Broadcast to all clients to clear the custom livery
    TriggerClientEvent('vehiclemods:client:clearCustomLivery', -1, netId)
    
    if Config.Debug then
        print("^2DEBUG:^0 Cleared custom livery from vehicle with netId " .. netId)
    end
end)

-- Save vehicle modifications
RegisterNetEvent('vehiclemods:server:saveModifications')
AddEventHandler('vehiclemods:server:saveModifications', function(vehicleModel, vehicleProps)
    local src = source
    local playerId = tostring(src) -- In standalone mode, use the player's server ID
    
    if Config.Debug then
        print("^2DEBUG:^0 Saving modifications for vehicle: " .. vehicleModel)
    end
    
    ox_mysql:execute("INSERT INTO vehicle_mods (vehicle_model, extras, player_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE extras = VALUES(extras)",
        {vehicleModel, vehicleProps, playerId})
        
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Vehicle Saved',
        description = 'Your vehicle configuration has been saved.',
        type = 'success',
        duration = 5000
    })
end)

-- Add a new custom livery
-- Add a new custom livery
RegisterNetEvent('vehiclemods:server:addCustomLivery')
AddEventHandler('vehiclemods:server:addCustomLivery', function(vehicleModel, liveryName, liveryFile)
    local src = source
    
    -- Don't add "liveries/" prefix to the file path anymore
    -- Just ensure it has .yft extension
    if not string.match(liveryFile, "%.yft$") then
        liveryFile = liveryFile .. ".yft"
    end
    
    -- First, check if the vehicle model exists in the custom liveries config
    if not Config.CustomLiveries[vehicleModel:lower()] then
        Config.CustomLiveries[vehicleModel:lower()] = {}
    end
    
    -- Check if we've reached the limit of 20 liveries for this vehicle
    if #Config.CustomLiveries[vehicleModel:lower()] >= 20 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Limit Reached',
            description = 'This vehicle already has the maximum of 20 custom liveries.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Add the new livery
    table.insert(Config.CustomLiveries[vehicleModel:lower()], {
        name = liveryName,
        file = liveryFile
    })
    
    -- Save to database
    ox_mysql:execute("INSERT INTO custom_liveries (vehicle_model, livery_name, livery_file) VALUES (?, ?, ?)",
        {vehicleModel:lower(), liveryName, liveryFile})
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Livery Added',
        description = 'Custom livery "' .. liveryName .. '" added for ' .. vehicleModel,
        type = 'success',
        duration = 5000
    })
    
    -- Broadcast the updated config to all clients
    TriggerClientEvent('vehiclemods:client:updateCustomLiveries', -1, Config.CustomLiveries)
end)

-- Request vehicle configuration
RegisterNetEvent('vehiclemods:server:requestVehicleConfig')
AddEventHandler('vehiclemods:server:requestVehicleConfig', function(vehicleModel)
    local src = source
    local playerId = tostring(src) -- In standalone mode, use the player's server ID
    
    -- Check if config exists in database
    ox_mysql:execute('SELECT extras FROM vehicle_mods WHERE vehicle_model = ?', {vehicleModel}, 
        function(result)
            if result and result[1] and result[1].extras then
                -- Send the configuration back to the client
                TriggerClientEvent('vehiclemods:client:applyVehicleConfig', src, vehicleModel, result[1].extras)
                
                if Config.Debug then
                    print("^2DEBUG:^0 Sent saved configuration for " .. vehicleModel .. " to player " .. src)
                end
            else
                if Config.Debug then
                    print("^3DEBUG:^0 No saved configuration found for " .. vehicleModel)
                end
            end
        end
    )
end)

-- Remove a custom livery
RegisterNetEvent('vehiclemods:server:removeCustomLivery')
AddEventHandler('vehiclemods:server:removeCustomLivery', function(vehicleModel, liveryName)
    local src = source
    
    -- Check if the vehicle model exists in the custom liveries config
    if not Config.CustomLiveries[vehicleModel:lower()] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No custom liveries found for this vehicle.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Find and remove the livery
    local removed = false
    for i, livery in ipairs(Config.CustomLiveries[vehicleModel:lower()]) do
        if livery.name == liveryName then
            table.remove(Config.CustomLiveries[vehicleModel:lower()], i)
            removed = true
            break
        end
    end
    
    if removed then
        -- Remove from database
        ox_mysql:execute("DELETE FROM custom_liveries WHERE vehicle_model = ? AND livery_name = ?",
            {vehicleModel:lower(), liveryName})
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Livery Removed',
            description = 'Custom livery "' .. liveryName .. '" removed from ' .. vehicleModel,
            type = 'success',
            duration = 5000
        })
        
        -- Broadcast the updated config to all clients
        TriggerClientEvent('vehiclemods:client:updateCustomLiveries', -1, Config.CustomLiveries)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Livery "' .. liveryName .. '" not found.',
            type = 'error',
            duration = 5000
        })
    end
end)

-- Send all custom liveries to a client when requested
RegisterNetEvent('vehiclemods:server:requestCustomLiveries')
AddEventHandler('vehiclemods:server:requestCustomLiveries', function()
    local src = source
    TriggerClientEvent('vehiclemods:client:updateCustomLiveries', src, Config.CustomLiveries)
end)

-- Initialize custom liveries when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Load all custom liveries from database
    ox_mysql:execute("SELECT vehicle_model, livery_name, livery_file FROM custom_liveries", {}, function(result)
        if result and #result > 0 then
            for _, livery in ipairs(result) do
                if not Config.CustomLiveries[livery.vehicle_model] then
                    Config.CustomLiveries[livery.vehicle_model] = {}
                end
                
                table.insert(Config.CustomLiveries[livery.vehicle_model], {
                    name = livery.livery_name,
                    file = livery.livery_file
                })
            end
            
            print("^2INFO:^0 Loaded " .. #result .. " custom liveries from database.")
        else
            print("^3INFO:^0 No custom liveries found in database.")
        end
    end)
end)

-- Duplicate event handler removed - functionality already exists above

-----------------------------------------------------------
-- FIELD REPAIR SYSTEM (v2.1.0+)
-- Server-side item checking and cooldown management
-----------------------------------------------------------
local fieldRepairCooldowns = {} -- Track per-player cooldowns

-- Get player identifier based on framework
local function GetPlayerIdentifier(playerId)
    if currentFramework == 'esx' and frameworkObject then
        local xPlayer = frameworkObject.GetPlayerFromId(playerId)
        return xPlayer and xPlayer.identifier or nil
    elseif currentFramework == 'qbcore' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        return Player and Player.PlayerData.citizenid or nil
    elseif currentFramework == 'qbox' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        return Player and Player.PlayerData.citizenid or nil
    end
    return 'player_' .. tostring(playerId) -- Fallback for standalone
end

-- Get player job based on framework
local function GetPlayerJob(playerId)
    if currentFramework == 'esx' and frameworkObject then
        local xPlayer = frameworkObject.GetPlayerFromId(playerId)
        if xPlayer then
            return xPlayer.job.name, xPlayer.job.grade
        end
    elseif currentFramework == 'qbcore' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            return Player.PlayerData.job.name, Player.PlayerData.job.grade.level
        end
    elseif currentFramework == 'qbox' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            return Player.PlayerData.job.name, Player.PlayerData.job.grade.level
        end
    end
    return nil, 0
end

-- Check if player has required item
local function HasRequiredItem(playerId, items)
    if currentFramework == 'esx' and frameworkObject then
        local xPlayer = frameworkObject.GetPlayerFromId(playerId)
        if xPlayer then
            for _, itemName in ipairs(items) do
                local item = xPlayer.getInventoryItem(itemName)
                if item and item.count > 0 then
                    return true, itemName
                end
            end
        end
    elseif currentFramework == 'qbcore' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            for _, itemName in ipairs(items) do
                local item = Player.Functions.GetItemByName(itemName)
                if item and item.amount > 0 then
                    return true, itemName
                end
            end
        end
    elseif currentFramework == 'qbox' and frameworkObject then
        -- QBox uses ox_inventory typically
        for _, itemName in ipairs(items) do
            local hasItem = exports.ox_inventory:GetItemCount(playerId, itemName)
            if hasItem and hasItem > 0 then
                return true, itemName
            end
        end
    else
        -- Standalone - always allow or check ox_inventory if available
        if GetResourceState('ox_inventory') == 'started' then
            for _, itemName in ipairs(items) do
                local hasItem = exports.ox_inventory:GetItemCount(playerId, itemName)
                if hasItem and hasItem > 0 then
                    return true, itemName
                end
            end
        else
            return true, items[1] -- Allow in standalone without inventory
        end
    end
    return false, nil
end

-- Remove item from player inventory
local function RemoveItem(playerId, itemName)
    if currentFramework == 'esx' and frameworkObject then
        local xPlayer = frameworkObject.GetPlayerFromId(playerId)
        if xPlayer then
            xPlayer.removeInventoryItem(itemName, 1)
            return true
        end
    elseif currentFramework == 'qbcore' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.RemoveItem(itemName, 1)
            TriggerClientEvent('inventory:client:ItemBox', playerId, frameworkObject.Shared.Items[itemName], 'remove')
            return true
        end
    elseif currentFramework == 'qbox' or GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:RemoveItem(playerId, itemName, 1)
        return true
    end
    return true -- Standalone without inventory
end

-- Field repair validation
RegisterNetEvent('vehiclemods:server:requestFieldRepair')
AddEventHandler('vehiclemods:server:requestFieldRepair', function()
    local src = source
    local cfg = Config.FieldRepair

    if not cfg or not cfg.enabled then
        TriggerClientEvent('vehiclemods:client:fieldRepairResult', src, false, 'Field repair is disabled')
        return
    end

    -- Check cooldown
    local currentTime = os.time()
    if fieldRepairCooldowns[src] and (currentTime - fieldRepairCooldowns[src]) < (cfg.cooldown / 1000) then
        local remaining = math.ceil((cfg.cooldown / 1000) - (currentTime - fieldRepairCooldowns[src]))
        TriggerClientEvent('vehiclemods:client:fieldRepairResult', src, false,
            ('Field repair on cooldown. %d seconds remaining.'):format(remaining))
        return
    end

    -- Check job if required
    local playerJob, playerGrade = GetPlayerJob(src)
    local jobAllowed = false

    if cfg.allowedJobs and #cfg.allowedJobs > 0 then
        for _, allowedJob in ipairs(cfg.allowedJobs) do
            if playerJob == allowedJob then
                jobAllowed = true
                break
            end
        end

        if not jobAllowed then
            TriggerClientEvent('vehiclemods:client:fieldRepairResult', src, false,
                'Your job does not allow field repairs')
            return
        end

        -- Check grade
        if cfg.minGrade > 0 and playerGrade < cfg.minGrade then
            TriggerClientEvent('vehiclemods:client:fieldRepairResult', src, false,
                ('Requires job grade %d+'):format(cfg.minGrade))
            return
        end
    end

    -- Check for required item
    if cfg.requireItem then
        local hasItem, itemName = HasRequiredItem(src, cfg.alternativeItems or {cfg.itemName})
        if not hasItem then
            TriggerClientEvent('vehiclemods:client:fieldRepairResult', src, false,
                'You need a repair kit to perform field repairs')
            return
        end

        -- Consume item if configured
        if cfg.consumeItem then
            RemoveItem(src, itemName)
        end
    end

    -- Set cooldown and approve repair
    fieldRepairCooldowns[src] = currentTime
    TriggerClientEvent('vehiclemods:client:fieldRepairResult', src, true, nil, cfg.maxEngineRepair, cfg.repairTime)

    if Config.Debug then
        print(("^2[FIELD-REPAIR]:^0 Player %s approved for field repair (Job: %s, Grade: %d)"):format(
            src, playerJob or "unknown", playerGrade))
    end
end)

-----------------------------------------------------------
-- PRESET SYSTEM (v2.1.0+)
-- Save, load, delete vehicle configuration presets
-----------------------------------------------------------

-- Save a preset
RegisterNetEvent('vehiclemods:server:savePreset')
AddEventHandler('vehiclemods:server:savePreset', function(presetName, vehicleModel, presetData, isJobPreset)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local cfg = Config.Presets

    if not cfg or not cfg.enabled then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Preset system is disabled',
            type = 'error'
        })
        return
    end

    local jobPresetName = nil
    if isJobPreset and cfg.allowJobPresets then
        local playerJob, playerGrade = GetPlayerJob(src)
        if playerGrade < cfg.minGradeForJobPresets then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = ('Requires grade %d+ to create job presets'):format(cfg.minGradeForJobPresets),
                type = 'error'
            })
            return
        end
        jobPresetName = playerJob
    end

    -- Check preset limits
    ox_mysql:execute(
        'SELECT COUNT(*) as count FROM vehicle_presets WHERE owner_identifier = ? AND job_preset IS NULL',
        {identifier},
        function(result)
            local personalCount = result and result[1] and result[1].count or 0

            if not isJobPreset and personalCount >= cfg.maxPresetsPerPlayer then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Limit Reached',
                    description = ('Maximum %d personal presets allowed'):format(cfg.maxPresetsPerPlayer),
                    type = 'error'
                })
                return
            end

            -- Serialize preset data
            local presetJson = json.encode(presetData)

            -- Insert or update preset
            ox_mysql:execute([[
                INSERT INTO vehicle_presets (preset_name, vehicle_model, owner_identifier, job_preset, preset_data)
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE preset_data = VALUES(preset_data), updated_at = CURRENT_TIMESTAMP
            ]], {presetName, vehicleModel:lower(), identifier, jobPresetName, presetJson}, function(insertResult)
                if insertResult then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Preset Saved',
                        description = ('Saved "%s" for %s'):format(presetName, vehicleModel),
                        type = 'success'
                    })
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Error',
                        description = 'Failed to save preset',
                        type = 'error'
                    })
                end
            end)
        end
    )
end)

-- Load presets for a vehicle
RegisterNetEvent('vehiclemods:server:loadPresets')
AddEventHandler('vehiclemods:server:loadPresets', function(vehicleModel)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local playerJob = GetPlayerJob(src)

    -- Get personal and job presets
    ox_mysql:execute([[
        SELECT preset_name, preset_data, job_preset, owner_identifier
        FROM vehicle_presets
        WHERE vehicle_model = ? AND (owner_identifier = ? OR job_preset = ?)
        ORDER BY job_preset IS NOT NULL DESC, preset_name ASC
    ]], {vehicleModel:lower(), identifier, playerJob}, function(result)
        local presets = {}
        if result then
            for _, row in ipairs(result) do
                table.insert(presets, {
                    name = row.preset_name,
                    data = json.decode(row.preset_data),
                    isJobPreset = row.job_preset ~= nil,
                    isOwner = row.owner_identifier == identifier
                })
            end
        end
        TriggerClientEvent('vehiclemods:client:receivePresets', src, presets)
    end)
end)

-- Delete a preset
RegisterNetEvent('vehiclemods:server:deletePreset')
AddEventHandler('vehiclemods:server:deletePreset', function(presetName, vehicleModel)
    local src = source
    local identifier = GetPlayerIdentifier(src)

    ox_mysql:execute(
        'DELETE FROM vehicle_presets WHERE preset_name = ? AND vehicle_model = ? AND owner_identifier = ?',
        {presetName, vehicleModel:lower(), identifier},
        function(result)
            if result and result.affectedRows > 0 then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Preset Deleted',
                    description = ('Deleted "%s"'):format(presetName),
                    type = 'success'
                })
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Error',
                    description = 'Preset not found or not owned by you',
                    type = 'error'
                })
            end
        end
    )
end)

-----------------------------------------------------------
-- LIVERY MEMORY SYSTEM (v2.1.0+)
-- Remember last used livery per vehicle model per player
-----------------------------------------------------------

-- Save livery selection
RegisterNetEvent('vehiclemods:server:saveLiveryMemory')
AddEventHandler('vehiclemods:server:saveLiveryMemory', function(vehicleModel, liveryIndex, liveryMod, customLivery, extras)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local cfg = Config.AutoApplyLivery

    if not cfg or not cfg.enabled then return end

    local extrasJson = extras and json.encode(extras) or nil

    ox_mysql:execute([[
        INSERT INTO player_livery_memory (identifier, vehicle_model, livery_index, livery_mod, custom_livery, extras)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            livery_index = VALUES(livery_index),
            livery_mod = VALUES(livery_mod),
            custom_livery = VALUES(custom_livery),
            extras = VALUES(extras),
            updated_at = CURRENT_TIMESTAMP
    ]], {identifier, vehicleModel:lower(), liveryIndex or -1, liveryMod or -1, customLivery, extrasJson})

    if Config.Debug then
        print(("^2[LIVERY-MEMORY]:^0 Saved for %s: %s (livery: %d, mod: %d, custom: %s)"):format(
            src, vehicleModel, liveryIndex or -1, liveryMod or -1, customLivery or "none"))
    end
end)

-- Load livery memory for a vehicle
RegisterNetEvent('vehiclemods:server:loadLiveryMemory')
AddEventHandler('vehiclemods:server:loadLiveryMemory', function(vehicleModel)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local cfg = Config.AutoApplyLivery

    if not cfg or not cfg.enabled then return end

    ox_mysql:execute(
        'SELECT livery_index, livery_mod, custom_livery, extras FROM player_livery_memory WHERE identifier = ? AND vehicle_model = ?',
        {identifier, vehicleModel:lower()},
        function(result)
            if result and result[1] then
                local memory = result[1]
                local extras = memory.extras and json.decode(memory.extras) or nil
                TriggerClientEvent('vehiclemods:client:applyLiveryMemory', src, vehicleModel, {
                    liveryIndex = memory.livery_index,
                    liveryMod = memory.livery_mod,
                    customLivery = memory.custom_livery,
                    extras = extras
                })
            end
        end
    )
end)

-- Clear player cooldowns on disconnect
AddEventHandler('playerDropped', function()
    local src = source
    fieldRepairCooldowns[src] = nil
end)

-----------------------------------------------------------
-- REPAIR COST SYSTEM (v2.1.1+)
-- Charge players for repairs based on config
-----------------------------------------------------------

-- Get player money based on framework
local function GetPlayerMoney(playerId, moneyType)
    if currentFramework == 'esx' and frameworkObject then
        local xPlayer = frameworkObject.GetPlayerFromId(playerId)
        if xPlayer then
            if moneyType == 'bank' then
                return xPlayer.getAccount('bank').money
            else
                return xPlayer.getMoney()
            end
        end
    elseif currentFramework == 'qbcore' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            if moneyType == 'bank' then
                return Player.PlayerData.money.bank
            else
                return Player.PlayerData.money.cash
            end
        end
    elseif currentFramework == 'qbox' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            if moneyType == 'bank' then
                return Player.PlayerData.money.bank
            else
                return Player.PlayerData.money.cash
            end
        end
    end
    return 0
end

-- Remove money from player
local function RemoveMoney(playerId, amount, moneyType)
    if currentFramework == 'esx' and frameworkObject then
        local xPlayer = frameworkObject.GetPlayerFromId(playerId)
        if xPlayer then
            if moneyType == 'bank' then
                xPlayer.removeAccountMoney('bank', amount)
            else
                xPlayer.removeMoney(amount)
            end
            return true
        end
    elseif currentFramework == 'qbcore' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.RemoveMoney(moneyType, amount, 'vehicle-repair')
            return true
        end
    elseif currentFramework == 'qbox' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.RemoveMoney(moneyType, amount, 'vehicle-repair')
            return true
        end
    end
    return false
end

-- Check if player's job gets free/discounted repairs
local function GetRepairDiscount(playerId)
    local cfg = Config.RepairCosts
    if not cfg then return 0 end

    local playerJob = GetPlayerJob(playerId)
    if not playerJob then return 0 end

    -- Check free jobs
    if cfg.freeForJobs then
        for _, job in ipairs(cfg.freeForJobs) do
            if playerJob == job then
                return 1.0 -- 100% discount (free)
            end
        end
    end

    -- Check discount jobs
    if cfg.discountJobs then
        for _, discountInfo in ipairs(cfg.discountJobs) do
            if playerJob == discountInfo.job then
                return discountInfo.discount or 0
            end
        end
    end

    return 0
end

-- Handle repair payment request
RegisterNetEvent('vehiclemods:server:chargeRepair')
AddEventHandler('vehiclemods:server:chargeRepair', function(repairType, cost)
    local src = source
    local cfg = Config.RepairCosts

    -- If repair costs disabled, allow free
    if not cfg or not cfg.enabled then
        TriggerClientEvent('vehiclemods:client:repairPaymentResult', src, true)
        return
    end

    -- Check jg-scripts compatibility (defer to jg-mechanic for repairs)
    local jgCompat = Config.Compatibility and Config.Compatibility['jg-scripts']
    if jgCompat and jgCompat.enabled and jgCompat.deferToMechanicForRepairs then
        TriggerClientEvent('vehiclemods:client:repairPaymentResult', src, true)
        if Config.Debug then
            print(("^2[COMPAT]:^0 Skipping repair charge (jg-mechanic handles economy)"))
        end
        return
    end

    -- Apply job discount
    local discount = GetRepairDiscount(src)
    local finalCost = math.floor(cost * (1 - discount))

    if finalCost <= 0 then
        TriggerClientEvent('vehiclemods:client:repairPaymentResult', src, true)
        return
    end

    -- Try to charge from configured source
    local chargeFrom = cfg.chargeFrom or 'bank'
    local success = false
    local chargedFrom = nil

    if chargeFrom == 'both' then
        -- Try bank first, then cash
        local bankMoney = GetPlayerMoney(src, 'bank')
        if bankMoney >= finalCost then
            success = RemoveMoney(src, finalCost, 'bank')
            chargedFrom = 'bank'
        else
            local cashMoney = GetPlayerMoney(src, 'cash')
            if cashMoney >= finalCost then
                success = RemoveMoney(src, finalCost, 'cash')
                chargedFrom = 'cash'
            end
        end
    else
        local money = GetPlayerMoney(src, chargeFrom)
        if money >= finalCost then
            success = RemoveMoney(src, finalCost, chargeFrom)
            chargedFrom = chargeFrom
        end
    end

    if success then
        TriggerClientEvent('vehiclemods:client:repairPaymentResult', src, true)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Repair Payment',
            description = ('$%d charged from %s'):format(finalCost, chargedFrom),
            type = 'success',
            duration = 3000
        })

        if Config.Debug then
            print(("^2[REPAIR-COST]:^0 Player %s charged $%d for %s repair"):format(src, finalCost, repairType))
        end
    else
        TriggerClientEvent('vehiclemods:client:repairPaymentResult', src, false,
            ('Insufficient funds. Need $%d'):format(finalCost))
    end
end)

