# SINTRAN III boots on the Nexys 4 DDR (25-AUG-2026)

First SINTRAN boot ever on this board, validated the same evening with an
interactive console login.

## Measured result

- 5 of 5 boot cycles (each = full JTAG reprogram, then `20500&` at the OPCOM
  prompt) reach the SINTRAN III banner, "SINTRAN IS RUNNING", and
  "ERS/SINTRAN III Watchdog has started".
- Banner arrives 36-48 s after `20500&`. For comparison the Tang Nano 20K
  measures 29.4 s cold - but the two figures come from different sessions
  with different card cache states, so the gap is indicative only.
- Interactive login at the console works (human-verified, 25-AUG ~20:30).
- Build: `build.tcl -tclargs clk 16 ilaslim` - CPU clock 16.667 MHz,
  WNS +1.460 ns (timing met), DDR2-backed main RAM with BRAM cache.
- Console: 9600 baud, 7 data bits, even parity. A logger reading the port
  as 8N1 shows the parity bit as a set bit 7 on odd-parity characters -
  that is rendering, not corruption.
- Boot logs: `boardtest-results/ddr2_sintran_15min.log` and
  `boardtest-results/ddr2_sintran_hitq_run2.log` .. `run5.log`.

## The bug that blocked it (stale cached word)

`ddr2/MEM_RAM_49_DDR2.v` computed the cache-update qualifier as
`wire whit = wr_edge & hit;` where `hit` compares the LIVE tag-RAM output
against the latched access tag. The tag RAM re-reads every clock from the
live AA bus. When the DDR2 write strobe (`wr_edge`) lands late - stretched
cycles, refresh interleave - AA has already drifted to another line, the tag
compare falsely reads "miss", and the cache update is DROPPED while DDR2
takes the write. Write-through has no dirty state, so the cache then serves
one stale word forever. Refresh alignment varies per boot, which made the
corrupt-word target nondeterministic: quiet spin hangs, ERRFATAL with
varying L registers, or a silent WAIT, all from the same bitstream.

The decisive silicon evidence (ILA at the memory funnel): the machine spun
at PIL 11 on virtual 056061-63 (phys word 01024063) executing 124376 where
the oracle and the disc both hold 006377; every spin read was a cache hit;
a full-boot trigger on "write 124376 to that word" NEVER fired; and with a
write-data probe added, the CORRECT value 006377 was seen being written.
Correct value written, wrong value served: the dropped cache update.

## The fix

One flop: latch the hit verdict when the address is checked, and use the
latched copy for a late write strobe.

```verilog
reg hit_q;                      // latched at A_CHK
wire whit = wr_edge & ((astate == A_CHK) ? hit : hit_q);
```

## Teeth

Test 6 "late-CAS write with AA drift" in
`../../../CPU-BOARD-3202/circuit/sim/MEM_RAM_49_DDR2_tb.v`
(run via `make test-ddr2ram` in that sim directory) reproduces the exact
sequence: cached word, late CAS, AA drifted off the column. The pre-fix
RTL FAILS it (reads back the stale value); the fixed RTL passes
(4048 accesses, 0 errors). `make test-memchain-ddr2` also passes.

Address-split reminder for anyone extending the tb: word address bits
[19:10] are the ROW - word 0500020 (octal) has row 0240, column 020.

## Still open on this board

- Long soak under SINTRAN (hours, file activity) is unmeasured; the 5
  cycles prove the boot path only.
- `nd_ddr2_arb.v`: no watchdog, strict-A starvation, silent response drop
  in G_IDLE - dormant defects, not implicated in the boot bug.
- SD runs a 1-bit bus (Tang runs 4-bit); the likely lever if boot speed
  ever matters here.
