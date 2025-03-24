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


void addDevices();
void proccess_bif_signal(VND120_TOP *top);