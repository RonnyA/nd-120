# ND-120 Verilog testbench coverage catalog

> Generated 31-JUL-2026 by a full-tree sweep. Paths are repo-root-relative.
> Registry: `Verilog/tests/run_all_tests.sh` (109 registered entries at scan
> time). Goal (Ronny 31-JUL): comprehensive self-checking testbenches for ALL
> Verilog modules, validating all input variants; build them one by one in
> the priority order below, exhaustive golden-table style where the module is
> pure combinational (the `Verilog/DELILAH-CPU/CGA_MAC/sim/CGA_MAC_DECODE_tb.v`
> pattern), equivalence style for `_EN` refactors
> (`Verilog/Shared/support/sim/FF_EN_equiv_tb.v` pattern).

## Headline numbers (at scan time)

| Tree | Modules | COVERED | PARTIAL | UNCOVERED |
|---|---|---|---|---|
| DELILAH-CPU | 76 | 34 | 10 | 32 |
| DECODE-GateArray | 11 | 1 | 2 | 8 |
| CPU-BOARD-3202/circuit | 51 | 15 | 21 | 15 |
| ND-BUS-DEVICES | 7 | 5 | 0 | 2 |
| PAL (excl. templates) | 30 | 5 | 19 | 6 |
| Shared/support | 26 | 6 | 3 | 17 |
| Shared/ndlib | 33 | 4 | 0 | 29 |
| Shared/logisim | 37 | 0 | 1 | 36 |
| SD-FAT/circuit | 12 | 8 | 1 | 3 |
| Top level | 2 | 0 | 1 | 1 |
| **TOTAL** | **285** | **78 (27%)** | **58 (20%)** | **149 (52%)** |

