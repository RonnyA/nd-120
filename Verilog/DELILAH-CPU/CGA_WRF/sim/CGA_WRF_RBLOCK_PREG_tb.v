/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA_WRF_RBLOCK_PREG testbench                                         **
**                                                                       **
** Verification of the P / PR program-counter pair (PDF page 62):        **
** 16 MUX31LP source selectors feeding both a clocked register (P, two   **
** R81_EN halves on ALUCLK) and a level latch (PR, two L8 halves on      **
** ALUCLKN).                                                             **
**                                                                       **
** Reference model source: READ FROM THE NETLIST                         **
** (Verilog/DELILAH-CPU/CGA_WRF/circuit/CGA_WRF_RBLOCK_PREG.v plus the   **
** shared MUX31LP.v, R81_EN.v and L8.v). No ND documentation and no      **
** drawing was used.                                                     **
**                                                                       **
** Transcribed model. MUX31LP selects on {B,A} = {WR2, ~XFETCHN} and     **
** drives ZN (inverted); both R81 and L8 are read out on their QxN pins, **
** so the two inversions cancel and the visible behaviour is:            **
**   sel = {WR2, XFETCH} with XFETCH = ~XFETCHN                          **
**     0 -> P[n]        (recirculate: hold)                              **
**     1 -> NLCA_15_0[n]                                                 **
**     2 -> RB_15_0[n]                                                   **
**     3 -> RB_15_0[n]  (D3 is tied to D2 inside MUX31LP - WR2 wins)     **
**   P_15_0  <= mux      on the rising edge of ALUCLK                    **
**   PR_15_0  = mux      while ALUCLKN is high, held when it falls       **
** CHARACTERISED, not judged: WR2 overrides XFETCH because MUX31LP ties  **
** its D3 input to D2. Recorded as read from the shared primitive.       **
**                                                                       **
** Test plan:                                                            **
**   1. walking-one and walking-zero on RB_15_0 with WR2=1 (per-bit RB   **
**      wiring, both register halves 0-7 and 8-15)                       **
**   2. walking-one and walking-zero on NLCA_15_0 with WR2=0, XFETCH=1   **
**      (per-bit NLCA wiring), RB driven with the complement so a        **
**      swapped D1/D2 pin cannot pass                                    **
**   3. recirculate: sel=0 must hold P over several clocks while both    **
**      source buses are driven with changing junk                       **
**   4. WR2 priority: WR2=1 with XFETCH=1 must still take RB             **
**   5. PR transparency: PR follows the mux while ALUCLKN is high        **
**      and freezes when ALUCLKN goes low, with the source bus changing  **
**      underneath it                                                    **
**   6. 256 fixed-seed LFSR steps, all inputs random                     **
**                                                                       **
** TWO independent build switches touch this module:                     **
**   FPGA_FF_MODE          - R81_EN becomes a sysclk+ALUCLK_EN capture   **
**   USE_TRANSPARENT_LATCHES - L8 becomes a true transparent latch       **
** The Makefile target test-wrf-preg runs all four combinations and all  **
** four must print PASS. The stimulus deliberately holds every input     **
** stable for a whole sysclk period before ALUCLKN falls, so the two L8  **
** flavours must agree on the held value.                                **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_WRF/sim && make test-wrf-preg            **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_WRF_RBLOCK_PREG_tb;

  reg         sysclk = 0;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg         ALUCLKN = 1;
  reg  [15:0] NLCA_15_0 = 0;
  reg  [15:0] RB_15_0 = 0;
  reg         WR2 = 1;
  reg         XFETCHN = 1;

  wire [15:0] PR_15_0;
  wire [15:0] P_15_0;

  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [31:0] lfsr;

  reg [15:0] m_p;  // model P register

  CGA_WRF_RBLOCK_PREG dut (
      .sysclk   (sysclk),
      .sys_rst_n(1'b1),
      .ALUCLK_EN(ALUCLK_EN),
      .ALUCLK   (ALUCLK),
      .ALUCLKN  (ALUCLKN),
      .NLCA_15_0(NLCA_15_0),
      .RB_15_0  (RB_15_0),
      .WR2      (WR2),
      .XFETCHN  (XFETCHN),
      .PR_15_0  (PR_15_0),
      .P_15_0   (P_15_0)
  );

  always #5 sysclk = ~sysclk;

  initial begin
    $dumpfile("CGA_WRF_RBLOCK_PREG_tb.vcd");
    $dumpvars(0, CGA_WRF_RBLOCK_PREG_tb);
  end

  // mux value seen by BOTH storage elements
  function [15:0] muxval(input [15:0] p, input [15:0] nlca, input [15:0] rb,
                         input wr2, input xfetchn);
    reg [1:0] sel;
    begin
      sel = {wr2, ~xfetchn};
      case (sel)
        2'd0: muxval = p;
        2'd1: muxval = nlca;
        default: muxval = rb;  // D3 is tied to D2 inside MUX31LP
      endcase
    end
  endfunction

  task chk16(input [255:0] name, input [15:0] got, input [15:0] exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04h exp %04h (WR2=%b XFETCHN=%b RB=%04h NLCA=%04h)",
                 name, got, exp, WR2, XFETCHN, RB_15_0, NLCA_15_0);
      end
    end
  endtask

  // One full ALUCLK phase pair. ALUCLKN is driven as the complement of
  // ALUCLK, which is how the drawing wires it, and every input is held
  // stable for a whole sysclk period before the latch closes.
  task step(input [15:0] rb, input [15:0] nlca, input wr2, input xfetchn,
            input [15:0] junk, input [255:0] name);
    reg [15:0] mv;
    begin
      // --- ALUCLK low phase: latch transparent -----------------------
      RB_15_0   = rb;
      NLCA_15_0 = nlca;
      WR2       = wr2;
      XFETCHN   = xfetchn;
      ALUCLK    = 1'b0;
      ALUCLKN   = 1'b1;
      mv        = muxval(m_p, nlca, rb, wr2, xfetchn);
      repeat (2) @(posedge sysclk);
      #1;
      chk16({name, " PR transparent"}, PR_15_0, mv);

      // --- close the latch, then clock P -----------------------------
      @(negedge sysclk);
      ALUCLKN   = 1'b0;
      ALUCLK_EN = 1'b1;
      @(posedge sysclk);
      #1 ALUCLK = 1'b1;
      @(negedge sysclk);
      ALUCLK_EN = 1'b0;
      m_p = mv;
      #1;
      chk16({name, " P captured"}, P_15_0, m_p);
      chk16({name, " PR held"}, PR_15_0, mv);

      // --- change the source bus while the latch is closed -----------
      RB_15_0   = junk;
      NLCA_15_0 = ~junk;
      #12;
      chk16({name, " PR frozen"}, PR_15_0, mv);
      chk16({name, " P stable"}, P_15_0, m_p);
      RB_15_0   = rb;
      NLCA_15_0 = nlca;
      ALUCLK    = 1'b0;
      #2;
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_WRF_RBLOCK_PREG_tb: FPGA_FF_MODE=1");
`else
    $display("CGA_WRF_RBLOCK_PREG_tb: FPGA_FF_MODE=0");
`endif
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_WRF_RBLOCK_PREG_tb: USE_TRANSPARENT_LATCHES=1");
`else
    $display("CGA_WRF_RBLOCK_PREG_tb: USE_TRANSPARENT_LATCHES=0");
`endif

    // A defining first step through the RB path - the R81/L8 storage has no
    // initial value in latch mode, so nothing is checked against P before it
    // has been written once, and the mux never reads P on this path.
    // Preamble: Shared/logisim/Multiplexer_4.v (inside MUX31LP) uses
    // always @(*) and Icarus does not execute it until an input actually
    // transitions, so a bit whose source never moved stays X. Toggle both
    // source buses once before anything is checked. (Reported as a
    // simulator-visible oddity of the shared mux primitive.)
    RB_15_0 = 16'hFFFF; NLCA_15_0 = 16'hFFFF; #1;
    RB_15_0 = 16'h0000; NLCA_15_0 = 16'h0000; #1;

    m_p = 16'h0000;
    step(16'hA5A5, 16'h0000, 1'b1, 1'b1, 16'h1234, "define via RB");

    // 1. walking one / walking zero on RB (WR2=1)
    for (i = 0; i < 16; i = i + 1)
      step(16'h0001 << i, ~(16'h0001 << i), 1'b1, 1'b1, 16'hFFFF, "walk1 RB");
    for (i = 0; i < 16; i = i + 1)
      step(~(16'h0001 << i), 16'h0001 << i, 1'b1, 1'b0, 16'h0000, "walk0 RB");

    // 2. walking one / walking zero on NLCA (WR2=0, XFETCH=1 -> XFETCHN=0)
    for (i = 0; i < 16; i = i + 1)
      step(~(16'h0001 << i), 16'h0001 << i, 1'b0, 1'b0, 16'hFFFF, "walk1 NLCA");
    for (i = 0; i < 16; i = i + 1)
      step(16'h0001 << i, ~(16'h0001 << i), 1'b0, 1'b0, 16'h0000, "walk0 NLCA");

    // 3. recirculate: sel=0 (WR2=0, XFETCHN=1) must hold P
    step(16'h1357, 16'h0000, 1'b1, 1'b1, 16'h0000, "seed 1357");
    for (i = 0; i < 6; i = i + 1)
      step(16'hFFFF ^ {16{i[0]}}, 16'h5555 ^ {16{i[0]}}, 1'b0, 1'b1, 16'hAAAA,
           "recirculate");

    // 4. WR2 priority over XFETCH (sel=3 must still take RB)
    step(16'h0F0F, 16'hF0F0, 1'b1, 1'b0, 16'h9999, "WR2 wins over XFETCH");
    step(16'hF0F0, 16'h0F0F, 1'b1, 1'b0, 16'h6666, "WR2 wins over XFETCH 2");

    // 5. explicit PR transparency sweep: with ALUCLKN high, retarget the
    //    RB bus several times and PR must follow every time with no clock.
    WR2 = 1'b1; XFETCHN = 1'b1; ALUCLK = 1'b0; ALUCLKN = 1'b1;
    for (i = 0; i < 8; i = i + 1) begin
      RB_15_0 = 16'h0101 * (i + 1);
      #12;
      chk16("PR follows live", PR_15_0, RB_15_0);
      chk16("P untouched while transparent", P_15_0, m_p);
    end

    // 6. pseudo-random soak
    lfsr = 32'h2468ACE0;
    for (i = 0; i < 256; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      step(lfsr[19:4], {lfsr[7:0], lfsr[27:20]}, lfsr[0], lfsr[1], lfsr[31:16],
           "lfsr");
    end

    // steps = 1 + 16*4 + 1 + 6 + 2 + 256 = 330, 5 checks each = 1650
    // plus the transparency sweep 8*2 = 16 -> 1666
    if (errors == 0 && checks == 1666) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 1666 checks)", checks, errors);
    if (errors == 0 && checks == 1666) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
