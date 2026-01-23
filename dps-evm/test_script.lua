-- Test Script for Emergency Vehicle Menu
-- This script can be used to test the basic functionality

print("^2INFO:^0 Starting Emergency Vehicle Menu Test")

-- Test 1: Config Loading
if Config then
    print("^2PASS:^0 Config loaded successfully")
    
    -- Test framework detection
    local framework = Config.DetectFramework()
    print("^2INFO:^0 Detected framework: " .. framework)

    -- Test framework-specific resources
    if framework == 'esx' then
        print("^2INFO:^0 ESX resource state: " .. GetResourceState('es_extended'))
    elseif framework == 'qbcore' then
        print("^2INFO:^0 QBCore resource state: " .. GetResourceState('qb-core'))
        print("^2INFO:^0 QBX Core resource state: " .. GetResourceState('qbx_core'))
    elseif framework == 'qbox' then
        print("^2INFO:^0 QBox Core resource state: " .. GetResourceState('qbox-core'))
        print("^2INFO:^0 QBX Core resource state: " .. GetResourceState('qbx-core'))
    end
    
    -- Test modification zones
    if Config.ModificationZones and #Config.ModificationZones > 0 then
        print("^2PASS:^0 " .. #Config.ModificationZones .. " modification zones configured")
        for i, zone in ipairs(Config.ModificationZones) do
            print("^2INFO:^0 Zone " .. i .. ": " .. zone.name .. " (" .. zone.type .. ")")
        end
    else
        print("^1FAIL:^0 No modification zones configured")
    end
    
    -- Test enabled modifications
    if Config.EnabledModifications then
        print("^2PASS:^0 Enabled modifications:")
        for mod, enabled in pairs(Config.EnabledModifications) do
            print("^2INFO:^0   " .. mod .. ": " .. tostring(enabled))
        end
    else
        print("^1FAIL:^0 No modifications enabled")
    end
    
    -- Test custom liveries
    if Config.CustomLiveries then
        local totalLiveries = 0
        for vehicle, liveries in pairs(Config.CustomLiveries) do
            totalLiveries = totalLiveries + #liveries
            print("^2INFO:^0 " .. vehicle .. " has " .. #liveries .. " custom liveries")
        end
        print("^2PASS:^0 Total custom liveries: " .. totalLiveries)
    else
        print("^3WARN:^0 No custom liveries configured")
    end
else
    print("^1FAIL:^0 Config not loaded")
end

-- Test 2: Emergency Vehicle Detection
print("^2INFO:^0 Testing emergency vehicle detection...")

-- Test with common emergency vehicle models
local testVehicles = {
    "police", "police2", "police3", "police4", "policeb", "policet",
    "sheriff", "sheriff2", "ambulance", "firetruk", "fbi", "fbi2"
}

for _, model in ipairs(testVehicles) do
    local hash = GetHashKey(model)
    if IsModelValid(hash) then
        print("^2INFO:^0 Testing model: " .. model)
        -- Note: We can't actually test the vehicle detection without spawning vehicles
        -- This would require being in-game
    end
end

-- Test 3: Zone Detection Function
print("^2INFO:^0 Testing zone detection...")

if Config.IsInModificationZone then
    -- Test with a sample coordinate (Mission Row PD)
    local testCoords = vector3(454.6, -1017.4, 28.4)
    local inZone, zoneInfo = Config.IsInModificationZone(testCoords)
    
    if inZone then
        print("^2PASS:^0 Zone detection working - " .. zoneInfo.message)
    else
        print("^3INFO:^0 Test coordinates not in zone (expected if using default config)")
    end
else
    print("^1FAIL:^0 Zone detection function not found")
end

print("^2INFO:^0 Emergency Vehicle Menu Test Complete")
print("^2INFO:^0 To fully test the menu, spawn an emergency vehicle and use /modveh in a modification zone")
