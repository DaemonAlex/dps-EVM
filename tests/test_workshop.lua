local cfg = { EnabledModifications = { Liveries = true, CustomLiveries = false, Performance = true, Appearance = true, Neon = false, Extras = true, Doors = true, Repair = true, Presets = true },
  UndercoverNeon = { enabled = true, allowedVehicles = { 'unbuffalo4' } },
  RepairCosts = { enabled = true, fullRepairCost = 500, emergencyRepairCost = 200, fieldRepairCost = 350, freeForJobs = { 'mechanic' }, discountJobs = { { job = 'police', discount = 0.25 } } },
  Presets = { enabled = true, maxPresetsPerPlayer = 10, maxPresetsPerJob = 5, allowJobPresets = true, minGradeForJobPresets = 3 } }
local ids = {} for i, s in ipairs(Workshop.enabledSections(cfg, 'sultan', false)) do ids[i] = s.id end
check('customliveries hidden when disabled', not table.concat(ids, ','):find('customliveries'))
check('neon hidden for normal car', not table.concat(ids, ','):find('neon'))
ids = {} for i, s in ipairs(Workshop.enabledSections(cfg, 'unbuffalo4', true)) do ids[i] = s.id end
check('neon shown for undercover car', table.concat(ids, ','):find('neon'))
eq('repair full police', Workshop.repairPrice('full', 'police', cfg), 375)
eq('repair emergency mechanic free', Workshop.repairPrice('emergency', 'mechanic', cfg), 0)
eq('repair field civilian', Workshop.repairPrice('field', 'unemployed', cfg), 350)
eq('repair disabled', Workshop.repairPrice('full', 'unemployed', { RepairCosts = { enabled = false } }), 0)
eq('preset personal ok', Workshop.presetAllowed('personal', 9, 0, cfg), true)
eq('preset limit', Workshop.presetAllowed('personal', 10, 0, cfg), false)
eq('job preset grade', Workshop.presetAllowed('job', 0, 2, cfg), false)
eq('job preset ok', Workshop.presetAllowed('job', 0, 3, cfg), true)
eq('livery file ok', Workshop.isSafeLiveryFile('lspd_pack/stanier_1.yft'), true)
eq('livery file traversal', Workshop.isSafeLiveryFile('../x.yft'), false)
eq('livery file empty', Workshop.isSafeLiveryFile(''), false)
eq('wheel type name', Workshop.WHEEL_TYPES[7], 'High End')
eq('tint name', Workshop.TINTS[2], 'Dark smoke')
eq('colour name 0', Workshop.COLOURS[0], 'Metallic Black')
local lines = Workshop.describeDamage({ engine = 420, body = 1000, tank = 1000, tyres = { burst = 2 }, windows = { broken = 0 }, doors = { damaged = 1 } })
eq('damage engine line', lines[1], 'Engine 42 %')
check('damage tyres line', table.concat(lines, '|'):find('2 tyres burst', 1, true))

-- Controller ruling 2026-09-27: sirens section added after presets, before repair
cfg.EnabledModifications.Sirens = true
ids = {} for i, s in ipairs(Workshop.enabledSections(cfg, 'sultan', false)) do ids[i] = s.id end
check('sirens section present', table.concat(ids, ','):find('sirens'))

