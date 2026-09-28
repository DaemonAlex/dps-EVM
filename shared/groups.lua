--[[
    dps-carmenu shared/groups.lua
    Friendly names for the registry's use-based categories, the seven top groups the
    panel shows, and the department / kind vocabulary for the emergency fleet.
    Pure data; shared by client, server and tests.
]]
Groups = {}

Groups.CATEGORY_LABEL = {
    daily = 'Daily drivers', family = 'Family cars', luxury = 'Luxury', suvs = 'SUVs', pickups = 'Pickups', vans = 'Vans',
    offroad = 'Off-road', muscle = 'Muscle', lowriders = 'Lowriders', classics = 'Classics', tuners = 'Tuners', sports = 'Sports',
    exotics = 'Exotics', custom = 'Custom builds',
    cruisers = 'Cruisers', sportbikes = 'Sport bikes', dirtbikes = 'Dirt bikes', scooters = 'Scooters', dragbikes = 'Drag bikes', cycles = 'Bicycles',
    race_gt = 'GT', race_proto = 'Prototype', race_formula = 'Formula', race_touring = 'Touring', race_sprint = 'Sprint', race_rally = 'Rally',
    race_drag = 'Drag', race_stock = 'Stock car', race_drift = 'Drift', race_offroad = 'Off-road racing',
    emergency = 'Emergency', transit = 'Transit', service = 'Service', food = 'Food trucks', haulage = 'Haulage', trailers = 'Trailers',
    construction = 'Construction', farm = 'Farm', military = 'Military',
    airliners = 'Airliners', bizjets = 'Business jets', aviation = 'General aviation', helicopters = 'Helicopters',
    boats = 'Boats', workboats = 'Work boats', rc = 'RC', trains = 'Trains',
}

Groups.GROUPS = {
    { id = 'street', label = 'Street', cats = { 'daily', 'family', 'luxury', 'suvs', 'pickups', 'vans', 'offroad', 'muscle', 'lowriders', 'classics', 'tuners', 'sports', 'exotics', 'custom' } },
    { id = 'bikes', label = 'Bikes', cats = { 'cruisers', 'sportbikes', 'dirtbikes', 'scooters', 'dragbikes', 'cycles' } },
    { id = 'racing', label = 'Racing', cats = { 'race_gt', 'race_proto', 'race_formula', 'race_touring', 'race_sprint', 'race_rally', 'race_drag', 'race_stock', 'race_drift', 'race_offroad' } },
    { id = 'emergency', label = 'Emergency', cats = { 'emergency' } },
    { id = 'work', label = 'Work', cats = { 'transit', 'service', 'food', 'haulage', 'trailers', 'construction', 'farm', 'military' } },
    { id = 'air', label = 'Air', cats = { 'airliners', 'bizjets', 'aviation', 'helicopters' } },
    { id = 'sea', label = 'Sea', cats = { 'boats', 'workboats' } },
    { id = 'other', label = 'Other', cats = { 'rc', 'trains' } },
}

Groups.GROUP_OF = {}
for _, g in ipairs(Groups.GROUPS) do for _, c in ipairs(g.cats) do Groups.GROUP_OF[c] = g end end

-- Department keys are the qbx job names (plus police_swat for the tactical fleet).
Groups.DEPT_ORDER = { 'police', 'police_swat', 'bcso', 'sasp', 'fib', 'doc', 'dfw', 'uscg', 'rpd', 'rcso', 'lsfd', 'rfd', 'sams', 'omc', 'rmc', 'unsorted', 'none' }
Groups.DEPT_NAME = {
    police = 'Los Santos Police Department', police_swat = 'LSPD SWAT', bcso = "Blaine County Sheriff's Office", sasp = 'San Andreas Highway Patrol',
    fib = 'Federal Investigation Bureau', doc = 'Department of Corrections', dfw = 'Fish & Wildlife', uscg = 'Coast Guard',
    rpd = 'Roxwood Police Department', rcso = "Roxwood County Sheriff's Office", lsfd = 'Los Santos Fire Department', rfd = 'Roxwood Fire Department',
    sams = 'San Andreas Medical Services', omc = 'Ocean Medical Center', rmc = 'Roxwood Medical Center', unsorted = 'Unsorted', none = 'No department yet',
}
Groups.DEPT_CODE = {
    police = 'LSPD', police_swat = 'SWAT', bcso = 'BCSO', sasp = 'SAHP', fib = 'FIB', doc = 'DOC', dfw = 'DFW', uscg = 'USCG', rpd = 'RPD', rcso = 'RCSO',
    lsfd = 'LSFD', rfd = 'RFD', sams = 'SAMS', omc = 'OMC', rmc = 'RMC', unsorted = '?', none = '-',
}
Groups.KIND_ORDER = { 'Cruiser', 'Unmarked', 'SUV / truck', 'Motorcycle', 'Tactical', 'Command', 'Fire engine', 'Ladder truck', 'Brush truck', 'Rescue', 'Ambulance', 'Van', 'Helicopter', 'Boat' }
Groups.KIND_PLURAL = {
    ['Cruiser'] = 'Cruisers', ['SUV / truck'] = 'SUVs & trucks', ['Motorcycle'] = 'Motorcycles', ['Fire engine'] = 'Fire engines', ['Ladder truck'] = 'Ladder trucks',
    ['Brush truck'] = 'Brush trucks', ['Ambulance'] = 'Ambulances', ['Helicopter'] = 'Helicopters', ['Boat'] = 'Boats', ['Van'] = 'Vans', ['Rescue'] = 'Rescue units',
    ['Command'] = 'Command units', ['Tactical'] = 'Tactical', ['Unmarked'] = 'Unmarked', ['Other'] = 'Other',
}
-- Words people type that mean a group or a kind. Matched as whole words at the front of the query.
Groups.SYNONYMS = {
    cops = 'dept:police', lspd = 'dept:police', police = 'dept:police', swat = 'dept:police_swat', sheriff = 'dept:bcso', bcso = 'dept:bcso',
    sahp = 'dept:sasp', sasp = 'dept:sasp', fib = 'dept:fib', rangers = 'dept:dfw', dfw = 'dept:dfw', coastguard = 'dept:uscg', uscg = 'dept:uscg',
    rpd = 'dept:rpd', rcso = 'dept:rcso', lsfd = 'dept:lsfd', rfd = 'dept:rfd', sams = 'dept:sams', ems = 'kind:ambulance', omc = 'dept:omc', rmc = 'dept:rmc',
    ambulance = 'kind:ambulance', ambulances = 'kind:ambulance', engine = 'kind:fire engine', engines = 'kind:fire engine', ladder = 'kind:ladder truck', ladders = 'kind:ladder truck',
    cruiser = 'kind:cruiser', cruisers = 'kind:cruiser', tactical = 'kind:tactical', heli = 'kind:helicopter', helis = 'kind:helicopter', helicopters = 'kind:helicopter',
    bikes = 'group:bikes', bike = 'group:bikes', motorcycles = 'group:bikes', racing = 'group:racing', race = 'group:racing', emergency = 'group:emergency',
    street = 'group:street', work = 'group:work', air = 'group:air', planes = 'group:air', sea = 'group:sea', boats = 'group:sea',
}