**The scaffold trap:** 48 of the 58 PARTIAL entries are copy-paste
`test_code.cpp` / `test_pal.cpp` Verilator skeletons with 0-5 stimulus rows,
`Passed/FAILED!!` output (not `TB_RESULT:`), unregistered - several check
signals belonging to a DIFFERENT module (e.g. `Verilog/PAL/44302B/sim/test_pal.cpp`
checks PAL_44304E's signals) and `Verilog/DELILAH-CPU/CGA_IDBCTL/sim/test_idbctl.cpp:126`
compares a value with itself. Treat scaffolds as UNCOVERED. Real regression
coverage is ~27%.

## Fully covered subtrees (reference patterns)

- `Verilog/DELILAH-CPU/CGA_INTR/` - 27 of 30 modules, the model subtree.
- `Verilog/DELILAH-CPU/CGA_TRAP/` - 5/5.
- `Verilog/ND-BUS-DEVICES/` - all devices except TAPE-400 (empty sim/).
- `Verilog/SD-FAT/` - 8/12.

## Cheap structural fixes (no new tb authoring)

1. `Verilog/CPU-BOARD-3202/circuit/sim/CPU_MMU_PT_29_tb.v` - orphan tb, no
   Makefile target at all. Add target + register.
2. `Verilog/DECODE-GateArray/DGA/sim/F595_transparency_tb.v` - target
   `test-f595-transparency` exists, never registered.
3. `Verilog/DECODE-GateArray/DGA/circuit/F714_TEST/F714_tb.v` - non-standard
   location; move to `DGA/sim/`, register.
4. `Verilog/Shared/support/FIFO_8BIT_TB/FIFO_tb.v` and
   `Verilog/Shared/support/IDT6168A_20_TB/IDT6168A_20_tb.v` - move to
   `Shared/support/sim/`, register.
5. `Verilog/DELILAH-CPU/CGA_TESTMUX/sim/test_testmux.cpp` - 25 real vectors;
   convert verdict to `TB_RESULT:` and register.
6. `Verilog/PAL/44302B/sim/test_pal.cpp` and sibling scaffolds check
   wrong-module signals - delete or rewrite when their PAL gets a real tb.

## Progress

- 31-JUL-2026: **Tier 1 COMPLETE** (26 tbs: CGA_MAC FASTADD/PTSEL/SEGPT
  family, CGA_ALU SWAP/SEL7/SEL8/MUX216L/RMUX/LOGOP/SMUX/SHIFT, CGA_MIC
  CSEL/INCOUNT/IINC/IPOS, CGA_IDBCTL SEL6/PGSREG, CGA_WRF SEL16/LR16,
  CGA_INTR CLRBIT/VECGEN - CGA_INTR now 100%). **Tier 2 COMPLETE** (11
  equivalence tbs: 5 ndlib _EN + 6 PAL _EN; no base-vs-_EN divergence found
  anywhere). All teeth-proven, all registered in run_all_tests.sh.
  Findings logged: SCAN_WITH_RESET_N R_n is a no-op in BOTH variants
  (D_FLIPFLOP default ignores async reset); J_K_FLIPFLOP preset is
  synchronous where real 74-series is async; LOGOP instance-name typo
  MUXLL3; no functional transcription errors in any Tier-1/2 netlist.
- 31-JUL-2026 (cont): Tier 3 started - CGA_ALU DBR/QREG/STS done (QREG's
  teeth mutation is exactly the historical MPY MUXQ15.D3 bug and the tb
  catches it; STS teeth = the FIDBO-swap class). 40 new tbs total today,
  all registered. NEXT in Tier 3: CGA_MAC APOS_INC/APOS_CALCA/LASEL, then
  CGA_MIC STACK family, DGA F-cells, CPU-BOARD small combs.
- 31-JUL-2026 (cont 2): CGA_MAC APOS_INC/APOS_CALCA/LASEL done; CGA_MIC
  STACK/STACK_BIT/STACK_BIT12/WCAREG/CONDREG done (POP-on-empty duplicates
  the bottom level = correct 74S482 behavior); DGA F091/F103/F571/F617 +
  CPU_STOC_35 done. 51 tbs today. F617 FINDINGS (F595 divergence class,
  FPGA-relevant): its async SB/RB pins are EDGE-only in RTL (a held-low pin
  does not re-assert after the other releases); the NEC prohibition row
  RB=SB=0 gives Q=0,QB=1 in RTL vs Q=0,QB=0 in the cell comment;
  ACTIVE_ASYNC=0 (repo default) ignores RB entirely. All pinned by
  DGA/sim/F617_tb.v. NEXT: MEM_RAMC_50, MEM_LBDIF_48, IO_PANCAL_40,
  CPU_MMU_CACHE_25, then Tier 4/5 per the ladder below.
- 31-JUL-2026 (cont 3): CPU-board four done - MEM_RAMC_50 (grant chain),
  MEM_LBDIF_48 (both latch modes, separate golden checksums), IO_PANCAL_40
  (pins the 68705-stub contract), CPU_MMU_CACHE_25 (3 builds; teeth = the
  ungated cache drive, provably identical to the escape-hatch checksum).
  55 tbs today. **SUSPECTED TRANSCRIPTION ERROR to audit vs the PALASM
  scan: `Verilog/PAL/PAL_44902A.v` RAS_n equation carries a
  self-contradictory dead term `(QD_n & QA & QD)`; with the next line it
  reduces to `QD_n & QA` - same audit class as the 30-JUL PAL fixes.**
  Cosmetic: MEM_LBDIF_48 wire named s_bgnt50_n_out is the 25ns tap;
  IO_PANCAL_40 CHIP_32B captures PA once at power-on (stub, now pinned).

- 01-AUG-2026: Tier 5 started - three sequential register modules done, each
  built+run in BOTH modes (default posedge-net capture and -DFPGA_FF_MODE
  sysclk+EN capture; none contain USE_TRANSPARENT_LATCHES primitives):
  CGA_MIC_MASEL_REPEAT (`DELILAH-CPU/CGA_MIC/sim/CGA_MIC_MASEL_REPEAT_tb.v`,
  target test-mic-repeat, 12201 checks; PINNED: SC5/SC6 are dead inputs -
  the s_hack gating wire is computed but never read, the HACK always-block
  is commented out - and the MPN clear is SYNCHRONOUS, unlike the
  commented-out original's async posedge-s_mp clear; teeth = dropped
  inversion on s_mp, FAILs), CGA_ALU_ARG
  (`DELILAH-CPU/CGA_ALU/sim/CGA_ALU_ARG_tb.v`, target test-alu-arg, 69537
  checks incl. exhaustive 65536-value load sweep; teeth = output byte-swap,
  FAILs), CGA_WRF_RBLOCK_DR16
  (`DELILAH-CPU/CGA_WRF/sim/CGA_WRF_RBLOCK_DR16_tb.v`, target
  test-wrf-dr16, 69555 checks; sys_rst_n pinned as a no-op port; teeth =
  inverted WR qualifier, FAILs). All three registered in
  tests/run_all_tests.sh. 58 tbs this campaign. NEXT in Tier 5: BIF_BCTL_6
  / BIF_BCTL_SYNC_8 / BIF_DPATH_LDBCTL_12 / BIF_DPATH_PESPEA_13 /
  MEM_ADEC_45, then PAL_44445B_D/44446B_D and the DGA POW/COMM FSMs.

- 01-AUG-2026: **Cheap structural fixes 1-5 done** (item 6 untouched):
  1. `Verilog/CPU-BOARD-3202/circuit/sim/CPU_MMU_PT_29_tb.v` was already
     self-checking; added `test-mmupt` target + registered
     (`TB_RESULT: PASS (5 checks)`).
  2. `test-f595-transparency` **NOT registered - FAILS BY DESIGN**: the F595
     FPGA branch is the reverted lagging FF (transparent-latch fix was a
     comb-loop board-killer, reverted 19-JUL), and the tb's first check
     (zero-latency SET) fails. Documented in the run_all_tests.sh
     "NOT in the registry" block; register only if F595's FPGA branch is
     ever made transparent again.
  3. `F714_tb.v` moved `git mv` from `DGA/circuit/F714_TEST/` to
     `Verilog/DECODE-GateArray/DGA/sim/F714_tb.v`, rewritten self-checking
     (18 fixed checks; pins the RTL reset-priority behavior on the NEC
     R=S=1 prohibition row - RTL gives Q=0/QB=1, data sheet says Q=1/QB=1);
     target `test-f714`, registered. F714_TEST dir removed (its Makefile,
     readme, vcd/binary artifacts deleted; readme content was a duplicate
     of the truth table already in `F714.v`).
  4. `FIFO_tb.v` + `IDT6168A_20_tb.v` moved to `Verilog/Shared/support/sim/`;
     old `FIFO_8BIT_TB/` + `IDT6168A_20_TB/` dirs removed. The old FIFO tb
     NEVER CONNECTED the DUT clk port (FIFO never clocked, zero checks) -
     rewritten self-checking (25 fixed checks incl. write-when-full drop and
     read-when-empty zero), target `test-fifo`. IDT tb kept, upgraded to a
     `TB_RESULT` verdict with fixed count (10 checks) + ASCII-only comments,
     target `test-idt6168a`. Both registered.
  5. `Verilog/DELILAH-CPU/CGA_TESTMUX/sim/test_testmux.cpp` verdict converted
     to `TB_RESULT: PASS (25 checks)` / `TB_RESULT: FAIL`; new Makefile
     target `test-testmux` (Verilator build+run+grep); registered. Its stale
     obj_dir (old Verilator install paths) needed a `make clean` once.
  All five targets run and their pass lines verified from their sim dirs.

- 01-AUG-2026: **ND_TAPE_400 covered** - the last ND-BUS device with an
  empty sim/. New `ND-BUS-DEVICES/TAPE-400/sim/nd_tape_400_tb.v` (target
  test-tape400, 355 checks, registered), full stack through ND_BUS_SLAVE
  with the slave's iox_hit wired to the tape core's new iox_sel output;
  tape-array byte source in the tb (0x00 past EOF = the C model's blank
  tape). Covered: reset state, IOX 400/402/403, iox_sel decode (400/402
  hit; 377/404-407 foreign -> NO BDRY/BINPUT answer), RFT preset,
  activate -> byte_req -> byte_valid -> RFT with the wait window
  observable (slow-source directed test), full 16-byte stream readout,
  EOF, device clear (buffer wipe + source_rewind + rewound restart),
  level-12 interrupt lines, IDENT 02 on level 12 only (wrong-level poll
  no-hit, clear-on-IDENT keeps RFT, grant daisy chain via a strobe
  monitor), 32-op seeded random soak vs a register-level model. Oracle =
  nd100x devicePapertape.c; FOUR divergences PINNED as RTL behavior
  (PIN-D1..D4 in the tb header): reset RFT 0-vs-1, control write loads
  RFT from bit 3 vs oracle's unconditional RFT=1, device clear forces
  RFT=0 vs oracle's RFT=1, activate fetch is asynchronous (byte_valid)
  vs the oracle's instant in-write fetch. Teeth = status-bit swap
  (s_rft<->s_read_active, the FIDBO-swap class), 52 errors, FAILs.
  `nd_tape_sdfat_source` (the SD-FAT byte-source wrapper) remains
  uncovered - it needs the sd_card_model/nds_mem_model harness, Tier 6.

- 01-AUG-2026: **Tier 4 started - CGA_MAC_ADD covered**
  (`Verilog/DELILAH-CPU/CGA_MAC/sim/CGA_MAC_ADD_tb.v`, target test-mac-add,
  both build modes, 121536 checks per mode, registered). Confirmed pure
  combinational (A02 AOI + bubbled-OR PRP selector, NAND CDS network,
  FASTADD). Independent golden model derived from schematic intent:
  PRP[n] = (RB&PRB)|(BR&PB)|(XR&PX)|(LCA&PLCA) per bit (sources OR-merge
  when several selects are up), effCD = CDS ? sign-extend(CD[7:0]) : CD,
  ADD = (PRP+effCD) mod 2^16. Layers: 32-combo control sweep x 18 directed
  tuples (576), per-bit carry corners x 4 single-select modes (192), CDS
  low-byte exhaustive x 3 ignored high bytes (768), 120000 fixed-seed
  random vectors. No transcription error found; two header-comment
  imprecisions PINNED in the tb header: the CDS port comment says "only
  the low 8 bits are added" but the gates SIGN-EXTEND CD[7:0] (correct
  for signed displacement), and "Add CD if PLCA is low" is usage - the
  netlist adds CD unconditionally. Teeth = GATES_31 input pin moved to
  s_cdsn_nand_cd11 (wrong pin in the CD high-byte network), 29948 errors,
  FAILs. 59 tbs this campaign. NEXT in Tier 4: CGA_MAC_AP09,
  CGA_MAC_LA1025, CGA_ALU_OUTMUX.

