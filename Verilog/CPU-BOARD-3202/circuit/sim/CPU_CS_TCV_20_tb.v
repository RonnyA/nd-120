/****************************************************************************
** TESTBENCH: CPU_CS_TCV_20 - the control-store transceivers, sheet 20      **
**                                                                         **
** WHAT THIS PINS DOWN (08-AUG-2026)                                       **
**                                                                         **
** Sheet 20 puts two 74PCT373 octal latches between the word-select '245s   **
** and the IDB - chip 9C carries IDB15..IDB8, chip 8C carries IDB7..IDB0.   **
** On BOTH chips the SAME net, ECSL~, drives pin 11 (C, latch enable) AND   **
** pin 1 (/OC, output control):                                            **
**                                                                         **
**   ECSL~ = 1 : C high -> transparent, /OC high -> outputs TRI-STATED      **
**   ECSL~ = 0 : C low  -> HOLDS,      /OC low  -> outputs drive the IDB    **
**                                                                         **
** Because the transparent window never drives the bus, the only            **
** observable behaviour is CAPTURE ON THE FALLING EDGE OF ECSL~ and hold    **
** while ECSL~ is low. That is a flip-flop, not a latch, which is why the   **
** RTL models it with a posedge-sysclk edge detect and nothing here expects **
** transparent-latch behaviour.                                            **
**                                                                         **
** WHY IT EXISTS                                                           **
**                                                                         **
** This capture was MISSING from the RTL entirely - ECSL_n was an unused    **
** input port and the read path was a plain combinational mux. That was the **
** root cause of TRA CS (150017) returning 000000, which is what stopped    **
** SINTRAN III booting with "Micro-code not loaded. CPU revision too low".  **
** During an RWCS microcycle the control-store address moves on BY DESIGN   **
** once EWCA drops, so without this flip-flop the word was gone long before **
** ALUCLK wrote the A register at TERM.                                     **
**                                                                         **
** The checks below are written so that DELETING the capture, or turning it **
** back into a pass-through, fails loudly - see especially checks 4 and 5,  **
** which change the source data underneath a closed latch.                  **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <n> errors                    **
**                                                                         **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module CPU_CS_TCV_20_tb;

  integer errors = 0;

  task ck;
    input          cond;
    input [1023:0] what;
    begin
      if (!cond) begin
        $display("FAIL: %0s", what);
        errors = errors + 1;
      end else begin
        $display("[ ok ] %0s", what);
      end
    end
  endtask

  task ckv;
    input [15:0]   got;
    input [15:0]   want;
    input [1023:0] what;
    begin
      if (got !== want) begin
        $display("FAIL: %0s (got %04h, want %04h)", what, got, want);
        errors = errors + 1;
      end else begin
        $display("[ ok ] %0s (= %04h)", what, got);
      end
    end
  endtask

  // ------------------------------------------------------------------
  reg sysclk = 1'b0;
  always #1 sysclk = ~sysclk;

  reg         sys_rst_n = 1'b0;
  reg  [63:0] csbits    = 64'h0;
  reg  [15:0] idb_in    = 16'h0;
  reg         ecsl_n    = 1'b1;
  reg         wcs_n     = 1'b1;   // 1 = READ direction (CSBITS -> IDB)
  reg  [ 3:0] ew_n      = 4'b1111;

  wire [63:0] csbits_out;
  wire [15:0] idb_out;

  CPU_CS_TCV_20 DUT (
      .sysclk      (sysclk),
      .sys_rst_n   (sys_rst_n),
      .CSBITS      (csbits),
      .CSBITS_OUT  (csbits_out),
      .IDB_15_0_IN (idb_in),
      .IDB_15_0_OUT(idb_out),
      .ECSL_n      (ecsl_n),
      .WCS_n       (wcs_n),
      .EW_3_0_n    (ew_n)
  );

  task tick;
    integer k;
    begin
      for (k = 0; k < 2; k = k + 1) @(posedge sysclk);
      #0;
    end
  endtask

  // Drive one full capture: park ECSL~ high, present data, then assert ECSL~.
  task capture;
    input [63:0] word;
    input [ 3:0] sel_n;
    begin
      ecsl_n = 1'b1;
      csbits = word;
      ew_n   = sel_n;
      tick;
      ecsl_n = 1'b0;   // falling edge = the 373s close
      tick;
    end
  endtask

  localparam [63:0] W = 64'h8877_6655_4433_2211;

  integer k;

  initial begin
    sys_rst_n = 1'b0;
    for (k = 0; k < 6; k = k + 1) @(posedge sysclk);
    sys_rst_n = 1'b1;
    tick;

    // ================================================================
    $display("");
    $display("== 1. outputs are off while ECSL~ is high (/OC deasserted) ==");
    ecsl_n = 1'b1;
    csbits = W;
    ew_n   = 4'b1110;   // select slice 0
    tick;
    ckv(idb_out, 16'h0000,
        "ECSL~ high: IDB driven to 0 (inside the FPGA a disabled 3-state drives 0, not z)");

    // ================================================================
    $display("");
    $display("== 2. falling edge of ECSL~ captures the selected slice ==");
    capture(W, 4'b1110);
    ckv(idb_out, 16'h2211, "slice 0 captured and driven onto the IDB");

    // ================================================================
    $display("");
    $display("== 3. every word-select slice captures its own 16 bits ==");
    capture(W, 4'b1101);
    ckv(idb_out, 16'h4433, "slice 1 captured");
    capture(W, 4'b1011);
    ckv(idb_out, 16'h6655, "slice 2 captured");
    capture(W, 4'b0111);
    ckv(idb_out, 16'h8877, "slice 3 captured");

    // ================================================================
    // THE TEETH. This is the check that fails if the capture is deleted or
    // turned back into a pass-through: the source data is changed while the
    // latch is closed, and the output must NOT follow it.
    $display("");
    $display("== 4. TEETH: held while ECSL~ stays low, even as CSBITS changes ==");
    capture(W, 4'b1110);
    ckv(idb_out, 16'h2211, "captured before the source is disturbed");
    csbits = 64'hDEAD_BEEF_CAFE_F00D;   // control store re-addressed underneath
    tick;
    ckv(idb_out, 16'h2211,
        "IDB STILL holds the captured word after CSBITS changed (a pass-through would show f00d)");
    tick; tick;
    ckv(idb_out, 16'h2211, "and it is still held several cycles later");

    // ================================================================
    // Same teeth for the word-select: in a real RWCS cycle the '245 select
    // does not move, but if the capture were a pass-through this would also
    // leak through, so it is worth nailing down.
    $display("");
    $display("== 5. TEETH: held while ECSL~ stays low, even as EW select changes ==");
    capture(W, 4'b1110);
    ew_n = 4'b0111;      // point the select at a different slice
    tick;
    ckv(idb_out, 16'h2211,
        "IDB STILL holds slice 0 after the select moved to slice 3 (a pass-through would show 8877)");

    // ================================================================
    $display("");
    $display("== 6. releasing ECSL~ turns the outputs off again ==");
    ecsl_n = 1'b1;
    tick;
    ckv(idb_out, 16'h0000, "ECSL~ high again: IDB back to 0");

    // ================================================================
    $display("");
    $display("== 7. a second capture replaces the first ==");
    capture(64'h0000_0000_0000_5A5A, 4'b1110);
    ckv(idb_out, 16'h5A5A, "new value captured on the next ECSL~ falling edge");

    // ================================================================
    $display("");
    $display("== 8. write direction (WCS_n=0) does not drive the IDB ==");
    wcs_n  = 1'b0;
    idb_in = 16'h1234;
    ew_n   = 4'b1110;
    ecsl_n = 1'b0;
    tick;
    ckv(idb_out, 16'h0000,
        "WCS_n low (IDB -> CSBITS): the CS transceivers do not drive the IDB");
    ck(csbits_out[15:0] === 16'h1234,
       "WCS_n low: the selected CSBITS slice takes the IDB input");
    wcs_n = 1'b1;

    // ================================================================
    $display("");
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

endmodule
