# BFILL / BYTE-STRING STS corruption - static analysis (microcode semantics vs RTL)

Date: 17-JUL-2026. Static analysis only; no simulations were run for this
document. Every claim below is tagged VERIFIED (read directly from the cited
source) or INFERRED/UNKNOWN.

Symptom under analysis (measured earlier, not re-measured here): after BFILL
the STS register reads 025052 (0x2A2A = the fill word), entry value was
077760 (0x7FF0); the INSTRUCTION-B BYTE-STRING framework then re-runs BFILL
forever (IRW writes level-1 registers, triggers level 1, IRR verifies).

## 1. TRUE microcode semantics (ground truth: the C# microcode emulator)

### 1.1 COMM,EWRF and IDBS,REG address by FIELD VALUE, not register content

VERIFIED in /mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/Cpu.cs:

- EWRF (line 1313): `hw.RF.Write(hw.alu.A_Operand, hw.alu.B_Operand,
  hw.idb.ReadWord())` - IDB is written to the external register file cell
  addressed by the raw A-operand and B-operand values.
- IDBS,REG (lines 3069-3089): `hw.RF.Read(hw.alu.A_Operand,
  hw.alu.B_Operand)` onto the IDB - same addressing.
- A_Operand/B_Operand come from the microword fields themselves when no
  special RASEL/RBSEL mode is selected: RBSEL case 0 takes microword bits
  16-19 (Cpu.cs line 2899), RASEL case 0 takes bits 12-15 (line 2939).
- RegisterFile.Write/Read (/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/RegisterFile.cs
  lines 117-136) index a 16x16 array: [A-operand (level slot), B-operand
  (register slot)].

Token encodings (VERIFIED,
/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110Compile/ND120Tokens.cs):

- `A,R3` = A-op 13 octal (line 22), `B,R6` = B-op 16 octal (line 72).
- `COMM,EWRF` (line 221): "IDB -> REGISTER FILE WORD ADDRESSED BY A-OP AND
  B-OP".
- `AB,SSAVE` (line 370): A-op 13, B-op 16, described as "SCRATCH WORD HOLDING
  STS DURING DECIMAL INTRUCTIONS".

Consequence - THE CONFLICT IN THE TASK STATEMENT DISSOLVES (VERIFIED):

- CSA 01341 (`A,R3 ... B,R6 COMM,EWRF IDBS,STS`,
  /mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah.uc line 1751) saves the
  hardware STS into external register-file cell [013,016] - the fixed global
  scratch cell AB,SSAVE. It is saved into NEITHER local R3 NOR local R6.
- CSA 01355's R3 increment (uc line 1777) writes LOCAL working-register 013
  (R3, the byte pointer). Different storage entirely; no conflict.
- CSA 01345 (`A,R3 ... B,R6 IDBS,REG STS,LO`, uc line 1759) reads the same
  cell [013,016] back onto the IDB and STS,LO restores hardware STS bits 0-7.
- CSA 01342's `B,R6` (uc line 1753) writes LOCAL register 016 (R6) - also
  does not touch bank cell [013,016].

### 1.2 Register numbering and the two different "STS" storages

VERIFIED: C# RegisterEnum
(/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/Enums.cs lines 899-939):
0=Zero ("ZERO REG., STATUS OR SCRATCH"), 1=D, 2=P, 3=B, 4=L, 5=A, 6=T, 7=X,
8=STS ("STATUS OR SCRATCH"), 9-15=R1-R7. The RTL local working register file
uses the identical numbering (VERIFIED, header comment of
/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_WRF/circuit/CGA_WRF.v
lines 15-31).

Three distinct things exist:

1. The HARDWARE STS register (C#: BUFALU.STS_value,
   /mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/BUFALU.cs line 107; RTL:
   /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_STS.v).
   Written ONLY by the CSST field ops (STS,EA / STS,ES / STS,LO) and by
   COMM,LDPIL (high byte). IDBS,STS reads it (Cpu.cs lines 3090-3092).
2. LOCAL working register 010 octal ("B,STS"/"A,STS") - a SCRATCH register.
   Writing it (e.g. BFLOO 01354 `A,R2 ALUD,B ALUF,PASSA B,STS`, uc line 1775)
   does NOT touch the hardware STS. BFILL's per-iteration scratch use of it
   is legal.