- 01-AUG-2026: **CGA_MAC_AP09 covered**
  (`Verilog/DELILAH-CPU/CGA_MAC/sim/CGA_MAC_AP09_tb.v`, target
  test-mac-ap09, 13648 checks per build, registered). NOT pure comb: the
  wrapper instantiates CGA_MAC_APOS_CALCA (L8 latches + R81_EN registers),
  so it runs the full SEGPT-style THREE-build matrix (plain / FPGA_FF_MODE
  / USE_TRANSPARENT_LATCHES). Behavioral golden model from schematic
  intent: ICA[n] = (HOLD&LCA)|(PSEL&PR)|(ADDSEL&ADD)|(CDSEL&CD)|
  (NLCASEL&(LCA+1)) wired-OR per bit; NLCA = LCA+1 on the port
  UNCONDITIONALLY (NLCASEL only gates the ICA feedback); MCA = ICA[9:0]
  latched transparent while MCLK=0; LCA registered at the MCLK load event;
  ECCR = ~ECCRHIN & LCA[9:0]==10'o0115. Layers: 2 LCA contexts x
  exhaustive 32 control combos x 18 directed tuples, walking-1/0 per
  source (incl. HOLD/NLCASEL via 16 single-bit LCA loads), 28
  incrementer carry-corner loads, ECCR 4 upper-bit-variant hits + 10
  one-bit near-misses both ECCRHIN polarities, 8-pattern MCA
  transparency/hold, 4000-step fixed-seed xorshift soak with 1000 full
  load events + steered ECCR hits. Cross-mode PIN documented in the tb:
  an MCLK rise WITHOUT MCLK_EN clocks the CP-mode R81 but not the
  FF-mode one, so the tb never makes an LCA-dependent check after a bare
  MCLK rise until a full load resyncs (same class as the CALCA tb load
  pulse). Cosmetic only: ICA0B has the CDSEL/CD pin pair swapped vs bits
  1-15 (AND commutative, same function). No transcription error found.
  Teeth = ICA7B .C moved s_cd_15_0[7]->s_cd_15_0[8] (wrong-input-pin
  class), 1302 errors, FAILs. 60 tbs this campaign. NEXT in Tier 4:
  CGA_MAC_LA1025, CGA_ALU_OUTMUX.

