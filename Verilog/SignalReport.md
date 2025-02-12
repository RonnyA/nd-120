| Signal      | Input            | Output            | Description |
|-------------|------------------|-------------------|-------------|
| A | M169C |  | Input A |
| A_15_0 [15:0] |  | CGA_WRF, CGA_WRF_RBLOCK | DATA output 16 bit A, from register selected by LAA_3_0 , DATA iutput 16 bit A, from register selected by EA_15_0 |
| A0 | CMP4 |  | A bit 0 |
| A1 | CMP4 |  | A bit 1 |
| A2 | CMP4 |  | A bit 2 |
| A3 | CMP4 |  | A bit 3 |
| AA_9_0 [9:0] |  | MEM_ADDR_44 | 10 bits of LBD (including parity in bit 10)- 10 bit input to MEM/RAM |
| ABIT |  | PAL_44904B | Q0_n - ABIT  7-Segmen A-bit |
| ACOND_n | PAL_44403C | CPU_15, CPU_PROC_32, CPU_PROC_CGA_33 | I4, ACOND is the output of the condition register., ALU Condition, active low |
| ACONDN |  | CGA_MIC, CGA_MIC_CONDREG | Active condition, ACOND - ACOND is the output of the condition register. Input to PAL 44403 in Cycle Control to control DLY0 signal |
| ACT_n |  | PAL_44801A | Q1_n - ACT_n (n.c.) (BUS IS ACTIVE) |
| ADD_15_0 [15:0] |  | CGA_MAC_ADD | Addition result output |
| ADDRESS [9:0] | SIP1M9 |  | Address input |
| AEB |  | CMP4 | A EQUAL B |
| AGB |  | CMP4 | A GREATER THEN B |
| ALB |  | CMP4 | A LESS THAN B |
| ALUCLK | CPU_PROC_32, CPU_PROC_CGA_33, CGA_CPU_ALU_CONTR, CGA_MIC, CGA_WRF, CGA_WRF_RBLOCK |  | ALU clock, ALU clock signal, Clock, To clock the operation |
| ALUI4 | CGA_CPU_ALU_RALU |  | ALU Instruction - bit 4 |
| AOK |  | PAL_44446B | B0_n - AOK |
| B | M169C |  | Input B |
| B_15_0 [15:0] |  | CGA_WRF, CGA_WRF_RBLOCK | DATA output 16 bit B, from register selected by LBA_3_0 , DATA output 16 bit B, from register selected by EB_15_0 |
| B0 | CMP4 |  | B bit 0 |
| B1 | CMP4 |  | B bit 1 |
| B1_n |  | PAL_44511A | B1_n - (not connected) |
| B2 | CMP4 |  | B bit 2 |
| B2_n | PAL_44302B | PAL_44511A | B2_n, B2_n - (not connected) |
| B3 | CMP4 |  | B bit 3 |
| BACT_n | PAL_44303B | PAL_44304E | I9, B0_n BUS Activity |
| BANK0 |  | PAL_44445B, PAL_44446B | Q2_n - BANK0 |
| BANK1 |  | PAL_44445B, PAL_44446B | Q1_n - BANK1 |
| BANK2 |  | PAL_44445B, PAL_44446B | Q0_n - BANK2 |
| BAPR_n |  | BIF_5, BIF_BCTL_6 | Bus Address Present |
| BAUD_RATE_SWITCH [3:0] | IO_UART_42 |  | Baud rate switch |
| BB10 | CGA_MAC_LA1025 |  | no PONI + DOUBLE + SHADOW + MREQ |
| BBIT |  | PAL_44904B | Q1_n - BBIT  7-Segmen B-bit |
| BCGNT25 | MEM_LBDIF_48 | PAL_44803A, MEM_RAMC_50 | Q7_n - BCGNT25, Bus cycle grant (Delayed 25ns), CPU Grant (Delayed 25ns) |
| BCGNT50 | PAL_45009B, MEM_ADDR_44 | MEM_LBDIF_48 | I2 - BCGNT50, Bus cycle grant 50ns delayed CLOCK signal to latch LOW or HIGH bits from memory to AA_9_0, Bus cycle grant (Delayed 50ns) |
| BCGNT50R_n | PAL_45008B, MEM_DATA_46 | PAL_44310D, MEM_LBDIF_48 | Y0, I8 - BCGNT50R_n, Bus CPU Grant on read from memory after the address, Bus cycle grant (Delayed 50ns) |
| BD_23_0_n_IN [23:0] | BIF_5, BIF_DPATH_9, BIF_DPATH_BDLBD_10 |  | BUS Data/Address 24 bit IN, Bus Data IN |
| BD_23_0_n_OUT [23:0] |  | BIF_5, BIF_DPATH_9, BIF_DPATH_BDLBD_10 | BUS Data/Address 24 bit OUT, Bus Data OUT |
| BD_23_19_n [4:0] | MEM_43 |  | Bus Data and Address (bits 23:19 negated) |
| BD19_n | PAL_44446B |  | B3_n - BD19_n (not in use) |
| BD20_n | PAL_44446B |  | I4 - BD20_n |
| BD21_n | PAL_44446B |  | I5 - BD21_n |
| BD22_n | PAL_44446B |  | I6 - BD22_n |
| BD23_n | PAL_44446B |  | I7 - BD23_n |
| BDAP_n |  | BIF_5, BIF_BCTL_6 | Bus Data Present, Bus Data Present Data |
| BDAP50_n | PAL_44304E, PAL_44310D, PAL_44902A, BIF_DPATH_9, MEM_43, MEM_LBDIF_48, MEM_RAMC_50 | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 | I4, I8, I3 - BDAP50_n , Bus Data Present (Delayed 50ns), Bus Data Present 50ns delayed, BDAP50_n - Bus Data Address Present (50ns delayed), Bus Data Address Present (50ns delayed), BUS DAta Present |
| BDEST | CGA_WRF |  | B is destination (enable write to B from 'RB_15_0' on ALUCLK) |
| BDRY_n |  | PAL_44310D, BIF_5, BIF_BCTL_6, MEM_43, MEM_LBDIF_48 | B0, Bus Data Ready |
| BDRY25_n | PAL_44302B, PAL_44801A, BIF_DPATH_9 | BIF_BCTL_6, BIF_BCTL_SYNC_8 | I3 - Bus Data Ready (25ns delayed), I5 - BDRY25_n (Bus Data Ready (25ns delayed)), Bus Data Ready 25ns delayed, BDRY25_n - Bus Data Ready (25ns delayed), Bus Data Ready (25ns delayed) |
| BDRY50_n | PAL_44302B, PAL_44902A, PAL_45001B, BIF_DPATH_9, MEM_43, MEM_RAMC_50 | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 | I4 - Bus Data Ready (50ns delayed), I7 - BDRY50_n (Bus Data Ready 50ns delayed), I0 - BDRY50_n, Bus Data Ready (Delayed 50ns), Bus Data Ready 50ns delayed, BDRY50_n - Bus Data Ready (50ns delayed), Bus Data Ready (50ns delayed), BUS Data ReadY |
| BDRY75_n | PAL_45001B | BIF_BCTL_SYNC_8 | I1 - BDRY75_n, BDRY75_n - Bus Data Ready (75ns delayed) |
| BEDO_n | CPU_PROC_32, CPU_PROC_CGA_33 | CPU_MMU_24, CPU_MMU_CSR_26 | Buffered Enable IDB "data out" from CGA, Buffered EDO_n, Bus Error Data Output, active low |
| BEMPID_n | CPU_PROC_32, CPU_PROC_CGA_33 | CPU_MMU_24, CPU_MMU_CSR_26 | Buffered EMPID - Interrupt Disable (EPIC.LDMPIE->set mask reg:inh all ints), Buffered EMPID_n, Bus Empty ID, active low |
| BERROR_n |  | BIF_5, BIF_BCTL_6, ND3202D | Bus Error, Output-signal to "C PLIG", signal B21 BERROR~ |
| BGNT_n | PAL_44302B, PAL_44304E, PAL_44310D, PAL_44902A, BIF_5, BIF_DPATH_9, BIF_DPATH_BDLBD_10, MEM_LBDIF_48 | PAL_44803A, MEM_43, MEM_RAMC_50 | I9 - Bus Grant, I1, Q2_n - BGNT_n (BUS Grant), I2 - BGNT_n (NOT USED!!), Bus Grant |
| BGNT25_n | PAL_44902A, MEM_RAMC_50 | MEM_LBDIF_48 | I5 - BGNT25_n (Bus Grant 25ns delayed), Bus Grant (Delayed 25ns), BUS Grant (Delayed 25 ns) |
| BGNT50_n | PAL_44304E, PAL_44310D, BIF_5, BIF_DPATH_9 | MEM_43, MEM_LBDIF_48 | I2, I6, Bus Grant (Delayed 50ns), Bus Grant (50ns delayed) |
| BGNT75_n | PAL_44310D |  | I7 |
| BGNTCACT |  | BIF_DPATH_LDBCTL_12 | Bus Grant OR CPU Active |
| BGNTCACT_n | BIF_DPATH_BDLBD_10 | PAL_44302B | Y0_n - Combined BUS Grant/CPU Active signal, Bus Grant Control Active |
| BINACK_n |  | BIF_5, BIF_BCTL_6, ND3202D | Bus Input Acknowledge, Output-signal to "C PLIG", signal B19 BINACK~ |
| BINPUT_n | PAL_44446B | BIF_5, BIF_BCTL_6 | I2 - IBINPUT_n, Bus Input |
| BINPUT50_n | PAL_44303B, BIF_DPATH_9 | BIF_BCTL_6, BIF_BCTL_SYNC_8 | I3, Bus Input 50ns delayed, BINPUT50_n - Bus Input (50ns delayed), Bus Input (50ns delayed) |
| BINPUT75_n |  | BIF_BCTL_SYNC_8 | BINPUT75_n - Bus Input (75ns delayed) |
| BINT10_n | ND3202D |  | Input signal from "C PLUG", signal A15 - BINT10_n |
| BINT10N | CGA_INTR |  | Bus Interrupt 10, active low |
| BINT11_n | ND3202D |  | Input signal from "C PLUG", signal C15 - BINT11_n |
| BINT11N | CGA_INTR |  | Bus Interrupt 11, active low |
| BINT12_n | ND3202D |  | Input signal from "C PLUG", signal A16 - BINT12_n |
| BINT12N | CGA_INTR |  | Bus Interrupt 12, active low |
| BINT13_n | ND3202D |  | Input signal from "C PLUG", signal C16 - BINT13_n |
| BINT13N | CGA_INTR |  | Bus Interrupt 13, active low |
| BINT15_n | ND3202D |  | Input signal from "C PLUG", signal C17 - BINT15_n |
| BINT15N | CGA_INTR |  | Bus Interrupt 15, active low |
| BIOEX_n |  | ND3202D | Output-signal to "C PLIG", signal C19 BIOXE~ |
| BIOXE_n | PAL_44310D, MEM_43, MEM_LBDIF_48 | BIF_5, BIF_BCTL_6 | B4, Bus IOX Enabled, Bus I/O Execute, BUS IOX Enable |
| BIOXL_n | PAL_45008B, MEM_DATA_46 | PAL_44310D, MEM_LBDIF_48 | B1, I6 - BIOXL_n, Bus IOX Enable |
| BLCS_n | CPU_CS_16 | CPU_MMU_24, CPU_MMU_CSR_26 | Buffered LCS_n (same as LCS_n), Bus LCS (Load Control Store), Buffered LCS_n |
| BLOCK_n | BIF_BCTL_SYNC_8 | PAL_45001B | B0_n - BLOCK_n (out), BLOCK_n - Bus Block |
| BLOCK25_n | PAL_45001B | BIF_BCTL_SYNC_8 | I2 - BLOCK25_n, BLOCK25_n - Bus Block (25ns delayed) |
| BLOCKL_n | MEM_LBDIF_48 | PAL_45009B | B2_n - BLOCKL_n, Bus Block |
| BLOCKL25_n | PAL_45009B | MEM_LBDIF_48 | I1 - BLOCKL25_n, Bus Block |
| BLRQ_n | MEM_LBDIF_48 |  | Bus Load Request |
| BLRQ50_n | PAL_44803A, MEM_RAMC_50 | MEM_LBDIF_48 | I4 - BLRQ50_n, Bus Load Request, Bus Load Request (Delayed 50ns) |
| BMEM_n | PAL_44446B, MEM_43 | BIF_5, BIF_BCTL_6, ND3202D | I3 - BMEM_n, Bus MEM enabled, Bus Memory, BUS MEMORY Enable, Output-signal to "C PLIG", signal C28 BMEM~ |
| BPERR50_n | PAL_45001B | BIF_BCTL_SYNC_8 | I3 - BPERR50_n, BPERR50_n - Bus Parity Error (50ns delayed) |
| BR_15_0 [15:0] | CGA_MAC, CGA_MAC_ADD | CGA_WRF, CGA_WRF_RBLOCK | ALU B Register, B register from ALU, Direct output from B register (register #3) |
| BREF_n |  | BIF_5, BIF_BCTL_6, ND3202D | Bus Refresh, Output-signal to "C PLIG", signal B12 BREF~ |
| BREQ_n | ND3202D |  | Input signal from "C PLUG", signal C12 - BREQ_n |
| BREQ50_n |  | BIF_BCTL_SYNC_8 | BREQ50_n - Bus Request (50ns delayed) |
| BRK_n | PAL_44305D, PAL_44307C, PAL_44601B, CPU_MMU_24 | CPU_15, CPU_PROC_32 | I8 - Break signal, active low, used to interrupt normal operation for debugging or error handling., I6 Break, I7 - BRK_n  - BREAK Cycle, CPU Break Signal, Break |
| BRKN | DECODE_DGA_COMM, CGA_DCD |  | Break signal |
| BRQ50_n | PAL_44801A |  | I3 - BRQ50_n (Bus Request (50ns delayed)) |
| BSEM_n |  | PAL_44803A | Q6_n - BSEM_n (n.c.) |
| BSTP | CPU_PROC_32, CPU_PROC_CGA_33 | CPU_MMU_24, CPU_MMU_CSR_26 | Bus Stop, Buffered STP , Buffered STP (STP = Stop), Bus Stop signal |
| btn1 | ND120_TOP |  | Button 1, mapped to S1 (not labeled) on the board - connected to sys_rst_n |
| btn2 | ND120_TOP |  | Button 2, mapped to S2 (not labeled) on the board |
| C | M169C |  | Input C |
| C0 | PAL_44408B |  | I4 - CSCOMM0 - CSBIT# 32 - Command bit 0 |
| C1 | PAL_44408B |  | I3 - CSCOMM1 - CSBIT# 33 - Command bit 1 |
| C10 | CGA_MAC_LA1025 |  | no PONI + DOUBLE + SHADOW + not MREQ |
| C2 | PAL_44408B |  | I2 - CSCOMM2 - CSBIT# 34 - Command bit 2 |
| C3 | PAL_44408B |  | I1 - CSCOMM3 - CSBIT# 35 - Command bit 3 |
| C4 | PAL_44408B |  | I0 - CSCOMM4 - CSBIT# 36 - Command bit 4 |
| CA_10_0 [10:0] | CPU_MMU_24 |  | Cache address, 11 bits |
| CA_9_0 [9:0] | BIF_5, BIF_DPATH_9 | CPU_PROC_32 | CPU Address, Control Store Address, CPU Address 9-0 |
| CA10 |  | DECODE_DGA_COMM | Control Store address bit 10 |
| CACT_n | PAL_44302B, PAL_44303B, BIF_BCTL_SYNC_8, BIF_DPATH_9 | PAL_44801A, BIF_BCTL_6 | I7 - CPU Active, I0, Q7_n - CACT_n (CPU IS ACTIVE ON THE ND100 BUS), CPU Active, CACT_n - CPU Active |
| CACT25_n |  | BIF_BCTL_SYNC_8 | CACT25_n - CPU Active (25ns delayed) |
| CAS |  | PAL_44902A, MEM_RAMC_50 | Q5_n - CAS, Column Address Strobe |
| CAS_n | SIP1M9 |  | Column address strobe |
| CAS9_n | SIP1M9 |  | Column address strobe |
| CBIT |  | PAL_44904B | Q2_n - CBIT  7-Segmen C-bit |
| CBRKN |  | CGA_DCD | CBRK negated |
| CBWRITE_n | BIF_BCTL_6 | PAL_44303B, BIF_DPATH_9, BIF_DPATH_LDBCTL_12 | Y1_n - CPU Write cycle to Bus, CPU Bus Write, CPU Write cycle to Bus |
| CC0_n | PAL_44307C | PAL_44601B | I1 Cycle Clock 0, Q2_n - Cycle Control 0 (negated) |
| CC1_n | PAL_44305D, PAL_44307C | PAL_44601B | I1 - Cycle Control 1 (b+c+d+e+j+k+l+m), I2 Cycle Clock 1, Q3_n - Cycle Control 1 (negated) |
| CC2_n | PAL_44302B, PAL_44305D, PAL_44307C, BIF_5, BIF_BCTL_6, BIF_DPATH_9, CPU_MMU_24 | PAL_44601B | I2 - Cycle Control bit 2, I2 - Cycle control 2 (e+f+g+h+i+j+k), I3 Cycle Clock 2, Q4_n - Cycle Control 2 (negated), CPU Cycle Counter bit 2, Cycle Counter bit 2, Cpu Cycle bit 2, Cycle clock 2 |
| CC3_n | PAL_44305D, PAL_44307C | PAL_44601B | I3 - Cycle Control 3 (h+i+j+k+l+m+n+o), I4 Cycle Clock 3, Q5_n - Cycle Control 3 (negated) |
| CCLR_n | CPU_MMU_24 |  | Cache clear |
| CCLRN |  | DECODE_DGA_COMM | Cache Clear |
| CD_10_9 [1:0] | CGA_CPU_ALU_CONTR |  | CPU Data 10:9 |
| CD_15_0 [15:0] | CPU_PROC_CGA_33, CGA_MAC_ADD, CGA_MIC |  | Command/Data bus, CPU data (Added to the selected register), Data bus for communication |
| CD_15_0_IN [15:0] | BIF_5, BIF_DPATH_9, BIF_DPATH_CDLBD_11, CPU_MMU_24, CPU_PROC_32 |  | CPU Data 16 bit IN, CPU Data IN, CPU Data Input (16 bits), Cache data input, 16 bits, CPU Data 15-0 |
| CD_15_0_OUT [15:0] |  | BIF_5, BIF_DPATH_9, BIF_DPATH_CDLBD_11, CPU_MMU_24 | CPU Data 16 bit OUT, CPU Data OUT, CPU Data Output (16 bits), Cache data output, 16 bits |
| CDS | CGA_MAC_ADD |  | If false all 16 bits of CD is added. If true, only the low 8 bits are added. |
| CEUART_n | IO_UART_42 |  | Chip Enable UART |
| CEUARTN |  | DECODE_DGA_COMM | Enable UART |
| CFETCH | CGA_MIC | CGA_DCD | Command fetch, Control signal for fetch operation |
| CGABRK_n |  | CPU_PROC_CGA_33 | CGA Break, active low |
| CGNT_n | PAL_44302B, PAL_44303B, PAL_44304E, PAL_44310D, PAL_44902A, BIF_5, BIF_BCTL_6, BIF_DPATH_9, MEM_LBDIF_48 | PAL_44803A, MEM_43, MEM_RAMC_50 | I5 - CPU Grant, I1, I0, I2, Q1_n - CGNT_n (CPU Grant), I1 - CGNT_n (NOT USED!!), Bus Grant, CPU Grant, Bus CPU Grant |
| CGNT25_n | PAL_44902A, MEM_RAMC_50 | MEM_LBDIF_48 | I6 - CGNT25_n (CPU Grant 25ns delayed), Bus CPU Grant (Delayed 25ns), CPU Grant (Delayed 25 ns) |
| CGNT50_n | PAL_44302B, PAL_44310D, BIF_5, BIF_BCTL_6, BIF_DPATH_9 | MEM_43, MEM_LBDIF_48 | I6 - CPU Grant (50ns delayed), I4, Bus Grant (Delayed 50ns), Grant 50ns delayed, Bus Grant (50ns delayed), CPU Grant (Delayed 50ns), Bus CPU Grant (Delayed 50ns) |
| CGNTCACT_n | PAL_44601B | PAL_44302B, BIF_5, BIF_DPATH_9, BIF_DPATH_LDBCTL_12 | Y1_n - Combined CPU Grant/Active signal, I5 - CGNTCACT_n, Combined CPU Grant/Active signal, CPU Grant OR CPU Active |
| CI | CGA_CPU_ALU_RALU |  | Carry IN (1=carry in) |
| CK | PAL_44407A, PAL_44408B, PAL_44445B, PAL_44446B, PAL_44511A, PAL_44801A, PAL_44803A, PAL_44902A, PAL_44904B, AM29C821 |  | Clock signal, Clock signal (connected to DBAPR), Clock input (Latching on rising edge of CK) |
| CLEAR | DECODE_DGA_COMM | DECODE_DGA_POW | Clear signal |
| CLEAR_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 |  | Clear, CLEAR_n - Clear |
| CLFFN | CGA_MIC | CGA_DCD | Clear FF negated, Clear flag function |
| CLIRQN | CGA_INTR | CGA_DCD | Clear interrupt request negated, Clear Interrupt Request, active low |
| CLK | PAL_44402D, PAL_44403C, PAL_44404C, PAL_44511A, CPU_PROC_32, IO_UART_42, SCAN_FF, AM29833A |  | Clock signal, I4 - CLK (same signal as CK), Clock, Clock (positive triggered), Clock for parity error |
| CLK0 | DECODE_DGA_IDBS |  | Clock input 0 |
| CLK1 | DECODE_DGA_COMM, DECODE_DGA_IDBS |  | Clock input 1 |
| CLK2 | DECODE_DGA_COMM |  | Clock input 2 |
| CLK3 | DECODE_DGA_COMM |  | Clock input 3 |
| CLKBD | BIF_DPATH_BDLBD_10 | PAL_44304E | B4_n Clock BD, Clock BD |
| clock | D_FLIPFLOP_SIMPLE |  | Clock |
| CLOCK_1 | ND3202D |  | XTAL1 = 39.3216MHZ |
| CLOCK_2 | ND3202D |  | XTAL2 = 35 MHZ (for slow operations?) |
| CLOSC | DECODE_DGA_POW |  | Clear Oscilator signal (From IO_DCD_38) - Is 1 during a very short time at power-on. Then goes to 0 and stays there. |
| CLR_n | AM29833A |  | Clear error |
| CLRERR_n |  | PAL_45008B | B1_n - CLRERR_n |
| CLRQ_15_0 [15:0] |  | CGA_INTR_CNTLR_CLR |  |
| CLRQ_n | PAL_44803A, MEM_RAMC_50 | PAL_44445B | B1_n - CLRQ_n, I3 - CLRQ_n, Bus Clear Request |
| CLRTIN | DECODE_DGA_POW | DECODE_DGA_COMM | Clear Real Time Clock |
| CMIS_1_0 [1:0] | CGA_MAC |  | Microcode: Misc  (2 bits) |
| CMWRITE_n |  | PAL_44303B | B1_n - CPU Write to Local Memory |
| CON | CPU_MMU_CSR_26 | M169C | Cache ON (CON) goes to IDB1 when ECSR_n is low. CON_n goes to IDB2, Count is Zero |
| COND |  | CGA_MIC | Condition output signal |
| CONSOLE_n | IO_UART_42 |  | Console signal |
| CONTINUE_n | ND3202D |  | Input signal from "C PLUG", signal B15 - CONTINUE_n |
| CONTINUEN | DECODE_DGA_POW |  | Continue Enable |
| CP | M169C |  | Clock Pulse |
| CRQ_n | PAL_44801A, BIF_5, BIF_BCTL_6 | PAL_44445B, MEM_43 | B2_n - CRQ_n, I0 - CRQ_n (CPU Request), CPU Request |
| CRY | CGA_CPU_ALU_CONTR, CGA_DCD, CGA_MIC | CGA_CPU_ALU_RALU | ALU Carry, Carry Out, Carry flag, Carry flag input |
| CSA_12_0 [12:0] | CPU_CS_16 | CPU_PROC_32, CPU_PROC_CGA_33 | XMA_12_0 from CGA (Delilah) (MA_12_0 from CGA.MIC) <= Microcode address, 13 bits., Control Store Address 12-0, Control Store Address |
| CSALUI_8_0 [8:0] | CGA_CPU_ALU_CONTR |  | ALU Instruction |
| CSALUI7 | PAL_44404C |  | I4 |
| CSALUI8 | PAL_44404C, CGA_MIC |  | I3, ALU immediate operation control |
| CSALUM_1_0 [1:0] | CGA_CPU_ALU_CONTR |  | ALU Mode |
| CSALUM0 | PAL_44404C |  | I2 |
| CSALUM1 | PAL_44404C |  | I1 |
| CSBIT_11_0 [11:0] | CGA_MIC_CONDREG |  | Microcode bits 11:0 |
| CSBIT_15_0 [15:0] | CGA_MIC |  | Control signals for bits 15 to 0 |
| CSBIT20 | CGA_MIC |  | Control signal for bit 20 |
| CSBITS [63:0] | CPU_CS_TCV_20, CPU_PROC_32, CPU_PROC_CGA_33 |  | 64 bits CSBITS (input when reading from CSBITS to IDB OUT), Control Store Bits  (64 bits Microcode), Control Store Bits |
| CSBITS_OUT [63:0] |  | CPU_CS_TCV_20 | 64 bits CSBITS (output when IDB IN writes a 16 bit part to the CSBITS) |
| CSCA_9_0 [9:0] | CPU_CS_16 | CPU_PROC_32, CPU_PROC_CGA_33 | Source CGA.XMCA_9_0, source MAC.MCA_9_0, sourcr MAC_AP09.MCA_9_0, source CALCA.MCA9_0 <= Input ICA.Bits [15:0] but only when MCLK is low. Almost the same as LCA15_0, exectp LCA_15_0 is locked in a register on clock lo-hi, Control Store Cache Address 9-0, Control Store Cache Address |
| CSCINSEL_1_0 [1:0] | CGA_CPU_ALU_CONTR |  | Carry In Select (00: Carry In, 01: Carry In Not, 10: Carry In Not, 11: Carry In) |
| CSCOMM_4_0 [4:0] | DECODE_DGA_COMM, CGA_DCD, CGA_MAC |  | Microcode Command 4:0, Command control signals, Microcode: Commands (5 bits) |
| CSCOND | CGA_MIC |  | Conditional execution control |
| CSDELAY0 | PAL_44403C, PAL_44601B |  | I0, I2 - CSDELAY0   CSDELAY0 (CSBITS #26 - DELAY 0) |
| CSDELAY1 | PAL_44404C |  | I0 |
| CSDLY | PAL_44403C |  | I1 |
| CSECOND | PAL_44403C, CGA_MIC |  | I2, Control signal for Enable Condition |
| CSEM_n |  | PAL_44803A | Q5_n - CSEM_n (n.c.) |
| CSIDBS_4_0 [4:0] | DECODE_DGA_IDBS, CGA_DCD |  | Microcode IDB Source select, IDB control signals |
| CSLOOP | PAL_44403C, CGA_MIC |  | I3, Loop control signal |
| CSMIS_1_0 [1:0] | DECODE_DGA_COMM, CGA_CPU_ALU_CONTR, CGA_DCD |  | Microcode Misc signal 1:0, Control Store - MIS, MIS control signals |
| CSMIS0 | CGA_MIC |  | Control signal for miscellaneous operation bit 0 |
| CSMREQ |  | CGA_DCD | CSM request |
| CSRASEL_1_0 [1:0] | CGA_MIC |  | Register A select control |
| CSRB_3_0 [3:0] | CGA_MIC |  | Control signals for register B bits 3 to 0 |
| CSRBSEL_1_0 [1:0] | CGA_MIC |  | Register B select control |
| CSSCOND | CGA_MIC_CONDREG |  | Microcode "SCOND" - COND) sets a 4-bit condition-code to be tested on a later occasion. |
| CSSST_1_0 [1:0] | CGA_CPU_ALU_CONTR |  | Control Store - STSS  (00=Hold STS, 01=Enable Set C O Q, 10=Enable set M, 11=Load STS) |
| CSTS_6_3 [3:0] | CGA_MIC |  | Status control signals bits 6 to 3 |
| CSVECT | CGA_MIC |  | Vector control signal |
| CSXRF3 | CGA_MIC |  | Cross-reference control signal 3 |
| CUP | CPU_MMU_24, CPU_MMU_CSR_26 | PAL_44511A, CPU_PROC_32 | Q0_n - (not connected), Cache updated, Cache Updated (CUP) goes to IDB0 when ECSR_n is low  |
| CWR | CPU_MMU_24 | CPU_PROC_32 | Cache write |
| CWR_n |  | PAL_44511A | B0_n - CWR_n |
| CX_n |  | PAL_44601B | Q0_n - CX_n    - CX is always 1 in the fast version (CX_n = 0) |
| CYD | PAL_44402D, CPU_MMU_24 | PAL_44307C | B1_n - CYD_n     Cycle Done ?, I4, Cycle done |
| d | D_FLIPFLOP_SIMPLE |  | D input (DATA) |
| D | M169C, SCAN_FF |  | Input D, D input |
| D [9:0] | AM29C821 |  | 10 Bit Data Inputs |
| D_IN [9:0] | AM29861A |  | Receiver Data Bus - input (read left, write right) |
| D_OUT [9:0] |  | AM29861A | Receiver Data Bus - output |
| D8 [7:0] | SIP1M9 |  | DATA INPUT (8-bit) |
| D9 | SIP1M9 |  | DATA INPUT (1-bit) |
| DA_n |  | IO_UART_42 | Data Available |
| DAP_n |  | BIF_5, BIF_BCTL_6 | Data Present |
| DAPN | DECODE_DGA_COMM |  | Data Address |
| DBAPR | PAL_44446B, BIF_BCTL_6, MEM_43 | PAL_44304E, BIF_5, BIF_DPATH_9 | Y0_n, I0 - DBAPR, Data Bus Address Present, Data Bus Address Parity register, BUS Address Present |
| DBAPR_n | PAL_45001B |  | I4 - DBAPR_n |
| DBIT |  | PAL_44904B | Q3_n - DBIT  7-Segmen D-bit |
| DDBAPR_n |  | PAL_44446B | B1_n - DDBAPR_n |
| DEEP |  | CGA_MIC | output        DZD,          Divide by zero detection |
| DGPR0N | CGA_CPU_ALU_CONTR |  | GPR0 Not |
| DIN_15_8 [7:0] | CGA_INTR_CNTLR_CLR |  | input [7:0] DIN_7_0,       |
| DIS_n |  | PAL_45008B | Y0_n DIS_n (OUT Only) |
| DISB_n |  | PAL_45008B | B2_n - DISB_n (n.c.) |
| DLSHADOW |  | PAL_44404C | Q1_n (new output for 44404D) |
| DLY0_n | PAL_44601B | PAL_44403C | B0_n, I1 - DLY0_n     DLY0_ (Ouput from PAL 44403 DLY0_n (B0) |
| DLY1_n | PAL_44601B | PAL_44404C | B3_n, I0 - DLY1_n     DLY1_ (Ouput from PAL 44404 DLY1_n (B3) |
| DMA12_n |  | PAL_44403C | Q2_n |
| DMAP_n |  | PAL_44403C | Q3_n |
| DOREF_n |  | PAL_44801A | Q2_n - DOREF_n (n.c.) (INDICATES THAT LAST BUS CYCLE WAS A REFRESH) |
| DOUBLE | CPU_MMU_24 | CPU_PROC_32, CPU_PROC_CGA_33 | Extended Adressing Mode (SEXI), Double, Double precision operation |
| DSTB_n | BIF_DPATH_CDLBD_11 | PAL_44302B | B1_n - Data Strobe, Data Strobe |
| DSTOPN |  | CGA_DCD | DSTOP negated |
| DT_n | PAL_44402D, CPU_MMU_24 |  | I0, Data transfer |
| DTN |  | DECODE_DGA_COMM | Data Transfer |
| DVACC_n | CPU_MMU_24 |  | Data valid acknowledge |
| DVACCN |  | DECODE_DGA_COMM | Data Valid |
| EA_15_0 [15:0] | CGA_WRF_RBLOCK | CGA_WRF | Enable A (source) bits for read. 16 bits to select register., Enable A (source) for read. 16 bits to select register. |
| EADDR_n | BIF_DPATH_9 |  | Enable External Address |
| EADR_n | PAL_44303B, BIF_DPATH_LDBCTL_12 | BIF_BCTL_6 | I2 - Address from CPU to Bus, Enable Address, Address from CPU to BUS |
| EAUTO_n | IO_UART_42 |  | External Auto signal |
| EB_15_0 [15:0] | CGA_WRF_RBLOCK |  | Enable B (dest) for read. 16 bits to select register. |
| EBADR | BIF_DPATH_BDLBD_10 |  | Enable Address from Bus to Local Memory |
| EBADR_b1 |  | PAL_44304E | B1_n Enable Address from BUS to Local Memory |
| EBD_n | BIF_DPATH_BDLBD_10 | PAL_44304E | B5_n Enable Bus Data, Enable Bus Data (Enable LBD to BD transceiver). |
| EBUS | ND3202D |  | EBUS B-B3 (pulled high) |
| EBUS_n | PAL_44304E, BIF_5, BIF_DPATH_9 |  | I5, Enable Bus, Enable External Bus |
| ECCR | PAL_44310D, PAL_45008B, MEM_43, MEM_DATA_46, MEM_LBDIF_48 | CPU_15, CPU_PROC_32, CPU_PROC_CGA_33, CGA_MAC, CGA_MAC_APOS_CALCA | I5, I7 - ECCR, ECC Register Detected for IOX, ECC Register Detected (IOX 100115), Error Correction Code Ready, BUS ECC Request, Error Correction Code Register, DECODE "TRR ECCR" = IOX 100115 |
| ECCRHIN | CGA_MAC_APOS_CALCA |  | ECCR HI (ECCR Hi bits valid) |
| ECREQ | PAL_44445B, BIF_5, BIF_DPATH_9, BIF_DPATH_CDLBD_11, MEM_43 | DECODE_DGA_COMM | B3_n - ECREQ, Enable CPU Request, BUS ECC Request |
| ECSL_n | CPU_CS_TCV_20 | PAL_44305D | Enable Control Store LOWER (CSL negated)  B0_n - READ CONTROL STORE HOLD | HOLD OVERLAP WITH EWCA_n, When asserted (low), IDB 15:0 is connected to IDB 15:0. Source PAL_44305D, CPU_CS_CTL_18. Comment in the PAL source says "ECSL HOLD IN g AND h cycles" |
| ECSR_n | CPU_MMU_24, CPU_MMU_CSR_26 |  | Enable cache status register, Enable Cache Status Reg |
| ECSRN |  | DECODE_DGA_IDBS | Enable Cache Status Register (CSR) - 24 |
| EDO_n | CPU_MMU_24 |  | Enable data output |
| EDON |  | DECODE_DGA_IDBS | Enable DO signal (multiple IDB sources) - 0,1,2,3,4,6,10,11,14,25,36 |
| EHI_n |  | PAL_44904B | Q7_n - EHISEG_n (Eneble HI-Segment) |
| EIOR_n | IO_UART_42 |  | Enable I/O Read |
| EIORN |  | DECODE_DGA_IDBS | Enable IO register from UART etc -16 |
| EIPL_n | CPU_MMU_PPNX_28 |  | Enable IDB lower bits |
| EIPU_n | CPU_MMU_PPNX_28 |  | Enable IDB upper bits |
| EIPUR_n | CPU_MMU_PPNX_28 |  | Mask away the PROTECT BITS in PPN (PPN 25:19 == 000000) |
| ELOW_n | CPU_CS_WCS_21_22 | PAL_44305D, PAL_44904B | Enable Low                          B3_n - NORMAL ADDRESSING. ON FETCH EITHER MI |  ENABLE ACCORDING TO LUA12 BEFORE FETCH | OR A MAP IS USED. |  DO A MAP | ON BRK: USE BANK SELECTED BY LUA12., Q5_n - ELOWSG_n (Enable LOW segment), Enable LOW chips |
| EMCL_n | CPU_MMU_24 |  | Enable master clear |
| EMCLN | DECODE_DGA_POW | DECODE_DGA_COMM | Enable Master Clear |
| EMD_n | BIF_DPATH_CDLBD_11 | PAL_44302B, BIF_DPATH_LDBCTL_12 | B0_n - Enable Data Path between CD and LBD, Enable Memory, Enable Memory LBD to CD bus |
| EMID_n |  | PAL_44904B | Q6_n - EMIDSEG_n (Enable MID-Segment) |
| EMPID_n | CPU_MMU_24 |  | Interrupt disable |
| EMPIDN | CGA_INTR | DECODE_DGA_COMM | Enable MPID - Set bits in the micro—PID (Priority Interrupt Detect) register in the PIC. Command #012. "set mask reg: inh all ints", Interrupt Disable (EPIC.LDMPIE->set mask reg:inh all ints) |
| EORF_n | CPU_MMU_24 | PAL_44307C | B2_n - EORF_n    End of Read Flag ? (Miscellaneous write pulse), End of Read Flag |
| EORFN | DECODE_DGA_COMM |  | Enable Output Register |
| EPANN |  | DECODE_DGA_IDBS | Enable Panel Interrupt Vector - 27 |
| EPANSN |  | DECODE_DGA_IDBS | Enable Panel Status register (MIPANS/MAPANS - 20/21 |
| EPCRN |  | CGA_DCD | EPCR negated |
| EPEA_n | PAL_45001B, BIF_DPATH_9 | BIF_BCTL_6 | I9 - EPEA_n, Enable PEA, Enable PEA register |
| EPEAL_n |  | PAL_45009B | B1_n - EPEAL_n (/output enable to PEAL register) |
| EPEAN |  | DECODE_DGA_IDBS | Enable Parity Error address (PEA) - 12 |
| EPES_n | PAL_45001B, BIF_DPATH_9 | BIF_BCTL_6 | I8 - EPES_n, Enable PES, Enable PES register |
| EPESL_n |  | PAL_45009B | B0_n - EPESL_n (clock to PEAL register) |
| EPESN |  | DECODE_DGA_IDBS | Enable Parity Error Status & Address (PES) -13 |
| EPGSN |  | CGA_DCD | EPGS negated |
| EPIC | CGA_INTR | CGA_DCD | EPIC signal, Enable PIC (Programmable Interrupt Controller) signal |
| EPICMASKN |  | CGA_INTR | EPIC Mask, active low |
| EPICSN |  | CGA_DCD | EPICS negated |
| EPICVN |  | CGA_DCD | EPICV negated |
| EPMAP_n | CPU_MMU_PT_29 |  | Enable EPMAP chips (Extended map?) |
| EPT_n | CPU_MMU_PT_29 |  | Enable PT chips (Chip select for PT chips). Combine with WMAP_n to write to PT chips (Chip 24G and Chip 25G) |
| ERF_n |  | PAL_44407A, CPU_PROC_CGA_33 | B0_n - ERF_n ((WRTRF or RRF) negated) - Enables RAM chips 34F and 35F in CPU_PROC_32.v for read or write of REG, Error Flag, active low |
| ERFN |  | CGA_DCD | ERF negated |
| ERR_n |  | AM29833A | Parity Error |
| ESTOF_n | CPU_MMU_24, CPU_MMU_PPNX_28, CPU_PROC_32 |  | Enable store of Fault, Input signal for direction control (PPN<->IDB) |
| ESTOFN |  | DECODE_DGA_COMM | Enable Store Overflow |
| ETRAP_n | CPU_PROC_32, CPU_PROC_CGA_33 | PAL_44307C | B4_n - ETRAP_n   Enable Trap signals, Enable Trap , External Trap, active low |
| EUPP_n | CPU_CS_WCS_21_22 | PAL_44305D | Enable Upper                        B2_n - NORMAL ADDRESSING | WRITE INTO MICROINSTRUCTION CACHE | ENABLE IN THE FIRST 50NS , Enable UPPER chips |
| EW_3_0_n [3:0] | CPU_CS_TCV_20 |  | Enable Word (4 bits, where the enabled word (0-3) has its bit set to 0. Chooses which 16 bits of the 64 bits CSBITS that is read or written |
| EWC_n | PAL_44402D |  | I7 |
| EWCA_n | CPU_PROC_32, CPU_PROC_CGA_33 | PAL_44305D | Enable WCA reg in mic onto MA       B1_n - ENABLE WCA REG. IN MIC ONTO MA |  AVOID BLIP ON NEXT CYCLE, Enable Write Cache Address , External Write Cache Acknowledge, active low |
| EWCAN | CGA_MIC |  | Enable write control |
| F_15_0 [15:0] |  | CGA_CPU_ALU_RALU | Function Result (15:0) |
| F0 | CGA_CPU_ALU_CONTR |  | F bit 0 |
| F11 | CGA_MIC |  | Bit F11 |
| F15 | CGA_CPU_ALU_CONTR, CGA_DCD, CGA_MIC |  | F bit 15, Flag F15 (Bit 15 in F is 1), Bit F15 |
| FAPR |  | PAL_44304E | B2_n |
| FETCH | PAL_44305D, BIF_5, BIF_DPATH_9, CPU_CS_16, MEM_43 | DECODE_DGA_COMM | I7 - Fetch macrocode, Fetch, Fetch command , Bus Fetch, Fetch cycle active |
| FETCHN | CGA_TRAP_TBUF | CGA_DCD | Fetch negated, FETCH_n (Fetch instruction, negate) |
| FIDB_15_0_IN [15:0] | CPU_PROC_CGA_33 |  | FIDB input bus |
| FIDB_15_0_OUT [15:0] |  | CPU_PROC_CGA_33 | FIDB output bus |
| FIDBO_15_0 [15:0] | CGA_INTR, CGA_MAC |  | FIDB , 16-bit, FIDBO output from previous stage |
| FIDBO5 | CGA_DCD |  | FIDB Output signal 5 |
| FMISS | PAL_44402D, CPU_MMU_24 | DECODE_DGA_COMM | I3, Force miss, Cache miss during fetch |
| FORM_n | PAL_44305D, PAL_44307C |  | I0, I5 Form |
| FORMN |  | DECODE_DGA_COMM | Form number |
| FS_6_3 [3:0] |  | CGA_MIC_CONDREG | False Select. CSBIT 3:0 |
| FSEL | CGA_CPU_ALU_RALU |  | Function Select (1=Logic function (XOR), 0=OR/AND/NOT) |
| GNT_n | PAL_44304E, BIF_DPATH_9, MEM_43, MEM_LBDIF_48 | PAL_44801A, BIF_5, BIF_BCTL_6 | I7, Q6_n - GNT_n  (GRANT ND100 BUS TO A DMA DEVICE OR EXTERNAL BUS CONTROLLER), Grant, Bus Grant |
| GNT50_n | BIF_5, BIF_BCTL_6 | MEM_43, MEM_LBDIF_48 | Grant (Delayed 50ns), Grant 50ns delayed, CPU Grant (Delayed 50ns), Bus Grant (Delayed 50ns) |
| GPR0 | CGA_CPU_ALU_CONTR |  | GPR bit 0 |
| HIEN_n | PAL_44310D, PAL_45008B, MEM_ADDR_44, MEM_DATA_46, MEM_LBDIF_48 | PAL_44902A, MEM_RAMC_50 | I0, Q7_n - HIEN_n, I9 - EPEA_n  (NOT USED!), High address bits enable, High address bits enable (not used) |
| HIERR |  | MEM_DATA_46 | High address bits error |
| HIGSN |  | CGA_INTR | High Speed signal, active low |
| HIK | CGA_INTR_CNTLR_CLR |  | HI K |
| HIT | PAL_44601B | CPU_15, CPU_MMU_24 | I6 - HIT    - Cache hit, Cache hit, Cache hit signal, indicates a successful cache lookup |
| HIT0_n | PAL_44402D |  | I5 |
| HIT1_n | PAL_44402D |  | I6 |
| HITN | DECODE_DGA_COMM |  | Cache Hit |
| HIVEC_2_0 [2:0] | CGA_INTR_CNTLR_IRGEL_VMUX |  | High vector |
| HVE | CGA_INTR_CNTLR_IRGEL_VMUX |  | High vector Enable |
| HX_2_0_N [2:0] | CGA_INTR_CNTLR_CLR |  | input [2:0] HX_2_0,        |
| i3 | PAL_44904B |  | I3 - (n.c.) |
| i4 | PAL_44904B |  | I4 - (n.c.) |
| i5 | PAL_44904B |  | I5 - (n.c.) |
| i6 | PAL_44904B |  | I6 - (n.c.) |
| i7 | PAL_44904B |  | I7 - (n.c.) |
| I7 | PAL_44511A |  | I7 - (not connected) |
| I8 | PAL_44303B |  | I8 |
| I9 | PAL_44304E |  | I9 |
| IBAPR_n | PAL_44304E, BIF_5, BIF_DPATH_9 |  | I6, Input Bus Address Parity Register, Bus Address Present |
| IBDAP_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 |  | Input Bus Data Present, Input Bus Address Present, IBDAP_n - Bus Data Address Present |
| IBDRY_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 |  | Input Bus Data Ready, IBDRY_n - Bus Data Ready |
| IBINPUT_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8, MEM_43 |  | Input Bus Input, Input Bus Input (0=Input, 1=Output), IBINPUT_n - Bus Input, Bus Input Enable |
| IBINT10_n | CPU_PROC_32, CPU_PROC_CGA_33 |  | Input Interrupt 10, Internal Bus Interrupt 10, active low |
| IBINT11_n | CPU_PROC_32, CPU_PROC_CGA_33 |  | Input Interrupt 11, Internal Bus Interrupt 11, active low |
| IBINT12_n | CPU_PROC_32, CPU_PROC_CGA_33 |  | Input Interrupt 12, Internal Bus Interrupt 12, active low |
| IBINT13_n | CPU_PROC_32, CPU_PROC_CGA_33 |  | Input Interrupt 13, Internal Bus Interrupt 13, active low |
| IBINT15_n | CPU_PROC_32, CPU_PROC_CGA_33 |  | Input Interrupt 15, Internal Bus Interrupt 15, active low |
| IBPERR_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 |  | Input Bus Parity Error, IBPERR_n - Bus Parity Error |
| IBREQ_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 |  | Input Bus Request, IBREQ_n - Bus Request |
| ICA_15_0 [15:0] | CGA_MAC_APOS_CALCA |  | CPU Address Input (16 bits) |
| IDB_15_0_IN [15:0] | CPU_CS_16, CPU_CS_TCV_20, CPU_MMU_24, CPU_PROC_32 |  | IDB 15 bit input, 16 bit IDB IN (when writing to CSBITS), Internal data bus input, 16 bits, Input IDB 15-0 |
| IDB_15_0_OUT [15:0] |  | BIF_5, BIF_DPATH_9, CPU_CS_TCV_20, CPU_MMU_24, CPU_PROC_32, IO_UART_42, MEM_43 | Internal Bus Data (IBD) 16 bit OUT, Internal Data Bus OUT, 16 bits IDB OUT (when reading a 16 bit word from CSBITS), Internal data bus output, 16 bits, Output IDB 15-0, Internal Data Bus 15:0 OUT, Bus Data 15:0 |
| IDB_7_0_IN [7:0] | IO_UART_42 |  | Internal Data Bus 7:0 IN |
| IDB0 |  | DECODE_DGA_POW | IDB 0 |
| IDB1 |  | DECODE_DGA_POW | IDB 1 |
| IDB2 | PAL_44408B | DECODE_DGA_POW | B1_n - IDB2, IDB 2 |
| IDBI2 | DECODE_DGA_COMM |  | Internal data bus input bit 2 |
| IDBI5 | DECODE_DGA_COMM |  | Internal data bus input bit 5 |
| IDBI7 | DECODE_DGA_COMM |  | Internal data bus input bit 7 |
| IDBS0 | PAL_44407A |  | I0 - CSIDBS0 |
| IDBS1 | PAL_44407A |  | I1 - CSIDBS1 |
| IDBS2 | PAL_44407A |  | I2 - CSIDBS2 |
| IDBS3 | PAL_44407A |  | I3 - CSIDBS3 |
| IDBS4 | PAL_44407A |  | I4 - CSIDBS4 |
| IHIT_n |  | PAL_44402D | Q3_n (not connected signal?) |
| ILCSN | CGA_MAC, CGA_MIC |  | Instruction Load Control Signal, Internal Load Control Store (negated) |
| INDN | CGA_TRAP_TBUF | CGA_DCD | IND negated, IDN_n |
| INR_7_0 [7:0] | ND3202D |  | INR 7:0 |
| INTRQ_n_tp1 |  | CPU_PROC_CGA_33 | Interrupt Request, active low, test point 1 |
| INTRQN | CGA_DCD, CGA_TRAP_TBUF | CGA_INTR | Interrupt request negated, Interrupt Request, active low, INTRQ_n |
| IOD_n | PAL_44303B, BIF_DPATH_9 | PAL_44801A, BIF_BCTL_6 | I5, Q5_n - IOD_n  (IO SIGNAL TO LAST FOR THE ENTIRE BUS CYCLE), I/O signal to last for the entire bus cycle, IO SIGNAL TO LAST FOR THE ENTIRE BUS CYCLE |
| IONI |  | CPU_15, CPU_PROC_32, CPU_PROC_CGA_33 | Interrupt System ON, I/O Non-Maskable Interrupt |
| IORQ_n | PAL_44302B, PAL_44445B, PAL_44801A, BIF_5, BIF_BCTL_6, BIF_DPATH_9, MEM_43 |  | B4_n - IO Request, I1 - IORQ_n - IO Request, I1 - IORQ_n (IO Request), IO Request, Input I/O Request, Input/Output Request, Bus Input/Output Request |
| IORQN |  | DECODE_DGA_COMM | I/O Request |
| IOXERR_n | CPU_PROC_32, CPU_PROC_CGA_33 | BIF_5, BIF_BCTL_6 | IOX Error, I/O Execute Error, I/O Error, active low |
| IOXERRN | CGA_INTR |  | IO Exception Error, active low |
| IRQ | CGA_MIC | CGA_INTR | Interrupt Request, Interrupt request signal |
| ISEMRQ_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 |  | Input Bus Semaphore Request, Input Semaphore Request, ISEMRQ_n - Semaphore Request |
| J | CGA_INTR_CNTLR_CLR |  | J |
| L | L4, L8 |  | LATCH ENABLE |
| LA_20_10 [10:0] | CPU_MMU_24, CPU_MMU_PT_29 |  | Logical address, 11 bits, 11 bit addressing into PT chips |
| LA_23_10 [13:0] |  | CPU_PROC_32, CPU_PROC_CGA_33, CGA_MAC | Local Address 23-10, Local Address, Latch Address bits 23 to 10 |
| LAA_3_0 [3:0] | CGA_ALU, CGA_INTR, CGA_WRF | CPU_PROC_CGA_33, CGA_MIC | Local Address A, A Operand. CSBITS [15:12], Latched Address A, 4-bit, Load address A bits 3 to 0, 4 bits to select A (source), for 16 different registers. |
| LAPA_n |  | CPU_MMU_24 | Latch Page Address, controls latching of the page address |
| LBA_3_0 [3:0] | CGA_ALU, CGA_WRF | CPU_PROC_32, CPU_PROC_CGA_33, CGA_MIC | B Operand (CSBITS 19:16), Local Bus Address, B Operand. CSBITS [19:16], Load address B bits 3 to 0, 4 bits to select B (destination), for 16 different registers. |
| LBA0 | PAL_44404C |  | I7 |
| LBA1 | PAL_44404C |  | I6 |
| LBA3 | PAL_44404C |  | I5 |
| LBD_15_0_IN [15:0] | BIF_DPATH_CDLBD_11 |  | Local Bus Data Input (16 bits) |
| LBD_15_0_OUT [15:0] |  | BIF_DPATH_CDLBD_11 | Local Bus Data Output (16 bits) |
| LBD_19_0 [19:0] | MEM_ADDR_44 |  | Local Bus Address and Data - 20 bits (including parity 2 bits) |
| LBD_23_0_IN [23:0] | BIF_5, BIF_DPATH_9, BIF_DPATH_BDLBD_10, MEM_43 |  | Local Bus Data 24 bit IN, Local Bus Data IN, Local Bus Address and Data 23:0 (IN) -  Address and Data for RAM |
| LBD_23_0_OUT [23:0] |  | BIF_5, BIF_DPATH_9, BIF_DPATH_BDLBD_10, MEM_43 | Local Bus Data 24 bit OUT, Local Bus Data OUT, Local Bus Address and Data 23:0 (OUT) - Data from from RAM (15:0) |
| LBD0 | PAL_45008B |  | I2 - LBD0 |
| LBD1 | PAL_45008B |  | I3 - LBD1 |
| LBD3 | PAL_45008B |  | I4 - LBD3 |
| LBD4 | PAL_45008B |  | I5 - LBD4 |
| LCA_15_0 [15:0] | CGA_MAC_ADD | CGA_MAC_APOS_CALCA | ALU Load Control Address, Local Address Output (16 bits) |
| LCC_3_0 [3:0] |  | CGA_MIC_CONDREG | Loop Counter Compare (?)  CSBIT 11:8 |
| LCS_n | PAL_44305D, PAL_44407A, PAL_44408B, CPU_CS_16, CPU_MMU_24, CPU_MMU_CSR_26, CPU_PROC_32, CPU_PROC_CGA_33, IO_UART_42 | PAL_44403C | I4 - Load Control Store (negated), Q0_n, I6 - LCS_n, B0 - Load Control Store (negated), Load Control Store (Negated), Load control store, LCS_n (LCS = Load Control Store), Local Chip Select, active low |
| LCSN | DECODE_DGA_COMM, DECODE_DGA_IDBS, CGA_DCD, CGA_MIC_CONDREG |  | Load Control Store, LCS negated signal (Load Control Store) |
| LCZN | CGA_CPU_ALU_CONTR | CGA_MIC | Loop Counter Not, Load condition zero not |
| LDDBRN |  | CGA_DCD | Latch DBR negated |
| LDEXM_n |  | PAL_44408B, CPU_15, CPU_PROC_32 | Q1_n - Command 21.3, Load Examine Mode, COMMAND 21.3 LDEXM - Load examine mode in MAC function |
| LDGPRN | CGA_CPU_ALU_CONTR | CGA_DCD | Load GPR, Latch GPR negated |
| LDIRV | CGA_CPU_ALU_CONTR, CGA_MIC | CGA_DCD | Load Instruction Register (MIC), Load IRV, Load direction vector |
| LDLCN | CGA_MIC | CGA_DCD | Load LCN |
| LDPANCN |  | DECODE_DGA_COMM | Load Panel Control |
| LDPILN |  | CGA_DCD | Load PIL negated |
| LDR_n |  | PAL_44803A | Q4_n - LDR_n (n.c.) |
| led [5:0] |  | ND120_TOP | 6-bit output for controlling LEDs |
| LED_BUS_GI |  | MEM_RAMC_50 | LED_BUS_GRANT_INDICATOR |
| LED_CPU_GI |  | MEM_43, MEM_RAMC_50 | LED_CPU_GRANT_INDICATOR |
| LED1 |  | CPU_15, CPU_MMU_24 | Cache enabled ? |
| LED4 |  | MEM_43, MEM_DATA_46 | LED4_RED_PARITY_ERROR |
| LERR_n | PAL_45001B, PAL_45009B, BIF_5, BIF_BCTL_6 | MEM_43, MEM_DATA_46 | B5_n, I7 - LERR_n, Local Error |
| LEV0 |  | PAL_44511A, CPU_15, CPU_PROC_32 | B3_n - LEV0, Level 0 active, Level 0 |
| LHIT |  | DECODE_DGA_COMM | Load Hit |
| LOAD_n | ND3202D |  | Input signal from "C PLUG", signal B12 - LOAD_n |
| LOADN | DECODE_DGA_POW |  | Load |
| LOCK_n | IO_UART_42 |  | Lock signal |
| LOEN_n | PAL_44310D, PAL_44803A, MEM_ADDR_44, MEM_LBDIF_48 | PAL_44902A, MEM_RAMC_50 | I3, I0 - LOEN_n, Q6_n - LOEN_n, Low address bits enable |
| LOEN25_n |  | PAL_44803A | Q3_n - LOEN25_n (n.c.) |
| LOERR |  | MEM_DATA_46 | Low address bits error |
| LOG | CGA_CPU_ALU_RALU |  | Logical Operation (1=Logic function (AND/OR). 0=ADD/SUB) |
| LOGSN |  | CGA_INTR | Logical Segment Number, active low |
| LOK | CGA_INTR_CNTLR_CLR |  | LO K |
| LOVEC_2_0 [2:0] | CGA_INTR_CNTLR_IRGEL_VMUX |  | Lo vector |
| LPERR_n | PAL_45001B, BIF_5, BIF_BCTL_6 | MEM_43, MEM_DATA_46 | I6 - LPERR_n, Local Parity Error |
| LSHADOW | PAL_44402D, PAL_44404C, CPU_MMU_24, DECODE_DGA_COMM, CGA_DCD | CPU_15, CPU_PROC_32, CPU_PROC_CGA_33, CGA_MAC | I2, B1_n (new input for 44404D), Latch Shadow signal, Load shadow signal, Latch Shadow, Shadow Register Load, Load shadow, Shadow latch signal |
| LUA12 | PAL_44305D, PAL_44403C |  | B5_n - Low Unit Address. Select RAM bank (0=lower,1=upper), I6 |
| LVE | CGA_INTR_CNTLR_IRGEL_VMUX |  | Lo vector Enable |
| LWCAN | CGA_MIC | CGA_DCD | Latch WCA negated, Latch WCA |
| LX_2_0_N [2:0] | CGA_INTR_CNTLR_CLR |  | input [2:0] LX_2_0,        |
| M0 | PAL_44408B |  | I6 - CSMIS0   - CSBIT #42 - ALU MIS0 SIGNAL (also used for sub-commands for CSCOMM) |
| M1 | PAL_44408B |  | I5 - CSMIS1   - CSBIT #43 - ALU MIS1 SIGNAL (also used for sub-commands for CSCOMM) |
| MA_12_0 [12:0] |  | CGA_MIC, CGA_MIC_IPOS | Memory address bits 12 to 0, Microcode Address (13 bits) |
| MACLK_n |  | PAL_44307C | Y1_n - MACLK_n   Memory Access Clock ? |
| MAP_n | PAL_44403C, CPU_PROC_32, CPU_PROC_CGA_33 | PAL_44307C | B5_n - MAP_n, I7, MAP_n (MAP = Enable Map), Memory Access Protection, active low |
| MAPN | CGA_MIC |  | MAP Opcode |
| MCA_9_0 [9:0] |  | CGA_MAC, CGA_MAC_APOS_CALCA | Microcode Address bits 9 to 0, Memory Address Output (10 bits) |
| MCL |  | ND3202D, DECODE_DGA_POW | Output-signal to "C PLIG", signal B20 MCL~ (after negation), Master Clear |
| MCLK | CPU_PROC_32, CPU_PROC_CGA_33, CGA_DCD, CGA_INTR, CGA_MAC, CGA_MAC_APOS_CALCA, CGA_MIC, CGA_MIC_CONDREG |  | Clock, Main Clock, Master Clock, Memory Clock, Main clock signal |
| MCLK_n |  | PAL_44307C | Y0_n - MCLK_n    Main Clock ? |
| MDLY_n |  | PAL_44403C | Q1_n |
| MEM_n |  | PAL_44801A | Q3_n - MEM_n (n.c.) (MEM SIGNAL TO LAST FOR ENTIRE BUS CYCLE) |
| MI | CGA_MIC |  | M bit |
| MIS_1_0 [1:0] | IO_UART_42 |  | Microcode Misc signal 1:0 |
| MIS0 | PAL_44303B, BIF_5, BIF_BCTL_6, BIF_DPATH_9 |  | I4, Microcode: Miscellaneous bit 0, Miscellaneous 0, Miscellaneous bit 0 |
| MOFF_n | PAL_44445B, PAL_44446B, PAL_44801A, PAL_44904B, BIF_5, BIF_BCTL_6 | MEM_43 | I2 - MOFF_n - Memory Off, I1 - MOFF_n, I7 - MOFF_n  (not used) (Memory OFF), I2 - MOFF_n, Memory Off |
| MOR_n | CPU_PROC_32, CPU_PROC_CGA_33, MEM_43, MEM_LBDIF_48 | BIF_5, BIF_BCTL_6 | Memory Error, Memory Operation Ready, active low |
| MOR25_n | PAL_45001B, BIF_5, BIF_BCTL_6 | MEM_43, MEM_LBDIF_48 | I5 - MOR25_n, Memory Error (25ns delayed), Memory Operation Ready 25ns delayed, Memory Request (Delayed 25ns), Memory Error (Delayed 25ns) |
| MORN | CGA_INTR |  | MOR signal, active low (Memory Error) |
| MR_n | PAL_44310D, PAL_44403C, PAL_44801A, PAL_44803A, PAL_44902A, PAL_45001B, PAL_45008B, PAL_45009B, CPU_PROC_32, CPU_PROC_CGA_33, MEM_43, MEM_DATA_46, MEM_LBDIF_48, MEM_RAMC_50 | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 | I9, I5, I2 - MR_n (Master Reset), I2 - MR_n, I4 - MR_n , I7 - MR_n, B5_n - MR_n, I9 - MR_n, Master Reset, Memory Read, active low, Master Reset (negated) |
| MREQ |  | DECODE_DGA_COMM | Memory Request |
| MREQ_n | PAL_44511A, CPU_PROC_32 |  | I5 - MREQ_n, Memory Request |
| MRN | CGA_DCD, CGA_MIC |  | MR negated signal, Memory read |
| MSIZE0_n | PAL_44904B | PAL_44445B | B0_n - MSIZE0_n (not connected?), I0 - MSIZE0_n |
| MSIZE1_n | PAL_44904B | PAL_44446B | B2_n - MSIZE1_n (not connected?), I1 - MSIZE1_n |
| MWRITE_n | PAL_44304E, PAL_45008B, BIF_5, BIF_DPATH_9, MEM_DATA_46, MEM_LBDIF_48 | PAL_44445B, PAL_44446B, MEM_43 | I3, Q3_n - MWRITE_n, I0 - MWRITE_n, Memory Write |
| MWRITE50_n | PAL_44310D | MEM_LBDIF_48 | B5, Memory Write (Delayed 50ns) |
| NL | M169C |  | Load Next |
| NLCA_15_0 [15:0] | CGA_WRF, CGA_WRF_RBLOCK | CGA_MAC | Next Latch Address bits 15 to 0, Input to P register (B=Reg2 which is P) |
| not_connected | PAL_45009B |  | I8 - |
| NOWRIT_n |  | PAL_44404C | Q0_n |
| NUBD_n |  | PAL_44402D | Q1_n  |
| NUBI_n |  | PAL_44402D | Q0_n |
| OE_n | PAL_44402D, PAL_44403C, PAL_44404C, PAL_44407A, PAL_44408B, PAL_44445B, PAL_44446B, PAL_44511A, PAL_44801A, PAL_44803A, PAL_44902A, PAL_44904B, AM29C821 |  | OUTPUT ENABLE (active-low) for Q0-Q3, OUTPUT ENABLE (active-low) for Q0-Q3 (connected to BGNT_n), OUTPUT ENABLE (active-low) for Q0-Q5 , OUTPUT ENABLE (active-low) for Q0-Q5, Output Enable (active low) |
| OER_n | AM29833A, AM29861A | PAL_45008B | Y1_n OER_n (OUT ONLY), Output enable (negated) R, Output Enable Receiver, active low |
| OET_n | AM29833A, AM29861A | PAL_45008B | B0_n - OET_n, Output enable (negated) T, Output Enable Transmitter, active low |
| OOD |  | CGA_MIC | Out of data signal |
| OPCLCS |  | PAL_44408B, CPU_15, CPU_PROC_32 | Q3_n - Command 36.2 (LCS), COMMAND 36.2 LCS - Load control store from PROM and perform a Master Clear |
| OSC | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8, MEM_43, MEM_LBDIF_48, MEM_RAMC_50 |  | Oscillator, OSC - Oscillator |
| OUBD | PAL_44402D |  | B3_n (Signal input from CHIP 21F) |
| OUBI | PAL_44402D |  | B2_n (Signal input from CHIP 21F) |
| OUTGRANT_n |  | BIF_5, BIF_BCTL_6, ND3202D | Bus OUTGRANT, Output Grant, Output-signal to "C PLIG", signal C23 OUTGRANT~ |
| OUTIDEN_n |  | ND3202D | Output-signal to "C PLIG", signal C22 OUTIDENT~ |
| OUTIDENT_n |  | BIF_5, BIF_BCTL_6 | Bus OUTIDENT, Output Identity |
| OVF | CGA_MIC | CGA_CPU_ALU_RALU | Overflow Flag |
| PA_7_0 [7:0] | IO_PANCAL_40 |  | Data from FIFO in DGA |
| PA_n | PAL_45009B, BIF_5, BIF_BCTL_6, MEM_43, MEM_DATA_46 |  | I5 - PA_n, Parity Error Address (PEA) |
| PAN_n | CPU_PROC_32, CPU_PROC_CGA_33 |  | Panel, Parity Error, active low |
| PANN | CGA_INTR, CGA_TRAP_TBUF | DECODE_DGA_POW | Panel Interrupt Vector, PAN signal, active low (Panel Interrupt), PAN_n |
| PANOSC |  | DECODE_DGA_POW | Panel Oscillator |
| PAR | AM29833A |  | Parity bit (in) |
| PAR_OUT |  | AM29833A | Parity bit (out) |
| PARERR_n | CPU_PROC_32, CPU_PROC_CGA_33 | PAL_45001B, BIF_5, BIF_BCTL_6 | B1_n - PARERR_n (out), Parity Error, Parity Error, active low |
| PARERRN | CGA_INTR |  | Parity Error, active low |
| PB | CGA_MAC_ADD |  | Select ALU register B |
| PCR_1_0 [1:0] | CGA_TRAP_TBUF | CPU_PROC_32, CPU_PROC_CGA_33 | Paging Control Register[1:0] = Ring Protection Level, Processor Control Register, PCR[1:0] |
| PCR_15_0 [15:0] |  | CGA_MAC | Program Counter Register bits 15 to 0 |
| PD |  | CGA_INTR | Power Down signal |
| PD1 | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8, BIF_DPATH_9, CPU_CS_16, CPU_PROC_32, MEM_43, MEM_RAMC_50 |  | Power Down 1, PD1 - Power Down 1, P Disable1 - Always 0 during normal operations, Powe down 1 |
| PD2 | CPU_MMU_24, CPU_MMU_CSR_26 |  | Power down 2 |
| PD3 | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8, BIF_DPATH_9, MEM_43, MEM_RAMC_50 |  | Power Down 3, PD3 - Power Down 3 |
| PD4 | MEM_43, MEM_ADDR_44, MEM_LBDIF_48 |  | Power Down 4 |
| PICMASK_15_0 [15:0] |  | CGA_INTR | PIC Mask, 16-bit |
| PICS_2_0 [2:0] |  | CGA_INTR | PIC Select, 3-bit |
| PICV_2_0 [2:0] |  | CGA_INTR, CGA_INTR_CNTLR_IRGEL_VMUX | PIC Vector, 3-bit, Prioritized Interrupt Vector |
| PIL_3_0 [3:0] | CGA_MIC | CPU_PROC_32, CPU_PROC_CGA_33 | Current Program Level, Processor Interrupt Level, Priority interrupt level bits 3 to 0 |
| PIL0 | PAL_44511A |  | I0 - PIL0 |
| PIL1 | PAL_44511A |  | I1 - PIL1 |
| PIL2 | PAL_44511A |  | I2 - PIL2 |
| PIL3 | PAL_44511A |  | I3 - PIL3 |
| PLCA | CGA_MAC_ADD |  | Select ALU Load Control Address |
| PN | M169C | CGA_MIC | Enable P, Parity not signal |
| PONI | IO_37, IO_DCD_38, IO_PANCAL_40, DECODE_DGA_COMM, CGA_DCD, CGA_MAC, CGA_MAC_PTSEL | CPU_15, CPU_PROC_32, CPU_PROC_CGA_33 | Memory Protection ON, PONI=1, Memory Management ON |
| POWFAIL_n | CPU_PROC_32, CPU_PROC_CGA_33 |  | Power Fail, Power Fail, active low |
| POWFAILN | CGA_INTR | DECODE_DGA_POW | Power Fail, Power Failure, active low |
| POWSENSE | DECODE_DGA_POW |  | Power Sense. If high, power is good. If low, will trigger POWFAILN after some clock cycles. (1.2s delay?) |
| POWSENSE_n | ND3202D |  | Input signal from "C PLUG", signals A29,B29,C29 - POWSENSE_n (Power sense signal from the PSU?) |
| PPN_23_10 [13:0] | BIF_DPATH_9 |  | Physical Page Number |
| PPN_23_19 [4:0] | MEM_43 |  | Physical Page Number Bits 23:19 |
| PPN_25_10_IN [15:0] | CPU_MMU_24, CPU_MMU_PT_29 |  | Physical page number input, 16 bits, Physical Page Number (PPN) Bidirectional PPN (in) (bit 23-10 in the calculated physical address) |
| PPN_25_10_OUT [15:0] |  | CPU_MMU_24, CPU_MMU_PT_29 | Physical page number output, 16 bits, Physical Page Number (PPN) Bidirectional PPN (out) (bit 23-10 in the calculated physical address) |
| PPN19 | PAL_44445B |  | I3 - PPN19   Not in use in logic. Uncomment when needed. |
| PPN20 | PAL_44445B |  | I4 - PPN20 |
| PPN21 | PAL_44445B |  | I5 - PPN21 |
| PPN22 | PAL_44445B |  | I6 - PPN22 |
| PPN23 | PAL_44445B |  | I7 - PPN23 |
| PPOSC | IO_UART_42 |  | Panel Oscillator |
| PR_15_0 [15:0] | CGA_MAC | CGA_WRF, CGA_WRF_RBLOCK | ALU P Register, Direct output from P register (register #2) |
| PRB | CGA_MAC_ADD |  | Select Microcode register B |
| PRD_n |  | SIP1M9 | Parity bit |
| PRQN | DECODE_DGA_POW | DECODE_DGA_IDBS | Panel Request (Read MIPANS), Panel Request |
| PS_n | PAL_45009B, BIF_5, BIF_BCTL_6, MEM_43 |  | I3 - PS_n, Parity Error Signal (PES) |
| PT_15_0_IN [15:0] | CPU_MMU_PT_29 |  | Bidirectional PT (in) |
| PT_15_0_OUT [15:0] |  | CPU_MMU_PT_29 | Bidirectional PT (out) |
| PT_15_9 [6:0] | CPU_PROC_32, CPU_PROC_CGA_33, CGA_TRAP_TBUF |  | Page Table 15-9, Page Table bits, PT[15:9] |
| PT_15_9_OUT [6:0] |  | CPU_MMU_24 | Page Table data output, top 7 bits |
| PWCL | DECODE_DGA_POW |  | Power Control |
| PX | CGA_MAC_ADD |  | Select ALU register X |
| q |  | D_FLIPFLOP_SIMPLE | Q out |
| Q |  | SCAN_FF | Q output |
| Q_2_0_n [2:0] |  | BIF_BCTL_6 | State bits 0-2 |
| Q0 | CGA_CPU_ALU_CONTR |  | Q0 |
| Q0_n | PAL_44302B |  | I0 |
| Q1_n |  | PAL_44511A | Q1_n - (not connected) |
| Q15 | CGA_CPU_ALU_CONTR |  | Q15 |
| Q2_n | PAL_44302B | PAL_44511A | I1, Q2_n - (not connected), Q3_n - (not connected) |
| Q4_n |  | PAL_44904B | Q4_n - (n.c.) |
| Q8 [7:0] |  | SIP1M9 | DATA OUTPUT (8-bit) |
| Q9 |  | SIP1M9 | DATA OUTPUT (1-bit) |
| QA |  | M169C | Output A |
| QA_n |  | PAL_44902A | Q0_n - QA_n (n.c.) |
| QB |  | M169C | Output B |
| QB_n |  | PAL_44902A | Q1_n - QB_n (n.c.) |
| qBar |  | D_FLIPFLOP_SIMPLE | QBar out |
| QC |  | M169C | Output C |
| QC_n |  | PAL_44902A | Q2_n - QC_n (n.c.) |
| QD |  | M169C | Output D |
| QD_n | PAL_45008B, MEM_DATA_46 | PAL_44902A, MEM_RAMC_50 | Q3_n - QD_n, B4_n - QD_n, Parity Error Signal (PES), Clock D signal |
| QN |  | SCAN_FF | Q_n output |
| R [7:0] | AM29833A |  | R in |
| R_OUT [7:0] |  | AM29833A | R out |
| RAS | PAL_44310D, MEM_LBDIF_48 | PAL_44902A, MEM_RAMC_50 | B2, Q4_n - RAS (RAM Row Address Strobe), Row Address Strobe |
| RAS_n | SIP1M9 |  | Row address strobe |
| RB_15_0 [15:0] | CGA_MAC, CGA_MAC_ADD, CGA_WRF, CGA_WRF_RBLOCK |  | Microcode Register B, Register B DATA (Destination) for WRITE. 16 bits to select register(s) |
| RDATA | PAL_45009B, MEM_DATA_46 | PAL_44310D, MEM_LBDIF_48 | Y1, I0 - RDATA25 signal (doesnt match name), Read Data |
| RDATA25 |  | MEM_LBDIF_48 | Read Data (Delayed 25ns) |
| REF_n | MEM_43, MEM_LBDIF_48 | PAL_44801A, BIF_5, BIF_BCTL_6 | Q4_n - REF_n  (REFRESH GRANT ON ND100 BUS), Refresh, Refresh Request |
| REF100_n | PAL_44310D |  | B3 |
| REFN | DECODE_DGA_POW |  | Refresh |
| REFRQ_n | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8, MEM_43 |  | Refresh Request, REFRQ_n - Refresh Request |
| REFRQ50_n | PAL_44801A | BIF_BCTL_SYNC_8 | I4 - REFRQ50_n (Refresh Request (50ns delayed)), REFRQ50_n - Refresh Request (50ns delayed) |
| REFRQN |  | DECODE_DGA_POW | Refresh Request |
| RERR_n | PAL_45009B, MEM_43 | PAL_45001B, BIF_5, BIF_BCTL_6 | B2_n, I4 - RERR_n, Refresh Error |
| RESET | DECODE_DGA_POW | DECODE_DGA_COMM | Reset signal, Reset |
| RESTR | CGA_MIC |  | input        SPARE,         Spare signal for future use |
| RET_12_0 [12:0] |  | CGA_MIC_STACK | Return Microcode Address (13 bits) |
| RF_1_0 [1:0] |  | CPU_PROC_32, CPU_PROC_CGA_33, CGA_MIC | Selects which of the 4 16 bit's of the microcode to fetch from ROM, Register File, Register file bits 1 to 0 |
| RGNT_n | PAL_44902A | PAL_44803A, MEM_RAMC_50 | Q0_n - RGNT_n, I0 - RGNT_n (RAM Grant), RAM Grant |
| RINRN |  | DECODE_DGA_IDBS | Read Installation Number from B-PLUG (RINR) - IDBS=35 |
| RLRQ_n | PAL_44803A, MEM_RAMC_50 |  | I1 - RLRQ_n, RAM Load Request |
| RN_15_0 [15:0] | CGA_CPU_ALU_RALU |  | R(15:0) negated |
| RRF_n | PAL_44404C | PAL_44407A, CPU_15, CPU_PROC_32 | B0_n, Q0_n - RRF_n  (CSIDBS source 5, REG), Output RRF signal from CPU to CYCLE, Read REG Flag - CSIDBS Source = 5 (REG) |
| RSN | CGA_CPU_ALU_RALU |  | RS (1=Subtract. 0=Add) |
| RT_n | PAL_44302B, PAL_44402D, BIF_5, BIF_DPATH_9, CPU_MMU_24 | PAL_44408B, CPU_PROC_32 | B5_n - Return, I1, Q5_n, Return, RT_n - Return, Return signal |
| RTN |  | DECODE_DGA_COMM | Return |
| RTOSC | DECODE_DGA_POW |  | Real Time Oscillator |
| RUART_n | IO_UART_42 |  | Read UART (HIGH=Write UART) |
| RUARTN |  | DECODE_DGA_IDBS | Read UART - 37 |
| RWCS_n | PAL_44305D, PAL_44307C, CPU_CS_16 | PAL_44408B, CPU_PROC_32 | I5 - Read/Write Control Store (low=write), I7 Read Write Cycle Start, Q4_n - Command 36.1 (RWCS), Read/Write Control Store (low=write), COMMAND 36.1 RWCS - Read/write control store as addressed by ADCS command |
| RWCSN |  | DECODE_DGA_COMM | Read Write Control Store |
| RXD | IO_UART_42 |  | RS232 Receive |
| S_15_0 [15:0] | CGA_CPU_ALU_RALU |  | S(15:0) |
| SAPR |  | PAL_44304E | B3_n |
| SC_6_3 [3:0] |  | CGA_MIC | Status control bits 6 to 3 |
| SC3 | CGA_MIC_STACK |  | SC[4:3] values - 00:HOLD, 01:POP, 10:LOAD, 11:PUSH |
| SC5 | CGA_MIC_MASEL_REPEAT |  | Selector SC5 |
| SC6 | CGA_MIC_MASEL_REPEAT |  | Selector SC6 |
| SEL_TESTMUX [2:0] | CPU_PROC_32, CPU_PROC_CGA_33 |  | Selects testmux signals to output on TEST_4_0 |
| SEL5MS_n | ND3202D |  | SEL5MS if active will trigger RTC after 5 ms, not 20ms) |
| SEL5MSN | DECODE_DGA_POW |  | Select 5ms (if active will trigger RTC after 5 ms, not 20ms) |
| SEM_n |  | PAL_44801A | Q0_n - SEM_n  (SEMAPHORE GRANT SIGNAL) |
| SEMRQ_n |  | BIF_5, BIF_BCTL_6 | Semaphore Request |
| SEMRQ50_n | PAL_44801A, PAL_44803A, MEM_43, MEM_RAMC_50 | BIF_5, BIF_BCTL_6, BIF_BCTL_SYNC_8 | I6 - SEMRQ50_n (Semaphore Request (50ns delayed)), I6 - SEMRQ50_n, Semaphore Request (Delayed 50ns), Semaphore Request 50ns delayed, SEMRQ50_n - Semaphore Request (50ns delayed), Semaphore Request, Bus Semaphore Request (Delayed 50ns) |
| SGR | CGA_DCD | CGA_CPU_ALU_RALU | Sign Greater Than, Segment register |
| SHORT_n | PAL_44601B |  | B1_n - SHORT_n  - SHORT Cycle |
| SHORTN |  | DECODE_DGA_COMM | Short cycle active |
| SIOCN |  | DECODE_DGA_COMM | Serial I/O Control |
| SLCOND_n | PAL_44404C | PAL_44403C | B2_n |
| SLOW_n | PAL_44601B |  | B0_n - SLOW_n   - SLOW Cycle |
| SLOWN |  | DECODE_DGA_COMM | Slow cycle active |
| SPEA | BIF_DPATH_9 | PAL_45001B, BIF_BCTL_6 | Y0_n (OUT Only), Signal PEA, SPEA - Signal PEA Load |
| SPEAL |  | PAL_45009B | Y1_n (OUT ONLY) |
| SPES | BIF_DPATH_9 | PAL_45001B, BIF_BCTL_6 | Y1_n (OUT ONLY), Signal PES, SPES - Signal PES Load |
| SPESL |  | PAL_45009B | Y0_n (OUT Only) |
| SSEMA_n | PAL_44803A, BIF_5, BIF_BCTL_6, MEM_43, MEM_RAMC_50 |  | I5 - SSEMA_n, Semaphore, Bus Semaphore Enable |
| SSEMAN |  | DECODE_DGA_COMM | Serial Semaphore |
| SSTOPN | DECODE_DGA_POW | DECODE_DGA_COMM | Set Stop Flip-Flop, Set Stop Flip-Flop (When next FETCH is performed the microcproram is forced to microaddress 16 (Panel Interrupt) - Microcode command 14 |
| STARTN | DECODE_DGA_POW | DECODE_DGA_COMM | Start signal, Start |
| STAT_4_3 [1:0] | IO_DCD_38 |  | Status bits 4 and 3 from PANEL/CALENDAR CPU 68705 |
| STAT3 | DECODE_DGA_IDBS |  | Status bit 4 from PANEL/CALENDAR CPU 68705 |
| STAT4 | DECODE_DGA_IDBS |  | Status bit 4 from PANEL/CALENDAR CPU 68705 |
| STOCN |  | DECODE_DGA_COMM | Stop signal |
| STOP_n | ND3202D |  | Input signal from "C PLUG", signal B16 - STOP_n |
| STOPN | DECODE_DGA_POW |  | Stop |
| STP | CPU_MMU_24, CGA_MIC |  | Stop signal, Stop control signal |
| STPN |  | DECODE_DGA_POW | Stop |
| STS6 | CGA_CPU_ALU_CONTR |  | STS bit 6 (Carry Flag - C) - SSC |
| STS7 | CGA_CPU_ALU_CONTR |  | STS bit 7 (Multishift Flag - M) - SSM |
| SW1_CONSOLE | CPU_MMU_24 |  | Switch on the console (on/off) |
| SWDIS_n | PAL_45008B |  | I1 - SWDIS_n (SW4 - Parity disable, normal position = down. |
| sys_rst_n | BIF_5, CPU_CS_16, CPU_CS_PROM_19, CPU_MMU_PT_29, CPU_PROC_CGA_33, IO_UART_42, ND3202D, SIP1M9, CGA_WRF_RBLOCK |  | System reset in FPGA |
| sysclk | ND120_TOP, BIF_5, CPU_CS_16, CPU_CS_PROM_19, CPU_MMU_PT_29, CPU_PROC_CGA_33, IO_UART_42, ND3202D, SIP1M9, CGA_WRF_RBLOCK |  | System Clock, System clock in FPGA |
| T [7:0] | AM29833A |  | T in |
| T_OUT [7:0] |  | AM29833A | T out |
| TBMT_n |  | IO_UART_42 | Transmit Buffer Empty |
| TCLK | CGA_TRAP_TVGEN_P2 |  | TRAP CLOCK |
| TE | SCAN_FF |  | T enable |
| TERM_n | PAL_44302B, PAL_44305D, PAL_44307C, BIF_5, BIF_BCTL_6, BIF_DPATH_9, CPU_PROC_32 | PAL_44601B | I8 - Terminate Cycle, I9 - Terminate signal, active-low, I0 Bus Cycle Terminate, Q1_n - TERM_n  (Trigger clock signal that latches CS input signals and more), Terminate Bus Cycle, TERM_n - Terminate |
| TEST | PAL_44302B, PAL_44303B, PAL_44304E, PAL_45001B, PAL_45009B |  | B3_n  (PD3), I7 - PD1, I8 - PD3, B4_n - PD3, I6 - PD4 |
| TEST_4_0 [4:0] |  | CPU_PROC_32, CPU_PROC_CGA_33 | Test signals 4-0, Test output |
| TESTE | DECODE_DGA_POW |  | Test Enable |
| TESTO |  | DECODE_DGA_POW | Test Output |
| TI | SCAN_FF |  | T Input |
| TN | M169C | CGA_MIC | Enable T, Trap not signal |
| TOUT | BIF_5, BIF_BCTL_6 | DECODE_DGA_POW | Timeout, Time Out |
| TP1_INTRQ_n |  | CPU_15, CPU_PROC_32 | Testpoint1 - Interrupt Request, Test point TP1 Interrupt Request |
| TRAALDN |  | DECODE_DGA_IDBS | Read Automatic Load Descriptor and print-status (ALD) - 26 |
| TRAP_n | PAL_44307C | CPU_PROC_CGA_33 | I8 Trap, Trap, active low |
| TRAPN | CGA_MIC | CPU_15, CPU_PROC_32 | Enable TRAP signal, Trap, Trap signal (negated) |
| TSEL_3_0 [3:0] |  | CGA_MIC_CONDREG | Test Select. CSBIT 7:4 |
| TST_n |  | PAL_45008B | B3_n - TST_n (n.c) |
| TVEC_3_0 [3:0] | CGA_MIC | CGA_TRAP_TVGEN_P2 | Trap vector bits 3 to 0, TRAP VECTOR (4 bits) |
| TXD |  | IO_UART_42 | RS232 Transmit |
| uartRx | ND120_TOP |  | UART Receive pin |
| uartTx |  | ND120_TOP | UART Transmit pin |
| UCLK | CPU_MMU_24, CPU_PROC_32, CPU_PROC_CGA_33, DECODE_DGA_COMM | PAL_44307C | B3_n - UCLK      Update Clock ? (A universal clock signal for memory requests), User clock, U clock |
| UP | M169C |  | Up/Down (1=Up, 0=Down) |
| UPN | CGA_CPU_ALU_CONTR | CGA_MIC | Up, Update not signal |
| USED_n |  | PAL_44402D | B0_n |
| VACCN | CGA_TRAP_TBUF | CGA_DCD | Violation access negated, VACC_n |
| VAL |  | DECODE_DGA_IDBS | Panel Interrupt (Panel Status Register bit 12 on read) |
| VEX | PAL_44307C, CGA_DCD | PAL_44408B, CPU_15, CPU_PROC_32, CGA_MAC | I9 Vector Exception (Disable Traps), Q2_n - Violation Exception, Vector Exception, Violation exception, Vector EXecute signal |
| W_n | SIP1M9 |  | Read/Write signal |
| WAIT1 | PAL_44601B |  | I3 - WAIT1 |
| WAIT2 | PAL_44601B |  | I4 - WAIT2 |
| WBD_n | BIF_DPATH_BDLBD_10 | PAL_44303B, BIF_DPATH_LDBCTL_12 | Y0_n - Write Bus Direction, Write Bus Data, Direction from LBD to BD (LBD to BD transceiver) |
| WCA_n | PAL_44305D, PAL_44511A, CPU_PROC_32 | PAL_44402D, CPU_MMU_24 | B4_n - WRITE INTO MICROINSTRUCTION CACHE (negated), B1_n (new input for 44404D), I6 - WCA_n, Write Cache Address, controls writing to the cache address register, Write Cache Address |
| WCHIM_n | CPU_MMU_24 |  | Write cache inhibit |
| WCHIMN |  | DECODE_DGA_COMM | Write Cache Miss |
| WCLIM_n | CPU_MMU_PT_29 |  | Write to RAM chip with 1 bit Data being PPN hi bit (bit ppn 25) |
| WCS_n | PAL_44305D, CPU_CS_TCV_20 | CPU_PROC_32, CPU_PROC_CGA_33 | I6 - Write Control Store (negated), Write Control Store (negated), Write Control Store, Write Control Store, active low |
| WCSN |  | CGA_MIC | Write control signal not |
| WCSTB_n |  | PAL_44305D | Y1_n - (e+f) WRITE PULSE TO WRITEABLE | (m+n) WRITE PULSE DURING LOAD CONTROL |
| WICA_n |  | PAL_44305D | Y0_n - WRITE PULSE TO MICROINSTRUCTION CACHE |
| WLBD_n | BIF_DPATH_CDLBD_11 | PAL_44303B, BIF_DPATH_LDBCTL_12 | B0_n - Write Local Bus Direction, Write Local Bus Data, Direction from CD to LBD (LBD to BD transceiver) |
| WMAP_n | CPU_MMU_PT_29 |  | Write MAPPING signal |
| WPN | CGA_DCD | CGA_WRF | Write protect negated, Enable write to WR2 Negated (P register) (from WR_15_0) |
| WR_15_0 [15:0] | CGA_WRF_RBLOCK |  | Register B DATA (select) for WRITE. 16 bits to select register(s) |
| WR3 |  | CGA_WRF | Enable write to WR3 (B register) (from WR_15_0) |
| WR7 |  | CGA_WRF | Enable write to WR7 (X register) (from WR_15_0) |
| WRFSTB | CPU_PROC_32 | PAL_44307C | B0_n - WRFSTB    Write Strobe ?, Write Register File Strobe |
| WRITE | PAL_44303B, PAL_44445B, BIF_5, BIF_DPATH_9, CPU_MMU_24, MEM_43 | DECODE_DGA_COMM | I6, I0 - WRITE - Write to memory, Write, WRITE - Write, Write enable, Write Cycle Active |
| WRITEN | CGA_TRAP_TBUF | CGA_DCD | Write enable negated, WRITE_n |
| WRTRF | PAL_44407A, CPU_PROC_CMDDEC_34 | CPU_PROC_CGA_33, CGA_DCD | I5 - WRTRF (Write to registry file), Write Register File, Write to Registry File (enable flag), Write TRF |
| XEDON | CGA |  | Enable IDB "data out" from CGA |
| XFETCHN | CGA_CPU_ALU_CONTR, CGA_WRF, CGA_WRF_RBLOCK | CGA_DCD | XFetch, XFETCH negated, Input to P register |
| XPONI |  | CGA | Memory Protection ON, PONI=1 |
| XR_15_0 [15:0] | CGA_MAC, CGA_MAC_ADD | CGA_WRF, CGA_WRF_RBLOCK | X Register, X register from ALU, Direct output from B register (register #7) |
| XTR | IO_UART_42 |  | External Transmit/Receive Clock (not used) |
| Y [9:0] |  | AM29C821 | 10 Bit Data Outputs |
| Y_IN [9:0] | AM29861A |  | Transmitter Data Bus - input (read right, write left) |
| Y_OUT [9:0] |  | AM29861A | Transmitter Data Bus - output |
| Y1_n |  | PAL_44304E | Y1_n |
| Z | CGA_INTR |  | Error flag from ALU |
| ZF | CGA_DCD, CGA_MIC | CGA_CPU_ALU_RALU | Zero Flag |
