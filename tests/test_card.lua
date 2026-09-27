local info = {
    model = 'hellspawn', name = 'Hellspawn', brand = 'LCC', category = 'cruisers', type = 'bike',
    price = 30000, pack = 'dpsveh-civilian', cls = 'Motorcycles', make = 'WESTERN',
    speed = 178, accel = 0.34, brake = 0.9, traction = 2.1, seats = 2, dims = { l = 2.3, w = 0.8, h = 1.1 },
}
local card = Card.format(info)
check('card header', card:find('^DPS VEHICLE CARD\n'))
check('card model line', card:find('model: hellspawn   name: LCC Hellspawn   category: cruisers   type: bike', 1, true))
check('card money', card:find('price: $30,000', 1, true))
check('card pack', card:find('pack: dpsveh-civilian', 1, true))
check('card speed', card:find('top speed 178 km/h', 1, true))
check('card dims', card:find('2.3 x 0.8 x 1.1 m', 1, true))
check('card no handling hint', card:find('spawn it or sit in it', 1, true))
check('card notes', card:find('LVC only', 1, true))

info.handling = { fMass = 320, fInitialDriveForce = 0.28, fDriveBiasFront = 0.0, nInitialDriveGears = 5, fInitialDriveMaxFlatVel = 175,
    fBrakeForce = 0.9, fBrakeBiasFront = 0.5, fTractionCurveMax = 2.1, fTractionCurveMin = 1.9, fTractionCurveLateral = 22.5,
    fSuspensionForce = 2.4, fPetrolTankVolume = 15 }
card = Card.format(info)
check('handling line', card:find('handling: mass 320 · drive force 0.28 · drive bias 0.00 (rear) · gears 5 · flat vel 175', 1, true))
check('handling line 2', card:find('brake force 0.90 bias 0.50 · traction max 2.10 min 1.90 lat 22.5 · susp force 2.40 · fuel 15', 1, true))
check('hint gone', not card:find('spawn it or sit in it', 1, true))
info.handling.fDriveBiasFront = 1.0
check('front bias word', Card.format(info):find('(front)', 1, true))
info.handling.fDriveBiasFront = 0.4
check('awd bias word', Card.format(info):find('(awd)', 1, true))

-- money formatting edge cases
check('million', Card.format({ price = 1200000 }):find('price: $1,200,000', 1, true))
check('no price', Card.format({}):find('price: -', 1, true))
check('brandless name', Card.format({ model = 'x', name = 'Solo' }):find('name: Solo ', 1, true))

-- handling block in meta order
local rec = { fMass = 1500.5, fInitialDriveForce = 0.31, nInitialDriveGears = 6, vecCentreOfMassOffset = { x = 0, y = 0.1, z = -0.2 } }
local block = Card.handling(rec, HandlingFields, 'sultan')
check('block title', block:find('^handling for sultan'))
local massPos, drivePos = block:find('<fMass value="1500.500000" />', 1, true), block:find('<fInitialDriveForce value="0.310000" />', 1, true)
check('mass present', massPos)
check('meta order kept', massPos and drivePos and massPos < drivePos)
check('int field', block:find('<nInitialDriveGears value="6" />', 1, true))
check('vector field', block:find('<vecCentreOfMassOffset x="0.000000" y="0.100000" z="-0.200000" />', 1, true))
check('missing float shown as -', block:find('<fBrakeForce value="-" />', 1, true))
eq('field count sanity', #HandlingFields.floats, 42)
