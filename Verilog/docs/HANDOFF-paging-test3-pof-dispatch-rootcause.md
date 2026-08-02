# HANDOFF: PAGING test 3 (Issue D) - ROOT CAUSE FOUND AND FIXED: PAL 44306A EIPL transcription error (PPN map RAM never written)

Date: 28/29-JUL-2026. Status: ROOT CAUSE PROVEN, FIX APPLIED, validation run in flight.

## 29-JUL FINAL ROOT CAUSE (supersedes the D1/D2 framing below - both were symptoms)

Windowed full-signal FST capture (TRACE_FST_WINDOW, trigger P=077675) of the failing
bracket showed, in order of discovery:
1. The trap-refetches and the POF fetch physically read from PAGE 0 (local-bus address
   phases 001676/001677/001700), returning garbage words (120116/147727/135520) that
   became "instructions" - the "POF as NOP" dispatch (07355) and the wrong AREAD
   displacement were decoded from GARBAGE FETCHED WORDS, not from decode bugs.
2. MMU PPN_25_10 (the translated physical page driven to memory) went to 0 at the FIRST
   paged fetch after PON and stayed 0: EVERY paged access ran in physical page 0.
3. The PPN map RAM (CPU_MMU_PT_29 chips 22G/23G, CS=EPMAP_n) is a SEPARATE bank from
   the PT status RAM (24G/25G, CS=EPT_n). The PPN bank's WRITE DATA arrives from the
   IDB through the EIPL/EIPU gates of PAL 44306A (21G, MMUCTL). In the FST, EIPL_n
   NEVER asserted - the test's 44 map writes stored the protection words but wrote
   NOTHING into the PPN bank, which kept its power-on zeros -> physical page 0 always.
4. Diff against the original PALASM
   (`DesignDocuments/PAL-Code/SRC/44306A.txt`):
   PALASM:  EIPL = WCHIM + DOUBLE*LSHADOW*CA0 + LSHADOW*WRITE   ; "(SAME FOR REX AND SEX)"
   Verilog: had an extra `DOUBLE &` on the third term (copy-paste from the EIPU
   equation above it). In REX mode DOUBLE=0 -> EIPL never fires. All 7 other
   equations in the file match the PALASM exactly.

**FIX (applied 29-JUL):** `Verilog/PAL/PAL_44306A.v` -
EIPL third term corrected to `(LSHADOW & WRITE)`. Same single-term transcription-error
class as CGA_ALU_QREG and CGA_CPU_ALU_CONTR.

Why nothing else ever caught it: PAGING test 3 is the only code in the whole campaign
that turns paging ON (PON). Every other test runs unmapped. The MMU translation path
was never validated before (see also the cache-never-validated note) - it was always
broken, on sim and on silicon identically (the PAL equation is mode-independent RTL).

Validation in flight: rebuild + PAGING test 3 rerun (expect: no page-0 fetches, POF
reaches its handler, test 3 completes "- End of test -" with zero errors like the
nd100x oracle). Full unit suite + instruction-verify must follow before commit.

---

# ORIGINAL 28-JUL ANALYSIS (kept for the measurement record; D1/D2 below are
# DOWNSTREAM SYMPTOMS of the EIPL bug, not independent defects)

Date: 28-JUL-2026. Status: MEASURED, no fix attempted (fix decision needs Ronny).
Applies to both Verilator and Tang Nano 20K (behavior is identical - proven this session).

## One-paragraph summary

