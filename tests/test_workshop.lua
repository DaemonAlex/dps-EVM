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
