/**************************************************************************
** ND120 CPU - unit test                                                 **
** MEM_RAM_49_BLOCKRAM address-SPACE integrity gate                      **
**                                                                       **
** REGRESSION FOR THE 24-AUG-2026 LIST-FILE-NAMES RUNAWAY: the Nexys    **
** build shipped ND120_BLOCKRAM_ADDR_BITS=15 - 32K words per bank, HALF **
** the ND-120's 64K-word logical space - so every access at or above    **
** word 0o100000 silently wrapped onto low memory. FILSYS's answer path **
** aliased and the machine printed its help line forever. The protocol  **
** bench (MEM_RAM_49_BLOCKRAM_tb) runs at the default size and cannot   **
** see a CONFIGURATION that is too small; this bench exists to fail the **
** suite the day anyone truncates the space again.                      **
**                                                                       **
** Checks:                                                              **
**  0. CONTRACT: BANK_ADDR_BITS >= 16. The ND-120 addresses 64K words   **
**     per bank; a smaller backend wraps by construction -> immediate   **
**     FAIL, no vectors needed. (With =15 this is the one-line tooth    **
**     that catches the exact 24-AUG bug.)                              **
**  1. ADDRESS-BIT WALK: a unique tag at word 0 and at every power-of-  **
**     two word address (1<<0 .. 1<<15), then all 17 read back intact.  **
**     A dropped, truncated, or swapped CPU address bit aliases at      **
**     least one pair and fails. This also re-proves the old lin-concat **
**     reversal (400& junk bug) at full size.                           **
**  2. TOP-OF-SPACE: tags at 0o177777, 0o100000, 0o077777 stay distinct **
**     - the exact bit-15 pair the 24-AUG bug collapsed.                **
**  3. BANK WALK: the same word address tagged differently in banks     **
**     0/1/2 reads back per-bank.                                       **
**                                                                       **
** Size under test: ND120_BLOCKRAM_ADDR_BITS if defined (the Makefile   **
** passes 16 = what fpga/nexys4ddr/build.tcl ships - keep them in       **
** step), else 16.                                                      **
**                                                                       **
** CPU word address -> DRAM protocol: col = addr[9:0] on AA at CAS,     **
** row = addr[15:10] (zero-extended to 10 bits) on AA at the RAS edge;  **
** lin = {row, col} and the module keeps lin[BANK_ADDR_BITS-1:0].       **
**                                                                       **
** Teeth (proven 24-AUG-2026): iverilog -DND120_BLOCKRAM_ADDR_BITS=15   **
** makes this bench FAIL on check 0 AND on the bit-15 walk step.        **
**                                                                       **
** Run: make test-blockram-space   (CPU-BOARD-3202/circuit/sim)         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL                           **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_RAM_49_BLOCKRAM_SPACE_tb;

`ifdef ND120_BLOCKRAM_ADDR_BITS
  localparam integer TB_ADDR_BITS = `ND120_BLOCKRAM_ADDR_BITS;
`else
  localparam integer TB_ADDR_BITS = 16;
`endif

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg         sys_rst_n = 0;
  reg  [9:0]  aa = 0;
  reg         bank0 = 0, bank1 = 0, bank2 = 0;
  reg         ras = 0, cas = 0;
  reg         mwrite50_n = 1;
  reg  [17:0] dd_in = 0;
  wire [17:0] dd_out;
  wire        corr_n;

  MEM_RAM_49_BLOCKRAM #(.BANK_ADDR_BITS(TB_ADDR_BITS)) dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(aa),
      .BANK0(bank0),
      .BANK1(bank1),
      .BANK2(bank2),
      .CAS(cas),
      .RAS(ras),
      .MWRITE50_n(mwrite50_n),
      .DD_17_0_IN(dd_in),
      .DD_17_0_OUT(dd_out),
      .CORR_n(corr_n)
  );

  integer errors = 0;
  integer checks = 0;

  task set_bank(input [1:0] b);
    begin
      bank0 = (b == 0);
      bank1 = (b == 1);
      bank2 = (b == 2);
    end
  endtask

  // one full CPU word address through the measured DRAM protocol
  task waddr(input [1:0] b, input [15:0] addr, input [15:0] data);
    begin
      @(negedge sysclk); set_bank(b); aa = {4'b0, addr[15:10]}; ras = 1; mwrite50_n = 0;
      @(negedge sysclk); aa = addr[9:0]; dd_in = {1'b0, 1'b0, data[15:8], 1'b0, data[7:0]};
      @(negedge sysclk); cas = 1;
      @(negedge sysclk);
      @(negedge sysclk); ras = 0; cas = 0; mwrite50_n = 1; set_bank(3);
      @(negedge sysclk);
    end
  endtask

  task raddr(input [1:0] b, input [15:0] addr, output [15:0] data);
    reg [17:0] d18;
    begin
      @(negedge sysclk); set_bank(b); aa = {4'b0, addr[15:10]}; ras = 1; mwrite50_n = 1;
      @(negedge sysclk); aa = addr[9:0];
      @(negedge sysclk); cas = 1;
      @(negedge sysclk);
      @(negedge sysclk); d18 = dd_out;
      @(negedge sysclk); ras = 0; cas = 0; set_bank(3);
      @(negedge sysclk);
      data = {d18[16:9], d18[7:0]};
    end
  endtask

  task check_addr(input [1:0] b, input [15:0] addr, input [15:0] want,
                  input [127:0] label);
    reg [15:0] got;
    begin
      raddr(b, addr, got);
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: bank %0d addr %06o got %06o expected %06o",
                 label, b, addr, got, want);
      end
    end
  endtask

  integer b;
  reg [15:0] a16;

  initial begin
    // ---- 0. CONTRACT: the backend must span the 64K-word logical space
    if (TB_ADDR_BITS < 16) begin
      $display("FAIL contract: BANK_ADDR_BITS=%0d holds only %0d words per bank;",
               TB_ADDR_BITS, (1 << TB_ADDR_BITS));
      $display("     the ND-120 addresses 65536 words per bank - every access at");
      $display("     or above word %06o WRAPS onto low memory (the 24-AUG-2026", (1 << TB_ADDR_BITS));
      $display("     LIST-FILE-NAMES runaway). Set ND120_BLOCKRAM_ADDR_BITS=16.");
      $display("TB_RESULT: FAIL");
      $finish;
    end

    repeat (4) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (2) @(negedge sysclk);

    // ---- 1. address-bit walk: unique tag at word 0 and at every 1<<b ----
    waddr(0, 16'd0, 16'o170000);
    for (b = 0; b < 16; b = b + 1)
      waddr(0, 16'd1 << b, 16'o100 + b[15:0]);
    check_addr(0, 16'd0, 16'o170000, "bitwalk addr0");
    for (b = 0; b < 16; b = b + 1)
      check_addr(0, 16'd1 << b, 16'o100 + b[15:0], "bitwalk 1<<b");

    // ---- 2. top-of-space: the exact bit-15 pair the 24-AUG bug collapsed
    waddr(0, 16'o077777, 16'o031111);
    waddr(0, 16'o100000, 16'o032222);
    waddr(0, 16'o177777, 16'o033333);
    check_addr(0, 16'o077777, 16'o031111, "top 077777");
    check_addr(0, 16'o100000, 16'o032222, "top 100000");
    check_addr(0, 16'o177777, 16'o033333, "top 177777");

    // ---- 3. bank walk at one shared address ----
    waddr(0, 16'o123456, 16'o000111);
    waddr(1, 16'o123456, 16'o000222);
    waddr(2, 16'o123456, 16'o000333);
    check_addr(0, 16'o123456, 16'o000111, "bank0");
    check_addr(1, 16'o123456, 16'o000222, "bank1");
    check_addr(2, 16'o123456, 16'o000333, "bank2");

    if (errors == 0)
      $display("TB_RESULT: PASS (%0d checks, BANK_ADDR_BITS=%0d)", checks, TB_ADDR_BITS);
    else
      $display("TB_RESULT: FAIL (%0d of %0d checks)", errors, checks);
    $finish;
  end

endmodule
