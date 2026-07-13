#include "TIM16.h"
#include "LCD.h"
#include "ENCODER.h"
#include "display.h"
#include "ADC.h"
#include "STM8Slave.h"
#include "control.h"


//TIM16 use as time base timer

void TIM16_Init(void)
{
	RCC->APB2ENR |= RCC_APB2ENR_TIM16EN;
	
	NVIC_EnableIRQ(TIM16_IRQn);
	NVIC_SetPriority(TIM16_IRQn,2);
	
	TIM16->PSC = 47; //Set prescaler to 48
	TIM16->ARR = 999; //1ms 
	TIM16->DIER = TIM_DIER_UIE;//Enable interrupt on Update
	TIM16->CR1 |= TIM_CR1_CEN; //Enable counter
	TIM16->EGR |= TIM_EGR_UG; //Force update generation	
}



void TIM16_IRQHandler(void)
{
	TIM16->SR &= (uint16_t)(~TIM_SR_UIF);//Clear update interrupt
	ENCODER_KEY_Service();
	ADC_Tick_Service();
	STM8_Slave_EEPROM_Writer_Time_Service();
	Display_UI_Timer_Service();
	Ctrl_Dispaly_Refresh_Timer_Service();
}





