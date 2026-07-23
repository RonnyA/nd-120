# HANDOFF — CGA_INTR async-latch masked-grant analysis (Tang Nano 20K silicon)

> **ANSWERED 18-JUL-2026.** Root cause found (trap-unit vector-17 misclassification,
> NOT an async latch in the mask/claim cone) and RTL fix implemented; see
> `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/ANALYSIS-cga-intr-masked-grant-root-cause.md`.
> Silicon re-test still pending (that doc, §5).

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/HANDOFF-cga-intr-masked-grant-analysis.md`
**Written:** 18-JUL-2026, after the S3 vector-claim fix was proven insufficient on silicon.
**Repo root:** `/mnt/e/Dev/Repos/Ronny/nd-120`  (branch `clock-enable-fix`)
**Audience:** a fresh analyst with no prior context. Everything below is grounded in
measured evidence or source; where something is inferred it is labelled INFERRED.

---

## 1. The mission (one line)

Find why the ND-120 interrupt controller **grants a masked level-10 interrupt on
Tang Nano 20K (Gowin GW2AR-18C) silicon** during cold start — a switch to PIL=10
with the level disabled — when the zero-delay Verilator simulation **never** does.
Then propose an RTL fix that is verifiable (sim regression + a silicon re-test).

This is the single open blocker to booting the ND-120 CPU on the Tang. Every
reported Tang hang (`0!`, `400$` autostart, RUN / BYTE-STRING / STACK / SEGMENT,
CONFIGURATION list-all-devices) traces to this one grant: it parks the running
level and switches the CPU into a stale level-10 register bank (garbage P), from
which it never returns.

---

## 2. Ground truth — the measured event (do not re-derive, this is fact)

Measured 18-JUL on the physical Tang over the OPCOM console (`/dev/ttyUSB1`,
9600 8N1), on the **correctly-flashed fixed bitstream**
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/build/nd120_tang20k_build/impl/pnr/ao_0.fs`.

Method: btn1 (clean Master Clear, keeps SDRAM) → software `MACL` → deposit P=0
(the `0!` cold-start entry) → single-step (`Z`), reading the internal-register
dump (`IRD`) each step. Single-stepping (never free-running) is mandatory — a
free-run to a breakpoint wedges the console before the event.

```
step  1..17 : STS = 010040   PIL = 0           (clean, running level 0)
step   18   : STS = 015000   PIL = 10   PIE=0  PID=002000   <-- MASKED GRANT
after       : 12P (level-10 P) = 054564         (level-10 context now executing)
```

- `STS 015000` octal → bits 8..11 (PIL) = 10 (octal 12). Confirmed by hand.
- `PIE = 000000` — no level is enabled in the microcode's PIE scratch.
- `PID = 002000` octal = bit 10 set — a level-10 request IS pending.
- So: **a pending-but-not-enabled level-10 request produced a vector claim and a
  PIL switch.** The Am2914 must not do this.

The Verilator simulation, stepped the same way against the same microcode, stays
at PIL=0 for thousands of instructions. **Sim is the reference / truth. Silicon
diverges. That divergence is the bug.**