- 01-AUG-2026: **CGA_ALU_OUTMUX covered (Tier 4, parent netlist)**
  (`Verilog/DELILAH-CPU/CGA_ALU/sim/CGA_ALU_OUTMUX_tb.v`, target
  test-alu-outmux, 101236 checks per mode, both build modes). Value-add is
  the selector wiring BETWEEN the already-covered submodules (16x SEL8 +
  the bit-7 SEL7 D-mux slices, 16x MUX31LP G-mux, IDBS enable decoder).
  NOT pure comb: the IDBS decoder registers the CSIDBS decode in two
  R81_EN on ALUCLK; ALUD2N stays combinational. Independent golden model
  re-derived from the gates: registered rcs routes D = EA_bus@1, GPR full
  @2, DBR@3, ARG@4, STS@6, {AARG0,LBA}@8, SW@9, {LAA,AARG0}@12, GPR
  low+sign-extend@18, FIDBI on every other code (incl. 0); slot 6 is
  EGPRL for bits 0-7 / EGPRH for 8-15; G[n] = ~(EA?A : EF?F : D) with
  EA/EF = rcs==0 split by unregistered ALUD2N. PINNED as netlist
  behavior: the G bus is INVERTED (MUX31LP.ZN), and at rcs==0 the D bus
  still shows FIDBI while G shows ~A/~F. Layers: exhaustive 32-rcs x
  2-ALUD2N select sweep x 4 distinct-constant tuples (512), walking-1/0
  per 16-bit bus under its selecting rcs incl. both GPR modes and A/F
  (640), exhaustive {LBA,AARG0}@8 + {LAA,AARG0}@12 on all-ones
  background (64), registered-vs-comb seam (stale CSIDBS without ALUCLK
  holds enables while D follows new data; ALUD2N flip without clock
  switches G ~A<->~F) (20), 25000-step fixed-seed LFSR soak with a
  no-pulse data/select mutation re-check per step (100000). Sim-only
  gotcha worked around in the tb: iverilog leaves logisim always @(*)
  primitives (Decoder_8) X until an input CHANGES, so the tb wiggles all
  inputs once before the init pulse - startup artifact, not DUT
  behavior. No transcription error found. Teeth = parent wiring mutant
  s_e_dmux4[7] s_eaarg->s_ebarg (wrong enable pin on one slice), 3228
  errors, FAILs. 61 tbs this campaign. NEXT in Tier 4: CGA_MAC_LA1025,
  CGA_WRF_RBLOCK, DECODE_DGA_IDBS.

- 01-AUG-2026: **CGA_MAC_LA1025 covered (Tier 4)**
  (`Verilog/DELILAH-CPU/CGA_MAC/sim/CGA_MAC_LA1025_tb.v`, target
  test-mac-la1025, 24962 checks per build, registered). NOT pure comb:
  LA23-10 sit in two R81_EN registers on MCLK; the module contains NO
  L4/L8/LATCH primitives, so plain and -DUSE_TRANSPARENT_LATCHES are
  identical netlists - the target still runs the full SEGPT three-build
  matrix for family uniformity (FPGA_FF_MODE is the real second mode).
  Behavioral golden model from schematic intent: each LA bit is a wired
  OR of its enabled source products - SEG[7:4] under A1617/B1821 (NAND
  registered through inverting QxN outputs, inversion cancels),
  LA19/18 = (A1619&~PCR[14/13])|(SEG[3/2]&B1821)|(~ICA[10/9]&A1819)
  |(~PCR[10/9]&B1819), LA17/16 = 7-term merge (ICA/PCR/SEG/XPT under
  A10/BB10/A1619/A1617/D1617/E1617/F1617), LA15..10 = ICA[n-10]&A10 |
  ICA[n-9]&BB10 | ICA[n]&C10; ECCRHIN = ~(LA15&~LA14..~LA10), low only
  at registered LA[15:10]==100000 - the upper bits of IOX 100115,
  matching CALCA's LCA[9:0]==0115 half. PCR[15] and PCR[6:0] pinned
  unused by the exhaustive sweep. Layers: EXHAUSTIVE 2^11 control-combo
  sweep x 4 distinct-constant tuples (16384), walking-1/0 per data
  input under each single select (520), ECCRHIN directed hits +
  one-bit near-misses through all three ICA paths (22), register hold
  with every input inverted and no clock event (32), 4000-step
  fixed-seed xorshift soak with steered ECCRHIN hits (8000). The
  regICA always@(s_ica_input) delta-copy is pinned as a pass-through
  (tb toggles ICA before priming so it never holds x). No
  transcription error found. Teeth = ILA13B input1
  s_ica_15_0[13]->s_ica_15_0[12] (wrong-input-pin class), 1753 errors,
  FAILs. 62 tbs this campaign. NEXT in Tier 4: CGA_WRF_RBLOCK,
  DECODE_DGA_IDBS, CGA_CPU_ALU_CONTR.

