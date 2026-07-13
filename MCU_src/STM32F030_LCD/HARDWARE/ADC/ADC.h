#ifndef _ADC_H_
#define _ADC_H_
#include "stm32f0xx.h"

void ADC_DMA_Init(void);

void ADC_Tick_Service(void);

void ADC_Data_Service(void);

extern int16_t ADC_VBIAS_Voltage;
extern uint8_t ADC_Value_Valid;

#endif
