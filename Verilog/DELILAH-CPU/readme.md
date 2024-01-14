# Verilog code for DELILAH-CPU

## Status for the different modules in the DELILAH CPU

| Folder           | Status        |  Test status | Comment              |
|------------------|---------------|--------------|----------------------|
| CGA_WRF          | Completed     | 4 test cases |                      |
| CGA_ALU          | In progreess  |              | ALU functions seem to work, need more testcases |
| CGA_DCD          | In progress   | Need to build testcases             |
| CGA_HELPER       | In progress   | Need to build testcases             |
| CGA_IDBCTL       | In progress   | Need to build testcases             |
| CGA_INTR         | In progress   | 4 test cases. Looking good |
| CGA_MAC          | In progress   | Need to build testcases             |
| CGA_MIC          | In progress   | Need to build testcases             |
| CGA_TRAP         | In progress   | 4 test cases. | Need to validate TRAP logic and add more testcases |
| TESTMUX          | Completed     | 26 test cases |         |
| CGA (DELILAH)    | In progress   | Need to build testcases             |

## Source code stat

The generated Verilog files contain a total of 20,372 lines.

The generated C++ files from Verilator contains (for all submodules) a total of 325,447 lines.
