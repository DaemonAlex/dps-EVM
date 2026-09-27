local L = {
    { model = 'hvfiretruk', name = 'Fire Engine', brand = 'MTL', category = 'emergency', type = 'automobile', price = 0, pack = 'cfx-hv-safr-pack', dept = 'lsfd', kind = 'Fire engine' },
    { model = 'hvfdladder', name = 'Fire Ladder Truck', brand = 'MTL', category = 'emergency', type = 'automobile', price = 0, pack = 'cfx-hv-safr-pack', dept = 'lsfd', kind = 'Ladder truck' },
    { model = 'hvfdambulance', name = 'Fire Ambulance', brand = 'Brute', category = 'emergency', type = 'automobile', price = 0, pack = 'cfx-hv-safr-pack', dept = 'lsfd', kind = 'Ambulance' },
    { model = 'ambroxfireeng1', name = 'Roxwood Fire Engine', brand = 'MTL', category = 'emergency', type = 'automobile', price = 0, pack = 'amb-roxwood-vehicles', dept = 'rfd', kind = 'Fire engine' },
    { model = 'hvsamsambulance', name = 'Ambulance', brand = 'Brute', category = 'emergency', type = 'automobile', price = 0, pack = 'hv-lorefriendly-sams-pack', dept = 'sams', kind = 'Ambulance' },
    { model = 'gbpolstanier', name = 'Stanier LE Police', brand = 'Vapid', category = 'emergency', type = 'automobile', price = 0, pack = 'gb_vehicles_pd_ems', dept = 'police', kind = 'Cruiser' },
    { model = 'hvswatalamo', name = 'Alamo SWAT', brand = 'Declasse', category = 'emergency', type = 'automobile', price = 0, pack = 'cfx-hv-lorefriendly-swat-pack', dept = 'police_swat', kind = 'Tactical' },
    { model = 'mysteryfire', name = 'Mystery Fire Thing', brand = '', category = 'emergency', type = 'automobile', price = 0, pack = 'x' },
    { model = 'sultan', name = 'Sultan', brand = 'Karin', category = 'tuners', type = 'automobile', price = 42000, pack = 'vanilla' },
    { model = 'comet2', name = 'Comet', brand = 'Pfister', category = 'sports', type = 'automobile', price = 100000, pack = 'vanilla' },
    { model = 'hellspawn', name = 'Hellspawn', brand = 'LCC', category = 'cruisers', type = 'bike', price = 30000, pack = 'dpsveh-civilian' },
    { model = 'luxor', name = 'Luxor', brand = 'Buckingham', category = 'bizjets', type = 'plane', price = 1500000, pack = 'vanilla' },
}
local function names(secs) local t = {} for i, s in ipairs(secs) do t[i] = s.a .. (s.b and (' — ' .. s.b) or '') end return table.concat(t, ' | ') end

-- empty query: Recent and Favorites first, then every group in order
local s = Search.sections(L, '', { chip = 'all', recent = { 'sultan', 'nope' }, favorites = { 'comet2' } })
eq('recent first', s[1].a, 'Recent'); eq('recent has 1 (unknown dropped)', s[1].count, 1)
eq('favorites second', s[2].a, 'Favorites')
eq('street section', s[3].a .. ' — ' .. s[3].b, 'Street — Tuners')
check('order: tuners before sports (the fleet ladder, not alpha)', names(s):find('Street — Tuners | Street — Sports', 1, true))
check('bikes group', names(s):find('Bikes — Cruisers', 1, true))
check('dept then kind', names(s):find('Los Santos Fire Department — Fire engines | Los Santos Fire Department — Ladder trucks | Los Santos Fire Department — Ambulances', 1, true))
check('lspd before lsfd (dept order)', names(s):find('Los Santos Police Department') < names(s):find('Los Santos Fire Department'))
check('swat as its own dept', names(s):find('LSPD SWAT — Tactical', 1, true))
check('roxwood fire after LS fire', names(s):find('Roxwood Fire Department — Fire engines', 1, true))
check('unsorted emergency lands in No department yet — Other', names(s):find('No department yet — Other', 1, true))
check('air group', names(s):find('Air — Business jets', 1, true))

-- typing: Recent/Favorites drop out, groups filter
s = Search.sections(L, 'fire', { chip = 'all' })
eq('fire: first is LSFD engines', s[1].a .. ' — ' .. s[1].b, 'Los Santos Fire Department — Fire engines')
check('fire: no recent', names(s):find('Recent', 1, true) == nil)
check('fire: mystery matched by name', names(s):find('No department yet', 1, true))

-- group words
s = Search.sections(L, 'ambulances', { chip = 'all' })
eq('ambulances: two sections', #s, 2)
eq('ambulances: LSFD first', s[1].a, 'Los Santos Fire Department')
eq('ambulances: then SAMS', s[2].a, 'San Andreas Medical Services')
s = Search.sections(L, 'swat', { chip = 'all' })
eq('swat: one section', #s, 1); eq('swat: model', s[1].models[1], 'hvswatalamo')
s = Search.sections(L, 'bikes', { chip = 'all' })
eq('bikes: cruisers only', names(s), 'Bikes — Cruisers')
s = Search.sections(L, 'fire engines', { chip = 'all' })
eq('fire engines: both departments', #s, 2)
s = Search.sections(L, 'rox engine', { chip = 'all' })
eq('rox engine: one', #s, 1); eq('rox engine: roxwood', s[1].models[1], 'ambroxfireeng1')

-- chips
s = Search.sections(L, '', { chip = 'emergency' })
check('chip emergency only', names(s):find('Street', 1, true) == nil and names(s):find('Los Santos', 1, true))
s = Search.sections(L, '', { chip = 'fav', favorites = { 'hellspawn' } })
eq('chip fav', #s, 1); eq('chip fav model', s[1].models[1], 'hellspawn')
s = Search.sections(L, 'zzz', { chip = 'all' })
eq('no match: no sections', #s, 0)

-- groupWords helper
local rest, gw = Search.groupWords('cops stanier')
eq('rest', rest, 'stanier'); eq('dept word', gw.dept, 'police')