Reproduce it yourself with:
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/scratch_piltrace.py`
(paced single-step tracer; read its header for the OPCOM protocol rules).
Console command reference:
`/home/ronny/.claude/skills/nd120-fpga/references/opcom-commands.md`.

---

## 3. Why the simulation cannot help you (critical framing)

The RTL is **zero-delay** Verilog. This grant is a **real-timing effect** on
Gowin — an asynchronous-latch race / combinational glitch that only exists once
gates and routing have real propagation delays. Consequences:

- You CANNOT reproduce this in the normal Verilator or iverilog RTL sim. It will
  show correct behaviour (PIL=0) no matter what you do — that is exactly why the
  bug survived every sim gate.
- Therefore a fix "proven in sim" only proves it did not *break* the reference
  behaviour; it does NOT prove it *cures* the silicon grant. The only proofs of
  a cure are: (a) a silicon re-test (§2 method), (b) a GAO capture of the grant
  net, or (c) a **Gowin post-PnR gate-level sim with SDF timing back-annotation**
  (real delays) — the one simulation that could actually exhibit the race.
- Design the fix to be *structurally* robust (no async latch in the claim/grant
  path, no combinational feedback, clean synchronous capture), not to make a
  zero-delay waveform change.

Designer's standing note (from project memory `[[hw-timing-vs-verilog]]`): our
zero-delay Verilog legitimately differs from the real ASIC+TTL signal speeds;
phase mismatches can be timing-model artefacts. Here the artefact is load-bearing.

---

## 4. What has already been tried and RULED OUT (do not repeat)

1. **S3 vector-claim enable-FF gate (THE failed fix).** The hypothesis was that
   the vector-claim outputs HVE/LVE were missing an interrupt-request-enable term.
   Added it:
   - `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v`
     `GATES_7`: `AND_GATE` → `AND_GATE_3_INPUTS`, added `.input3(s_int_req_qn)` → `s_hve_out`.
   - `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_LORL.v`
     `GATES_4`: same, added `.input3(s_int_req_enable_q_n)` → `s_lve_out`.
   Built into `ao_0.fs` (verified: bitstream mtime 18:56 > source mtime 18:50).
   **Result: masked grant STILL fires (§2). Insufficient.** These edits are
   UNCOMMITTED — decide whether to keep, revert, or supersede.
   **NETLIST CHECK DONE 18-JUL (answers the "optimised away vs wrong" question):**
   the fix is **present in the gates, not optimised away** — the post-synth
   netlist
   `.../build/nd120_tang20k_build/impl/gwsynthesis/nd120_tang20k_build.vg`
   keeps `s_int_req_qn`, `s_int_req_enable_q`, `s_hve`, `s_hidis_n` (the
   `syn_keep` pragmas held), and `s_int_req_enable_q` is wired into the
   interrupt OR-logic (a `LUT4` feeding net `n9_5`). So the S3 gate is
   present-but-**ineffective** ⇒ **the grant does NOT come (solely) through the
   HVE/LVE vector-claim S3 gated.** Look elsewhere (§5). Concrete lead found in
   the same netlist: the **PICV level-code** `s_picv_2_0_out` (which drives the
   PIL switch) is combinational — `LUT4` INIT=`16'hF888` over inputs
   `s_lve, s_hve, n10_3` (and `n6_3` variants), i.e. a glitch on `s_hve`/`s_lve`
   or those intermediate nets directly perturbs which level is claimed. Trace
   what makes `s_hve`/`s_lve` (or `n10_3`) transiently assert for level 10 when
   the mask is closed.

2. **RQBIT async SR-latch → V2 (committed `9d5a1cb`).** The per-level request
   bit `CGA_INTR_CNTLR_IRQ_REG_RQBIT.v` was an async set/reset latch; it was
   replaced by a loop-free sysclk "catcher-FF" version
   `CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2.v`. This removed all 22 combinational loops
   the OSS (yosys/nextpnr) flow reported. KEY LESSON captured in memory
   `[[rqbit-v2-loop-free]]`: the async latch was **load-bearing** — it caught
   1-sysclk PID-write pulses that land *between* MCLK edges on levels 0-3,14,15;
   a naive FF loses them, so V2 uses a sysclk catcher-FF. **Only RQBIT got V2.
   Its neighbours in the grant path did not.** ← prime suspect, see §5.

3. **Status-fence / FIDBO-swap / MOR bugs** — all separate, already fixed
   (commits `3acef36`, and the fence is RTL default). Not this bug.

Full ranked-suspect writeup from the first pass:
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/tang-masked-grant-audit.md`.

---

## 5. The leading hypothesis (where to look first)

**A remaining asynchronous latch in the CGA_INTR grant/mask path glitches on
Gowin the way RQBIT did before V2.** The grant is: a pending request survives the
mask, reaches the priority/vector logic, and asserts a vector-claim that a latch
captures as a level switch — transiently, on a real-delay edge that zero-delay
sim collapses to nothing.

Trace this path end-to-end and find every async latch / combinational feedback
in it. The modules (all under
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/`):

| Stage | File | What it does |
|---|---|---|
| request bits | `CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2.v` (+ `_RQBIT.v` old) | per-level pending FF (already V2) |
| request reg | `CGA_INTR_CNTLR_IRQ_REG.v` | assembles the 16 request bits |
| mask | `CGA_INTR_CNTLR_IRQ_MASK.v`, `_MASK_MASKBIT.v` | per-level enable mask (the Am2914 mask register) |
| masked request | `CGA_INTR_CNTLR_IRQ_MREQ.v` | request AND mask → the thing that may claim |
| request wrapper | `CGA_INTR_CNTLR_IRQ.v` | ties REG+MASK+MREQ together |
| priority/claim HI | `CGA_INTR_CNTLR_IRGEL_HIRL.v`, `_HIGEL.v` | high-group vector-enable (HVE), the enable FFs |
| priority/claim LO | `CGA_INTR_CNTLR_IRGEL_LORL.v`, `_LOGEL.v` | low-group vector-enable (LVE) |
| vector mux | `CGA_INTR_CNTLR_IRGEL_VMUX.v`, `CGA_INTR_CNTLR_IRGEL.v` | selects the winning vector |
| decode | `CGA_INTR_CNTLR_MDCD.v` | mask/level decode |
| vector gen | `CGA_INTR_CNTLR_VECGEN*.v` (CMP, STAT, PTY, VHR, ISMUX/OSMUX) | builds vector + status |
| clear | `CGA_INTR_CNTLR_CLR.v`, `_CLR_CLRBIT.v` | request clear on grant |
| top | `CGA_INTR_CNTLR.v`, `CGA_INTR.v`, `CGA_INTR_IRSRC.v` | wiring, MORN, IRSRC bit map |

