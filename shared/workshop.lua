--[[
    dps-fleet shared/workshop.lua
    EVM workshop access. Pure data/logic; shared by client, server and tests.
]]
Workshop = Workshop or {}
Access = Access or {}

local jobSetCache, jobSetSource = nil, nil
local function jobSet(cfg)
    if jobSetCache and jobSetSource == cfg.JobMappings then return jobSetCache end
    local set = {}
    for _, names in pairs(cfg.JobMappings or {}) do
        for _, n in ipairs(names) do set[n] = true end
    end
    jobSetCache, jobSetSource = set, cfg.JobMappings
    return set
end

---The access rule itself, over an already-built job set. The server derives that
---set from qbx_core at start (Config.AutoJobs), so the rule must not read config.
---@param jobName string|nil
---@param isAdmin boolean
---@param set table<string, boolean> job names allowed to use the workshop
---@param restrictionsOn boolean false = the workshop is open to everyone
---@return boolean ok, string|nil reason
function Access.canWorkshopSet(jobName, isAdmin, set, restrictionsOn)
    if restrictionsOn == false then return true end
    if not jobName then return false, 'Your character is not loaded yet.' end
    if isAdmin then return true end
    if set and set[jobName] then return true end
    return false, 'Your job does not permit vehicle modifications.'
end

---Config.JobMappings form of the rule above (Config.AutoJobs = false, and the client).
---@param jobName string|nil
---@param isAdmin boolean
---@param cfg table
---@return boolean ok, string|nil reason
function Access.canWorkshop(jobName, isAdmin, cfg)
    return Access.canWorkshopSet(jobName, isAdmin, jobSet(cfg), cfg.EnableJobRestrictions ~= false)
end

-----------------------------------------------------------------------
-- Workshop vocabulary and pricing (Task 3, DPS 2026-09-27). Pure
-- data/logic ported from legacy/evm_config.lua and evm_client.lua;
-- no natives, tables built once at load.
-----------------------------------------------------------------------

-- Ordered menu sections. enabledKey names the Config.EnabledModifications
-- flag that gates the section (checked by Workshop.enabledSections below).
-- 'sirens' added 2026-09-27 (controller ruling): a later task builds the
-- siren sheet; the section slot and its config flag land now.
Workshop.SECTIONS = {
    { id = 'liveries', label = 'Liveries', icon = 'fa-paint-roller', enabledKey = 'Liveries' },
    { id = 'customliveries', label = 'Custom liveries', icon = 'fa-file-image', enabledKey = 'CustomLiveries' },
    { id = 'extras', label = 'Extras', icon = 'fa-lightbulb', enabledKey = 'Extras' },
    { id = 'performance', label = 'Performance', icon = 'fa-gauge-high', enabledKey = 'Performance' },
    { id = 'colours', label = 'Colours', icon = 'fa-palette', enabledKey = 'Appearance' },
    { id = 'wheels', label = 'Wheels', icon = 'fa-circle-notch', enabledKey = 'Appearance' },
    { id = 'tint', label = 'Window tint', icon = 'fa-window-maximize', enabledKey = 'Appearance' },
    { id = 'neon', label = 'Neon', icon = 'fa-bolt', enabledKey = 'Neon' },
    { id = 'doors', label = 'Doors', icon = 'fa-door-open', enabledKey = 'Doors' },
    { id = 'windows', label = 'Windows', icon = 'fa-window-restore', enabledKey = 'Doors' },
    { id = 'seats', label = 'Seats', icon = 'fa-chair', enabledKey = 'Doors' },
    { id = 'presets', label = 'Presets', icon = 'fa-floppy-disk', enabledKey = 'Presets' },
    { id = 'sirens', label = 'Sirens', icon = 'fa-bullhorn', enabledKey = 'Sirens' },
    { id = 'repair', label = 'Repair', icon = 'fa-screwdriver-wrench', enabledKey = 'Repair' },
}

