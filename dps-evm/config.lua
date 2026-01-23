Config = {}

-----------------------------------------------------------
-- [[ 1. CORE SETTINGS ]]
-----------------------------------------------------------
Config.Debug = true                   -- Keep TRUE while setting up. Set FALSE for production.
Config.CheckUpdates = true            -- Check for script updates on startup
Config.AutoConfigure = true           -- Auto-configure framework, zones, vehicles

-----------------------------------------------------------
-- [[ 2. FRAMEWORK & PERFORMANCE ]]
-----------------------------------------------------------
Config.AutoDetectFramework = true     -- Let script detect ESX/QBCore/QBox
Config.Framework = nil                -- Keep nil for auto-detect, or set 'esx'/'qbcore'/'qbox'/'standalone'

-- Performance: Job caching prevents SQL spam
Config.CacheJobInfo = true            -- Cache job info instead of checking DB every time
Config.JobCacheTimeout = 300000       -- 5 minutes cache duration (ms)

-----------------------------------------------------------
-- [[ 3. JOB ACCESS CONTROL ]]
-----------------------------------------------------------
Config.EnableJobRestrictions = true   -- Enable job-based zone restrictions
Config.EnableGradeRestrictions = true -- Enable grade/rank requirements
Config.DisableZoneRestrictions = false -- Set TRUE to bypass all zone checks (admin testing)

-- Job name mappings (add your custom job names here)
Config.JobMappings = {
    police = {'police', 'lspd', 'bcso', 'sheriff', 'sahp', 'saspr', 'statepolice', 'trooper'},
    fire = {'fire', 'lsfd', 'firefighter'},
    ambulance = {'ambulance', 'ems', 'medical'},
    mechanic = {'mechanic', 'lscustoms', 'bennys'}
}

-----------------------------------------------------------
-- [[ 4. ZONE CONFIGURATION ]]
-----------------------------------------------------------
Config.ManualZones = true             -- Use manual zone definitions below
Config.AutoDetectZones = false        -- Disable auto-zone detection when using manual

-- Manual modification zones with Grade 0 access (ALL ranks can use)
Config.ManualModificationZones = {
    -- Police Stations
    {
        name = "Mission Row PD - Garage",
        coords = vector3(454.6, -1017.4, 28.4),
        radius = 30.0,
        type = "police",
        requiredJob = "police",
        minGrade = 0,                 -- Grade 0 = Cadets/Officers can access
        jobLabel = "Police Officer"
    },
    {
        name = "Sandy Shores Sheriff - Parking",
        coords = vector3(1855.9, 3683.5, 33.7),
        radius = 20.0,
        type = "police",
        requiredJob = "police",
        minGrade = 0,
        jobLabel = "Sheriff Deputy"
    },
    {
        name = "Paleto Bay Sheriff - Garage",
        coords = vector3(-456.3, 6008.4, 31.3),
        radius = 20.0,
        type = "police",
        requiredJob = "police",
        minGrade = 0,
        jobLabel = "Sheriff Deputy"
    },
    {
        name = "Davis Sheriff Station - Lot",
        coords = vector3(379.9, -1600.5, 29.3),
        radius = 20.0,
        type = "police",
        requiredJob = "police",
        minGrade = 0,
        jobLabel = "Police Officer"
    },
    {
        name = "Vespucci PD - Garage",
        coords = vector3(-1088.6, -834.7, 37.7),
        radius = 20.0,
        type = "police",
        requiredJob = "police",
        minGrade = 0,
        jobLabel = "Police Officer"
    },

    -- Fire Stations
    {
        name = "Los Santos Fire Station 1",
        coords = vector3(1193.8, -1464.8, 34.9),
        radius = 20.0,
        type = "fire",
        requiredJob = "fire",
        minGrade = 0,
        jobLabel = "Firefighter"
    },
    {
        name = "Davis Fire Station",
        coords = vector3(213.7, -1644.2, 29.8),
        radius = 20.0,
        type = "fire",
        requiredJob = "fire",
        minGrade = 0,
        jobLabel = "Firefighter"
    },
    {
        name = "Paleto Bay Fire Station",
        coords = vector3(-367.2, 6123.4, 31.5),
        radius = 20.0,
        type = "fire",
        requiredJob = "fire",
        minGrade = 0,
        jobLabel = "Firefighter"
    },
    {
        name = "Sandy Shores Fire Station",
        coords = vector3(1691.5, 3581.2, 35.6),
        radius = 20.0,
        type = "fire",
        requiredJob = "fire",
        minGrade = 0,
        jobLabel = "Firefighter"
    },

    -- Medical/EMS
    {
        name = "Pillbox Hill Medical Center",
        coords = vector3(338.5, -580.3, 28.8),
        radius = 25.0,
        type = "medical",
        requiredJob = "ambulance",
        minGrade = 0,
        jobLabel = "EMS Personnel"
    },
    {
        name = "Sandy Shores Medical Center",
        coords = vector3(1835.2, 3678.9, 34.3),
        radius = 20.0,
        type = "medical",
        requiredJob = "ambulance",
        minGrade = 0,
        jobLabel = "EMS Personnel"
    },

    -- Custom MLO Examples (Gabz-style) - Uncomment and adjust coords as needed
    -- {
    --     name = "Gabz MRPD - Main Garage",
    --     coords = vector3(441.5, -981.0, 30.7),
    --     radius = 15.0,
    --     type = "police",
    --     requiredJob = "police",
    --     minGrade = 0,
    --     jobLabel = "Police Officer"
    -- },
    -- {
    --     name = "Gabz Pillbox - Ambulance Bay",
    --     coords = vector3(311.2, -595.5, 43.3),
    --     radius = 12.0,
    --     type = "medical",
    --     requiredJob = "ambulance",
    --     minGrade = 0,
    --     jobLabel = "EMS Personnel"
    -- },
}

