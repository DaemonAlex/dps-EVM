# Upgrading from dps-EVM / dps-carmenu to dps-fleet

dps-fleet replaces both dps-EVM (2.4.x, the workshop) and dps-carmenu (2.x,
the vehicle browser) with one resource. Your data is kept; the commands you
already type still work.

## What's kept

- **Database tables** — `custom_liveries`, `vehicle_mods`, `vehicle_presets`,
  and `player_livery_memory` are unchanged: same names, same columns.
  dps-fleet reads and writes them exactly as dps-EVM did. One table is new,
  and starts empty: `fleet_siren_assignments`.
- **Commands** — `/carmenu` (dps-carmenu's command) and `/evm` (dps-EVM's
  command) both still work, as aliases. `F7` still opens Browse. `/fleet` is
  the new primary command for Browse; you don't have to switch to it.
- **Your saved presets, custom liveries, and livery memory** — nothing to
  migrate; they're the same rows in the same tables.

## Steps

1. **Stop the old resources.** `fx stop`, or at minimum
   `ensure`/`stop dps-EVM` and `stop dps-carmenu` if you `ensure` them
   individually. Never edit resource files under a running server.
2. **Remove the old `server.cfg` lines**, and any old aces:
   ```
   # remove:
   ensure dps-EVM
   ensure dps-carmenu
   add_ace group.admin dps.evm allow        # or whatever ace dps-EVM used
   add_ace group.admin dps.carmenu allow    # or whatever ace dps-carmenu used
   ```
3. **Add dps-fleet:**
   ```
   ensure dps-fleet
   add_ace group.admin dps.fleet allow
   add_ace group.tester dps.fleet allow
   ```
   (These two `add_ace` lines are optional — `Config.AutoAces = true`, the
   default, grants them itself at start if missing.)
4. **Bench, don't delete, the old resource folders** — move
   `dps-EVM/` and `dps-carmenu/` somewhere outside `resources/` (a `backups/`
   or `benched-<date>/` folder). If you had a standalone Vehiclegear
   resource, bench that too — its functionality is now dps-fleet's trunk
   gear.
5. **Keep the database as-is.** No SQL to run; dps-fleet creates
   `fleet_siren_assignments` itself on first boot alongside the four tables
   it already recognises.
6. **Start the server** (`fx start`) and check the boot log for
   `Started resource dps-fleet` and no `SCRIPT ERROR` lines mentioning it.
7. **New in dps-fleet, not in either old resource:** the Sirens Workshop
   section, and trunk gear on emergency vehicles via `ox_target`. Neither
   needs setup beyond what's already in `config.lua` and
   `data/emergency.json` — see the main [README](../README.md#config-reference)
   for every key if you want to change the defaults.

## If you customised the old configs

- Anything you changed in dps-EVM's `Config.EnabledModifications`,
  `Config.RepairCosts`, `Config.FieldRepair`, `Config.Presets`,
  `Config.AutoApplyLivery`, `Config.CustomLiveries`, `Config.InputValidation`,
  or `Config.Constants` has a same-named key in dps-fleet's `config.lua` —
  copy your values across.
- Anything you changed in dps-carmenu's search/grouping data has a
  counterpart in `shared/groups.lua` / `shared/search.lua`.
- If you had a manual job list instead of relying on auto-detection, set
  `Config.AutoJobs = false` and fill in `Config.JobMappings` (Workshop) and/or
  `Config.TrunkGear.AutoJobs = false` + `Authorizedjobs` (trunk gear) the way
  you had them before.

## Saved workshop rows from EVM 2.4

dps-fleet keys every workshop row (`vehicle_mods`, `vehicle_presets`, `player_livery_memory`, `custom_liveries`) by the vehicle's **spawn code**. EVM 2.4 keyed them by the in-game display name. For vanilla vehicles the two are the same word; for add-on vehicles whose display name differs (for example a display name of `JET` or `avro rj70`), the old rows are not matched and the player simply picks the livery or preset again once. No migration runs; nothing is deleted.

Custom livery texture dictionaries follow the same rule: name them `<spawncode>_<file>` (the `Config.CustomLiveries` key is the spawn code).
