/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_CLR   (clear-control: CLRQ_15_0 generation, schematic p.82)                     **
**                                                                                               **
** DUT contract (derived directly from CGA_INTR_CNTLR_CLR.v + its 16 CLRBIT instances):           **
**   Each CLRBIT computes  BIT = (J & K) | (J & DATA) | (K & X0 & X1 & X2)                         **
**   The three X lines per instance one-hot-select the addressed bit-within-group:                **
**     bits 0-7  use group key K=LOK and address LX_2_0 :  Xsel_b = (LX_2_0 == b)                  **
**     bits 8-15 use group key K=HIK and address HX_2_0 :  Xsel_(8+j) = (HX_2_0 == j)             **
**   DATA source: bit i in 0..7 = DIN_7_0[i];  bit 8+j = DIN_15_8[j].                              **
**                                                                                               **
**   => independent golden, per bit i:                                                            **
**        K   = (i<8) ? LOK : HIK                                                                  **
**        idx = i & 7                                                                             **
**        Xsel= ((i<8?LX:HX) == idx)                                                              **
**        DATA= (i<8) ? DIN_7_0[i] : DIN_15_8[i-8]                                                 **
**        CLRQ[i] = (J & K) | (J & DATA) | (K & Xsel)                                              **
**                                                                                               **
**   Semantics this pins down:                                                                    **
**     - K & Xsel clears EXACTLY the addressed bit of the group (neighbors untouched).            **
**     - J & K clears the WHOLE group (broadcast) regardless of address.                          **
**     - J & DATA clears bits selected by the data word (per-bit clear).                          **
**   HX_2_0_N / LX_2_0_N are driven as the true complements of HX_2_0 / LX_2_0.                    **
**                                                                                               **
** Self-checking: golden computed INDEPENDENTLY. Sweeps J x LOK x HIK x LX(0..7) x HX(0..7)        **
**   = 512 addressing combos, each crossed with 8 DATA patterns (zeros, ones, walking-1,          **
**   walking-0, alt, addressed-bit-only). Whole 16-bit CLRQ compared each step. Also an           **
**   explicit "no neighbor clobber" assertion: with J=0, only the single addressed bit clears.    **
**   Prints "TB_RESULT: PASS/FAIL".                                                               **
**                                                                                               **
** -DTEETH_TEST perturbs the golden address decode (idx+1 instead of idx) -> the addressed        **
**   clear lands on the wrong (neighbor) bit -> the tb must report FAIL.                           **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_clr -y Shared/logisim -y Shared/support -y Shared/ndlib \          **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_CLR.v \                                          **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_CLR_CLRBIT.v \                                   **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_CLR_tb.v && vvp /tmp/tb_clr                          **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_CLR_tb;

  reg        HIK, J, LOK;
  reg  [2:0] HX_2_0, LX_2_0;
  reg  [7:0] DIN_15_8, DIN_7_0;
  wire [2:0] HX_2_0_N = ~HX_2_0;
  wire [2:0] LX_2_0_N = ~LX_2_0;
  wire [15:0] CLRQ_15_0;

  CGA_INTR_CNTLR_CLR dut (
      .HIK(HIK), .J(J), .LOK(LOK),
      .HX_2_0_N(HX_2_0_N), .HX_2_0(HX_2_0),
      .LX_2_0_N(LX_2_0_N), .LX_2_0(LX_2_0),
      .DIN_15_8(DIN_15_8), .DIN_7_0(DIN_7_0),
      .CLRQ_15_0(CLRQ_15_0)
  );

  integer errors = 0;
  integer checks = 0;

  // independent golden for one bit
  function golden_bit(input integer i, input jj, input lok, input hik,
                      input [2:0] lx, input [2:0] hx,
                      input [7:0] din_lo, input [7:0] din_hi);
    reg kk, dat, xsel;
    integer idx;
    begin
      kk  = (i < 8) ? lok : hik;
      idx = i & 3'h7;
`ifdef TEETH_TEST
      xsel = ((i < 8) ? lx : hx) == ((idx + 1) & 3'h7);   // TEETH: off-by-one decode
`else
      xsel = ((i < 8) ? lx : hx) == idx[2:0];
