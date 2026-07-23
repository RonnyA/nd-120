# Instruction-verify campaign status (13-JUL-2026)

Two verification layers per INSTRUCTION-B area:
- **Deep verdict**: run the area to its own `== END OF TEST ==` and count
  error lines (the area's full case sweep, tens of thousands of
  instructions; catches what the golden window cannot).
- **Golden gate**: `run_area_test.sh <AREA>` - first 400 instructions
  trace-compared against the ND-110 reference, mechanical comparator.

FF-mode build (`USE_LATCHES=0`). Deep logs: session scratchpad
`verdict2_*/verdict3_*` (verdict3 = after the SSEL shift fix, commit 2e2ea37).

| Area | Deep END-OF-TEST | Golden 400 gate |
|---|---|---|
| ARGUMENT | PASS, 0 err | PASS |
| MEMORY-REFERENCE | PASS, 0 err (post MPY fix dc61bd6) | PASS |
| REGISTER-OPERATIONS | PASS, 0 err | PASS |
| SHIFT-INSTRUCTIONS | PASS, 0 err (post SSEL fix 2e2ea37; was 3988) | PASS |
| BIT-OPERATIONS | PASS, 0 err | PASS (12-JUL batch) |
| SEQUENCE | PASS, 0 err | PASS (12-JUL batch) |
| STACK | PASS, 0 err | PASS (12-JUL batch) |
| BYTE-STRING | PASS, 0 err | PASS (12-JUL batch) |
| BCD | PASS, 0 err | PASS |
| ND100-24BIT | PASS, 0 err | PASS |
| ND100-CX | PASS, 0 err | PASS |
| PRIVILEGED | PASS, 0 err | PASS |
| 32-BITS-FLOATING | PASS, 0 err | PASS |
| 48-BITS-FLOATING | **N/A** - machine is 32-bit-float configured (see docs/48bit-float-not-configured.md) | n/a |
| RUN | deferred - needs level-12/14 stress-interrupt device models in runSim | pending |

Bugs found and fixed by the campaign:
1. `CGA_ALU_QREG` MUXQ15.D3 - multiply product/overflow
   (docs/MPY-dynamic-overflow-rootcause.md, commit dc61bd6).
2. `CGA_CPU_ALU_CONTR` MEMORY_46/47 - shift-type capture
   (docs/SHIFT-serial-input-rootcause.md, commit 2e2ea37).

Both have Logisim-drawing regeneration hazards tracked in TODO.md.
CPU self-test: 0 execution-phase STERR visits.
