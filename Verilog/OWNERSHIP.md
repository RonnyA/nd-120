# Ownership map — who may edit what

Several people and several parallel sessions work in this tree at once. The
boundaries below are not style preferences; crossing them has repeatedly
destroyed someone else's in-flight work.

Check this file before editing anything outside the area you were asked about.

| Path | Owner | Rule |
|---|---|---|
| `Verilog/runSim/` | Ronny | **Do not edit.** Not `Run120.cpp`, not its `Makefile`. Instrumentation belongs in `Verilog/sim/` instead. |
| `Verilog/sim/nd120_probe.*` | shared with a concurrent session | Do not edit without coordinating. Another session drives these probes; concurrent edits corrupt each other's traces. |
| `Verilog/PAL/PAL_*.v` | the original design documents | Change only when a PALASM listing proves the Verilog wrong. Never to make a symptom go away. See `Verilog/PAL/PROVENANCE.md` and run `make test-pal-provenance`. |
| `Verilog/ND-BUS-DEVICES/SMD/` | handed off to another session | `ND_SMD.v` and `nd_storage_disc_adapter.v` are owned elsewhere. Report findings, do not edit. |
| `Verilog/sim/`, `Verilog/runSim/` locations | Ronny | These directories stay where they are. Do not propose moving them. |
| anything under `Verilog/tests/vivado_warning_fixes/` | legacy | Do not add to it. New testbenches go in the module's own `sim/`. |

## Related hard rules

These live outside this repo but bite work done here.

- **nd100x**: the only clone that may be edited, built or committed is
  `~/repos/nd100x` in WSL. Any other checkout — in particular one under a
  Windows drive — is off limits, whatever it contains.
- **Never create branches or commits** without being asked. Edit files and
  report; the git state is Ronny's call.
- **Never kill a process** you did not start in the current session.
- **No root-anchored paths in committed files.** No drive letters, no
  `/mnt/...`, no `/home/...`, in scripts, Makefiles, config, source, tests or
  documentation. Scripts derive the repo root from their own location. If a
  file outside the repo is needed, either copy it in or use an environment
  variable.

## Long-running and destructive actions

Full synthesis runs, full Verilator rebuilds, running the simulator, and
anything that wipes build state (`obj_dir`) are Ronny's call, not a step to
take unprompted. A project rule such as "always compile before reporting
success" covers compiling what you just changed — it does not authorise
rebuild sweeps, flag changes, or executing the machine.

Only one Verilator build or simulation may run at a time; concurrent `obj_dir`
builds corrupt each other. Same for Gowin builds.

## Board handling

After **every** `openFPGALoader` operation the Tang Nano 20K must be
power-cycled, and after every power-cycle it must be re-attached to WSL with
`usbipd` — the bus id changes each time, so it has to be looked up again rather
than assumed.

## When a boundary is unclear

Ask before editing, not after. A one-line question costs less than a lost
afternoon of someone else's work.