`endif
      dat = (i < 8) ? din_lo[i] : din_hi[i-8];
      golden_bit = (jj & kk) | (jj & dat) | (kk & xsel);
    end
  endfunction

  function [15:0] golden(input jj, input lok, input hik,
                         input [2:0] lx, input [2:0] hx,
                         input [7:0] din_lo, input [7:0] din_hi);
    integer i;
    begin
      for (i = 0; i < 16; i = i + 1)
        golden[i] = golden_bit(i, jj, lok, hik, lx, hx, din_lo, din_hi);
    end
  endfunction

  reg [15:0] exp;

  task do_check(input [127:0] tag);
    begin
      #1;
      exp    = golden(J, LOK, HIK, LX_2_0, HX_2_0, DIN_7_0, DIN_15_8);
      checks = checks + 1;
      if (CLRQ_15_0 !== exp) begin
        errors = errors + 1;
        $display("FAIL[%0s] J=%b LOK=%b HIK=%b LX=%0d HX=%0d DIN=%04h : CLRQ exp=%016b got=%016b",
                 tag, J, LOK, HIK, LX_2_0, HX_2_0, {DIN_15_8, DIN_7_0}, exp, CLRQ_15_0);
      end
    end
  endtask

  integer jv, lk, hk, lxi, hxi, dp;
  reg [7:0] dlo, dhi;

  task set_data(input integer pat);
    begin
      case (pat)
        0: begin dlo = 8'h00; dhi = 8'h00; end
        1: begin dlo = 8'hFF; dhi = 8'hFF; end
        2: begin dlo = 8'h01; dhi = 8'h80; end          // walking-1 ends
        3: begin dlo = 8'hFE; dhi = 8'h7F; end          // walking-0 ends
        4: begin dlo = 8'hAA; dhi = 8'h55; end          // alternating
        5: begin dlo = 8'h55; dhi = 8'hAA; end
        6: begin dlo = 8'h3C; dhi = 8'hC3; end
        default: begin dlo = 8'h5A; dhi = 8'hA5; end
      endcase
      DIN_7_0 = dlo; DIN_15_8 = dhi;
    end
  endtask

  // explicit single-bit "no neighbor clobber" assertion, J=0 (address-only clear)
  task check_addr_only;
    integer b, i;
    reg [15:0] e;
    begin
      // LO group: with J=0, LOK=1, HIK=0, DIN=0 -> only bit LX clears (=1), all else 0
      J = 0; LOK = 1; HIK = 0; DIN_7_0 = 0; DIN_15_8 = 0;
      for (b = 0; b < 8; b = b + 1) begin
        LX_2_0 = b[2:0]; HX_2_0 = 3'd0;
        #1;
        e = 16'h0; e[b] = 1'b1;
        checks = checks + 1;
        if (CLRQ_15_0 !== e) begin
          errors = errors + 1;
          $display("FAIL[addr-LO] LX=%0d exp=%016b got=%016b", b, e, CLRQ_15_0);
        end
      end
      // HI group: J=0, HIK=1, LOK=0 -> only bit 8+HX clears
      J = 0; LOK = 0; HIK = 1; DIN_7_0 = 0; DIN_15_8 = 0;
      for (b = 0; b < 8; b = b + 1) begin
        HX_2_0 = b[2:0]; LX_2_0 = 3'd0;
        #1;
        e = 16'h0; e[8+b] = 1'b1;
        checks = checks + 1;
        if (CLRQ_15_0 !== e) begin
          errors = errors + 1;
          $display("FAIL[addr-HI] HX=%0d exp=%016b got=%016b", b, e, CLRQ_15_0);
        end
      end
    end
  endtask

  initial begin
    HIK = 0; J = 0; LOK = 0; HX_2_0 = 0; LX_2_0 = 0; DIN_15_8 = 0; DIN_7_0 = 0;

    // exhaustive addressing sweep x data patterns
    for (jv = 0; jv < 2; jv = jv + 1)
      for (lk = 0; lk < 2; lk = lk + 1)
        for (hk = 0; hk < 2; hk = hk + 1)
          for (lxi = 0; lxi < 8; lxi = lxi + 1)
            for (hxi = 0; hxi < 8; hxi = hxi + 1)
              for (dp = 0; dp < 8; dp = dp + 1) begin
                J = jv[0]; LOK = lk[0]; HIK = hk[0];
                LX_2_0 = lxi[2:0]; HX_2_0 = hxi[2:0];
                set_data(dp);
                do_check("sweep");
              end

    // explicit neighbor-protection assertion
    check_addr_only;

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
