#ifndef _DISPLAY_H_
#define _DISPLAY_H_

#include "stm32f0xx.h"

void Display_UI_Init(void);
void Display_UI_Show_Service(void);
void Display_UI_Timer_Service(void);
uint32_t Display_UI_Get_Status(void);
void Display_UI_Blink_Show_Stop(void);

void Display_UI_Microwave_Source_Refresh_Status(void);
void Display_UI_Microwave_Source_Status(uint32_t blink);
void Display_UI_Microwave_Source_Power(uint32_t blink);
void Display_UI_Microwave_Source_Freq(uint32_t blink_bit);

void Display_UI_PLL_Enable(uint32_t blink);
void Display_UI_Show_PLL_Set_Freq(uint32_t blink_bit);
void Display_UI_Show_PLL_Mux_Div_Index(uint32_t blink_mul, uint32_t blink_div);
void Display_UI_PLL_Refresh_Status(void);

void Display_UI_Show_PLL_Gain(uint8_t row, uint32_t blink_bit);
void Display_UI_Show_PLL_Limit(uint8_t row, uint32_t blink_bit);
void Display_UI_Show_Phase_Threshold(uint32_t blink_bit);
void Display_UI_Show_Amplitude_Freq_Threshold(uint32_t amplitude_blink,
                                              uint32_t frequency_blink);

void Display_UI_PLL_Main_Page_Init(void);
void Display_UI_PLL_Vice_Page_Init(void);

#endif
