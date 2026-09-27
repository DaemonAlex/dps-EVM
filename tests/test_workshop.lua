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