-----------------------------------------------------------
-- [[ 5. VEHICLE DETECTION ]]
-----------------------------------------------------------
-- Auto-detect often fails on custom add-on vehicles. Use manual list.
Config.ManualVehicleDetection = true
Config.AutoDetectVehicles = false

-- List ALL your emergency vehicle spawn codes here
Config.ManualEmergencyVehicles = {
    -- GTA V Default Emergency Vehicles
    "police", "police2", "police3", "police4", "policeb", "policet",
    "sheriff", "sheriff2", "riot", "riot2",
    "fbi", "fbi2", "pranger", "lguard",
    "firetruk", "ambulance",
    "polmav", "predator",

    -- Common Custom Police Vehicles (add your server's vehicles)
    -- "nypd_explorer",
    -- "bcso_charger",
    -- "2020tahoe",
    -- "lapd_cvpi",
    -- "sahp_charger",
    -- "unmarked_charger",
    -- "slicktop_explorer",

    -- Common Custom Fire/EMS Vehicles
    -- "lafd_engine",
    -- "lafd_ladder",
    -- "ems_sprinter",
    -- "rescue_suburban",

    -- Helicopters (work if landed in zone)
    -- "as350",
    -- "polmav_fib",
    -- "medevac",
}

-- Auto-configured framework-specific settings
Config.FrameworkSettings = {}

-- Auto-configuration function for framework settings
function Config.AutoConfigureFramework()
    local detectedFramework = Config.DetectFramework()
    
    -- Default settings template
    local defaultSettings = {
        esx = {
            jobRestriction = true,
            allowedJobs = {'police', 'ambulance', 'fire'},
            useJobGrades = true,
            minGrade = 0,
            resourceName = 'es_extended'
        },
        qbcore = {
            jobRestriction = true,
            allowedJobs = {'police', 'ambulance', 'fire'},
            useJobGrades = true,
            minGrade = 0,
            resourceName = GetResourceState('qb-core') == 'started' and 'qb-core' or 'qbx_core'
        },
        qbox = {
            jobRestriction = true,
            allowedJobs = {'police', 'ambulance', 'fire'},
            useJobGrades = true,
            minGrade = 0,
            resourceName = 'qbox-core'
        },
        standalone = {
            jobRestriction = false,
            locationOnly = true
        }
    }
    
    -- Auto-configure based on detected framework (unless manual override)
    if not Config.ManualFramework then
        Config.FrameworkSettings = defaultSettings
        Config.Framework = detectedFramework
        if Config.Debug then
            print("^2[AUTO-CONFIG]:^0 Framework auto-configured as: " .. detectedFramework)
        end
    else
        Config.FrameworkSettings = defaultSettings
        if Config.Debug then
            print("^2[AUTO-CONFIG]:^0 Using manual framework configuration: " .. Config.Framework)
        end
    end
    
    -- Auto-configure job system
    if Config.EnableJobRestrictions and not Config.ManualJobSystem then
        Config.AutoConfigureJobSystem()
    end
end

-- Auto-configure job system based on framework
function Config.AutoConfigureJobSystem()
    local framework = Config.Framework
    
    -- Framework-specific database table detection
    Config.JobTables = {
        esx = {
            jobs = "jobs",
            job_grades = "job_grades",
            users = "users",
            userJobField = "job",
            userGradeField = "job_grade",
            identifierField = "identifier"
        },
        qbcore = {
            jobs = "jobs",
            players = "players", 
            userJobField = "job",
            userGradeField = "grade",
            identifierField = "citizenid",
            jobDataColumn = "job" -- JSON column in qbcore
        },
        qbox = {
            jobs = "jobs",
            players = "players",
            userJobField = "job", 
            userGradeField = "grade",
            identifierField = "citizenid"
        }
    }
    
    -- Auto-detect job names based on framework
    Config.JobMappings = {
        police = {"police", "lspd", "bcso", "sahp", "sheriff"},
        fire = {"fire", "lsfd", "firefighter"},
        ambulance = {"ambulance", "ems", "medical"}
    }
    
    if Config.Debug then
        print("^2[AUTO-CONFIG]:^0 Job system configured for " .. framework)
    end
end

-- Auto-configured modification zones
Config.ModificationZones = {}

-- Auto-configuration function for modification zones
function Config.AutoConfigureZones()
    -- Default zones with job restrictions (auto-configured based on framework)
    local defaultZones = {
        -- Police Stations (Police job, grade 4+) - Repositioned to parking areas with car-sized zones
        {
            name = "Mission Row Police Department - Parking Garage",
            coords = vector3(454.2, -1025.1, 28.4),
            radius = 4.0,
            type = "police",
            requiredJob = "police",
            minGrade = 4,
            jobLabel = "Police Officer"
        },
        {
            name = "Davis Sheriff Station - Parking Lot",
            coords = vector3(379.9, -1600.5, 29.3),
            radius = 4.0,
            type = "police",
            requiredJob = "police",
            minGrade = 4,
            jobLabel = "Police Officer"
        },
        {
            name = "Sandy Shores Sheriff Office - Garage",
            coords = vector3(1862.1, 3673.8, 33.7),
            radius = 4.0,
            type = "police",
            requiredJob = "police",
            minGrade = 4,
            jobLabel = "Police Officer"
        },
        {
            name = "Paleto Bay Sheriff Office - Parking",
            coords = vector3(-456.3, 6008.4, 31.3),
            radius = 4.0,
            type = "police",
            requiredJob = "police",
            minGrade = 4,
            jobLabel = "Police Officer"
        },
        {
            name = "Vespucci Police Station - Garage",
            coords = vector3(-1088.6, -834.7, 37.7),
            radius = 4.0,
            type = "police",
            requiredJob = "police",
            minGrade = 4,
            jobLabel = "Police Officer"
        },
        -- Fire Stations (Fire job, grade 4+)
        {
            name = "Los Santos Fire Station 1 - Garage",
            coords = vector3(1193.8, -1464.8, 34.9),
            radius = 4.0,
            type = "fire",
            requiredJob = "fire",
            minGrade = 4,
            jobLabel = "Firefighter"
        },
        {
            name = "Davis Fire Station - Garage",
            coords = vector3(213.7, -1644.2, 29.8),
            radius = 4.0,
            type = "fire",
            requiredJob = "fire",
            minGrade = 4,
            jobLabel = "Firefighter"
        },
        {
            name = "Paleto Bay Fire Station - Garage",
            coords = vector3(-367.2, 6123.4, 31.5),
            radius = 4.0,
            type = "fire",
            requiredJob = "fire",
            minGrade = 4,
            jobLabel = "Firefighter"
        },
        {
            name = "Sandy Shores Fire Station - Garage",
            coords = vector3(1691.5, 3581.2, 35.6),
            radius = 4.0,
            type = "fire",
            requiredJob = "fire",
            minGrade = 4,
            jobLabel = "Firefighter"
        },
        -- Hospitals (Ambulance job, grade 4+)
        {
            name = "Pillbox Hill Medical Center - Parking Garage",
            coords = vector3(338.5, -580.3, 28.8),
            radius = 4.0,
            type = "medical",
            requiredJob = "ambulance",
            minGrade = 4,
            jobLabel = "EMS Personnel"
        },
        {
            name = "Sandy Shores Medical Center - Parking",
            coords = vector3(1835.2, 3678.9, 34.3),
            radius = 4.0,
            type = "medical",
            requiredJob = "ambulance",
            minGrade = 4,
            jobLabel = "EMS Personnel"
        }
    }
    
    if Config.AutoDetectZones and not Config.ManualZones then
        Config.ModificationZones = defaultZones
        if Config.Debug then
            print("^2[AUTO-CONFIG]:^0 Configured " .. #defaultZones .. " modification zones")
        end
    elseif Config.ManualZones then
        if Config.Debug then
            print("^2[AUTO-CONFIG]:^0 Using manual zone configuration")
        end
    end
end


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

-- Other display settings
Config.ShowBlips = false        -- Show modification zone blips on map
Config.ShowMarkers = false      -- Show ground markers at zones
Config.EmergencyVehiclesOnly = true  -- Only allow emergency vehicles (set FALSE for testing)

-----------------------------------------------------------
-- THIRD-PARTY SCRIPT COMPATIBILITY (v2.1.2+)
-- Settings for integration with other popular scripts
-----------------------------------------------------------
Config.Compatibility = {
    -- jg-mechanic / jg-advancedgarages
    ['jg-scripts'] = {
        enabled = true,                     -- Enable jg-scripts compatibility
        deferToMechanicForRepairs = true,   -- Don't charge for repairs (let jg-mechanic handle economy)
        respectGarageLivery = true,         -- Don't auto-apply livery if garage just set it
        garageSpawnGracePeriod = 5000       -- ms to wait after spawn before auto-applying livery
    },

    -- qb-mechanicjob / qb-garages
    ['qb-scripts'] = {
        enabled = false,
        deferToMechanicForRepairs = true,
        respectGarageLivery = true
    },

    -- Generic compatibility for other scripts
    ['generic'] = {
        disableRepairCostsIfMechanicJob = true,  -- Free repairs if player is mechanic
        checkOwnedVehicleBeforeLivery = false    -- Only auto-apply to owned vehicles
    }
}

-----------------------------------------------------------
-- DYNAMIC MARKER SYSTEM (v2.1.1+)
-- Markers with distance-based opacity for premium feel
-----------------------------------------------------------
Config.DynamicMarkers = {
    enabled = false,                   -- Enable dynamic markers (overrides ShowMarkers)
    markerType = 1,                    -- Marker type (1 = cylinder, 27 = arrow)
    size = vector3(3.0, 3.0, 1.0),     -- Marker size
    -- Uses Config.Constants.MARKER_FADE_START and MARKER_FADE_END if available
    fadeStartDistance = 30.0,          -- Distance where marker starts appearing
    fadeEndDistance = 5.0,             -- Distance where marker is fully visible
    bobUpDown = false,                 -- Marker bobs up and down
    rotate = false,                    -- Marker rotates
    colors = {                         -- Zone-specific colors (RGBA)
        police = {0, 100, 255, 200},   -- Blue
        fire = {255, 50, 0, 200},      -- Red
        medical = {50, 255, 50, 200},  -- Green
        default = {255, 255, 255, 200} -- White
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

    -- Scaling
    scaleCostByDamage = true,          -- More damage = higher cost
    maxCostMultiplier = 2.5,           -- Cap at 2.5x base cost

    -- Job-based pricing
    freeForJobs = {
        'mechanic',                    -- Mechanics repair free
        'lscustoms'
    },
    discountJobs = {
        {job = 'police', discount = 0.25},    -- 25% off for police
        {job = 'ambulance', discount = 0.25}, -- 25% off for EMS
        {job = 'fire', discount = 0.25}       -- 25% off for fire
    }
}

-----------------------------------------------------------
-- JOB-SPECIFIC DEFAULTS (v2.1.1+)
-- Zone-aware menu defaults for better UX
-----------------------------------------------------------
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
    medical = {
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
    allowedJobs = {                    -- Jobs that can use field repair
        'police', 'ambulance', 'fire', 'mechanic', 'lspd', 'bcso', 'sahp', 'ems', 'lsfd'
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

-- Validate preset/livery name
function Config.ValidateName(name)
    if not name or type(name) ~= "string" then
        return false, "Invalid name format"
    end

    local trimmed = name:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return false, "Name cannot be empty"
    end

    if #trimmed < Config.InputValidation.minNameLength then
        return false, "Name too short"
    end

    if #trimmed > Config.InputValidation.maxNameLength then
        return false, "Name too long (max " .. Config.InputValidation.maxNameLength .. " characters)"
    end

    if Config.InputValidation.blockSpecialChars then
        if not trimmed:match(Config.InputValidation.allowedCharacters) then
            return false, "Name contains invalid characters"
        end
    end

    return true, trimmed
end

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

-- Framework Detection
function Config.DetectFramework()
    if Config.AutoDetectFramework and not Config.ManualFramework then
        if GetResourceState('es_extended') == 'started' then
            return 'esx'
        -- Check for QBox FIRST (it uses qbx_core but is different from QBX/QB-Core)
        elseif GetResourceState('qbx_core') == 'started' then
            -- QBox uses qbx_core resource name
            return 'qbox'
        elseif GetResourceState('qb-core') == 'started' then
            -- Legacy QB-Core
            return 'qbcore'
        else
            return 'standalone'
        end
    else
        return Config.Framework -- Use manual setting
    end
end

-- Job information cache using ox_lib cache system
Config.JobCache = {}
Config.LastCacheUpdate = 0

-- Advanced job permission checking with caching and database fallback
function Config.HasJobPermission(playerId, requiredJob, minGrade, framework, frameworkObject)
    if not Config.EnableJobRestrictions then
        return true
    end
    
    local currentFramework = framework or Config.Framework
    
    -- Check cache first (using ox_lib cache if available)
    local cacheKey = playerId .. ":" .. (requiredJob or "any")
    local cachedResult = Config.GetCachedJobInfo(cacheKey)
    
    if cachedResult and cachedResult.timestamp > (GetGameTimer() - Config.JobCacheTimeout) then
        return Config.ValidateJobAccess(cachedResult.jobData, requiredJob, minGrade)
    end
    
    -- Try framework method first
    local jobData = Config.GetJobFromFramework(playerId, currentFramework, frameworkObject)
    
    if not jobData then
        -- Fallback to database polling
        jobData = Config.GetJobFromDatabase(playerId, currentFramework)
    end
    
    if jobData then
        -- Cache the result
        Config.CacheJobInfo(cacheKey, jobData)
        return Config.ValidateJobAccess(jobData, requiredJob, minGrade)
    end
    
    return false
end

-- Get job info from framework objects (real-time)
function Config.GetJobFromFramework(playerId, framework, frameworkObject)
    if framework == 'esx' and frameworkObject then
        local xPlayer = frameworkObject.GetPlayerFromId(playerId)
        if xPlayer then
            local job = xPlayer.getJob()
            return {
                name = job.name,
                grade = job.grade,
                label = job.label
            }
        end
    elseif framework == 'qbcore' and frameworkObject then
        local Player = frameworkObject.Functions.GetPlayer(playerId)
        if Player then
            local job = Player.PlayerData.job
            return {
                name = job.name,
                grade = job.grade and job.grade.level or job.grade,
                label = job.label
            }
        end
    elseif framework == 'qbox' then
        -- QBox uses qbx_core resource with GetPlayer export
        local Player = exports.qbx_core:GetPlayer(playerId)
        if Player then
            local job = Player.PlayerData.job
            return {
                name = job.name,
                grade = job.grade,
                label = job.label
            }
        end
    end
    
    return nil
end

-- Validate job access against requirements
function Config.ValidateJobAccess(jobData, requiredJob, minGrade)
    if not jobData or not requiredJob then
        return false
    end
    
    -- Check if job matches (including mapped job names)
    local jobMatches = false
    if Config.JobMappings[requiredJob] then
        for _, jobName in ipairs(Config.JobMappings[requiredJob]) do
            if jobData.name == jobName then
                jobMatches = true
                break
            end
        end
    else
        jobMatches = jobData.name == requiredJob
    end
    
    if not jobMatches then
        return false
    end
    
    -- Check grade requirement if enabled
    if Config.EnableGradeRestrictions and minGrade then
        return jobData.grade >= minGrade
    end
    
    return true
end

-- Cache management using ox_lib or fallback
function Config.GetCachedJobInfo(key)
    if lib and lib.cache then
        return lib.cache.get('job_' .. key)
    else
        return Config.JobCache[key]
    end
end

function Config.CacheJobInfo(key, jobData)
    local cacheData = {
        jobData = jobData,
        timestamp = GetGameTimer()
    }
    
    if lib and lib.cache then
        lib.cache.set('job_' .. key, cacheData, Config.JobCacheTimeout)
    else
        Config.JobCache[key] = cacheData
    end
end

-- Legacy permission function for backwards compatibility
function Config.HasPermission(playerId, framework, frameworkObject)
    local settings = Config.FrameworkSettings[framework or Config.Framework]
    
    if not settings or not settings.jobRestriction then
        return true
    end
    
    -- Use new job permission system with default job requirements
    for _, allowedJob in ipairs(settings.allowedJobs) do
        if Config.HasJobPermission(playerId, allowedJob, settings.minGrade, framework, frameworkObject) then
            return true
        end
    end
    
    return false
end

-- Enhanced zone checking with job-specific requirements
function Config.IsInModificationZone(playerCoords, playerId, framework, frameworkObject)
    -- Bypass zone restrictions entirely if disabled (admin mode)
    if Config.DisableZoneRestrictions then
        return true, {
            allowed = true,
            message = "Zone restrictions disabled - access granted anywhere",
            zone = { name = "Anywhere", type = "admin" }
        }
    end

    for _, zone in ipairs(Config.ModificationZones) do
        local distance = #(playerCoords - zone.coords)
        if distance <= zone.radius then
            -- Check job-specific permissions for this zone
            if playerId and Config.EnableJobRestrictions then
                if zone.requiredJob then
                    local hasAccess = Config.HasJobPermission(
                        playerId, 
                        zone.requiredJob, 
                        zone.minGrade, 
                        framework, 
                        frameworkObject
                    )
                    
                    if not hasAccess then
                        return false, {
                            allowed = false,
                            message = string.format("Access denied. Requires %s (Grade %d+)", 
                                zone.jobLabel or zone.requiredJob, zone.minGrade or 0),
                            zone = zone,
                            requiredJob = zone.requiredJob,
                            minGrade = zone.minGrade
                        }
                    end
                else
                    -- Fallback to legacy permission system
                    if framework and not Config.HasPermission(playerId, framework, frameworkObject) then
                        return false, {
                            allowed = false,
                            message = "You don't have permission to use vehicle modifications",
                            zone = zone
                        }
                    end
                end
            end

            return true, {
                allowed = true,
                message = "Access granted at " .. zone.name,
                zone = zone
            }
        end
    end

    return false, {
        allowed = false,
        message = "You must be at a designated modification garage",
        zone = nil
    }
end

-- Database polling system for job information (async with ox_lib)
function Config.GetJobFromDatabase(playerId, framework)
    if not Config.AutoDetectJobTables or not Config.JobTables[framework] then
        return nil
    end
    
    local jobTables = Config.JobTables[framework]
    local identifier = Config.GetPlayerIdentifier(playerId)
    
    if not identifier then
        return nil
    end
    
    -- Use oxmysql for async database queries
    local ox_mysql = exports['oxmysql']
    if not ox_mysql then
        if Config.Debug then
            print("^3[AUTO-CONFIG]:^0 Warning: oxmysql not available for database job polling")
        end
        return nil
    end
    
    local jobData = nil
    local completed = false
    
    if framework == 'esx' then
        -- ESX job query
        local query = string.format(
            "SELECT u.job, u.job_grade, j.label FROM %s u JOIN %s j ON u.job = j.name WHERE u.%s = ?",
            jobTables.users, jobTables.jobs, jobTables.identifierField
        )
        
        ox_mysql:execute(query, {identifier}, function(result)
            if result and result[1] then
                jobData = {
                    name = result[1].job,
                    grade = result[1].job_grade,
                    label = result[1].label
                }
            end
            completed = true
        end)
        
    elseif framework == 'qbcore' then
        -- QBCore job query (handles JSON job column)
        local query = string.format(
            "SELECT %s FROM %s WHERE %s = ?",
            jobTables.jobDataColumn, jobTables.players, jobTables.identifierField
        )
        
        ox_mysql:execute(query, {identifier}, function(result)
            if result and result[1] and result[1][jobTables.jobDataColumn] then
                local jobJson = json.decode(result[1][jobTables.jobDataColumn])
                if jobJson then
                    jobData = {
                        name = jobJson.name,
                        grade = jobJson.grade and jobJson.grade.level or jobJson.grade,
                        label = jobJson.label
                    }
                end
            end
            completed = true
        end)
        
    elseif framework == 'qbox' then
        -- QBox job query
        local query = string.format(
            "SELECT %s, %s FROM %s WHERE %s = ?",
            jobTables.userJobField, jobTables.userGradeField, jobTables.players, jobTables.identifierField
        )
        
        ox_mysql:execute(query, {identifier}, function(result)
            if result and result[1] then
                jobData = {
                    name = result[1][jobTables.userJobField],
                    grade = result[1][jobTables.userGradeField],
                    label = result[1][jobTables.userJobField] -- Fallback
                }
            end
            completed = true
        end)
    end
    
    -- Wait for async query to complete (with timeout)
    local timeout = 0
    while not completed and timeout < 50 do -- 500ms max wait
        Citizen.Wait(10)
        timeout = timeout + 1
    end
    
    return jobData
end

-- Get player identifier based on framework
function Config.GetPlayerIdentifier(playerId)
    local framework = Config.Framework
    
    if framework == 'esx' then
        -- ESX uses steam identifier
        for _, id in ipairs(GetPlayerIdentifiers(playerId)) do
            if string.find(id, "steam:") then
                return id
            end
        end
    elseif framework == 'qbcore' or framework == 'qbox' then
        -- QBCore/QBox uses citizenid (license identifier)
        for _, id in ipairs(GetPlayerIdentifiers(playerId)) do
            if string.find(id, "license:") then
                return string.gsub(id, "license:", "")
            end
        end
    end
    
    return nil
end

-- Clean up expired cache entries
function Config.CleanJobCache()
    if not lib or not lib.cache then
        local currentTime = GetGameTimer()
        for key, data in pairs(Config.JobCache) do
            if data.timestamp < (currentTime - Config.JobCacheTimeout) then
                Config.JobCache[key] = nil
            end
        end
    end
end

-- Check if vehicle is an emergency vehicle
function Config.IsEmergencyVehicle(vehicle)
    return IsVehicleEmergency(vehicle)
end

-- Auto-detect emergency vehicles or use manual list
function IsVehicleEmergency(vehicle)
    if Config.ManualVehicleDetection then
        -- Use manual vehicle list (defined at top of config)
        for _, model in ipairs(Config.ManualEmergencyVehicles) do
            if IsVehicleModel(vehicle, GetHashKey(model)) then
                return true
            end
        end
        return false
    else
        -- Auto-detection mode
        -- Check emergency vehicle class using named constant
        local emergencyClass = Config.Constants and Config.Constants.VEHICLE_CLASS_EMERGENCY or 18
        if GetVehicleClass(vehicle) == emergencyClass then
            return true
        end

        -- Fallback: Check vehicles from manual list even in auto mode
        for _, model in ipairs(Config.ManualEmergencyVehicles) do
            if IsVehicleModel(vehicle, GetHashKey(model)) then
                return true
            end
        end

        return false
    end
end

-- Initialize all auto-configurations
function Config.Initialize()
    if Config.AutoConfigure then
        Config.AutoConfigureFramework()
        Config.AutoConfigureZones()
        
        -- Use manual zones if specified
        if Config.ManualZones and Config.ManualModificationZones and #Config.ManualModificationZones > 0 then
            Config.ModificationZones = Config.ManualModificationZones
        end
        
        -- Validate configuration
        Config.ValidateConfiguration()
        
        if Config.Debug then
            print("^2[AUTO-CONFIG]:^0 Emergency Vehicle Menu auto-configuration completed")
            print("^2[AUTO-CONFIG]:^0 Framework: " .. (Config.Framework or "unknown"))
            print("^2[AUTO-CONFIG]:^0 Zones: " .. #Config.ModificationZones)
            print("^2[AUTO-CONFIG]:^0 Vehicle Detection: " .. (Config.ManualVehicleDetection and "Manual" or "Auto"))
        end
    else
        if Config.Debug then
            print("^3[AUTO-CONFIG]:^0 Auto-configuration disabled, using manual settings")
        end
    end
end

-- Validate configuration and provide fallbacks
function Config.ValidateConfiguration()
    -- Ensure we have modification zones
    if not Config.ModificationZones or #Config.ModificationZones == 0 then
        print("^3[AUTO-CONFIG]:^0 Warning: No modification zones configured! Using default zone.")
        Config.ModificationZones = {{
            name = "Default Emergency Services Garage",
            coords = vector3(454.2, -1025.1, 28.4), -- Mission Row PD Parking Garage
            radius = 4.0,
            type = "police"
        }}
    end
    
    -- Ensure framework settings exist
    if not Config.FrameworkSettings or not Config.FrameworkSettings[Config.Framework] then
        print("^3[AUTO-CONFIG]:^0 Warning: No framework settings for " .. Config.Framework .. ". Using defaults.")
        if not Config.FrameworkSettings then Config.FrameworkSettings = {} end
        Config.FrameworkSettings[Config.Framework] = {
            jobRestriction = false,
            locationOnly = true
        }
    end
    
    -- Ensure enabled modifications are configured
    if not Config.EnabledModifications then
        print("^3[AUTO-CONFIG]:^0 Warning: No modifications enabled! Enabling defaults.")
        Config.EnabledModifications = {
            Liveries = true,
            CustomLiveries = true,
            Performance = true,
            Appearance = true,
            Neon = false,
            Extras = true,
            Doors = true
        }
    end
    
    -- Ensure custom liveries table exists
    if not Config.CustomLiveries then
        Config.CustomLiveries = {}
    end
end
