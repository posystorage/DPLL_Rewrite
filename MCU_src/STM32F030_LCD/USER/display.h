#ifndef _DISPLAY_H_
#define _DISPLAY_H_
#include "stm32f0xx.h"

void Display_UI_Init(void);
void Display_UI_PLL_Main_Init(void);

void Display_UI_Show_Service(void);
void Display_UI_Timer_Service(void);
uint32_t Display_UI_Get_Status(void);
void Display_UI_Blink_Show_Stop(void);

void Display_UI_Microwave_Source_Refresh_Status(void);
void Display_UI_PLL_Refresh_Status(void);

void Display_UI_Microwave_Source_Status(uint32_t Blink);
void Display_UI_Microwave_Source_Power(uint32_t Blink);
void Display_UI_Microwave_Source_Freq(uint32_t Blink_Bit);

void Display_UI_Show_PLL_Set_Freq(uint32_t Blink_Bit);
void Display_UI_PLL_Enable(uint32_t Blink);
void Display_UI_Show_PLL_Amplitude(uint32_t Blink_Bit);
void Display_UI_Show_PLL_Mux_Div_Index(uint32_t Blink_Bit_Mul ,uint32_t Blink_Bit_Div);
void Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(uint32_t Blink_Bit_Freq ,uint32_t Blink_Bit_Phase);

void Display_UI_Show_PLL_Up_Down_Limit(uint32_t Blink_Bit_Up ,uint32_t Blink_Bit_Down);
void Display_UI_Show_PLL_PID_Value(uint32_t Blink_Bit_P ,uint32_t Blink_Bit_I ,uint32_t Blink_Bit_II ,uint32_t Blink_Bit_D);

void Display_UI_PLL_Main_Page_Init(void);
void Display_UI_PLL_Vice_Page_Init(void);




#endif
