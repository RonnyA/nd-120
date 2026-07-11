# runSim - full CPU simulation with OPCOM console

Runs the complete ND-120: microcode load from the PROM images, CPU
self-test, then the OPCOM (MOPC) console on stdin/stdout for
interactive use. `make help` lists every target and variable.

```
make compile              build (C device models on the external bus)
make run                  compile + run interactively
make run-floppy           boot-from-floppy session (see below)
make clean                required when switching build flags
```

## Booting from the floppy (1560&)

```
make run-floppy
# wait for the '#' prompt, then type:
1560&
```

`run-floppy` builds the VERILOG device configuration (`VERILOG_TAPE=1`:
the Verilog tape-400, DMA floppy at 1560 and SMD at 1540 live inside
ND120_TOP on the real external bus, with their own DMA bus masters)
and starts the simulator with a bootable diskette image served behind
the floppy controller (default: the 210523I01 test-program diskette
from `../ND-BUS-DEVICES/testdata/`, override with `FLOPPY_IMG=path`).

`1560&` runs the microcode mass-storage loader: it is the BPUN loader
pointed at the device - per byte it activates the controller, polls
the status register for ready, and reads the next boot-stream word
from the data register (a diskette stores one stream byte per 16-bit
word). Action word 0 in the BPUN means autostart at the leader's B
address. After the boot THE LOADED PROGRAM OWNS THE CONSOLE - what you
type goes to it, not to OPCOM.

The same works for the SMD: `1540&` with an image behind
`ND120_SMD_IMG`. Note the C device models CANNOT satisfy the `&`
loader (the control word's high byte lands in the PIO command field);
booting requires the Verilog build.

## Device backends (sim side)

With `VERILOG_TAPE=1` the C harness only serves raw storage:

| Env | Device | Default |
|---|---|---|
| (fixed) INSTRUCTION-B.BPUN | tape-400 byte source (`400$`) | - |
| `ND120_FLOPPY_IMG` | floppy 1560 image | `FLOPPY.IMG` |
| `ND120_SMD_IMG` | SMD 1540 disk-0 image | none = drive not ready |

Without the flag, the original C models (papertape + PIO floppy) are
registered instead - the historical runSim behavior.

## System gates (run from Verilog/, not here)

`make test-tape`, `make test-dma-rtl`, `make test-floppy-boot`,
`make test-smd-boot` - each compiles this simulator in a scripted
configuration and checks a hard verdict (console landmarks, RAM
contents, executed-code proof). See the top-level `Verilog/Makefile`
header and `docs/device-bus-todo.md`.

`make test-floppy-stdin` additionally proves the INTERACTIVE input
path: it pipes `1560&` into the exact `make run-floppy` binary
(worst-case: all chars buffered at once) and requires the boot to
load AND execute. The harness paces stdin (one char per 300000 cnt,
`ND120_STDIN_GAP`), holds input until the `#` prompt, and after a
`&` boot holds again until the loaded program has printed a full
line and gone quiet (`ND120_AMP_SETTLE`). Without that pacing MOPC
(no RX FIFO) drops chars and a typed `1560&` arrives mangled - the
old "interactive boot hangs" bug. `ND120_MAX_CNT` bounds a run for
tests.

## Known sim-only limitation: console input to a BOOTED program

After `&` the loaded program owns the console, but in Verilator it
never sees typed input: the program polls the terminal controller
via IOX and the zero-delay sim's IDB read race returns 0 for the
data-available status (the same artifact that blocks the `300$`
serial loader). Proven 11-JUL-2026: the 210523I01 diskette boots,
runs, prints its greeting and completes all its floppy I/O, the
harness delivers `help` cleanly afterwards, and the program never
receives a char. On FPGA hardware this path works. Interactive
validation of booted programs is therefore a HARDWARE test until
the IDB read race is modeled/fixed.
