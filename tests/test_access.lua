local cfg = { EnableJobRestrictions = true, JobMappings = { police = { 'police', 'bcso' }, fire = { 'lsfd' }, ambulance = { 'sams' }, mechanic = { 'mechanic' } } }
eq('police allowed', Access.canWorkshop('police', false, cfg), true)
eq('mechanic allowed', Access.canWorkshop('mechanic', false, cfg), true)
local ok, why = Access.canWorkshop('unemployed', false, cfg)
eq('unemployed refused', ok, false); check('reason text', why and why:find('job', 1, true))
eq('admin bypass', Access.canWorkshop('unemployed', true, cfg), true)
eq('no job = refused even for admin (player not loaded)', Access.canWorkshop(nil, true, cfg), false)
eq('restrictions off = everyone', Access.canWorkshop('unemployed', false, { EnableJobRestrictions = false }), true)
