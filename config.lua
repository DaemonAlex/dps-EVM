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

-- Drop-in job access (DPS 2026-09-27). With AutoJobs the workshop job set is derived
-- at resource start from exports.qbx_core:GetJobs(), so a new department needs no edit here.
Config.AutoJobs = true                     -- true: every job whose type is 'leo' or 'ems' may use the workshop
Config.ExtraWorkshopJobs = { 'mechanic' }  -- extra job names added to the derived set (not LEO/EMS typed)
Config.AutoAces = true                     -- true: grant the dps.fleet ace to group.admin and group.tester at start when missing
-- Config.JobMappings below is only read when Config.AutoJobs = false.

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
    Repair = true,              -- Vehicle repair functionality
    Sirens = true,  -- DPS: per-model siren tones for LVC
    Presets = true,  -- DPS: presets section
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

-----------------------------------------------------------
-- [[ 7. ECONOMY / REPAIR COSTS ]]
-- Charge for repairs to integrate with server economy
-- Set high to encourage using actual mechanic players
-----------------------------------------------------------
Config.RepairCosts = {
    enabled = true,                    -- Enable repair costs
    chargeFrom = 'bank',               -- 'bank', 'cash', or 'both' (tries bank first)
    currency = 'money',                -- Alternative: use 'money' for cash

    -- Cost structure (balanced for economy)
    fullRepairCost = 500,              -- Full repair at station
    emergencyRepairCost = 200,         -- Quick patch-up
    fieldRepairCost = 350,             -- Field repair (higher to encourage station use)

    -- (scaleCostByDamage / maxCostMultiplier removed 2026-08-28: damage-scaled
    -- pricing was computed client-side and is not trusted — the server charges
    -- flat per-type base costs.)

    -- Job-based pricing (real DPS jobs only)
    freeForJobs = {
        'mechanic'                     -- Mechanics repair free
    },
    discountJobs = {
        {job = 'police', discount = 0.25},
        {job = 'bcso', discount = 0.25},
        {job = 'sasp', discount = 0.25},
        {job = 'fib', discount = 0.25},
        {job = 'doc', discount = 0.25},
        {job = 'dfw', discount = 0.25},
        {job = 'rpd', discount = 0.25},
        {job = 'rcso', discount = 0.25},
        {job = 'uscg', discount = 0.25},
        {job = 'lsfd', discount = 0.25},
        {job = 'rfd', discount = 0.25},
        {job = 'sams', discount = 0.25}, -- DPS 2026-09-25: medical set (was vendor 'ambulance')
        {job = 'omc', discount = 0.25},
        {job = 'rmc', discount = 0.25}
    }
}

-----------------------------------------------------------
-- JOB-SPECIFIC DEFAULTS (v2.1.1+)
-- Zone-aware menu defaults for better UX
-----------------------------------------------------------
-- Group keys (police / fire / ambulance) match Config.JobMappings; these are NOT job names.
Config.JobDefaults = {
    enabled = true,                    -- Enable zone-specific defaults
    police = {
        defaultColors = {              -- Default vehicle colors
            primary = 0,               -- Black
            secondary = 0              -- Black
        },
        suggestedNeonColor = {0, 0, 255},  -- Blue neon
        priorityExtras = {1, 2, 3},    -- Lightbar, pushbar, spots
        showNeon = false               -- Police usually don't want neon
    },
    fire = {
        defaultColors = {
            primary = 27,              -- Red
            secondary = 0              -- Black
        },
        suggestedNeonColor = {255, 0, 0},  -- Red neon
        priorityExtras = {1, 2},       -- Lightbar, equipment
        showNeon = false
    },
    ambulance = {
        defaultColors = {
            primary = 111,             -- White
            secondary = 27             -- Red accent
        },
        suggestedNeonColor = {255, 255, 255},  -- White neon
        priorityExtras = {1, 3},       -- Lightbar, medical equipment
        showNeon = false
    }
}

