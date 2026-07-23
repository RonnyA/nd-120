# ND-120 FPGA Debug Reference - Basys3

## LED Layout (LD15 left to LD0 right)

```
+------+------+------+------+------+------+------+------+------+------+------+------+------+------+------+------+
| LD15 | LD14 | LD13 | LD12 | LD11 | LD10 | LD9  | LD8  | LD7  | LD6  | LD5  | LD4  | LD3  | LD2  | LD1  | LD0  |
+------+------+------+------+------+------+------+------+------+------+------+------+------+------+------+------+
| TERM | CC3  | CC2  | CC1  | CC0  |  -   |  -   |  -   | LCS  | MCLK | BEAT | UART | RST  | RUN  | GRN  | RED  |
+------+------+------+------+------+------+------+------+------+------+------+------+------+------+------+------+
  ^                                                        ^             ^                                    ^
  |                                                        |             |                                    |
  Cycle state machine (ON = active)                    Microcode     Heartbeat                           CPU Error
                                                       loaded       ~1.5 Hz
```

## LED Descriptions

| LED   | Signal               | ON means                                      | OFF means                    |
|-------|----------------------|-----------------------------------------------|------------------------------|
| LD0   | CPU RED              | CPU error/halt                                | Normal                       |
| LD1   | CPU GREEN            | CPU in normal operation                       | Not running                  |
| LD2   | RUN                  | CPU executing microcode                       | OPCOM mode (halted)          |
| LD3   | RESET (sys_rst_n)    | Reset released (SW0 UP)                       | CPU held in reset            |
| LD4   | UART TX              | UART transmitting (blinks)                    | No serial output             |
| LD5   | Heartbeat            | Blinks ~1.5 Hz if clock running               | FPGA not clocked             |
| LD6   | MCLK                 | Memory clock active                           | No memory clock              |
| LD7   | LCS (loaded)         | Microcode ROM loaded (~5.7ms after reset)     | Still loading microcode      |
| LD8   | (spare)              | -                                             | -                            |
| LD9   | (spare)              | -                                             | -                            |
| LD10  | (spare)              | -                                             | -                            |
| LD11  | CC0                  | Cycle counter bit 0 active                    | -                            |
| LD12  | CC1                  | Cycle counter bit 1 active                    | -                            |
| LD13  | CC2                  | Cycle counter bit 2 active                    | -                            |
| LD14  | CC3                  | Cycle counter bit 3 active                    | -                            |
| LD15  | TERM                 | Cycle termination active                      | -                            |

## Switch Layout

```
+------+------+
| SW1  | SW0  |    (leftmost switches on Basys3)
+------+------+
| 7seg | RST  |
| sel  | ctrl |
+------+------+
```

| Switch | Signal      | UP (1)                        | DOWN (0)                      |
|--------|-------------|-------------------------------|-------------------------------|
| SW0    | sys_rst_n   | Reset released (CPU runs)     | CPU held in reset             |
| SW1    | Display sel | 7-seg shows MAC address       | 7-seg shows MIC address       |

## 7-Segment Display

```
+--------+--------+--------+--------+
| Digit3 | Digit2 | Digit1 | Digit0 |    4 hex digits
+--------+--------+--------+--------+
```

| SW1 State | Display Content         | Format   | Example  |
|-----------|-------------------------|----------|----------|
| DOWN (0)  | MIC address (CSA_12_0)  | 0000-1FFF | 0E40    |
| UP (1)    | MAC address (LA_23_10)  | 0000-3FFF | 01A0    |

**If display shows changing values** = CPU is fetching/executing
**If display shows 0000 or stuck** = CPU is not running

## UART

| Parameter | Value            |
|-----------|------------------|
| Baud rate | 115200           |
| Data bits | 8                |
| Parity    | None             |
| Stop bits | 1                |
| Flow ctrl | None             |
| TX pin    | A17 (FPGA to PC) |
| RX pin    | A18 (PC to FPGA) |