3. The per-level STS slot the framework verifies. IRR/IRW address register 0
   within the level: IRR at CSA 00403 (`A,REG ... IDBS,REG` with EMPTY B
   field = B-op 0, uc line 657) reads bank[level][0]; IRW at CSA 00424
   (`A,REG ... B,DEST COMM,EWRF`, uc line 696) writes bank[level][dr], and
   the IRR/IRW dr code for STS is 0 (C# RBSEL case for B,DEST:
   `Operand & 7`, Cpu.cs line 2903). When level == PIL, IRW instead updates
   the live hardware STS directly (CSA 00422 `ALUF,PASSA STS,LO`, uc line
   691).

### 1.3 What writes the per-level slot on switch-away: LVSWP

VERIFIED from /mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah.uc lines
1477-1499 (LVSWP, CSA 01146-01160):

- 01150 (line 1482): `ALUD,B ALUF,PASSD IDBS,STS` with EMPTY B field ->
  hardware STS is copied into LOCAL register 0.
- 01151 (line 1484): `A,PIL ALUD,Q ALUF,PASSB B,LC COMM,EWRF LCOUNT` loop ->
  local registers [LC..0] are copied to bank[PIL][LC..0]; the last write puts
  local reg 0 (= hardware STS) into bank[PIL][0]. This is the ONLY microcode
  path that refreshes the IRR-visible per-level STS on switch-away.
- Restore side: 01156 (line 1494) loop loads local regs from bank[newPIL],
  01153 (line 1488) `COMM,LDPIL` loads STS bits 8-15 from the IDB (ALU
  result), 01160 (line 1498) `ALUF,PASSA STS,LO` with empty A field (A-op 0)
  restores STS bits 0-7 from local register 0.

C# confirms LDPIL semantics and that flag preservation across a level switch
is the microcode's job, not LDPIL's (Cpu.cs lines 1300-1310).

So: if the RTL corrupts the hardware STS during BFILL, LVSWP faithfully
propagates the corruption into bank[1][0], IRR reads it back, and the
framework verify fails forever - exactly the observed hang. The scratch fill
word in local/bank register 010 is NOT itself a failure.

## 2. RTL paths checked against these semantics

### 2.1 EWRF / IDBS,REG addressing - MATCHES

VERIFIED, /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/CPU-BOARD-3202/circuit/CPU_PROC_32.v:

- lines 286-289: external register-file address = {2'b0(RASEL bits 9:8),
  LBA_3_0 (bits 7:4, register), LAA_3_0 (bits 3:0, level)} - one-to-one with
  the C# [A,B] cell for both read and write (same packing on both sides).
- lines 456-474: registerBlock write gated by ERF_n/TWRF_n (EWRF decode in
  CPU_PROC_CMDDEC_34), read is the WRTRF/ERF-gated async read.

VERIFIED, /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v:

- LAA muxes (lines 949-987): RASEL 0 -> CS bits 15:12; 1 -> PIL; 2 -> IR
  bits; 3 -> LC. LBA muxes (lines 1012-1050): RBSEL 0 -> CS bits 19:16;
  1 -> {0, IR[2:0]} (B,DEST); 2 -> IR[5:3] (B,SRCE); 3 -> LC. Both are
  registered on MCLK (LAA_REG line 989, LBA_REG line 1053). All match the C#
  RBSEL/RASEL cases (Cpu.cs lines 2899-2979), including dr=0 -> slot 0 for
  IRR/IRW STS.

### 2.2 Local WRF - MATCHES (register 0 is a real register)

VERIFIED: /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_WRF/circuit/CGA_WRF_RBLOCK.v
line 925 instantiates `CGA_WRF_RBLOCK_DR16 Z_REG_0` - local register 0 is a
real 16-bit register, so LVSWP 01150's write of hardware STS into local reg 0
is representable. STS_REG_8 (line 1040) is the separate scratch "STS slot".

### 2.3 CGA_ALU_STS - re-checked, consistent with prior verification

VERIFIED, /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_STS.v:

- Bits 0-3: SCAN_FF with TE = NAND(CSTS[1],CSTS[0]) (GATES_2, lines 128-134,
  FFs lines 288-330) -> load FIDBO only when CSTS==3.
- Bits 4-7: muxes (lines 141-176): CSTS==3 -> FIDBO; EA -> CRY/OVF/O-sticky;
  ES -> MI into bit 7; else hold.
