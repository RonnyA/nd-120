/****************************************************************************
** BusDriver16 - exhaustive functional testbench                           **
**                                                                         **
** BusDriver16 (DELILAH-CPU/CGA/circuit/BusDriver16.v) is the CGA's FIDBO  **
** bus driver: it drives the internal FIDBO bus out to the external XFIDB  **
** bus, and passes the external bus back in as XFIDBI. It sits directly on **
** the loop that made Vivado report a 181-level path (see the note in      **
** Shared/support/TTL_74245.v), so its behaviour needs to be pinned down    **
** before anyone refactors around it.                                       **
**                                                                         **
** THE CONTRACT THIS LOCKS IN (read out of the RTL as it stands, then       **
** confirmed against the module on 20-AUG-2026 - it is a RECORD of current **
** behaviour, not an independent claim about what the schematic wants):    **
**                                                                         **
**   IO_15_0_OUT = (TN && !EN) ? A_15_0_IN : 16'b0                          **
**   A_15_0_OUT  = IO_15_0_IN                (UNCONDITIONAL)                **
**                                                                         **
**   EN  0 = drive A out to IO,  1 = receive IO into A                      **
**   TN  test enable, active HIGH here: TN=0 forces IO_15_0_OUT to zero     **
**                                                                         **
** THREE THINGS THIS TESTBENCH DELIBERATELY PINS, EACH FLAGGED BECAUSE THEY**
** ARE THE ONES A REFACTOR IS LIKELY TO "TIDY" AND BREAK:                   **
**                                                                         **
**   1. A_15_0_OUT IGNORES EN. The receive side is live even while the      **
**      driver is driving outward. On the real bidirectional bus that is    **
**      read-back of what you are driving, which is why the RTL comment     **
**      says "A is always read from IO". Gating it with EN would break the  **
**      loop reported by synthesis - but it is a FUNCTIONAL CHANGE, not a   **
**      cleanup, and test A_OUT_IGNORES_EN exists to make that loud.        **
**   2. A_15_0_OUT IGNORES TN. Test mode isolates only the outward driver.  **
**   3. Zero, not z, when disabled. Repo rule: inside the FPGA a disabled   **
**      "tri-state" drives 0 (the buses are OR-ed), never z.                **
**                                                                         **
** Coverage: all 4 EN/TN combinations x (walking ones, walking zeros, all   **
** the corner patterns, and 500 pseudo-random vectors), every result        **
** checked against a reference model. Prints TB_RESULT: PASS or FAIL.       **
**                                                                         **
** Run: cd Verilog/DELILAH-CPU/CGA/sim && make test-busdriver16             **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module BusDriver16_full_tb;

  reg         EN, TN;
  reg  [15:0] A_IN, IO_IN;
  wire [15:0] A_OUT, IO_OUT;

  integer errors = 0;
  integer checks = 0;

  BusDriver16 DUT (
      .EN        (EN),
      .TN        (TN),
      .A_15_0_IN (A_IN),
      .A_15_0_OUT(A_OUT),
      .IO_15_0_IN(IO_IN),
      .IO_15_0_OUT(IO_OUT)
  );

  // ---- reference model -------------------------------------------------
  function [15:0] ref_io_out;
    input        en, tn;
    input [15:0] a_in;
    begin
      ref_io_out = (tn && !en) ? a_in : 16'h0000;
    end
  endfunction

  function [15:0] ref_a_out;
    input        en, tn;
    input [15:0] io_in;
    begin
      ref_a_out = io_in;  // unconditional - see header note 1 and 2
    end
  endfunction

  task check;
    input [255:0] name;
    reg [15:0] exp_io, exp_a;
    begin
      #1;  // settle combinational logic
      exp_io = ref_io_out(EN, TN, A_IN);
      exp_a  = ref_a_out(EN, TN, IO_IN);
      checks = checks + 1;
      if (IO_OUT !== exp_io) begin
        errors = errors + 1;
        $display("FAIL %0s: EN=%b TN=%b A_IN=%04h IO_IN=%04h -> IO_OUT=%04h expected %04h",
                 name, EN, TN, A_IN, IO_IN, IO_OUT, exp_io);
      end
      if (A_OUT !== exp_a) begin
        errors = errors + 1;
        $display("FAIL %0s: EN=%b TN=%b A_IN=%04h IO_IN=%04h -> A_OUT=%04h expected %04h",
                 name, EN, TN, A_IN, IO_IN, A_OUT, exp_a);
      end
    end
  endtask

  task drive_and_check;
    input        en, tn;
    input [15:0] a, io;
    input [255:0] name;
    begin
      EN = en; TN = tn; A_IN = a; IO_IN = io;
      check(name);
    end
  endtask

  integer i, m;
  reg [15:0] pat;
  reg [31:0] seed;

  initial begin
    seed = 32'h5EED_1234;
    EN = 0; TN = 0; A_IN = 0; IO_IN = 0;
    #10;

    $display("=====================================================");
    $display(" BusDriver16 exhaustive functional testbench");
    $display("=====================================================");

    // ---- 1. all four control combinations with fixed data --------------
    for (m = 0; m < 4; m = m + 1) begin
      drive_and_check(m[1], m[0], 16'hA5A5, 16'h5A5A, "CTRL_COMBO");
      drive_and_check(m[1], m[0], 16'h0000, 16'hFFFF, "CTRL_COMBO_0F");
      drive_and_check(m[1], m[0], 16'hFFFF, 16'h0000, "CTRL_COMBO_F0");
    end

    // ---- 2. walking ones and walking zeros on both inputs ---------------
    for (i = 0; i < 16; i = i + 1) begin
      pat = 16'h0001 << i;
      drive_and_check(1'b0, 1'b1, pat, ~pat, "WALK1_DRIVE");
      drive_and_check(1'b1, 1'b1, ~pat, pat, "WALK1_RECEIVE");
      drive_and_check(1'b0, 1'b0, pat, pat, "WALK1_TESTOFF");
    end

    // ---- 3. the three properties this module is most likely to lose -----

    // 3a. A_OUT follows IO_IN even while DRIVING outward (EN=0).
    //     If a refactor gates A_OUT with EN to break the synthesis loop,
    //     THIS is the test that fires. That is a functional change.
    drive_and_check(1'b0, 1'b1, 16'hDEAD, 16'hBEEF, "A_OUT_IGNORES_EN");
    if (A_OUT !== 16'hBEEF) begin
      $display("NOTE: A_OUT no longer follows IO_IN while EN=0 - the receive");
      $display("      side has been gated. That BREAKS the read-back path.");
    end

    // 3b. A_OUT is not affected by test mode either
    drive_and_check(1'b0, 1'b0, 16'hDEAD, 16'hBEEF, "A_OUT_IGNORES_TN");

    // 3c. disabled outputs are ZERO, never z (repo rule: buses are OR-ed)
    drive_and_check(1'b1, 1'b1, 16'hFFFF, 16'h0000, "DISABLED_IS_ZERO_RX");
    if (IO_OUT !== 16'h0000) begin
      errors = errors + 1;
      $display("FAIL DISABLED_IS_ZERO_RX: IO_OUT=%04h, must be 0 not z", IO_OUT);
    end
    drive_and_check(1'b0, 1'b0, 16'hFFFF, 16'h0000, "DISABLED_IS_ZERO_TEST");

    // ---- 4. combinational, not clocked: back-to-back changes ------------
    // Any state element sneaking in here shows up as a stale value.
    EN = 1'b0; TN = 1'b1;
    A_IN = 16'h1111; #1;
    if (IO_OUT !== 16'h1111) begin
      errors = errors + 1;
      $display("FAIL COMB_1: IO_OUT=%04h expected 1111", IO_OUT);
    end
    A_IN = 16'h2222; #1;
    if (IO_OUT !== 16'h2222) begin
      errors = errors + 1;
      $display("FAIL COMB_2: IO_OUT=%04h expected 2222 (stale => latch!)", IO_OUT);
    end
    A_IN = 16'h3333; #1;
    if (IO_OUT !== 16'h3333) begin
      errors = errors + 1;
      $display("FAIL COMB_3: IO_OUT=%04h expected 3333 (stale => latch!)", IO_OUT);
    end
    checks = checks + 3;

    // ---- 5. direction toggling under live data --------------------------
    for (i = 0; i < 8; i = i + 1) begin
      drive_and_check(1'b0, 1'b1, 16'hC000 + i[15:0], 16'h0C00 + i[15:0], "TOGGLE_DRIVE");
      drive_and_check(1'b1, 1'b1, 16'hC000 + i[15:0], 16'h0C00 + i[15:0], "TOGGLE_RECV");
    end

    // ---- 6. pseudo-random soak ------------------------------------------
    for (i = 0; i < 500; i = i + 1) begin
      seed = seed * 32'd1103515245 + 32'd12345;
      drive_and_check(seed[16], seed[17], seed[15:0], ~seed[15:0], "RANDOM");
    end

    // ---- verdict ---------------------------------------------------------
    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
