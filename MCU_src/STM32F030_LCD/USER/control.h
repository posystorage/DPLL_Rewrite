#ifndef _CONTROL_H_
#define _CONTROL_H_
#include "stm32f0xx.h"

extern uint32_t Set_Frequency;
extern uint32_t Set_Amplitude;
extern int32_t Set_UpperLimit;
extern int32_t Set_LowerLimit;

void Ctrl_KEY_Response_Service(void);
void Ctrl_Data_Init(void);
void Ctrl_Dispaly_Refresh_Timer_Service(void);
void Ctrl_Dispaly_Refresh_Show_Status(void);












#endif
