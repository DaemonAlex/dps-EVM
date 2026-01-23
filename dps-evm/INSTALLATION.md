# Installation & Upgrade Guide

## 🚀 **Fresh Installation (30 Seconds)**

### **Step 1: Download Dependencies**
Install these required resources first:
1. **ox_lib**: [Download](https://github.com/overextended/ox_lib)
2. **oxmysql**: [Download](https://github.com/overextended/oxmysql)

### **Step 2: Install Emergency Vehicle Menu**
1. Download the latest release from [GitHub](https://github.com/DaemonAlex/EmergencyVehicleMenu)
2. Extract to your `server-data/resources/` folder
3. Rename folder to `EmergencyVehicleMenu` (if needed)

### **Step 3: Server Configuration**
Add to your `server.cfg` in this exact order:
```cfg
# Dependencies (must be first)
ensure ox_lib
ensure oxmysql

# Emergency Vehicle Menu
ensure EmergencyVehicleMenu
```

### **Step 4: Database Setup**
**Nothing required!** The script automatically creates all necessary tables on first startup.

### **Step 5: Start Server**
Restart your server. That's it! The script will:
- ✅ Auto-detect your framework (ESX/QBCore/QBox/Standalone)
- ✅ Configure 11+ emergency service locations
- ✅ Setup job-based access control (Grade 4+)
- ✅ Create database tables automatically

## 🔄 **Upgrading from Version 1.x**

### **Important: Breaking Changes in v2.0.0**
Version 2.0.0 introduces major changes. Please follow this upgrade guide carefully.

### **Step 1: Backup Current Installation**
```bash
# Backup your current config
cp EmergencyVehicleMenu/config.lua EmergencyVehicleMenu/config.lua.backup

# Backup database (optional but recommended)
# Export custom_liveries and vehicle_mods tables
```

### **Step 2: Remove Old Version**
1. Stop your server
2. Delete the old `EmergencyVehicleMenu` folder
3. Remove any custom modifications you made

### **Step 3: Install New Version**
Follow the fresh installation steps above.

### **Step 4: Migrate Custom Settings**
If you had custom configurations:

#### **Custom Zones**
Old format:
```lua
Config.ModificationZones = {
    {
        name = "My Custom Station",
        coords = vector3(100.0, 200.0, 30.0),
        radius = 25.0,
        type = "police"
    }
}
```

New format:
```lua
Config.ManualZones = true  -- Enable manual override
Config.ManualModificationZones = {
    {
        name = "My Custom Station",
        coords = vector3(100.0, 200.0, 30.0),
        radius = 25.0,
        type = "police",
        requiredJob = "police",    -- NEW: Job requirement
        minGrade = 4,              -- NEW: Minimum grade
        jobLabel = "Police Officer" -- NEW: Display name
    }
}
```

#### **Framework Settings**
Old format:
```lua
Config.Framework = 'esx'
```

New format (only if you want to override auto-detection):
```lua
Config.ManualFramework = true  -- Disable auto-detection
Config.Framework = 'esx'       -- Force specific framework
```

#### **Custom Vehicles**
Old format:
```lua
-- Vehicles were hardcoded in IsVehicleEmergency function
```

New format:
```lua
Config.ManualVehicleDetection = true
Config.ManualEmergencyVehicles = {
    "ambulance", "firetruk", "police",
    "my_custom_vehicle"  -- Add your custom vehicles
}
```

### **Step 5: Test Configuration**
1. Enable debug mode: `Config.Debug = true`
2. Start server and check console for auto-config messages
3. Test with different job grades and locations
4. Verify all custom settings work correctly

## 🔧 **Framework-Specific Installation**

### **ESX Servers**
**No additional setup required!** The script automatically:
- Detects ESX resource
- Integrates with `users`, `jobs`, and `job_grades` tables
- Uses Steam identifiers for player identification
- Supports all ESX job grades and permissions

### **QBCore/QBX Servers**
**No additional setup required!** The script automatically:
- Detects QBCore or QBX resources
- Handles JSON job columns in `players` table
- Uses license identifiers (citizenid)
- Supports QBCore job grade structures

### **QBox Servers**
**No additional setup required!** The script automatically:
- Detects QBox resource via exports
- Accesses job/grade columns directly
- Uses license identifiers
- Integrates with QBox job system

### **Standalone Servers**
**Perfect for non-framework servers!** The script automatically:
- Enables location-only restrictions
- Disables job-based access control
- Works with any vehicle modification setup
- Provides full functionality without framework dependencies

## 🛠️ **Custom Configuration Examples**

### **Disable Auto-Configuration**
```lua
Config.AutoConfigure = false           -- Disable all auto-config
Config.ManualFramework = true          -- Manual framework
Config.ManualZones = true              -- Manual zones
Config.ManualVehicleDetection = true   -- Manual vehicles
```

### **Mixed Configuration**
```lua
-- Use auto-framework detection but manual zones
Config.AutoConfigure = true
Config.ManualFramework = false  -- Auto-detect framework
Config.ManualZones = true       -- Use custom zones
Config.ManualVehicleDetection = false -- Auto-detect vehicles
```

### **High-Security Setup**
```lua
-- Require higher grades for access
Config.ManualModificationZones = {
    {
        name = "LSPD Command Center",
        coords = vector3(454.6, -1017.4, 28.4),
        requiredJob = "police",
        minGrade = 8,  -- Command staff only
        jobLabel = "Command Staff"
    }
}
```

### **Multi-Job Zones**
```lua
-- Zone accessible by multiple emergency services
{
    name = "Emergency Services Hub",
    coords = vector3(0.0, 0.0, 0.0),
    radius = 50.0,
    allowedJobs = {"police", "fire", "ambulance"},
    minGrade = 3,
    jobLabel = "Emergency Personnel"
}
```

## 🐛 **Troubleshooting Installation**

### **Common Issues**

**1. Menu Not Opening**
- **Cause**: Not in a modification zone or insufficient job grade
- **Solution**: Check you're at a designated location with proper job/grade
- **Debug**: Enable `Config.Debug = true` to see zone checks

**2. Framework Not Detected**
- **Cause**: Resource start order or framework not properly loaded
- **Solution**: Ensure framework resources start before EmergencyVehicleMenu
- **Debug**: Check console for framework detection messages

**3. Job Not Recognized**
- **Cause**: Job name doesn't match expected format
- **Solution**: Add job mapping in `Config.JobMappings`
- **Example**: 
  ```lua
  Config.JobMappings = {
      police = {"police", "lspd", "bcso", "sheriff", "my_custom_police"}
  }
  ```

**4. Database Connection Issues**
- **Cause**: oxmysql not properly configured
- **Solution**: Verify oxmysql is installed and database credentials are correct
- **Check**: Ensure oxmysql starts before EmergencyVehicleMenu

**5. Grade Requirements Too High**
- **Cause**: Default Grade 4+ requirement too restrictive
- **Solution**: Lower grade requirements in zone configuration
- **Example**:
  ```lua
  {
      name = "Trainee Station",
      requiredJob = "police",
      minGrade = 0,  -- Allow all grades
      jobLabel = "Police Trainee"
  }
  ```

### **Debug Mode**
Enable comprehensive logging:
```lua
Config.Debug = true
```

This provides console output for:
- Framework detection and initialization
- Database table detection and queries
- Job validation and caching operations
- Zone access checks and permissions
- Performance metrics and error handling

### **Performance Issues**
If experiencing lag or slow responses:

1. **Enable Caching**:
   ```lua
   Config.CacheJobInfo = true
   Config.JobCacheTimeout = 300000  -- 5 minutes
   ```

2. **Reduce Zone Count**:
   - Use fewer modification zones for better performance
   - Increase zone radius instead of adding more zones

3. **Optimize Database**:
   - Ensure proper database indexing
   - Monitor oxmysql connection pool settings

## 📊 **Verification Steps**

After installation, verify everything works:

### **1. Console Checks**
Look for these messages in console:
```
[AUTO-CONFIG]: Framework auto-configured as: esx
[AUTO-CONFIG]: Configured 11 modification zones
[AUTO-CONFIG]: Emergency Vehicle Menu auto-configuration completed
```

### **2. In-Game Testing**
1. Join server with emergency job (Grade 4+)
2. Go to Mission Row Police Department garage
3. Enter an emergency vehicle
4. Press F7 or `/modveh` to open menu
5. Verify all modification options work

### **3. Job Testing**
Test with different scenarios:
- ✅ Correct job, sufficient grade → Menu opens
- ❌ Correct job, insufficient grade → Access denied message
- ❌ Wrong job, any grade → Access denied message
- ❌ No job, any grade → Access denied message

### **4. Framework Testing**
If using multiple frameworks, test each:
- ESX: Test with different ESX job structures
- QBCore: Test with QBCore job grades
- QBox: Test with QBox permissions
- Standalone: Test location-only access

## 🔄 **Maintenance**

### **Regular Tasks**
- **Monitor Logs**: Check for job system errors or database issues
- **Update Dependencies**: Keep ox_lib and oxmysql updated
- **Cache Cleanup**: Automatic, but monitor memory usage

### **Database Maintenance**
```sql
-- Clean old vehicle configurations (optional)
DELETE FROM vehicle_mods WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Optimize tables
OPTIMIZE TABLE custom_liveries, vehicle_mods;
```

### **Performance Monitoring**
Monitor these metrics:
- **Job Validation Time**: Should be <50ms for database queries
- **Cache Hit Rate**: Should be >80% for active players
- **Memory Usage**: Should remain <2MB total
- **Database Queries**: Should decrease over time as cache warms up

---

**Need help?** Check our [Troubleshooting Guide](JOB_SYSTEM_GUIDE.md) or create an [issue on GitHub](https://github.com/DaemonAlex/EmergencyVehicleMenu/issues).