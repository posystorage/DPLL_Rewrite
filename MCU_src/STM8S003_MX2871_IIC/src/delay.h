#ifndef _DELAY_H_
#define _DELAY_H_
#include "stm8s.h"
#include "max2891_pll_conf.h"

//void delay_init(u8 clk); //延时函数初始化
void delay_us(uint16_t nus);  //us级延时函数,最大65536us.
void delay_ms(uint32_t nms);  //ms级延时函数



#endif