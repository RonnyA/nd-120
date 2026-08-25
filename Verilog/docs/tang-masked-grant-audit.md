# Tang Nano 20K: masked-interrupt grant audit (PIL 0 -> 10 with PIE = 000000)

Date: 17-JUL-2026. Branch: clock-enable-fix.
Scope: STATIC source audit only. Every claim below is tagged VERIFIED (read
directly from the named file/line) or INFERRED (labelled as such).

Measured fact under audit (from the board session, not re-measured here):
~10 instructions into the INSTRUCTION-B cold start, right after the IOF at
address 000261, the CPU switches PIL 0 -> 10 while PIE (I7) reads 000000 and
PID (I6) = 002000. Verilator FF-mode with the identical instruction stream
stays at PIL = 0.

---

## 1. The exact grant conjunction (what must be true for a level switch)

### 1a. Request must be latched (normal - PID=002000 is this)

- IREQ_15_0_N[10] pulses low. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_IRSRC.v:141-147
  (GATES_7: FIDBO[10] AND EMPID = software PID write) OR'd at lines 269-275
  (GATES_23) with IOXERRN. NOTE: request bit 10 is SHARED between the PID-write
  path and the IOX-error line - an IOXERRN pulse of one sysclk also pends
  "level 10".
- The request is caught by the sysclk catcher and registered at MCLK_EN.
  VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2.v:94-117
  (catcher FF lines 94-98, output FF lines 105-117, INR = qBar).

### 1b. The mask must pass bit 10

- MIREQ_n[10] goes active (low) only when LREQ[10]=1 AND PICMASK_N[10]=1.
  VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MREQ.v:83-89
  (GATES_9, NAND(LREQ[10], PICMASK_N[10])).
