#ifndef _STM8_SLAVE_H_
#define _STM8_SLAVE_H_

#include "stm32f0xx.h"
#include "control_protocol.h"

extern uint8_t STM8_Control_Bank[CTRL_BANK_SIZE];

void STM8Slave_Init(void);
void STM8Slave_MAX2871_ON_CMD(void);
void STM8Slave_MAX2871_OFF_CMD(void);
void STM8Slave_PLL_ON_CMD(void);
void STM8Slave_PLL_OFF_CMD(void);

void STM8_Slave_Set_MAX2871_Freq_Power(void);
void STM8_Slave_Send_PLL_Cfg(void);
void STM8_Slave_Read_Status(void);
void STM8_Slave_EEPROM_Write_Trigger(void);
void STM8_Slave_EEPROM_Writer_Time_Service(void);
void STM8_Slave_EEPROM_Write_Service(void);

uint16_t STM8_Bank_Get_U16(uint8_t offset);
uint32_t STM8_Bank_Get_U32(uint8_t offset);
int32_t STM8_Bank_Get_S32(uint8_t offset);
void STM8_Bank_Put_U16(uint8_t offset, uint16_t value);
void STM8_Bank_Put_U32(uint8_t offset, uint32_t value);

#endif