Specific questions to answer:
1. In `IRQ_MASK` / `MREQ` / `IRGEL_*`, is any latch **level-sensitive on a routed
   signal** (transparent `LATCH.v` instance, or an async set/reset), rather than a
   clean `SCAN_FF_EN` capture on `sysclk` gated by `MCLK_EN`? List each one.
2. Can a **pending level-10 request whose mask bit is closed** produce even a
   transient high on the HVE/LVE claim or on the PIL-load enable? Follow every
   combinational path from `MREQ`/`RQBIT` to the register-bank / PIL switch.
3. Where does the actual **PIL load** happen (the level switch that set STS→015000)?
   Is its enable a clean synchronous term, or does it ride a latch that can catch a
   glitch? (The PIL/level register lives with the microcode / status path — see how
   `CGA_INTR` drives it and where the level-switch strobe originates.)
4. Apply the **RQBIT-V2 pattern** to whichever latch is implicated: replace the
   async latch with a sysclk catcher-FF that preserves the load-bearing
   pulse-catch semantics (do NOT naively convert — you will drop sub-MCLK pulses,
   see §4.2).

---

## 6. Ground-truth reference model (the Am2914 semantics)

The behavioural reference for the Am2914 priority interrupt controller is the C#
emulator, which matches the ND-110/ND-120 hardware behaviour:
`/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/AMD/Amd2914PIC.cs`
(the grant/status logic is around lines 950-977; read the whole class).

