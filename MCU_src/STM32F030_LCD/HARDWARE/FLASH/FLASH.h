#ifndef _FLASH_H_
#define _FLASH_H_

#include "stm32f0xx.h"

uint8_t FLASH_Found_The_Latest_Data(void);
void FLASH_Write_Block(void);

extern uint8_t FLASH_Mem_Cache[128];



#endif
