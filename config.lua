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

-----------------------------------------------------------
-- [[ 10. TRUNK GEAR ]]  (Task 7b, DPS 2026-09-28)
-- Vehiclegear 1.1.5-dps1 folded in: original by Lapertaja (CC BY-NC-SA 4.0,
-- docs/licenses/vehiclegear.txt), DPS fork by DaemonAlex. Everything the old
-- resource kept at the top level of its own Config lives under Config.TrunkGear
-- so no key can collide with the workshop's.
--
-- Damon 2026-09-27: "add fire gear to engines and other fire cars as well as
-- police, swat and other jobs in vehicles that need them". Gear is therefore
-- chosen by the vehicle's DEPARTMENT (data/emergency.json), not by a hand list.
-----------------------------------------------------------
Config.TrunkGear = {
    enabled = true,                          -- one switch for the whole feature

    ---------------------------------------------------------
    -- Which vehicles carry gear
    ---------------------------------------------------------
    -- true: every model in data/emergency.json carries its department's kit, so a
    -- new emergency pack needs no edit here. allowedVehicles is the per-model
    -- override and is read either way; with AutoVehicles = false it is the only list.
    AutoVehicles = true,
    allowedVehicles = {
        -- gbpolstanier = { 'bproof', 'refvest', 'helmet' },   -- model = kit
    },

    -- Department -> kit. The keys are the dept values in data/emergency.json
    -- (police, police_swat, bcso, sasp, fib, doc, dfw, uscg, rpd, rcso, lsfd, rfd,
    -- sams, omc, rmc). A department missing here falls through to DefaultGear.
    DeptGear = {
        police      = { 'bproof', 'refvest', 'helmet' },
        police_swat = { 'heavy', 'bproof', 'helmet' },
        bcso        = { 'bproof', 'refvest', 'helmet' },
        sasp        = { 'bproof', 'refvest', 'helmet' },
        fib         = { 'bproof', 'refvest', 'helmet' },
        doc         = { 'bproof', 'refvest', 'helmet' },
        dfw         = { 'bproof', 'refvest', 'helmet' },
        uscg        = { 'bproof', 'refvest', 'helmet' },
        rpd         = { 'bproof', 'refvest', 'helmet' },
        rcso        = { 'bproof', 'refvest', 'helmet' },
        lsfd        = { 'turnout', 'firehelmet', 'refvest' },
        rfd         = { 'turnout', 'firehelmet', 'refvest' },
        sams        = { 'refvest', 'medbag' },
        omc         = { 'refvest', 'medbag' },
        rmc         = { 'refvest', 'medbag' },
    },
    -- Only reached by a model that IS in data/emergency.json but whose department
    -- has no kit above — the dept 'none' and 'unsorted' rows (coroner vans, tow
    -- trucks, 13 models on 2026-09-28). A reflective vest is safe on any of them.
    DefaultGear = { 'refvest' },

    ---------------------------------------------------------
    -- Who may take it
    ---------------------------------------------------------
    -- true: reuse the workshop job set (qbx_core types leo + ems + Config.ExtraWorkshopJobs),
    -- so fire and medical jobs are in without an edit. Authorizedjobs is only read
    -- when AutoJobs = false.
    AutoJobs = true,
    Authorizedjobs = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },

    -- false: an allowed job may only take gear off its own family's vehicles, so
    -- police cannot pull turnout gear out of a fire engine. true: any allowed job
    -- may take any department's gear.
    CrossDept = false,
    -- Department -> the job names that may take its kit. A department left out is
    -- open to every allowed job. Job names are the canon in qbx_core/shared/jobs.lua.
    DeptJobs = {
        police      = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        police_swat = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        bcso        = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        sasp        = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        fib         = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        doc         = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        dfw         = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        uscg        = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        rpd         = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        rcso        = { 'police', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'rpd', 'rcso', 'uscg' },
        lsfd        = { 'lsfd', 'rfd' },
        rfd         = { 'lsfd', 'rfd' },
        sams        = { 'sams', 'omc', 'rmc' },
        omc         = { 'sams', 'omc', 'rmc' },
        rmc         = { 'sams', 'omc', 'rmc' },
    },

    ---------------------------------------------------------
    -- Behaviour (upstream keys, unchanged defaults)
    ---------------------------------------------------------
    RequireUnlocked = true,                  -- the vehicle must be unlocked
    RequireItems = true,                     -- the item must be in that trunk (only bproof and medbag have one)
    NotifyDuration = 5,                      -- seconds
    Duration = 3500,                         -- progress circle, ms
    Sound = { Enable = false, Name = 'CHALLENGE_UNLOCKED', Set = 'HUD_AWARDS' },

    ---------------------------------------------------------
    -- The gear itself
    ---------------------------------------------------------
    -- slot: vest (component 9) / torso (component 11) / head (prop 0), or false for
    --       item-only gear that changes no clothing.
    -- item: the ox_inventory item that must be in the trunk (false = none).
    -- give: true hands that item to the player instead of consuming it.
    -- male/female: { drawable, texture } for that gender, or false for no clothing change.
    --   Freemode drawables differ between mp_m_freemode_01 and mp_f_freemode_01;
    --   one number for both was the upstream bug.
    -- Set an entry to false to switch that piece off, e.g. Config.TrunkGear.Gear.heavy = false
    Gear = {
        bproof = {
            label = 'Grab bulletproof vest', busy = 'Equipping bulletproof vest…',
            done = "You've equipped a bulletproof vest.", icon = 'fa-solid fa-shield-halved',
            slot = 'vest', armour = 50, item = 'armour',
            male = { 15, 2 }, female = { 17, 2 },        -- wasabi_police_v2 tactical outfit, verified in game
        },
        heavy = {
            label = 'Grab heavy vest', busy = 'Equipping heavy vest…',
            done = "You've equipped a heavy vest.", icon = 'fa-solid fa-shield-halved',
            slot = 'vest', armour = 75, item = false,
            male = { 20, 0 }, female = { 20, 0 },        -- female TUNE
        },
        refvest = {
            label = 'Grab reflective vest', busy = 'Putting on reflective vest…',
            done = "You've put on a reflective vest.", icon = 'fa-solid fa-vest',
            slot = 'vest', armour = 0, item = false,
            male = { 21, 0 }, female = { 21, 0 },        -- female TUNE
        },
        helmet = {
            label = 'Grab bulletproof helmet', busy = 'Equipping bulletproof helmet…',
            done = "You've equipped a bulletproof helmet.", icon = 'fa-solid fa-hard-hat',
            slot = 'head', armour = 25, item = false,
            male = { 150, 0 }, female = { 149, 0 },
        },
        turnout = {
            label = 'Grab turnout coat', busy = 'Pulling on turnout gear…',
            done = "You've pulled on your turnout coat.", icon = 'fa-solid fa-fire-extinguisher',
            slot = 'torso', armour = 0, item = false,
            male = { 15, 2 }, female = { 17, 2 },        -- TUNE: placeholder, the LEO vest numbers on component 11
        },
        firehelmet = {
            label = 'Grab fire helmet', busy = 'Putting on fire helmet…',
            done = "You've put on a fire helmet.", icon = 'fa-solid fa-helmet-safety',
            slot = 'head', armour = 0, item = false,
            male = { 150, 0 }, female = { 149, 0 },      -- TUNE: placeholder, the LEO helmet numbers
        },
        medbag = {
            label = 'Grab a medical bag', busy = 'Lifting the medical bag out…',
            done = "You've taken a medical bag.", icon = 'fa-solid fa-briefcase-medical',
            slot = false, armour = 0, item = 'medbag', give = true,
            male = false, female = false,                -- item only: no clothing change
        },
    },
    -- Menu order (Gear above is a map, so the order lives here).
    GearOrder = { 'bproof', 'heavy', 'refvest', 'helmet', 'turnout', 'firehelmet', 'medbag' },

    -- The "put it back" option, one per slot in Gear.SLOTS.
    Slots = {
        vest = { label = 'Remove vest', busy = 'Taking off vest…', done = 'You removed your vest.', icon = 'fa-solid fa-vest' },
        torso = { label = 'Remove turnout coat', busy = 'Taking off turnout gear…', done = 'You took off your turnout coat.', icon = 'fa-solid fa-fire-extinguisher' },
        head = { label = 'Remove helmet', busy = 'Taking off helmet…', done = 'You removed your helmet.', icon = 'fa-solid fa-hard-hat' },
    },
    SlotOrder = { 'vest', 'torso', 'head' },

    Translation = {
        notifyTitle = 'Gear system',
        not_in_trunk = 'That is not in the trunk.',
        no_room = 'You have no room for that.',
        wrong_dept = "That is another department's gear.",
        no_job = 'Your job does not carry that gear.',
        failed = 'That did not work.',
        not_returned = 'It would not go back in the trunk.',
    },
}