-- Task 4: Workshop.liveryChoices merges stock liveries and livery mods (slot 48)
-- into one labelled list; labels keep numbering across the join.
local ch = Workshop.liveryChoices(2, 3, { [0] = 'Slicktop' })
eq('livery choices count', #ch, 5)
eq('first is named', ch[1].label, 'Slicktop'); eq('first src', ch[1].value.src, 'livery'); eq('first index', ch[1].value.index, 0)
eq('second default label', ch[2].label, 'Livery 2')
eq('mod entries follow', ch[3].value.src, 'mod'); eq('mod label numbering continues', ch[3].label, 'Livery 3')
eq('none when nothing', #Workshop.liveryChoices(0, 0, {}), 0)

-- Task 6: Workshop.chargePlan(price, bank, cash, chargeFrom) -> { account, amount } | nil
-- 'bank' and 'both' both fall back to cash; 'cash' never reaches the bank.
local plan = Workshop.chargePlan(375, 0, 400, 'bank')
eq('bank empty falls to cash', plan.account, 'cash'); eq('amount', plan.amount, 375)
eq('bank has it', Workshop.chargePlan(375, 1000, 0, 'bank').account, 'bank')
eq('cash only', Workshop.chargePlan(100, 1000, 50, 'cash'), nil)
eq('free', Workshop.chargePlan(0, 0, 0, 'bank').amount, 0)
eq('both prefers bank', Workshop.chargePlan(100, 100, 100, 'both').account, 'bank')
eq('nothing anywhere', Workshop.chargePlan(100, 10, 10, 'both'), nil)
eq('exact bank balance pays', Workshop.chargePlan(100, 100, 0, 'bank').account, 'bank')
eq('cash pays from cash', Workshop.chargePlan(100, 0, 100, 'cash').account, 'cash')

-- Task 6b: sirens. Workshop.SIREN_TONES is a transcription of lvc/SIRENS.lua and
-- the ids are the contract with LVC, so the count and the spot checks are the guard:
-- if a siren pack is added or removed in LVC these tests must be updated with it.
eq('siren key from game name', Workshop.sirenKey('hvsamsambulance', 'hvsamsambulance'), 'hvsamsambul')
eq('siren key keeps case', Workshop.sirenKey('POLSTANIER', 'gbpolstanier'), 'POLSTANIER')
eq('siren key falls back to model', Workshop.sirenKey(nil, 'mysteryfire'), 'mysteryfire')
eq('siren key of nothing', Workshop.sirenKey(nil, nil), nil)
eq('siren key ignores an empty game name', Workshop.sirenKey('', 'gbpolstanier'), 'gbpolstanie')

eq('siren tone count', #Workshop.SIREN_TONES, 46)
eq('tone name 1', Workshop.SIREN_TONES[1], 'Airhorn')
eq('tone name 14', Workshop.SIREN_TONES[14], 'Fire Wail')
eq('tone name 21', Workshop.SIREN_TONES[21], 'Whelen Yelp')
eq('tone name 46', Workshop.SIREN_TONES[46], 'Smart Siren HiLo')
eq('tone string', Workshop.SIREN_TONES_STRING[21], 'GAMMA_YELP')
eq('tone soundset', Workshop.SIREN_TONES_REF[21], 'WHELENGAMMA2_SOUNDSET')
eq('base game tone has no soundset', Workshop.SIREN_TONES_REF[1], 0)
eq('string column is complete', #Workshop.SIREN_TONES_STRING, #Workshop.SIREN_TONES)
eq('soundset column is complete', #Workshop.SIREN_TONES_REF, #Workshop.SIREN_TONES)

eq('valid tones', Workshop.validTones({ 19, 20, 21, 22, 23 }, 46), true)
eq('two is the floor', Workshop.validTones({ 19, 20 }, 46), true)
eq('empty refused', Workshop.validTones({}, 46), false)
-- LVC reads position 1 as the airhorn and 2.. as the cycle, so a lone tone is not a
-- siren. The server gate refuses it, not just the panel.
eq('single tone refused', Workshop.validTones({ 1 }, 46), false)
eq('out of range refused', Workshop.validTones({ 1, 99 }, 46), false)
eq('zero refused', Workshop.validTones({ 0, 1 }, 46), false)
eq('non-integer refused', Workshop.validTones({ 1, 2.5 }, 46), false)
eq('too many refused', Workshop.validTones({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 46), false)
eq('eight is the ceiling', Workshop.validTones({ 1, 2, 3, 4, 5, 6, 7, 8 }, 46), true)
eq('holes refused', Workshop.validTones({ [1] = 1, [3] = 2 }, 46), false)
eq('string keys refused', Workshop.validTones({ 1, 2, horn = 3 }, 46), false)
eq('not a table refused', Workshop.validTones('19,20', 46), false)
eq('a float that is whole is fine', Workshop.validTones({ 19.0, 20.0 }, 46), true)

eq('preset fire', Workshop.SIREN_PRESETS.fire.tones[1], 12)
eq('preset leo', Workshop.SIREN_PRESETS.leo.tones[1], 19)
eq('preset ems', Workshop.SIREN_PRESETS.ems.tones[1], 1)
eq('preset smart siren', Workshop.SIREN_PRESETS.smart.tones[5], 46)
check('every preset is a valid tone list', (function()
    for key, preset in pairs(Workshop.SIREN_PRESETS) do
        if type(preset.label) ~= 'string' then return false, key end
        if not Workshop.validTones(preset.tones, #Workshop.SIREN_TONES) then return false, key end
    end
    return true
end)())
check('the preset order lists every preset once', (function()
    local n = 0
    for _ in pairs(Workshop.SIREN_PRESETS) do n = n + 1 end
    if n ~= #Workshop.SIREN_PRESET_ORDER then return false end
    for _, key in ipairs(Workshop.SIREN_PRESET_ORDER) do
        if not Workshop.SIREN_PRESETS[key] then return false end
    end
    return true
end)())

eq('a saved list that matches a preset names it', Workshop.sirenPresetOf({ 19, 20, 21, 22, 23 }), 'leo')
eq('order matters', Workshop.sirenPresetOf({ 20, 19, 21, 22, 23 }), nil)
eq('a hand-built list is custom', Workshop.sirenPresetOf({ 1, 2, 3 }), nil)
eq('nothing is custom', Workshop.sirenPresetOf(nil), nil)

-- Task 7b: trunk gear (Vehiclegear folded in). Gear.allowedFor and Gear.jobAllowed
-- are the whole vehicle-and-job rule; the controller ruling 2026-09-27 puts the
-- department kit between the per-model override and DefaultGear.
local em = {
    gbpolstanier = { dept = 'police', kind = 'Cruiser' },
    hvfiretruk = { dept = 'lsfd', kind = 'Fire engine' },
    hvswatalamo = { dept = 'police_swat', kind = 'Tactical' },
}
local gcfg = { TrunkGear = { AutoVehicles = true, DefaultGear = { 'bproof', 'helmet' },
    allowedVehicles = { gbpolstanier = { 'bproof', 'refvest' } },
    AutoJobs = true, Authorizedjobs = { 'police' } } }
eq('auto: emergency model gets default gear', Gear.allowedFor('hvfiretruk', gcfg, em)[1], 'bproof')
eq('explicit override wins', Gear.allowedFor('gbpolstanier', gcfg, em)[2], 'refvest')
eq('civilian model not allowed', Gear.allowedFor('sultan', gcfg, em), nil)
gcfg.TrunkGear.AutoVehicles = false
eq('manual list only', Gear.allowedFor('hvfiretruk', gcfg, em), nil)
eq('an override still works with the auto list off', Gear.allowedFor('gbpolstanier', gcfg, em)[1], 'bproof')
eq('auto jobs use workshop set', Gear.jobAllowed('sams', gcfg, { sams = true }), true)
gcfg.TrunkGear.AutoJobs = false
eq('manual jobs', Gear.jobAllowed('sams', gcfg, { sams = true }), false)
eq('manual jobs ok', Gear.jobAllowed('police', gcfg, {}), true)
eq('no job at all is refused', Gear.jobAllowed(nil, gcfg, { police = true }), false)

-- Department kits (ruling 2026-09-27): DeptGear[dept] beats DefaultGear, the
-- per-model override beats both, and the auto list is still the gate.
gcfg.TrunkGear.AutoVehicles, gcfg.TrunkGear.AutoJobs = true, true
gcfg.TrunkGear.DeptGear = {
    police = { 'bproof', 'refvest', 'helmet' },
    police_swat = { 'heavy', 'bproof', 'helmet' },
    lsfd = { 'turnout', 'firehelmet', 'refvest' },
}
eq('dept gear wins over default', Gear.allowedFor('hvfiretruk', gcfg, em)[1], 'turnout')
eq('swat gets heavy', Gear.allowedFor('hvswatalamo', gcfg, em)[1], 'heavy')
eq('override still wins', Gear.allowedFor('gbpolstanier', gcfg, em)[2], 'refvest')
eq('a department with no kit falls back to the default',
    Gear.allowedFor('bccoroner', gcfg, { bccoroner = { dept = 'none' } })[1], 'bproof')

-- CrossDept = false keeps an allowed job to its own family's vehicles, so police
-- cannot pull turnout gear out of a fire engine.
gcfg.TrunkGear.DeptJobs = { police = { 'police', 'bcso' }, police_swat = { 'police', 'bcso' }, lsfd = { 'lsfd', 'rfd' } }
eq('own department ok', Gear.deptAllowed('police', 'police', gcfg), true)
eq('police may not raid an engine', Gear.deptAllowed('police', 'lsfd', gcfg), false)
eq('fire may take fire gear off another fire rig', Gear.deptAllowed('rfd', 'lsfd', gcfg), true)
eq('a department with no job list is open to any allowed job', Gear.deptAllowed('police', 'none', gcfg), true)
gcfg.TrunkGear.CrossDept = true
eq('CrossDept opens every department', Gear.deptAllowed('police', 'lsfd', gcfg), true)
gcfg.TrunkGear.CrossDept = false

-- Gear.buildIndex is the table the client hashes: one entry per model that
-- carries a kit, and only gear keys that still have a definition.
gcfg.TrunkGear.Gear = { bproof = {}, helmet = {}, turnout = {}, firehelmet = {}, refvest = {}, heavy = {} }
local gi = Gear.buildIndex(gcfg, em)
eq('index has the fire engine', gi.hvfiretruk.gear[1], 'turnout')
eq('index carries the department', gi.hvfiretruk.dept, 'lsfd')
check('index set is a lookup', gi.hvfiretruk.set.turnout == true)
eq('index skips a model with no kit', gi.sultan, nil)
gcfg.TrunkGear.Gear.turnout = nil
gi = Gear.buildIndex(gcfg, em)
eq('a disabled gear key drops out of the set', gi.hvfiretruk.set.turnout, nil)
check('the rest of the kit stays', gi.hvfiretruk.set.firehelmet == true)

-- Slots are the structural half: component 9 vest, component 11 turnout coat, prop 0 head.
eq('vest slot', Gear.SLOTS.vest.index, 9)
eq('torso slot', Gear.SLOTS.torso.index, 11)
eq('head slot is a prop', Gear.SLOTS.head.kind, 'prop')

-- Final review F4: the canonical model key is the spawn code; the lowercased game
-- name is the fallback for a model the qbx_core registry does not know.
eq('spawn code wins', Workshop.modelKey('hvfiretruk', 'FIRETRUK'), 'hvfiretruk')
eq('spawn code is lowercased', Workshop.modelKey('HVFireTruk', 'FIRETRUK'), 'hvfiretruk')
eq('game name is the fallback', Workshop.modelKey(nil, 'FIRETRUK'), 'firetruk')
eq('empty spawn code falls back too', Workshop.modelKey('', 'POLICE'), 'police')
eq('no key at all', Workshop.modelKey(nil, nil), '')
eq('CARNOTFOUND is not a key', Workshop.modelKey(nil, 'CARNOTFOUND'), '')
