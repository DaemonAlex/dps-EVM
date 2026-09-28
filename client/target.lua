--[[
    dps-fleet client/target.lua

    ox_target entry point for the workshop, and the auto-apply-livery-memory hook
    that replaces EVM's Wait(1000) vehicle-entry thread. Both are event/callback
    driven; this file adds no thread of its own.

    Ported from legacy/evm_client.lua 3521-3553 (ox_target registration) and the
    AutoApplyLivery restore block 3208-3445 (the restore body now lives in
    client/workshop.lua as WorkshopClient.applyMemory).
]]

-- ── ox_target: Workshop ────────────────────────────────────────────────────────
-- Explicit entity, not GetVehiclePedIsIn: the option must work standing beside a
-- parked car, not only from the driver seat. WorkshopClient.setVehicle stores it
-- for ws:open; closePanel (client.lua) clears it so a stale target never outranks
-- cache.vehicle on the next open.

local function registerFleetTarget()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'dps_fleet_workshop',
            icon = 'fa-solid fa-screwdriver-wrench',
            label = 'Workshop',
            distance = 3.0,
            canInteract = function(entity)
                return entity ~= nil and DoesEntityExist(entity)
            end,
            onSelect = function(data)
                if not data or not data.entity then return end
                WorkshopClient.setVehicle(data.entity)
                FleetPanel.open('workshop')
            end,
        },
    })
end

if GetResourceState('ox_target') == 'started' then
    registerFleetTarget()
end
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'ox_target' then registerFleetTarget() end
end)

-- ── auto-apply livery memory ──────────────────────────────────────────────────
-- ox_lib fires this once per vehicle-entry (cache.vehicle change), never a loop,
-- which is what EVM's Wait(1000) thread was polling for. Driver seat only: a
-- passenger did not choose this vehicle. applyOnEnter/applyOnSpawn are honoured
-- the way the legacy thread did (either flag gates the same entry check).

lib.onCache('vehicle', function(veh)
    if not veh or not Config.AutoApplyLivery or not Config.AutoApplyLivery.enabled then return end
    if not (Config.AutoApplyLivery.applyOnEnter or Config.AutoApplyLivery.applyOnSpawn) then return end
    if cache.seat ~= -1 then return end

    local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower()
    local mem = lib.callback.await('dps-fleet:server:liveryMemory', false, model)
    if not mem then return end
    WorkshopClient.applyMemory(veh, mem)
end)
