#include "Timer4.h"
uint16_t sys_delay;

void TIM4_Init(void)//2ms一次中断
{ 
  CLK->PCKENR1 |= 0x10;//time4 clk OPEN
  TIM4->CNTR =0;
  TIM4->CR1 =0X80;   //允许自动重载
  /* Set the Prescaler value 128*/
  TIM4->PSCR = 0x07;
  /* Set the Autoreload value 250-1*/
  TIM4->ARR = 0xF9;
  /* Enable the Interrupt sources */
  TIM4->IER = 0x01; 
  TIM4->SR1  =0X00;   //清中断标志位
  TIM4->EGR =0X00;   //更新事件产生
  /* set or Reset the CEN Bit */
  TIM4->CR1 |= TIM6_CR1_CEN;//使能
  ITC->ISPR6 &=~ 0xC0;
  ITC->ISPR6 |=  0x40;
  sys_delay=0;
}

void EEPROM_Auto_Save_Timer(void);

INTERRUPT_HANDLER(TIM4_UPD_OVF_IRQHandler, 23)
{
  TIM4->SR1=0;//清中断
  //EEPROM_Auto_Save_Timer();
}