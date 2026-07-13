#ifndef _LCD_1602S_CONF_H_
#define _LCD_1602S_CONF_H_
#include "stm8s.h"
#include "delay.h"
#include "Timer4.h"
#include "EEPROM.h"
#include "IIC.h"
#include "MAX2871.h"
#include "RedPitaya.h"



#define Use_MAX2871_LD_PIN 1


#define Key_Reflesh_Speed 4//短按 //按键读取刷新速度 即至少要按2ms*（4+1）即10ms以上的时间才能被认定为一次有效的按键   必须小于245 
#define Key_Long_Press_Time 500//长按触发条件 //500*2=1s

//下为库的补充(不要修改)

typedef enum
{
  GPIO_PIN_0    = ((uint8_t)0x01),  /*!< Pin 0 selected */
  GPIO_PIN_1    = ((uint8_t)0x02),  /*!< Pin 1 selected */
  GPIO_PIN_2    = ((uint8_t)0x04),  /*!< Pin 2 selected */
  GPIO_PIN_3    = ((uint8_t)0x08),  /*!< Pin 3 selected */
  GPIO_PIN_4    = ((uint8_t)0x10),  /*!< Pin 4 selected */
  GPIO_PIN_5    = ((uint8_t)0x20),  /*!< Pin 5 selected */
  GPIO_PIN_6    = ((uint8_t)0x40),  /*!< Pin 6 selected */
  GPIO_PIN_7    = ((uint8_t)0x80),  /*!< Pin 7 selected */
  GPIO_PIN_LNIB = ((uint8_t)0x0F),  /*!< Low nibble pins selected */
  GPIO_PIN_HNIB = ((uint8_t)0xF0),  /*!< High nibble pins selected */
  GPIO_PIN_ALL  = ((uint8_t)0xFF)   /*!< All pins selected */
}GPIO_Pin_TypeDef;

#endif