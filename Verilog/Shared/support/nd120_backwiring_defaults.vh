//---------------------------------------------------------------------------
// ND-120 back-wiring PROM (installation number) - build-time default values
//
// Full path: Verilog/Shared/support/nd120_backwiring_defaults.vh
//
// These are the values SINTRAN's GCPUNR reads out of the back-wiring PROM with
// the VERSN instruction (IDB source 35 octal). They are meant to be BAKED INTO
// A BITSTREAM, so every one of them can be overridden on the compiler command
// line - the same `ifndef + `define idiom SC2661_UART.v:139-144 uses for
// BOARD_CLK_FREQ / UART_BAUD_RATE:
//
//   * sim      : make -C runSim compile EXTRA_VDEFINES="-DND120_SYSNO=16'd42"
//   * yosys    : read_verilog -DND120_SYSNO=16'd42 ...
//   * iverilog : -DND120_SYSNO=16'd42
//   * Tang     : add a `define to fpga/tang-nano-20k/src/tang20k_defines.v
//                (compiled FIRST, so it wins over these defaults)
//
// (Note the leading "* " above: a comment whose text STARTS with the word
//  "verilator" is taken as a Verilator metacomment and aborts the build with
//  "Unknown verilator comment" - so the tool name must never lead a line here.)
//
// Or, from Verilog, by overriding the matching parameter on BACKWIRING_PROM /
// ND120_CORE.
//
// "NOT PRESENT" SENTINELS - not every field has to be used. GCPUNR skips a
// field whose PROM value is the documented sentinel, and SINTRAN then keeps
// whatever its own image has:
//   SYSNO   = 16'hFFFF (= -1)   -> no CPU NUMBER in the PROM
//   HWINFO2 = 16'hFFFF (= -1)   -> no CPU TYPE in the PROM
//   NLEGU   =  8'o377  (= 0xFF) -> no legal-user count in the PROM
// A build that sets all three to their sentinel still has a VALID PROM: the
// signature bytes 6/7 (0x55/0xAA) are hardwired in BACKWIRING_PROM.v and are
// deliberately not parameterised, because a wrong signature makes GCPUNR EXIT
// and throws away everything else.
//
// See docs/backwiring-prom-installation-number.md for the full mechanism.
//---------------------------------------------------------------------------

`ifndef ND120_SYSNO
  // CHOSEN DEFAULT, NOT A SOURCED FACT. SYSNO is FUNCTIONAL - COSMOS local vs
  // remote routing keys on it - so it must be UNIQUE per machine on a site.
  // 120 is picked simply because this is the ND-120; override it per build.
  `define ND120_SYSNO 16'd120
`endif

`ifndef ND120_HWINFO2
  // CHOSEN DEFAULT taken from the documented system-type list (100, 102, 500,
  // 502, 5561 - the list is explicitly open-ended, SINTRAN OPPSTART.NPL:3440).
  // 102 is a documented type and is the type of the one live-verified pair we
  // have (SYSNO=102 / HWINFO(2)=9883, NDInsight SINTRAN-STRUCTURES.md:2036-2039).
  // NOTE: the CPU identity proper lives in HWINFO(0), NOT here, and no
  // ND-120-specific system-type value is documented anywhere we found.
  `define ND120_HWINFO2 16'd102
`endif

`ifndef ND120_NLEGU
  // DELIBERATE "ABSENT" DEFAULT. NLEGU is a licence limit (number of legal
  // users); inventing one could silently shrink a working system, so the stock
  // build ships the documented opt-out sentinel 0377B and SINTRAN keeps
  // whatever its image has. Override with a real count to let the PROM decide.
  `define ND120_NLEGU 8'o377
`endif

`ifndef ND120_INR_BYTE5
  // Byte 5 is the low half of the word GCPUNR loads as INF2, but GCPUNR uses
  // only the HIGH byte (INF2 SHZ -10), so this byte has no known consumer.
  // Filler, chosen 0.
  `define ND120_INR_BYTE5 8'h00
`endif

`ifndef ND120_INR_FILLER
  // Bytes 8..15: the contents of a real back-wiring PROM are unknown (no dump
  // exists in these repos) and SINTRAN never reads them. Filler, chosen 0.
  `define ND120_INR_FILLER 8'h00
`endif
