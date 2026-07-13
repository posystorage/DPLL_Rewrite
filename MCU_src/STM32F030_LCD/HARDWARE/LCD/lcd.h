#ifndef __LCD_H
#define __LCD_H		
//#include "usart.h"
#include "delay.h"
#include "stm32f0xx.h"


extern uint16_t BACK_COLOR;


//画笔颜色
#define WHITE        0xFFFF
#define BLACK        0x0000	  
#define BLUE         0x001F  
#define BRED         0XF81F
#define GRED 			   0XFFE0
#define GBLUE			   0X07FF
#define RED          0xF800
#define MAGENTA      0xF81F
#define GREEN        0x07E0
#define CYAN         0x7FFF
#define YELLOW       0xFFE0
#define BROWN 			 0XBC40 //棕色
#define BRRED 			 0XFC07 //棕红色
#define GRAY  			 0X8430 //灰色
//GUI颜色

#define DARKBLUE     0X01CF	//深蓝色
#define LIGHTBLUE    0X7D7C	//浅蓝色  
#define GRAYBLUE     0X5458 //灰蓝色
//以上三色为PANEL的颜色 
 
#define LIGHTGREEN   0X841F //浅绿色 
#define LGRAY 			 0XC618 //浅灰色(PANNEL),窗体背景色

#define LGRAYBLUE    0XA651 //浅灰蓝色(中间层颜色)
#define LBBLUE       0X2B12 //浅棕蓝色(选择条目的反色)

#define LIGHTCYAN    0XC7FF //
#define INDIANRED    0XCAAA // 	IndianRed3
#define DARKGREEN    0X0500 //darkgreen


void LCD_Init(void);
void LCD_Clear(uint16_t color);
void LCD_Show_Buaa_Logo(void);
void LCD_SHOW_ASCII_1608(uint16_t x,uint16_t y,uint8_t data,uint16_t color);
void LCD_SHOW_ASCII_0806(uint16_t x,uint16_t y,uint8_t data,uint16_t color);
void LCD_SHOW_HANZI(uint16_t x,uint16_t y,uint8_t data_Num,uint16_t color);
void LCD_SHOW_Icon_1612(uint16_t x,uint16_t y,uint8_t data,uint16_t color);
void LCD_ShowString(uint16_t x,uint16_t y,uint8_t *p,uint16_t color);
void LCD_16ShowString_hanzi(uint16_t x,uint16_t y,uint8_t *p,uint16_t color);
void LCD_Show_Square(uint16_t x,uint16_t y,uint16_t wide,uint16_t high,uint16_t color);

#endif
