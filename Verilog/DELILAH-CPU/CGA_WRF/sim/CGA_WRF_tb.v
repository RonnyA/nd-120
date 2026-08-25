/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA_WRF testbench (top level of the Working Register File)            **
**                                                                       **
** Verification of the whole 16-register file (PDF page 59) as seen from **
** its own ports: the LAA/LBA address decoders, the BDEST write-enable   **
** plane, the two read ports A_15_0 / B_15_0, and the three direct       **
** outputs PR_15_0 (P), BR_15_0 (B) and XR_15_0 (X).                     **
**                                                                       **
** Reference model source: READ FROM THE NETLIST                         **
** (CGA_WRF.v, CGA_WRF_RBLOCK.v, CGA_WRF_RBLOCK_DR16.v,                  **
**  CGA_WRF_RBLOCK_LR16.v, CGA_WRF_RBLOCK_PREG.v,                        **
**  CGA_WRF_RBLOCK_SEL16.v and the shared primitives). No ND             **
** documentation was consulted; the 256 s_selK_in_15_0 assignments in    **
** CGA_WRF_RBLOCK.v were checked one by one to be the regular            **
** transpose selK_in[r] = register r, bit K.                             **
**                                                                       **
** Transcribed behaviour:                                                **
**   EA_15_0 = one-hot(LAA_3_0)     (two ND38GLP halves, G = LAA[3])     **
**   EB_15_0 = one-hot(LBA_3_0)                                          **
**   WR_15_0[k] = BDEST & EB[k];  WPN = ~WR_15_0[2]                      **
**   WR3 = WR_15_0[3];  WR7 = WR_15_0[7]                                 **
**   A_15_0 = reg[LAA] , B_15_0 = reg[LBA]   (SEL16 one-hot OR plane;    **
**            with all enables low the plane drives 0, never z)          **
**   registers 0,1,4,5,6,8..15 (DR16): reg <= RB on posedge ALUCLK when  **
**            their WR bit is high                                       **
**   registers 3 and 7 (LR16): R <= (WR ? RB : R) on every posedge       **
**            ALUCLK, and the direct outputs BR_15_0 / XR_15_0 are L8    **
**            latches transparent while (~ALUCLK & WR)                   **
**   register 2 (PREG): written on EVERY posedge ALUCLK from             **
**            sel={WR2,~XFETCHN}: 0 -> hold, 1 -> NLCA, 2 or 3 -> RB     **
**            and PR_15_0 is an L8 latch transparent while ALUCLK is low **
**                                                                       **
** CHARACTERISED, not judged:                                            **
**   - register 0 (named Z in the header comment) is a normal writable   **
**     DR16 here, NOT a hard-wired zero.                                 **
**   - register 2 (P) is clocked on every ALUCLK edge; WR2 only picks    **
**     the source, and WR2=0 with XFETCHN=1 is what makes it hold.       **
**   - MUX31LP ties D3 to D2, so WR2 beats XFETCH.                       **
**                                                                       **
** Test plan:                                                            **
**   1. address-decoder sweep: all 16 x 16 LAA/LBA combinations x BDEST  **
**      0 and 1, checking EA_15_0 one-hot, WPN, WR3 and WR7 (no clock)   **
**   2. per-register per-bit wiring: write a walking one into every bit  **
**      of every one of the 16 registers (256 writes) and after EACH     **
**      write read back ALL 16 registers on both read ports. This is     **
**      what catches a write landing in the wrong register, a read port  **
**      taking the wrong register, or a single crossed bit lane.         **
**   3. P register: walking one through the NLCA path, walking one       **
**      through the RB path, and a recirculate hold with both source     **
**      buses changing underneath                                        **
**   4. PR / BR / XR direct outputs: transparency while their latch      **
**      window is open, and freeze when it closes                        **
**   5. 256 fixed-seed LFSR steps with every input random                **
**                                                                       **
** TWO independent build switches touch this module:                     **
**   FPGA_FF_MODE            - the register captures move to sysclk+EN   **
**   USE_TRANSPARENT_LATCHES - L8 becomes a true transparent latch       **
** The Makefile target test-wrf runs all four combinations and all four  **
** must print PASS. Every input is held stable for a whole sysclk period **
** before a latch window closes, so both L8 flavours must agree.         **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_WRF/sim && make test-wrf                 **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_WRF_tb;

  reg         sysclk = 0;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg         BDEST = 0;
  reg  [ 3:0] LAA_3_0 = 0;
  reg  [ 3:0] LBA_3_0 = 0;
  reg  [15:0] RB_15_0 = 0;
  reg  [15:0] NLCA_15_0 = 0;
  reg         XFETCHN = 1;

  wire [15:0] EA_15_0;
  wire        WPN, WR3, WR7;
  wire [15:0] A_15_0, B_15_0;
  wire [15:0] PR_15_0, BR_15_0, XR_15_0;

  integer errors = 0;
  integer checks = 0;
  integer i, j, k, b;
  reg [31:0] lfsr;

  // ---- model state ----
  reg [15:0] m_reg [0:15];
  reg [15:0] m_pr, m_br, m_xr;

  CGA_WRF dut (
      .sysclk   (sysclk),
      .sys_rst_n(1'b1),
      .ALUCLK_EN(ALUCLK_EN),
      .ALUCLK   (ALUCLK),
      .BDEST    (BDEST),
      .LAA_3_0  (LAA_3_0),
      .LBA_3_0  (LBA_3_0),
      .RB_15_0  (RB_15_0),
      .NLCA_15_0(NLCA_15_0),
      .XFETCHN  (XFETCHN),
      .EA_15_0  (EA_15_0),
      .WPN      (WPN),
      .WR3      (WR3),
      .WR7      (WR7),
      .A_15_0   (A_15_0),
      .B_15_0   (B_15_0),
      .PR_15_0  (PR_15_0),
      .BR_15_0  (BR_15_0),
      .XR_15_0  (XR_15_0)
  );

  always #5 sysclk = ~sysclk;

  initial begin
    $dumpfile("CGA_WRF_tb.vcd");
    $dumpvars(0, CGA_WRF_tb);
  end

  task chk16(input [255:0] name, input [15:0] got, input [15:0] exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04h exp %04h (LAA=%0d LBA=%0d BDEST=%b RB=%04h)",
                 name, got, exp, LAA_3_0, LBA_3_0, BDEST, RB_15_0);
      end
    end
  endtask

  task chk1(input [255:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %b exp %b (LAA=%0d LBA=%0d BDEST=%b)",
                 name, got, exp, LAA_3_0, LBA_3_0, BDEST);
      end
    end
  endtask

  // P input mux, transcribed from MUX31LP inside CGA_WRF_RBLOCK_PREG
  function [15:0] pmux(input [15:0] p, input [15:0] nlca, input [15:0] rb,
                       input wr2, input xfetchn);
    reg [1:0] sel;
    begin
      sel = {wr2, ~xfetchn};
      case (sel)
        2'd0: pmux = p;
        2'd1: pmux = nlca;
        default: pmux = rb;
      endcase
    end
  endfunction

  // ---- one ALUCLK rising edge, valid in BOTH register build modes ----
  task clk_rise;
    reg [15:0] pnext;
    integer kk;   // task-local: must NOT reuse the shared loop counters
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1'b1;
      @(posedge sysclk);
      #1 ALUCLK = 1'b1;
      @(negedge sysclk);
      ALUCLK_EN = 1'b0;
      // model: every register clocks here
      pnext = pmux(m_reg[2], NLCA_15_0, RB_15_0, BDEST & (LBA_3_0 == 4'd2), XFETCHN);
      for (kk = 0; kk < 16; kk = kk + 1)
        if (BDEST && (LBA_3_0 == kk[3:0])) m_reg[kk] = RB_15_0;
      m_reg[2] = pnext;
      #1;
    end
  endtask

  // Open the low phase: hold the inputs for a whole sysclk period so the two
  // L8 flavours capture the same value, and update the transparent outputs.
  task settle_low;
    begin
      ALUCLK = 1'b0;
      repeat (2) @(posedge sysclk);
      #1;
      m_pr = pmux(m_reg[2], NLCA_15_0, RB_15_0, BDEST & (LBA_3_0 == 4'd2), XFETCHN);
      if (BDEST && (LBA_3_0 == 4'd3)) m_br = RB_15_0;
      if (BDEST && (LBA_3_0 == 4'd7)) m_xr = RB_15_0;
    end
  endtask

  // Write one register (no checks - the checks are the read-back sweep)
  task write_reg(input [3:0] addr, input [15:0] data);
    begin
      BDEST     = 1'b1;
      LBA_3_0   = addr;
      RB_15_0   = data;
      XFETCHN   = 1'b1;  // P holds unless it is the addressed register
      settle_low;
      clk_rise;
    end
  endtask

  // Read every register on both ports. 32 checks. No clock, BDEST low so no
  // latch window can open underneath.
  task read_sweep;
    integer r;
    begin
      BDEST  = 1'b0;
      ALUCLK = 1'b0;
      for (r = 0; r < 16; r = r + 1) begin
        LAA_3_0 = r[3:0];
        LBA_3_0 = 4'd15 - r[3:0];
        #4;
        chk16("read A", A_15_0, m_reg[r]);
        chk16("read B", B_15_0, m_reg[15-r]);
      end
    end
  endtask

  function [15:0] onehot(input [3:0] a);
    begin
      onehot = 16'h0001 << a;
    end
  endfunction

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_WRF_tb: FPGA_FF_MODE=1");
`else
    $display("CGA_WRF_tb: FPGA_FF_MODE=0");
`endif
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_WRF_tb: USE_TRANSPARENT_LATCHES=1");
`else
    $display("CGA_WRF_tb: USE_TRANSPARENT_LATCHES=0");
`endif

    // Preamble: the shared Multiplexer_2/_4/_8 and Decoder_8 primitives use
    // always @(*), and Icarus does not execute those until an input actually
    // transitions - a lane whose source never moved would read X. Wiggle
    // every bus once. (Reported as a simulator-visible oddity of the shared
    // primitives, not of this module.)
    RB_15_0 = 16'hFFFF; NLCA_15_0 = 16'hFFFF; LAA_3_0 = 4'hF; LBA_3_0 = 4'hF;
    BDEST = 1'b1; XFETCHN = 1'b0; #1;
    RB_15_0 = 16'h0000; NLCA_15_0 = 16'h0000; LAA_3_0 = 4'h0; LBA_3_0 = 4'h0;
    BDEST = 1'b0; XFETCHN = 1'b1; #1;

    // Bring every storage element to a known value (no checks yet: the R81
    // and L8 primitives have no initial value in latch mode).
    for (k = 0; k < 16; k = k + 1) write_reg(k[3:0], 16'h0000);
    for (k = 0; k < 16; k = k + 1) m_reg[k] = 16'h0000;
    m_pr = 16'h0000; m_br = 16'h0000; m_xr = 16'h0000;

    // ---- 1. address decoder sweep: 16*16*2 vectors, 4 checks each ----
    ALUCLK = 1'b1;  // keep every latch window shut
    for (i = 0; i < 16; i = i + 1)
      for (j = 0; j < 16; j = j + 1)
        for (b = 0; b < 2; b = b + 1) begin
          LAA_3_0 = i[3:0];
          LBA_3_0 = j[3:0];
          BDEST   = b[0];
          #4;
          chk16("EA one-hot", EA_15_0, onehot(i[3:0]));
          chk1("WPN", WPN, ~(b[0] & (j == 2)));
          chk1("WR3", WR3, b[0] & (j == 3));
          chk1("WR7", WR7, b[0] & (j == 7));
        end
    ALUCLK = 1'b0;

    // ---- 2. per-register per-bit wiring: 256 writes, 32 checks each ----
    for (k = 0; k < 16; k = k + 1)
      for (b = 0; b < 16; b = b + 1) begin
        write_reg(k[3:0], 16'h0001 << b);
        read_sweep;
      end

    // ---- 3. P register source paths ----
    // NLCA path: WR2=0 (BDEST low) and XFETCHN=0
    for (b = 0; b < 16; b = b + 1) begin
      BDEST     = 1'b0;
      LBA_3_0   = 4'd2;
      XFETCHN   = 1'b0;
      NLCA_15_0 = 16'h0001 << b;
      RB_15_0   = ~(16'h0001 << b);
      settle_low;
      chk16("PR follows NLCA", PR_15_0, m_pr);
      clk_rise;
      LAA_3_0 = 4'd2;
      #4;
      chk16("P via NLCA", A_15_0, m_reg[2]);
    end
    // RB path: WR2=1 with XFETCHN=0 as well - WR2 must win
    for (b = 0; b < 16; b = b + 1) begin
      BDEST     = 1'b1;
      LBA_3_0   = 4'd2;
      XFETCHN   = 1'b0;
      RB_15_0   = 16'h0001 << b;
      NLCA_15_0 = ~(16'h0001 << b);
      settle_low;
      chk16("PR follows RB", PR_15_0, m_pr);
      clk_rise;
      LAA_3_0 = 4'd2;
      #4;
      chk16("P via RB, WR2 wins", A_15_0, m_reg[2]);
    end
    // recirculate: BDEST=0, XFETCHN=1 -> P must hold across 6 clocks
    for (b = 0; b < 6; b = b + 1) begin
      BDEST     = 1'b0;
      LBA_3_0   = 4'd2;
      XFETCHN   = 1'b1;
      RB_15_0   = 16'hAAAA ^ {16{b[0]}};
      NLCA_15_0 = 16'h5555 ^ {16{b[0]}};
      settle_low;
      chk16("PR holds P", PR_15_0, m_pr);
      clk_rise;
      LAA_3_0 = 4'd2;
      #4;
      chk16("P recirculates", A_15_0, m_reg[2]);
    end

    // ---- 4. direct outputs PR / BR / XR: window open then shut ----
    // B register: BDEST=1, LBA=3, ALUCLK low -> BR must track RB live
    BDEST = 1'b1; LBA_3_0 = 4'd3; XFETCHN = 1'b1; ALUCLK = 1'b0;
    for (b = 0; b < 4; b = b + 1) begin
      RB_15_0 = 16'h1111 * (b + 1);
      repeat (2) @(posedge sysclk);
      #1;
      m_br = RB_15_0;
      chk16("BR tracks RB", BR_15_0, m_br);
    end
    clk_rise;                 // ALUCLK high: window shut
    RB_15_0 = 16'hDEAD; #12;
    chk16("BR frozen while ALUCLK high", BR_15_0, m_br);
    // Put RB back to the latched value BEFORE reopening the window, so the
    // B latch cannot pick up junk while ALUCLK falls.
    RB_15_0 = 16'h1111 * 4; #4; ALUCLK = 1'b0; #4;
    // X register: same, LBA=7. NOTE the #4 after retargeting LBA: in
    // USE_TRANSPARENT_LATCHES mode L8 is a real level-sensitive latch, so
    // changing LBA (which closes the B window) and RB in the SAME delta
    // is a zero-delay race - the latch can grab the new RB before its
    // enable has fallen. Real hardware has gate delay here; the stimulus
    // separates the two events instead of relying on delta ordering.
    BDEST = 1'b1; LBA_3_0 = 4'd7; #4;
    for (b = 0; b < 4; b = b + 1) begin
      RB_15_0 = 16'h2222 * (b + 1);
      repeat (2) @(posedge sysclk);
      #1;
      m_xr = RB_15_0;
      chk16("XR tracks RB", XR_15_0, m_xr);
    end
    clk_rise;
    RB_15_0 = 16'hBEEF; #12;
    chk16("XR frozen while ALUCLK high", XR_15_0, m_xr);
    // BR and XR must NOT move while LBA points at some other register.
    // Retarget LBA and RB while ALUCLK is still HIGH (both windows shut),
    // then reopen ALUCLK - otherwise the falling edge would open the X
    // window for one delta with the junk RB still applied.
    BDEST = 1'b1; LBA_3_0 = 4'd5; RB_15_0 = 16'h0F0F; #4;
    ALUCLK = 1'b0; #20;
    chk16("BR untouched by another LBA", BR_15_0, m_br);
    chk16("XR untouched by another LBA", XR_15_0, m_xr);

    // ---- 5. pseudo-random soak ----
    lfsr = 32'h13572468;
    for (i = 0; i < 256; i = i + 1) begin
      lfsr      = lfsr_next(lfsr);
      BDEST     = lfsr[0];
      LBA_3_0   = lfsr[4:1];
      LAA_3_0   = lfsr[8:5];
      XFETCHN   = lfsr[9];
      RB_15_0   = lfsr[25:10];
      NLCA_15_0 = {lfsr[7:0], lfsr[31:24]};
      settle_low;
      chk16("rnd PR", PR_15_0, m_pr);
      clk_rise;
      chk16("rnd A", A_15_0, m_reg[LAA_3_0]);
      chk16("rnd B", B_15_0, m_reg[LBA_3_0]);
      chk1("rnd WPN", WPN, ~(BDEST & (LBA_3_0 == 4'd2)));
    end

    // checks = 512*4 + 256*32 + (16+16+6)*2 + (4+1+4+1+2) + 256*4
    //        = 2048 + 8192 + 76 + 12 + 1024 = 11352
    if (errors == 0 && checks == 11352) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 11352 checks)", checks, errors);
    if (errors == 0 && checks == 11352) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
