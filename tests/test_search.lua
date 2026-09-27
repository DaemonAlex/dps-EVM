local L = {
    { model = 'hellspawn', name = 'Hellspawn', brand = 'LCC', category = 'cruisers', type = 'bike', price = 30000, pack = 'dpsveh-civilian', make = 'WESTERN', speed = 178 },
    { model = 'hellfire', name = 'Hellfire', brand = 'Pegassi', category = 'exotics', type = 'automobile', price = 1200000, pack = 'gb-cars', make = 'PEGASSI', speed = 260 },
    { model = 'sultan', name = 'Sultan', brand = 'Karin', category = 'tuners', type = 'automobile', price = 42000, pack = 'vanilla', make = 'KARIN' },
    { model = 'shinobid', name = 'Shinobi Drag', brand = 'Nagasaki', category = 'dragbikes', type = 'bike', price = 88000, pack = 'dpsveh-race', make = 'NAGASAKI', speed = 240 },
}

-- parse
local p = Search.parse('hell cat:cruisers price:<50000 sort:speed-desc')
eq('word', p.words[1], 'hell')
eq('filter cat', p.filters.category, 'cruisers')
eq('range op', p.ranges.price.op, '<')
eq('range val', p.ranges.price.value, 50000)
eq('sort', p.sort, 'speed')
eq('desc', p.desc, true)
eq('empty query words', #Search.parse(nil).words, 0)
eq('bad range ignored', Search.parse('price:cheap').ranges.price, nil)

-- free text hits name, brand, model, category, pack
local r = Search.run(L, 'hell')
eq('hell finds two', #r, 2)
eq('civilian finds pack', Search.run(L, 'civilian')[1].model, 'hellspawn')
eq('gb also hits dragbikes (substring, by design)', #Search.run(L, 'gb'), 2)
eq('pack token is exact to the pack field', Search.run(L, 'pack:gb')[1].model, 'hellfire')
eq('pegassi finds brand', Search.run(L, 'pegassi')[1].model, 'hellfire')
eq('two words both required', #Search.run(L, 'hell pegassi'), 1)
eq('no hit', #Search.run(L, 'zzz'), 0)

-- filters and ranges
eq('cat filter substring', #Search.run(L, 'cat:bike'), 1)
eq('cat filter exact word', #Search.run(L, 'cat:cruisers'), 1)
eq('type filter', #Search.run(L, 'type:bike'), 2)
eq('price under', #Search.run(L, 'price:<50000'), 2)
eq('speed over', #Search.run(L, 'speed:>200'), 2)
eq('speed missing excluded', #Search.run(L, 'speed:>0'), 3)
eq('pack token', Search.run(L, 'pack:race')[1].model, 'shinobid')

-- sort
eq('default sort by display name', Search.run(L, '')[1].model, 'sultan')      -- Karin Sultan < LCC Hellspawn < Nagasaki < Pegassi
eq('sort price asc', Search.run(L, 'sort:price')[1].model, 'hellspawn')
eq('sort price desc', Search.run(L, 'sort:price-desc')[1].model, 'hellfire')
eq('sort speed desc, missing last', Search.run(L, 'sort:speed-desc')[4].model, 'sultan')
eq('opts sort', Search.run(L, '', { sort = 'model' })[1].model, 'hellfire')

-- rail category + only set
eq('category opt', #Search.run(L, '', { category = 'exotics' }), 1)
eq('category all', #Search.run(L, '', { category = 'all' }), 4)
eq('only set', #Search.run(L, '', { only = { sultan = true, hellfire = true } }), 2)

-- never mutates input
local before = #L
Search.run(L, 'hell')
eq('input untouched', #L, before)

-- counts
local c = Search.counts(L)
eq('count cruisers', c.cruisers, 1)
eq('count exotics', c.exotics, 1)