- Bits 8-15: SCAN_FF with TE = LDPILN (lines 198-284) -> load FIDBO high byte
  only when LDPILN is low. LDPILN decodes COMM==00001 only (VERIFIED,
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_DCD/circuit/CGA_DCD.v
  GATES_13, lines 820-833, from the REGISTERED COMM bits) - COMM,EWRF (=3)
  cannot assert it, and the decode inputs are registered so a zero-delay
  simulation cannot glitch it.

Consequence (VERIFIED structure): a full 16-bit STS load of 0x2A2A requires
FIDBO==0x2A2A while BOTH CSTS==3 (bits 0-7) AND LDPILN==0 (bits 8-15) are
captured - and no single microword in the BFILL region (CSA 01333-01360)
legally produces either condition with the fill word on the IDB. The only
CSST!=0 word is 01345 (STS,LO, IDB sourced from bank cell [013,016]); the
only LDPIL words in the switch path are LVSWP 01153 / entry code, whose IDB
is the computed new-level STS word.

### 2.4 CSTS generation in CGA_CPU_ALU_CONTR - CONFIRMED DIVERGENCE (pipeline skew)

/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_CPU_ALU_CONTR.v:

- CSTS[0] = CONTR_REG QE = ALUCLK-registered CSST[0] (lines 879, 892).
- CSTS[1] = NAND(s_icsst1, s_gates49_out) (GATES_48, lines 710-716), where
  s_icsst1 = registered ~CSST[1] (QFN, line 895) and s_gates49_out =
  NAND(s_alui8, s_gates1_out) (GATES_49, lines 718-724).
- s_alui8 is REGISTERED (CONTR_REG QD, line 890; D input via CSALUI8_MUX,
  lines 814-819) - i.e. it belongs to the EXECUTING microword.
- s_gates1_out = AND(CSALUM[1], CSALUM[0]) (GATES_1, lines 286-292) - the
  RAW, UNREGISTERED CSALUM field. Every other execute-side consumer of the
  microword fields in this module goes through CONTR_REG/REG_RFLA4/REG_BAAD
  first; gates1_out is also (correctly) used pre-register to steer the
  fetch-side muxes (CSMIS1/0_MUX, CSALUI7/8_MUX, lines 793-819). Reusing the
  same combinational term on the execute side mixes two microword
  generations. (That the raw fields belong to the next microword at execute
  time is INFERRED from this module's own register structure, not from the
  DELILAH schematic, which was not consulted.)

Ground-truth semantics (VERIFIED, C#): the "M is set automatically" forcing
term must use the EXECUTING word's ALUM and i8 - Cpu.cs line 2859
(`if (hw.alu.ALUM == ND_ALUMode.IR_SHIFT)`) with hw.alu.ALUM assigned from
the current microword (line 2429), gated by the current word's i8 (line
2875). ALUM,IR = CSALUM 11 (ND120Tokens.cs line 181).

Failure signature of the skew (derived from the verified gate structure):
during any microword W whose registered alui8==1 (any shift-type ALU
destination, including plain ALUM,MIC shifts like BFILL's 01342 ALUD,SRB),
if the word at the NEXT control-store address has CSALUM==11, then CSTS[1]
is forced high during W:

- W has CSST=00 -> CSTS becomes 2 (ES): STS bit 7 (M) is spuriously
  reclocked from MI.
- W has CSST=01 (STS,EA) -> CSTS becomes 3 (LOAD): STS bits 0-7 are loaded
  from the IDB - a genuine low-byte corruption vector.
- Conversely a real ALUM,IR shift word followed by a non-ALUM-11 word loses
  its forced ES.

Checked against BFILL itself (VERIFIED from the uc listing): no word in CSA
01333-01360 carries STS,EA or ALUM,IR, and 01342's successor (01260/01343)
has CSALUM=00 - so within BFILL proper this skew can at worst corrupt the M
flag (STS bit 7), not produce 0x2A2A. Whether the surrounding BYTE-STRING
framework code (fetch/loop/shift sequences between iterations) hits the
STS,EA-followed-by-ALUM,IR pattern is UNKNOWN statically.

## 3. Verdict

1. RESOLVED (semantics): the task's R3-vs-R6 conflict is a misreading -
   EWRF/IDBS,REG address the bank by literal A/B field values; BFILL keeps
   the saved hardware STS in the global scratch cell [013,016] (AB,SSAVE),
   which neither the R3 increment (local reg 013) nor 01342's B,R6 (local
   reg 016) touches. The microcode is self-consistent.
