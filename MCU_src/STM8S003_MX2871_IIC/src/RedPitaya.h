#ifndef _PED_PITAYA_H_
#define _PED_PITAYA_H_

#include "max2891_pll_conf.h"


void RedPitaya_Uart_Init(void);

uint8_t RedPitaya_CMD_WRITE_CFG_DATA(void);
uint8_t RedPitaya_CMD_READ_STATUS_DATA(void);
uint8_t RedPitaya_CMD_PLL_ON(void);
uint8_t RedPitaya_CMD_PLL_OFF(void);
uint8_t RedPitaya_CMD_CMD_RESET(void);

#endif
