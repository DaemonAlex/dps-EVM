--[[
    dps-fleet client/repair.lua

    Repairs: emergency patch-up, full repair and field repair (item-gated),
    called from client/workshop.lua's APPLY.repair. All pricing/gating is
    server-side (server.lua dps-fleet:server:chargeRepair / :fieldRepair);
    this file only runs the progress bar and, once the server confirms
    payment, the native repair sequence.

      RepairClient.report(veh)     -> table shaped for Workshop.describeDamage
      RepairClient.run(veh, kind)  -> ok, message  (kind: emergency|full|field)

    Ordering (controller ruling 2026-09-28): the progress bar runs FIRST;
    only when it completes uncancelled does this charge the player (or, for
    field, ask the server to check job/item/cooldown and charge). A charge
    that fails, or a cancelled bar, applies no natives and returns false.
    Nothing here calls lib.notify — the panel shows the returned message.

    Ported from legacy/evm_client.lua 2455-2988 (GetVehicleDamageReport,
    FormatDamageReport, EmergencyRepairVehicle, FullRepairVehicle,
    RequestFieldRepair/fieldRepairResult). Redesigned: one SetPedIntoVehicle
    instead of legacy's nine TaskWarpPedIntoVehicle call sites, no power/
    torque multiplier debuff (not in the ported native list), and the
    emergency cap formula replaces legacy's flat 450/650/800 magic numbers.
]]

RepairClient = RepairClient or {}

---@param veh number
---@return table|nil { engine, body, tank, tyres = { burst }, windows = { broken }, doors = { damaged } }
function RepairClient.report(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end

    local burst, broken, damaged = 0, 0, 0
    for i = 0, 5 do
        if IsVehicleTyreBurst(veh, i, false) then burst = burst + 1 end
    end
    for i = 0, 7 do
        if not IsVehicleWindowIntact(veh, i) then broken = broken + 1 end
    end
    for i = 0, 5 do
        if IsVehicleDoorDamaged(veh, i) then damaged = damaged + 1 end
    end

    return {
        engine = GetVehicleEngineHealth(veh),
        body = GetVehicleBodyHealth(veh),
        tank = GetVehiclePetrolTankHealth(veh),
        tyres = { burst = burst },
        windows = { broken = broken },
        doors = { damaged = damaged },
    }
end

-- kind -> the server callback that takes payment (and, for field, checks the
-- job/item/cooldown gate) once the progress bar has already completed.
local CHARGE = {
    emergency = function() return lib.callback.await('dps-fleet:server:chargeRepair', false, 'emergency') end,
    full = function() return lib.callback.await('dps-fleet:server:chargeRepair', false, 'full') end,
    field = function() return lib.callback.await('dps-fleet:server:fieldRepair', false) end,
}

-- Emergency and field both land the vehicle at the field repair cap — the
-- roadside/kit-limited fix; only 'full' fully resets the vehicle. Neither
-- profile below carries a power/torque multiplier debuff (legacy had one;
-- it is not in the ported native list for this task).
local function applyLimitedRepair(veh)
    local cap = (Config.Constants and Config.Constants.ENGINE_MAX_FIELD_REPAIR) or 350.0
    SetVehicleEngineHealth(veh, math.min(GetVehicleEngineHealth(veh) + 350, cap))
    for i = 0, 5 do
        if IsVehicleTyreBurst(veh, i, false) then SetVehicleTyreFixed(veh, i) end
    end
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
end

local function applyFullRepair(veh)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
end

local NATIVE_APPLY = { emergency = applyLimitedRepair, field = applyLimitedRepair, full = applyFullRepair }
local DONE_MESSAGE = { emergency = 'Emergency repair complete.', full = 'Full repair complete.', field = 'Field repair complete.' }

---@param veh number
---@param kind string 'emergency'|'full'|'field'
---@return boolean ok, string message
function RepairClient.run(veh, kind)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'No vehicle.' end
    local charge = CHARGE[kind]
    if not charge then return false, 'Unknown repair option.' end

    local ped = cache.ped
    local wasInside = cache.vehicle == veh
    local seat = wasInside and cache.seat or nil

    -- Out of the vehicle for the repair animation (legacy behaviour, kept);
    -- put back once below, whichever way this call ends, instead of legacy's
    -- nine separate TaskWarpPedIntoVehicle call sites.
    if wasInside then
        TaskLeaveVehicle(ped, veh, 0)
        Wait(1500)
    end

    local function restore()
        if wasInside and ped and DoesEntityExist(ped) and not IsPedInAnyVehicle(ped, false) then
            SetPedIntoVehicle(ped, veh, seat or -1)
        end
    end

    local completed = lib.progressBar({
        duration = (Config.FieldRepair and Config.FieldRepair.repairTime) or 8000,
        label = 'Repairing…',
        canCancel = true,
        disable = { car = true, move = true, combat = true },
    })
    if not completed then
        restore()
        return false, 'Repair cancelled.'
    end

    local paid, reason = charge()
    if paid ~= true then
        restore()
        return false, reason or 'Payment failed — no repairs applied.'
    end

    if not DoesEntityExist(veh) then
        restore()
        return false, 'Vehicle no longer exists.'
    end

    NATIVE_APPLY[kind](veh)
    restore()

    return true, DONE_MESSAGE[kind]
end