- PICMASK_N is the q output of the per-bit mask flip-flop; PICMASK (readback
  value) is qBar. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MASK_MASKBIT.v:117-129
  (MEMORY_6: .q(s_msk_n_out)=MSKN=PICMASK_N, .qBar(s_msk_out)=MSK=PICMASK).
  Mask polarity is classic Am2914: PICMASK bit = 1 DISABLES, = 0 ENABLES.
  VERIFIED against ground truth:
  $ND_REPOS/ND110Compile/ND110CPU/AMD/Amd2914PIC.cs:501
  ("Mask Register. 1=Masked, 0=Enabled") and
  Verilog/docs/am2914-command-model.md ("Mask
  polarity (measured): a mask bit = 1 DISABLES").

### 1c. Priority encode + status fence (fence cannot CAUSE a masked grant)

- HIDET + HIVEC=2 from the high-chip priority encoder over MIREQ only (the
  mask is already applied upstream; there is NO unmasked bypass into the
  encoder). VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_PTY.v:52-56.
- HIVGES = (HIVEC >= HISTAT), pure magnitude compare of the vector against the
  3-bit status (fence) register; the compare has no mask input. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN.v:137-144 (CMP).
  Consequence: the status fence can only BLOCK a grant, never let a masked
  level through. The 15-JUL fence feature (RDVECT auto-loads vector+1,
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT_SBIT.v:118-126)
  is therefore NOT a candidate for this bug.

### 1d. The two per-chip enable flip-flops

- HIDIS_n = 1 (status-overflow / chip-disable FF). VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v:179-188
  (STATUS_OVERFLOW_FF, SCAN_FF: D=Q recirculate, TE=H, TI=HIGAS_n).
- int_req_q = 1 (the Am2914 "interrupt request enable" FF = ND PIC,ION/IOF).
  VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v:191-200
  (INT_REQ_ENABLE_FF: D=E, TE=D, TI=Q recirculate). Low-chip twin:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_LORL.v:150-158.
  Command decode driving it (VERIFIED,
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_MDCD.v):
  - E = s_d13_n (line 178): 0 ONLY when LAA=13 (raw decode, NOT gated by EPIC).
  - D = NAND(OR(LAA in {0,13,15}), EPIC) (GATES_35/36, lines 480-495): 0 when
    EPIC and LAA in {0,13,15}.
  - Capture rule (SCAN_FF_EN, VERIFIED
    Verilog/Shared/ndlib/SCAN_FF_EN.v:42):
    q <= TE ? TI : D at MCLK_EN. So:
      LAA=13 + EPIC (PIC,IOF / DISIN)  -> q <= 0 (disable)
      LAA=15 + EPIC (PIC,ION / ENIN)   -> q <= 1 (enable)
      LAA=0  + EPIC (PIC,MCL / MCLR)   -> q <= 1 (ENABLE - datasheet-correct)
      anything else                    -> hold.

### 1e. IRQ assembly and the INTRQN flip-flop

- HIRQ = HIDET AND HIVGES AND HIDIS_n AND int_req_q. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v:131-138
  (GATES_3 = NAND3(HIVGES,HIDET,HIDIS_n)) and 157-163 (GATES_6 AND with
  int_req_q).
- IRQN = NOR(HIRQ, LIRQ). VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL.v:118-124.
- INTRQN: MEMORY_2 registers d = (PAN asserted) OR (IRQ asserted) at MCLK_EN;
  INTRQN = qBar; async clear by CLIRQ. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR.v:155-177
  (GATES_1 OR with BubblesMask 2'b11 = ~PANN | ~IRQN; MEMORY_2 ASYNC_RESET=1).
  NOTE: PANN reaches INTRQN with NO mask/PIE/ION term of any kind. PANN is the
  DGA panel/RTC aggregate - VERIFIED
  Verilog/DECODE-GateArray/DGA/circuit/DECODE_DGA_POW.v:232,242
  (A592 NAND includes s_rtc_n and s_prq_n; A595 makes PAN_n) - so INTRQN
  asserts on EVERY RTC tick / panel request in normal operation. This is how
  OPCOM/MOPC is serviced; the panel-vs-macro-interrupt split happens in the
  microcode dispatch (TRAP/DCD), not in this FF.
- CLIRQN = ~(registered iclirq | master clear). VERIFIED:
  Verilog/DELILAH-CPU/CGA_DCD/circuit/CGA_DCD.v:1163.

### 1f. How the CPU learns WHICH level: the vector-claim read

- Microcode reads the vector over the IDB under EPICVN / EPICSN. VERIFIED:
  Verilog/DELILAH-CPU/CGA_IDBCTL/circuit/CGA_IDBCTL.v:110-115
  (enable one-hot) and 253-299 (V bank: IDB[2:0]=PICV, IDB[3]=PDF; S bank:
  IDB[2:0]=PICS, IDB[3]=HIGSN, IDB[4]=LOGSN). This read is COMBINATIONAL
  through the SEL6 muxes; the consuming register latches it at its own MCLK_EN.
- The claim that steers PICV: HVE = HIPASSALL AND (S active). VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v:165-171
  (GATES_7), where HIPASSALL = HIDET AND HIVGES AND HIDIS_n (GATES_3,
  lines 131-138) and S = RDVECT strobe (MDCD GATES_37,
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_MDCD.v:497-503).

  ***The RTL claim does NOT include int_req_q.*** The C# ground truth DOES:
  $ND_REPOS/ND110Compile/ND110CPU/AMD/Amd2914PIC.cs (ReadVector):
  "_vectorClaim = Output_InterruptRequest", and Output_InterruptRequest
  (lines ~545-560) requires _interruptDetected AND
  _interruptRequestEnableFlipFlop AND the fence AND not-disabled.
  So in the RTL, a READ VECTOR performed after PIC,IOF (DISIN) will still
  claim and emit the vector of a pending, unmasked, above-fence level; in the
  C# model it will not. This divergence is identical in Verilator and on
  silicon, but it removes one of the two guards the ground-truth machine has -
  see suspect S3.

Level 10 = high chip (bits 8-15), vector 2, so the observed PIL=10 requires
MIREQ_n[10] active AT THE TIME of the claim/dispatch, i.e. PICMASK_N[10]=1
(bit 10 ENABLED in the Am2914 mask) at that instant on silicon.

---

## 2. PIE readback vs the Am2914 mask - they are NOT the same register

- The mask register is loaded from FIDBO by the PIC command LDM (PIC,LMSK,
  LAA=14) through the DIN mux. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR.v:124-131
  (PLEXERS_1: sel=OEM recirculates PICMASK during mask read, else DIN=FIDBO).
- The ND software PIE convention is INVERTED relative to the mask: the
  microcode inverts PIE before PIC,LMSK. VERIFIED (doc, which cites microcode
  CS 000730 ALUF,INVQ):
  Verilog/docs/am2914-command-model.md
  ("The ND software PIE convention is the inverse (1 = enabled), so the
  microcode inverts before PIC,LMSK").
- PIE (I7) as read by OPCOM/TRA is a microcode-held value, not a hardware read
  of PICMASK (no PIE register exists in the C# CPU either - grep of
  $ND_REPOS/ND110Compile/ND110CPU/CpuInternals.cs and Cpu.cs finds
  no PIE register; it lives in scratch/register file). INFERRED from that
  grep plus the IDBCTL wiring (EPICMASKN reads raw PICMASK, which is the
  INVERSE convention of PIE - a raw PICMASK readback could not print as "PIE").

CONSEQUENCE (the central trap of the measured fact): "PIE reads 000000" does
NOT prove the Am2914 mask had every level disabled. Ground truth says the
opposite is the RESET STATE:

- Am2914 MASTER CLEAR (PIC,MCL, issued by the DELILAH microcode on every MCL)
  leaves the mask register = 0 = ALL LEVELS ENABLED and sets the interrupt
  request enable FF = ENABLED. VERIFIED in the C# ground truth:
  $ND_REPOS/ND110Compile/ND110CPU/AMD/Amd2914PIC.cs:950-977
  (MasterClear: _maskRegister = 0x00 with the 2026-07-11 polarity bug-fix
  comment; _interruptRequestEnableFlipFlop = true), and for the RTL:
  Verilog/docs/am2914-command-model.md line for
  MCLR: "A/C -> mask register -> 0 (enable all, measured)". The RTL MDCD/
  MASKBIT equations reproduce this (MCLR: A=0,B=0,C=1 -> d=1 -> q=PICMASK_N=1
  = enabled; derived from
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRQ_MASK_MASKBIT.v:74-114).

So between the microcode master clear and the FIRST PIC,LMSK (which only
happens when PIE is written / on the PICF2 path - see
Verilog/docs/RUN-level14-livelock-analysis.md),
the Am2914 mask is ALL-ENABLED while PIE prints 000000. In that window the
ONLY guards against granting a pending level are the per-chip int_req_q FFs
(cleared by PIC,IOF/DISIN) and the status fence (0 after MCLR = passes
everything). Whether INSTRUCTION-B's cold start sits in that window, or the
boot microcode issues an LMSK/DISIN earlier, was NOT verifiable statically -
the discriminating probe is experiment E1 below.

---

## 3. Q3: the status fence and IOF/ION

- After master clear the status (fence) registers are 0: SBIT d-input is 0
  when G (active-low RDVECT/MCLR strobe) is asserted with HIF/LOF idle - all
  three product terms die. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT_SBIT.v:79-160
  and the strobe table in
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT.v:176-196.
- Fence = 0 means HIVGES is true for every vector (compare is >=). A fence
  value can therefore never make a MASKED level pass - the compare has no mask
  input (section 1c). The fence is exonerated as a cause.
- IOF/ION interact with the grant ONLY through the int_req_q FFs:
  ENIN = "PIC,ION", DISIN = "PIC,IOF". VERIFIED in ground truth:
  $ND_REPOS/ND110Compile/ND110CPU/InterruptSubSystem.cs:458-467.
  In the RTL that is the LAA=13/15 capture described in section 1d. The IOF at
  000261 is therefore not incidental: it is the very instruction whose PIC
  side-effect (q <= 0) is the last thing standing between the pending PID bit
  and a grant whenever the mask window of section 2 is open.

---

## 4. Q4: power-up and warm-reset state (btn1)

- NO register in the CGA_INTR tree has a reset tied to the board reset:
  CGA_INTR has no sys_rst_n port at all. VERIFIED:
  Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR.v:13-44
  (port list). The only async clear in the whole tree is MEMORY_2's CLIRQ
  (which master clear does assert, via
  Verilog/DELILAH-CPU/CGA_DCD/circuit/CGA_DCD.v:1163).
- State bits with bitstream-INIT only (no reset, survive btn1): 16 mask bits,
  16 RQBIT catchers + 16 RQBIT output FFs, 6 status/fence bits, 2 HIDIS FFs,
  2 int_req_q FFs, HIGEL/LOGEL group FFs, MDCD MEMORY_42/43, VHR hold
  registers.
- Bitstream INIT values were verified IN THE ACTUAL VENDOR NETLIST:
  Verilog/fpga/tang-nano-20k/build/nd120_tang20k_build/impl/gwsynthesis/nd120_tang20k_build.vg
  - every relevant DFFE carries INIT=1'b0 and the physical Q drives the
  expected polarity net: mask bits Q -> s_picmask_15_0_n_out[i] (INIT 0 =
  MASKED at configuration), SCAN_FF_EN_63 Q -> s_hidis_n (0 = chip disabled),
  SCAN_FF_EN_64 Q -> s_int_req_q (0 = requests disabled), RQBIT_V2 catchers
  DFFRE INIT 0. This MATCHES Verilator's `reg q_r = 1'b0` initialisation, so
  the "mask powers up enabled on Gowin" hypothesis is REFUTED for a fresh
  configuration of THIS netlist.
- btn1 (S1) only re-runs the 256-cycle sys_rst_n pulse. VERIFIED:
  Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v:102-128.
  It does NOT re-initialise any of the FFs above; recovery relies entirely on
  the microcode PIC,MCL - which per section 2 deliberately leaves the mask
  ALL-ENABLED and int_req_q ENABLED. A btn1 restart therefore always passes
  through the vulnerable window, carrying whatever request bits the previous
  run left latched (the RQBIT catchers are only cleared by CLRQ commands).

- Tang build mode: FPGA_FF_MODE is defined. VERIFIED:
  Verilog/fpga/tang-nano-20k/src/tang20k_defines.v:20.
  So all structures above are sysclk+MCLK_EN flip-flops on silicon, not
  routed-MCLK latches.

---

## 5. Timing evidence from the build on disk

Report:
Verilog/fpga/tang-nano-20k/build/nd120_tang20k_build/impl/pnr/nd120_tang20k_build.tr
(caveat: not proven to be the exact bitstream flashed on 17-JUL).

- Setup violated endpoints: 0. Hold violated endpoints: 109.
- Every printed negative-slack path (worst -2.285 ns, all HOLD) is a
  sys_clk <-> PLL-clock crossing in the STORAGE seam: s_dev_addr_l_* ->
  s_addr_*, s_dev_start_tgl -> s_dev_st, s_bridge_rd_data_* ->
  g_fe[0].r_buf_wdata_*, s_err_c -> s_meta. None are in CGA_INTR or the CPU
  clk_cpu domain (per-clock TNS table shows 0.000 for every single-domain
  analysis).
- Consequence: the CPU-domain grant cone (mask FFs, MDCD decode, PTY/CMP,
  HIRL, MEMORY_2) is formally timing-clean in this build; pure
  glitch-capture stories inside the clk_cpu domain are NOT supported by the
  report. The broken crossings live in the SD/tape/SDRAM device-port seam and
  can deterministically corrupt storage-side data per bitstream (consistent
  with the earlier "stable-junk reads" finding) - and note from section 1a
  that IOXERR shares request bit 10 with the PID-write path.

---

## 6. Ranked suspects

### S1. int_req_q = 1 at the fatal dispatch (the single-bit divergence)
Mechanism: PIC,MCL sets int_req_q = 1 (ground-truth-correct, section 2). The
guard that turns it off is the DISIN capture of the IOF at 000261
(q <= E = d13_n with TE = 0, section 1d). If on silicon that capture is
missed (TE resolved 1 = hold) or captured E = 1 (decode of LAA=13 not yet 0),
the machine leaves IOF with interrupts ENABLED, the mask window of section 2
is open, fence = 0, and the first PID bit 10 pend grants PIL = 10 - exactly
what was measured, with PIE = 000000 the whole time. Deterministic per
bitstream. STA says the cone is setup-clean, which weakens the pure-timing
version; the state-order version (E1/E2 discriminates) survives.
Files: Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v:191-200,
Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_MDCD.v:178,489-495.
Cheapest experiment (E1): route s_int_req_enable_q of HIRL and LORL (2 wires)
to two spare LEDs or two bits of the existing 512-sample debug capture in
Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v
- during the hang, if either LED shows ENABLED after the IOF, S1 is confirmed
on the board directly. Companion sim probe (E2, 1 line in Verilator): print
(int_req_q_hi, int_req_q_lo, PICMASK) at the IOF - it identifies which guard
the sim actually relies on (enable FF vs mask), which halves the search.

### S2. The MCL->first-LMSK window: mask ALL-ENABLED while PIE reads 000000
Not a defect of the RTL alone - it is ground-truth Am2914 behavior (section 2)
- but it is the reason S1/S3 have anything to grant, and the reason the
measured "PIE=000000 - every level masked" reading is misleading. If the boot
microcode does not issue an early PIC,LMSK/DISIN, both sim and silicon sit in
this window and only differ in event CADENCE: the 20 ms real RTC tick
(Verilog/DECODE-GateArray/DGA/circuit/DECODE_DGA_POW.v,
RTC_20MS = BOARD_CLK_FREQ/50 on FPGA vs 8192 sysclk under VERILATOR_SIM,
lines 340-380) and the SDRAM wait-state stretching mean the tick/dispatch
lands at a different instruction-stream position on silicon than in sim - a
real RTL window can then fire deterministically on the board and never in
Verilator. Cheapest experiment: E2 above (shows whether the mask really is
0xFFFF in sim at the IOF); on the board, compare cold power-cycle repro vs
btn1 repro (E3, no code change) - btn1 always replays the window with stale
request bits, a difference in behavior confirms state carry-over.

### S3. RTL vector-claim ignores the interrupt-request-enable FF (divergence
from C# ground truth)
HVE = HIDET & HIVGES & HIDIS_n & S - no int_req_q term
(Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v:165-171),
whereas the C# claim is Output_InterruptRequest which REQUIRES the enable FF
($ND_REPOS/ND110Compile/ND110CPU/AMD/Amd2914PIC.cs, ReadVector +
Output_InterruptRequest). Any microcode path that executes PIC,RVECT after an
IOF (e.g. inside the PAN/RTC panel dispatch that fires INTRQN uncondition-
ally, section 1e) will, in the RTL only-by-semantics, be handed hi-claim +
vector 2 for the pending level 10. Same in sim and silicon, so it needs the
S2 cadence difference to explain the divergence - but it is a hard deviation
from ground truth and should be closed regardless.
Cheapest experiment (E4): 3-line Verilator assertion in
CGA_INTR_CNTLR_IRGEL_HIRL.v - flag if HVE asserts while s_int_req_enable_q=0;
run the existing seq tb
(Verilog/DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_seq_tb.v)
and runSim to see if it ever fires.

### S4. Storage-seam hold violations feeding IOXERR/request bit 10
109 hold-violated endpoints, all in the sys_clk <-> PLL crossing of the
SD/tape/SDRAM device port (section 5). They cannot reach the grant chain
directly, but request bit 10 is IREQ = PID-write OR IOXERRN
(Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_IRSRC.v:269-275)
and the RQBIT_V2 catcher latches a single-sysclk IOXERRN pulse forever. A
corrupted device-port transaction that trips the IOX timeout would pend "level
10" invisibly. This does not by itself grant (still needs mask+enable), but
it can supply the pending bit at an unexpected time.
Cheapest experiment (E5): rebuild with SD_STORAGE=0 (storage stack out, seam
gone) and re-run the INSTRUCTION-B cold start; if the grant vanishes, the
seam is implicated upstream.

### S5. Warm-start stale PIC state via btn1 (subset of S2)
All 60+ PIC state bits survive btn1 (section 4); PIC,MCL then re-ENABLES mask
and int_req_q. A previous run that serviced level 10 leaves nothing that
blocks a re-grant. Experiment: E3 (power-cycle vs btn1 comparison).

### S6. The regLAA delta-delay hack (sim/silicon semantic difference by design)
Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR.v:141-146:
`always @(LAA_3_0) regLAA_3_0 <= LAA_3_0;` with the comment "so that if it
changes when MCLK changes we dont get the new and wrong value". In synthesis
this is a plain wire (no delay); in event simulation it adds an NBA delta that
deliberately makes MCLK-edge captures see the OLD LAA. Any behavior that
depends on that delta is by construction different on silicon. In the current
FF-mode build the exposure is small (all captures are same-edge sysclk FFs),
but this is the PIC command-decode input and the hack should be replaced by
an honest sysclk register (or deleted) so sim is faithful. In LATCH-mode
iverilog tbs it actively changes capture results today.
Cheapest experiment (E6): in sim only, replace the block with `assign` and
diff the latch-mode golden traces; any diff = the hack is load-bearing and
hiding a real race.

### S7. (Downgraded) Gowin INIT / power-up polarity flip
Refuted for this netlist by direct inspection (section 4): all PIC state FFs
carry INIT=1'b0 on the correctly-polarised physical Q nets. Only revisit if
the flashed bitstream is proven to be a different build than
Verilog/fpga/tang-nano-20k/build/nd120_tang20k_build/.

---

## 7. What was NOT verifiable statically

- Whether the boot microcode issues PIC,LMSK or PIC,DISIN between PIC,MCL and
  the first instruction (decides how wide the S2 window really is). The
  microcode listing in the nd120uc project would answer this without any run.
- Which guard blocks the grant in Verilator at the failure point (E2 answers
  with one printf).
- Whether the .tr timing report corresponds to the bitstream that produced
  the 17-JUL measurement.
