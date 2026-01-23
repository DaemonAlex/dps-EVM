-- Framework variables
ESX = nil
QBCore = nil

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if not Config then
        print("^1CRITICAL ERROR:^0 Config not loaded!")
        return
    end

    -- Initialize auto-configuration
    Config.Initialize()
    
    local framework = Config.Framework

    if framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
        print("^2INFO:^0 ESX initialized")
    elseif framework == 'qbcore' then
        if GetResourceState('qb-core') == 'started' then
            QBCore = exports['qb-core']:GetCoreObject()
        elseif GetResourceState('qbx_core') == 'started' then
            QBCore = exports['qbx_core']:GetCoreObject()
        end
        print("^2INFO:^0 QBCore initialized")
    elseif framework == 'qbox' then
        -- QBox uses exports directly, no need to get core object
        print("^2INFO:^0 QBox framework detected")
    end

    print("^2SUCCESS:^0 Vehicle Modification System client initialized with " .. framework .. " framework")
    
    if Config.Debug then
        print("^2[AUTO-CONFIG]:^0 Client configuration completed")
        print("^2[AUTO-CONFIG]:^0 Zones available: " .. #Config.ModificationZones)
        print("^2[AUTO-CONFIG]:^0 Modifications enabled: " .. (Config.EnabledModifications and "Yes" or "No"))
    end
end)

if not Config then
    print("^1ERROR:^0 Config is not loaded! Check fxmanifest.lua.")
    return
end

-- Performance optimization variables
local TEXTURE_LOAD_TIMEOUT = 300
local loadedTextures = {}