2. RESOLVED (per-level STS): the IRR-visible per-level STS is bank slot 0,
   refreshed only by LVSWP 01150/01151 copying the LIVE hardware STS on
   switch-away. RTL addressing paths for this (LAA/LBA muxes, board
   registerBlock, local reg 0) all match the C# emulator. Therefore the
   observed persistent 025052 means the HARDWARE STS register itself was
   0x2A2A when the CPU left level 1; the framework hang is a faithful
   downstream consequence, not a separate slot-rewrite bug.
3. CONFIRMED RTL-vs-emulator divergence: CGA_CPU_ALU_CONTR GATES_49
   (/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_CPU_ALU_CONTR.v
   lines 718-724) evaluates the ES-forcing term with the registered
   (executing-word) alui8 but the unregistered (next-word) CSALUM via
   s_gates1_out (lines 286-292). Per the C# ground truth both must be the
   executing word's. The fix direction is a registered ALUM==11 term (e.g.
   register s_gates1_out through the same ALUCLK stage) for the GATES_49
   input only - the pre-register mux uses must keep the combinational term.
4. NOT PROVEN statically: that this skew is the mechanism behind 0x2A2A in
   BFILL. The verified CGA_ALU_STS structure says a full 0x2A2A load needs
   CSTS==3 and LDPILN==0 with the fill word on FIDBO, and no BFILL-region
   microword does that legally. Surviving hypotheses, in order:
   - H1: the skew (or a sibling same-class IDBS/FIDBO pipeline skew) fires in
     the framework code around BFILL, loading STS low byte from a fill-word
     IDB, and a second skewed event (or LVSWP's LDPIL with a corrupted local
     reg 0) propagates it to the high byte.
   - H2: at CSA 01345 the FIDBO capture edge sees a neighboring word's IDB
     value instead of the bank-cell read (IDB-source timing), restoring junk.
   - H3: the earlier measurement probed the WRF scratch register 010
     (labelled "STS" in CGA_WRF) rather than CGA_ALU_STS; then the 0x2A2A
     reading is expected scratch content and the real corruption is
     elsewhere.

## 4. The single decisive experiment

One Verilator run of the BYTE-STRING area with a change-triggered log on the
hardware STS register: on every ALUCLK capture where
CGA_ALU_STS.STS_15_0 changes, print {CSA_12_0, CSTS_1_0, LDPILN,
FIDBO_15_0, STS old->new}. The first line where STS picks up 0x2A (either
byte) names the exact corrupting microword and which load path (CSTS vs
LDPILN) fired, immediately selecting between H1/H2/H3 and confirming or
clearing the GATES_49 skew. (Not run here per the static-analysis-only
instruction.)

## 5. File index

- Microcode: /mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah.uc (BFILL lines
  1738-1790; LVSWP lines 1477-1499; IRR lines 645-672; IRW lines 673-703)
- C# ground truth: /mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/Cpu.cs,
  /mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/RegisterFile.cs,
  /mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/BUFALU.cs,
  /mnt/e/Dev/Repos/Ronny/ND110Compile/ND110CPU/Enums.cs,
  /mnt/e/Dev/Repos/Ronny/ND110Compile/ND110Compile/ND120Tokens.cs
- RTL: /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_CPU_ALU_CONTR.v,
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_STS.v,
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_WRF/circuit/CGA_WRF.v,
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_WRF/circuit/CGA_WRF_RBLOCK.v,
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v,
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_DCD/circuit/CGA_DCD.v,
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/CPU-BOARD-3202/circuit/CPU_PROC_32.v

## Framework verify decode (17-JUL)

