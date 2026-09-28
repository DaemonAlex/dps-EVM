## What this is

dps-carmenu (the vehicle browser) and dps-EVM (the workshop) are merged into
one resource, `dps-fleet`: one config, one ace, one panel (`F7` / `/fleet` for
Browse, `/evm` or the `ox_target` "Workshop" option for the workshop side).
Trunk gear (a fork of Vehiclegear) and a new per-model siren-tone assignment
section are folded in as well. Full detail in `README.md` and `CHANGELOG.md`.

### Added
- One panel for Browse and Workshop, sharing search/spawn/replace/beside,
  copy card, and favorites/recent on the Browse side, and every EVM section
  on the Workshop side.
- Trunk gear: department-based kits offered through `ox_target` on emergency
  vehicles, gated by job and (by default) by department.
- Sirens: a Workshop section to assign which tones LVC cycles through per
  model, with ready-made presets. dps-fleet owns the assignment in its own
  table (`fleet_siren_assignments`); the only change on the LVC side is a
  small, credited read-hook — no LVC code is copied.
- Copy card now includes a workshop line (livery/extras/colours/wheels/tint)
  once a live vehicle is selected.
- Drop-in install: Workshop access, trunk-gear vehicle list, and trunk-gear
  job list all auto-derive from `qbx_core` at start (`Config.AutoJobs`,
  `Config.TrunkGear.AutoVehicles`/`AutoJobs`), and the `dps.fleet` ace is
  self-granted to `group.admin`/`group.tester` (`Config.AutoAces`).

### Changed
- Commands: `/fleet` and `F7` open Browse; `/carmenu` and `/evm` are kept as
  aliases (`/evm` opens the Workshop on the current vehicle).

### Removed
- `legacy/` (pre-merge EVM source copies used during the port).
- The standalone Vehiclegear installation — folded into dps-fleet's trunk
  gear; it was never `ensure`d on this server, so no `server.cfg` change is
  needed for that removal.

### Fixed
- Trunk gear's logout hook now clears on the native Qbox event
  (`qbx_core:client:playerLoggedOut`) instead of a QBCore-only event that
  never fires under Qbox.

## Verify

- `lua5.4 tests/run.lua` — 206 passed, 0 failed.
- `luac5.4 -p client/*.lua client/**/*.lua server.lua shared/*.lua config.lua` — clean.
- Full `fx stop` / `fx start` on the live server: 449 `Started resource` lines
  (450 minus the now-benched standalone `vehiclegear`), 0 `SCRIPT ERROR` /
  `Error parsing` lines. `dps-fleet`'s own boot lines: fleet state loaded
  (617 models), emergency fleet index built (158 models), workshop database
  tables ready (including the new `fleet_siren_assignments`, and the
  `custom_liveries` unique-key migration), siren assignments loaded.
- In-game acceptance walk (client-only, handed to the server owner
  separately): F7 browse → spawn → Workshop → change livery + an extra → Esc
  → re-enter the car → livery kept; `/evm` on foot while targeting a car;
  mechanic on a civilian car; `unemployed` refused; Copy card shows the
  workshop line; no full-screen black background behind the panel.