## Boot Sequence (expected)

1. Program FPGA bitstream
2. LD5 starts blinking (clock running)
3. Slide SW0 UP (release reset)
4. LD3 turns ON (reset released)
5. LD15-LD11 start cycling (cycle state machine)
6. LD7 turns ON after ~6ms (microcode loaded, LCS_n=1)
7. LD2 turns ON (CPU running)
8. 7-seg shows changing MIC addresses
9. Serial terminal shows `#` prompt (OPCOM ready)

## Vivado ILA Debug Signals

These signals have `mark_debug` attributes for Vivado ILA probing:

### Top Level (ND120_TOP)

| Signal              | Width | Description                              |
|---------------------|-------|------------------------------------------|
| s_run               | 1     | CPU run state (0=running, active low)    |
| s_debug_csa[12:0]   | 13    | MIC address (microcode fetch address)    |
| s_debug_uartTx      | 1     | UART TX line                             |
| s_debug_uartRx      | 1     | UART RX line                             |
| s_debug_cpu_led[6:0] | 7    | CPU status LEDs                          |
| s_debug_la_23_10[13:0] | 14 | MAC address upper (logical address)      |
| s_debug_ca_9_0[9:0] | 10    | MAC address lower (cache address)        |
| s_debug_cc_term[4:0] | 5    | {TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}    |
| s_debug_mclk        | 1     | Memory clock                             |
| s_debug_lcs_n       | 1     | LCS_n (0=loading, 1=microcode loaded)    |

### Signals to add for deeper debug (inside hierarchy)

| Signal Path                                    | Width | Description                    |
|------------------------------------------------|-------|--------------------------------|
| CPU_BOARD.s_term_n                             | 1     | TERM_n at board level          |
| CPU_BOARD.CPU.PROC.CGA.DELILAH.s_FIDBO_15_0   | 16    | CGA internal data bus output   |
| CPU_BOARD.CPU.PROC.CGA.DELILAH.s_FIDBI_15_0   | 16    | CGA internal data bus input    |
| CPU_BOARD.CPU.CS.s_csbits[63:0]               | 64    | TOPCSB - full microcode word   |
| CPU_BOARD.CPU.PROC.s_idb_erf_out[15:0]        | 16    | Register file output to IDB    |
| CPU_BOARD.MEM.RAM.CHIP_15H.sdram[addr]        | 8     | Main RAM content               |
| CPU_BOARD.IO.UART.CHIP_32H.txState            | 3     | UART TX state machine          |
| CPU_BOARD.IO.UART.CHIP_32H.rxState            | 3     | UART RX state machine          |

### Pin Mapping Reference (Basys3 xc7a35tcpg236-1)

| Port      | Pin  | Function          |
|-----------|------|-------------------|
| sysclk    | W5   | 100 MHz clock     |
| btn1/SW0  | V17  | Reset control     |
| btn2/SW1  | V16  | Display select    |
| uartTx    | A17  | Serial TX         |
| uartRx    | A18  | Serial RX         |
| led[0]    | U16  | LD0 - CPU RED     |
| led[1]    | E19  | LD1 - CPU GREEN   |
| led[2]    | U19  | LD2 - RUN         |
| led[3]    | V19  | LD3 - RESET       |
| led[4]    | W18  | LD4 - UART TX     |
| led[5]    | U15  | LD5 - Heartbeat   |
| led[6]    | U14  | LD6 - MCLK        |
| led[7]    | V14  | LD7 - LCS loaded  |
| led[11]   | U3   | LD11 - CC0        |
| led[12]   | P3   | LD12 - CC1        |
| led[13]   | N3   | LD13 - CC2        |
| led[14]   | P1   | LD14 - CC3        |
| led[15]   | L1   | LD15 - TERM       |
| seg[0-6]  | W7,W6,U8,V8,U5,V5,U7 | 7-seg segments |
| an[0-3]   | U2,U1,T1,R2          | 7-seg anodes   |
