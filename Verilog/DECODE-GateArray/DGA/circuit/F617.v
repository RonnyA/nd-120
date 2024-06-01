/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F617 - D Flip-Flop with RB, SB                                    **
**                                                                       **
** Truth table from REN_A12213XJ5V1UM00_OTH_19980801.pdf                 **
** Page 6-238. Function D-F/F WITH RB, SB                                **
**                                                                       **
** Last reviewed: 20-MAY-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module F617
( 
   input H01_D, // Data
   input H02_C,  // Clock 
   input H03_RB, // Reset (negated)
   input H04_SB, // Set (negated)

   output N01_Q,
   output N02_QB
);

   // Registers to hold outputs
   reg regQ;
   reg reqQ_n;
 
   // Wires
   wire s_sb;
   wire s_d;
   wire s_c;
   wire s_rb;

   
   // Assign inputs
   assign s_sb    = H04_SB;
   assign s_d     = H01_D;
   assign s_c     = H02_C;
   assign s_rb    = H03_RB;

   // Assign outputs
   assign N01_Q   = regQ;
   assign N02_QB  = reqQ_n;


   always @(s_c, s_rb, s_sb) begin
      if (s_rb & s_sb) begin // no forced clear or set
         regQ   <= s_d;
         reqQ_n <= ~s_d;
      end else if (s_sb & !s_rb) begin // reset (negated SB)
         regQ   <= 1'b0;
         reqQ_n <= 1'b1;
      end else if (!s_sb & s_rb) begin // set (negated RB  )
         regQ   <= 1'b1;
         reqQ_n <= 1'b0;
      end else begin /* !s_rb & !s_sb */  
         regQ   <= 1'b0;
         reqQ_n <= 1'b0;
      end

   end  

endmodule


/* 

TRUTH TABLE
===========

| D | C       |RB | SB| Q | QB |
|---|---------|---|---|---|----|
| 0 | posedge | 1 | 1 | 0 | 1  |
| 1 | posedge | 1 | 1 | 1 | 0  |
| X | negedge | 1 | 1 |  Hold  |
| X |   X     | 0 | 1 | 0 | 1  |
| X |   X     | 1 | 0 | 1 | 0  |
| X |   X     | 0 | 0 | 0 | 0  |  <= prohibition

X=irrelevant

*/
