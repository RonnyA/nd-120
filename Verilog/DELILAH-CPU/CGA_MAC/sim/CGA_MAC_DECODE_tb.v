/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_DECODE testbench                                              **
**                                                                       **
** Exhaustive verification of the MAC request decoder:                   **
**                                                                       **
**  1. All 512 input combinations {WR7,WR3,CSMIS[1:0],CSCOMM[4:0]}       **
**     checked against a golden table of the 13 combinational outputs    **
**     (table generated from the decode equations after the 31-JUL-2026  **
**     GATES_5 fix; SPT/SAPT trees verified term-by-term against the     **
**     DELILAH schematic, CGA/MAC/DECODE sheet 1 of 4).                  **
**  2. Invariant: SPT (=~SPTN) and SAPT are never asserted together on   **
**     ANY input combination. This is the Issue-C regression tooth: the  **
**     pre-fix RTL (GATES_5 input3 = s_cscomm_4) asserts both on         **
**     RDRQ,APT / WRRQ,APT (CSCOMM 0o34/0o35, CSMIS=1), which makes the **
**     PTSEL JK (J=SPT, K=SAPT) toggle instead of selecting APT and      **
**     drops the destination page-boundary word of MOVEW APT ==> APT.    **
**  3. Direct request-code checks: RDRQ/WRRQ with CSMIS=1 (APT) must     **
**     assert SAPT only; with CSMIS=0 (PT) must assert SPT only.         **
**  4. The MCLK-registered outputs LLDEXM/LLDSEG/LLDPCR: correct decode  **
**     combination loads the strobe, a non-matching combination clears   **
**     it, the value holds without a clock, and LCSN=0 blocks all three. **
**     Compile once plain (latch/CP mode) and once with -DFPGA_FF_MODE   **
**     (sysclk+MCLK_EN capture) - the Makefile target runs both.         **
**                                                                       **
** Output vector bit order (bit 12 down to 0):                           **
**   {ADDSEL,CDS,CDSEL,EXMN,HOLD,NLCASEL,PB,PLCA,PRB,PSEL,PX,SAPT,SPTN}  **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_DECODE_tb;

  reg        sysclk = 0;
  reg        MCLK_EN = 0;
  reg        MCLK = 0;
  reg  [4:0] CSCOMM_4_0 = 0;
  reg  [1:0] CSMIS_1_0 = 0;
  reg        LCSN = 1;
  reg        WR3 = 0;
  reg        WR7 = 0;

  wire ADDSEL, CDS, CDSEL, EXMN, HOLD, LLDEXM, LLDPCR, LLDSEG;
  wire NLCASEL, PB, PLCA, PRB, PSEL, PX, SAPT, SPTN;

  integer errors = 0;
  integer checks = 0;
  integer idx;
  reg [12:0] expected;
  wire [12:0] got = {ADDSEL, CDS, CDSEL, EXMN, HOLD, NLCASEL, PB, PLCA,
                     PRB, PSEL, PX, SAPT, SPTN};

  CGA_MAC_DECODE dut (
      .sysclk(sysclk),
      .MCLK_EN(MCLK_EN),
      .CSCOMM_4_0(CSCOMM_4_0),
      .CSMIS_1_0(CSMIS_1_0),
      .LCSN(LCSN),
      .MCLK(MCLK),
      .WR3(WR3),
      .WR7(WR7),
      .ADDSEL(ADDSEL), .CDS(CDS), .CDSEL(CDSEL), .EXMN(EXMN), .HOLD(HOLD),
      .LLDEXM(LLDEXM), .LLDPCR(LLDPCR), .LLDSEG(LLDSEG), .NLCASEL(NLCASEL),
      .PB(PB), .PLCA(PLCA), .PRB(PRB), .PSEL(PSEL), .PX(PX),
      .SAPT(SAPT), .SPTN(SPTN)
  );

  always #5 sysclk = ~sysclk;

  // One MCLK event, valid in BOTH build modes: the EN-mode register captures
  // at posedge sysclk while MCLK_EN=1; the CP-mode register captures at the
  // posedge of MCLK raised just after the same sysclk edge (inputs stable).
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK   = 0;
      MCLK_EN = 0;
    end
  endtask

  task check_bit(input val, input exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (val !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %b expected %b (WR7=%b WR3=%b CSMIS=%o CSCOMM=%02o)",
                 name, val, exp, WR7, WR3, CSMIS_1_0, CSCOMM_4_0);
      end
    end
  endtask

  // Golden table, index = {WR7,WR3,CSMIS[1:0],CSCOMM[4:0]}
  function [12:0] golden(input [8:0] i);
    begin
      case (i)
      9'o000: golden = 13'o05441;

      9'o001: golden = 13'o05441;

      9'o002: golden = 13'o05441;

      9'o003: golden = 13'o05441;

      9'o004: golden = 13'o05441;

      9'o005: golden = 13'o05421;

      9'o006: golden = 13'o05441;

      9'o007: golden = 13'o05421;

      9'o010: golden = 13'o05441;

      9'o011: golden = 13'o05421;

      9'o012: golden = 13'o05441;

      9'o013: golden = 13'o05421;

      9'o014: golden = 13'o05441;

      9'o015: golden = 13'o05421;

      9'o016: golden = 13'o05441;

      9'o017: golden = 13'o05421;

      9'o020: golden = 13'o07041;

      9'o021: golden = 13'o07041;

      9'o022: golden = 13'o15040;

      9'o023: golden = 13'o15040;

      9'o024: golden = 13'o05050;

      9'o025: golden = 13'o05030;

      9'o026: golden = 13'o15040;

      9'o027: golden = 13'o15020;

      9'o030: golden = 13'o15040;

      9'o031: golden = 13'o15023;

      9'o032: golden = 13'o15040;

      9'o033: golden = 13'o15023;

      9'o034: golden = 13'o07040;

      9'o035: golden = 13'o07020;

      9'o036: golden = 13'o07041;

      9'o037: golden = 13'o07021;

      9'o040: golden = 13'o05501;

      9'o041: golden = 13'o05441;

      9'o042: golden = 13'o05501;

      9'o043: golden = 13'o05441;

      9'o044: golden = 13'o05501;

      9'o045: golden = 13'o01405;

      9'o046: golden = 13'o05501;

      9'o047: golden = 13'o01405;

      9'o050: golden = 13'o05501;

      9'o051: golden = 13'o01405;

      9'o052: golden = 13'o05501;

      9'o053: golden = 13'o01405;

      9'o054: golden = 13'o05501;

      9'o055: golden = 13'o01405;

      9'o056: golden = 13'o05501;

      9'o057: golden = 13'o01405;

      9'o060: golden = 13'o07101;

      9'o061: golden = 13'o07041;

      9'o062: golden = 13'o15103;

      9'o063: golden = 13'o15041;

      9'o064: golden = 13'o05110;

      9'o065: golden = 13'o01014;

      9'o066: golden = 13'o15100;

      9'o067: golden = 13'o11004;

      9'o070: golden = 13'o15103;

      9'o071: golden = 13'o11007;

      9'o072: golden = 13'o15103;

      9'o073: golden = 13'o11007;

      9'o074: golden = 13'o07103;

      9'o075: golden = 13'o03007;

      9'o076: golden = 13'o07101;

      9'o077: golden = 13'o03005;

      9'o100: golden = 13'o05441;

      9'o101: golden = 13'o05441;

      9'o102: golden = 13'o05441;

      9'o103: golden = 13'o05441;

      9'o104: golden = 13'o05441;

      9'o105: golden = 13'o05421;

      9'o106: golden = 13'o05441;

      9'o107: golden = 13'o05421;

      9'o110: golden = 13'o05441;

      9'o111: golden = 13'o05421;

      9'o112: golden = 13'o05441;

      9'o113: golden = 13'o05421;

      9'o114: golden = 13'o05441;

      9'o115: golden = 13'o05421;

      9'o116: golden = 13'o05441;

      9'o117: golden = 13'o05421;

      9'o120: golden = 13'o07041;

      9'o121: golden = 13'o07041;

      9'o122: golden = 13'o05440;

      9'o123: golden = 13'o15041;

      9'o124: golden = 13'o05050;

      9'o125: golden = 13'o05030;

      9'o126: golden = 13'o07040;

      9'o127: golden = 13'o05030;

      9'o130: golden = 13'o07043;

      9'o131: golden = 13'o05221;

      9'o132: golden = 13'o07043;

      9'o133: golden = 13'o05421;

      9'o134: golden = 13'o07041;

      9'o135: golden = 13'o07021;

      9'o136: golden = 13'o07041;

      9'o137: golden = 13'o07021;

      9'o140: golden = 13'o05405;

      9'o141: golden = 13'o05441;

      9'o142: golden = 13'o05405;

      9'o143: golden = 13'o05441;

      9'o144: golden = 13'o05405;

      9'o145: golden = 13'o01405;

      9'o146: golden = 13'o05405;

      9'o147: golden = 13'o01405;

      9'o150: golden = 13'o05405;

      9'o151: golden = 13'o01405;

      9'o152: golden = 13'o05405;

      9'o153: golden = 13'o01405;

      9'o154: golden = 13'o05405;

      9'o155: golden = 13'o01405;

      9'o156: golden = 13'o05405;

      9'o157: golden = 13'o01405;

      9'o160: golden = 13'o07005;

      9'o161: golden = 13'o07041;

      9'o162: golden = 13'o05014;

      9'o163: golden = 13'o15040;

      9'o164: golden = 13'o05014;

      9'o165: golden = 13'o01014;

      9'o166: golden = 13'o15004;

      9'o167: golden = 13'o01014;

      9'o170: golden = 13'o15007;

      9'o171: golden = 13'o01205;

      9'o172: golden = 13'o15007;

      9'o173: golden = 13'o01205;

      9'o174: golden = 13'o06005;

      9'o175: golden = 13'o02005;

      9'o176: golden = 13'o07005;

      9'o177: golden = 13'o03005;

      9'o200: golden = 13'o05441;

      9'o201: golden = 13'o05441;

      9'o202: golden = 13'o05441;

      9'o203: golden = 13'o05441;

      9'o204: golden = 13'o05441;

      9'o205: golden = 13'o05421;

      9'o206: golden = 13'o05441;

      9'o207: golden = 13'o05421;

      9'o210: golden = 13'o05441;

      9'o211: golden = 13'o05421;

      9'o212: golden = 13'o05441;

      9'o213: golden = 13'o05421;

      9'o214: golden = 13'o05441;

      9'o215: golden = 13'o05421;

      9'o216: golden = 13'o05441;

      9'o217: golden = 13'o05421;

      9'o220: golden = 13'o07041;

      9'o221: golden = 13'o07041;

      9'o222: golden = 13'o15040;

      9'o223: golden = 13'o15040;

      9'o224: golden = 13'o05050;

      9'o225: golden = 13'o05030;

      9'o226: golden = 13'o15040;

      9'o227: golden = 13'o15020;

      9'o230: golden = 13'o15040;

      9'o231: golden = 13'o15023;

      9'o232: golden = 13'o15040;

      9'o233: golden = 13'o15023;

      9'o234: golden = 13'o07040;

      9'o235: golden = 13'o07020;

      9'o236: golden = 13'o07041;

      9'o237: golden = 13'o07021;

      9'o240: golden = 13'o05421;

      9'o241: golden = 13'o05441;

      9'o242: golden = 13'o05421;

      9'o243: golden = 13'o05441;

      9'o244: golden = 13'o05421;

      9'o245: golden = 13'o01405;

      9'o246: golden = 13'o05421;

      9'o247: golden = 13'o01405;

      9'o250: golden = 13'o05421;

      9'o251: golden = 13'o01405;

      9'o252: golden = 13'o05421;

      9'o253: golden = 13'o01405;

      9'o254: golden = 13'o05421;

      9'o255: golden = 13'o01405;

      9'o256: golden = 13'o05421;

      9'o257: golden = 13'o01405;

      9'o260: golden = 13'o07021;

      9'o261: golden = 13'o07041;

      9'o262: golden = 13'o15023;

      9'o263: golden = 13'o15041;

      9'o264: golden = 13'o05030;

      9'o265: golden = 13'o01014;

      9'o266: golden = 13'o15020;

      9'o267: golden = 13'o11004;

      9'o270: golden = 13'o15023;

      9'o271: golden = 13'o11007;

      9'o272: golden = 13'o15023;

      9'o273: golden = 13'o11007;

      9'o274: golden = 13'o07023;

      9'o275: golden = 13'o03007;

      9'o276: golden = 13'o07021;

      9'o277: golden = 13'o03005;

      9'o300: golden = 13'o05441;

      9'o301: golden = 13'o05441;

      9'o302: golden = 13'o05441;

      9'o303: golden = 13'o05441;

      9'o304: golden = 13'o05441;

      9'o305: golden = 13'o05421;

      9'o306: golden = 13'o05441;

      9'o307: golden = 13'o05421;

      9'o310: golden = 13'o05441;

      9'o311: golden = 13'o05421;

      9'o312: golden = 13'o05441;

      9'o313: golden = 13'o05421;

      9'o314: golden = 13'o05441;

      9'o315: golden = 13'o05421;

      9'o316: golden = 13'o05441;

      9'o317: golden = 13'o05421;

      9'o320: golden = 13'o07041;

      9'o321: golden = 13'o07041;

      9'o322: golden = 13'o05440;

      9'o323: golden = 13'o15041;

      9'o324: golden = 13'o05050;

      9'o325: golden = 13'o05030;

      9'o326: golden = 13'o07040;

      9'o327: golden = 13'o05030;

      9'o330: golden = 13'o07043;

      9'o331: golden = 13'o05221;

      9'o332: golden = 13'o07043;

      9'o333: golden = 13'o05421;

      9'o334: golden = 13'o07041;

      9'o335: golden = 13'o07021;

      9'o336: golden = 13'o07041;

      9'o337: golden = 13'o07021;

      9'o340: golden = 13'o05405;

      9'o341: golden = 13'o05441;

      9'o342: golden = 13'o05405;

      9'o343: golden = 13'o05441;

      9'o344: golden = 13'o05405;

      9'o345: golden = 13'o01405;

      9'o346: golden = 13'o05405;

      9'o347: golden = 13'o01405;

      9'o350: golden = 13'o05405;

      9'o351: golden = 13'o01405;

      9'o352: golden = 13'o05405;

      9'o353: golden = 13'o01405;

      9'o354: golden = 13'o05405;

      9'o355: golden = 13'o01405;

      9'o356: golden = 13'o05405;

      9'o357: golden = 13'o01405;

      9'o360: golden = 13'o07005;

      9'o361: golden = 13'o07041;

      9'o362: golden = 13'o05014;

      9'o363: golden = 13'o15040;

      9'o364: golden = 13'o05014;

      9'o365: golden = 13'o01014;

      9'o366: golden = 13'o15004;

      9'o367: golden = 13'o01014;

      9'o370: golden = 13'o15007;

      9'o371: golden = 13'o01205;

      9'o372: golden = 13'o15007;

      9'o373: golden = 13'o01205;

      9'o374: golden = 13'o06005;

      9'o375: golden = 13'o02005;

      9'o376: golden = 13'o07005;

      9'o377: golden = 13'o03005;

      9'o400: golden = 13'o05441;

      9'o401: golden = 13'o05441;

      9'o402: golden = 13'o05441;

      9'o403: golden = 13'o05441;

      9'o404: golden = 13'o05441;

      9'o405: golden = 13'o05421;

      9'o406: golden = 13'o05441;

      9'o407: golden = 13'o05421;

      9'o410: golden = 13'o05441;

      9'o411: golden = 13'o05421;

      9'o412: golden = 13'o05441;

      9'o413: golden = 13'o05421;

      9'o414: golden = 13'o05441;

      9'o415: golden = 13'o05421;

      9'o416: golden = 13'o05441;

      9'o417: golden = 13'o05421;

      9'o420: golden = 13'o07041;

      9'o421: golden = 13'o07041;

      9'o422: golden = 13'o15040;

      9'o423: golden = 13'o15040;

      9'o424: golden = 13'o05050;

      9'o425: golden = 13'o05030;

      9'o426: golden = 13'o15040;

      9'o427: golden = 13'o15020;

      9'o430: golden = 13'o15040;

      9'o431: golden = 13'o15023;

      9'o432: golden = 13'o15040;

      9'o433: golden = 13'o15023;

      9'o434: golden = 13'o07040;

      9'o435: golden = 13'o07020;

      9'o436: golden = 13'o07041;

      9'o437: golden = 13'o07021;

      9'o440: golden = 13'o05501;

      9'o441: golden = 13'o05441;

      9'o442: golden = 13'o05501;

      9'o443: golden = 13'o05441;

      9'o444: golden = 13'o05501;

      9'o445: golden = 13'o01421;

      9'o446: golden = 13'o05501;

      9'o447: golden = 13'o01421;

      9'o450: golden = 13'o05501;

      9'o451: golden = 13'o01421;

      9'o452: golden = 13'o05501;

      9'o453: golden = 13'o01421;

      9'o454: golden = 13'o05501;

      9'o455: golden = 13'o01421;

      9'o456: golden = 13'o05501;

      9'o457: golden = 13'o01421;

      9'o460: golden = 13'o07101;

      9'o461: golden = 13'o07041;

      9'o462: golden = 13'o15103;

      9'o463: golden = 13'o15041;

      9'o464: golden = 13'o05110;

      9'o465: golden = 13'o01030;

      9'o466: golden = 13'o15100;

      9'o467: golden = 13'o11020;

      9'o470: golden = 13'o15103;

      9'o471: golden = 13'o11023;

      9'o472: golden = 13'o15103;

      9'o473: golden = 13'o11023;

      9'o474: golden = 13'o07103;

      9'o475: golden = 13'o03023;

      9'o476: golden = 13'o07101;

      9'o477: golden = 13'o03021;

      9'o500: golden = 13'o05441;

      9'o501: golden = 13'o05441;

      9'o502: golden = 13'o05441;

      9'o503: golden = 13'o05441;

      9'o504: golden = 13'o05441;

      9'o505: golden = 13'o05421;

      9'o506: golden = 13'o05441;

      9'o507: golden = 13'o05421;

      9'o510: golden = 13'o05441;

      9'o511: golden = 13'o05421;

      9'o512: golden = 13'o05441;

      9'o513: golden = 13'o05421;

      9'o514: golden = 13'o05441;

      9'o515: golden = 13'o05421;

      9'o516: golden = 13'o05441;

      9'o517: golden = 13'o05421;

      9'o520: golden = 13'o07041;

      9'o521: golden = 13'o07041;

      9'o522: golden = 13'o05440;

      9'o523: golden = 13'o15041;

      9'o524: golden = 13'o05050;

      9'o525: golden = 13'o05030;

      9'o526: golden = 13'o07040;

      9'o527: golden = 13'o05030;

      9'o530: golden = 13'o07043;

      9'o531: golden = 13'o05221;

      9'o532: golden = 13'o07043;

      9'o533: golden = 13'o05421;

      9'o534: golden = 13'o07041;

      9'o535: golden = 13'o07021;

      9'o536: golden = 13'o07041;

      9'o537: golden = 13'o07021;

      9'o540: golden = 13'o05421;

      9'o541: golden = 13'o05441;

      9'o542: golden = 13'o05421;

      9'o543: golden = 13'o05441;

      9'o544: golden = 13'o05421;

      9'o545: golden = 13'o01421;

      9'o546: golden = 13'o05421;

      9'o547: golden = 13'o01421;

      9'o550: golden = 13'o05421;

      9'o551: golden = 13'o01421;

      9'o552: golden = 13'o05421;

      9'o553: golden = 13'o01421;

      9'o554: golden = 13'o05421;

      9'o555: golden = 13'o01421;

      9'o556: golden = 13'o05421;

      9'o557: golden = 13'o01421;

      9'o560: golden = 13'o07021;

      9'o561: golden = 13'o07041;

      9'o562: golden = 13'o05030;

      9'o563: golden = 13'o15040;

      9'o564: golden = 13'o05030;

      9'o565: golden = 13'o01030;

      9'o566: golden = 13'o15020;

      9'o567: golden = 13'o01030;

      9'o570: golden = 13'o15023;

      9'o571: golden = 13'o01221;

      9'o572: golden = 13'o15023;

      9'o573: golden = 13'o01221;

      9'o574: golden = 13'o06021;

      9'o575: golden = 13'o02021;

      9'o576: golden = 13'o07021;

      9'o577: golden = 13'o03021;

      9'o600: golden = 13'o05441;

      9'o601: golden = 13'o05441;

      9'o602: golden = 13'o05441;

      9'o603: golden = 13'o05441;

      9'o604: golden = 13'o05441;

      9'o605: golden = 13'o05421;

      9'o606: golden = 13'o05441;

      9'o607: golden = 13'o05421;

      9'o610: golden = 13'o05441;

      9'o611: golden = 13'o05421;

      9'o612: golden = 13'o05441;

      9'o613: golden = 13'o05421;

      9'o614: golden = 13'o05441;

      9'o615: golden = 13'o05421;

      9'o616: golden = 13'o05441;

      9'o617: golden = 13'o05421;

      9'o620: golden = 13'o07041;

      9'o621: golden = 13'o07041;

      9'o622: golden = 13'o15040;

      9'o623: golden = 13'o15040;

      9'o624: golden = 13'o05050;

      9'o625: golden = 13'o05030;

      9'o626: golden = 13'o15040;

      9'o627: golden = 13'o15020;

      9'o630: golden = 13'o15040;

      9'o631: golden = 13'o15023;

      9'o632: golden = 13'o15040;

      9'o633: golden = 13'o15023;

      9'o634: golden = 13'o07040;

      9'o635: golden = 13'o07020;

      9'o636: golden = 13'o07041;

      9'o637: golden = 13'o07021;

      9'o640: golden = 13'o05421;

      9'o641: golden = 13'o05441;

      9'o642: golden = 13'o05421;

      9'o643: golden = 13'o05441;

      9'o644: golden = 13'o05421;

      9'o645: golden = 13'o01421;

      9'o646: golden = 13'o05421;

      9'o647: golden = 13'o01421;

      9'o650: golden = 13'o05421;

      9'o651: golden = 13'o01421;

      9'o652: golden = 13'o05421;

      9'o653: golden = 13'o01421;

      9'o654: golden = 13'o05421;

      9'o655: golden = 13'o01421;

      9'o656: golden = 13'o05421;

      9'o657: golden = 13'o01421;

      9'o660: golden = 13'o07021;

      9'o661: golden = 13'o07041;

      9'o662: golden = 13'o15023;

      9'o663: golden = 13'o15041;

      9'o664: golden = 13'o05030;

      9'o665: golden = 13'o01030;

      9'o666: golden = 13'o15020;

      9'o667: golden = 13'o11020;

      9'o670: golden = 13'o15023;

      9'o671: golden = 13'o11023;

      9'o672: golden = 13'o15023;

      9'o673: golden = 13'o11023;

      9'o674: golden = 13'o07023;

      9'o675: golden = 13'o03023;

      9'o676: golden = 13'o07021;

      9'o677: golden = 13'o03021;

      9'o700: golden = 13'o05441;

      9'o701: golden = 13'o05441;

      9'o702: golden = 13'o05441;

      9'o703: golden = 13'o05441;

      9'o704: golden = 13'o05441;

      9'o705: golden = 13'o05421;

      9'o706: golden = 13'o05441;

      9'o707: golden = 13'o05421;

      9'o710: golden = 13'o05441;

      9'o711: golden = 13'o05421;

      9'o712: golden = 13'o05441;

      9'o713: golden = 13'o05421;

      9'o714: golden = 13'o05441;

      9'o715: golden = 13'o05421;

      9'o716: golden = 13'o05441;

      9'o717: golden = 13'o05421;

      9'o720: golden = 13'o07041;

      9'o721: golden = 13'o07041;

      9'o722: golden = 13'o05440;

      9'o723: golden = 13'o15041;

      9'o724: golden = 13'o05050;

      9'o725: golden = 13'o05030;

      9'o726: golden = 13'o07040;

      9'o727: golden = 13'o05030;

      9'o730: golden = 13'o07043;

      9'o731: golden = 13'o05221;

      9'o732: golden = 13'o07043;

      9'o733: golden = 13'o05421;

      9'o734: golden = 13'o07041;

      9'o735: golden = 13'o07021;

      9'o736: golden = 13'o07041;

      9'o737: golden = 13'o07021;

      9'o740: golden = 13'o05421;

      9'o741: golden = 13'o05441;

      9'o742: golden = 13'o05421;

      9'o743: golden = 13'o05441;

      9'o744: golden = 13'o05421;

      9'o745: golden = 13'o01421;

      9'o746: golden = 13'o05421;

      9'o747: golden = 13'o01421;

      9'o750: golden = 13'o05421;

      9'o751: golden = 13'o01421;

      9'o752: golden = 13'o05421;

      9'o753: golden = 13'o01421;

      9'o754: golden = 13'o05421;

      9'o755: golden = 13'o01421;

      9'o756: golden = 13'o05421;

      9'o757: golden = 13'o01421;

      9'o760: golden = 13'o07021;

      9'o761: golden = 13'o07041;

      9'o762: golden = 13'o05030;

      9'o763: golden = 13'o15040;

      9'o764: golden = 13'o05030;

      9'o765: golden = 13'o01030;

      9'o766: golden = 13'o15020;

      9'o767: golden = 13'o01030;

      9'o770: golden = 13'o15023;

      9'o771: golden = 13'o01221;

      9'o772: golden = 13'o15023;

      9'o773: golden = 13'o01221;

      9'o774: golden = 13'o06021;

      9'o775: golden = 13'o02021;

      9'o776: golden = 13'o07021;

      9'o777: golden = 13'o03021;
        default: golden = 13'bx;
      endcase
    end
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MAC_DECODE_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MAC_DECODE_tb: latch/CP mode (posedge MCLK capture)");
`endif

    // ------------------------------------------------------------------
    // 1+2. Exhaustive combinational sweep vs golden table + SPT/SAPT
    //      mutual-exclusion invariant on every combination.
    // ------------------------------------------------------------------
    for (idx = 0; idx < 512; idx = idx + 1) begin
      {WR7, WR3, CSMIS_1_0, CSCOMM_4_0} = idx[8:0];
      #2;
      expected = golden(idx[8:0]);
      checks = checks + 1;
      if (got !== expected) begin
        errors = errors + 1;
        $display("FAIL comb idx=%03o: got %13b expected %13b (WR7=%b WR3=%b CSMIS=%o CSCOMM=%02o)",
                 idx[8:0], got, expected, WR7, WR3, CSMIS_1_0, CSCOMM_4_0);
      end
      checks = checks + 1;
      if (SAPT === 1'b1 && SPTN === 1'b0) begin
        errors = errors + 1;
        $display("FAIL mutex: SPT and SAPT both asserted (CSMIS=%o CSCOMM=%02o) - PTSEL JK would toggle",
                 CSMIS_1_0, CSCOMM_4_0);
      end
    end

    // ------------------------------------------------------------------
    // 3. Issue-C teeth: RDRQ (0o34) / WRRQ (0o35) request codes.
    //    CSMIS=1 = APT: SAPT only.  CSMIS=0 = PT: SPT only.
    //    The pre-fix RTL fails the two CSMIS=1 SPTN checks.
    // ------------------------------------------------------------------
    WR7 = 0; WR3 = 0;
    CSMIS_1_0 = 2'o1; CSCOMM_4_0 = 5'o34; #2;
    check_bit(SAPT, 1'b1, "RDRQ,APT SAPT");
    check_bit(SPTN, 1'b1, "RDRQ,APT SPTN(off)");
    CSMIS_1_0 = 2'o1; CSCOMM_4_0 = 5'o35; #2;
    check_bit(SAPT, 1'b1, "WRRQ,APT SAPT");
    check_bit(SPTN, 1'b1, "WRRQ,APT SPTN(off)");
    CSMIS_1_0 = 2'o0; CSCOMM_4_0 = 5'o34; #2;
    check_bit(SAPT, 1'b0, "RDRQ,PT SAPT(off)");
    check_bit(SPTN, 1'b0, "RDRQ,PT SPTN(on)");
    CSMIS_1_0 = 2'o0; CSCOMM_4_0 = 5'o35; #2;
    check_bit(SAPT, 1'b0, "WRRQ,PT SAPT(off)");
    check_bit(SPTN, 1'b0, "WRRQ,PT SPTN(on)");

    // ------------------------------------------------------------------
    // 4. Registered strobes LLDEXM / LLDSEG / LLDPCR.
    //    Decodes (from GATES_54/55/58):
    //      LLDEXM: LCSN=1, CSMIS=3, CSCOMM=0o21
    //      LLDSEG: LCSN=1, CSMIS=0, CSCOMM=0o20
    //      LLDPCR: LCSN=1, CSMIS=3, CSCOMM=0o06
    //    Register powers up cleared (QAN=1 = strobes active) - first
    //    neutral load clears them; then each decode is loaded, held, and
    //    cleared, and LCSN=0 must block all three.
    // ------------------------------------------------------------------
    WR7 = 0; WR3 = 0; LCSN = 1;

    // neutral load: no decode matches
    CSMIS_1_0 = 2'o2; CSCOMM_4_0 = 5'o00;
    pulse_mclk;
    check_bit(LLDEXM, 1'b0, "reg neutral LLDEXM");
    check_bit(LLDSEG, 1'b0, "reg neutral LLDSEG");
    check_bit(LLDPCR, 1'b0, "reg neutral LLDPCR");

    // LLDEXM load
    CSMIS_1_0 = 2'o3; CSCOMM_4_0 = 5'o21;
    pulse_mclk;
    check_bit(LLDEXM, 1'b1, "LLDEXM load");
    check_bit(LLDSEG, 1'b0, "LLDEXM load, LLDSEG off");
    check_bit(LLDPCR, 1'b0, "LLDEXM load, LLDPCR off");
    // hold without clock: decode removed, no MCLK -> value must stay
    CSMIS_1_0 = 2'o2; CSCOMM_4_0 = 5'o00; #20;
    check_bit(LLDEXM, 1'b1, "LLDEXM hold (no clock)");
    // clear
    pulse_mclk;
    check_bit(LLDEXM, 1'b0, "LLDEXM clear");

    // LLDSEG load
    CSMIS_1_0 = 2'o0; CSCOMM_4_0 = 5'o20;
    pulse_mclk;
    check_bit(LLDSEG, 1'b1, "LLDSEG load");
    check_bit(LLDEXM, 1'b0, "LLDSEG load, LLDEXM off");
    check_bit(LLDPCR, 1'b0, "LLDSEG load, LLDPCR off");
    CSMIS_1_0 = 2'o2; CSCOMM_4_0 = 5'o00;
    pulse_mclk;
    check_bit(LLDSEG, 1'b0, "LLDSEG clear");

    // LLDPCR load
    CSMIS_1_0 = 2'o3; CSCOMM_4_0 = 5'o06;
    pulse_mclk;
    check_bit(LLDPCR, 1'b1, "LLDPCR load");
    check_bit(LLDEXM, 1'b0, "LLDPCR load, LLDEXM off");
    check_bit(LLDSEG, 1'b0, "LLDPCR load, LLDSEG off");
    CSMIS_1_0 = 2'o2; CSCOMM_4_0 = 5'o00;
    pulse_mclk;
    check_bit(LLDPCR, 1'b0, "LLDPCR clear");

    // LCSN=0 blocks all three decodes
    LCSN = 0;
    CSMIS_1_0 = 2'o3; CSCOMM_4_0 = 5'o21;
    pulse_mclk;
    check_bit(LLDEXM, 1'b0, "LCSN=0 blocks LLDEXM");
    CSMIS_1_0 = 2'o0; CSCOMM_4_0 = 5'o20;
    pulse_mclk;
    check_bit(LLDSEG, 1'b0, "LCSN=0 blocks LLDSEG");
    CSMIS_1_0 = 2'o3; CSCOMM_4_0 = 5'o06;
    pulse_mclk;
    check_bit(LLDPCR, 1'b0, "LCSN=0 blocks LLDPCR");
    LCSN = 1;

    // ------------------------------------------------------------------
    // Verdict. Expected check count: 512*2 (sweep+mutex) + 8 (request
    // codes) + 19 (registered path) = 1051. A short count means part of
    // the tb silently did not run -> FAIL.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == 1051)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 1051 checks)", errors, checks);
    $finish;
  end

endmodule