-- Command to open the vehicle modification menu
RegisterCommand('modveh', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local inZone, zoneInfo = Config.IsInModificationZone(playerCoords)
    
    if not inZone then
        lib.notify({
            title = 'Access Denied',
            description = zoneInfo.message,
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You must be in a vehicle to use this menu',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Check if vehicle is an emergency vehicle (if restriction is enabled)
    if Config.EmergencyVehiclesOnly and not Config.IsEmergencyVehicle(vehicle) then
        lib.notify({
            title = 'Vehicle Not Authorized',
            description = 'Only emergency vehicles can be modified here',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    print("^2SUCCESS:^0 " .. zoneInfo.message .. ". Opening menu...")
    TriggerEvent('vehiclemods:client:openVehicleModMenu')
end, false)

-- Display help text function
function DisplayHelpTextThisFrame(text, beep)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

-- Add a keybind to quickly open the menu without typing the command
RegisterKeyMapping('modveh', 'Open Vehicle Modification Menu', 'keyboard', 'F7')

-- Initialize variables
ActiveCustomLiveries = {}

-- Zone blips and markers
local zoneBlips = {}

-- Create blips for modification zones
CreateThread(function()
    if not Config.ShowBlips then return end

    for i, zone in ipairs(Config.ModificationZones) do
        local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)

        if zone.type == "police" then
            SetBlipSprite(blip, 60) -- Police station
            SetBlipColour(blip, 3) -- Light blue
        elseif zone.type == "fire" then
            SetBlipSprite(blip, 436) -- Fire station
            SetBlipColour(blip, 1) -- Red
        else
            SetBlipSprite(blip, 446) -- Garage
            SetBlipColour(blip, 5) -- Yellow
        end

        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(zone.name)
        EndTextCommandSetBlipName(blip)

        zoneBlips[i] = blip
    end
end)

-- Invisible zone checking - no visual markers, only access control
local lastAccessAttempt = {}
local ACCESS_COOLDOWN = 2000 -- 2 seconds between access attempts per zone

-- Performance-optimized zone checking with dynamic tick rates
-- Uses tiered sleep similar to FiveM best practices:
-- >100m: 2000ms (deep sleep), 30-100m: 1000ms, <30m: 500ms, in-zone: 250ms
CreateThread(function()
    while true do
        local sleep = 2000  -- Default: deep sleep when far from all zones
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        -- Early exit if not in vehicle - no need to check zones
        if vehicle == 0 then
            Wait(sleep)
            goto continue
        end

        local playerCoords = GetEntityCoords(playerPed)
        local currentTime = GetGameTimer()
        local nearestDistance = 999999.0
        local inAnyZone = false

        -- Find nearest zone and check if in any zone
        for i, zone in ipairs(Config.ModificationZones) do
            local distance = #(playerCoords - zone.coords)

            -- Track nearest zone for dynamic sleep calculation
            if distance < nearestDistance then
                nearestDistance = distance
            end

            -- Check if in this zone
            if distance <= zone.radius then
                inAnyZone = true

                -- Player entered zone with vehicle - check access with cooldown
                if not lastAccessAttempt[i] or (currentTime - lastAccessAttempt[i]) >= ACCESS_COOLDOWN then
                    lastAccessAttempt[i] = currentTime

                    -- Check zone access
                    local inZone, zoneInfo = Config.IsInModificationZone(playerCoords)

                    if inZone then
                        -- Access granted - show success notification and open menu
                        lib.notify({
                            title = 'Access Granted',
                            description = zoneInfo.message,
                            type = 'success',
                            duration = 3000
                        })
                        TriggerEvent('vehiclemods:client:openVehicleModMenu')
                    else
                        -- Access denied - show error notification
                        lib.notify({
                            title = 'Access Denied',
                            description = zoneInfo.message,
                            type = 'error',
                            duration = 4000
                        })
                    end
                end
                break  -- Already in a zone, no need to check others
            end
        end

        -- Dynamic sleep based on distance to nearest zone
        -- Optimized thresholds prevent wasted CPU cycles
        if inAnyZone then
            sleep = 250   -- In zone: responsive for menu interaction
        elseif nearestDistance < 30.0 then
            sleep = 500   -- Close: approaching zone
        elseif nearestDistance < 100.0 then
            sleep = 1000  -- Medium: zone visible on minimap
        else
            sleep = 2000  -- Far: deep sleep, conserve resources
        end

        Wait(sleep)
        ::continue::
    end
end)

-- Main menu event
RegisterNetEvent('vehiclemods:client:openVehicleModMenu')
AddEventHandler('vehiclemods:client:openVehicleModMenu', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local vehicleTitle = "Vehicle Menu"
    local vehicleInfo = nil

    if vehicle ~= 0 then
        -- IMPORTANT: Must set mod kit before accessing vehicle mods
        SetVehicleModKit(vehicle, 0)

        local vehicleModel = GetEntityModel(vehicle)
        local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModel)
        local vehicleMake = GetMakeNameFromVehicleModel(vehicleModel)

        vehicleTitle = vehicleModelName .. " Modifications"
        vehicleInfo = {
            {label = 'Make', value = (vehicleMake and vehicleMake ~= "") and vehicleMake or "Unknown"},
            {label = 'Model', value = vehicleModelName},
            {label = 'Class', value = GetVehicleClass(vehicle)}
        }
    end
    
    local options = {}
    
    -- Only add options that are enabled in the config
    if Config.EnabledModifications.Liveries then
        table.insert(options, {
            title = 'Liveries',
            description = 'Select a vehicle livery.',
            onSelect = function()
                OpenLiveryMenu()
            end
        })
    end
    
    if Config.EnabledModifications.CustomLiveries then
        table.insert(options, {
            title = 'Custom Liveries',
            description = 'Apply custom YFT liveries.',
            onSelect = function()
                OpenCustomLiveriesMenu()
            end
        })
    end
    
    if Config.EnabledModifications.Appearance then
        table.insert(options, {
            title = 'Vehicle Appearance',
            description = 'Customize vehicle appearance.',
            onSelect = function()
                OpenAppearanceMenu()
            end
        })
    end
    
    if Config.EnabledModifications.Performance then
        table.insert(options, {
            title = 'Performance Mods',
            description = 'Install performance upgrades.',
            onSelect = function()
                OpenPerformanceMenu()
            end
        })
    end
    
    if Config.EnabledModifications.Extras then
        table.insert(options, {
            title = 'Extras',
            description = 'Enable or disable vehicle extras.',
            onSelect = function()
                OpenExtrasMenu()
            end
        })
    end
    
    if Config.EnabledModifications.Doors then
        table.insert(options, {
            title = 'Doors',
            description = 'Open or close individual doors.',
            onSelect = function()
                OpenDoorsMenu()
            end
        })
    end

    -- Window controls (roll up/down) - always available for emergency vehicles
    table.insert(options, {
        title = 'Window Controls',
        description = 'Roll windows up or down.',
        icon = 'window-maximize',
        onSelect = function()
            OpenWindowControlsMenu()
        end
    })

    -- Seat controls (shuffle positions) - useful for passenger management
    table.insert(options, {
        title = 'Seat Controls',
        description = 'Move between seats or eject passengers.',
        icon = 'chair',
        onSelect = function()
            OpenSeatControlsMenu()
        end
    })

    -- Field Repair option (v2.1.0+) - works anywhere with toolkit
    if Config.FieldRepair and Config.FieldRepair.enabled then
        table.insert(options, {
            title = 'Field Repair',
            description = 'Emergency roadside repair (requires toolkit)',
            icon = 'toolbox',
            onSelect = function()
                RequestFieldRepair()
            end
        })
    end

    -- These options should always be available
    table.insert(options, {
        title = 'Emergency Repair',
        description = 'Partial repair for disabled vehicles (slow movement only)',
        onSelect = function()
            EmergencyRepairVehicle()
        end
    })

    table.insert(options, {
        title = 'Full Repair',
        description = 'Complete vehicle repair and performance restoration',
        onSelect = function()
            FullRepairVehicle()
        end
    })

    -- Preset System (v2.1.0+)
    if Config.Presets and Config.Presets.enabled then
        table.insert(options, {
            title = 'Vehicle Presets',
            description = 'Save and load vehicle configurations',
            icon = 'bookmark',
            onSelect = function()
                OpenPresetMenu()
            end
        })
    end

    table.insert(options, {
        title = 'Save Configuration',
        description = 'Save current vehicle setup.',
        onSelect = function()
            SaveVehicleConfig()
        end
    })

    table.insert(options, {
        title = 'Close Menu',
        description = 'Exit the vehicle modification menu',
        onSelect = function()
            lib.hideContext()
        end
    })

    lib.registerContext({
        id = 'VehicleModMenu',
        title = vehicleTitle,
        metadata = vehicleInfo,
        options = options
    })
    lib.showContext('VehicleModMenu')
end)

-- Livery Menu
-- Pagination settings for large livery lists
local LIVERIES_PER_PAGE = 20  -- Prevents frame drops with 50+ liveries

function OpenLiveryMenu(page)
    page = page or 1
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You need to be in a vehicle to change liveries',
            type = 'error',
            duration = 5000
        })
        return
    end

    -- IMPORTANT: Must set mod kit before accessing vehicle mods
    SetVehicleModKit(vehicle, 0)

    local options = {}
    local numLiveries = GetVehicleLiveryCount(vehicle)
    local currentLivery = GetVehicleLivery(vehicle)
    local numMods = GetNumVehicleMods(vehicle, 48)

    -- Determine total liveries (standard or mod-based)
    local totalLiveries = numLiveries > 0 and numLiveries or (numMods > 0 and numMods + 1 or 0)
    local totalPages = math.ceil(totalLiveries / LIVERIES_PER_PAGE)
    local startIndex = (page - 1) * LIVERIES_PER_PAGE
    local endIndex = math.min(startIndex + LIVERIES_PER_PAGE - 1, totalLiveries - 1)

    -- Add custom liveries option if available (always at top)
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModel):lower()

    if Config.CustomLiveries and Config.CustomLiveries[vehicleModelName] then
        table.insert(options, {
            title = 'Custom Liveries (YFT)',
            description = 'Browse custom YFT liveries for this vehicle',
            icon = 'palette',
            onSelect = function()
                OpenCustomLiveriesMenu()
            end
        })
    end

    -- Search option for large livery lists
    if totalLiveries > 10 then
        table.insert(options, {
            title = 'Search Liveries',
            description = 'Find specific liveries by name or number',
            icon = 'magnifying-glass',
            onSelect = function()
                OpenLiverySearchMenu()
            end
        })
    end

    -- Pagination header for large lists
    if totalPages > 1 then
        table.insert(options, {
            title = ('Page %d of %d (%d liveries)'):format(page, totalPages, totalLiveries),
            description = 'Use Previous/Next to navigate pages',
            icon = 'list-ol',
            disabled = true
        })
    end

    -- Build livery options for current page only (prevents frame drops)
    if numLiveries > 0 then
        -- Standard liveries
        for i = startIndex, endIndex do
            if i < numLiveries then
                local isActive = (currentLivery == i)
                local liveryIndex = i
                -- Use enhanced livery name with label lookup (v2.1.1+)
                local liveryName = GetEnhancedLiveryName and GetEnhancedLiveryName(vehicle, i) or ('Livery %d'):format(i)
                table.insert(options, {
                    title = liveryName,
                    description = isActive and 'Currently Active' or 'Click to apply',
                    icon = isActive and 'check-circle' or 'circle',
                    metadata = {
                        {label = 'ID', value = tostring(i)}
                    },
                    onSelect = function()
                        SetVehicleLivery(vehicle, liveryIndex)
                        SaveLiveryToMemory(vehicle) -- v2.1.0+ livery memory
                        lib.notify({
                            title = 'Livery Applied',
                            description = 'Applied ' .. liveryName,
                            type = 'success',
                            duration = 3000
                        })
                        OpenLiveryMenu(page)
                    end
                })
            end
        end
    elseif numMods > 0 then
        -- Mod-based liveries (index 48)
        local currentMod = GetVehicleMod(vehicle, 48)
        for i = startIndex, endIndex do
            local modIndex = i - 1  -- -1 is default, 0+ are mods
            if modIndex < numMods then
                local modName = modIndex == -1 and "Default" or ("Style %d"):format(modIndex + 1)
                local isActive = (currentMod == modIndex)

                table.insert(options, {
                    title = modName,
                    description = isActive and 'Currently Active' or 'Click to apply',
                    icon = isActive and 'check-circle' or 'circle',
                    onSelect = function()
                        SetVehicleMod(vehicle, 48, modIndex, false)
                        SaveLiveryToMemory(vehicle) -- v2.1.0+ livery memory
                        lib.notify({
                            title = 'Livery Applied',
                            description = 'Applied ' .. modName,
                            type = 'success',
                            duration = 3000
                        })
                        OpenLiveryMenu(page)
                    end
                })
            end
        end
    else
        table.insert(options, {
            title = 'No Liveries Available',
            description = 'This vehicle has no standard liveries',
            icon = 'ban',
            disabled = true
        })
    end

    -- Pagination controls
    if totalPages > 1 then
        if page > 1 then
            table.insert(options, {
                title = '← Previous Page',
                description = ('Go to page %d'):format(page - 1),
                icon = 'arrow-left',
                onSelect = function()
                    OpenLiveryMenu(page - 1)
                end
            })
        end

        if page < totalPages then
            table.insert(options, {
                title = 'Next Page →',
                description = ('Go to page %d'):format(page + 1),
                icon = 'arrow-right',
                onSelect = function()
                    OpenLiveryMenu(page + 1)
                end
            })
        end
    end

    lib.registerContext({
        id = 'LiveryMenu',
        title = totalPages > 1 and ('Liveries (Page %d/%d)'):format(page, totalPages) or 'Select Livery',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('LiveryMenu')
end

-- Custom Liveries Menu
function OpenCustomLiveriesMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You need to be in a vehicle to change liveries',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModel):lower()
    
    local availableLiveries = {}
    
    if Config.CustomLiveries then
        availableLiveries = Config.CustomLiveries[vehicleModelName] or {}
    else
        Config.CustomLiveries = {}
    end
    
    local options = {}
    
    table.insert(options, {
        title = 'Stock (No Livery)',
        description = 'Remove custom livery',
        onSelect = function()
            SetVehicleLivery(vehicle, 0)
            SetVehicleMod(vehicle, 48, -1, false)
            
            TriggerServerEvent('vehiclemods:server:clearCustomLivery', NetworkGetNetworkIdFromEntity(vehicle))
            
            lib.notify({
                title = 'Livery Removed',
                description = 'Custom livery removed',
                type = 'success',
                duration = 5000
            })
            OpenCustomLiveriesMenu()
        end
    })
    
    if availableLiveries and #availableLiveries > 0 then
        for i, livery in ipairs(availableLiveries) do
            table.insert(options, {
                title = livery.name,
                description = 'Apply ' .. livery.name .. ' livery',
                onSelect = function()
                    TriggerServerEvent('vehiclemods:server:applyCustomLivery', 
                        NetworkGetNetworkIdFromEntity(vehicle), 
                        vehicleModelName, 
                        livery.file
                    )
                    lib.notify({
                        title = 'Livery Applied',
                        description = 'Applied ' .. livery.name .. ' livery',
                        type = 'success',
                        duration = 5000
                    })
                    OpenCustomLiveriesMenu()
                end
            })
        end
    else
        table.insert(options, {
            title = 'No Custom Liveries',
            description = 'This vehicle has no custom YFT liveries configured',
            onSelect = function() end
        })
    end
    
    -- Option to add new livery
    table.insert(options, {
        title = 'Add New Livery',
        description = 'Add a new custom livery for this vehicle',
        onSelect = function()
            OpenAddCustomLiveryMenu(vehicleModelName)
        end
    })

    lib.registerContext({
        id = 'CustomLiveriesMenu',
        title = 'Custom Liveries',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('CustomLiveriesMenu')
end

-- Enhanced custom livery event handler with proper timeout and cleanup
RegisterNetEvent('vehiclemods:client:setCustomLivery')
AddEventHandler('vehiclemods:client:setCustomLivery', function(netId, vehicleModelName, liveryFile)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if not vehicle or not DoesEntityExist(vehicle) then
        if Config.Debug then
            print("^1ERROR:^0 Vehicle not found for custom livery application")
        end
        return
    end
    
    -- Validate inputs
    if not vehicleModelName or not liveryFile then
        print("^1ERROR:^0 Invalid parameters for custom livery")
        return
    end
    
    -- Extract base name without "liveries/" prefix
    local baseName = string.match(liveryFile, "([^/]+)%.yft$")
    if not baseName then
        baseName = liveryFile:gsub(".yft", "")
    end
    
    local textureDict = vehicleModelName .. "_" .. baseName
    
    -- Check if already loaded
    if not HasStreamedTextureDictLoaded(textureDict) then
        RequestStreamedTextureDict(textureDict)
        local timeout = 0
        while not HasStreamedTextureDictLoaded(textureDict) and timeout < TEXTURE_LOAD_TIMEOUT do
            Wait(10)
            timeout = timeout + 1
        end
        
        if not HasStreamedTextureDictLoaded(textureDict) then
            print("^1ERROR:^0 Failed to load texture dictionary: " .. textureDict .. " (timeout)")
            return
        end
    end
    
    if HasStreamedTextureDictLoaded(textureDict) then
        local vehicleEntityId = VehToNet(vehicle)
        if not ActiveCustomLiveries then ActiveCustomLiveries = {} end
        
        -- Clean up old texture if exists
        if ActiveCustomLiveries[vehicleEntityId] and ActiveCustomLiveries[vehicleEntityId].dict then
            local oldDict = ActiveCustomLiveries[vehicleEntityId].dict
            if oldDict ~= textureDict and HasStreamedTextureDictLoaded(oldDict) then
                SetStreamedTextureDictAsNoLongerNeeded(oldDict)
                if loadedTextures then
                    loadedTextures[oldDict] = nil
                end
            end
        end
        
        ActiveCustomLiveries[vehicleEntityId] = {
            file = liveryFile,
            dict = textureDict,
            model = vehicleModelName
        }
        
        -- Track loaded texture
        if not loadedTextures then loadedTextures = {} end
        loadedTextures[textureDict] = GetGameTimer()
        
        -- Apply livery
        local liveryModCount = GetNumVehicleMods(vehicle, 48)
        if liveryModCount > 0 then
            SetVehicleMod(vehicle, 48, 0, false)
        else
            local liveryCount = GetVehicleLiveryCount(vehicle)
            if liveryCount > 0 then
                SetVehicleLivery(vehicle, 1) -- Use first livery as base
            end
        end
        
        -- Update entity routing to refresh appearance
        local currentBucket = GetEntityRoutingBucket(vehicle)
        SetEntityRoutingBucket(vehicle, 100 + currentBucket)
        Wait(50)
        SetEntityRoutingBucket(vehicle, currentBucket)
        
        print("^2INFO:^0 Applied custom livery " .. liveryFile .. " to vehicle")
    else
        print("^1ERROR:^0 Failed to load texture dictionary for livery: " .. textureDict)
    end
end)

-- Removing custom liveries
RegisterNetEvent('vehiclemods:client:clearCustomLivery')
AddEventHandler('vehiclemods:client:clearCustomLivery', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if not vehicle or not DoesEntityExist(vehicle) then
        return
    end
    
    local vehicleEntityId = VehToNet(vehicle)
    if ActiveCustomLiveries and ActiveCustomLiveries[vehicleEntityId] then
        local liveryInfo = ActiveCustomLiveries[vehicleEntityId]
        
        SetVehicleLivery(vehicle, 0) -- Reset to default livery
        SetVehicleMod(vehicle, 48, -1, false) -- Remove livery mod
        
        if HasStreamedTextureDictLoaded(liveryInfo.dict) then
            SetStreamedTextureDictAsNoLongerNeeded(liveryInfo.dict)
        end
        
        ActiveCustomLiveries[vehicleEntityId] = nil
        
        print("^2INFO:^0 Cleared custom livery from vehicle")
    end
end)

-- Add custom livery menu
function OpenAddCustomLiveryMenu(vehicleModelName)
    lib.showTextInput({
        title = 'Add Custom Livery',
        description = 'Enter the name and YFT file for the new livery:',
        fields = {
            { label = 'Livery Name', name = 'name', type = 'text', required = true, placeholder = 'e.g. Police Livery 1' },
            { label = 'YFT File Path', name = 'file', type = 'text', required = true, placeholder = vehicleModelName .. '_livery1.yft' }
        },
        onSubmit = function(data)
            if data.name and data.file then
                TriggerServerEvent('vehiclemods:server:addCustomLivery', vehicleModelName, data.name, data.file)
                
                Citizen.SetTimeout(500, function()
                    OpenCustomLiveriesMenu()
                end)
            end
        end
    })
end

-- Function to search for liveries
function OpenLiverySearchMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    if vehicle == 0 then
        return
    end
    
    lib.showTextInput({
        title = 'Search Liveries',
        description = 'Enter a search term to filter liveries',
        placeholder = 'e.g. LSPD or Sheriff',
        onSubmit = function(data)
            if data and data ~= "" then
                FilteredLiveryMenu(data:lower())
            else
                OpenLiveryMenu()
            end
        end
    })
end

-- Function to filter liveries by search term
function FilteredLiveryMenu(searchTerm)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local options = {}
    local numLiveries = GetVehicleLiveryCount(vehicle)
    local currentLivery = GetVehicleLivery(vehicle)
    local filteredResults = 0
    
    -- For standard liveries
    if numLiveries > 0 then
        for i = 0, numLiveries - 1 do
            local liveryName = 'Livery ' .. i
            
            if string.find(liveryName:lower(), searchTerm) then
                local isActive = (currentLivery == i)
                table.insert(options, {
                    title = liveryName,
                    description = 'Apply ' .. liveryName,
                    metadata = {
                        {label = 'Status', value = isActive and 'Active' or 'Inactive'}
                    },
                    onSelect = function()
                        SetVehicleLivery(vehicle, i)
                        SaveLiveryToMemory(vehicle) -- v2.1.0+ livery memory
                        lib.notify({
                            title = 'Livery Applied',
                            description = 'Applied ' .. liveryName .. '.',
                            type = 'success',
                            duration = 5000
                        })
                        FilteredLiveryMenu(searchTerm)
                    end
                })
                filteredResults = filteredResults + 1
            end
        end
    end
    
    -- For mod slot 48 liveries
    local numMods = GetNumVehicleMods(vehicle, 48)
    local currentMod = GetVehicleMod(vehicle, 48)
    
    if numMods > 0 then
        for i = -1, numMods - 1 do
            local modName = i == -1 and "Default" or "Style " .. (i + 1)

            if string.find(modName:lower(), searchTerm) then
                local isActive = (currentMod == i)

                table.insert(options, {
                    title = modName,
                    description = 'Apply ' .. modName,
                    metadata = {
                        {label = 'Status', value = isActive and 'Active' or 'Inactive'}
                    },
                    onSelect = function()
                        SetVehicleMod(vehicle, 48, i, false)
                        SaveLiveryToMemory(vehicle) -- v2.1.0+ livery memory
                        lib.notify({
                            title = 'Livery Applied',
                            description = 'Applied ' .. modName .. '.',
                            type = 'success',
                            duration = 5000
                        })
                        FilteredLiveryMenu(searchTerm)
                    end
                })
                filteredResults = filteredResults + 1
            end
        end
    end
    
    -- Custom YFT liveries search
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModel):lower()
    
    if Config.CustomLiveries and Config.CustomLiveries[vehicleModelName] then
        for _, livery in ipairs(Config.CustomLiveries[vehicleModelName]) do
            if string.find(livery.name:lower(), searchTerm) then
                table.insert(options, {
                    title = livery.name,
                    description = 'Apply ' .. livery.name .. ' custom livery',
                    onSelect = function()
                        TriggerServerEvent('vehiclemods:server:applyCustomLivery', 
                            NetworkGetNetworkIdFromEntity(vehicle), 
                            vehicleModelName, 
                            livery.file
                        )
                        lib.notify({
                            title = 'Livery Applied',
                            description = 'Applied ' .. livery.name .. ' livery',
                            type = 'success',
                            duration = 5000
                        })
                        FilteredLiveryMenu(searchTerm)
                    end
                })
                filteredResults = filteredResults + 1
            end
        end
    end
    
    if filteredResults == 0 then
        table.insert(options, {
            title = 'No Results Found',
            description = 'No liveries match your search term: ' .. searchTerm,
            onSelect = function()
                OpenLiverySearchMenu()
            end
        })
    end
    
    table.insert(options, 1, {
        title = 'New Search',
        description = 'Search for a different livery',
        onSelect = function()
            OpenLiverySearchMenu()
        end
    })
    
    table.insert(options, 2, {
        title = 'Show All Liveries',
        description = 'Display all available liveries',
        onSelect = function()
            OpenLiveryMenu()
        end
    })

    lib.registerContext({
        id = 'FilteredLiveryMenu',
        title = 'Search Results: ' .. searchTerm,
        metadata = {
            {label = 'Results', value = filteredResults}
        },
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('FilteredLiveryMenu')
end

-- Performance Menu
function OpenPerformanceMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    -- IMPORTANT: Must set mod kit before accessing vehicle mods
    SetVehicleModKit(vehicle, 0)

    local modTypes = {
        { name = "Engine", id = 11 },
        { name = "Brakes", id = 12 },
        { name = "Transmission", id = 13 },
        { name = "Suspension", id = 15 },
        { name = "Armor", id = 16 },
        { name = "Turbo", id = 18 }
    }
    
    local options = {}
    
    for _, modType in pairs(modTypes) do
        local numMods = GetNumVehicleMods(vehicle, modType.id)
        local specialCase = false
        
        -- Special case for Turbo which is a toggle
        if modType.id == 18 then
            numMods = 1
            specialCase = true
        end
        
        if numMods > 0 then
            local status = ""
            if specialCase then
                status = IsToggleModOn(vehicle, modType.id) and "Enabled" or "Disabled"
            else
                local currentLevel = GetVehicleMod(vehicle, modType.id)
                if currentLevel == -1 then
                    status = "Stock"
                else
                    status = "Level " .. (currentLevel + 1)
                end
            end
            
            table.insert(options, {
                title = modType.name,
                description = specialCase and 'Toggle turbo on/off' or 'Available upgrades: ' .. numMods,
                metadata = {
                    {label = 'Current', value = status}
                },
                onSelect = function()
                    if specialCase then
                        ToggleTurbo(vehicle)
                    else
                        OpenPerformanceModMenu(modType.id, modType.name)
                    end
                end
            })
        end
    end

    lib.registerContext({
        id = 'PerformanceMenu',
        title = 'Performance Upgrades',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('PerformanceMenu')
end

-- Toggle turbo function
function ToggleTurbo(vehicle)
    local hasTurbo = IsToggleModOn(vehicle, 18)
    
    ToggleVehicleMod(vehicle, 18, not hasTurbo)
    
    lib.notify({
        title = 'Turbo',
        description = hasTurbo and 'Turbo disabled' or 'Turbo enabled',
        type = 'success',
        duration = 5000
    })
    
    OpenPerformanceMenu()
end

-- Performance mod selection menu
function OpenPerformanceModMenu(modType, modTypeName)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    -- IMPORTANT: Must set mod kit before accessing vehicle mods
    SetVehicleModKit(vehicle, 0)

    local options = {}
    local numMods = GetNumVehicleMods(vehicle, modType)
    local currentMod = GetVehicleMod(vehicle, modType)
    
    table.insert(options, {
        title = 'Stock ' .. modTypeName,
        description = 'Remove ' .. modTypeName .. ' upgrades',
        metadata = {
            {label = 'Status', value = (currentMod == -1) and 'Active' or 'Inactive'}
        },
        onSelect = function()
            SetVehicleMod(vehicle, modType, -1, false)
            lib.notify({
                title = 'Upgrade Removed',
                description = modTypeName .. ' set to stock',
                type = 'success',
                duration = 5000
            })
            OpenPerformanceModMenu(modType, modTypeName)
        end
    })
    
    local modNames = {}
    if modType == 11 then  -- Engine
        modNames = {"EMS Upgrade, Level 1", "EMS Upgrade, Level 2", "EMS Upgrade, Level 3", "EMS Upgrade, Level 4"}
    elseif modType == 12 then  -- Brakes
        modNames = {"Street Brakes", "Sport Brakes", "Race Brakes", "Racing Brakes"}
    elseif modType == 13 then  -- Transmission
        modNames = {"Street Transmission", "Sports Transmission", "Race Transmission", "Super Transmission"}
    elseif modType == 15 then  -- Suspension
        modNames = {"Lowered Suspension", "Street Suspension", "Sport Suspension", "Competition Suspension"}
    elseif modType == 16 then  -- Armor
        modNames = {"Armor Upgrade 20%", "Armor Upgrade 40%", "Armor Upgrade 60%", "Armor Upgrade 80%", "Armor Upgrade 100%"}
    end
    
    for i = 0, numMods - 1 do
        local modName = (modNames[i+1] ~= nil) and modNames[i+1] or (modTypeName .. " Level " .. (i + 1))
        local isActive = (currentMod == i)
        
        table.insert(options, {
            title = modName,
            description = 'Apply ' .. modName,
            metadata = {
                {label = 'Status', value = isActive and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleMod(vehicle, modType, i, false)
                lib.notify({
                    title = 'Upgrade Applied',
                    description = 'Applied ' .. modName,
                    type = 'success',
                    duration = 5000
                })
                OpenPerformanceModMenu(modType, modTypeName)
            end
        })
    end

    lib.registerContext({
        id = 'PerformanceModMenu',
        title = modTypeName .. ' Upgrades',
        options = options,
        menu = 'PerformanceMenu',
        onBack = function()
            OpenPerformanceMenu()
        end
    })
    lib.showContext('PerformanceModMenu')
end

-- Extras Menu
function OpenExtrasMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local options = {}
    
    for i = 1, 20 do
        if DoesExtraExist(vehicle, i) then
            local isEnabled = IsVehicleExtraTurnedOn(vehicle, i)
            
            table.insert(options, {
                title = 'Extra ' .. i,
                description = isEnabled and 'Disable Extra ' .. i or 'Enable Extra ' .. i,
                metadata = {
                    {label = 'Status', value = isEnabled and 'Enabled' or 'Disabled'}
                },
                onSelect = function()
                    SetVehicleExtra(vehicle, i, isEnabled and 1 or 0)
                    lib.notify({
                        title = 'Success',
                        description = (isEnabled and 'Disabled' or 'Enabled') .. ' Extra ' .. i .. '.',
                        type = 'success',
                        duration = 5000
                    })
                    OpenExtrasMenu()
                end
            })
        end
    end

    if #options == 0 then
        table.insert(options, {
            title = 'No Extras Available',
            description = 'This vehicle has no extras to toggle',
            onSelect = function() end
        })
    end
    
    lib.registerContext({
        id = 'ExtrasMenu',
        title = 'Toggle Extras',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('ExtrasMenu')
end

-- Door Control Menu
function OpenDoorsMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local doors = {
        { title = 'Driver Door', index = 0 },
        { title = 'Passenger Door', index = 1 },
        { title = 'Rear Driver Door', index = 2 },
        { title = 'Rear Passenger Door', index = 3 },
        { title = 'Hood', index = 4 },
        { title = 'Trunk', index = 5 }
    }

    local options = {}
    for _, door in pairs(doors) do
        local isDoorOpen = GetVehicleDoorAngleRatio(vehicle, door.index) > 0
        
        table.insert(options, {
            title = door.title,
            description = isDoorOpen and 'Close ' .. door.title or 'Open ' .. door.title,
            metadata = {
                {label = 'Status', value = isDoorOpen and 'Open' or 'Closed'}
            },
            onSelect = function()
                if isDoorOpen then
                    SetVehicleDoorShut(vehicle, door.index, false)
                else
                    SetVehicleDoorOpen(vehicle, door.index, false, false)
                end
                OpenDoorsMenu()
            end
        })
    end

    -- Add all doors options
    table.insert(options, {
        title = 'All Doors',
        description = 'Open or close all doors at once',
        onSelect = function()
            -- Check if any door is open
            local anyDoorOpen = false
            for _, door in pairs(doors) do
                if GetVehicleDoorAngleRatio(vehicle, door.index) > 0 then
                    anyDoorOpen = true
                    break
                end
            end
            
            for _, door in pairs(doors) do
                if anyDoorOpen then
                    SetVehicleDoorShut(vehicle, door.index, false)
                else
                    SetVehicleDoorOpen(vehicle, door.index, false, false)
                end
            end
            
            lib.notify({
                title = 'All Doors',
                description = anyDoorOpen and 'All doors closed' or 'All doors opened',
                type = 'success',
                duration = 5000
            })
            
            OpenDoorsMenu()
        end
    })

    lib.registerContext({
        id = 'DoorsMenu',
        title = 'Doors Control',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('DoorsMenu')
end

-----------------------------------------------------------
-- WINDOW CONTROLS MENU
-- Roll windows up/down for emergency vehicle operations
-----------------------------------------------------------
function OpenWindowControlsMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You must be in a vehicle',
            type = 'error',
            duration = 3000
        })
        return
    end

    local windows = {
        { title = 'Driver Window', index = 0 },
        { title = 'Passenger Window', index = 1 },
        { title = 'Rear Driver Window', index = 2 },
        { title = 'Rear Passenger Window', index = 3 }
    }

    local options = {}

    -- Individual window controls
    for _, window in ipairs(windows) do
        local windowIndex = window.index
        table.insert(options, {
            title = window.title,
            description = 'Roll down this window',
            icon = 'window-maximize',
            onSelect = function()
                RollDownWindow(vehicle, windowIndex)
                lib.notify({
                    title = 'Window Rolled Down',
                    description = window.title .. ' rolled down',
                    type = 'success',
                    duration = 2000
                })
            end
        })
    end

    -- All windows controls
    table.insert(options, {
        title = 'Roll All Windows Down',
        description = 'Lower all windows at once',
        icon = 'arrows-down-to-line',
        onSelect = function()
            for _, window in ipairs(windows) do
                RollDownWindow(vehicle, window.index)
            end
            lib.notify({
                title = 'All Windows Down',
                description = 'All windows rolled down',
                type = 'success',
                duration = 2000
            })
            OpenWindowControlsMenu()
        end
    })

    table.insert(options, {
        title = 'Roll All Windows Up',
        description = 'Raise all windows at once',
        icon = 'arrows-up-to-line',
        onSelect = function()
            for _, window in ipairs(windows) do
                RollUpWindow(vehicle, window.index)
            end
            lib.notify({
                title = 'All Windows Up',
                description = 'All windows rolled up',
                type = 'success',
                duration = 2000
            })
            OpenWindowControlsMenu()
        end
    })

    -- Smash window option (for emergency extraction)
    table.insert(options, {
        title = 'Smash Window',
        description = 'Break a window (for emergency extraction)',
        icon = 'hammer',
        onSelect = function()
            local smashOptions = {}
            for _, window in ipairs(windows) do
                local windowIndex = window.index
                table.insert(smashOptions, {
                    title = window.title,
                    onSelect = function()
                        SmashVehicleWindow(vehicle, windowIndex)
                        lib.notify({
                            title = 'Window Smashed',
                            description = window.title .. ' broken',
                            type = 'warning',
                            duration = 2000
                        })
                    end
                })
            end
            lib.registerContext({
                id = 'SmashWindowMenu',
                title = 'Select Window to Smash',
                options = smashOptions,
                menu = 'WindowControlsMenu'
            })
            lib.showContext('SmashWindowMenu')
        end
    })

    lib.registerContext({
        id = 'WindowControlsMenu',
        title = 'Window Controls',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('WindowControlsMenu')
end

-----------------------------------------------------------
-- SEAT CONTROLS MENU
-- Move between seats, eject passengers
-----------------------------------------------------------
function OpenSeatControlsMenu()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You must be in a vehicle',
            type = 'error',
            duration = 3000
        })
        return
    end

    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    local currentSeat = nil

    -- Find current seat
    for i = -1, maxSeats - 1 do
        if GetPedInVehicleSeat(vehicle, i) == playerPed then
            currentSeat = i
            break
        end
    end

    local seatNames = {
        [-1] = 'Driver',
        [0] = 'Front Passenger',
        [1] = 'Rear Left',
        [2] = 'Rear Right',
        [3] = 'Seat 5',
        [4] = 'Seat 6',
        [5] = 'Seat 7',
        [6] = 'Seat 8'
    }

    local options = {}

    -- Current seat info
    table.insert(options, {
        title = 'Current Seat: ' .. (seatNames[currentSeat] or 'Unknown'),
        description = 'You are in this seat',
        icon = 'user',
        disabled = true
    })

    -- Shuffle to different seats
    for i = -1, maxSeats - 1 do
        if i ~= currentSeat then
            local seatIndex = i
            local seatName = seatNames[i] or ('Seat ' .. (i + 2))
            local occupant = GetPedInVehicleSeat(vehicle, i)
            local isOccupied = occupant ~= 0 and occupant ~= playerPed

            table.insert(options, {
                title = 'Move to ' .. seatName,
                description = isOccupied and 'Seat is occupied' or 'Click to move here',
                icon = isOccupied and 'user-lock' or 'arrow-right',
                disabled = isOccupied,
                onSelect = function()
                    if not isOccupied then
                        SetPedIntoVehicle(playerPed, vehicle, seatIndex)
                        lib.notify({
                            title = 'Seat Changed',
                            description = 'Moved to ' .. seatName,
                            type = 'success',
                            duration = 2000
                        })
                        Wait(500)
                        OpenSeatControlsMenu()
                    end
                end
            })
        end
    end

    -- Passenger management section
    table.insert(options, {
        title = '── Passenger Management ──',
        disabled = true
    })

    -- Eject passengers
    local hasPassengers = false
    for i = -1, maxSeats - 1 do
        local occupant = GetPedInVehicleSeat(vehicle, i)
        if occupant ~= 0 and occupant ~= playerPed then
            hasPassengers = true
            local seatIndex = i
            local seatName = seatNames[i] or ('Seat ' .. (i + 2))
            local isNPC = not IsPedAPlayer(occupant)

            table.insert(options, {
                title = 'Eject from ' .. seatName,
                description = isNPC and 'Remove NPC from vehicle' or 'Remove player from vehicle',
                icon = 'right-from-bracket',
                onSelect = function()
                    TaskLeaveVehicle(occupant, vehicle, 16)
                    lib.notify({
                        title = 'Passenger Ejected',
                        description = 'Removed from ' .. seatName,
                        type = 'warning',
                        duration = 2000
                    })
                    Wait(1000)
                    OpenSeatControlsMenu()
                end
            })
        end
    end

    if not hasPassengers then
        table.insert(options, {
            title = 'No Passengers',
            description = 'Vehicle has no other occupants',
            icon = 'user-slash',
            disabled = true
        })
    end

    -- Eject all passengers
    if hasPassengers then
        table.insert(options, {
            title = 'Eject All Passengers',
            description = 'Remove everyone except driver',
            icon = 'users-slash',
            onSelect = function()
                for i = 0, maxSeats - 1 do
                    local occupant = GetPedInVehicleSeat(vehicle, i)
                    if occupant ~= 0 and occupant ~= playerPed then
                        TaskLeaveVehicle(occupant, vehicle, 16)
                    end
                end
                lib.notify({
                    title = 'All Passengers Ejected',
                    description = 'Vehicle cleared',
                    type = 'warning',
                    duration = 2000
                })
                Wait(1000)
                OpenSeatControlsMenu()
            end
        })
    end

    lib.registerContext({
        id = 'SeatControlsMenu',
        title = 'Seat Controls',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('SeatControlsMenu')
end

-- Appearance Menu
function OpenAppearanceMenu()
    local options = {
        {
            title = 'Colors',
            description = 'Change vehicle colors.',
            onSelect = function()
                OpenColorsMenu()
            end
        },
        {
            title = 'Wheels',
            description = 'Change vehicle wheels.',
            onSelect = function()
                OpenWheelsMenu()
            end
        },
        {
            title = 'Windows',
            description = 'Apply window tint.',
            onSelect = function()
                OpenWindowTintMenu()
            end
        },
        {
            title = 'Neon Lights',
            description = 'Customize neon lights.',
            onSelect = function()
                OpenNeonMenu()
            end
        }
    }

    lib.registerContext({
        id = 'AppearanceMenu',
        title = 'Vehicle Appearance',
        options = options,
        menu = 'VehicleModMenu',
        onBack = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })
    lib.showContext('AppearanceMenu')
end

-- Window Tint Menu
function OpenWindowTintMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    local tintOptions = {
        { name = "None", tint = 0 },
        { name = "Pure Black", tint = 1 },
        { name = "Dark Smoke", tint = 2 },
        { name = "Light Smoke", tint = 3 },
        { name = "Stock", tint = 4 },
        { name = "Limo", tint = 5 },
        { name = "Green", tint = 6 }
    }
    
    local options = {}
    local currentTint = GetVehicleWindowTint(vehicle)
    
    for _, tintOption in pairs(tintOptions) do
        local isActive = (currentTint == tintOption.tint)
        table.insert(options, {
            title = tintOption.name,
            description = 'Apply ' .. tintOption.name .. ' window tint',
            metadata = {
                {label = 'Status', value = isActive and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleWindowTint(vehicle, tintOption.tint)
                lib.notify({
                    title = 'Window Tint Applied',
                    description = 'Applied ' .. tintOption.name .. ' window tint',
                    type = 'success',
                    duration = 5000
                })
                OpenWindowTintMenu()
            end
        })
    end

    lib.registerContext({
        id = 'WindowTintMenu',
        title = 'Window Tint',
        options = options,
        menu = 'AppearanceMenu',
        onBack = function()
            OpenAppearanceMenu()
        end
    })
    lib.showContext('WindowTintMenu')
end

-- Neon Menu
function OpenNeonMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    local options = {
        {
            title = 'Toggle Neon',
            description = 'Turn neon lights on/off',
            onSelect = function()
                local hasNeon = false
                for i = 0, 3 do
                    if IsVehicleNeonLightEnabled(vehicle, i) then
                        hasNeon = true
                        break
                    end
                end
                
                for i = 0, 3 do
                    SetVehicleNeonLightEnabled(vehicle, i, not hasNeon)
                end
                
                lib.notify({
                    title = 'Neon Lights',
                    description = hasNeon and 'Neon lights turned off' or 'Neon lights turned on',
                    type = 'success',
                    duration = 5000
                })
                OpenNeonMenu()
            end
        },
        {
            title = 'Neon Layout',
            description = 'Choose which neon lights to enable',
            onSelect = function()
                OpenNeonLayoutMenu()
            end
        },
        {
            title = 'Neon Color',
            description = 'Change the color of neon lights',
            onSelect = function()
                OpenNeonColorMenu()
            end
        }
    }

    lib.registerContext({
        id = 'NeonMenu',
        title = 'Neon Lights',
        options = options,
        menu = 'AppearanceMenu',
        onBack = function()
            OpenAppearanceMenu()
        end
    })
    lib.showContext('NeonMenu')
end

-- Neon Layout Menu
function OpenNeonLayoutMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    local neonOptions = {
        { name = "Front", index = 2 },
        { name = "Back", index = 3 },
        { name = "Left", index = 0 },
        { name = "Right", index = 1 },
        { name = "All", index = -1 }
    }
    
    local options = {}
    
    for _, neonOption in pairs(neonOptions) do
        local isEnabled = neonOption.index == -1 and false or IsVehicleNeonLightEnabled(vehicle, neonOption.index)
        
        table.insert(options, {
            title = neonOption.name,
            description = isEnabled and 'Turn off ' .. neonOption.name .. ' neon' or 'Turn on ' .. neonOption.name .. ' neon',
            metadata = {
                {label = 'Status', value = isEnabled and 'Enabled' or 'Disabled'}
            },
            onSelect = function()
                if neonOption.index == -1 then
                    local allEnabled = IsVehicleNeonLightEnabled(vehicle, 0)
                    for i = 0, 3 do
                        SetVehicleNeonLightEnabled(vehicle, i, not allEnabled)
                    end
                else
                    SetVehicleNeonLightEnabled(vehicle, neonOption.index, not isEnabled)
                end
                
                lib.notify({
                    title = 'Neon Layout Updated',
                    description = 'Updated ' .. neonOption.name .. ' neon setting',
                    type = 'success',
                    duration = 5000
                })
                OpenNeonLayoutMenu()
            end
        })
    end

    lib.registerContext({
        id = 'NeonLayoutMenu',
        title = 'Neon Layout',
        options = options,
        menu = 'NeonMenu',
        onBack = function()
            OpenNeonMenu()
        end
    })
    lib.showContext('NeonLayoutMenu')
end

-- Neon Color Menu
function OpenNeonColorMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    local colorOptions = {
        { name = "White", r = 255, g = 255, b = 255 },
        { name = "Blue", r = 0, g = 0, b = 255 },
        { name = "Electric Blue", r = 0, g = 150, b = 255 },
        { name = "Mint Green", r = 50, g = 255, b = 155 },
        { name = "Lime Green", r = 0, g = 255, b = 0 },
        { name = "Yellow", r = 255, g = 255, b = 0 },
        { name = "Golden Shower", r = 204, g = 204, b = 0 },
        { name = "Orange", r = 255, g = 128, b = 0 },
        { name = "Red", r = 255, g = 0, b = 0 },
        { name = "Pony Pink", r = 255, g = 0, b = 255 },
        { name = "Hot Pink", r = 255, g = 0, b = 150 },
        { name = "Purple", r = 153, g = 0, b = 153 }
    }
    
    local options = {}
    local currentR, currentG, currentB = GetVehicleNeonLightsColour(vehicle)
    
    for _, colorOption in pairs(colorOptions) do
        local isActive = (currentR == colorOption.r and currentG == colorOption.g and currentB == colorOption.b)
        
        table.insert(options, {
            title = colorOption.name,
            description = 'Apply ' .. colorOption.name .. ' neon color',
            metadata = {
                {label = 'Status', value = isActive and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleNeonLightsColour(vehicle, colorOption.r, colorOption.g, colorOption.b)
                lib.notify({
                    title = 'Neon Color Applied',
                    description = 'Applied ' .. colorOption.name .. ' neon color',
                    type = 'success',
                    duration = 5000
                })
                OpenNeonColorMenu()
            end
        })
    end

    lib.registerContext({
        id = 'NeonColorMenu',
        title = 'Neon Colors',
        options = options,
        menu = 'NeonMenu',
        onBack = function()
            OpenNeonMenu()
        end
    })
    lib.showContext('NeonColorMenu')
end

-- Colors Menu
function OpenColorsMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local primaryColor, secondaryColor = GetVehicleColours(vehicle)
    
    local colorOptions = {
        { name = "Black", color = 0 },
        { name = "Carbon Black", color = 147 },
        { name = "Graphite", color = 1 },
        { name = "Black Steel", color = 2 },
        { name = "Dark Steel", color = 3 },
        { name = "Silver", color = 4 },
        { name = "Red", color = 27 },
        { name = "Torino Red", color = 28 },
        { name = "Formula Red", color = 29 },
        { name = "Blue", color = 64 },
        { name = "Dark Blue", color = 62 },
        { name = "White", color = 111 },
        { name = "Frost White", color = 112 }
    }

    local options = {
        {
            title = 'Primary Color',
            description = 'Change the primary color of the vehicle.',
            menu = 'primary_color',
        },
        {
            title = 'Secondary Color',
            description = 'Change the secondary color of the vehicle.',
            menu = 'secondary_color',
        },
        {
            title = 'Pearlescent Color',
            description = 'Apply pearlescent finish.',
            onSelect = function()
                OpenPearlescentMenu()
            end
        }
    }

    lib.registerContext({
        id = 'ColorsMenu',
        title = 'Vehicle Colors',
        options = options,
        menu = 'AppearanceMenu',
        onBack = function()
            OpenAppearanceMenu()
        end
    })

    -- Generate primary color menu options
    local primaryOptions = {}
    for _, colorOption in pairs(colorOptions) do
        table.insert(primaryOptions, {
            title = colorOption.name,
            description = 'Set primary color to ' .. colorOption.name,
            metadata = {
                {label = 'Status', value = (primaryColor == colorOption.color) and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleColours(vehicle, colorOption.color, secondaryColor)
                lib.notify({
                    title = 'Color Applied',
                    description = 'Primary color set to ' .. colorOption.name,
                    type = 'success',
                    duration = 5000
                })
                OpenColorsMenu()
            end
        })
    end

    -- Generate secondary color menu options
    local secondaryOptions = {}
    for _, colorOption in pairs(colorOptions) do
        table.insert(secondaryOptions, {
            title = colorOption.name,
            description = 'Set secondary color to ' .. colorOption.name,
            metadata = {
                {label = 'Status', value = (secondaryColor == colorOption.color) and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleColours(vehicle, primaryColor, colorOption.color)
                lib.notify({
                    title = 'Color Applied',
                    description = 'Secondary color set to ' .. colorOption.name,
                    type = 'success',
                    duration = 5000
                })
                OpenColorsMenu()
            end
        })
    end

    lib.registerContext({
        id = 'primary_color',
        title = 'Primary Colors',
        menu = 'ColorsMenu',
        options = primaryOptions,
        onBack = function()
            OpenColorsMenu()
        end
    })

    lib.registerContext({
        id = 'secondary_color',
        title = 'Secondary Colors',
        menu = 'ColorsMenu',
        options = secondaryOptions,
        onBack = function()
            OpenColorsMenu()
        end
    })

    lib.showContext('ColorsMenu')
end

-- Pearlescent Color Menu
function OpenPearlescentMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    
    local pearlescentOptions = {
        { name = "Black", color = 0 },
        { name = "Carbon Black", color = 147 },
        { name = "Graphite", color = 1 },
        { name = "Black Steel", color = 2 },
        { name = "Dark Steel", color = 3 },
        { name = "Silver", color = 4 },
        { name = "Red", color = 27 },
        { name = "Torino Red", color = 28 },
        { name = "Formula Red", color = 29 },
        { name = "Blue", color = 64 },
        { name = "Dark Blue", color = 62 },
        { name = "White", color = 111 },
        { name = "Frost White", color = 112 }
    }

    local options = {}
    
    for _, colorOption in pairs(pearlescentOptions) do
        local isActive = (pearlescentColor == colorOption.color)
        
        table.insert(options, {
            title = colorOption.name,
            description = 'Set pearlescent color to ' .. colorOption.name,
            metadata = {
                {label = 'Status', value = isActive and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleExtraColours(vehicle, colorOption.color, wheelColor)
                lib.notify({
                    title = 'Pearlescent Applied',
                    description = 'Pearlescent color set to ' .. colorOption.name,
                    type = 'success',
                    duration = 5000
                })
                OpenPearlescentMenu()
            end
        })
    end

    lib.registerContext({
        id = 'PearlescentMenu',
        title = 'Pearlescent Colors',
        options = options,
        menu = 'ColorsMenu',
        onBack = function()
            OpenColorsMenu()
        end
    })
    lib.showContext('PearlescentMenu')
end

-- Wheels Menu
function OpenWheelsMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    -- IMPORTANT: Must set mod kit before accessing vehicle mods
    SetVehicleModKit(vehicle, 0)

    local wheelType = GetVehicleWheelType(vehicle)

    local wheelTypeOptions = {
        { name = "Sport", type = 0 },
        { name = "Muscle", type = 1 },
        { name = "Lowrider", type = 2 },
        { name = "SUV", type = 3 },
        { name = "Offroad", type = 4 },
        { name = "Tuner", type = 5 },
        { name = "Bike Wheels", type = 6 },
        { name = "High End", type = 7 }
    }
    
    local options = {}
    
    for _, wheelOption in pairs(wheelTypeOptions) do
        local isActive = (wheelType == wheelOption.type)
        
        table.insert(options, {
            title = wheelOption.name,
            description = 'Switch to ' .. wheelOption.name .. ' wheels',
            metadata = {
                {label = 'Status', value = isActive and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleWheelType(vehicle, wheelOption.type)
                lib.notify({
                    title = 'Wheel Type Changed',
                    description = 'Changed to ' .. wheelOption.name .. ' wheels',
                    type = 'success',
                    duration = 5000
                })
                OpenWheelSelectionMenu(wheelOption.type)
            end
        })
    end

    -- Add wheel color option
    table.insert(options, {
        title = 'Wheel Color',
        description = 'Change the color of wheels',
        onSelect = function()
            OpenWheelColorMenu()
        end
    })

    lib.registerContext({
        id = 'WheelsMenu',
        title = 'Vehicle Wheels',
        options = options,
        menu = 'AppearanceMenu',
        onBack = function()
            OpenAppearanceMenu()
        end
    })
    lib.showContext('WheelsMenu')
end

-- Wheel Style Selection Menu
function OpenWheelSelectionMenu(wheelType)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    -- IMPORTANT: Must set mod kit before accessing vehicle mods
    SetVehicleModKit(vehicle, 0)

    local options = {}

    -- Get the number of wheel mods available
    local numWheels = GetNumVehicleMods(vehicle, 23) -- 23 = wheels
    local currentWheel = GetVehicleMod(vehicle, 23)
    
    for i = -1, numWheels - 1 do
        local title = i == -1 and "Stock Wheels" or "Wheel " .. (i + 1)
        local isActive = (currentWheel == i)
        
        table.insert(options, {
            title = title,
            metadata = {
                {label = 'Status', value = isActive and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleMod(vehicle, 23, i, GetVehicleModVariation(vehicle, 23))
                if GetVehicleClass(vehicle) == 8 then -- Motorcycle
                    SetVehicleMod(vehicle, 24, i, GetVehicleModVariation(vehicle, 24))
                end
                
                lib.notify({
                    title = 'Wheels Changed',
                    description = 'Applied ' .. title,
                    type = 'success',
                    duration = 5000
                })
                
                OpenWheelSelectionMenu(wheelType)
            end
        })
    end

    lib.registerContext({
        id = 'WheelSelectionMenu',
        title = 'Select Wheels',
        options = options,
        menu = 'WheelsMenu',
        onBack = function()
            OpenWheelsMenu()
        end
    })
    lib.showContext('WheelSelectionMenu')
end

-- Wheel Color Menu
function OpenWheelColorMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local pearlescent, wheelColor = GetVehicleExtraColours(vehicle)
    
    local colorOptions = {
        { name = "Black", color = 0 },
        { name = "Carbon Black", color = 147 },
        { name = "Graphite", color = 1 },
        { name = "Dark Steel", color = 3 },
        { name = "Silver", color = 4 },
        { name = "Red", color = 27 },
        { name = "Blue", color = 64 },
        { name = "White", color = 111 }
    }

    local options = {}
    
    for _, colorOption in pairs(colorOptions) do
        local isActive = (wheelColor == colorOption.color)
        
        table.insert(options, {
            title = colorOption.name,
            description = 'Set wheel color to ' .. colorOption.name,
            metadata = {
                {label = 'Status', value = isActive and 'Active' or 'Inactive'}
            },
            onSelect = function()
                SetVehicleExtraColours(vehicle, pearlescent, colorOption.color)
                lib.notify({
                    title = 'Wheel Color Applied',
                    description = 'Wheel color set to ' .. colorOption.name,
                    type = 'success',
                    duration = 5000
                })
                OpenWheelColorMenu()
            end
        })
    end

    lib.registerContext({
        id = 'WheelColorMenu',
        title = 'Wheel Colors',
        options = options,
        menu = 'WheelsMenu',
        onBack = function()
            OpenWheelsMenu()
        end
    })
    lib.showContext('WheelColorMenu')
end

-- Save Vehicle Configuration with enhanced error handling
function SaveVehicleConfig()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You need to be in a vehicle to save configuration',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local vehicleProps = GetVehicleProperties(vehicle)
    if not vehicleProps then
        lib.notify({
            title = 'Error',
            description = 'Failed to read vehicle properties',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModel)
    
    if not vehicleModelName or vehicleModelName == "" then
        lib.notify({
            title = 'Error',
            description = 'Unable to identify vehicle model',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Save to database via server
    local success, jsonString = pcall(json.encode, vehicleProps)
    if success then
        TriggerServerEvent('vehiclemods:server:saveModifications', vehicleModelName, jsonString)
        
        lib.notify({
            title = 'Configuration Saved',
            description = 'Your vehicle configuration has been saved.',
            type = 'success',
            duration = 5000
        })
        TriggerEvent('vehiclemods:client:openVehicleModMenu')
    else
        lib.notify({
            title = 'Error',
            description = 'Failed to encode vehicle configuration',
            type = 'error',
            duration = 5000
        })
        print("^1ERROR:^0 JSON encoding failed: " .. tostring(jsonString))
        TriggerEvent('vehiclemods:client:openVehicleModMenu')
    end
end

-- Function to get all vehicle properties
function GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then
        return nil
    end
    
    -- Get the colors
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    
    -- Get neon status and color
    local neonEnabled = {}
    for i = 0, 3 do
        neonEnabled[i] = IsVehicleNeonLightEnabled(vehicle, i)
    end
    local neonColor = {GetVehicleNeonLightsColour(vehicle)}
    
    -- Get extras
    local extras = {}
    for extraId = 0, 20 do
        if DoesExtraExist(vehicle, extraId) then
            extras[extraId] = IsVehicleExtraTurnedOn(vehicle, extraId)
        end
    end
    
    local tyreSmokeColor = {GetVehicleTyreSmokeColor(vehicle)}
    local livery = GetVehicleLivery(vehicle)
    local modLivery = GetVehicleMod(vehicle, 48)
    
    return {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        color1 = colorPrimary,
        color2 = colorSecondary,
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        neonEnabled = neonEnabled,
        neonColor = neonColor,
        extras = extras,
        tyreSmokeColor = tyreSmokeColor,
        modSpoilers = GetVehicleMod(vehicle, 0),
        modFrontBumper = GetVehicleMod(vehicle, 1),
        modRearBumper = GetVehicleMod(vehicle, 2),
        modSideSkirt = GetVehicleMod(vehicle, 3),
        modExhaust = GetVehicleMod(vehicle, 4),
        modFrame = GetVehicleMod(vehicle, 5),
        modGrille = GetVehicleMod(vehicle, 6),
        modHood = GetVehicleMod(vehicle, 7),
        modFender = GetVehicleMod(vehicle, 8),
        modRightFender = GetVehicleMod(vehicle, 9),
        modRoof = GetVehicleMod(vehicle, 10),
        modEngine = GetVehicleMod(vehicle, 11),
        modBrakes = GetVehicleMod(vehicle, 12),
        modTransmission = GetVehicleMod(vehicle, 13),
        modHorns = GetVehicleMod(vehicle, 14),
        modSuspension = GetVehicleMod(vehicle, 15),
        modArmor = GetVehicleMod(vehicle, 16),
        modTurbo = IsToggleModOn(vehicle, 18),
        modSmokeEnabled = IsToggleModOn(vehicle, 20),
        modXenon = IsToggleModOn(vehicle, 22),
        modFrontWheels = GetVehicleMod(vehicle, 23),
        modBackWheels = GetVehicleMod(vehicle, 24),
        modPlateHolder = GetVehicleMod(vehicle, 25),
        modVanityPlate = GetVehicleMod(vehicle, 26),
        modTrimA = GetVehicleMod(vehicle, 27),
        modOrnaments = GetVehicleMod(vehicle, 28),
        modDashboard = GetVehicleMod(vehicle, 29),
        modDial = GetVehicleMod(vehicle, 30),
        modDoorSpeaker = GetVehicleMod(vehicle, 31),
        modSeats = GetVehicleMod(vehicle, 32),
        modSteeringWheel = GetVehicleMod(vehicle, 33),
        modShifterLeavers = GetVehicleMod(vehicle, 34),
        modAPlate = GetVehicleMod(vehicle, 35),
        modSpeakers = GetVehicleMod(vehicle, 36),
        modTrunk = GetVehicleMod(vehicle, 37),
        modHydrolic = GetVehicleMod(vehicle, 38),
        modEngineBlock = GetVehicleMod(vehicle, 39),
        modAirFilter = GetVehicleMod(vehicle, 40),
        modStruts = GetVehicleMod(vehicle, 41),
        modArchCover = GetVehicleMod(vehicle, 42),
        modAerials = GetVehicleMod(vehicle, 43),
        modTrimB = GetVehicleMod(vehicle, 44),
        modTank = GetVehicleMod(vehicle, 45),
        modWindows = GetVehicleMod(vehicle, 46),
        modLivery = modLivery,
        livery = livery
    }
end

function LoadVehicleConfig(vehicle)
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModel)
    
    if not vehicleModelName or vehicleModelName == "" then
        return
    end
    
    -- Request configuration from server
    TriggerServerEvent('vehiclemods:server:requestVehicleConfig', vehicleModelName)
end

-- Event handler to apply vehicle configuration from server
RegisterNetEvent('vehiclemods:client:applyVehicleConfig')
AddEventHandler('vehiclemods:client:applyVehicleConfig', function(vehicleModel, configJson)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    if vehicle == 0 then
        return
    end
    
    local success, vehicleProps = pcall(json.decode, configJson)
    if not success or not vehicleProps then
        if Config.Debug then
            print("^1ERROR:^0 Failed to decode vehicle configuration")
        end
        return
    end
    
    ApplyVehicleProperties(vehicle, vehicleProps)
    
    lib.notify({
        title = 'Configuration Loaded',
        description = 'Vehicle configuration has been applied.',
        type = 'success',
        duration = 5000
    })
end)

-- Function to apply vehicle properties
function ApplyVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or not props then
        return
    end
    
    -- Apply colors
    if props.color1 and props.color2 then
        SetVehicleColours(vehicle, props.color1, props.color2)
    end
    
    if props.pearlescentColor and props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor)
    end
    
    -- Apply window tint
    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end
    
    -- Apply wheels
    if props.wheels then
        SetVehicleWheelType(vehicle, props.wheels)
    end
    
    -- Apply mods
    local modTypes = {
        {prop = 'modEngine', id = 11},
        {prop = 'modBrakes', id = 12},
        {prop = 'modTransmission', id = 13},
        {prop = 'modSuspension', id = 15},
        {prop = 'modArmor', id = 16},
        {prop = 'modFrontWheels', id = 23},
        {prop = 'modLivery', id = 48}
    }
    
    for _, mod in pairs(modTypes) do
        if props[mod.prop] and props[mod.prop] ~= -1 then
            SetVehicleMod(vehicle, mod.id, props[mod.prop], false)
        end
    end
    
    -- Apply toggle mods
    if props.modTurbo ~= nil then
        ToggleVehicleMod(vehicle, 18, props.modTurbo)
    end
    
    if props.modXenon ~= nil then
        ToggleVehicleMod(vehicle, 22, props.modXenon)
    end
    
    -- Apply neon
    if props.neonEnabled then
        for i = 0, 3 do
            if props.neonEnabled[i] ~= nil then
                SetVehicleNeonLightEnabled(vehicle, i, props.neonEnabled[i])
            end
        end
    end
    
    if props.neonColor and props.neonColor[1] and props.neonColor[2] and props.neonColor[3] then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end
    
    -- Apply extras
    if props.extras then
        for extraId, enabled in pairs(props.extras) do
            if DoesExtraExist(vehicle, tonumber(extraId)) then
                SetVehicleExtra(vehicle, tonumber(extraId), enabled and 0 or 1)
            end
        end
    end
    
    -- Apply livery
    if props.livery and props.livery > -1 then
        SetVehicleLivery(vehicle, props.livery)
    end
end

-- Auto-load configuration when entering a vehicle
CreateThread(function()
    local lastVehicle = 0
    
    while true do
        Wait(1000)
        
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 and vehicle ~= lastVehicle then
            -- Check if we're in a modification zone and it's an emergency vehicle
            local playerCoords = GetEntityCoords(playerPed)
            local inZone = Config.IsInModificationZone(playerCoords)
            
            if inZone and (not Config.EmergencyVehiclesOnly or Config.IsEmergencyVehicle(vehicle)) then
                LoadVehicleConfig(vehicle)
            end
            
            lastVehicle = vehicle
        elseif vehicle == 0 then
            lastVehicle = 0
        end
    end
end)

RegisterNetEvent('vehiclemods:client:updateCustomLiveries')
AddEventHandler('vehiclemods:client:updateCustomLiveries', function(customLiveries)
    Config.CustomLiveries = customLiveries
    
    if Config.Debug then
        print("^2INFO:^0 Updated custom liveries configuration")
    end
end)

-- Request custom liveries when resource starts
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    TriggerServerEvent('vehiclemods:server:requestCustomLiveries')
end)

CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        if loadedTextures then
            local currentTime = GetGameTimer()
            local toRemove = {}
            
            for textureDict, loadTime in pairs(loadedTextures) do
                -- Remove textures loaded more than 5 minutes ago and not currently in use
                if currentTime - loadTime > 300000 then
                    local inUse = false
                    
                    -- Check if any active custom livery is using this texture
                    if ActiveCustomLiveries then
                        for _, liveryInfo in pairs(ActiveCustomLiveries) do
                            if liveryInfo.dict == textureDict then
                                inUse = true
                                break
                            end
                        end
                    end
                    
                    if not inUse and HasStreamedTextureDictLoaded(textureDict) then
                        SetStreamedTextureDictAsNoLongerNeeded(textureDict)
                        table.insert(toRemove, textureDict)
                        
                        if Config.Debug then
                            print("^3INFO:^0 Cleaned up unused texture: " .. textureDict)
                        end
                    end
                end
            end
            
            -- Remove from tracking
            for _, textureDict in pairs(toRemove) do
                loadedTextures[textureDict] = nil
            end
        end
    end
end)

-----------------------------------------------------------
-- ENHANCED REPAIR SYSTEM
-- Detailed damage assessment, component-specific repair,
-- immersive animations, and engine health tracking
-----------------------------------------------------------

-- Get detailed vehicle damage report
function GetVehicleDamageReport(vehicle)
    local report = {
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        tiresBurst = {},
        windowsBroken = {},
        doorsLost = {}
    }

    -- Check tires (0-3 for standard, 4-5 for bikes/6-wheelers)
    for i = 0, 5 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            table.insert(report.tiresBurst, i)
        end
    end

    -- Check windows (0-7)
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then
            table.insert(report.windowsBroken, i)
        end
    end

    -- Check doors (0-5)
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then
            table.insert(report.doorsLost, i)
        end
    end

    -- Calculate overall condition percentage
    local enginePct = math.max(0, report.engineHealth) / 10
    local bodyPct = math.max(0, report.bodyHealth) / 10
    local tankPct = math.max(0, report.tankHealth) / 10
    report.overallCondition = math.floor((enginePct + bodyPct + tankPct) / 3)

    -- Determine severity
    if report.overallCondition > 70 then
        report.severity = 'minor'
        report.severityLabel = 'Minor Damage'
    elseif report.overallCondition > 40 then
        report.severity = 'moderate'
        report.severityLabel = 'Moderate Damage'
    elseif report.overallCondition > 15 then
        report.severity = 'severe'
        report.severityLabel = 'Severe Damage'
    else
        report.severity = 'critical'
        report.severityLabel = 'Critical Damage'
    end

    return report
end

-- Format damage report for display
function FormatDamageReport(report)
    local lines = {}

    table.insert(lines, ('**Overall Condition:** %d%%'):format(report.overallCondition))
    table.insert(lines, ('**Status:** %s'):format(report.severityLabel))
    table.insert(lines, '')
    table.insert(lines, ('Engine: %d%%'):format(math.floor(math.max(0, report.engineHealth) / 10)))
    table.insert(lines, ('Body: %d%%'):format(math.floor(math.max(0, report.bodyHealth) / 10)))
    table.insert(lines, ('Fuel Tank: %d%%'):format(math.floor(math.max(0, report.tankHealth) / 10)))

    if #report.tiresBurst > 0 then
        table.insert(lines, ('Flat Tires: %d'):format(#report.tiresBurst))
    end
    if #report.windowsBroken > 0 then
        table.insert(lines, ('Broken Windows: %d'):format(#report.windowsBroken))
    end

    return table.concat(lines, '\n')
end

-- Emergency Repair System (Enhanced)
function EmergencyRepairVehicle()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You must be in a vehicle to use emergency repair',
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Get detailed damage report
    local damage = GetVehicleDamageReport(vehicle)

    -- Check if vehicle needs repair
    if damage.overallCondition > 70 then
        lib.notify({
            title = 'Emergency Repair',
            description = 'Vehicle condition is good (' .. damage.overallCondition .. '%). No emergency repair needed.',
            type = 'info',
            duration = 5000
        })
        return
    end

    -- Show damage assessment dialog
    local alert = lib.alertDialog({
        header = 'Emergency Repair - Damage Assessment',
        content = FormatDamageReport(damage) .. '\n\n**Warning:** Emergency repair provides limited functionality. Vehicle will have reduced power (30%) until full repair.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Begin Emergency Repair',
            cancel = 'Cancel'
        }
    })

    if alert == 'confirm' then
        -- Exit vehicle for repair animation
        local wasDriver = GetPedInVehicleSeat(vehicle, -1) == playerPed

        TaskLeaveVehicle(playerPed, vehicle, 0)
        Wait(2000)

        -- Play repair animation with proper scenario
        lib.notify({
            title = 'Emergency Repair',
            description = 'Assessing damage and applying field repairs...',
            type = 'info',
            duration = 3000
        })

        -- Multi-stage repair with progress
        local repairStages = {
            { label = 'Checking engine...', duration = 3000 },
            { label = 'Patching fuel system...', duration = 2500 },
            { label = 'Stabilizing components...', duration = 2500 },
            { label = 'Testing systems...', duration = 2000 }
        }

        local repairSuccess = true
        for _, stage in ipairs(repairStages) do
            if not lib.progressBar({
                duration = stage.duration,
                label = stage.label,
                useWhileDead = false,
                canCancel = true,
                disable = { move = true, combat = true },
                anim = {
                    dict = 'mini@repair',
                    clip = 'fixing_a_ped'
                }
            }) then
                repairSuccess = false
                break
            end
        end

        if repairSuccess then
            -- Apply emergency repairs
            SetVehicleEngineHealth(vehicle, 450.0)
            SetVehicleBodyHealth(vehicle, 650.0)
            SetVehiclePetrolTankHealth(vehicle, 800.0)

            -- Fix flat tires (critical for mobility)
            for i = 0, 5 do
                if IsVehicleTyreBurst(vehicle, i, false) then
                    SetVehicleTyreFixed(vehicle, i)
                end
            end

            -- Reduce performance (emergency mode)
            SetVehicleEnginePowerMultiplier(vehicle, 0.3)
            SetVehicleEngineTorqueMultiplier(vehicle, 0.4)
            SetVehicleCheatPowerIncrease(vehicle, 0.0)

            -- Ensure engine runs
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehicleUndriveable(vehicle, false)

            -- Get back in vehicle
            Wait(500)
            TaskWarpPedIntoVehicle(playerPed, vehicle, wasDriver and -1 or 0)

            -- Play success sound
            PlaySoundFrontend(-1, "PICK_UP_WEAPON", "HUD_FRONTEND_CUSTOM_SOUNDSET", true)

            lib.notify({
                title = 'Emergency Repair Complete',
                description = ('Vehicle at %d%% - Reduced power mode active. Seek full repair.'):format(
                    math.floor((GetVehicleEngineHealth(vehicle) + GetVehicleBodyHealth(vehicle)) / 20)
                ),
                type = 'success',
                duration = 8000
            })

            -- Periodic reminders
            SetTimeout(60000, function()
                if DoesEntityExist(vehicle) and GetVehiclePedIsIn(playerPed, false) == vehicle then
                    lib.notify({
                        title = 'Vehicle Warning',
                        description = 'Emergency repairs are temporary. Full repair recommended.',
                        type = 'warning',
                        duration = 5000
                    })
                end
            end)
        else
            lib.notify({
                title = 'Repair Cancelled',
                description = 'Emergency repair was interrupted',
                type = 'error',
                duration = 3000
            })
            TaskWarpPedIntoVehicle(playerPed, vehicle, wasDriver and -1 or 0)
        end

        TriggerEvent('vehiclemods:client:openVehicleModMenu')
    else
        TriggerEvent('vehiclemods:client:openVehicleModMenu')
    end
end

-- Full Repair Function (Enhanced)
function FullRepairVehicle()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You must be in a vehicle to repair it',
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Get detailed damage report
    local damage = GetVehicleDamageReport(vehicle)

    -- Calculate repair time based on damage
    local baseTime = 8000
    local extraTime = math.floor((100 - damage.overallCondition) * 100) -- More damage = longer repair
    local totalTime = baseTime + extraTime

    -- Show damage assessment
    local alert = lib.alertDialog({
        header = 'Full Vehicle Repair',
        content = FormatDamageReport(damage) .. ('\n\n**Estimated Repair Time:** %d seconds'):format(math.ceil(totalTime / 1000)),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Begin Full Repair',
            cancel = 'Cancel'
        }
    })

    if alert == 'confirm' then
        -- Exit vehicle for full repair
        local wasDriver = GetPedInVehicleSeat(vehicle, -1) == playerPed
        TaskLeaveVehicle(playerPed, vehicle, 0)
        Wait(2000)

        -- Multi-stage full repair
        local stages = {
            { label = 'Diagnosing vehicle systems...', duration = math.floor(totalTime * 0.15) },
            { label = 'Repairing engine components...', duration = math.floor(totalTime * 0.25) },
            { label = 'Fixing body damage...', duration = math.floor(totalTime * 0.20) },
            { label = 'Replacing damaged parts...', duration = math.floor(totalTime * 0.20) },
            { label = 'Calibrating systems...', duration = math.floor(totalTime * 0.10) },
            { label = 'Final inspection...', duration = math.floor(totalTime * 0.10) }
        }

        local repairSuccess = true
        for i, stage in ipairs(stages) do
            if not lib.progressBar({
                duration = stage.duration,
                label = stage.label,
                useWhileDead = false,
                canCancel = true,
                disable = { move = true, combat = true },
                anim = {
                    dict = 'mini@repair',
                    clip = 'fixing_a_ped'
                }
            }) then
                repairSuccess = false
                break
            end

            -- Incremental repair during process
            if i == 2 then
                SetVehicleEngineHealth(vehicle, 1000.0)
            elseif i == 3 then
                SetVehicleBodyHealth(vehicle, 1000.0)
            elseif i == 4 then
                -- Fix all tires
                for t = 0, 5 do SetVehicleTyreFixed(vehicle, t) end
                -- Fix all windows
                for w = 0, 7 do FixVehicleWindow(vehicle, w) end
            end
        end

        if repairSuccess then
            -- Complete full repair
            SetVehicleFixed(vehicle)
            SetVehicleDeformationFixed(vehicle)
            SetVehicleDirtLevel(vehicle, 0.0)
            SetVehicleEngineHealth(vehicle, 1000.0)
            SetVehicleBodyHealth(vehicle, 1000.0)
            SetVehiclePetrolTankHealth(vehicle, 1000.0)

            -- Restore full performance
            SetVehicleEnginePowerMultiplier(vehicle, 1.0)
            SetVehicleEngineTorqueMultiplier(vehicle, 1.0)
            SetVehicleUndriveable(vehicle, false)
            SetVehicleEngineOn(vehicle, true, true, false)

            -- Get back in vehicle
            Wait(500)
            TaskWarpPedIntoVehicle(playerPed, vehicle, wasDriver and -1 or 0)

            -- Success sound
            PlaySoundFrontend(-1, "SHOOTING_RANGE_ROUND_OVER", "HUD_AWARDS", true)

            lib.notify({
                title = 'Full Repair Complete',
                description = 'Vehicle restored to 100% condition. All systems operational.',
                type = 'success',
                duration = 5000
            })
        else
            -- Partial repair if cancelled mid-way
            lib.notify({
                title = 'Repair Interrupted',
                description = 'Partial repairs applied. Some damage may remain.',
                type = 'warning',
                duration = 4000
            })
            TaskWarpPedIntoVehicle(playerPed, vehicle, wasDriver and -1 or 0)
        end

        TriggerEvent('vehiclemods:client:openVehicleModMenu')
    else
        TriggerEvent('vehiclemods:client:openVehicleModMenu')
    end
end

-----------------------------------------------------------
-- FIELD REPAIR SYSTEM (v2.1.0+)
-- Allows emergency repairs anywhere with toolkit
-----------------------------------------------------------
local pendingFieldRepair = nil

-- Request field repair from server
function RequestFieldRepair()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You must be in a vehicle',
            type = 'error',
            duration = 3000
        })
        return
    end

    -- Check engine health
    local engineHealth = GetVehicleEngineHealth(vehicle)
    if engineHealth > 350.0 then
        lib.notify({
            title = 'Field Repair',
            description = 'Engine is functional. Field repair not needed.',
            type = 'info',
            duration = 4000
        })
        return
    end

    -- Request validation from server
    pendingFieldRepair = vehicle
    TriggerServerEvent('vehiclemods:server:requestFieldRepair')
end

-- Handle field repair result from server
RegisterNetEvent('vehiclemods:client:fieldRepairResult')
AddEventHandler('vehiclemods:client:fieldRepairResult', function(approved, errorMsg, maxRepair, repairTime)
    if not approved then
        lib.notify({
            title = 'Field Repair Denied',
            description = errorMsg or 'Unable to perform field repair',
            type = 'error',
            duration = 5000
        })
        pendingFieldRepair = nil
        return
    end

    local vehicle = pendingFieldRepair
    pendingFieldRepair = nil

    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({
            title = 'Error',
            description = 'Vehicle no longer exists',
            type = 'error',
            duration = 3000
        })
        return
    end

    -- Perform field repair
    local playerPed = PlayerPedId()
    local wasDriver = GetPedInVehicleSeat(vehicle, -1) == playerPed

    -- Exit vehicle
    TaskLeaveVehicle(playerPed, vehicle, 0)
    Wait(2000)

    lib.notify({
        title = 'Field Repair',
        description = 'Using repair kit... Stand by.',
        type = 'info',
        duration = 3000
    })

    -- Single progress bar for field repair
    local success = lib.progressBar({
        duration = repairTime or 15000,
        label = 'Performing field repair...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        }
    })

    if success then
        -- Apply limited repair
        SetVehicleEngineHealth(vehicle, maxRepair or 350.0)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, true, false)

        -- Fix flat tires only
        for i = 0, 5 do
            if IsVehicleTyreBurst(vehicle, i, true) then
                SetVehicleTyreFixed(vehicle, i)
            end
        end

        -- Reduced performance (field repair limitation)
        SetVehicleEnginePowerMultiplier(vehicle, 0.5)
        SetVehicleEngineTorqueMultiplier(vehicle, 0.5)

        Wait(500)
        TaskWarpPedIntoVehicle(playerPed, vehicle, wasDriver and -1 or 0)

        PlaySoundFrontend(-1, "PICK_UP_WEAPON", "HUD_FRONTEND_CUSTOM_SOUNDSET", true)

        lib.notify({
            title = 'Field Repair Complete',
            description = ('Engine at %d%%. Reduced power. Seek full repair.'):format(math.floor(maxRepair / 10)),
            type = 'success',
            duration = 6000
        })
    else
        lib.notify({
            title = 'Repair Cancelled',
            description = 'Field repair interrupted',
            type = 'error',
            duration = 3000
        })
        TaskWarpPedIntoVehicle(playerPed, vehicle, wasDriver and -1 or 0)
    end
end)

-----------------------------------------------------------
-- PRESET SYSTEM (v2.1.0+)
-- Save and load vehicle configuration presets
-----------------------------------------------------------
local cachedPresets = {}

-- Get current vehicle configuration
local function GetVehicleConfiguration(vehicle)
    if not vehicle or vehicle == 0 then return nil end

    SetVehicleModKit(vehicle, 0)

    local config = {
        livery = GetVehicleLivery(vehicle),
        liveryMod = GetVehicleMod(vehicle, 48),
        extras = {},
        colors = {
            primary = {GetVehicleColours(vehicle)},
            extra = {GetVehicleExtraColours(vehicle)}
        },
        mods = {}
    }

    -- Get extras state
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            config.extras[i] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    -- Get performance mods
    for i = 0, 16 do
        config.mods[i] = GetVehicleMod(vehicle, i)
    end

    return config
end

-- Apply vehicle configuration
local function ApplyVehicleConfiguration(vehicle, config)
    if not vehicle or vehicle == 0 or not config then return end

    SetVehicleModKit(vehicle, 0)

    -- Apply livery
    if config.livery and config.livery >= 0 then
        SetVehicleLivery(vehicle, config.livery)
    end
    if config.liveryMod and config.liveryMod >= 0 then
        SetVehicleMod(vehicle, 48, config.liveryMod, false)
    end

    -- Apply extras
    if config.extras then
        for i, state in pairs(config.extras) do
            if DoesExtraExist(vehicle, tonumber(i)) then
                SetVehicleExtra(vehicle, tonumber(i), not state)
            end
        end
    end

    -- Apply colors
    if config.colors then
        if config.colors.primary then
            SetVehicleColours(vehicle, config.colors.primary[1], config.colors.primary[2])
        end
        if config.colors.extra then
            SetVehicleExtraColours(vehicle, config.colors.extra[1], config.colors.extra[2])
        end
    end

    -- Apply mods
    if config.mods then
        for modType, modIndex in pairs(config.mods) do
            if modIndex >= 0 then
                SetVehicleMod(vehicle, tonumber(modType), modIndex, false)
            end
        end
    end
end

-- Open preset menu
function OpenPresetMenu()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then
        lib.notify({
            title = 'Error',
            description = 'You must be in a vehicle',
            type = 'error',
            duration = 3000
        })
        return
    end

    local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

    -- Request presets from server
    TriggerServerEvent('vehiclemods:server:loadPresets', vehicleModel)

    -- Show loading
    lib.notify({
        title = 'Loading Presets',
        description = 'Fetching saved configurations...',
        type = 'info',
        duration = 2000
    })
end

-- Handle received presets
RegisterNetEvent('vehiclemods:client:receivePresets')
AddEventHandler('vehiclemods:client:receivePresets', function(presets)
    cachedPresets = presets or {}

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return end

    local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local options = {}

    -- Save new preset option
    table.insert(options, {
        title = 'Save New Preset',
        description = 'Save current configuration as a preset',
        icon = 'floppy-disk',
        onSelect = function()
            local input = lib.inputDialog('Save Preset', {
                { type = 'input', label = 'Preset Name', required = true, max = 50 },
                { type = 'checkbox', label = 'Share with Job (Fleet Preset)' }
            })

            if input then
                local config = GetVehicleConfiguration(vehicle)
                TriggerServerEvent('vehiclemods:server:savePreset', input[1], vehicleModel, config, input[2])
            end
        end
    })

    -- List existing presets
    if #cachedPresets > 0 then
        table.insert(options, {
            title = '─── Saved Presets ───',
            disabled = true
        })

        for _, preset in ipairs(cachedPresets) do
            local icon = preset.isJobPreset and 'users' or 'user'
            local suffix = preset.isJobPreset and ' [Fleet]' or ''

            table.insert(options, {
                title = preset.name .. suffix,
                description = preset.isOwner and 'Click to apply, right-click to delete' or 'Click to apply',
                icon = icon,
                onSelect = function()
                    ApplyVehicleConfiguration(vehicle, preset.data)
                    lib.notify({
                        title = 'Preset Applied',
                        description = ('Applied "%s"'):format(preset.name),
                        type = 'success',
                        duration = 3000
                    })
                end,
                menu = preset.isOwner and 'preset_delete_' .. preset.name or nil
            })

            -- Create delete submenu for owned presets
            if preset.isOwner then
                lib.registerContext({
                    id = 'preset_delete_' .. preset.name,
                    title = 'Delete ' .. preset.name .. '?',
                    menu = 'PresetMenu',
                    options = {
                        {
                            title = 'Confirm Delete',
                            description = 'This cannot be undone',
                            icon = 'trash',
                            onSelect = function()
                                TriggerServerEvent('vehiclemods:server:deletePreset', preset.name, vehicleModel)
                                Wait(500)
                                OpenPresetMenu()
                            end
                        },
                        {
                            title = 'Cancel',
                            icon = 'xmark',
                            onSelect = function()
                                lib.showContext('PresetMenu')
                            end
                        }
                    }
                })
            end
        end
    else
        table.insert(options, {
            title = 'No Presets Saved',
            description = 'Save your first preset using the option above',
            icon = 'circle-info',
            disabled = true
        })
    end

    -- Back button
    table.insert(options, {
        title = 'Back',
        icon = 'arrow-left',
        onSelect = function()
            TriggerEvent('vehiclemods:client:openVehicleModMenu')
        end
    })

    lib.registerContext({
        id = 'PresetMenu',
        title = vehicleModel .. ' Presets',
        options = options
    })
    lib.showContext('PresetMenu')
end)

-----------------------------------------------------------
-- LIVERY MEMORY SYSTEM (v2.1.0+)
-- Auto-apply last used livery when entering vehicles
-----------------------------------------------------------
local lastVehicle = 0
local appliedMemoryThisSession = {}

-- Save current livery to memory
function SaveLiveryToMemory(vehicle)
    if not Config.AutoApplyLivery or not Config.AutoApplyLivery.enabled then return end
    if not vehicle or vehicle == 0 then return end

    local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
    local liveryIndex = GetVehicleLivery(vehicle)
    local liveryMod = GetVehicleMod(vehicle, 48)

    -- Get extras state if configured
    local extras = nil
    if Config.AutoApplyLivery.rememberExtras then
        extras = {}
        for i = 0, 20 do
            if DoesExtraExist(vehicle, i) then
                extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
            end
        end
    end

    -- Get custom livery if active
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local customLivery = ActiveCustomLiveries[netId]

    TriggerServerEvent('vehiclemods:server:saveLiveryMemory',
        vehicleModel, liveryIndex, liveryMod, customLivery, extras)
end

-- Handle livery memory from server
RegisterNetEvent('vehiclemods:client:applyLiveryMemory')
AddEventHandler('vehiclemods:client:applyLiveryMemory', function(vehicleModel, memory)
    if not Config.AutoApplyLivery or not Config.AutoApplyLivery.enabled then return end

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then return end

    local currentModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
    if currentModel ~= vehicleModel:lower() then return end

    -- Check if already applied this session
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if appliedMemoryThisSession[netId] then return end
    appliedMemoryThisSession[netId] = true

    SetVehicleModKit(vehicle, 0)

    -- Apply remembered livery
    if memory.liveryIndex and memory.liveryIndex >= 0 then
        SetVehicleLivery(vehicle, memory.liveryIndex)
    end
    if memory.liveryMod and memory.liveryMod >= 0 then
        SetVehicleMod(vehicle, 48, memory.liveryMod, false)
    end

    -- Apply custom livery if remembered
    if memory.customLivery then
        TriggerEvent('vehiclemods:client:setCustomLivery',
            netId, currentModel, memory.customLivery)
    end

    -- Apply extras
    if memory.extras then
        for i, state in pairs(memory.extras) do
            if DoesExtraExist(vehicle, tonumber(i)) then
                SetVehicleExtra(vehicle, tonumber(i), not state)
            end
        end
    end

    if Config.AutoApplyLivery.notifyOnApply then
        lib.notify({
            title = 'Livery Applied',
            description = 'Previous configuration restored',
            type = 'success',
            duration = 2500
        })
    end

    if Config.Debug then
        print(("^2[LIVERY-MEMORY]:^0 Applied saved livery for %s"):format(vehicleModel))
    end
end)

-- Track recently spawned vehicles (for jg-garages compatibility)
local recentlySpawnedVehicles = {}

-- Monitor vehicle entry for auto-apply
CreateThread(function()
    while true do
        Wait(1000)

        if Config.AutoApplyLivery and Config.AutoApplyLivery.enabled then
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)

            -- Entered a new vehicle
            if vehicle ~= 0 and vehicle ~= lastVehicle then
                lastVehicle = vehicle

                -- Check jg-scripts compatibility
                local jgCompat = Config.Compatibility and Config.Compatibility['jg-scripts']
                local shouldApply = true

                if jgCompat and jgCompat.enabled and jgCompat.respectGarageLivery then
                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                    local spawnTime = recentlySpawnedVehicles[netId]

                    if spawnTime then
                        local elapsed = GetGameTimer() - spawnTime
                        local gracePeriod = jgCompat.garageSpawnGracePeriod or 5000

                        if elapsed < gracePeriod then
                            -- Vehicle was recently spawned by garage, skip auto-apply
                            shouldApply = false
                            if Config.Debug then
                                print(("^3[COMPAT]:^0 Skipping livery auto-apply (garage grace period: %dms remaining)"):format(gracePeriod - elapsed))
                            end
                        else
                            -- Grace period expired, clean up
                            recentlySpawnedVehicles[netId] = nil
                        end
                    end
                end

                if shouldApply and (Config.AutoApplyLivery.applyOnEnter or Config.AutoApplyLivery.applyOnSpawn) then
                    local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
                    TriggerServerEvent('vehiclemods:server:loadLiveryMemory', vehicleModel)
                end
            elseif vehicle == 0 then
                lastVehicle = 0
            end
        end
    end
end)

-- Listen for garage vehicle spawns (jg-advancedgarages compatibility)
-- jg-advancedgarages triggers this when spawning a vehicle
RegisterNetEvent('jg-advancedgarages:client:vehicleSpawned')
AddEventHandler('jg-advancedgarages:client:vehicleSpawned', function(vehicle, plate)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local jgCompat = Config.Compatibility and Config.Compatibility['jg-scripts']
    if jgCompat and jgCompat.enabled and jgCompat.respectGarageLivery then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        recentlySpawnedVehicles[netId] = GetGameTimer()

        if Config.Debug then
            print(("^2[COMPAT]:^0 jg-garages spawned vehicle (plate: %s), applying grace period"):format(plate or "unknown"))
        end
    end
end)

-- Alternative: Listen for QBCore garage spawns
RegisterNetEvent('qb-garages:client:vehicleSpawned')
AddEventHandler('qb-garages:client:vehicleSpawned', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local qbCompat = Config.Compatibility and Config.Compatibility['qb-scripts']
    if qbCompat and qbCompat.enabled and qbCompat.respectGarageLivery then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        recentlySpawnedVehicles[netId] = GetGameTimer()
    end
end)

-- Clean up session tracking periodically
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes
        appliedMemoryThisSession = {}
    end
end)

-----------------------------------------------------------
-- DYNAMIC MARKER SYSTEM (v2.1.1+)
-- Distance-based opacity for premium marker experience
-----------------------------------------------------------
CreateThread(function()
    while true do
        local cfg = Config.DynamicMarkers
        if not cfg or not cfg.enabled then
            Wait(5000) -- Check periodically if enabled
            goto continue
        end

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = 500 -- Default sleep when no markers nearby

        for _, zone in ipairs(Config.ModificationZones) do
            local distance = #(playerCoords - zone.coords)

            -- Only draw if within fade start distance
            if distance <= cfg.fadeStartDistance then
                sleep = 0 -- Need to draw every frame

                -- Calculate opacity based on distance
                local alpha = 0
                if distance <= cfg.fadeEndDistance then
                    alpha = 255 -- Full opacity
                else
                    -- Linear interpolation between fadeEnd and fadeStart
                    local fadeRange = cfg.fadeStartDistance - cfg.fadeEndDistance
                    local fadeProgress = (cfg.fadeStartDistance - distance) / fadeRange
                    alpha = math.floor(fadeProgress * 255)
                end

                -- Get zone-specific color
                local colors = cfg.colors[zone.type] or cfg.colors.default
                local r, g, b, baseAlpha = colors[1], colors[2], colors[3], colors[4]

                -- Apply calculated alpha (scaled by base alpha)
                local finalAlpha = math.floor((alpha / 255) * (baseAlpha or 200))

                -- Draw the marker
                DrawMarker(
                    cfg.markerType,
                    zone.coords.x, zone.coords.y, zone.coords.z - 0.5,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    cfg.size.x, cfg.size.y, cfg.size.z,
                    r, g, b, finalAlpha,
                    cfg.bobUpDown, false, 2, cfg.rotate, nil, nil, false
                )
            end
        end

        Wait(sleep)
        ::continue::
    end
end)

-----------------------------------------------------------
-- LIVERY LABEL SYSTEM (v2.1.1+)
-- Get human-readable livery names when available
-----------------------------------------------------------
local liveryLabelCache = {}

function GetLiveryLabel(vehicle, liveryIndex)
    local vehicleModel = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(vehicleModel):lower()
    local cacheKey = modelName .. "_" .. liveryIndex

    -- Check cache first
    if liveryLabelCache[cacheKey] then
        return liveryLabelCache[cacheKey]
    end

    -- Try to get livery name from game
    -- Format: VEHICLE_MODEL_LIVERY_INDEX (e.g., POLICE_LIVERY_1)
    local attempts = {
        ("%s_LIVERY_%d"):format(modelName:upper(), liveryIndex),
        ("%s_LIV%d"):format(modelName:upper(), liveryIndex),
        ("LIVERY_%s_%d"):format(modelName:upper(), liveryIndex)
    }

    for _, labelKey in ipairs(attempts) do
        local label = GetLabelText(labelKey)
        if label and label ~= "NULL" and label ~= labelKey then
            liveryLabelCache[cacheKey] = label
            return label
        end
    end

    -- Fallback: Check if this is a known emergency vehicle livery pattern
    local emergencyPatterns = {
        [0] = "Standard",
        [1] = "LSPD",
        [2] = "LSSD/BCSO",
        [3] = "Highway Patrol",
        [4] = "Unmarked",
        [5] = "Slicktop",
        [6] = "K9 Unit",
        [7] = "Traffic",
        [8] = "Supervisor"
    }

    -- Check if vehicle is emergency class
    local vehicleClass = GetVehicleClass(vehicle)
    if vehicleClass == 18 then -- Emergency vehicle class
        local pattern = emergencyPatterns[liveryIndex]
        if pattern then
            liveryLabelCache[cacheKey] = pattern
            return pattern
        end
    end

    -- Final fallback
    local fallback = "Livery " .. liveryIndex
    liveryLabelCache[cacheKey] = fallback
    return fallback
end

-- Enhanced livery name for search functionality
function GetEnhancedLiveryName(vehicle, liveryIndex)
    local label = GetLiveryLabel(vehicle, liveryIndex)
    -- Include index for search: "K9 Unit (6)" or "Livery 3"
    if label:match("^Livery %d") then
        return label
    else
        return ("%s (#%d)"):format(label, liveryIndex)
    end
end

-----------------------------------------------------------
-- REPAIR COST SYSTEM (v2.1.1+)
-- Integration with server economy
-----------------------------------------------------------
local currentZoneType = nil -- Track current zone for context

function GetRepairCost(repairType, vehicle)
    local cfg = Config.RepairCosts
    if not cfg or not cfg.enabled then
        return 0, true -- Free if disabled
    end

    -- Get base cost
    local baseCost = 0
    if repairType == 'full' then
        baseCost = cfg.fullRepairCost
    elseif repairType == 'emergency' then
        baseCost = cfg.emergencyRepairCost
    elseif repairType == 'field' then
        baseCost = cfg.fieldRepairCost
    end

    -- Scale by damage if enabled
    if cfg.scaleCostByDamage and vehicle and vehicle ~= 0 then
        local damage = GetVehicleDamageReport(vehicle)
        if damage then
            -- Lower condition = higher cost
            local damagePercent = (100 - damage.overallCondition) / 100
            local multiplier = 1 + (damagePercent * (cfg.maxCostMultiplier - 1))
            baseCost = math.floor(baseCost * multiplier)
        end
    end

    return baseCost, false
end

-- Request payment from server
function RequestRepairPayment(repairType, cost, callback)
    if cost <= 0 then
        callback(true)
        return
    end

    TriggerServerEvent('vehiclemods:server:chargeRepair', repairType, cost)

    -- Wait for response
    local responded = false
    local success = false

    RegisterNetEvent('vehiclemods:client:repairPaymentResult')
    AddEventHandler('vehiclemods:client:repairPaymentResult', function(result, message)
        responded = true
        success = result
        if not result then
            lib.notify({
                title = 'Payment Failed',
                description = message or 'Insufficient funds',
                type = 'error',
                duration = 4000
            })
        end
    end)

    -- Timeout after 5 seconds
    SetTimeout(5000, function()
        if not responded then
            callback(false)
        else
            callback(success)
        end
    end)
end

-----------------------------------------------------------
-- JOB-SPECIFIC SUB-MENUS (v2.1.1+)
-- Zone-aware menu customization
-----------------------------------------------------------
function GetCurrentZoneDefaults()
    if not Config.JobDefaults or not Config.JobDefaults.enabled then
        return nil
    end

    local playerCoords = GetEntityCoords(PlayerPedId())

    for _, zone in ipairs(Config.ModificationZones) do
        local distance = #(playerCoords - zone.coords)
        if distance <= zone.radius then
            currentZoneType = zone.type
            return Config.JobDefaults[zone.type]
        end
    end

    currentZoneType = nil
    return nil
end

-- Get priority extras for current zone
function GetPriorityExtras()
    local defaults = GetCurrentZoneDefaults()
    if defaults and defaults.priorityExtras then
        return defaults.priorityExtras
    end
    return {}
end

-- Check if neon should be shown for current zone
function ShouldShowNeon()
    local defaults = GetCurrentZoneDefaults()
    if defaults then
        return defaults.showNeon ~= false
    end
    return true
end

-- Get suggested colors for current zone
function GetZoneSuggestedColors()
    local defaults = GetCurrentZoneDefaults()
    if defaults and defaults.defaultColors then
        return defaults.defaultColors
    end
    return nil
end
