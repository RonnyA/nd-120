/****************************************************************************
** Unit testbench for the nd_storage CDC primitives + word bridge (iverilog)
**                                                                         **
** Exercises nds_sync_pulse / nds_sync_level across two SKEWED clocks     **
** (27.03 MHz "stor" vs 23.04 MHz "cpu", non-integer ratio) with the      **
** exact word-bridge handshake nd_storage_engine uses:                    **
**                                                                         **
**   direction A (stor -> cpu, the block-read stream): producer sets the  **
**   data one clock BEFORE flipping have_tgl, then waits for the synced   **
**   ack pulse; consumer samples the (stable) data at the have pulse and  **
**   flips ack. 1024 words with random 0..7 cycle stalls on both sides.   **
**                                                                         **
**   direction B (cpu -> stor, the block-write pull): requester flips     **
**   want_tgl and waits; responder answers with data + have_tgl on the    **
**   same edge (the front-end's cycle-B pattern), random stalls, 1024     **
**   words.                                                               **
**                                                                         **
**   level check: 64 random 8-bit values through nds_sync_level, each     **
**   held quasi-static, compared after the 2-flop settle.                 **
**                                                                         **
** Verifies order and data integrity word-for-word in both directions.    **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_storage_cdc_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz (non-integer ratio vs stor)
  localparam NWORDS    = 1024;

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

  // word patterns (address-unique so misordering is caught)
  function [15:0] pat_a(input integer n);
    pat_a = (n[15:0] * 16'h30D5) + 16'h1234 + {6'd0, n[15:6]};
  endfunction
  function [15:0] pat_b(input integer n);
    pat_b = (n[15:0] * 16'h1F4B) ^ 16'hA5C3;
  endfunction

  // =====================================================================
  // direction A: stor -> cpu (mirrors the engine's read push)
  // =====================================================================
  reg         a_have_tgl = 0;   // clk_stor
  reg  [15:0] a_data = 0;       // clk_stor, stable while the flip crosses
  reg         a_ack_tgl = 0;    // clk_cpu
  wire        a_have_pulse;     // clk_cpu
  wire        a_ack_pulse;      // clk_stor

  nds_sync_pulse u_a_have (
      .clk_dst(clk_cpu), .rst_dst_n(rst_n),
      .tgl_src(a_have_tgl), .pulse_dst(a_have_pulse)
  );
  nds_sync_pulse u_a_ack (
      .clk_dst(clk_stor), .rst_dst_n(rst_n),
      .tgl_src(a_ack_tgl), .pulse_dst(a_ack_pulse)
  );

  // producer (clk_stor)
  integer   ap_seed = 32'h0000_1111;
  integer   ap_n = 0;
  reg [2:0] ap_st = 0;
  reg [3:0] ap_stall = 0;
  always @(posedge clk_stor) begin
    if (!rst_n) begin
      ap_st <= 0;
    end else begin
      case (ap_st)
        0: begin
          ap_stall <= {$random(ap_seed)} % 8;
          ap_st    <= 1;
        end
        1: if (ap_stall == 0) ap_st <= 2;
           else ap_stall <= ap_stall - 4'd1;
        2: begin
          a_data <= pat_a(ap_n);  // data one clock before the flip
          ap_st  <= 3;
        end
        3: begin
          a_have_tgl <= ~a_have_tgl;
          ap_st      <= 4;
        end
        4: if (a_ack_pulse) begin
          ap_n  <= ap_n + 1;
          ap_st <= (ap_n == NWORDS - 1) ? 3'd5 : 3'd0;
        end
        5: ap_st <= 5;  // finished
        default: ap_st <= 0;
      endcase
    end
  end

  // consumer (clk_cpu)
  integer    ac_seed = 32'h0000_2222;
  integer    ac_n = 0;
  reg  [1:0] ac_st = 0;
  reg  [3:0] ac_stall = 0;
  reg [15:0] a_rx[0:NWORDS-1];
  always @(posedge clk_cpu) begin
    if (!rst_n) begin
      ac_st <= 0;
    end else begin
      case (ac_st)
        0: if (a_have_pulse) begin
          ac_stall <= {$random(ac_seed)} % 8;
          ac_st    <= 1;
        end
        1: if (ac_stall == 0) begin
          a_rx[ac_n] <= a_data;  // stable-payload rule
          ac_n       <= ac_n + 1;
          a_ack_tgl  <= ~a_ack_tgl;
          ac_st      <= 0;
        end else ac_stall <= ac_stall - 4'd1;
        default: ac_st <= 0;
      endcase
    end
  end

  // =====================================================================
  // direction B: cpu -> stor (mirrors the engine's write pull)
  // =====================================================================
  reg         b_want_tgl = 0;   // clk_stor
  reg         b_have_tgl = 0;   // clk_cpu
  reg  [15:0] b_data = 0;       // clk_cpu, set on the same edge as the flip
  wire        b_want_pulse;     // clk_cpu
  wire        b_have_pulse;     // clk_stor

  nds_sync_pulse u_b_want (
      .clk_dst(clk_cpu), .rst_dst_n(rst_n),
      .tgl_src(b_want_tgl), .pulse_dst(b_want_pulse)
  );
  nds_sync_pulse u_b_have (
      .clk_dst(clk_stor), .rst_dst_n(rst_n),
      .tgl_src(b_have_tgl), .pulse_dst(b_have_pulse)
  );

  // requester (clk_stor) - the engine side of W_PULL
  integer    bq_seed = 32'h0000_3333;
  integer    bq_n = 0;
  reg  [2:0] bq_st = 0;
  reg  [3:0] bq_stall = 0;
  reg [15:0] b_rx[0:NWORDS-1];
  always @(posedge clk_stor) begin
    if (!rst_n) begin
      bq_st <= 0;
    end else begin
      case (bq_st)
        0: begin
          bq_stall <= {$random(bq_seed)} % 8;
          bq_st    <= 1;
        end
        1: if (bq_stall == 0) bq_st <= 2;
           else bq_stall <= bq_stall - 4'd1;
        2: begin
          b_want_tgl <= ~b_want_tgl;
          bq_st      <= 3;
        end
        3: if (b_have_pulse) begin
          b_rx[bq_n] <= b_data;  // stable-payload rule
          bq_n       <= bq_n + 1;
          bq_st      <= (bq_n == NWORDS - 1) ? 3'd4 : 3'd0;
        end
        4: bq_st <= 4;  // finished
        default: bq_st <= 0;
      endcase
    end
  end

  // responder (clk_cpu) - the front-end side (data + flip, same edge)
  integer   br_seed = 32'h0000_4444;
  integer   br_n = 0;
  reg [1:0] br_st = 0;
  reg [3:0] br_stall = 0;
  always @(posedge clk_cpu) begin
    if (!rst_n) begin
      br_st <= 0;
    end else begin
      case (br_st)
        0: if (b_want_pulse) begin
          br_stall <= {$random(br_seed)} % 8;
          br_st    <= 1;
        end
        1: if (br_stall == 0) begin
          b_data     <= pat_b(br_n);
          b_have_tgl <= ~b_have_tgl;
          br_n       <= br_n + 1;
          br_st      <= 0;
        end else br_stall <= br_stall - 4'd1;
        default: br_st <= 0;
      endcase
    end
  end

  // =====================================================================
  // level synchronizer check
  // =====================================================================
  reg  [7:0] lv_d = 0;    // clk_stor side driver
  wire [7:0] lv_q;
  nds_sync_level #(
      .WIDTH(8)
  ) u_lvl (
      .clk_dst(clk_cpu), .rst_dst_n(rst_n),
      .d_src(lv_d), .q_dst(lv_q)
  );

  integer lv_seed = 32'h0000_5555;
  integer lv_i;
  integer lv_errors = 0;
  reg lv_done = 0;
  initial begin
    @(posedge rst_n);
    repeat (10) @(posedge clk_cpu);
    for (lv_i = 0; lv_i < 64; lv_i = lv_i + 1) begin
      @(posedge clk_stor);
      lv_d <= {$random(lv_seed)} % 256;
      repeat (12) @(posedge clk_cpu);  // quasi-static hold, then settled
      if (lv_q !== lv_d) begin
        if (lv_errors < 5)
          $display("FAIL: level sync value %0d: got %02x want %02x", lv_i, lv_q, lv_d);
        lv_errors = lv_errors + 1;
      end
    end
    lv_done = 1;
  end

  // =====================================================================
  // verdict
  // =====================================================================
  integer i, errors;
  initial begin
    repeat (10) @(posedge clk_stor);
    rst_n = 1;

    // wait for all three streams to finish
    wait (ap_st == 3'd5);
    wait (bq_st == 3'd4);
    wait (lv_done == 1);
    repeat (20) @(posedge clk_cpu);

    errors = lv_errors;

    if (ac_n !== NWORDS) begin
      $display("FAIL: direction A consumer got %0d words (want %0d)", ac_n, NWORDS);
      errors = errors + 1;
    end
    for (i = 0; i < NWORDS; i = i + 1) begin
      if (a_rx[i] !== pat_a(i)) begin
        if (errors < 10)
          $display("FAIL: A word %0d: got %04x want %04x", i, a_rx[i], pat_a(i));
        errors = errors + 1;
      end
      if (b_rx[i] !== pat_b(i)) begin
        if (errors < 10)
          $display("FAIL: B word %0d: got %04x want %04x", i, b_rx[i], pat_b(i));
        errors = errors + 1;
      end
    end
    if (br_n !== NWORDS) begin
      $display("FAIL: direction B responder answered %0d words (want %0d)", br_n, NWORDS);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #50_000_000;  // 50 ms absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog (A %0d/%0d, B %0d/%0d)",
             ac_n, NWORDS, bq_n, NWORDS);
    $finish;
  end

endmodule
