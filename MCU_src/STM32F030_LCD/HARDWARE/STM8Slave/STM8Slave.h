#ifndef _STM8_SLAVE_H_
#define _STM8_SLAVE_H_

#include "stm32f0xx.h"
#include "control_protocol.h"

extern uint8_t STM8_Control_Bank[CTRL_BANK_SIZE];

#define STM8_LINK_ONLINE          0U
#define STM8_LINK_ARM_OFFLINE     1U
#define STM8_LINK_STM8_OFFLINE    2U
#define STM8_LINK_PROTOCOL_ERROR  3U
#define STM8_LINK_CRC_ERROR       4U

void STM8Slave_Init(void);
void STM8Slave_MAX2871_ON_CMD(void);
void STM8Slave_MAX2871_OFF_CMD(void);
void STM8Slave_PLL_ON_CMD(void);
void STM8Slave_PLL_OFF_CMD(void);
uint8_t STM8_Slave_Reset_Frequency_Meter(void);

void STM8_Slave_Set_MAX2871_Freq_Power(void);
uint8_t STM8_Slave_Set_Debug_DAC_Preset(uint8_t preset);
uint8_t STM8_Slave_Send_PLL_Cfg(void);
uint8_t STM8_Slave_Read_Status(void);
uint8_t STM8_Slave_Wait_Status(void);
uint8_t STM8_Slave_Get_Link_State(void);
void STM8_Slave_EEPROM_Write_Trigger(void);
void STM8_Slave_EEPROM_Writer_Time_Service(void);
void STM8_Slave_EEPROM_Write_Service(void);

uint16_t STM8_Bank_Get_U16(uint8_t offset);
uint32_t STM8_Bank_Get_U32(uint8_t offset);
int32_t STM8_Bank_Get_S32(uint8_t offset);
void STM8_Bank_Put_U16(uint8_t offset, uint16_t value);
void STM8_Bank_Put_U32(uint8_t offset, uint32_t value);

#endif
