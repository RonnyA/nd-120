/*******************************************************************************************************************************
** ND120 Shared                                                                                                               **
**                                                                                                                            **
** Component Am9150                                                                                                           **
**                                                                                                                            **
** Am9150 1024x4 High-Speed Static R/W RAM                                                                                    **
**                                                                                                                            **
**                                                                                                                            **
** DISTINCTIVE CHARACTERISTICS                                                                                                **
**  • 1024 x 4 organization                                                                                                   **
**  • High speed - 20 ns Max. access time                                                                                     **
**  • Separate data inputs and outputs                                                                                        **
**  • Memory reset function                                                                                                   **
**  • High density SLIM 24-pin 300-MIL package                                                                                **
**  • Three-state output buffers                                                                                              **
**  • Single + 5 V power supply ± 10%                                                                                         **
**  • Low-power version                                                                                                       **
**                                                                                                                            **
**  GENERAL DESCRIPTION                                                                                                       **
**                                                                                                                            **
**  The Am9150 is a high-performance, static, n-channel, read/write, random-access memory organized as 1024 x 4.              **
**  It features single 5 V supply operation, TTL-compatible input and output levels,                                          **
**  and separate input and output pins for improved system performance and ease of use.                                       **
**                                                                                                                            **
**  The Am9150 also incorporates a reset feature which will reset the entire contents of the memory to logical                **
**   LOW in two cycle times by controlling /R (RESET) and /S (CS).                                                            **
**                                                                                                                            **
**  The Am9150 has four control signals /R, /S, /W and /G.                                                                    **
**  The /S input controls read, write and reset operations of the device and provides for easy                                **
**  selection of an individual device when the outputs are tied together.                                                     **
**  The /W (/WE) input controls the normal read and write operations, and the /G (/OE)                                        **
**  controls the state of the outputs.                                                                                        **
**                                                                                                                            **
**  http://www.sintran.com/library/libother/extern/AM9150.pdf                                                                 **
**                                                                                                                            **
** Last reviewed: 2-FEB-2025                                                                                                  **
** Ronny Hansen                                                                                                               **
********************************************************************************************************************************/

module Am9150 (
    input  wire       clk,              // Clock input (BLOCK RAM MUST HAVE CLOCK)
    input  wire [9:0] address,          // 10-bit address for 1024 locations
    input  wire [3:0] data_in,          // 4-bit data input (D0-D3)
    output wire [3:0] data_out,         // 4-bit data output (Q0-Q3)
    input  wire       WRITE_ENABLE_n,   // /W - Write Enable (active low)
    input  wire       CHIP_SELECT_n,    // /S - Chip Select (active low)
    input  wire       OUTPUT_ENABLE_n,  // /G - Output Enable (active low)
    input  wire       RESET_n           // /R - Reset (active low)
);
  //integer i;


  reg  [3:0] data4bit;

  /*******************************************************************************
   ** Memory array using block RAM                                               **
   **                                                                            **
   ** yosys: the asynchronous read on data_out (assign below) cannot map to a   **
   ** BSRAM, and yosys treats ram_style="block" as a hard requirement ("ERROR:  **
   ** no valid mapping") where Vivado/Gowin EDA treat it as advisory and fall   **
   ** back. 1024x4 = 4 Kbit as distributed LUT RAM (~256 LUT4); one instance    **
   ** in the design (MMU cache CHIP_21F). yosys pre-defines YOSYS, so every     **
   ** other flow (Vivado, Gowin EDA, Verilator, iverilog) is untouched.         **
   *******************************************************************************/
`ifdef YOSYS
  (* ram_style = "distributed" *) reg [3:0] am_memory_array[0:1023];
`else
  (* ram_style = "block" *) reg [3:0] am_memory_array[0:1023];
`endif


  /*******************************************************************************
   ** RESET (/R) - the real chip resets the ENTIRE memory to 0 "in two cycle   **
   ** times" (datasheet, controlling /R and /S). The old model skipped this    **
   ** ("NO CAN DO WITH BLOCK RAM") and only gated data_out to 0 WHILE /R was   **
   ** low - so every location came back with its old contents the moment the  **
   ** reset pulse ended. In the MMU cache (CHIP_21F, the used/valid bits)     **
   ** that made the CCLR cache-clear command a NO-OP: SINTRAN's cache flush   **
   ** after a disc DMA transfer flushed nothing and stale pre-DMA data kept   **
   ** hitting (found 24-AUG-2026, ND120_ERRFA hunt; demonstrated by          **
   ** CPU-BOARD-3202/circuit/sim/CPU_MMU_CACHE_DMA_tb.v).                    **
   **                                                                         **
   ** The array is distributed LUT RAM on every FPGA flow (the async read     **
   ** below forbids BSRAM), so a write-port sweep IS implementable: the       **
   ** falling edge of /R starts a 1024-step sweep writing 0. While the sweep  **
   ** runs, data_out reads as 0 (everything is invalid), so no stale value    **
   ** can hit before its location has been cleared. The sweep also runs once  **
   ** at power-up (counter initializer), which scrubs the X/random power-up   **
   ** state instead of trusting bitstream zero-init. External writes during   **
   ** the ~1024-clock sweep may be swept afterwards - for a cache valid bit   **
   ** that only causes a spurious later miss, never a stale hit.              **
   *******************************************************************************/
  reg        reset_n_d = 1'b1;
  reg [10:0] sweep = 11'd0;         // bit10 clear = sweep active; starts at power-up
  wire       sweep_active = !sweep[10];

  // Read, write and reset operations
  always @(posedge clk)
  begin
    reset_n_d <= RESET_n;
    if (reset_n_d && !RESET_n) begin
      // /R falling edge: restart the clear sweep
      sweep <= 11'd0;
      am_memory_array[10'd0] <= 4'b0000;
    end else if (sweep_active) begin
      sweep <= sweep + 11'd1;
      am_memory_array[sweep[9:0]] <= 4'b0000;
    end else if (!CHIP_SELECT_n && !WRITE_ENABLE_n) begin
      // Write operation: active when chip is selected and write enable is low
      am_memory_array[address] <= data_in;
    end

    data4bit <= am_memory_array[address];
  end

  // Read operation: active when chip is selected and output enable is low
  // (and not writing, not in reset, not mid-sweep)
  assign data_out = (!CHIP_SELECT_n & !OUTPUT_ENABLE_n & WRITE_ENABLE_n & RESET_n & !sweep_active)
                    ? am_memory_array[address] : 4'b0;

endmodule
