//============================================================================
//! Equivalence-check driver for CPU_PROC_32.v's registerBlock array
//! (31-AUG-2026) - isolates just the read/write pattern (2048x16, write
//! synchronous on !s_erf_n && !s_twrf_n, read a pure combinational function
//! of the array) rather than dragging in the whole CPU_PROC_32 hierarchy.
//! Two small wrapper modules below reproduce EXACTLY the two branches from
//! CPU_PROC_32.v (copy-checked against the source) - one plain, one
//! altsyncram (MLAB, UNREGISTERED) - driven by identical stimulus, logged,
//! diffed.
//============================================================================

`timescale 1ns / 1ps

module regblock_plain (
    input  wire        sysclk,
    input  wire [10:0] addr,
    input  wire        erf_n,
    input  wire        twrf_n,
    input  wire [15:0] din,
    output wire [15:0] dout
);
  (* ram_style = "block" *) reg [15:0] registerBlock[0:2047];
  always @(posedge sysclk) begin
    if (!erf_n) begin
      if (!twrf_n) registerBlock[addr] <= din;
    end
  end
  assign dout = erf_n ? 16'b0 : twrf_n ? registerBlock[addr] : 16'b0;
endmodule

module regblock_alt (
    input  wire        sysclk,
    input  wire [10:0] addr,
    input  wire        erf_n,
    input  wire        twrf_n,
    input  wire [15:0] din,
    output wire [15:0] dout
);
  wire [15:0] q_a;
  altsyncram #(
      .operation_mode                 ("SINGLE_PORT"),
      .width_a                        (16),
      .widthad_a                      (11),
      .numwords_a                     (2048),
      .outdata_reg_a                  ("UNREGISTERED"),
      .ram_block_type                 ("MLAB"),
      .lpm_type                       ("altsyncram"),
      .intended_device_family         ("Cyclone V")
  ) REGBLOCK_INST (
      .clock0    (sysclk),
      .clocken0  (1'b1),
      .address_a (addr),
      .data_a    (din),
      .wren_a    (!erf_n && !twrf_n),
      .rden_a    (1'b1),
      .aclr0     (1'b0),
      .q_a       (q_a)
  );
  assign dout = erf_n ? 16'b0 : twrf_n ? q_a : 16'b0;
endmodule

`ifdef QUARTUS_ALTSYNCRAM
`define DUT_MOD regblock_alt
`else
`define DUT_MOD regblock_plain
`endif

module registerblock_equiv_tb;

  reg         sysclk = 0;
  reg  [10:0] addr = 0;
  reg         erf_n = 1;
  reg         twrf_n = 1;
  reg  [15:0] din = 0;
  wire [15:0] dout;

  integer logf;
  integer seed = 32'hFEEDFACE;
  integer i;

  always #5 sysclk = ~sysclk;

  `DUT_MOD DUT (
      .sysclk(sysclk),
      .addr  (addr),
      .erf_n (erf_n),
      .twrf_n(twrf_n),
      .din   (din),
      .dout  (dout)
  );

  // Combinational read: the value is valid the SAME cycle the inputs
  // settle, no clock edge needed. Log on every input change point, not on
  // a clock edge - this is the whole point of testing an async-read array.
  task settle_and_log;
    begin
      #1;
      logf = $fopen("regblock_equiv_log.txt", "a");
      $fdisplay(logf, "%0t erf=%b twrf=%b addr=%0d din=%0d dout=%0d", $time, erf_n, twrf_n, addr,
                din, dout);
      $fclose(logf);
    end
  endtask

  task write_word(input [10:0] a, input [15:0] d);
    begin
      @(posedge sysclk);
      addr   = a;
      din    = d;
      erf_n  = 0;
      twrf_n = 0;
      // Wait for the edge that actually SAMPLES these inputs and commits
      // the write, before returning - setting inputs right after an edge
      // and immediately reading again (no further wait) races the DUT's
      // own posedge-triggered write against the testbench's read, which is
      // undefined-order in Verilog and was producing simulator-scheduling
      // noise, not a real RTL difference (found 31-AUG-2026: false
      // divergence traced to exactly this).
      @(posedge sysclk);
      settle_and_log;
      erf_n  = 1;
      twrf_n = 1;
    end
  endtask

  task read_word(input [10:0] a);
    begin
      erf_n  = 0;
      twrf_n = 1;
      addr   = a;
      settle_and_log;  // combinational - must be correct WITHOUT a clock edge
    end
  endtask

  initial begin
    logf = $fopen("regblock_equiv_log.txt", "w");
    $fclose(logf);

    repeat (2) @(posedge sysclk);

    // directed: write then immediately read (no clock edge between), same address
    write_word(11'h010, 16'hA5A5);
    read_word(11'h010);

    // directed: write a run, read them back with NO write in between
    for (i = 0; i < 16; i = i + 1) write_word(11'h100 + i, 16'h1000 + i);
    for (i = 0; i < 16; i = i + 1) read_word(11'h100 + i);

    // directed: read while deselected (erf_n=1) must give 0
    erf_n = 1;
    settle_and_log;

    // directed: read while twrf_n=0 (write mode, not a real read) must give 0
    erf_n  = 0;
    twrf_n = 0;
    addr   = 11'h100;
    settle_and_log;

    // directed: address changes with erf_n/twrf_n held in READ mode - the
    // combinational path must track EVERY address change with no clock
    erf_n  = 0;
    twrf_n = 1;
    for (i = 0; i < 8; i = i + 1) begin
      addr = 11'h100 + i;
      settle_and_log;
    end

    // pseudo-random stress: 400 random write/read events
    for (i = 0; i < 400; i = i + 1) begin
      if ($random(seed) % 2 == 0) begin
        write_word($random(seed) % 2048, $random(seed) % 65536);
      end else begin
        read_word($random(seed) % 2048);
      end
    end

    $display("EQUIV_TB_DONE");
    $finish;
  end

endmodule
