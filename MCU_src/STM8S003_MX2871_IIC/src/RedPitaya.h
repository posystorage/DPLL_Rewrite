#ifndef _PED_PITAYA_H_
#define _PED_PITAYA_H_

#include "max2891_pll_conf.h"


void RedPitaya_Uart_Init(void);

void RedPitaya_Service(void);
void RedPitaya_2ms_Tick(void);

#endif
