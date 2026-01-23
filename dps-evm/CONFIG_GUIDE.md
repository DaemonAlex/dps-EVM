# Emergency Vehicle Menu - Auto-Configuration Guide

## 🚀 Quick Start (Zero Configuration Required!)

The script now works **completely out of the box** with automatic configuration. Just install and it will:

- ✅ Auto-detect your framework (ESX, QBCore, QBox, or Standalone)
- ✅ Auto-configure modification zones at all major police/fire/medical stations
- ✅ Auto-detect emergency vehicles using multiple methods
- ✅ Auto-setup database tables and dependencies

**Simply start the resource and it works!**

## ⚙️ Auto-Configuration Features

### Automatic Framework Detection
The script automatically detects and configures for:
- **ESX** - Full job integration with police/ambulance/fire restrictions
- **QBCore/QBX** - Complete job system support
- **QBox** - Full compatibility
- **Standalone** - Location-only restrictions

### Automatic Zone Detection
Pre-configured modification zones at:
- **Police Stations**: Mission Row, Davis, Sandy Shores, Paleto Bay, Vespucci
- **Fire Stations**: Los Santos, Davis, Paleto Bay, Sandy Shores  
- **Hospitals**: Pillbox Hill, Sandy Shores Medical

### Automatic Vehicle Detection
Uses multiple methods to detect emergency vehicles:
1. Vehicle Class 18 (Emergency) - Most reliable
2. Emergency light detection
3. Common emergency vehicle model names
4. Expandable for custom vehicles

## 🎛️ Manual Override Options

Want custom settings? You can override any auto-configuration:

### Framework Override
```lua
Config.ManualFramework = true
Config.Framework = 'esx' -- Force specific framework
```

### Zone Override
```lua
Config.ManualZones = true
Config.ManualModificationZones = {
    {
        name = "My Custom Police Station",
        coords = vector3(100.0, 200.0, 30.0),
        radius = 25.0,
        type = "police"
    }
}
```

### Vehicle Detection Override
```lua
Config.ManualVehicleDetection = true
Config.ManualEmergencyVehicles = {
    "ambulance", "firetruk", "police", -- Standard vehicles
    "my_custom_police_car", -- Your custom vehicles
    "my_custom_ambulance"
}
```

### Feature Toggles
```lua
Config.EnabledModifications = {
    Liveries = true,            -- Standard liveries
    CustomLiveries = true,      -- Custom YFT liveries
    Performance = true,         -- Engine, brakes, transmission
    Appearance = true,          -- Colors, wheels, tint
    Neon = false,               -- Neon lights (disabled for performance)
    Extras = true,              -- Vehicle extras
    Doors = true                -- Door controls
}

Config.ShowBlips = true         -- Map blips for zones
Config.ShowMarkers = true       -- Ground markers
Config.EmergencyVehiclesOnly = true  -- Emergency vehicles only
```

## 🔧 Advanced Configuration

### Disable Auto-Configuration Entirely
```lua
Config.AutoConfigure = false
-- Then manually configure everything below
```

### Selective Auto-Configuration
```lua
Config.AutoDetectFramework = true   -- Auto-detect framework
Config.AutoDetectZones = false      -- Use manual zones
Config.AutoDetectVehicles = true    -- Auto-detect vehicles
```

### Debug Mode
```lua
Config.Debug = true  -- Enable detailed logging
```

## 📋 Configuration Priority

The script uses this priority order:

1. **Manual Overrides** (if enabled) - Highest priority
2. **Auto-Configuration** - Default behavior  
3. **Validation Fallbacks** - Safety nets if something fails

## 🛠️ Troubleshooting

### Script Not Working?
1. Check console for auto-config messages
2. Enable debug mode: `Config.Debug = true`
3. Verify dependencies (ox_lib, oxmysql) are started first

### No Zones Available?
Auto-config will create a default zone at Mission Row PD if none are found.

### Framework Not Detected?
The script will default to standalone mode and work with location-only restrictions.

### Custom Vehicles Not Detected?
Either add them to `Config.ManualEmergencyVehicles` or ensure they have Vehicle Class 18.

## 📝 Migration from Old Config

If upgrading from an older version:

1. **Backup your old config.lua**
2. **Replace with new auto-config version**  
3. **Add any custom zones/vehicles to manual override sections**
4. **Test thoroughly**

The new system is designed to work better than manual configuration while still allowing full customization when needed.

## 🎯 Best Practices

- **Leave auto-config enabled** for easiest maintenance
- **Only use manual overrides** when you need specific customization  
- **Enable debug mode** during setup to see what's being configured
- **Test with different frameworks** if you switch between them
- **Keep manual vehicle lists updated** when adding new emergency vehicles

## 📞 Support

If auto-configuration isn't working for your setup:
1. Enable debug mode and check console output
2. Verify all dependencies are properly installed
3. Check that framework resources start before this script
4. Report issues with full debug output