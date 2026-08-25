/**************************************************************************
** ND BUS BIF INTERFACE DEFINITIONS                                      **
**                                                                       **
** Processing of BIF signals                                             **
** Creation of ND BUS Devices                                            **
**                                                                       **
**                                                                       **
** Last reviewed: 22-MAR-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


#include <iostream>
#include <vector>
#include <random>
#include <ctime>
#include <string>

#include "VND120_TOP.h"
#include "VND120_TOP___024root.h" // Root-level details for updating RAM directly



#define DEBUG_BIF 0 //0=OFF Bus Interface

// C-model interrupt delivery to the CPU. The original code compared
// (interruptBits & (1<<level)) == 1, which is 0 or (1<<level) - NEVER 1 for
// level >= 1 - so BINT10..13 were ALWAYS deasserted and a C device (e.g. the
// papertape at level 12) could only be serviced by polling. 1 = deliver the
// interrupt correctly (bit set -> line asserted). Set to 0 to fall back to the
// old always-deasserted / poll-only behaviour if a boot path regresses.
#define NDBUS_ASSERT_C_INTERRUPTS 1


void addDevices();
void proccess_bif_signal(VND120_TOP *top);

#ifdef ND120_VERILOG_DEVICES
void process_verilog_tape(VND120_TOP *top);
void process_verilog_floppy(VND120_TOP *top);
void process_verilog_smd(VND120_TOP *top);
void process_verilog_wd(VND120_TOP *top);
#endif