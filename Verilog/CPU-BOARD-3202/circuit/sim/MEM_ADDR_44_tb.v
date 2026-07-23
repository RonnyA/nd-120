/****************************************************************************
** Testbench for MEM_ADDR_44 - the row/col address latches                 **
**                                                                         **
** REGRESSION TEST for the 8-JUL-2026 memory-write break: BCGNT50 is a    **
** multi-cycle grant window and LBD is ADDRESS-then-DATA multiplexed. The  **
** address registers (AM29C821 CHIP_3H/4H) must capture LBD exactly ONCE   **
** at the BCGNT50 rising edge and HOLD it while LBD moves on to the write  **
** data. A level-enable conversion (USE_SYSCLK=1) re-captures every cycle  **
** and ends up presenting the DATA as the address - this tb FAILS on that  **
** and PASSES on posedge-CK (original) and USE_SYSCLK=2 (edge capture).    **
**                                                                         **
** Prints "TB_RESULT: PASS" on success.                                    **
**                                                                         **
** Last reviewed: 8-JUL-2026                                               **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module MEM_ADDR_44_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg [19:0] LBD = 0;
  reg BCGNT50 = 0;
  reg LOEN_n = 1;
  reg HIEN_n = 1;
  wire [9:0] AA;

  MEM_ADDR_44 dut (
      .sysclk(sysclk),
      .LBD_19_0(LBD),
      .BCGNT50(BCGNT50),
      .LOEN_n(LOEN_n),
      .HIEN_n(HIEN_n),
      .PD4(1'b0),
      .AA_9_0(AA)
  );

  integer errors = 0;

  task check(input [9:0] expect_aa, input [127:0] what);
    if (AA !== expect_aa) begin
      errors = errors + 1;
      $display("FAIL at %0t: %0s (AA=%o expected %o)", $time, what, AA, expect_aa);
    end
  endtask

  // One grant window, modelled on the measured protocol (docs/
  // nd120-dram-memory.md): grant rises with the address on LBD, the address
  // stays ~2 cycles, then LBD carries the WRITE DATA while the grant is
  // still high and the row/col phases (HIEN/LOEN) play out.
  task grant_cycle(input [19:0] addr, input [19:0] wdata);
    begin
      @(posedge sysclk);
      LBD     <= addr;
      BCGNT50 <= 1;             // grant rises, address valid on LBD
      @(posedge sysclk);
      @(posedge sysclk);        // registers have captured by now (edge + 1)
      LBD <= wdata;             // LBD moves on to the WRITE DATA (grant still high!)
      @(posedge sysclk);
      HIEN_n <= 0;              // row phase
      @(posedge sysclk);
      #1 check(addr[19:10], "row phase: AA must be the ADDRESS high bits");
      @(posedge sysclk);
      HIEN_n <= 1;
      LOEN_n <= 0;              // column phase
      @(posedge sysclk);
      #1 check(addr[9:0], "col phase: AA must be the ADDRESS low bits");
      @(posedge sysclk);
      #1 check(addr[9:0], "col phase hold: AA must STILL be the address");
      @(posedge sysclk);
      LOEN_n  <= 1;
      BCGNT50 <= 0;             // grant window ends
      LBD     <= 20'hxxxxx;
      repeat (3) @(posedge sysclk);
    end
  endtask

  initial begin
    repeat (4) @(posedge sysclk);

    // The regression case: data differs from address in every bit group
    grant_cycle(20'o0000022, 20'o0054321);
    // Second grant: registers must re-arm and capture the NEW address
    grant_cycle(20'o1234567, 20'o0000000);
    // Data = 0 while address nonzero (catches stuck-at-data both ways)
    grant_cycle(20'o0770077, 20'o0707070);

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #100000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
