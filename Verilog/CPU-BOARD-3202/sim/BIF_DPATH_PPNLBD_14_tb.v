/**************************************************************************
** BIF_DPATH_PPNLBD_14 - address capture testbench                       **
** (sheet 14, BIF PPN TO LBD)                                            **
**                                                                       **
** This is the register that puts a CPU memory address onto the local    **
** bus: the 14-bit physical page number in LBD[23:10] and the 10-bit     **
** cache/word address in LBD[9:0], captured when the CPU raises ECREQ    **
** and published while EADR~ is low.                                     **
**                                                                       **
** WHAT THIS WOULD CATCH                                                 **
**   - the two fields swapped or mis-aligned. Every one of the 24 bits   **
**     is walked one-hot from its own source, so a field boundary off    **
**     by one bit fails on the boundary bits.                            **
**   - the capture strobe wired to the wrong edge, or the register       **
**     staying transparent (it must HOLD when ECREQ is steady, even      **
**     while PPN and CA change underneath).                              **
**   - EADR~ inverted, or a disabled output that does not settle to      **
**     ZERO. LBD is OR-ed with two other sources in BIF_DPATH_9.v line   **
**     196, so a disabled path leaking anything corrupts the others.     **
**   - the held value being LOST while EADR~ is high: the register must  **
**     still hold, so raising EADR~ and lowering it again republishes    **
**     the same word.                                                    **
**                                                                       **
** BOTH BUILD MODES: this module has an `FPGA_FF_MODE `ifdef - latch     **
** mode clocks on posedge ECREQ, FF mode captures on a sysclk-detected   **
** ECREQ rise. The same stimulus is used for both and the same           **
** assertions must hold; FF mode is given one extra sysclk of settling   **
** because the capture is by construction one clock later. Run twice:    **
**     iverilog ...                    (latch mode)                      **
**     iverilog -DFPGA_FF_MODE ...     (FF mode)                         **
**                                                                       **
** SPECIFICATION test for the field split and the enable; the one-clock  **
** FF-mode capture delay is CHARACTERISED, not specified.                **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-ppnlbd14              **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module BIF_DPATH_PPNLBD_14_tb;

  reg         sysclk = 1'b0;
  reg  [13:0] PPN_23_10;
  reg  [ 9:0] CA_9_0;
  reg         EADR_n, ECREQ;
  wire [23:0] LBD_23_0_OUT;

  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [23:0] held;

  always #5 sysclk = ~sysclk;

  BIF_DPATH_PPNLBD_14 DUT (
      .sysclk(sysclk), .PPN_23_10(PPN_23_10), .CA_9_0(CA_9_0),
      .EADR_n(EADR_n), .ECREQ(ECREQ), .LBD_23_0_OUT(LBD_23_0_OUT)
  );

`ifdef FPGA_FF_MODE
  localparam [8*5:1] MODE = "FF   ";
`else
  localparam [8*5:1] MODE = "LATCH";
`endif

  // Raise ECREQ, allow the capture to land in either mode, drop it again.
  task strobe;
    begin
      ECREQ = 1'b0;
      @(posedge sysclk); #1;
      ECREQ = 1'b1;
      @(posedge sysclk); #1;   // FF mode sees the rise here
      @(posedge sysclk); #1;   // and the data is out by now in both modes
      ECREQ = 1'b0;
      @(posedge sysclk); #1;
    end
  endtask

  task expect24;
    input [255:0] name;
    input [23:0] want;
    begin
      checks = checks + 1;
      if (LBD_23_0_OUT !== want) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL %0s: LBD=%06h want %06h (PPN=%04h CA=%03h EADR_n=%b)",
                   name, LBD_23_0_OUT, want, PPN_23_10, CA_9_0, EADR_n);
      end
    end
  endtask

  initial begin
    $dumpfile("BIF_DPATH_PPNLBD_14_tb.vcd");
    $dumpvars(0, BIF_DPATH_PPNLBD_14_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 3000 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #3000 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" BIF_DPATH_PPNLBD_14 (sheet 14) - mode %0s", MODE);
    $display("=====================================================");

    EADR_n = 1'b1; ECREQ = 1'b0; PPN_23_10 = 0; CA_9_0 = 0;
    @(posedge sysclk); #1;

    // ---- 1. field placement: one-hot walk on the CA field. Bit i of CA
    // ----    must appear at LBD bit i and NOWHERE else.
    EADR_n = 1'b0;
    PPN_23_10 = 14'h0000;
    for (i = 0; i < 10; i = i + 1) begin
      CA_9_0 = 10'b1 << i;
      strobe;
      expect24("CA_ONEHOT", {14'h0000, 10'b1 << i});
    end

    // ---- 2. one-hot walk on the PPN field. Bit i of PPN must appear at
    // ----    LBD bit i+10. A field boundary slipped by one bit shows up
    // ----    on PPN bit 0 or CA bit 9.
    CA_9_0 = 10'h000;
    for (i = 0; i < 14; i = i + 1) begin
      PPN_23_10 = 14'b1 << i;
      strobe;
      expect24("PPN_ONEHOT", {14'b1 << i, 10'h000});
    end

    // ---- 3. the two fields together, distinct values, so a swap of the
    // ----    fields cannot pass
    PPN_23_10 = 14'h2AAA; CA_9_0 = 10'h155; strobe;
    expect24("BOTH_FIELDS", {14'h2AAA, 10'h155});

    // ---- 4. HOLD: with ECREQ steady low the register must ignore the
    // ----    inputs completely. If the register were transparent this
    // ----    fires immediately.
    held = LBD_23_0_OUT;
    PPN_23_10 = 14'h1555; CA_9_0 = 10'h2AA;
    @(posedge sysclk); @(posedge sysclk); @(posedge sysclk); #1;
    checks = checks + 1;
    if (LBD_23_0_OUT !== held) begin
      errors = errors + 1;
      $display("FAIL NOT_HOLDING: LBD moved %06h -> %06h with ECREQ low",
               held, LBD_23_0_OUT);
    end

    // ---- 5. holding ECREQ HIGH must not re-open the register either -
    // ----    only the RISE captures.
    ECREQ = 1'b1; @(posedge sysclk); @(posedge sysclk); #1;
    held = LBD_23_0_OUT;   // this is the value captured by the rise
    PPN_23_10 = 14'h0555; CA_9_0 = 10'h0AA;
    @(posedge sysclk); @(posedge sysclk); #1;
    checks = checks + 1;
    if (LBD_23_0_OUT !== held) begin
      errors = errors + 1;
      $display("FAIL LEVEL_SENSITIVE: LBD moved %06h -> %06h while ECREQ stayed high",
               held, LBD_23_0_OUT);
    end
    ECREQ = 1'b0; @(posedge sysclk); #1;

    // ---- 6. EADR~ gating. Disabled must be EXACTLY zero (OR-ed bus), and
    // ----    the held word must come back unchanged when re-enabled.
    PPN_23_10 = 14'h3FFF; CA_9_0 = 10'h3FF; strobe;
    expect24("ALL_ONES", 24'hFFFFFF);
    EADR_n = 1'b1;
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (LBD_23_0_OUT !== 24'h000000) begin
      errors = errors + 1;
      $display("FAIL DISABLED_NOT_ZERO: LBD=%06h with EADR_n high", LBD_23_0_OUT);
    end
    EADR_n = 1'b0;
    @(posedge sysclk); #1;
    expect24("REPUBLISH_AFTER_DISABLE", 24'hFFFFFF);

    // ---- 7. a capture taken while EADR~ is HIGH must still be stored -
    // ----    the enable gates the OUTPUT, not the register.
    EADR_n = 1'b1;
    PPN_23_10 = 14'h1234; CA_9_0 = 10'h0DE;
    strobe;
    checks = checks + 1;
    if (LBD_23_0_OUT !== 24'h000000) begin
      errors = errors + 1;
      $display("FAIL GATE_LEAKS_DURING_CAPTURE: LBD=%06h", LBD_23_0_OUT);
    end
    EADR_n = 1'b0;
    @(posedge sysclk); #1;
    expect24("CAPTURED_WHILE_GATED", {14'h1234, 10'h0DE});

    $display("-----------------------------------------------------");
    $display(" mode       : %0s", MODE);
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
