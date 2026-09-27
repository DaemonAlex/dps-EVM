--[[
    dps-carmenu shared/fields.lua
    Handling fields read from a live vehicle with GetVehicleHandlingFloat /
    GetVehicleHandlingInt / GetVehicleHandlingVector on class CHandlingData.
    Same list dps-handlingdump uses; names are the game's, case-sensitive.
]]
HandlingFields = {
    floats = {
        'fMass', 'fInitialDragCoeff', 'fDownforceModifier', 'fPercentSubmerged',
        'fDriveBiasFront', 'fInitialDriveForce', 'fDriveInertia',
        'fClutchChangeRateScaleUpShift', 'fClutchChangeRateScaleDownShift',
        'fInitialDriveMaxFlatVel', 'fBrakeForce', 'fBrakeBiasFront', 'fHandBrakeForce',
        'fSteeringLock', 'fTractionCurveMax', 'fTractionCurveMin', 'fTractionCurveLateral',
        'fTractionSpringDeltaMax', 'fLowSpeedTractionLossMult', 'fCamberStiffnesss',
        'fTractionBiasFront', 'fTractionLossMult', 'fSuspensionForce', 'fSuspensionCompDamp',
        'fSuspensionReboundDamp', 'fSuspensionUpperLimit', 'fSuspensionLowerLimit',
        'fSuspensionRaise', 'fSuspensionBiasFront', 'fAntiRollBarForce', 'fAntiRollBarBiasFront',
        'fRollCentreHeightFront', 'fRollCentreHeightRear', 'fCollisionDamageMult',
        'fWeaponDamageMult', 'fDeformationDamageMult', 'fEngineDamageMult',
        'fPetrolTankVolume', 'fOilVolume', 'fSeatOffsetDistX', 'fSeatOffsetDistY',
        'fSeatOffsetDistZ',
    },
    ints = { 'nInitialDriveGears', 'nMonetaryValue' },
    vectors = { 'vecCentreOfMassOffset', 'vecInertiaMultiplier' },
}
