Config = Config or {}

-----------------------------------------------------------
-- [[ 3. JOB ACCESS CONTROL ]]
-----------------------------------------------------------
Config.EnableJobRestrictions = true    -- DSRP: emergency-job restriction ON (enforced server-side)
Config.EnableGradeRestrictions = false -- Enable grade/rank requirements
Config.DisableZoneRestrictions = true  -- DSRP 2026-08-22: zones OFF — emergency jobs may modify anywhere (job check still enforced server-side)

-- Keep the hand-authored mappings below. Without this flag,
-- Config.AutoConfigureJobSystem() runs during Initialize and OVERWRITES this
-- table with a generic list, silently dropping saspr/statepolice/trooper from
-- police and the whole mechanic group, so those jobs failed authorization even
-- though they are listed here.
Config.ManualJobSystem = true

-- Job name mappings — MUST match qbx_core/shared/jobs.lua on this server.
-- DPS runs six LEO agencies (2026-08-28 audit): police (LSPD), bcso, sasp,
-- fib, doc, dfw. Fire+EMS are lsfd and ambulance. The old list carried names
-- that don't exist here (sahp/saspr/statepolice/trooper/lspd/sheriff), which
-- locked SASP/FIB/DOC/DFW out of the menu entirely.
-- DPS 2026-09-27: the mechanic group is IN (Damon: "EVM any vehicle" for admins and mechanics); JobMappings drives MENU access
-- (police+fire+ambulance+mechanic). Mechanic repair pricing comes from
-- Config.RepairCosts.freeForJobs, which is a separate list.
Config.JobMappings = { -- DPS 2026-09-25: group keys, not job names. Every LEO / fire / medical job listed.
    police = {'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg'},
    fire = {'lsfd', 'rfd'},
    ambulance = {'sams', 'omc', 'rmc'},
    mechanic = {'mechanic'}
}

-----------------------------------------------------------
-- [[ 6. FEATURE TOGGLES ]]
-----------------------------------------------------------
Config.EnabledModifications = {
    Liveries = true,            -- Standard vehicle liveries
    CustomLiveries = true,      -- Custom YFT liveries
    Performance = true,         -- Engine, brakes, transmission, etc.
    Appearance = true,          -- Colors, wheels, window tint
    Neon = false,               -- Neon lights (enable for unmarked/undercover units)
    Extras = true,              -- Vehicle extras toggle (lightbars, pushbars, etc.)
    Doors = true,               -- Door controls
    Repair = true               -- Vehicle repair functionality
}

-- Selective neon for undercover/unmarked vehicles
Config.UndercoverNeon = {
    enabled = false,            -- Set TRUE to allow neon on specific vehicles only
    allowedVehicles = {         -- Vehicle spawn codes that CAN have neon
        -- "unmarked_charger",
        -- "undercover_taurus",
        -- "slicktop_explorer",
    }
}
