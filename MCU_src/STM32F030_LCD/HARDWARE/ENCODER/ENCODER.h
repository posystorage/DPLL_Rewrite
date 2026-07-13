#ifndef _ENCODER_AND_KEY_H_
#define _ENCODER_AND_KEY_H_
#include "stm32f0xx.h"
void ENCODER_KEY_Init(void);
void ENCODER_KEY_Service(void);

extern uint16_t Key_Value;

#define Econder_State_UP 0x01
#define Econder_State_DOWN 0x02
#define KEY1_Short_Press 0x04
#define KEY1_Long_Press 0x08
#define KEY2_Short_Press 0x10
#define KEY2_Long_Press 0x20
#define KEY3_Short_Press 0x40
#define KEY3_Long_Press 0x80
#define KEY4_Short_Press 0x100
#define KEY4_Long_Press 0x200
#define KEY5_Short_Press 0x400
#define KEY5_Long_Press 0x800
//#define Econder_State_KEY_Double_Press 0x10


#define Key_Long_Press_Time 500//500ms
#define Key_Short_Press_Time 3//3ms
//#define Key_Double_Press_Time 250//200ms

#endif
