#include "stm32f0xx.h"
//#include "usart.h"
#include "delay.h"
#include "lcd.h"
#include "TIM16.h"
#include "ENCODER.h"
#include "STM8Slave.h"
#include "display.h"
#include "control.h"
#include "ADC.h"


//目前运行48mhz
int main(void)
{
	delay_init();
	LCD_Init();
	ADC_DMA_Init();
	LCD_Show_Buaa_Logo();
	delay_ms(2000);	
	ENCODER_KEY_Init();
	TIM16_Init();
	STM8Slave_Init();
	ADC_Data_Service();
	Ctrl_Data_Init();
	
	Display_UI_Init();

	while(1)
	{		
		Ctrl_KEY_Response_Service();
		ADC_Data_Service();
		Display_UI_Show_Service();
		STM8_Slave_EEPROM_Write_Service();
		Ctrl_Dispaly_Refresh_Show_Status();
	}
}



