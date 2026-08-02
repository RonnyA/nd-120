# Serial binary loader (300$) - status and findings

10-JUL-2026. Goal: load BPUN programs fast by typing `300$` at the OPCOM
prompt and streaming the raw BPUN file bytes into the console UART - the
BPUN format IS the microcode loader's wire format, no conversion needed.
Reference: RetroTerm docs ND110-OPCOM-MICROCODE-REFERENCE.md (sections on
ETLO1, the 300$ transfer sequence, and the C appendix).

## What works

- The ND-120 microcode (DELILAH-L) HAS the full loader: ETLO1, SEEK/SIKI
  (ASCII preamble), EXFOU ('!' -> binary), BIN, STLP, INCH, DVACT, and
  the on-CPU-board console dispatch IOXG -> IOXX1 -> TERMX -> TRMVC with
  handlers TRM0 (IOX 300 data), TRM2 (IOX 302 status), TRM3 (IOX 303
  control). Confirmed in nd120uc source + L listing.
- `$` is dispatched (DOLOA/ETLOA -> LOAD1 -> ETLO1); the CPU enters the
  loader and its INCH polling loop. Confirmed by CSA trace in simulation.
- Host-side transfer tool: fpga/tools/ndcomm (-b mode) types 300$ and
  streams the file with settle delay + pad; estimated ~49 s for the full
  23001-word INSTRUCTION-B at 9600 baud (vs ~45 min via deposits).
- Feed-rate analysis: the 9600 line cannot be overfed from the host (the
  kernel blocks); once INCH polls, the microcode consumes bytes ~50x
  faster than the line delivers them, so no pacing or flow control is
  needed mid-transfer; too slow is safe (INCH polls forever). The only
  loss window is between typing '$' and ETLO1 polling (MOPC dispatch is
  RTC-tick paced and the SC2661 buffers ONE char) - covered by the
  tool's settle delay (-w ms, default 400) and leading pad spaces.

## The blocker: JMP0-3 vector dispatch lands on entry 0

Reproduced in Verilator (runSim, -DSCRIPT_CMD_BINLOAD + the
ND120_BINLOAD_FILE env harness in Run120.cpp) and identical on hardware.

CSA trace signature of the hang (repeats forever):

    2310 2311 2312 2313   INCH: compute IOX N+2, test DA bit, loop
    477 500 501 502 503   IOXG / IOXX1: 16-bit IOX, detect device 30x
    504 511               ... TERMX
    3720                  TRMVC vector base
    515 516 517           TRM0 (IOX **300** handler - WRONG, expected
                          TRM2 at 3722 for IOX 302)

INCH polls IOX 302 (console input status), but the TERMX 4-way dispatch
(`T,JMP0-3 TRMVC` - "jump; IR0-3 drive low address bits", see nd120uc
ND120-microcode-bitfields.md) always lands on TRMVC+0. The status
handler TRM2 never runs, the DA bit is never reported, INCH spins.
Meanwhile the SC2661 shows rxEnabled=1, RxRDY=1 and an overrun - the
data is there; the microcode just cannot see it.

Checked and exonerated:

- SC2661 8-bit RX path (RHR is full 8 bits, no 7-bit strip in hardware).
- The P3 LDIRV strobe conversion (rebuilt with LDIRV_CE=0: identical
  failure), so this is NOT a clock-enable regression.
- The IOC register (holds 0x28 throughout - but the handover comes via
  TRM3, which is never reached).

Conclusion: the CGA_MIC next-address logic does not implement (or gets
zero from) the JMP0-3 OR-dispatch of IR bits 0-3 into the low CS address
bits **in the MOPC/IOXG context**. Macro-instruction execution dispatch
works (real programs run - the RTC test passes on silicon), so the bug
is specific to how IR0-3 reach the sequencer on this path - possibly the
IR is loaded differently (or not at all) when the microcode itself
issues the IOX, or the OR path is masked.

This path was NEVER exercised before (no test, no OS): pre-existing bug,
first surfaced by the 300$ experiment.

## Repro (fast, simulation)

    cd Verilog/runSim
    make compile USE_LATCHES=0 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_BINLOAD -DTRACE_CSA"
    ND120_BINLOAD_FILE=<raw bpun stream> ND120_BINLOAD_CHECK=1000:5 ./obj_dir/VND120_TOP </dev/null
    # csa_trace.csv tail shows the 2310..3720,515-517 loop
    # RAM check prints the target words - unchanged = loader never wrote

