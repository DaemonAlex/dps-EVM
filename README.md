# dps-fleet

**dps-fleet** is a Qbox-native FiveM resource that puts the vehicle browser and
the vehicle workshop on one panel. Press **F7** (or type `/fleet`) to search
every vehicle on the server — by group, department, kind, price, brand, or
free text — see its photo where one exists, spawn it, replace the car you're
in, or park it beside you. On the same panel, open the **Workshop** to change
liveries, extras, performance, colours, wheels, tint, neon, doors, windows,
seats, sirens, and to save presets or run a repair. Emergency vehicles also
carry **trunk gear** (vests, helmets, turnout coats, medical bags) that the
right department can pull out through `ox_target`.

dps-fleet is the merge of two older DPS resources — **dps-carmenu** (the
browser) and **dps-EVM** (the workshop, formerly Emergency Vehicle Menu) —
into one resource, one config, and one ace. If you ran either of those before,
see [Upgrading from dps-EVM / dps-carmenu](#upgrading-from-dps-evm--dps-carmenu).

![dps-fleet panel](docs/fleet-panel.png)
*(screenshot pending — drop Damon's capture in at `docs/fleet-panel.png`)*

---

## Features

### Browse

- **Search tokens** — type plain words, or narrow with `key:value` tokens:
  `cat:sports`, `dept:police`, `type:suv`, `brand:vapid`, `price>50000`,
  `speed<200`, `sort:price-desc`. Words like `cops`, `swat`, `ambulance`,
  `bikes`, `heli` are recognised shortcuts for the tokens above.
- **Groups, departments and kinds** — the fleet is organised the way people
  think about it: top groups (Street, Bikes, Racing, Emergency, Work, Air,
  Sea, Other) → categories within a group. The Emergency group instead groups
  by **department** (Los Santos Police Department, BCSO, SAHP, FIB, DOC, Fish
  & Wildlife, Coast Guard, Roxwood PD/SO, LSFD, RFD, SAMS, OMC, RMC) and then
  by **kind** (Cruiser, Unmarked, SUV / truck, Fire engine, Ladder truck,
  Ambulance, Helicopter, …). LSPD SWAT (`police_swat`) has its own row inside
  the Los Santos Police Department department.
- **Photos** — when [jg-vehiclestudio](#requirements) is installed, Browse
  shows its default vehicle photo for every model it has one for. No
  jg-vehiclestudio, no photos — everything else still works.
- **Spawn / Replace / Beside** — spawn a car fresh, replace the one you're
  sitting in (removes it first), or spawn one beside you without touching
  what you're in.
- **Copy card** — copies a plain-text "DPS VEHICLE CARD" (model, name,
  category, price, class, handling summary, and — once you've sat in or
  spawned the car — its current workshop state) for pasting into a ticket or
  an LLM.
- **Favorites and recent** — the last 15 vehicles you spawned, and anything
  you've starred, lead an empty search.

### Workshop

Open on the vehicle you're in, or via the **Workshop** option `ox_target`
adds to any vehicle. Sections (each can be switched off independently, see
[Config reference](#config-reference)):

| Section | What it does |
|---|---|
| Liveries | Every livery the model's `vehicles.meta` defines |
| Custom liveries | Custom YFT liveries you list in `Config.CustomLiveries` |
| Extras | Toggle every extra the model has (lightbars, pushbars, spots, …) |
| Performance | Engine, brakes, transmission, suspension, armour, turbo |
| Colours | Primary/secondary paint, from the full 161-colour GTA V list |
| Wheels | Wheel type and index |
| Window tint | The 7 stock tint levels |
| Neon | Colour + on/off (see `Config.UndercoverNeon` for selective use) |
| Doors | Open/close each door |
| Windows | Roll each window, or smash one for an EMS-style extraction |
| Seats | Eject an occupied seat |
| Presets | Save/load your own or a job-wide vehicle configuration |
| Sirens | Assign which tones LVC cycles through on this model |
| Repair | Emergency, full, or field repair, with pricing |

- **Presets** — save up to `Config.Presets.maxPresetsPerPlayer` personal
  presets, or (grade `minGradeForJobPresets`+) a shared job preset, up to
  `maxPresetsPerJob` per job.
- **Livery memory** — with `Config.AutoApplyLivery` on, the livery/extras you
  last set on a model are re-applied automatically the next time you get in
  one (or one spawns), no menu trip needed.
- **Sirens** — every tone LVC has installed (46 as of this release), grouped
  into ready-made sets (LEO/Whelen, Fire, EMS, RLS, PA, DX5, Sapphire, Smart
  Siren) or built by hand, 2–8 tones with slot 1 always the airhorn. dps-fleet
  owns the assignment; LVC (GPL-3, unmodified except for a small credited
  read-hook) owns the sound. See [Credits](#credits).
- **Repairs** — Emergency (quick), Full (station-grade), and Field (needs a
  repair item, has a cooldown) repair, each priced from `Config.RepairCosts`
  with a job discount or a free pass for mechanics.

### Trunk gear

Emergency vehicles listed in `data/emergency.json` can carry gear in their
trunk — a bulletproof vest, heavy vest, reflective vest, helmet, turnout coat,
fire helmet, or a medical bag — offered through `ox_target` to whichever job
is allowed to take that department's kit. See
[Config reference → Trunk gear](#trunk-gear) and
[Data files](#data-files).

---

## Requirements

| Resource | Required | Used for |
|---|---|---|
| [ox_lib](https://github.com/overextended/ox_lib) | yes | menus, callbacks, cache, progress bars |
| [qbx_core](https://github.com/Qbox-project/qbx_core) | yes | jobs, player data, vehicle spawning, the vehicle registry |
| [oxmysql](https://github.com/overextended/oxmysql) | yes | custom liveries, saved mods, presets, livery memory, siren assignments |
| [ox_target](https://github.com/overextended/ox_target) | yes | the "Workshop" option and trunk-gear options on vehicles |
| wasabi_carlock | optional | hands the player a key on spawn, if it's running |
| jg-vehiclestudio | optional | vehicle photos in Browse |

---

## Install

1. Copy the `dps-fleet` folder into your resources tree (on DPS: `[dps]/dps-fleet`).
2. Add one line to `server.cfg`, after `ox_lib`, `qbx_core`, `oxmysql` and
   `ox_target`:
   ```
   ensure dps-fleet
   ```
3. Grant the Browse ace. With `Config.AutoAces = true` (the default) the
   server grants it itself at start to `group.admin` and `group.tester` if
   they don't already have it — you'll see one `dps.fleet ace: …` line in the
   boot log confirming it. To grant it to another group, or to be explicit,
   add to `server.cfg`:
   ```
   add_ace group.admin dps.fleet allow
   add_ace group.tester dps.fleet allow
   ```
4. Nothing else. On first boot, dps-fleet creates its own five database
   tables if they don't exist (`custom_liveries`, `vehicle_mods`,
   `vehicle_presets`, `player_livery_memory`, `fleet_siren_assignments`) — no
   SQL file to import. `Config.AutoJobs = true` derives who may use the
   Workshop straight from your job list (see
   [Permissions](#permissions)) — no job list to edit either.
5. *(Optional)* If you run a registry tool that produces a
   `vehicles_found.json` fleet listing, copy or symlink it to
   `data/fleet_state.json` (DPS does this automatically at server start via
   `registry-refresh.sh`) so Browse shows real pack, price and photo data
   instead of treating every model as vanilla. This file is git-ignored —
   it's expected to be missing on a fresh checkout; Browse still works
   without it.

---

## Config reference

Every `Config.*` key lives in `config.lua`, grouped the same way the file is.

### Job access control

| Key | Default | Meaning |
|---|---|---|
| `EnableJobRestrictions` | `true` | `false` opens the Workshop to everyone, no job check |
| `AutoJobs` | `true` | Derive the Workshop job set at start from `qbx_core:GetJobs()` — every job of type `leo` or `ems`, plus `ExtraWorkshopJobs` |
| `ExtraWorkshopJobs` | `{ 'mechanic' }` | Extra job names added to the auto-derived set (jobs that aren't typed `leo`/`ems` but should still get the Workshop) |
| `AutoAces` | `true` | Grant the `dps.fleet` ace to `group.admin` and `group.tester` at start if either is missing it |
| `JobMappings` | `{ police = {...}, fire = {...}, ambulance = {...}, mechanic = {...} }` | **Only read when `AutoJobs = false`.** Manual group → job-names map; group keys, not job names |
| `EnableGradeRestrictions`, `DisableZoneRestrictions`, `ManualJobSystem` | `false`, `true`, `true` | Carried over from dps-EVM; not read anywhere in the current code — reserved |
| `JobDefaults` | `enabled = true`, plus a `police`/`fire`/`ambulance` sub-table each with `defaultColors`, `suggestedNeonColor`, `priorityExtras`, `showNeon` | Carried over from dps-EVM; not read anywhere on this branch — reserved |

### Feature toggles

| Key | Default | Meaning |
|---|---|---|
| `EnabledModifications.*` | all `true` except `Neon` | 10 flags gate the Workshop's 14 sections (`Liveries`, `CustomLiveries`, `Performance`, `Appearance` covers Colours/Wheels/Window tint, `Neon`, `Extras`, `Doors` covers Doors/Windows/Seats, `Repair`, `Sirens`, `Presets`) — `false` removes that section (or that whole trio, for `Appearance`/`Doors`) from the menu |
| `UndercoverNeon.enabled` | `false` | `true` lets neon show on specific vehicles even while `EnabledModifications.Neon` is off |
| `UndercoverNeon.allowedVehicles` | `{}` | Spawn codes allowed neon under the rule above |

### Economy / repair costs

| Key | Default | Meaning |
|---|---|---|
| `RepairCosts.enabled` | `true` | `false` makes every repair free |
| `RepairCosts.chargeFrom` | `'bank'` | `'bank'`, `'cash'`, or `'both'` (bank first) |
| `RepairCosts.currency` | `'money'` | Unused/reserved — `chargeFrom` is what the code actually reads |
| `RepairCosts.fullRepairCost` / `emergencyRepairCost` / `fieldRepairCost` | `500` / `200` / `350` | Base price per repair kind, charged server-side (client-supplied cost is never trusted) |
| `RepairCosts.freeForJobs` | `{ 'mechanic' }` | Jobs that repair for free |
| `RepairCosts.discountJobs` | every LEO/fire/medical job at `0.25` | Per-job discount list |

### Field repair

| Key | Default | Meaning |
|---|---|---|
| `FieldRepair.enabled` | `true` | Switches the whole feature off |
| `FieldRepair.requireItem` / `itemName` / `alternativeItems` | `true` / `'repairkit'` / `{repairkit, toolkit, mechanickit, advanced_repairkit}` | The `ox_inventory` item needed; any name in the alternatives list also works |
| `FieldRepair.allowedJobs` | every LEO/fire/medical job | Jobs that may field-repair (mechanics aren't listed — they reach repair through the Workshop, which their job set already opens) |
| `FieldRepair.minGrade` | `0` | Minimum job grade required (`0` = any grade) |
| `FieldRepair.maxEngineRepair` | `350.0` | Engine health cap a field repair can reach |
| `FieldRepair.cooldown` | `300000` (5 min) | Per-player cooldown between field repairs |
| `FieldRepair.consumeItem` | `true` | Removes the item after use |
| `FieldRepair.repairTime` | `15000` | Progress-bar duration, ms |

### Presets

| Key | Default | Meaning |
|---|---|---|
| `Presets.enabled` | `true` | Switches the feature off |
| `Presets.maxPresetsPerPlayer` | `10` | Personal preset cap |
| `Presets.maxPresetsPerJob` | `5` | Shared job-preset cap |
| `Presets.allowJobPresets` | `true` | Lets a high-enough grade save a job-wide preset |
| `Presets.minGradeForJobPresets` | `3` | Grade needed to save (or delete another player's) job preset |
| `Presets.saveToDatabase` | `true` | Presets persist in `vehicle_presets` |
| `Presets.maxPresetBytes` | *(not in `config.lua`)* | Optional — `server.lua` reads it and falls back to `16384` bytes when it's absent, so a preset's saved size is capped either way |

### Auto-apply livery (livery memory)

| Key | Default | Meaning |
|---|---|---|
| `AutoApplyLivery.enabled` | `true` | Switches the feature off |
| `AutoApplyLivery.applyOnSpawn` | `true` | Re-apply your last livery/extras when the model spawns |
| `AutoApplyLivery.applyOnEnter` | `false` | Re-apply when you get in (alternative to the above) |
| `AutoApplyLivery.rememberPerVehicle` | `true` | Memory is keyed per vehicle model |
| `AutoApplyLivery.rememberExtras` | `true` | Extras are remembered along with the livery |
| `AutoApplyLivery.notifyOnApply` | `true` | Shows a notification when memory is applied |

### Custom liveries

`Config.CustomLiveries` — keys are **vehicle spawn codes**, not job names
(e.g. `police`, `ambulance` — the vanilla models). Each entry is a list of
`{ name, file }` custom YFT liveries for that model. Add your own vehicles
and files here.

### Input validation

| Key | Default | Meaning |
|---|---|---|
| `InputValidation.maxNameLength` / `minNameLength` | `32` / `1` | Preset/livery name length bounds |
| `InputValidation.allowedCharacters` | `^[%w%s%-_]+$` | Pattern a name must match |
| `InputValidation.sanitizeNames` / `blockSpecialChars` | `true` / `true` | Sanitisation switches |

### Constants

`Config.Constants` — only `ENGINE_MAX_FIELD_REPAIR` (`350`, the field-repair
engine-health cap) is read by the current code. The rest of this table
(`DAMAGE_*`, `ENGINE_HEALTHY`, `COOLDOWN_*`, `ZONE_CHECK_INTERVAL`,
`MARKER_FADE_*`, `CACHE_*`) is carried over from dps-EVM and currently unused
— reserved, do not expect it to change behaviour.

### Trunk gear

`Config.TrunkGear` — "make it as auto as possible" applies here too:

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `true` | One switch for the whole feature |
| `AutoVehicles` | `true` | Every model in `data/emergency.json` carries its department's kit automatically — a new emergency pack needs no edit here |
| `allowedVehicles` | `{}` | Per-model override, read whether `AutoVehicles` is on or off; with it off, this list is the *only* source |
| `DeptGear` | police/bcso/sasp/fib/doc/dfw/rpd/rcso/uscg → vest+helmet kit; `police_swat` → heavy kit; `lsfd`/`rfd` → turnout kit; `sams`/`omc`/`rmc` → medbag kit | Department → kit, keyed by the `dept` values in `data/emergency.json` |
| `DefaultGear` | `{ 'refvest' }` | Kit for a model that's in `data/emergency.json` but whose department isn't in `DeptGear` (`none`/`unsorted` rows — coroner vans, tow trucks) |
| `AutoJobs` | `true` | Re-uses the Workshop job set (LEO + EMS types + `Config.ExtraWorkshopJobs`) so a new department needs no edit |
| `Authorizedjobs` | `{ police, bcso, sasp, fib, doc, dfw, rpd, rcso, uscg }` | **Only read when `AutoJobs = false`** |
| `CrossDept` | `false` | `false`: an allowed job may only take **its own family's** department kit (police can't pull turnout gear from a fire engine); `true`: any allowed job can take any department's kit |
| `DeptJobs` | one list per department (see `config.lua`) | Which job names may take that department's kit; a department left out is open to any allowed job |
| `RequireUnlocked` | `true` | The vehicle must be unlocked to open its trunk |
| `RequireItems` | `true` | Item-backed gear (`bproof`, `medbag`) must actually be in the trunk |
| `NotifyDuration` | `5` | Notification duration, seconds |
| `Duration` | `3500` | Progress-circle duration, ms |
| `Sound` | `{ Enable = false, ... }` | Optional sound on pickup |
| `Gear` / `GearOrder` | 7 pieces (`bproof`, `heavy`, `refvest`, `helmet`, `turnout`, `firehelmet`, `medbag`) | The gear catalogue and its menu order — set a piece to `false` to switch it off entirely |
| `Slots` / `SlotOrder` | vest / torso / head | The "put it back" options, one per body slot |
| `Translation` | — | User-facing strings |

---

## Permissions

| What | Gate | Notes |
|---|---|---|
| **Browse** (F7 / `/fleet` / `/carmenu`) | ace `dps.fleet` | Granted automatically to `group.admin`/`group.tester` when `Config.AutoAces = true` |
| **Workshop** (any section) | job-based, not ace-based | Allowed set comes from `Config.AutoJobs` (qbx job types `leo`+`ems` + `Config.ExtraWorkshopJobs`), or `Config.JobMappings` when `AutoJobs = false` |
| **Workshop admin bypass** | ace `command` | Any player holding the FiveM `command` ace (normally `group.admin`) can open the Workshop on any vehicle regardless of job |
| **Trunk gear** | job-based (+ department) | `Config.TrunkGear.AutoJobs` re-uses the Workshop job set; `CrossDept = false` also requires the job to be listed for that vehicle's department in `DeptJobs` |

---

## Commands and keys

| Command / key | Opens |
|---|---|
| `F7` | Browse |
| `/fleet` | Browse |
| `/carmenu` | Browse (alias, kept for muscle memory) |
| `/evm` | Workshop, on the vehicle you're in or targeting (alias) |
| `ox_target` → **Workshop** | Workshop, on that vehicle |
| `ox_target` → trunk-gear options | Take or stow a piece of gear, on an emergency vehicle that carries it |

---

## Data files

- **`data/emergency.json`** *(committed)* — `{ "modelname": { "dept": "policename", "kind": "Cruiser" } }` for every emergency vehicle model (lowercase spawn name as the key). `dept` must already exist in `qbx_core/shared/jobs.lua` (or be `police_swat` for the tactical fleet, or `none`/`unsorted` for a vehicle with no department yet). `kind` is a display bucket (`Cruiser`, `Unmarked`, `SUV / truck`, `Motorcycle`, `Tactical`, `Command`, `Fire engine`, `Ladder truck`, `Brush truck`, `Rescue`, `Ambulance`, `Van`, `Helicopter`, `Boat`). This file drives three things: Browse's Emergency department/kind grouping, `Config.TrunkGear`'s `AutoVehicles` resolution, and the trunk-gear index.

  **To add a department:** add each of its models to `data/emergency.json` with the real job name as `dept`; add friendly labels for it to `Groups.DEPT_ORDER`/`DEPT_NAME`/`DEPT_CODE` in `shared/groups.lua` (cosmetic — Browse falls back to the raw key if you skip this); and, if it should hand out trunk gear, add its kit to `Config.TrunkGear.DeptGear` (and, if `CrossDept = false`, to `DeptJobs`) in `config.lua`.

- **`data/fleet_state.json`** *(git-ignored, not shipped)* — a copy of the fleet registry tool's `vehicles_found.json` output, dropped in by `registry-refresh.sh` at server start on this server. Optional: without it, every vehicle in Browse shows as vanilla (no pack, price, or photo metadata) instead of erroring.

---

## Performance notes

dps-fleet runs no `CreateThread` loops. The only thread in the whole
resource is a one-shot startup task that reads `data/fleet_state.json` and
`data/emergency.json`, ensures the database tables exist, and grants aces —
then it ends. Everything else is event- or callback-driven: the panel opens
on request, `ox_target` registers its options once when it starts (not
polled), and model-native reads (top speed, handling) happen once per
selection — debounced while you scroll — and the model is released right
after. Photo URLs from `jg-vehiclestudio` are fetched once per server run and
cached. Measured with the panel closed: 0.00 ms; open: ≤ 0.10 ms (`resmon`).

---

## Upgrading from dps-EVM / dps-carmenu

Short version: your data is kept, your commands still work. Full steps in
[docs/UPGRADING.md](docs/UPGRADING.md).

- Database tables `custom_liveries`, `vehicle_mods`, `vehicle_presets`, and
  `player_livery_memory` are unchanged — dps-fleet reads and writes them
  under the same names. One table is new: `fleet_siren_assignments`.
- `/carmenu` and `/evm` still work, as aliases. `F7` is unchanged.
- Remove `ensure dps-EVM` and `ensure dps-carmenu` from `server.cfg`, add
  `ensure dps-fleet`. Bench (don't delete) the old resource folders.

---

## Credits

- **Original EVM** (Emergency Vehicle Menu / dps-EVM) and **original
  dps-carmenu** — both by DaemonAlex. dps-fleet is their merge.
- **Luxart Vehicle Control (LVC)**, by **Lt.Caine** and
  **TrevorBarns** — GPL-3. dps-fleet copies no LVC code: the Sirens section
  and its `fleet_siren_assignments` table are entirely dps-fleet's own; the
  only LVC-side change is a small, credited hook inside LVC's own files that
  lets it read the tone list dps-fleet assigns. LVC's license stays with LVC.
- **Vehiclegear**, originally by **Lapertaja** (CC BY-NC-SA 4.0) — the
  trunk-gear feature is DaemonAlex's fork of Vehiclegear, folded into
  dps-fleet. The original license text is kept at
  [docs/licenses/vehiclegear.txt](docs/licenses/vehiclegear.txt) for
  attribution.
- **JG Vehicle Studio** — the source of Browse's vehicle photos, when
  installed.

## License

MIT — see [LICENSE](LICENSE). Third-party pieces keep their own license; see
Credits above.
