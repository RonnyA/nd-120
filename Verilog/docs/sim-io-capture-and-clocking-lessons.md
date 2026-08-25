# Lessons from the 300$ / JMP0-3 hunt - I/O capture, clocking, microcode hygiene

11-JUL-2026. Written after the JMP0-3 vector dispatch fix was proven and the
remaining simulation blocker was identified. The dispatch story itself lives in
docs/serial-binload-300.md; this file collects the findings that generalize to
OTHER code - especially the device-400 bus work and the self-test gate.

## 1. Strobed I/O reads are a broken CLASS in Verilator - and device-400 will use them

> **RESOLVED 12-JUL-2026: not reproducible anymore.** A per-clock probe
> (ND120_PROBE_IOR in runSim/Run120.cpp, --public-flat-rw build) shows the
> boot BAUDS IDBS,IOR read, the TRM2 UART status read and the UART data read
> all delivering real values, and INSTRUCTION-B (400$ boot) answers a typed
> `help` end-to-end. The measurements below predate the UART sysclk-edge fix
> (2026-07-06) and the P2 clock-enable conversions; the TPE "delivered but
> unanswered" case was actually the ND_FLOPPY_DMA status-writeback bug
> (NEVER-READY-ANALYSIS.md). Section kept for the mechanism description;
> treat its "proven broken" claims as historical. The 300$ path was never
> re-validated (abandoned).

The binary loader stalled because every read the CPU makes from an I/O register
over the bus with a read strobe returns ZERO in the zero-delay simulation:

- the UART status register (IDBS,UART + COMM,UART,STATUS),
- the UART data register (IDBS,UART + COMM,UART,DATA),
- the composite IOR word (IDBS,IOR: data-available flag, console flag, baud
  switch - CHIP_33G in CPU-BOARD-3202/circuit/IO_UART_42.v).

The value is genuinely present in the device model (the UART held the received
character with its ready flag set, plus an overrun flag). It is lost in the
LAST HOP: the CPU-side capture samples the bus at the same zero-delay instant
the output-enable strobe changes, so it captures the pre-strobe value (zero).
This is the same class as the already-documented baud-switch-reads-zero
divergence. The FPGA does not have this problem - real propagation delays mean
the strobe settles before the capture - which is why the same RTL reads real
values on hardware.

Why nobody noticed for a year: OPCOM console input does NOT use this path.
Typed characters reach MOPC through the panel interface registers
(IO_PANCAL_40, the MIPANS readout - the panel processor's territory on the
real machine). The TRMVC terminal handlers used by the binary loader are the
only microcode that reads the UART/IOR registers directly, and that path had
never been exercised before 300$.

**Consequence for the device-400 plan (docs/device-bus-todo.md).** To be
precise about scope: device 300 never reaches the bus - the microcode
intercepts IOX 30x on the CPU board and reads the ON-BOARD UART/IOR registers,
and it is that on-board strobed capture that is proven broken in sim. Device
400 takes the OTHER path: a real bus transaction (COMM,IOX at o000507), the
answer lands in the DBR (the data-bus register inside the CPU), and the
microcode reads the DBR afterward (o000510). DBR-style capture is not proven
broken - memory examine/deposit reads work in sim today. The warning is that
the bus-interface port will introduce NEW capture points of the same hazard
class (bus data into the DBR under the bus handshake, the IDENT sequence),
where a race would present identically: device has the data, CPU reads zero
and polls forever. Add a cheap directed test early (CPU IOX-reads a known
device register value through the bus) so that class is ruled in or out on
day one instead of surfacing mid-integration.

Fix directions, in increasing order of effort:
- Per-path: capture with edge-detect on the strobe instead of level sampling -
  the same cure as the AM29C821 USE_SYSCLK=2 mode that fixed the memory-write
  regression (see Verilog/docs and the 9b005c2 postmortem). The write direction
  was fixed this way; the READ direction has the same disease.
- Model-side: make device models answer reads combinationally (see section 2).
- Systemic: model real propagation delays (the designer's note about zero-delay
  Verilog vs real ASIC+TTL timing). Big project, catalogued, not urgent.

## 2. The SC2661 model answers reads one clock late (the real chip does not)

Shared/support/SC2661_UART.v registers its read response: regDataOut updates on
the UART's clock edge AFTER chip-enable + read go active, and the pins show
regDataOut during the strobe (lines ~340 and ~212). The real SCN2661 drives
data combinationally within its access time once CE/read are asserted. The
registered response adds artificial latency on top of the section-1 race and
makes the model harder to read correctly in sim regardless of the capture fix.
If the sim-side read path is ever fixed, make the read response combinational
(the microcode even grants extra time: the status read at TRMVC runs under
COMM,XSLOW, a 425 ns cycle on the real machine).

For the record, the model's flag semantics were AUDITED AND ARE CORRECT:
reading the data register clears the data-available flag; reading the status
register does not touch it. That was not the bug.

## 3. The microcode PROM copies have drifted - one is corrupt in the boot region