-----------------------------------------------------------
-- FIELD REPAIR SYSTEM (v2.1.0+)
-- Allows emergency repairs outside of stations with requirements
-----------------------------------------------------------
Config.FieldRepair = {
    enabled = true,                    -- Enable field repair system
    requireItem = true,                -- Require a toolkit item
    itemName = 'repairkit',            -- Item name (or 'advanced_repairkit', 'toolkit')
    alternativeItems = {               -- Alternative items that work
        'repairkit', 'toolkit', 'mechanickit', 'advanced_repairkit'
    },
    allowedJobs = {                    -- Jobs that can use field repair (real DPS jobs only;
                                       -- no mechanic: field repair is reached through the menu,
                                       -- which is emergency-jobs-only)
        'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg',
        'lsfd', 'rfd', 'sams', 'omc', 'rmc' -- DPS 2026-09-25: was '... lsfd, ambulance'
    },
    minGrade = 0,                      -- Minimum job grade (0 = any grade)
    maxEngineRepair = 350.0,           -- Max engine health from field repair (see Constants.ENGINE_MAX_FIELD_REPAIR)
    cooldown = 300000,                 -- 5 min cooldown (see Constants.COOLDOWN_FIELD_REPAIR)
    consumeItem = true,                -- Remove item after use
    repairTime = 15000                 -- Time in ms for field repair animation
}

-----------------------------------------------------------
-- PRESET/FLEET SYSTEM (v2.1.0+)
-- Save and load vehicle configurations for fleet standardization
-----------------------------------------------------------
Config.Presets = {
    enabled = true,                    -- Enable preset system
    maxPresetsPerPlayer = 10,          -- Max presets per player
    maxPresetsPerJob = 5,              -- Max shared job presets
    allowJobPresets = true,            -- Allow creating job-wide presets
    minGradeForJobPresets = 3,         -- Min grade to create job presets (Sergeant+)
    saveToDatabase = true              -- Persist presets to database
}

-----------------------------------------------------------
-- AUTO-APPLY LIVERY SYSTEM (v2.1.0+)
-- Automatically apply last used livery when spawning vehicles
-----------------------------------------------------------
Config.AutoApplyLivery = {
    enabled = true,                    -- Enable auto-apply
    applyOnSpawn = true,               -- Apply when vehicle spawns
    applyOnEnter = false,              -- Apply when entering vehicle (alternative)
    rememberPerVehicle = true,         -- Remember livery per vehicle model
    rememberExtras = true,             -- Also remember extra toggles
    notifyOnApply = true               -- Show notification when auto-applied
}

-- Custom liveries configuration - add your vehicle liveries here
Config.CustomLiveries = {
    ["police"] = {
        {name = "LSPD Standard", file = "liveries/police_livery1.yft"},
        {name = "LSPD Slicktop", file = "liveries/police_livery2.yft"},
        {name = "BCSO Standard", file = "liveries/police_livery3.yft"}
    },
    -- The keys here are vehicle spawn codes, not job names (controller 2026-09-27).
    ["ambulance"] = {
        {name = "EMS Standard", file = "liveries/ambulance_livery1.yft"},
        {name = "Fire Department", file = "liveries/ambulance_fire.yft"}
    }
    -- Add more vehicles and liveries as needed
}

-----------------------------------------------------------
-- [[ 8. INPUT VALIDATION ]]
-- Prevent invalid/malicious input for presets and liveries
-----------------------------------------------------------
Config.InputValidation = {
    maxNameLength = 32,                -- Max characters for preset/livery names
    minNameLength = 1,                 -- Min characters
    allowedCharacters = "^[%w%s%-_]+$", -- Alphanumeric, spaces, hyphens, underscores only
    sanitizeNames = true,              -- Auto-sanitize input
    blockSpecialChars = true           -- Block SQL injection characters
}

-----------------------------------------------------------
-- [[ 9. NAMED CONSTANTS ]]
-- Replace magic numbers for better maintainability
-----------------------------------------------------------
Config.Constants = {
    -- Vehicle classes
    VEHICLE_CLASS_EMERGENCY = 18,

    -- Damage thresholds
    DAMAGE_MINOR = 750,               -- Above this = minor damage
    DAMAGE_MODERATE = 500,            -- Above this = moderate damage
    DAMAGE_SEVERE = 250,              -- Above this = severe damage
    DAMAGE_CRITICAL = 100,            -- Above this = critical damage

    -- Engine health
    ENGINE_HEALTHY = 1000,
    ENGINE_MAX_FIELD_REPAIR = 350,

    -- Cooldowns (ms)
    COOLDOWN_FIELD_REPAIR = 300000,   -- 5 minutes
    COOLDOWN_MENU_REOPEN = 500,       -- 500ms anti-spam

    -- Distances
    ZONE_CHECK_INTERVAL = 1000,       -- Check zone every 1 second
    MARKER_FADE_START = 30.0,
    MARKER_FADE_END = 5.0,

    -- Cache durations
    CACHE_JOB_DURATION = 300000,      -- 5 minutes
    CACHE_VEHICLE_DURATION = 60000,   -- 1 minute
}
