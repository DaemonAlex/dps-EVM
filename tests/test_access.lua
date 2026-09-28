local cfg = { EnableJobRestrictions = true, JobMappings = { police = { 'police', 'bcso' }, fire = { 'lsfd' }, ambulance = { 'sams' }, mechanic = { 'mechanic' } } }
eq('police allowed', Access.canWorkshop('police', false, cfg), true)
eq('mechanic allowed', Access.canWorkshop('mechanic', false, cfg), true)
local ok, why = Access.canWorkshop('unemployed', false, cfg)
eq('unemployed refused', ok, false); check('reason text', why and why:find('job', 1, true))
eq('admin bypass', Access.canWorkshop('unemployed', true, cfg), true)
eq('no job = refused even for admin (player not loaded)', Access.canWorkshop(nil, true, cfg), false)
eq('restrictions off = everyone', Access.canWorkshop('unemployed', false, { EnableJobRestrictions = false }), true)

-- Task 6 (drop-in jobs): Access.canWorkshopSet takes the derived job set, so the
-- server can build it from qbx_core instead of Config.JobMappings.
local set = { police = true, sams = true, mechanic = true }
eq('set: police allowed', Access.canWorkshopSet('police', false, set, true), true)
eq('set: mechanic allowed', Access.canWorkshopSet('mechanic', false, set, true), true)
local sok, swhy = Access.canWorkshopSet('unemployed', false, set, true)
eq('set: unemployed refused', sok, false); check('set: reason text', swhy and swhy:find('job', 1, true))
eq('set: admin bypass', Access.canWorkshopSet('unemployed', true, set, true), true)
eq('set: no job refused even for admin', Access.canWorkshopSet(nil, true, set, true), false)
eq('set: restrictions off = everyone', Access.canWorkshopSet('unemployed', false, set, false), true)
eq('set: empty set refuses', Access.canWorkshopSet('police', false, {}, true), false)
eq('set: old function still delegates', Access.canWorkshop('police', false, cfg), true)
