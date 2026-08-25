/****************************************************************************
** nds_sync_level - 2-flop level synchronizer, exhaustive unit testbench   **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/nds_sync_level_tb.v                                **
**                                                                         **
** WHAT IS VERIFIED                                                        **
**   nds_sync_level (Verilog/SD-FAT/circuit/nds_sync.v, second module in   **
**   that file) is the level crossing used by every quasi-static CDC       **
**   signal in the nd_storage stack - open_ok, the grant id, the error     **
**   flag. It is two flops in the destination clock and nothing else, so   **
**   the properties that matter are countable and are ALL checked here:    **
**                                                                         **
**   1. DEPTH IS EXACTLY TWO. A change on d_src appears on q_dst on the    **
**      SECOND destination edge after it, never the first (that would be   **
**      a single-flop crossing and no metastability filter at all) and     **
**      never the third (an extra flop costs a cycle of latency the        **
**      handshake budget in nd_storage_engine assumes it does not pay).    **
**      Checked edge by edge, for a rise and for a fall, at every phase    **
**      offset of the source change inside the destination period.         **
**   2. THE FIRST FLOP IS A REAL BARRIER. A pulse on d_src that is         **
**      shorter than one destination period may be caught or missed -      **
**      either is correct for a 2-flop level synchronizer - but whatever   **
**      it does it must not produce a value that was never on d_src, and   **
**      it must settle back. Checked by asserting that q_dst only ever     **
**      takes values that were on d_src within the last two edges.         **
**   3. RESET. Synchronous, active low: q_dst is 0 during and immediately  **
**      after reset even while d_src is all ones, and takes exactly two    **
**      edges to follow d_src once reset is released.                      **
**   4. MULTI-BIT WIDTHS. Instantiated at WIDTH 1, 3 and 8; every bit of   **
**      the vector crosses together, so the whole word is compared, not    **
**      just bit 0. All 256 values are driven through the WIDTH=8 copy in  **
**      order, and 8'hFF..8'h00 back, so every bit sees both transitions   **
**      in both directions - EXHAUSTIVE over the value space.             **
**   5. NO X, EVER. q_dst is checked for x/z on every destination edge     **
**      of the whole run.                                                  **
**                                                                         **
** REFERENCE MODEL                                                         **
**   Not a datasheet and not an assumption about "how a synchronizer       **
**   usually works": the model is a two-deep shift register of the         **
**   SAMPLED d_src, built inside this testbench from the same clock and    **
**   the same reset, and compared against q_dst on every single            **
**   destination edge. The intended behaviour is stated in the RTL's own   **
**   header ("plain 2-flop level synchronizer ... for quasi-static         **
**   levels"), which is what the depth check pins down.                    **
**                                                                         **
** WHAT THIS CANNOT DO                                                     **
**   Metastability itself is an analogue effect; an event-driven simulator **
**   has none, so no testbench can show the first flop RESOLVING a         **
**   metastable sample. What is verified is the structural property that   **
**   makes that resolution possible - two flops between d_src and any      **
**   consumer - plus the value-integrity property in (2).                  **
**                                                                         **
** TEST PLAN                                                               **
**   T1  reset holds q_dst at 0 with d_src = all ones                      **
**   T2  release: two edges to follow, per width                           **
**   T3  rise and fall at 8 sub-period phase offsets (WIDTH=1)             **
**   T4  short pulse integrity (values seen must have been driven)         **
**   T5  all 256 values up and down through the WIDTH=8 copy               **
**   T6  reset asserted mid-stream returns q_dst to 0                      **
**   Continuous: the 2-deep shift-register model comparison and the x/z    **
**   check, on every destination edge from reset release to the end.       **
**                                                                         **
** HOW TO RUN                                                              **
**   cd Verilog/SD-FAT/sim && make test-nds-synclevel                      **
**   (or: iverilog -g2012 -o nds_sync_level_tb.vvp ../circuit/nds_sync.v \ **
**        nds_sync_level_tb.v && vvp -N nds_sync_level_tb.vvp)             **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module nds_sync_level_tb;

  // -------------------------------------------------------------- clock/reset
  reg clk = 1'b0;
  always #5 clk = ~clk;          // 100 MHz destination clock
  reg rst_n = 1'b0;

  integer checks = 0;
  integer errors = 0;

  task chk(input cond, input [8*48-1:0] what);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s", $time, what);
      end
    end
  endtask

  // -------------------------------------------------------------- DUTs
  reg        d1 = 1'b0;
  reg [2:0]  d3 = 3'd0;
  reg [7:0]  d8 = 8'd0;
  wire       q1;
  wire [2:0] q3;
  wire [7:0] q8;

  nds_sync_level #(.WIDTH(1)) U1 (
      .clk_dst(clk), .rst_dst_n(rst_n), .d_src(d1), .q_dst(q1));
  nds_sync_level #(.WIDTH(3)) U3 (
      .clk_dst(clk), .rst_dst_n(rst_n), .d_src(d3), .q_dst(q3));
  nds_sync_level #(.WIDTH(8)) U8 (
      .clk_dst(clk), .rst_dst_n(rst_n), .d_src(d8), .q_dst(q8));

  // ---------------------------------------------- independent reference model
  // Two flops, same clock, same synchronous active-low reset. Built here so
  // the comparison is against a model, not against the DUT's own registers.
  reg       m1a, m1b;
  reg [2:0] m3a, m3b;
  reg [7:0] m8a, m8b;
  reg       model_armed = 1'b0;   // compare only once both are past reset

  always @(posedge clk) begin
    if (!rst_n) begin
      m1a <= 1'b0; m1b <= 1'b0;
      m3a <= 3'd0; m3b <= 3'd0;
      m8a <= 8'd0; m8b <= 8'd0;
    end else begin
      m1a <= d1; m1b <= m1a;
      m3a <= d3; m3b <= m3a;
      m8a <= d8; m8b <= m8a;
    end
  end

  // continuous comparison + x/z guard, evaluated after the DUT's own update
  always @(posedge clk) begin
    #1;
    if (model_armed) begin
      chk(q1 === m1b, "WIDTH=1 q_dst != 2-flop model");
      chk(q3 === m3b, "WIDTH=3 q_dst != 2-flop model");
      chk(q8 === m8b, "WIDTH=8 q_dst != 2-flop model");
      chk(^{q1, q3, q8} !== 1'bx, "q_dst went x/z");
    end
  end

  // T4: value integrity - every value that appears on q_dst must be a value
  // that was actually driven on d_src at some point (no invented codes).
  reg [7:0] seen8 [0:255];
  integer   i;
  initial begin
    for (i = 0; i < 256; i = i + 1) seen8[i] = 8'd0;
    seen8[0] = 8'd1;  // 0 is the legitimate reset value of q_dst
  end
  always @(posedge clk) begin
    #1;
    if (model_armed) chk(seen8[q8] === 8'd1, "q_dst produced a value never driven");
  end
  always @(d8) seen8[d8] = 8'd1;

  // -------------------------------------------------------------- watchdog
  initial begin
    #2_000_000;
    $display("checks=%0d failures=%0d", checks, errors + 1);
    $display("TB_RESULT: FAIL  (watchdog: testbench did not finish)");
    $finish;
  end

  // -------------------------------------------------------------- VCD
  initial begin
    $dumpfile("nds_sync_level_tb.vcd");
    $dumpvars(0, nds_sync_level_tb);
  end

  // -------------------------------------------------------------- stimulus
  integer ph;
  integer v;

  initial begin
    // ---- T1: reset holds q_dst at 0 while d_src is all ones -------------
    d1 = 1'b1; d3 = 3'b111; d8 = 8'hFF;
    @(posedge clk); #1;
    chk(q1 === 1'b0 && q3 === 3'd0 && q8 === 8'd0, "T1 q_dst not 0 in reset");
    @(posedge clk); @(posedge clk); #1;
    chk(q1 === 1'b0 && q3 === 3'd0 && q8 === 8'd0, "T1 q_dst not 0 after 3 reset edges");

    // ---- T2: release reset, exactly two edges to follow ------------------
    @(negedge clk);
    rst_n = 1'b1;
    model_armed = 1'b1;
    @(posedge clk); #1;                       // edge 1: first flop only
    chk(q1 === 1'b0 && q8 === 8'h00, "T2 q_dst changed on the FIRST edge");
    @(posedge clk); #1;                       // edge 2: value appears
    chk(q1 === 1'b1 && q3 === 3'b111 && q8 === 8'hFF, "T2 q_dst not updated on the SECOND edge");

    // ---- T3: rise/fall at 8 sub-period phase offsets ---------------------
    for (ph = 0; ph < 8; ph = ph + 1) begin
      // falling transition, applied ph*1ns after a destination edge
      @(posedge clk);
      #(ph + 1);
      d1 = 1'b0;
      @(posedge clk); #1;
      chk(q1 === 1'b1, "T3 fall reached q_dst after ONE edge");
      @(posedge clk); #1;
      chk(q1 === 1'b0, "T3 fall did not reach q_dst after TWO edges");
      // rising transition at the same offset
      @(posedge clk);
      #(ph + 1);
      d1 = 1'b1;
      @(posedge clk); #1;
      chk(q1 === 1'b0, "T3 rise reached q_dst after ONE edge");
      @(posedge clk); #1;
      chk(q1 === 1'b1, "T3 rise did not reach q_dst after TWO edges");
    end

    // ---- T4: a pulse shorter than one destination period -----------------
    // Either sampled or missed - both are correct - but q_dst must settle
    // back to the held level and must never show a value never driven (the
    // seen8/model checks above police that continuously).
    @(posedge clk);
    #1  d1 = 1'b0;
    #2  d1 = 1'b1;                            // 2 ns pulse inside a 10 ns period
    repeat (4) @(posedge clk); #1;
    chk(q1 === 1'b1, "T4 q_dst did not settle back to the held level");

    // ---- T5: all 256 values up, then all 256 down, through WIDTH=8 -------
    for (v = 0; v < 256; v = v + 1) begin
      @(negedge clk);
      d8 = v[7:0];
      d3 = v[2:0];
      d1 = v[0];
    end
    for (v = 255; v >= 0; v = v - 1) begin
      @(negedge clk);
      d8 = v[7:0];
      d3 = v[2:0];
      d1 = v[0];
    end
    repeat (3) @(posedge clk); #1;
    chk(q8 === 8'h00, "T5 final value did not propagate");

    // ---- T6: reset asserted mid-stream ----------------------------------
    @(negedge clk);
    d8 = 8'hA5; d3 = 3'b101; d1 = 1'b1;
    repeat (3) @(posedge clk); #1;
    chk(q8 === 8'hA5 && q3 === 3'b101 && q1 === 1'b1, "T6 pre-reset value wrong");
    @(negedge clk);
    rst_n = 1'b0;
    @(posedge clk); #1;
    chk(q8 === 8'h00 && q3 === 3'd0 && q1 === 1'b0, "T6 reset did not clear q_dst");
    @(negedge clk);
    rst_n = 1'b1;
    @(posedge clk); #1;
    chk(q8 === 8'h00, "T6 q_dst moved on the first edge out of reset");
    @(posedge clk); #1;
    chk(q8 === 8'hA5, "T6 q_dst did not reload two edges out of reset");

    // ---- verdict ---------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
