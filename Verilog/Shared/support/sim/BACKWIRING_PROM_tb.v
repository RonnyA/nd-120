/**************************************************************************************************
** ND120 Shared - unit test                                                                      **
**                                                                                               **
** BACKWIRING_PROM testbench: the backplane installation-number PROM that the                    **
** VERSN instruction reads through IDBS,INR = 35 octal, addressed by PIL 3:0.                    **
**                                                                                               **
** Contract under test (SINTRAN GCPUNR, NDInsight PH-P2-OPPSTART.NPL:3534-3570):                 **
**   byte 0 = SYSNO MSB     byte 1 = SYSNO LSB       -> CPU NUMBER                               **
**   byte 2 = HWINFO(2) MSB byte 3 = HWINFO(2) LSB   -> CPU TYPE                                 **
**   byte 4 = NLEGU         byte 5 = unused by SINTRAN                                           **
**   byte 6 = 0x55          byte 7 = 0xAA            -> signature 52652 octal, HARDWIRED         **
**   bytes 8..15 = filler, SINTRAN never reads them                                              **
**                                                                                               **
** Pass 1: the STOCK build (module defaults) - proves a default bitstream has a                  **
**         VALID signature so GCPUNR does not EXIT.                                              **
** Pass 2: an explicitly parameterised build (a chosen SYSNO/HWINFO2/NLEGU).                     **
** Pass 3: the "not present" sentinels (SYSNO/HWINFO2 = -1, NLEGU = 0377B) -                     **
**         a deliberate "this machine has no configured number" bitstream; the                   **
**         signature must STILL be 0x55/0xAA.                                                    **
** Pass 4: self-check - the comparison is re-run against a deliberately wrong                    **
**         expectation and MUST report mismatches, proving this tb can fail.                     **
**                                                                                               **
** Run: make test-inrprom                                                                        **
**                                                                                               **
** Last reviewed: 20-JUL-2026                                                                    **
** Ronny Hansen                                                                                  **
***************************************************************************************************/
`timescale 1ns / 1ps

module BACKWIRING_PROM_tb;

  integer errors = 0;
  integer selfcheck_errors = 0;
  integer i;

  reg [3:0] pil;

  // (1) stock defaults - whatever nd120_backwiring_defaults.vh says
  wire [7:0] d_def;
  BACKWIRING_PROM DUT_DEFAULT (
      .PIL_3_0(pil),
      .INR_7_0(d_def)
  );

  // (2) explicitly configured machine
  localparam [15:0] P_SYSNO   = 16'd4711;
  localparam [15:0] P_HWINFO2 = 16'd9883;  // the one live-verified system type we have
  localparam [ 7:0] P_NLEGU   = 8'd32;
  wire [7:0] d_cfg;
  BACKWIRING_PROM #(
      .SYSNO  (P_SYSNO),
      .HWINFO2(P_HWINFO2),
      .NLEGU  (P_NLEGU)
  ) DUT_CONFIGURED (
      .PIL_3_0(pil),
      .INR_7_0(d_cfg)
  );

  // (3) every field set to its documented "not present" sentinel
  wire [7:0] d_abs;
  BACKWIRING_PROM #(
      .SYSNO  (16'hFFFF),
      .HWINFO2(16'hFFFF),
      .NLEGU  (8'o377)
  ) DUT_ABSENT (
      .PIL_3_0(pil),
      .INR_7_0(d_abs)
  );

  // Compare one byte; 'selfcheck' routes the failure count to the self-check
  // bucket instead of the real error count.
  task check;
    input [127:0] name;
    input [  3:0] addr;
    input [  7:0] got;
    input [  7:0] exp;
    input         selfcheck;
    begin
      if (got !== exp) begin
        if (selfcheck) selfcheck_errors = selfcheck_errors + 1;
        else begin
          errors = errors + 1;
          $display("  MISMATCH %0s PIL=%0d  got=%02h  expected=%02h", name, addr, got, exp);
        end
      end
    end
  endtask

  initial begin
    $dumpfile("BACKWIRING_PROM_tb.vcd");
    $dumpvars(0, BACKWIRING_PROM_tb);

    $display("== BACKWIRING_PROM: stock defaults ==");
    // The signature is the only thing the DEFAULT build must guarantee here -
    // the field values themselves are build choices, so the tb pins what is
    // contractual (signature + filler) and merely REPORTS the defaults.
    pil = 4'd0; #1; $display("   byte0 SYSNO   MSB = %02h", d_def);
    pil = 4'd1; #1; $display("   byte1 SYSNO   LSB = %02h", d_def);
    pil = 4'd2; #1; $display("   byte2 HWINFO2 MSB = %02h", d_def);
    pil = 4'd3; #1; $display("   byte3 HWINFO2 LSB = %02h", d_def);
    pil = 4'd4; #1; $display("   byte4 NLEGU       = %02h", d_def);
    pil = 4'd6; #1; check("default sign hi", pil, d_def, 8'h55, 1'b0);
    pil = 4'd7; #1; check("default sign lo", pil, d_def, 8'hAA, 1'b0);
    for (i = 8; i < 16; i = i + 1) begin
      pil = i[3:0]; #1; check("default filler", pil, d_def, 8'h00, 1'b0);
    end

    $display("== BACKWIRING_PROM: configured build (SYSNO=%0d HWINFO2=%0d NLEGU=%0d) ==",
             P_SYSNO, P_HWINFO2, P_NLEGU);
    pil = 4'd0; #1; check("cfg sysno hi",   pil, d_cfg, P_SYSNO[15:8],   1'b0);
    pil = 4'd1; #1; check("cfg sysno lo",   pil, d_cfg, P_SYSNO[7:0],    1'b0);
    pil = 4'd2; #1; check("cfg hwinfo2 hi", pil, d_cfg, P_HWINFO2[15:8], 1'b0);
    pil = 4'd3; #1; check("cfg hwinfo2 lo", pil, d_cfg, P_HWINFO2[7:0],  1'b0);
    pil = 4'd4; #1; check("cfg nlegu",      pil, d_cfg, P_NLEGU,         1'b0);
    pil = 4'd5; #1; check("cfg byte5",      pil, d_cfg, 8'h00,           1'b0);
    pil = 4'd6; #1; check("cfg sign hi",    pil, d_cfg, 8'h55,           1'b0);
    pil = 4'd7; #1; check("cfg sign lo",    pil, d_cfg, 8'hAA,           1'b0);

    $display("== BACKWIRING_PROM: all fields ABSENT (sentinels) ==");
    pil = 4'd0; #1; check("abs sysno hi",   pil, d_abs, 8'hFF, 1'b0);
    pil = 4'd1; #1; check("abs sysno lo",   pil, d_abs, 8'hFF, 1'b0);
    pil = 4'd2; #1; check("abs hwinfo2 hi", pil, d_abs, 8'hFF, 1'b0);
    pil = 4'd3; #1; check("abs hwinfo2 lo", pil, d_abs, 8'hFF, 1'b0);
    pil = 4'd4; #1; check("abs nlegu",      pil, d_abs, 8'hFF, 1'b0);
    // The signature must survive the "nothing configured" build, otherwise
    // GCPUNR EXITs before it ever looks at the sentinels.
    pil = 4'd6; #1; check("abs sign hi",    pil, d_abs, 8'h55, 1'b0);
    pil = 4'd7; #1; check("abs sign lo",    pil, d_abs, 8'hAA, 1'b0);

    // Pass 4: prove the tb can fail. Compare the signature against the WRONG
    // bytes; every one of these must be counted as a self-check mismatch.
    $display("== self-check (these MUST mismatch) ==");
    pil = 4'd6; #1; check("selfcheck", pil, d_cfg, 8'hAA, 1'b1);
    pil = 4'd7; #1; check("selfcheck", pil, d_cfg, 8'h55, 1'b1);

    if (selfcheck_errors != 2) begin
      $display("  SELF-CHECK BROKEN: expected 2 deliberate mismatches, saw %0d", selfcheck_errors);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