- 01-AUG-2026: **DECODE_DGA_IDBS covered (Tier 4)**
  (`Verilog/DECODE-GateArray/DGA/sim/DECODE_DGA_IDBS_tb.v`, target
  test-dga-idbs, 49281 checks default / 49137 checks -DFPGA_FF_MODE,
  registered). NOT pure comb: four F924 4-bit registers - A282 (panel
  PRQ/VAL/RIWR/DSTAT3 FSM) + A259 (RINR/EPAN/TRAALD) on CLK1, A248
  (ECSR/EIOR/EPES/EPEA) + A275 (EDO/RUART/internal MAPANS) on CLK0;
  both clock pins are XCLK in the parent, and in FF mode the single
  CLK_EN legally clocks all four. No latch primitives, so two builds.
  Independent golden model re-derived as exact octal code sets
  (ECSR=o24 EIOR=o16 EPES=o13 EPEA=o12 RUART=o37 RINR=o35 EPAN=o27
  TRAALD=o26 MAPANS=o21, EDO={0,1,2,3,4,6,10,11,14,15,22,23,25,31,36})
  plus register-level FSM equations (VAL'=RIWR_n&STAT4;
  RIWR'=STAT4&((VAL&MAPANS)|RIWR); DSTAT3'=STAT3&(DSTAT3|PRQ);
  PRQ'=~dec(20|21)&((STAT3&~DSTAT3)|PRQ); all LCSN-gated). Layers:
  power-on state (PINNED: flops init 0 so every active-low enable
  reads ASSERTED and VAL/RIWR/DSTAT3/PRQ/MAPANS read 1 until the
  first clock), exhaustive 32-code x 2-LCSN decode sweep with a comb
  EPANSN check before each clock (the documented A259.Q0 bypass -
  EPANSN comb while the other 9 enables are registered, checked
  no-clock), 23-step directed panel-FSM walk (PRQ set/hold, DSTAT3
  fence blocking re-set, clear via both MIPANS o20 and MAPANS o21,
  VAL->RIWR->VAL-drop chain through the MAPANS flag, RIWR hold on
  STAT4, LCSN=0 global mask), default-build-only clock-group routing
  (CLK0-only/CLK1-only pulses prove every register's clock pin - 12
  checksets), 4000-step fixed-seed xorshift32 soak with steered panel
  codes. STALE-COMMENT findings (gates internally consistent, DUT
  untouched): A250's comment claims "12=PEA,13=PES,16=IOR,17" but its
  term (~b4&b3&~b1) decodes o10/o11/o14/o15 - which is what the EDO
  merge needs since 12/13/16 have their own enables; the EDON port
  comment omits o15/o22/o23/o31 which the gates fire on (o22/o23 are
  A256's commented GPR_SE/PGS). No functional transcription error
  found. Teeth = A251 (PEA) s_csidbs_4_0[1]->s_csidbs_1_n
  (dropped-inversion class, moves PEA from o12 to o10), 192 errors,
  FAILs both modes. 63 tbs this campaign. NEXT in Tier 4:
  CGA_WRF_RBLOCK, CGA_CPU_ALU_CONTR.

- 01-AUG-2026: **CGA_CPU_ALU_CONTR covered (Tier 4)**
  (`Verilog/DELILAH-CPU/CGA_ALU/sim/CGA_CPU_ALU_CONTR_tb.v`, target
  test-alu-contr, 256305 checks per build, registered). NOT pure comb:
  ALUCLK registers (2x D_FLIPFLOP_EN, 2x R41P_EN, R81_EN CONTR_REG)
  plus the L8 SSEL_LATCH transparent on LDIRV - full SEGPT three-build
  matrix (plain / FPGA_FF_MODE / USE_TRANSPARENT_LATCHES). Independent
  behavioral golden model: CSALUM mode decode (01: alui1n=DGPR0, 10:
  alui3n=DGPR0, 11: shift-type - SSEL from the CD[10:9] latch, ALUI7/8
  from UPN/LCZN), registered SA/SB/RA/RD source decode, RSN/FSEL/LOG
  function decode, BDEST/ALUI4/6/7/8, and the comb post-register
  outputs (MI/QLI/RRI/RLI serial-input selects per SSEL state, GPRLI
  majority(STS7,CRY,GPR0), GPRC XFETCH/LDGPR codes, QSEL, ALUD2N,
  CSTS, CI 0/1/STS6/GPR0). Layers: exhaustive 2-aux-tuple x 4-CSALUM x
  512-CSALUI control sweep (4096 calls), 4-register-state x 1024
  async-combo no-clock sweep incl. register-input churn = hold proof
  (4100), SSEL-latch late-data + stale-hold directed (8, PIN-4), 4000
  fixed-seed xorshift soak with latch reload every 5th step; every
  call checks all 21 output fields. Every latch load uses the
  late-data protocol (garbage on CD at the LDIRV rise, real value only
  later in the high window) so the FIXED transparent capture is locked
  in. PINNED: (1) net s_alui3n carries CSALUI[3] UNINVERTED outside
  CSALUM=10 (ALUI3_MUX.B is the pre-inverted s_csalui3_n, MUX21LP
  negates again) while sibling s_alui1n carries ~CSALUI[1] - polarity
  asymmetry flagged for a schematic audit, behavior pinned (self-test
  and the 13-area instruction campaign pass with it); (2) CSTS[1]
  mixes registered CSSST[1]/ALUI8 with the CURRENT unregistered
  CSALUM==11 decode; (3) CI decodes 00->0, 01->1, 10->STS6, 11->GPR0 -
  the CSCINSEL port comment is usage text. Teeth = the exact
  historical bug class re-introduced (L8 SSEL_LATCH replaced by
  rise-edge D flip-flops on LDIRV - the bug that ran every ROT /
  ZIN-right / LIN shift as a plain shift): 1890 errors, all on
  SSEL-dependent outputs under CSALUM=11, FAILs. 64 tbs this
  campaign. NEXT in Tier 4: CGA_WRF_RBLOCK.

- 01-AUG-2026: **CGA_WRF_RBLOCK covered (Tier 4, parent netlist) - TIER 4
  COMPLETE** (`Verilog/DELILAH-CPU/CGA_WRF/sim/CGA_WRF_RBLOCK_tb.v`, target
  test-wrf-rblock, 47349 checks per build, registered). Submodules
  SEL16/LR16/DR16 already have their own tbs; value-add is the
  register-file addressing/selection wiring: 16 registers (0=Z 1=D 2=P
  3=B 4=L 5=A 6=T 7=X 8=STS 9..15=R1..R7), per-register WR_15_0[k]
  strobe, wired-OR read ports A=|(EA[k]&reg[k]) / B=|(EB[k]&reg[k]),
  and the three direct latched outputs (PR from the PREG mux while
  ALUCLK=0, BR/XR = LR16 latches gated ~ALUCLK&WR[3]/WR[7]). Contains
  L8 latches AND R81_EN/DR16 registers - full three-build matrix
  (plain / FPGA_FF_MODE / USE_TRANSPARENT_LATCHES). Independent golden
  model: behavioral 16x16 register array with own decode; PREG source
  priority re-derived from MUX31LP sel={WR2,XFETCH} (00 hold, 01 NLCA,
  1x RB - WR2 wins, phantom D3=D2). Layers: distinct-constant defining
  load + full both-port read-back (decode swap catch), WR=0 strobe
  gating, XFETCH-only P load, WR2-over-XFETCH priority directed,
  read-select corners (EA=EB=0 -> 0, multi-enable wired-OR,
  all-enable), exhaustive 16x16x2 walking-1/0 crossbar (all 256
  register-bit crossings both polarities), PR/BR/XR latch-close
  semantics (transparent pre-edge, held with RB churn while ALUCLK=1,
  reopen, WR-close), no-clock hold, 4200-step fixed-seed LFSR soak
  with multi-bit random WR checking all five buses pre and post edge.
  No transcription error found; tb-noted L8 nuance: the FPGA-form
  latch refreshes its hold value only at posedge sysclk while open, so
  a sub-sysclk transparency window is not retained on close (tb keeps
  gates open across a sysclk edge before closing - all three latch
  forms then agree). Teeth = R5_REG_13.WR moved to s_wr_15_0[12]
  (regs 12/13 alias on write): 1776 errors, FAILs. 65 tbs this
  campaign. Tier 4 is done - all seven Tier-4 modules (ADD, AP09,
  OUTMUX, LA1025, IDBS, ALU_CONTR, RBLOCK) are covered.

- 01-AUG-2026: **Tier 5 BIF trio covered: BIF_BCTL_SYNC_8 /
  BIF_DPATH_LDBCTL_12 / BIF_DPATH_PESPEA_13** (all three in
  `Verilog/CPU-BOARD-3202/circuit/sim/`, registered).
  BIF_BCTL_SYNC_8 (`BIF_BCTL_SYNC_8_tb.v`, target test-bifsync, 52884
  checks): two AM29C821 registers on posedge OSC building the
  25/50/75ns bus-handshake delay taps, PD3/PD1 comb output kills. The
  netlist has NO ifdef branches (AM29C821 default USE_SYSCLK=0), so ONE
  build is the complete mode set. Independent two-word golden model
  reproduces the 4D self-feedback taps (BINPUT75 re-registers BINPUT50,
  BDRY75 re-registers BDRY50) and the PD3-poisons-next-capture
  interaction (gated zeros read as ASSERTED downstream - checked, not
  avoided). Layers: power-on, per-input 25/50/75 tap walks (all 10
  inputs), no-clock hold, PD comb kills + PD3-across-an-edge, 4000-step
  fixed-seed soak checked after every edge. Teeth = chip-4D input pin
  moved s_bdry50_n -> s_bdry25_n (BDRY75 becomes a 50ns tap): 1739
  errors, FAILs.
  BIF_DPATH_LDBCTL_12 (`BIF_DPATH_LDBCTL_12_tb.v`, target test-ldbctl,
  94347 checks per mode, plain-FF + -DUSE_TRANSPARENT_LATCHES): the
  three LBC PALs (44303B/44302B/44304E) incl. the sheet-level BACT_n
  feedback into 44303B's WBD DMA term. Independent 5-state-bit golden
  (CBWRITE/CMWRITE/EMD/BACT/EBADR_n set-priority rules re-derived from
  the PALASM comments) with mode-switched semantics (latch = immediate
  on input change, FF = posedge OSC + async sys_rst_n); SAME stimulus
  and check counts in both modes, zero latch-vs-FF divergence found
  under this tb's one-change-then-check discipline. PINNED: top port
  BGNTCACT carries the ACTIVE-LOW ~(BGNT|CACT) value despite the
  un-suffixed name; 44304E ignores TEST so PD3 kills only the 44302B
  outputs and PD1 only the 44303B outputs. Layers: latch-X init
  wiggle + FF power-on reset, directed set/hold/clear walks for all
  five state bits (both EMD set terms, all three hold terms, the IOX
  IOD&MIS0&BINPUT50_n direction term, all three DSTB products, PD
  kills over live state), two 256-combo clock-frozen comb sweeps,
  4000-step soak checked after settle AND edge. Teeth = 44302B
  .BDRY25_n fed from s_bdry50_n (wrong-input-pin on the audited DSTB
  middle term): 228 errors, FAILs both modes.
  BIF_DPATH_PESPEA_13 (`BIF_DPATH_PESPEA_13_tb.v`, target test-pespea,
  4118 checks per mode, plain + -DFPGA_FF_MODE): the PEA/PES error
  registers on the silicon-validated PES/SPEA path (PAGING 11/11);
  locks in the FIXED behavior. PINNED: CHIP_10A (PES[7:0], the MS
  physical-address byte BD23..16) clocks on SPEA not SPES - a later
  SPES with different BD must NOT move PES[7:0]; PES[14]=GNT asserted
  (active-low GNT_n through the inverting 74534); registers power up X
  so reads are only enabled after both loads. Layers: directed
  captures + wired-OR enable matrix + FETCH x GNT_n combos, the
  pinned 10A-on-SPEA check, edge-not-level strobe-held churn, a
  per-mode capture-instant divergence phase (plain samples at the
  strobe rise, FF at the next sysclk), walking-1/0 over all 24 BD_n
  bits, 4000-step soak. Sim note: the tb gives 1ns data setup before
  each strobe rise - same-timestep data+strobe races the posedge
  block in iverilog (found live during bring-up, stimulus fixed).
  Teeth = CHIP_10A .CK moved to s_spes (the "looks right" wiring):
  1282 errors, FAILs both modes. 68 tbs this campaign. No
  transcription error found in any of the three sheets. NEXT in
  Tier 5: MEM_ADEC_45, PAL_44445B_D/44446B_D, DGA POW/COMM FSMs.

- 01-AUG-2026: **DECODE_DGA_POW covered (Tier 5)**
  (`Verilog/DECODE-GateArray/DGA/sim/DECODE_DGA_POW_tb.v`, target
  test-dga-pow, registered). FIVE builds cover every ifdef path: plain
  61802 checks (sync F595, ripple-chain F714s, default 100MHz RTC limit
  1999999/499999 checked statically via s_rtc_limit), -DVERILATOR_SIM
  61957 (transparent F595, 8192/2048 fire tests + RUNTIME period pokes
  through the public_flat_rw s_rtc_20ms_var/s_rtc_5ms_var regs -
  hierarchical writes, fire re-measured at 97/25),
  -DVERILATOR_SIM -DRTC_SIM_20MS=600 61957 (build-knob override, 600/150
  incl. the /4 ratio), -DFPGA_FF_MODE -DBOARD_CLK_FREQ=25600 61894
  (synchronous chain + A572 sysclk capture, derived limit 511/127 run
  dynamically), -DVERILATOR_SIM -DFPGA_FF_MODE 61957 (sim FF-mode
  combination). Independent settled-point golden model (F595 truth table
  incl. S&R->Q=1,QB=1; ripple chain as binary counter; F617
  old-value-sample semantics; independent RTC mirror). TOUT gates
  MEASURED and pinned for the deferred Tang analysis: rfclk=RTOSC/2;
  A630 raises a refresh request (REFRQN=0) on EVERY rfclk rise, REFN
  async-acks it; A631 samples the PRE-EDGE REFRQN each rfclk rise
  (BDRY50N async-sets it); TOUT=~(A631.Q|rfclk) - a PERIODIC LEVEL
  during rfclk-low halves once a request survives one full rfclk period
  unacked (first assert 3 RTOSC rises after the request), cleared by
  BDRY50N immediately, by an acked cycle at the next rfclk rise, or by
  CLOSC (forces rfclk=1). RTC pinned: fire at EXACTLY limit+1 sysclk
  edges after CLRTIN release, then LATCHED low until CLRTIN or RESCL.
  PINNED build divergences (tb header P1/P2): VERILATOR_SIM builds set
  the A574 RESTART flag on EVERY sys_rst_n release (a579n falls before
  A572's NBA capture drops s_lrst) and leave the STOP flag SET; the
  non-VERILATOR builds (FPGA) never set RESTART and leave STOP CLEAR
  (F595 forced idle during reset). Dead logic pinned: the
  A620/A624/A616/A618/A617/A627/A626 JK divide chain drives no output
  (TESTE observable only at the A620 mux, checked hierarchically).
  TANG_NO_RTC_PAN diagnostic knob not built. Teeth = A631 D pin moved
  to s_vcc in BOTH branch implementations (wrong-input-pin in the TOUT
  chain): 164 errors, first at the TOUT expiry check, FAILs in plain,
  FF and VERILATOR builds. 66 tbs this campaign. NEXT in Tier 5:
  BIF_BCTL_6, BIF_BCTL_SYNC_8, DECODE_DGA_COMM.

- 01-AUG-2026: **Tier 5 sheet-45 trio covered: MEM_ADEC_45 (real DUT) +
  PAL_44445B_D + PAL_44446B_D**, all registered.
  MEM_ADEC_45 (`CPU-BOARD-3202/circuit/sim/MEM_ADEC_45_tb.v`, target
  test-adec, 28602 checks per build, plain + -DFPGA_FF_MODE): replaces the
  inline-model-only coverage of `CPU-BOARD-3202/sim/reqgnt_equiv_tb.v`
  (untouched) with the REAL sheet: base PALs 44445B/44446B/44904B +
  D_FLIPFLOP flags in plain, the _D mirrors + sysclk edge-detect flags in
  FF mode; same stimulus/counts both builds, settled-point discipline
  (strobes sysclk-domain, >=1 cycle wide, data stable across rises).
  Covered: all four PPN/BD bank codes through both grant gates, MWRITE
  both PALs, CLRQ/CRQ literal walks (PPN20 don't-care proven; the MOFF
  products are untestable at sheet level - MOFF_n tied 1 - and are covered
  in the PAL unit tbs), AOK literal walk via the BLRQ flag (incl. BD20 NOT
  in AOK), request/grant set/hold/clear/grant-dominant/edge-not-level for
  BLRQ and RLRQ, the PIN-1 both-granted forced 111/1, 4000-step fixed-seed
  soak. **PIN-1 SUSPECTED-TRANSCRIPTION-ERROR in MEM_ADEC_45.v (benign
  under arbiter mutual exclusion): the sheet comment says BANK/MWRITE_n
  are "pulled high when CGNT_n and BGNT_n both are HIGH" (tri-state
  pull-up), but the gates test `(~s_bgnt_n & ~s_cgnt_n)` - both LOW, i.e.
  both GRANTED - for the forced-1 value; with NO grant the gates give
  BANK=000/MWRITE_n=0 where the pull-up reading gives 111/1. Pinned, DUT
  untouched.** Also pinned: RLRQ sets on the RISING edge of REFRQ_n; PD4
  only gates the unused 44904B LCD outputs. Teeth = dropped AOK qualifier
  on the BLRQ flag d-input in BOTH branch implementations (the reqgnt
  d-qualifier class): 806 errors, FAILs both builds.
  PAL_44445B_D (`PAL/sim/PAL_44445B_D_tb.v`, target test-44445b-d, 61495
  checks) and PAL_44446B_D (`PAL/sim/PAL_44446B_D_tb.v`, target
  test-44446b-d, 61495 checks): base PAL and _D mirror side by side vs ONE
  golden model re-derived independently from the PALASM header comments
  (PAL16R4 registered-inverting Q + comb B outputs; 44446B keeps the board
  CK=DBAPR tie). Layers per PAL: EXHAUSTIVE 128-combo input sweep x
  {CK-low held, CK-rise capture, OE-disabled} - every product literal
  asserted and deasserted incl. the 44445B CLRQ PPN20 don't-care merge and
  BD20 absent from 44446B AOK - plus edge-not-level churn under held CK,
  mid-run _D-only reset (base holds, mirror clears - dual golden register
  sets), 4000-step fixed-seed soak with steered resets. AUDIT: gates match
  the PALASM comments in both PALs and both mirrors - no transcription
  error. PINNED: disabled-output asymmetry (44445B drives MWRITE_n=1 when
  OE_n=1, 44446B drives 0 - masked by MEM_ADEC grant gating); _D reset
  state BANK=000/MWRITE_n=1; _D re-capture hazard if reset released under
  held-high CK (tb only resets with CK low, matching the parent). Teeth:
  44445B = dropped inversion BANK1_n_reg PPN21_n->PPN21 (798 errors),
  44446B = dropped BD21 literal from AOK (119 errors), both FAIL. 71 tbs
  this campaign. NEXT in Tier 5: BIF_BCTL_6, DECODE_DGA_COMM.

## Build order for missing testbenches

**Tier 1 - small pure-comb CPU-core netlists (exhaustive golden-table):**
CGA_MAC: FASTADD(69) PTSEL(131) SEGPT_SEG(115) SEGPT_XPT(127) SEGPT_PCR(133)
SEGPT(138). CGA_ALU: SWAP(115) OUTMUX_SEL7(118) OUTMUX_SEL8(129)
RALU_MUX216L(169) RMUX(183) RALU_LOGOP(223) SMUX(220) SHIFT(233).
CGA_IDBCTL: SEL6(97) PGSREG(232). CGA_MIC: CSEL(164) INCOUNT(158) IINC(225)
IPOS(248). CGA_WRF: RBLOCK_SEL16(230) RBLOCK_LR16(304). CGA_INTR:
CLR_CLRBIT(92) VECGEN(180) - closes CGA_INTR to 100%.

**Tier 2 - `_EN` equivalence tbs (DUT-vs-reference, no golden table):**
Shared/ndlib: SCAN_WITH_RESET_N_EN, SCAN_WITH_SET_N_EN, SR44_EN, M169C_EN,
F924_EN vs base modules. PAL: 44402D_EN, 44403C_EN, 44404C_EN, 44407A_EN,
44408B_EN, 44511A_EN vs base PALs.

**Tier 3 - mid-size comb decode/mux:** CGA_ALU DBR/QREG/STS/OUTMUX_IDBS/GPR;
CGA_MAC APOS_INC/APOS_CALCA/LASEL; CGA_MIC STACK_BIT/STACK_BIT12/STACK/
WCAREG/CONDREG; DGA F091/F103/F571/F924; CPU-BOARD CPU_STOC_35,
CPU_MMU_CACHE_25, MEM_LBDIF_48, MEM_RAMC_50, IO_PANCAL_40.

**Tier 4 - large comb (generated golden tables):** CGA_MAC_ADD(684),
CGA_MAC_AP09(709), CGA_MAC_LA1025(616), CGA_ALU_OUTMUX(945),
CGA_CPU_ALU_CONTR(912), CGA_WRF_RBLOCK(1272), DECODE_DGA_IDBS(601).

**Tier 5 - sequential/FSM:** CGA_MIC_MASEL_REPEAT, CGA_ALU_ARG,
CGA_WRF_RBLOCK_DR16; BIF_BCTL_6, BIF_BCTL_SYNC_8, BIF_DPATH_LDBCTL_12,
BIF_DPATH_PESPEA_13, MEM_ADEC_45 (replace the inline model in
`Verilog/CPU-BOARD-3202/sim/reqgnt_equiv_tb.v` with the real DUT),
PAL_44445B_D, PAL_44446B_D; DGA DECODE_DGA_POW(662), DECODE_DGA_COMM(1252),
F617; ND_TAPE_400 + nd_tape_sdfat_source (only ND-BUS device with an empty
sim/ - mirror the nd_floppy_*_tb.v set).

**Tier 6 - memory/storage & board glue (needs models):** sd_file_reader,
sd_fat_check, sd_fat_freescan, sd_fat_rewrite; Shared/support memories
(Am9150, TMM2018D_25, IMS1403_25, AM29841, AM29861A, TTL register family);
BIF_5, BIF_DPATH_9, MEM_43, IO_37, IO_DCD_38, CPU_15, CPU_PROC_32, ND3202D;
ND120_TOP / ND120_CORE (add real self-checks to `Verilog/sim/test_nd120.cpp`
- currently zero assertions).

**Skip/deprioritize:** `Verilog/Shared/logisim/*` gate primitives (one
parameterized sweep tb can cover all 36 in a single file);
`CPU_CS_PROM_19_ORG.v` (generated data); `Verilog/PAL/template/*`.

## Campaign conventions (every new tb)

- Self-checking, `TB_RESULT: PASS (<n> checks)` / `TB_RESULT: FAIL` verdict;
  a fixed expected check-count so a silent partial run fails.
- Registered in `Verilog/tests/run_all_tests.sh` with a strict pass pattern.
- Teeth-proven: a deliberate DUT mutation (compiled from a scratch copy,
  never committed) must make the tb FAIL before the tb counts as done.
- Golden tables generated by an INDEPENDENT model (script kept alongside the
  tb or in the commit message), never by copying the DUT's own equations
  blindly - re-derive from the schematic/PALASM where they exist.
