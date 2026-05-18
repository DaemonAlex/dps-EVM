# DSRP Emergency Vehicle Menu - Bug Fixes

**Version:** 2.0.2-DSRP
**Adapted for:** DelPerro Sands RP (QBox Framework)
**Original Author:** DaemonAlex
**Fixed by:** DelPerro Sands RP Development Team

---

## Critical Bugs Fixed

### 1. QBox Framework Detection (config.lua:296-299)

**Problem:**
```lua
elseif GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started' then
    return 'qbcore'
elseif GetResourceState('qbox-core') == 'started' or GetResourceState('qbx-core') == 'started' then
    return 'qbox'
```

- QBox uses `qbx_core` as resource name
- Was being detected as `qbcore` first (line 296)
- Never reached QBox detection (line 298)
- Also checked for wrong resource names (`qbox-core` and `qbx-core` which don't exist)

**Fix:**
```lua
-- Check for QBox FIRST (it uses qbx_core but is different from QBX/QB-Core)
elseif GetResourceState('qbx_core') == 'started' then
    -- QBox uses qbx_core resource name
    return 'qbox'
elseif GetResourceState('qb-core') == 'started' then
    -- Legacy QB-Core
    return 'qbcore'
```

**Result:** QBox now correctly detected before QB-Core

---

### 2. QBox Player Export (config.lua:371)

**Problem:**
```lua
elseif framework == 'qbox' then
    local Player = exports.qbox:GetPlayer(playerId)  -- WRONG!
```

- Used non-existent `exports.qbox`
- QBox resource is named `qbx_core`, not `qbox`
- Would throw errors: "No such export GetPlayer in resource qbox"

**Fix:**
```lua
elseif framework == 'qbox' then
    -- QBox uses qbx_core resource with GetPlayer export
    local Player = exports.qbx_core:GetPlayer(playerId)
```

**Result:** Job permission checking now works correctly with QBox

---

### 3. QBox Server Framework Object (server.lua:38)

**Problem:**
```lua
elseif currentFramework == 'qbox' then
    -- QBox uses exports directly
    frameworkObject = exports.qbox  -- WRONG!
```

- Same issue as #2 - wrong export name
- Would cause all server-side QBox calls to fail

**Fix:**
```lua
elseif currentFramework == 'qbox' then
    -- QBox uses qbx_core resource
    frameworkObject = exports.qbx_core
```

**Result:** Server-side framework integration now works

---

## Technical Details

### Why QBox Detection Failed

1. **Resource Name Confusion:**
   - QB-Core uses: `qb-core`
   - QBX (QB-Core extended) uses: `qbx_core`
   - **QBox (new framework) also uses: `qbx_core`**

2. **Detection Order Issue:**
   - Original script checked for `qbx_core` and assumed QB-Core
   - QBox was checked second, but for wrong resource names
   - QBox servers would be detected as QB-Core

3. **Export Name Confusion:**
   - Script assumed QBox used `exports.qbox`
   - Actual QBox export is `exports.qbx_core`

### The Fix

**Priority-based detection:**
1. Check for ESX first (`es_extended`)
2. Check for **QBox second** (`qbx_core`) - **This is the key change**
3. Check for QB-Core third (`qb-core`)
4. Default to standalone

This ensures QBox servers are correctly identified before falling back to QB-Core detection.

---

## What Still Works

All original features are intact:

✅ **Multi-framework support** (ESX, QBCore, QBox, Standalone)
✅ **Auto-configuration system**
✅ **Job-based access control**
✅ **Grade restrictions** (Grade 4+ by default)
✅ **11+ pre-configured locations**
✅ **Custom livery support**
✅ **Vehicle modification system**
✅ **Performance upgrades**
✅ **Database integration**
✅ **Smart caching**

---

## Installation for DSRP

1. **Copy** `dsrp-emergencymenu` to resources folder
2. **Add to server.cfg:**
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure qbx_core
   ensure dsrp-emergencymenu
   ```
3. **Restart server** - Auto-configuration handles the rest

---

## Configuration

### Job Requirements (config.lua)

Default settings work for DSRP:
- **Police:** Grade 4+ (Officer level)
- **Fire:** Grade 4+ (Firefighter level)
- **Ambulance:** Grade 4+ (EMS level)

### Custom Zones

To add your own zones:
```lua
Config.ManualZones = true
Config.ManualModificationZones = {
    {
        name = "Custom Police Garage",
        coords = vector3(x, y, z),
        radius = 4.0,
        type = "police",
        requiredJob = "police",
        minGrade = 6,  -- Custom grade requirement
        jobLabel = "Sergeant"
    }
}
```

---

## Debugging

Enable debug mode in `config.lua`:
```lua
Config.Debug = true
```

You'll see console output like:
```
[AUTO-CONFIG]: Framework auto-configured as: qbox
INFO: QBox framework initialized on server
[AUTO-CONFIG]: Configured 11 modification zones
```

If you see `qbcore` instead of `qbox`, the detection fix didn't work - check resource order in server.cfg.

---

## Credits

- **Original Script:** DaemonAlex - Emergency Vehicle Menu v2.0.1
- **Bug Fixes:** DelPerro Sands RP Development Team
- **Framework:** QBox (qbx_core)
- **Libraries:** ox_lib, oxmysql

---

## Changelog

### v2.0.2-DSRP (DSRP Fixes)
- 🐛 Fixed QBox framework detection order
- 🐛 Fixed QBox player export calls (`exports.qbox` → `exports.qbx_core`)
- 🐛 Fixed server framework object initialization for QBox
- 📝 Updated fxmanifest metadata for DSRP
- 📖 Added comprehensive fix documentation

### v2.0.1 (Original)
- Zone optimization and performance updates
- Reduced zone sizes to 4m
- Fixed notification spam
- Repositioned zones to parking areas

---

## Support

For DSRP-specific issues:
- Check `Config.Debug = true` output
- Verify `qbx_core` is loaded before this resource
- Ensure you're running QBox framework (not QB-Core or QBX)

Original script issues:
- [GitHub Issues](https://github.com/DaemonAlex/EmergencyVehicleMenu/issues)