Static decode of the 30000-macro-instruction golden trace
/tmp/claude-1000/-mnt-e-Dev-Repos-Ronny-nd-120/c2db37d6-ce27-49a9-bdfb-d7d9766f2fc6/scratchpad/bfill_iter2.md
(one full framework cycle: BFILL at trace section #1, BFILL again at #26679).
All addresses/opcodes octal, read directly from the trace; opcode decode per
the ND-100 ISA. Anything not directly observed is labelled INFERRED.

### Headline: NO compare fails in this window. The re-run is by design.

Every readback check the framework performs on the second BFILL passes.
The BFILL sub-test is re-invoked by a counted harness loop (MIN retry
counter, see below), not by a failed verification. MOVB (140131) does not
appear because the counter has not expired inside the captured window.

### 1. The level-0 framework cycle (verified section numbers)

One cycle, closed loop, as executed in the trace:

1. Subtest entry 042246 (called from harness 022226 `JPL I *337`, L=022227):
   - 042246 `146145` COPY SL DA; 042247 `004371` STA *371 (save return addr
     022227); 042250 `045163` LDA I *163 -> 056120; 042251 `172401` AAA 1 ->
     A=056121 (buffer base); 042252 `004367` STA *367; 042253 `146107`
     RCLR DX.
2. CLEAR loop 042254-042261 (2048 iterations, sections #16417-#26659):
   - 042254 `050160` LDT *160 -> T=003777 (limit)
   - 042255 `141076` SKP IF DT GRE SX  (stay while X <= 003777)
   - 042257 `003362` STZ ,X I *362     (zeroes buffer word; this loop is a
     buffer CLEAR, not a verify - STZ, mode 6 indexed-indirect)
   - 042260 `173401` AAX 1; 042261 `124373` JMP *-5 -> 042254
   - exit: no skip at 042255 when X=004000 -> 042256 `124004` JMP *4 -> 042262
3. Level-1 register setup 042262-042274 (#26660-#26673), each via
   `140660` = EXR ST executing an IRW code loaded by LDT I:
   - IRW 153417 (level 1, reg 7=X) <- A=056121   (buffer start)
   - IRW 153416 (level 1, reg 6=T) <- A=007776   (byte count 4094)
   - 042270 `170452` SAA 52; IRW 153415 (level 1, reg 5=A) <- 000052 (fill byte)
   - 042273 LDA *145 -> 042307 (BFILL address); 042274 `135145` JPL I *145
     -> dispatcher 022542, L=042275
4. Dispatcher 022542-022550 (#26674-#26684):
   - 022542 LDT I *7 -> 153412; 022543 EXR ST -> IRW (level 1, reg 2=P)
     <- 042307
   - 022544 `045006` LDA I *6 -> 000002; 022545 `150306` MST PID (sets
     PID bit 1) -> level 1 activates
   - level 1 (#26679-#26680): BFILL 140130 at 042307 completes, SKIP-returns
     to 042311 `151000` WAIT; LVSWP saves level-1 P=042312, X=062120, T=000000,
     A=000052; back to level 0 at 022546
   - 022546 LDT I *5 -> 153612; 022547 EXR ST -> IRR (level 1, reg 2=P)
     -> A=042312; 022550 `146142` COPY SL DP -> return to 042275
5. Readback checks 042275-042306 (#26685-#26695):
   - 042275 `050145` LDT *145 -> T=042311
   - 042276 `142065` SKP IF DA UEQ ST: A=042312 != T=042311 -> SKIP taken
     (F=000001 = A-T in the trace). The skipped instruction at 042277 is
     NEVER executed anywhere in the 30000-instruction window; its opcode is
     therefore unknown from the trace.
   - 042300-042301: IRR 153617 (level 1, reg 7=X) -> A=062120; 042302
     `146157` COPY SA DX
   - 042303-042304: IRR 153616 (level 1, reg 6=T) -> A=000000; 042305
     `146156` COPY SA DT
   - 042306 `124004` JMP *4 -> 042312
6. End-pointer and count checks 042312-042332 (#26696-#26701):
   - 042312 LDA *327 -> 056121; 042313 `060121` ADD *121 -> A=062120
     (expected end pointer = start + 004000 - 1 words... value read from
     memory; A equals the readback X exactly)
   - 042314 `142075` SKP IF DX UEQ SA: X=062120 == A=062120 -> NO skip
     (equal = pass) -> 042315 `124014` JMP *14 -> 042331
   - 042331 `142006` SKP IF (0) UEQ DT: T=000000 -> equal -> NO skip (pass)
     -> 042332 `124015` JMP *15 -> 042347
7. Verify loop setup + loop 042347-042367 (2461 iterations of 042351):
   - 042347 `146107` RCLR DX; 042350 `000272` STZ *272 (zeroes a level-0
     cell, EA approx 042242)
   - 042351 LDT *76 -> 003776; 042352 `141076` SKP IF DT GRE SX (stay while
     X <= 003776); 042354 `047265` LDA ,X I *265 (reads buffer word);
     042355 LDT *73 -> 025052; 042356 `142065` SKP IF DA UEQ ST
     (mismatch would skip to 042360 - NEVER taken: every word reads 025052,
     the correct BFILL fill pattern for fill byte 052);
     042357 JMP *7 -> 042366 `173401` AAX 1; 042367 JMP *-16 -> 042351
   - exit (#16404): 042353 `124015` JMP *15 -> 042370
8. Cycle closure 042370-042427 + harness (#16405-#16410):
   - 042370 `044252` LDA *252 (EA approx 042642) -> A=000000
   - 042371 `131036` JAZ *36: A==0 -> TAKEN -> 042427 (the fall-through at
     042372 is never executed; meaning of the 042642 cell is unknown -
     INFERRED: an error/flag word, 0 = clean)
   - 042427 `125211` JMP I *211 -> harness 022227
   - 022227 `040344` **MIN *344** - increments a level-0 counter cell
     (EA approx 022173): the trace shows the incremented value 177601
     written back (R1=177601 at #16409). Result nonzero -> NO skip ->
     022230 `124376` JMP *-2 -> 022226 `135337` JPL I *337 -> subtest entry
     042246 again. Cycle closed.

### 2. The branch that decides retry vs advance

It is NOT any of the register-readback compares - they all pass. The
decision point is the harness instruction:

    022227: 040344  MIN *344      (counter cell approx 022173)
    022230: 124376  JMP *-2       (executed while counter != 0 -> re-run)
    022231: ???                   (reached only when MIN wraps to 0;
                                   never executed in this window - INFERRED
                                   to be the advance path toward the next
                                   sub-test / MOVB)

Counter value after this cycle's increment: 177601. If the counter simply
counts up by one per cycle, 0177 = 127 more BFILL cycles (~127 x ~26700 =
~3.4M macro instructions) remain before the harness advances. The
secondary guard is 042371 `JAZ *36` on the cell at approx 042642 (currently
0; nonzero would fall through to 042372, contents unknown).

### 3. The suspected off-by-one is DISPROVEN

The suspicion was that the framework expects level-1 P = 042311 after WAIT
and our CPU returns 042312. The trace shows the opposite polarity:

- 042276 `142065` decodes as SKP IF DA UEQ ST (140000 + cond 4 (UEQ) x 400 +
  dest 6 (T) reg-field + src 5 (A) reg-field; condition self-confirmed by
  the trace: it skips exactly when the two values differ, here and at
  042314/042356 where equal values do NOT skip).
- Skip-when-UNEQUAL means readback P != 042311 is the CONTINUE path. The
  constant 042311 is the address of the WAIT itself = where P would point
  only if BFILL had taken its ERROR (non-skip) return through 042310
  (INFERRED: 042310 likely holds a WAIT or the error path re-enters WAIT;
  042310 is never executed so this is not provable from the trace).
- ND-100 semantics (and this RTL's LVSWP microcode, section #26680): WAIT
  saves P pointing at the instruction AFTER the WAIT, so 042312 is the
  CORRECT success value. Our CPU is behaving correctly here.

All three level-1 readbacks match BFILL's defined post-state for
entry A=000052, T=007776, X=056121:
- P = 042312 (skip return past 042310, then WAIT) - pass
- X = 062120 = 056121 + 003777 (end pointer) - matches the framework's own
  recomputation at 042312-042313 - pass
- T = 000000 (count exhausted) - pass
- The 2461-word verify sweep reads 025052 (052 in both bytes) from every
  buffer word - pass, zero mismatch skips.

### 4. Verdict and the experiment that settles it

From this window the CPU executes the BYTE-STRING/BFILL area correctly;
the repetition is the harness's counted re-run (MIN counter at approx
022173, 128-ish repetitions by the current value). Two possibilities for
the observed never-advancing storm:

1. The run simply has not executed the remaining ~127 cycles (~3.4M macro
   instructions) yet - no bug.
2. Something re-initializes the counter cell each cycle, so MIN never
   reaches zero - that would be the bug, and it is NOT visible in a
   single-cycle window.

Deciding experiment: capture the MIN at 022227 across two or more
consecutive cycles (one MIN per ~26700 macro instructions) and compare the
written-back counter value (visible as the R1/WRF write in the MIN row,
e.g. 177601 this cycle). Expected if healthy: 177601 -> 177602 -> ... -> 0
-> skip to 022231. If it does not increment monotonically, find the writer
of cell approx 022173. Note the EA values 022173/042642/042242 assume the
P-relative displacement is taken from the instruction's own address; the
cell identities (not the control flow) carry that one assumption.