---Filters Workshop.SECTIONS by cfg.EnabledModifications[enabledKey]. The
---neon section is special: it shows when Neon is globally enabled, OR when
---the vehicle is undercover and listed in cfg.UndercoverNeon.allowedVehicles
---while that table is enabled (selective neon for unmarked units).
---@param cfg table
---@param model string|nil
---@param isUndercover boolean|nil
---@return table
function Workshop.enabledSections(cfg, model, isUndercover)
    local mods = cfg and cfg.EnabledModifications or {}
    local out = {}
    for _, section in ipairs(Workshop.SECTIONS) do
        if section.id == 'neon' then
            local show = mods.Neon or false
            if not show and isUndercover then
                local uc = cfg.UndercoverNeon
                if uc and uc.enabled then
                    for _, allowed in ipairs(uc.allowedVehicles or {}) do
                        if allowed == model then show = true; break end
                    end
                end
            end
            if show then out[#out + 1] = section end
        elseif mods[section.enabledKey] then
            out[#out + 1] = section
        end
    end
    return out
end

-- Vehicle mod slot indices (SetVehicleMod class ids) and their menu labels.
Workshop.PERF_SLOTS = { {11,'Engine'}, {12,'Brakes'}, {13,'Transmission'}, {15,'Suspension'}, {16,'Armour'}, {18,'Turbo',toggle=true} }

Workshop.WHEEL_TYPES = { [0]='Sport',[1]='Muscle',[2]='Lowrider',[3]='SUV',[4]='Offroad',[5]='Tuner',[6]='Bike',[7]='High End',[8]='Benny\'s Original',[9]='Benny\'s Bespoke',[10]='Open Wheel',[11]='Street',[12]='Track' }

Workshop.TINTS = { [0]='None',[1]='Pure black',[2]='Dark smoke',[3]='Light smoke',[4]='Stock',[5]='Limo',[6]='Green' }

-- GTA V vehicle colour index -> name, indices 0-160. legacy/evm_client.lua's
-- OpenColorsMenu only carried a 13-colour subset; completed here from the
-- standard GTA V vehicle colour list.
Workshop.COLOURS = {
    [0] = 'Metallic Black',
    [1] = 'Metallic Graphite Black',
    [2] = 'Metallic Black Steel',
    [3] = 'Metallic Dark Silver',
    [4] = 'Metallic Silver',
    [5] = 'Metallic Blue Silver',
    [6] = 'Metallic Steel Gray',
    [7] = 'Metallic Shadow Silver',
    [8] = 'Metallic Stone Silver',
    [9] = 'Metallic Midnight Silver',
    [10] = 'Metallic Gun Metal',
    [11] = 'Metallic Anthracite Grey',
    [12] = 'Matte Black',
    [13] = 'Matte Gray',
    [14] = 'Matte Light Grey',
    [15] = 'Util Black',
    [16] = 'Util Black Poly',
    [17] = 'Util Dark silver',
    [18] = 'Util Silver',
    [19] = 'Util Gun Metal',
    [20] = 'Util Shadow Silver',
    [21] = 'Worn Black',
    [22] = 'Worn Graphite',
    [23] = 'Worn Silver Grey',
    [24] = 'Worn Silver',
    [25] = 'Worn Blue Silver',
    [26] = 'Worn Shadow Silver',
    [27] = 'Metallic Red',
    [28] = 'Metallic Torino Red',
    [29] = 'Metallic Formula Red',
    [30] = 'Metallic Blaze Red',
    [31] = 'Metallic Graceful Red',
    [32] = 'Metallic Garnet Red',
    [33] = 'Metallic Desert Red',
    [34] = 'Metallic Cabernet Red',
    [35] = 'Metallic Candy Red',
    [36] = 'Metallic Sunrise Orange',
    [37] = 'Metallic Classic Gold',
    [38] = 'Metallic Orange',
    [39] = 'Matte Red',
    [40] = 'Matte Dark Red',
    [41] = 'Matte Orange',
    [42] = 'Matte Yellow',
    [43] = 'Util Red',
    [44] = 'Util Bright Red',
    [45] = 'Util Garnet Red',
    [46] = 'Worn Red',
    [47] = 'Worn Golden Red',
    [48] = 'Worn Dark Red',
    [49] = 'Metallic Dark Green',
    [50] = 'Metallic Racing Green',
    [51] = 'Metallic Sea Green',
    [52] = 'Metallic Olive Green',
    [53] = 'Metallic Green',
    [54] = 'Metallic Gasoline Blue Green',
    [55] = 'Matte Lime Green',
    [56] = 'Util Dark Green',
    [57] = 'Util Green',
    [58] = 'Worn Dark Green',
    [59] = 'Worn Green',
    [60] = 'Worn Sea Wash',
    [61] = 'Metallic Midnight Blue',
    [62] = 'Metallic Dark Blue',
    [63] = 'Metallic Saxony Blue',
    [64] = 'Metallic Blue',
    [65] = 'Metallic Mariner Blue',
    [66] = 'Metallic Harbor Blue',
    [67] = 'Metallic Diamond Blue',
    [68] = 'Metallic Surf Blue',
    [69] = 'Metallic Nautical Blue',
    [70] = 'Metallic Bright Blue',
    [71] = 'Metallic Purple Blue',
    [72] = 'Metallic Spinnaker Blue',
    [73] = 'Metallic Ultra Blue',
    [74] = 'Metallic Bright Blue',
    [75] = 'Util Dark Blue',
    [76] = 'Util Midnight Blue',
    [77] = 'Util Blue',
    [78] = 'Util Sea Foam Blue',
    [79] = 'Util Lightning blue',
    [80] = 'Util Maui Blue Poly',
    [81] = 'Util Bright Blue',
    [82] = 'Matte Dark Blue',
    [83] = 'Matte Blue',
    [84] = 'Matte Midnight Blue',
    [85] = 'Worn Dark blue',
    [86] = 'Worn Blue',
    [87] = 'Worn Light blue',
    [88] = 'Metallic Taxi Yellow',
    [89] = 'Metallic Race Yellow',
    [90] = 'Metallic Bronze',
    [91] = 'Metallic Yellow Bird',
    [92] = 'Metallic Lime',
    [93] = 'Metallic Champagne',
    [94] = 'Metallic Pueblo Beige',
    [95] = 'Metallic Dark Ivory',
    [96] = 'Metallic Choco Brown',
    [97] = 'Metallic Golden Brown',
    [98] = 'Metallic Light Brown',
    [99] = 'Metallic Straw Beige',
    [100] = 'Metallic Moss Brown',
    [101] = 'Metallic Biston Brown',
    [102] = 'Metallic Beechwood',
    [103] = 'Metallic Dark Beechwood',
    [104] = 'Metallic Choco Orange',
    [105] = 'Metallic Beach Sand',
    [106] = 'Metallic Sun Bleeched Sand',
    [107] = 'Metallic Cream',
    [108] = 'Util Brown',
    [109] = 'Util Medium Brown',
    [110] = 'Util Light Brown',
    [111] = 'Metallic White',
    [112] = 'Metallic Frost White',
    [113] = 'Worn Honey Beige',
    [114] = 'Worn Brown',
    [115] = 'Worn Dark Brown',
    [116] = 'Worn straw beige',
    [117] = 'Brushed Steel',
    [118] = 'Brushed Black steel',
    [119] = 'Brushed Aluminium',
    [120] = 'Chrome',
    [121] = 'Worn Off White',
    [122] = 'Util Off White',
    [123] = 'Worn Orange',
    [124] = 'Worn Light Orange',
    [125] = 'Metallic Securicor Green',
    [126] = 'Worn Taxi Yellow',
    [127] = 'police car blue',
    [128] = 'Matte Green',
    [129] = 'Matte Brown',
    [130] = 'Worn Orange',
    [131] = 'Matte White',
    [132] = 'Worn White',
    [133] = 'Worn Olive Army Green',
    [134] = 'Pure White',
    [135] = 'Hot Pink',
    [136] = 'Salmon pink',
    [137] = 'Metallic Vermillion Pink',
    [138] = 'Orange',
    [139] = 'Green',
    [140] = 'Blue',
    [141] = 'Mettalic Black Blue',
    [142] = 'Metallic Black Purple',
    [143] = 'Metallic Black Red',
    [144] = 'hunter green',
    [145] = 'Metallic Purple',
    [146] = 'Metaillic V Dark Blue',
    [147] = 'MODSHOP BLACK1',
    [148] = 'Matte Purple',
    [149] = 'Matte Dark Purple',
    [150] = 'Metallic Lava Red',
    [151] = 'Matte Forest Green',
    [152] = 'Matte Olive Drab',
    [153] = 'Matte Desert Brown',
    [154] = 'Matte Desert Tan',
    [155] = 'Matte Foilage Green',
    [156] = 'DEFAULT ALLOY COLOR',
    [157] = 'Epsilon Blue',
    [158] = 'Pure Gold',
    [159] = 'Brushed Gold',
    [160] = 'Green',
}

-- Same indices as Workshop.COLOURS, for swatches (a later panel task draws
-- them). GTA V doesn't publish exact colour-picker RGB values; these are
-- approximations for swatches only.
Workshop.COLOUR_HEX = {
    [0] = '#0a0a0a',
    [1] = '#1c1c1c',
    [2] = '#2b2b2f',
    [3] = '#4d4d4d',
    [4] = '#8c8c8c',
    [5] = '#7c8a99',
    [6] = '#6e6e6e',
    [7] = '#5a5a5a',
    [8] = '#9a9a92',
    [9] = '#3a3a3f',
    [10] = '#4b4b4d',
    [11] = '#3f3f3f',
    [12] = '#101010',
    [13] = '#6b6b6b',
    [14] = '#a3a3a3',
    [15] = '#0d0d0d',
    [16] = '#151515',
    [17] = '#595959',
    [18] = '#b0b0b0',
    [19] = '#4a4a4a',
    [20] = '#666666',
    [21] = '#202020',
    [22] = '#3a3a3a',
    [23] = '#8f8f8f',
    [24] = '#a8a8a8',
    [25] = '#8296a3',
    [26] = '#707070',
    [27] = '#8a0b0b',
    [28] = '#7d1414',
    [29] = '#b30000',
    [30] = '#cc1c1c',
    [31] = '#a52a2a',
    [32] = '#6e0f1a',
    [33] = '#b5462d',
    [34] = '#5c0a1e',
    [35] = '#d90429',
    [36] = '#e8590c',
    [37] = '#c9a227',
    [38] = '#e2711d',
    [39] = '#9e1b1b',
    [40] = '#6b0f0f',
    [41] = '#d9660b',
    [42] = '#d9c400',
    [43] = '#a30000',
    [44] = '#e60000',
    [45] = '#7a1020',
    [46] = '#8f2a2a',
    [47] = '#a5613a',
    [48] = '#5a1414',
    [49] = '#1b3d1f',
    [50] = '#0c4a1e',
    [51] = '#2e8b6f',
    [52] = '#4c5c2a',
    [53] = '#1f7a3d',
    [54] = '#1f7a6d',
    [55] = '#7ac900',
    [56] = '#234d24',
    [57] = '#2f7a2f',
    [58] = '#33502f',
    [59] = '#4d7a4d',
    [60] = '#5c8a82',
    [61] = '#131a4d',
    [62] = '#1a2f66',
    [63] = '#2d4f8f',
    [64] = '#1f5fbf',
    [65] = '#2a6ea3',
    [66] = '#35729e',
    [67] = '#3d8fc9',
    [68] = '#3daed9',
    [69] = '#1f4e8f',
    [70] = '#1e90ff',
    [71] = '#4b3d99',
    [72] = '#274b8f',
    [73] = '#0f4fd9',
    [74] = '#1e90ff',
    [75] = '#17284d',
    [76] = '#10173d',
    [77] = '#274d99',
    [78] = '#4fa8a3',
    [79] = '#2e8fd9',
    [80] = '#2ba8c9',
    [81] = '#2f8fe6',
    [82] = '#1a2f5c',
    [83] = '#2b5ea3',
    [84] = '#131f42',
    [85] = '#26355c',
    [86] = '#3d5c8a',
    [87] = '#6f97c9',
    [88] = '#f2c200',
    [89] = '#f7e017',
    [90] = '#8c6239',
    [91] = '#f2d93a',
    [92] = '#a8e60a',
    [93] = '#d9c9a3',
    [94] = '#c9a878',
    [95] = '#a8967a',
    [96] = '#4a2e1a',
    [97] = '#7a4f21',
    [98] = '#9c6b3f',
    [99] = '#d1b98a',
    [100] = '#5c4d2e',
    [101] = '#3d2a1a',
    [102] = '#8a6a45',
    [103] = '#5c4326',
    [104] = '#a0521a',
    [105] = '#e0cba0',
    [106] = '#d9c79a',
    [107] = '#f0e6c8',
    [108] = '#4d3520',
    [109] = '#6b4a2a',
    [110] = '#96703f',
    [111] = '#f2f2f2',
    [112] = '#eef3f5',
    [113] = '#c9a76b',
    [114] = '#5c3f26',
    [115] = '#3a2717',
    [116] = '#c2ab7d',
    [117] = '#9098a0',
    [118] = '#33363a',
    [119] = '#b8bcc0',
    [120] = '#d8dcdf',
    [121] = '#e2ddd0',
    [122] = '#e6e0d0',
    [123] = '#b5602a',
    [124] = '#d98a4d',
    [125] = '#1f5c3d',
    [126] = '#d1ab1a',
    [127] = '#1a2f7a',
    [128] = '#2f5c2f',
    [129] = '#4d3320',
    [130] = '#b5602a',
    [131] = '#e6e6e6',
    [132] = '#d6d6d0',
    [133] = '#565c3a',
    [134] = '#ffffff',
    [135] = '#ff69b4',
    [136] = '#fa8072',
    [137] = '#e0556b',
    [138] = '#ff7f11',
    [139] = '#17a333',
    [140] = '#175ce0',
    [141] = '#12203d',
    [142] = '#241f3d',
    [143] = '#33141a',
    [144] = '#2e4d2e',
    [145] = '#6a2fa0',
    [146] = '#0d1433',
    [147] = '#050505',
    [148] = '#6b3fa0',
    [149] = '#3d2159',
    [150] = '#c22a1a',
    [151] = '#1f4d2e',
    [152] = '#4d4d29',
    [153] = '#6b4f2e',
    [154] = '#c2a06b',
    [155] = '#4d5c33',
    [156] = '#8c8c8c',
    [157] = '#1f3d8a',
    [158] = '#d4af37',
    [159] = '#c9a84a',
    [160] = '#17a333',
}

-- kind -> the Config.RepairCosts base-cost field it uses.
local REPAIR_BASE_KEY = { full = 'fullRepairCost', emergency = 'emergencyRepairCost', field = 'fieldRepairCost' }

---@param kind string 'full'|'emergency'|'field'
---@param jobName string|nil
---@param cfg table
---@return number
function Workshop.repairPrice(kind, jobName, cfg)
    local rc = cfg and cfg.RepairCosts
    if not rc or rc.enabled == false then return 0 end
    if jobName then
        for _, freeJob in ipairs(rc.freeForJobs or {}) do
            if freeJob == jobName then return 0 end
        end
    end
    local base = rc[REPAIR_BASE_KEY[kind]] or 0
    local discount = 0
    for _, entry in ipairs(rc.discountJobs or {}) do
        if entry.job == jobName then discount = entry.discount; break end
    end
    return math.floor(base * (1 - discount) + 0.5)
end

---Which account pays and how much, or nil when nothing can cover it. 'bank' and
---'both' try the bank first and fall back to cash; 'cash' never reaches the bank.
---A free repair returns amount 0 so the caller skips RemoveMoney but still succeeds.
---@param price number
---@param bank number
---@param cash number
---@param chargeFrom string 'bank'|'cash'|'both'
---@return table|nil plan { account = 'bank'|'cash', amount = number }
function Workshop.chargePlan(price, bank, cash, chargeFrom)
    price = tonumber(price) or 0
    local have = { bank = tonumber(bank) or 0, cash = tonumber(cash) or 0 }
    local order = chargeFrom == 'cash' and { 'cash' } or { 'bank', 'cash' }
    if price <= 0 then return { account = order[1], amount = 0 } end
    for _, account in ipairs(order) do
        if have[account] >= price then return { account = account, amount = price } end
    end
    return nil
end

---@param kind string 'personal'|'job'
---@param count number existing preset count for that scope
---@param grade number player's job grade
---@param cfg table
---@return boolean ok, string|nil reason
function Workshop.presetAllowed(kind, count, grade, cfg)
    local p = cfg and cfg.Presets
    if not p or p.enabled == false then return false, 'Presets are disabled.' end
    if kind == 'personal' then
        if count >= (p.maxPresetsPerPlayer or 0) then return false, 'Personal preset limit reached.' end
        return true
    elseif kind == 'job' then
        if not p.allowJobPresets then return false, 'Job presets are disabled.' end
        if grade < (p.minGradeForJobPresets or 0) then return false, 'Grade too low for job presets.' end
        if count >= (p.maxPresetsPerJob or 0) then return false, 'Job preset limit reached.' end
        return true
    end
    return false, 'Unknown preset kind.'
end

---Ported rule: string, 1-128 chars, no path traversal, restricted charset.
---@param file any
---@return boolean
function Workshop.isSafeLiveryFile(file)
    if type(file) ~= 'string' then return false end
    local len = #file
    if len < 1 or len > 128 then return false end
    if file:find('%.%.') then return false end
    if not file:match('^[%w%s%-_/%.]+$') then return false end
    return true
end

---@param report table { engine=, body=, tank=, tyres={burst=n}, windows={broken=n}, doors={damaged=n} }
---@return string[]
function Workshop.describeDamage(report)
    report = report or {}
    local lines = {}
    lines[#lines + 1] = ('Engine %d %%'):format(math.floor((report.engine or 0) / 10 + 0.5))
    lines[#lines + 1] = ('Body %d %%'):format(math.floor((report.body or 0) / 10 + 0.5))
    lines[#lines + 1] = ('Fuel tank %d %%'):format(math.floor((report.tank or 0) / 10 + 0.5))

    local burst = report.tyres and report.tyres.burst or 0
    if burst > 0 then
        lines[#lines + 1] = burst == 1 and '1 tyre burst' or ('%d tyres burst'):format(burst)
    end

    local broken = report.windows and report.windows.broken or 0
    if broken > 0 then
        lines[#lines + 1] = broken == 1 and '1 window broken' or ('%d windows broken'):format(broken)
    end

    local damaged = report.doors and report.doors.damaged or 0
    if damaged > 0 then
        lines[#lines + 1] = damaged == 1 and '1 door damaged' or ('%d doors damaged'):format(damaged)
    end

    return lines
end

---Merges the two ways GTA V carries a livery into one list: stock liveries
---(SetVehicleLivery, index 0..count-1) and livery mods (mod slot 48,
---index 0..modCount-1). Labels are numbered across the whole merged list, so a
---vehicle with 2 stock liveries and 3 mods reads Livery 1..5; names[i] (0-based
---on the merged position) overrides the default label.
---@param count number stock livery count (GetVehicleLiveryCount)
---@param modCount number livery-mod count (GetNumVehicleMods veh, 48)
---@param names table|nil optional labels keyed by merged position, 0-based
---@return table choices { { value = { src = 'livery'|'mod', index = n }, label = string } }
function Workshop.liveryChoices(count, modCount, names)
    count = tonumber(count) or 0
    modCount = tonumber(modCount) or 0
    if count < 0 then count = 0 end
    if modCount < 0 then modCount = 0 end
    names = names or {}
    local out = {}
    for i = 0, count - 1 do
        out[#out + 1] = { value = { src = 'livery', index = i }, label = names[i] or ('Livery %d'):format(i + 1) }
    end
    for j = 0, modCount - 1 do
        local i = count + j
        out[#out + 1] = { value = { src = 'mod', index = j }, label = names[i] or ('Livery %d'):format(i + 1) }
    end
    return out
end