The test stream used: 8 pad spaces + a 5-word tiny BPUN at 1000 with the
action field replaced by "1\r" (no autostart).
ND120_BINLOAD_SETTLE / ND120_BINLOAD_GAP (cnt units) tune the timing.

## Next steps

1. Find the JMP0-3 implementation in CGA_MIC (next-CSA formation) and
   how IR0-3 are sourced during microcode-initiated IOX; compare with
   the CGA design docs. Fix, then the sim repro above must load the
   tiny BPUN (RAM check = 123456 000001 177777 054321 000000) and
   return to '#'.
2. Re-run the full gauntlet (this touches the CPU core sequencer:
   traces must stay golden - the dispatch is supposedly inert in all
   currently-golden flows, so byte-identity should hold).
3. Then ndcomm -b -n -v on hardware, then INSTRUCTION-B with -b -g.
4. Note for the SD/tape-device plan (docs/sd-bpun-device-plan.md): the
   device-400 boot path uses general bus IOX, not TRMVC - but IOX-based
   device I/O in general should get a regression test once this works.

## LDIRV decode - documentation cross-check (agent research)

Question: which microinstruction COMMAND (COMM, microword bits 36-32) and
MIS (bits 43-42) combinations assert LDIRV ("Load instruction register
(MIC)") according to the original Norsk Data documentation, and does the
RTL decode in
Verilog/DELILAH-CPU/CGA_DCD/circuit/CGA_DCD.v
(gates GATES_79 / GATES_3 / GATES_8 / GATES_9, lines 754-819) match it.

### 1. Documentation entries

Source: NorskData-Doc/ND-06.031.1 EN ND-110
and ND-120 Microprogrammer's Guide-Gandalf-OCR.pdf

- Chapter 3 command-decode list (PDF page 31, printed page 24-25), exact
  quote (OCR-cleaned):
      "20,0  LDSEG  Load segment register. ...
       20,1  -      Spare.
       20,2  -      Spare.
       20,3  LDIRV  Load instruction register (MIC)."
  This is the ONLY command the guide labels LDIRV by name.
- The same 20,3 LDIRV entry appears in BOTH microword format charts:
  Figure 3 "ND-110 microinstruction word format functions chart"
  (PDF page 24) and Figure 4 "ND-120 microinstruction word format
  functions chart" (PDF page 25). The ND-110 -> ND-120 change list
  (PDF ~page 15: "command decodes 5, 36.2 and 36.3 changed") does NOT
  touch the 20-27 range, so the LDIRV-relevant decodes are identical on
  ND-110 and ND-120.
- The surrounding command list (PDF pages 31-33) defines the rest of the
  COMM 22-27 range: 22,0 IREAD,PT; 22,1 IREAD,APT; 22,2 MAP ("Address
  control store mapped as when FETCH. Used in Execute Register", i.e.
  EXR - uses IDB as instruction); 22,3 CNEXT,NWP; 23,0-3 CJMP,F15 /
  NF15 / F=0 / NF=0; 24,0-3 CNEXT,SGR / NSGR / CRY / NCRY; 25,0-3
  CNEXT,F15 / NF15 / F=0 / NF=0; 26,0-3 JMP,* / B / I / X; 27,0
  JMP,XB; 27,1 JMP,XI(,B); 27,2 spare; 27,3 CONTINUE ("Fetch relative
  to P").
- NorskData-Doc/ND-06026-1-EN ND-110
  Functional Description-ocr.pdf: no LDIRV occurrence at all (checked by
  full-text extraction).

### 2. (COMM,MIS) enumeration: RTL p1-p4 vs documentation

RTL product terms (comm active-high indices 4..0, lcs_n high, output
suppressed while MCLK is high):
    p1 = comm4 & ~comm3 & ~comm0 & mis1 & mis0    (COMM 20/22/24/26, MIS=3)
    p2 = comm4 & ~comm3 & comm1  & mis1           (COMM 22/23/26/27, MIS=2,3)
    p3 = comm4 & ~comm3 & comm1  & comm0          (COMM 23/27, any MIS)
    p4 = comm4 & ~comm3 & comm2                   (COMM 24-27, any MIS)

Brute-force union of p1-p4 = exactly 23 (COMM octal, MIS) pairs:

    COMM,MIS  mnemonic (ND-120)  fires via   loads IR because
    --------  -----------------  ---------   -------------------------------
    20,3      LDIRV              p1          explicit "Load instruction
                                             register (MIC)" - the only
                                             decode the docs NAME LDIRV
    22,2      MAP                p2          "use IDB as instruction (as in
                                             EXR)" - IR loaded from IDB
    22,3      CNEXT,NWP          p1,p2       conditional next instruction
    23,0-23,3 CJMP,F15/NF15/     p2,p3       conditional macro jump ->
              F=0/NF=0                       fetch of next instruction
    24,0-24,3 CNEXT,SGR/NSGR/    p1,p4       conditional next (skip family)
              CRY/NCRY
    25,0-25,3 CNEXT,F15/NF15/    p4          conditional next (skip family)
              F=0/NF=0
    26,0-26,3 JMP,*/B/I/X        p1,p2,p4    macro jump -> fetch
    27,0      JMP,XB             p2,p3,p4    macro jump, post-indexed
    27,1      JMP,XI(,B)         p2,p3,p4    macro jump, post-indexed
    27,2      (spare)            p3,p4       don't-care (unused decode)
    27,3      CONTINUE           p1,p2,p3,p4 "Fetch new instruction relative
                                             to P" - the normal fetch

Excluded, and correctly so: 20,0 LDSEG, 20,1/20,2 spare, 21,x
(WCIHM/SSEMA/CCLR/LDEXM), 22,0/22,1 (IREAD,PT/APT - indirect DATA reads,
must NOT load IR), and everything with COMM3=1 (30-37: AREAD/AWRITE/
READ/WRITE/RWCS/IOX etc. - data accesses).

Reading of the decode: the DCD does not implement a lone "LDIRV command";
it implements "IR must capture the incoming word" for the ENTIRE
fetch/map/jump/continue command family, plus the explicit 20,3 override.
The guide documents this behavior functionally (every one of those
commands is described as fetching or substituting the next
macroinstruction) but only the 20,3 row carries the signal name. There
is NO mismatch: every doc-documented "fetches/maps an instruction"
command is inside the p1-p4 union, and no data-access command is.
Note that for the conditional commands (CJMP/CNEXT) the DCD asserts
LDIRV regardless of the condition value - condition evaluation gates the
sequencing elsewhere (MIC), not this combinational decode.

Uncertainty note: the guide PDF is OCR'd; the 20,3 row was cross-checked
in three places (Figure 3, Figure 4, Chapter 3 list) and against two
independent machine-readable sources below, so it is considered VERIFIED.
The Figure 4 chart text is heavily OCR-garbled ("snare LDIRV") but the
row position matches Figure 3 and the Chapter 3 list.

### 3. Mnemonic encodings and usage in the microcode source

Encodings confirmed by /mnt/e/Dev/Ronny/nd120uc/scripts/nd120_tokens.json
(w3 field = MIS in bits 43-42 + COMM in bits 36-32, octal):
COMM,LDIRV w3=006020 (=20,3, description "LOAD INSTRUCTION REGISTER FOR
OR-LOGIC USE"); COMM,MAP 004022 (=22,2); COMM,CNEXT,NWP 006022;
COMM,CJMP,F15..NF=0 000023..006023; COMM,CNEXT,SGR..NCRY 000024..006024;
COMM,CNEXT,F15..NF=0 000025..006025; COMM,JMP,*..X 000026..006026;
COMM,JMP,XB 000027; COMM,JMP,XI 002027; COMM,CONTINUE 006027 (=27,3,
"FETCH NEW INSTRUCTION RELATIVE TO P"). So COMM,CONTINUE = COMM 27
octal, MIS 3 - the empirical observation is the documented encoding.

Usage counts in /mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah-K.uc:
COMM,CONTINUE 94; COMM,CNEXT,NWP 24; COMM,CJMP,F15 12; COMM,LDIRV 10;
COMM,JMP,* 8; COMM,JMP,B 8; COMM,JMP,X 8; COMM,CJMP,NF15 8;
COMM,CJMP,F=0 8; COMM,CJMP,NF=0 4; COMM,CNEXT,F=0 3; COMM,MAP 2;
COMM,CNEXT,NF=0 2; COMM,JMP,I 1; COMM,JMP,XB 1; COMM,JMP,XI 1; and one
each of CNEXT,SGR/NSGR/CRY/NCRY/F15/NF15. The canonical fetch is the
CONT label (nd-120-delilah-K.uc line 440):
    CONT:   B,Z  ALUF,ZERO  ALUD,B
            IDBS,ALU  COMM,CONTINUE  T,JMP  T,HOLD;
which is the microword observed empirically at CS address 000145 firing
LDIRV with COMM=27, MIS=3.

The C# ND-110 emulator
($ND_REPOS/ND110Compile/ND110CPU/Enums.cs, around line 141)
carries the same table: "20,3: LDIRV", MIS=2 of 22 = COMM,MAP, and the
CJMP/CNEXT_24/CNEXT_25/JMP_26/JMP_27 groups - consistent (ND-110, but
this range is identical on ND-120).

### 4. Conclusion

The RTL decode matches the documentation. The docs name LDIRV only at
COMM=20,MIS=3, but the CGA schematic (and our gate-for-gate RTL) ORs
that explicit decode with every command whose documented function
requires loading IR with a fetched/substituted macroinstruction: MAP
(22,2), CNEXT,NWP (22,3), the CJMP family (23,x), both CNEXT families
(24,x, 25,x), the JMP family (26,x, 27,0-1) and CONTINUE (27,3); spare
27,2 rides along as a don't-care. COMM,CONTINUE is indeed encoded as
COMM=27 octal with MIS=3 and is SUPPOSED to load IR - it is the normal
end-of-instruction fetch ("Fetch new instruction relative to P"), used
94 times in the K microcode, including the CONT microword at CS 000145.

## FINAL VERDICT (11-JUL-2026) - hunt closed, bug not ours to fix

Sheet-verified conclusion after full instrumentation and schematic
cross-check with the owner:

1. Our RTL is a FAITHFUL transcription of the CGA as drawn. Verified
   pin-for-pin against DELILAH.pdf: the four LDIRV product terms
   (DCD sheet 4/10: G1=COMM0N.COMM3N.COMM4.MIS0.MIS1.LCSN,
   ND5a=COMM1.COMM3N.COMM4.MIS1.LCSN, ND5b=COMM0.COMM1.COMM3N.COMM4.LCSN,
   ND4=COMM2.COMM3N.COMM4.LCSN = GATES_79/3/8/9), no fifth term, final
   NOR = {decode, MCLK} (GATES_6/10); MIC sheet 2: IRLATCH gate = bare
   LDIRV, data = CD0-CD6; the MUX34P vector legs and selects.
2. Measured in sim (window probes +-2 clocks): selects arrive exactly on
   the dispatch tick; LAA pipelining is by design; BMG=2, R1=302,
   MASKDA=A&~D all correct; IR=0 because nothing in the ETLO1/INCH flow
   fires LDIRV (LDIRV = the fetch/jump/continue COMM family, agent-
   verified against the Microprogrammer's Guide decode table).
3. Therefore the DRAWN hardware dispatches microcode-issued IOX-30x on
   stale IR - a real ND-120 per these sheets would fail 300$ exactly as
   ours does. The console-300 binary load is historically inconclusive
   (the ND110-OPCOM reference is an analysis, not silicon-verified);
   possibly it never worked on ND-120, or an ECO beyond these drawings
   changed it.
4. Experiments (kept behind +define+ND120_EXP_LDIRV_PUSH, OFF by
   default, normal builds untouched): loading IR from the internal IDB
   on T,PUSH calls fixes the poll vector (measured IR=02 -> CS 3722/TRM2,
   first correct dispatch ever) but not DVACT (tail-call, no push);
   loading on every IDBS,ALU word fixes all vectors but clobbers IR in
   macro/MOPC flows and deranges boot. No faithful-to-the-drawings rule
   exists because the drawings themselves lack the mechanism.

DECISION (owner, 11-JUL-2026): STOP hunting. 300$ is parked as
"mechanism proven, hardware-as-drawn cannot do it, disabled". BPUN
loading paths: ndcomm deposit mode (proven on silicon), and the
device-400 SD tape reader (docs/sd-bpun-device-plan.md) which uses the
general bus IOX path and needs no vector. All probes remain available:
Run120.cpp harness (-DND120_PROBE_MIC + --public-flat-rw build),
+define+ND120_EXP_LDIRV_PUSH for the vector experiments.
