#ifndef _STM8_SLAVE_H_
#define _STM8_SLAVE_H_

#include "stm32f0xx.h"

void STM8Slave_Init(void);
void STM8Slave_MAX2871_ON_CMD(void);
void STM8Slave_MAX2871_OFF_CMD(void);
void STM8Slave_Write_EEPROM_CMD(void);
void STM8Slave_PLL_ON_CMD(void);
void STM8Slave_PLL_OFF_CMD(void);
void STM8Slave_PLL_RESET_CMD(void);

void STM8_Slave_Set_MAX2871_Freq_Power(void);
void STM8_Slave_Send_PLL_Cfg(void);
void STM8_Slave_Read_Status(void);
void STM8_Slave_EEPROM_Write_Trigger(void);
void STM8_Slave_EEPROM_Writer_Time_Service(void);
void STM8_Slave_EEPROM_Write_Service(void);

typedef struct
{
	uint8_t Identifier;//Read Only
	uint8_t Microwave_Source_Status;//Read Only
	uint8_t PLL_Status;//Read Only
	uint8_t Microwave_Source_Power;
	uint32_t Microwave_Source_Frequency;
	
	uint32_t PLL_Center_Frequency;
	uint16_t PLL_Mul_Index;
	uint16_t PLL_Div_Index;
	
	uint32_t PLL_Gain_P;
	uint32_t PLL_Gain_I;
	uint32_t PLL_Gain_II;
	uint32_t PLL_Gain_D;
	
	uint16_t PLL_Upper_Limit;
	uint16_t PLL_Lower_Limit;
	uint16_t PLL_Freq_Residuals_Threshold;
	uint16_t PLL_Phase_Residuals_Threshold;
	uint16_t PLL_DAC_Amplitude;
	uint16_t PLL_Freq_Residuals;//Read Only
	uint32_t PLL_Phase_Residuals;//Read Only
	uint32_t PLL_PID_OUT;//Read Only
}STM8_Slave_Data_TypeDef;

union STM8_Slave_Data_Union 
{ 
	STM8_Slave_Data_TypeDef Data_Struct; 
	uint8_t IIC_Buff[52];
};

extern union STM8_Slave_Data_Union STM8_Slave_Data;

#endif