PAGING-C02 test 3 ("PGU/WIP bits for all PITS and ENTRIES") aborts silently ("Abort
after 10 errors" -> TPE banner) because of what happens inside ONE five-instruction
PON/POF bracket at virtual 077675-077703. Two distinct RTL misbehaviors were measured
cycle-by-cycle: (1) the POF instruction at 077700 dispatches to microword 07355 - a bare
"IREAD,APT" instruction terminator - instead of the real POF handler at 03644, so PONI
(STS bit 14) is never cleared; (2) the STA at 077677 translates its data access through
page-table entry 0o40 instead of its true effective-address page 0o33 - the wrong address
appears on the very AREAD (overlapped argument read) that follows a PGU-trap refetch. The
combination sends the CPU through an empty page-table entry (real protect violation ->
internal interrupt -> the test counts errors -> abort). The oracle (nd100x, ND120CX,
same FLOPPY1.IMG) single-steps the same bracket with byte-identical entry registers and
passes the whole test with zero errors.

## The failing code (disassembled from the oracle, physical 0x7FBD-0x7FC3)

```
077675  150410  PON            paging on
077676  150001  TRA STS        A <- STS   (oracle: A=150044, PONI bit 14 set)
077677  004612  STA ,B -166    store A at B-166 = 066314-166 = 066126 (page 0o33)
077700  150404  POF            paging off
077701  044612  LDA ,B -166    reload saved STS
077702  175365  BSKP ONE 160 DA  skip if the PONI bit is set in the reloaded value
077703  124003  JMP 3          (error path if the bit test fails)
```

Registers at the PON, IDENTICAL in our RTL and the oracle:
A=000003 T=000002 X=077675 B=066314 L=073206 D=022573, PCR=000002.
Test 3 maps PT entries 0000-0053 with 162xxx (identity), all PGU/WIP clear.

## Oracle ground truth (nd100x -d, DAP port 4711, single-stepped this session)

PON -> TRA(A=150044) -> STA -> POF -> LDA -> BSKP SKIPS to 077704. No trap, no protect
violation, PONI clears immediately at POF. Test 3 ends "- End of test -", zero error
lines. (nd100x does not model PGU/WIP traps at all - it sets the bits silently in
cpu_mms.c - so on real hardware the PGU/WIP traps in this bracket exist but are
microcode-transparent; the macro-visible behavior must match the oracle.)

## Our RTL, measured cycle-by-cycle

Probes: TRAP_RP_WATCH + TRAP_LA_WATCH in
`Verilog/runSim/Run120.cpp` (register snapshot at each
trap dispatch; every change of MMU `s_la_20_10` + PT output + EPT/WMAP + PONI + P from
the PON onward), PTDBG in
`Verilog/CPU-BOARD-3202/circuit/CPU_MMU_24.v`, TRAPDBG in
`Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP.v`.
Raw logs (scratchpad, session 61614461):
`/tmp/claude-1000/-mnt-e-Dev-Repos-Ronny-nd-120-Verilog/61614461-8603-4295-97e6-e3d0aac44e99/scratchpad/pgu_la.log`
(full) and `.../la_trace.txt` ([la] lines only). Engine:
`Verilog/runSim/obj_dir_ptdbg` (FF mode, SD_STORAGE=0,
`--public-flat-rw`, built `make -C obj_dir_ptdbg -f VND120_TOP.mk OPT_FAST="-Os -DTRAP_LA_WATCH"`).

Cycle numbers below are the `c=` values in la_trace.txt (sysclk half-cycles).

1. c=234284039: PON executes. Microcode path 6000 -> **07504 (PIONF)** -> 0657 -> 0326-0330
   -> 0660 -> **03650 (PON handler: A,R6 ORDQ IDBS,BMG)** -> 0662 -> 0677 -> **0700/0701**
   where PONI 0->1. CORRECT - this is the reference for what a good dispatch looks like.
2. c=234284047: PGU trap (tvec=4) on the fetch of 077676 via entry 0o37 (pt=162037).
   WIPGU handler (CSA 0067/0071/3151-3160/0072-0076) reads entry 0o37 via the IDB
   (RDI 162037), writes back 166037 (WRI + WR strobes), refetches. CORRECT trap handling.
3. c=234284114: the refetched TRA STS runs (CSA 07201 = `04420 ... COMM,AREAD,* IDBS,STS`).
   This word issues the overlapped ARGUMENT READ for the NEXT instruction (the STA).
4. c=234284121: **the AREAD/data address for the STA is page 0o40, not 0o33.** LA_20_10 =
   0040 while CSA=4420, P=077677. Page 0o40 = addresses 100000-101777. The two arithmetic
   candidates that land there: X+0o166 = 077675+166 = 100063 (wrong base register AND
   unsigned displacement) or P+0o212 = 077677+212 = 100111 (P-relative base AND unsigned
   displacement). The correct EA is B-166 = 066126 (page 0o33). A second PGU trap latches
   entry 0o40 (162040); the handler sets PGU on 0o40 - the WRONG page - and after the
   refetch the STA executes microwords 4420-4440 with LA STILL page 0o40, i.e. **the store
   went to physical page 0o40, and 066126 was never written.**
5. c=234284312-322: POF at 077700: fetch is clean (via 0o37, now 166037), dispatch goes
   6000 -> **07355** and NOTHING else. 07355 in the EPROM-validated microcode
   (`/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah.uc`) is
   `00140 A,P ... COMM,IREAD,APT F,PUSH T,HOLD T,JMP` - a bare next-instruction-fetch
   terminator (APT flavor). The real POF handler is **03644**
   (`A,R6 ALUD,Q ALUF,MASKDQ F,LOAD IDBS,BMG` - clear the PONI bit via the bit-mask
   generator), reached e.g. via the PIONF chain the way PON is. It is never visited.
   **PONI stays 1.** (It finally drops ~1000 cycles later, at P=000025 via the same
   0700/0701 route, during the post-violation interrupt handling - so the clear PATH
   works; the POF DISPATCH is what's wrong.)
6. c=234284329: LDA at 077701 (paging still on because of 5): its data access translates
   CORRECTLY via entry 0o33 (162033 - still PGU-clear because of 4), PGU trap #3,
   handler sets 166033, refetches. Note the asymmetry: LDA's EA is right where STA's was
   wrong - the difference upstream is the trap-refetch/AREAD overlap in step 3-4.
7. c=234284422: after the LDA resumes, the fetch address becomes page 0o64
   (la=0064, pt=000000 - EMPTY entry) and P reads 150402: the LDA loaded garbage
   (066126 was never written, step 4) and control transferred through it. Page 0o64 =
   addresses 150000-151777 - both 150044 (the STS value that SHOULD have been stored)
   and 150402 live there. This protect violation is REAL given the state - it is the
   macro-visible MPV the test sees (internal-interrupt dispatch CSA 0030-0037/0044-0047,
   level switch, L<-077701 observed at dispatch).
8. The test's error machinery counts these (one per bracket repetition), reaches 10,
   prints nothing per-error in this mode, wipes the PT and re-enters the TPE monitor =
   the silent eject seen on BOTH Verilator and the Tang.

## The two defects to fix (both must go)

**D1 - POF dispatch.** Opcode 150404 must reach the 03644 MASKDQ handler (the way 150410
reaches 03650 via 07504/PIONF). Our decode/dispatch sends it to the 07355 IREAD,APT
terminator instead - i.e. POF executes as a NOP (and additionally selects the ALTERNATE
page table for the next fetch). Note PON (unprivileged in nd100x) works and POF
(privileged, CheckPriv in nd100x `src/cpu/cpu_instr.c` ndfunc_pof) is the one demoted -
a ring/privilege qualification in the dispatch path is the prime suspect, but this is
NOT proven; the map/entry-point generation (DGA -> CGA_MIC) needs to be traced against
the schematics. PCR=000002 at the time (ring 2 - the oracle accepts POF with the same PCR).

**D2 - AREAD address after a trap refetch.** The overlapped argument read for instruction
N+1 (COMM,AREAD in instruction N's dispatch word) produces a wrong effective address when
instruction N was resumed via the WIPGU trap refetch path (FETCH o145 -> o143). Measured:
base/displacement resolve to page 0o40 (X+unsigned-disp or P+unsigned-disp shaped)
instead of B-166. The DGA argument pipeline (base select + sign-extended displacement)
appears skewed by one instruction after the refetch. This also poisons the PT (PGU set on
an untouched page 0o40), which the test's later verification phases would catch even if
D1 were fixed. Possible relation to Issue C (MOVEW drops the word at a page boundary -
also a wrong-address-on-write shape after MMU events); unproven.

## Why the trap machinery itself is NOT the bug

Traps 1 and 3 are textbook-correct (right entry, right read-modify-write, transparent
refetch). The interrupt/vector plumbing all checks out (earlier phases of this hunt).
The TMM2018D sync-read infidelity was A/B-refuted with -DTMM_ASYNC_READ (kept as a
diagnostic define in
`Verilog/Shared/support/TMM2018D_25.v`).

## How to reproduce

```
cd Verilog/runSim
# engine obj_dir_ptdbg already built (see above). Then:
ND120_FLOPPY_IMG=FLOPPY1.IMG ND120_SCRIPT='1560&load pag\rrun\r3\r' \
ND120_AMP_SETTLE=50000000 ND120_MAX_CNT=400000000 ./obj_dir_ptdbg/VND120_TOP > pgu_la.log
grep '\[la\]' pgu_la.log   # capture arms at P=077675, 8000 samples
```
Oracle side: `/home/ronny/repos/nd100x/build/bin/nd100x --boot=floppy
--image=Verilog/runSim/FLOPPY1.IMG --cputype=ND120CX -d`
then drive TPE over the DAP console (`load pag`, `run`, `3`), breakpoint 0x7FBD.

## Cleanup still owed (all probes are inert without their defines)

- `TRAP_RP_WATCH`, `TRAP_LA_WATCH`, `TRACE_MIC_TRAP45` blocks in
  `Verilog/runSim/Run120.cpp`
- `PTDBG` block in `Verilog/CPU-BOARD-3202/circuit/CPU_MMU_24.v`
- `TRAPDBG` block in `Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP.v`
- `TANG_TRAP_CAPTURE` is still DEFINED in
  `Verilog/fpga/tang-nano-20k/src/tang20k_defines.v` -
  must be commented out for normal Tang builds. The Tang currently holds the volatile
  SRAM capture build; a power cycle restores the flashed image.
- `obj_dir_ptdbg` / `obj_dir_sdstore_keep` juggling in
  `Verilog/runSim/` - current `obj_dir` is the foreign
  SD_STORAGE build (untouched).
