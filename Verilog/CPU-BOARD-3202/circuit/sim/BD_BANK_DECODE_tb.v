/***************************************************************************
** ND120 CPU-BOARD-3202                                                   **
** BD -> MEMORY BANK DECODE: the bus address must reach the bank decode   **
**                                                                        **
** REGRESSION GUARD for the defect fixed 24-AUG-2026 in ND3202D.v:533.    **
**                                                                        **
** WHAT WENT WRONG. The five address bits that select the memory bank     **
** were tapped from `s_bif_bd_23_0_n_OUT` - what THIS BOARD DRIVES onto   **
** the bus - instead of `s_bif_bd_23_0_n_IN`, what the bus CARRIES. On an **
** incoming DMA write the board is the slave and drives nothing, and      **
** BIF_DPATH_BDLBD_10.v:76 idles that output at ~24'b0 (all ones,         **
** active-low idle). BD23..BD19 therefore read as 0 for every incoming    **
** transfer, PAL_44446B.v:66 gave BANK0_n = BD21|BD20 = 0, and every DMA  **
** write landed in BANK0 whatever address the master presented. The row   **
** and column were unaffected - they come from LBD_19_0, which IS captured**
** from the bus INPUT - so disc data landed at the RIGHT ROW in the WRONG **
** BANK and the CPU read a page nothing had written.                      **
**                                                                        **
** Measured on Tang silicon: SINTRAN's segment load wrote physical page   **
** 1016 = {BANK0, row 1016} while the MMU resolved the same logical page  **
** to 2040 = {BANK2, row 1016}; the CPU fetched zeros, ran them as STZ    **
** and died in ERRFATAL after exactly 143 s on every boot.                **
**                                                                        **
** WHY THIS IS AN IVERILOG TEST AND NOT A SIM BOOT. The Verilator model   **
** MEM_RAM_49_SIM.v provides ALL THREE banks, so a misdirected bank still **
** finds real memory there and the boot succeeds. This class of fault is  **
** INVISIBLE in that harness by construction - the guard has to sit on    **
** the board decode path itself.                                          **
**                                                                        **
** WHAT IS CHECKED. Drive a physical address on the real BD_23_0_n_IN     **
** port while the board drives nothing, then read the internal decode tap **
** through a hierarchical reference - so the WIRING is tested, not a copy **
** of the expression.                                                     **
**                                                                        **
** 24-AUG-2026  Ronny Hansen                                              **
***************************************************************************/

`timescale 1ns / 1ps

module BD_BANK_DECODE_tb;

  reg sysclk = 1'b0;
  reg clk2x = 1'b0;
  reg sys_rst_n = 1'b0;
  reg [23:0] bd_n = 24'hFFFFFF;   // bus idle: active-low, all released

  integer errors = 0;
  integer checks = 0;

  always #5 sysclk = ~sysclk;
  always #5 clk2x = ~clk2x;

  // Every input is tied to a DEFINED idle state. That matters: the decode tap
  // is the wired-AND of the bus INPUT and what the board DRIVES, and the drive
  // side is only all-ones (active-low idle) once the BIF's enable is defined.
  // Leaving those inputs floating makes the tap read X and the test says
  // nothing.
  ND3202D DUT (
      .sysclk(sysclk),
      .clk2x(clk2x),
      .clk2x_sdram(clk2x),
      .sys_rst_n(sys_rst_n),
      .CLOCK_1(sysclk),
      .CLOCK_2(sysclk),

      // C-plug: every active-low control released
      .LOAD_n(1'b1),
      .BREQ_n(1'b1),
      .CONTINUE_n(1'b1),
      .STOP_n(1'b1),
      .BINT10_n(1'b1),
      .BINT11_n(1'b1),
      .BINT12_n(1'b1),
      .BINT13_n(1'b1),
      .BINT15_n(1'b1),
      .POWSENSE_n(1'b1),
      .SEMRQ_n_IN(1'b1),
      .BINPUT_n_IN(1'b1),
      .BDAP_n_IN(1'b1),
      .BDRY_n_IN(1'b1),
      .BAPR_n_IN(1'b1),

      .BD_23_0_n_IN(bd_n),

      .INR_7_0(8'h00),
      .EBUS(1'b0),
      .SEL5MS_n(1'b1),
      .OSCCL_n(1'b1),
      .OC_1_0(2'b00),
      .XTR(1'b0),
      .LOCK_n(1'b1),
      .CONSOLE_n(1'b1),
      .SWMCL_n(1'b1),
      .EAUTO_n(1'b1),
      .RXD(1'b1),
      .SW1_CONSOLE(1'b0),
      .SEL_TESTMUX(3'b000),
      .BAUD_RATE_SWITCH(4'b0000)
      // the nd_storage device port only exists under ND_STORAGE_PORT, which
      // this test does not define, so it is not connected here
  );

  // The five bits the bank decode actually receives (ND3202D.v:533).
  wire [4:0] tap_n = DUT.s_ram_bd_23_19_n;

  //! Present a physical WORD address on the bus and check the decode tap
  //! carries its bits 23:19. `expect_bank` is the bank PAL_44445B /
  //! PAL_44446B select from those bits, named for the failure message.
  task check_addr(input [23:0] addr, input [8*6-1:0] expect_bank);
    reg [4:0] want;
    begin
      bd_n = ~addr;               // the master pulls the lines low
      #40;
      want = addr[23:19];
      checks = checks + 1;
      if (tap_n !== ~want) begin
        errors = errors + 1;
        $display("FAIL addr=%06o (%s): decode tap saw BD23_19 = %b, expected %b",
                 addr, expect_bank, ~tap_n, want);
        if (tap_n === 5'b11111)
          $display("     the tap is idle-high - it is reading the side of the");
          $display("     transceiver THIS BOARD drives, not the bus (the 24-AUG bug)");
      end else begin
        $display("ok   addr=%06o (%s): decode tap saw BD23_19 = %b",
                 addr, expect_bank, ~tap_n);
      end
      bd_n = 24'hFFFFFF;          // release
      #20;
    end
  endtask

  initial begin
    $display("=== BD -> memory bank decode (ND3202D.v:533 regression) ===");
    #50 sys_rst_n = 1'b1;
    #200;

    // Physical page 2040 = {BANK2, row 1016}: the page SINTRAN's segment load
    // targeted on the Tang. Word address = 2040 * 1024. Bit 20 set, 21 clear.
    check_addr(24'o07740000, "BANK2");

    // Physical page 1016 = {BANK0, row 1016}: where the data actually landed
    // before the fix. Bits 21 and 20 both clear.
    check_addr(24'o03740000, "BANK0");

    // Page 3064 = {BANK1, row 1016}: bit 21 set, bit 20 clear.
    check_addr(24'o13740000, "BANK1");

    // A low address in BANK0, and one with the high bits set, to prove the tap
    // is not simply passing a constant.
    check_addr(24'o00000000, "BANK0");
    check_addr(24'o77740000, "high");

    $display("--- %0d checks, %0d failures ---", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else             $display("TB_RESULT: FAIL (%0d of %0d checks failed)", errors, checks);
    $finish;
  end

endmodule