There are several copies of the control-store PROM hex files (Verilog/runSim/,
Verilog/sim/, Verilog/CPU-BOARD-3202/circuit/) plus derived wcs_image.hex
files. Cross-checking runSim's copies against the EPROM ground truth
(/mnt/e/Dev/Ronny/nd120uc/source/nd120-microcode.txt) found real damage, all in
AM27256_45133L.hex (the high byte PROM):

| address | damage | region |
|---------|--------|--------|
| o002002 | bits 14:13 of the argument field flipped | master-clear / init |
| o002003 | bit 23 (ECOND - the CONDENABL bit) MISSING | master-clear / init |

CORRECTION (12-JUL-2026, from the designer): the o2002/o2003 divergence is
INTENTIONAL - it skips the 0.5-1 second hard wait loop at the start of boot.
It is NOT corruption and NOT a self-test suspect. Do not restore those words
from EPROM truth. (wcs_image.hex in runSim carries the o2003 edit and not the
o2002 one - the copies still disagree with each other, which the integrity
check below should whitelist explicitly rather than ignore.)

Action items:
- Add a microcode integrity check to `make test`: parse each PROM hex copy,
  rebuild the 8192 words, compare against nd120uc's EPROM listing, fail loudly
  on any mismatch (whitelist deliberate patches). Copies that can drift
  silently WILL drift silently - this one sat in the boot path.

## 4. Clocking and pipeline confirmations (good news for the clock-enable work)

- **The FF-mode MIC pipeline is cycle-accurate through heavy stress.** The
  dispatch test exercised 412,987 vectored jumps in FF mode (USE_LATCHES=0)
  through the microcode sequencer's full pipeline - operand-address register
  lagging one MCLK by design, condition set/enable pairs spanning words, jump
  target assembly - with zero mislandings. The P2-converted MIC clock domain
  holds up under real workload, not just boot.
- **Delay slots appear in CSA traces.** After a TAKEN conditional jump, the
  next sequential word shows up in the trace before the jump target (measured
  at o503 -> o504 -> o511, and o2312 -> o2313 -> o2310). Trace tooling and
  golden compares must not count a delay-slot visit as "the flow went there";
  visit counts of a delay-slot address roughly equal the loop count of the
  jump above it. (Whether the slot's side effects also execute was not
  established - treat that as unknown until measured.)
- **Strobe-class signals: prefer architectural fixes over new RTL clocking.**
  LDIRV (the microcode instruction-register load strobe) is decoded from the
  microword and gated to the MCLK-low half-cycle - exactly the signal class
  the latch->FF refactor keeps tripping over. The 300$ fix deliberately added
  NO new RTL: one word of microcode (COMM,LDIRV at o500) made the existing,
  already-converted strobe fire where it was needed. When a fix can live in
  microcode or configuration instead of a new clock-domain crossing, take it.

## 5. Toolchain recipe: microcode source -> PROM hex (now proven end to end)

Full pipeline used for the o500 patch, reusable for any future microcode work:

1. Edit the .uc source ($ND_REPOS/ND110Compile/ND110Compile/uCode/,
   version-L files; CRLF line endings - patch with line-targeted sed).
2. Build the assembler in WSL: `dotnet build -c Release` in
   $ND_REPOS/ND110Compile/ND110Compile/, then run with
   `DOTNET_ROLL_FORWARD=LatestMajor dotnet ./bin/Release/net8.0/ND110Compile.dll`
   (WSL has .NET 9; the project targets 8). Program.cs selects input files by
   File.Exists - WSL-path entries run only under Linux, E:\ entries only on
   Windows, which keeps the two environments from double-compiling.
3. Extract compiled words from the .DETAILS.TXT output: lines matching
   `uC: <octal-addr> : 0x<16 hex digits> =>`. Diff against EPROM truth before
   trusting anything.
4. PROM byte mapping (verified in Code/Microcode/gen_wcs_image.py): byte index
   = address*4 + chunk, chunk 0..3 = word bits 15:0 .. 63:48; 45132L holds the
   low byte of each 16-bit chunk, 45133L the high byte.
5. The sim loads runSim's copies via $readmemh in
   CPU-BOARD-3202/circuit/CPU_CS_PROM_19.v. Back up before patching
   (*.orig-unpatched convention).

Also proven: the assembler's token values are bit-exact ND semantics - e.g.
COMM,LDIRV = 0x00000C1000200000 including the delay bit, matching all ten
EPROM occurrences. When in doubt about a microword field, trust the token
table (nd120uc scripts/nd120_tokens.json) and verify against the EPROM.

## 6. Console harness note

Run120.cpp's console injector sends OPCOM characters in a 7-bit frame
(matching the 7-data-bit, even-parity, 2-stop mode the boot microcode programs
into the UART at o002010). Binary streams need all 8 bits, so the injector now
switches to 8-data-1-stop when an ND120_BINLOAD_FILE stream opens (tx8n1 in
Run120.cpp). The SC2661 model samples a fixed 8 data bits regardless of its
mode register, so this pairing works in sim and on our FPGA implementation.
How the REAL machine carried 8-bit binary over a console programmed 7E2 is an
open historical question (candidates: the panel processor, or terminal-control
reprogramming we have not traced) - only relevant if 300$ is ever attempted
against a real SC2661.