Established facts from that source (project memory `[[intr-verilog-is-truth]]`
notes a nuance: for *design structure* the DELILAH schematic RTL outranks the C#
INTR, but for *command semantics* the C# is the behavioural reference):
- `PIC,MCL` (master clear) leaves the **mask all-ENABLED** and the
  interrupt-request-enable FF **ON**.
- **PIE (internal register I7) is a microcode-held scratch value, NOT the Am2914
  hardware mask.** So "PIE=0" at the grant does not by itself mean the hardware
  mask was closed — but the *sim* with identical microcode does not grant, so the
  divergence is real regardless of PIE semantics. Keep this distinction straight:
  the hardware gate that should have blocked the claim is the Am2914
  mask/int-req-enable path, not PIE.
- A claim after `DISIN`/`IOF` must not fire even with requests pending and the
  mask open, because the int-req-enable FF is off. (This is what S3 tried and
  failed to enforce at the HVE/LVE stage — so either the enforcement point is
  wrong, or a glitch bypasses it.)

IRSRC / RQBIT bit-map and RQBIT latch semantics: see memory `[[intr-verilog-is-truth]]`
and the RQBIT files. Interrupt level meanings: 10=termout, 11=disk, 12=termin,
13=clock, 14=traps/MON, 15=fast HW (so a spurious **level-10** = terminal-output
interrupt granted while masked).

---

## 7. Constraints you must respect (project rules)

- **Inside the FPGA, `z` does not work.** 3-state buffers must drive 0 when
  disabled, never `z` (see `TTL_74245/244/241`, `AM29841`, `AM29861A`).
- **FF-mode is the FPGA target.** `FPGA_FF_MODE` forces edge-triggered behaviour;
  `USE_LATCHES=0` selects it. The MCLK-domain registers capture on `posedge
  sysclk` gated by `MCLK_EN` (aligned to the MCLK rise), NOT on the routed MCLK
  net. Any new register you add in the grant path must follow this pattern
  (`SCAN_FF_EN #(.USE_ENABLE(MCLK_CE))` with `sysclk`+`EN`), see the existing FFs
  in `IRGEL_HIRL.v` / `IRGEL_LORL.v`.
- The Logisim schematics are the source for most of this Verilog. Keep new code
  compatible with the generated structure; note any Logisim-regeneration hazard
  you introduce (there is a hazard list in `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/TODO.md`).
- Do not use LINQ (C# side) or introduce unicode into anything that feeds the
  1980s C/assembler toolchain (not relevant to RTL, but a global rule).
- These are silicon-only changes; **land them behind a clear escape hatch/`ifdef`
  only if asked** — the owner prefers single-version RTL with a one-line comment
  (precedent: the FIDBO-swap and status-fence fixes went in straight-through).

## 8. Verification plan for any proposed fix

1. **Sim regression (necessary, not sufficient):** the fix must keep the
   reference behaviour byte-identical. Run the CGA_INTR/CGA_TRAP unit suite
   (31 tbs incl. the Am2914 command-sequence functional tbs) and the full
   `make test` / `make test-full` from `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog`.
   Handoff for those tbs:
   `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/HANDOFF-interrupt-trap-testbenches.md`.
   Remember §3: sim CANNOT show the cure, only the absence of regression.
2. **Structural check:** confirm no async latch / combinational loop remains in
   the grant path — OSS flow (`make gowin` via yosys) reports combinational loops
   explicitly; Vivado/Basys3 `report_drc`+synth warnings enumerate inferred
   latches (board-independent structural signal, even though Vivado can't build
   for Gowin).
3. **Silicon cure test (the only real proof):** rebuild the Gowin bitstream,
   flash, and re-run the §2 single-step trace. PIL must stay 0 through the cold
   start. Optionally capture the grant net with GAO first to *see* the mechanism
   before/after — `ao_0.fs` already carries the AO core (trigger = rising HVE
   while PICV==2); see
   `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/GAO-HOWTO.md`.

## 9. Pointers / index

- Silicon repro + protocol: `.../tang-nano-20k/scratch_piltrace.py`,
  `.../tang-nano-20k/tang_validate.py`,
  `/home/ronny/.claude/skills/nd120-fpga/references/opcom-commands.md`.
- Debug avenues (GAO, ring analyzer, external LA, reset options):
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/DEBUG-OPTIONS.md`.
- First-pass suspect ranking: `.../Verilog/docs/tang-masked-grant-audit.md`.
- Am2914 reference: `/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/AMD/Amd2914PIC.cs`.
- The `nd120-fpga` skill has the FPGA-debug / latch→FF workflow guidance.

## 9b. Appendix — SDF gate-level timing-sim recipe (VERIFIED artifacts present)

This is the one *simulation* that can model the real delays that cause the
glitch, so it can both reproduce the grant and prove a cure without the slow
btn1/silicon loop. Confirmed available 18-JUL:

- PnR option **"Generate SDF File"** exists (`.../Gowin_V1.9.10.02_x64/IDE/data/
  config/rtlplacerouteoptions.xml`, id PNR01, cmd `-sdf`, default 1) — but our
  scripted build does NOT emit a post-PnR netlist+SDF (only the post-synth
  `.vg`). Enable it in `gowin_build.tcl` and also emit the post-PnR Verilog
  (`.vo`), then rerun PnR (on the Windows Gowin host).
- Timing primitive library present with real delays:
  `.../Gowin_V1.9.10.02_x64/IDE/simlib/gw2a/prim_tsim.v` (gw2a = the Tang's
  GW2AR die; 284 `specify` blocks = path-delay models). `gw_sh.exe` is the
  scriptable driver.
- Sim: iverilog (supports `$sdf_annotate` + specify delays; Verilator does NOT
  do timing/SDF). Flow:
  `iverilog -o gate <proj>.vo <.../simlib/gw2a/prim_tsim.v> tb.v` with
  `initial $sdf_annotate("<proj>.sdf", dut);` in the testbench.

**Recommended shape (tractable): a TARGETED unit-level timing sim of CGA_INTR**,
not the whole chip. A full-chip gate sim is heavy AND the main memory (SDRAM) is
external hardware absent from the FPGA netlist, so a full cold-start replay is
impractical. Instead: run just a `CGA_INTR` (or `CGA_INTR_CNTLR`) wrapper through
Gowin PnR to get its `.vo`+`.sdf`, then drive it with a testbench that replays
the exact request/mask/clock sequence around the silicon grant (a level-10
request pending with its mask closed, across the MCLK/sysclk edges). If the
glitch reproduces there with delays and vanishes at zero-delay, you have both the
proof and a fast regression for the fix. Once the analyst (§5) names the
implicated latch/net, this unit sim is the fastest confirmation path.

## 10. Deliverable expected back

1. A precise statement of the grant mechanism: the exact net/latch that captures
   the spurious claim, and the real-delay condition that lets a masked level-10
   request reach it — with the source lines that create it.
2. A proposed RTL change (RQBIT-V2-style if it's an async latch), with the sim
   regression run clean and the structural check showing the latch/loop gone.
3. A one-page note on whether the S3 HVE/LVE edits should be kept, reverted, or
   folded into the real fix.
