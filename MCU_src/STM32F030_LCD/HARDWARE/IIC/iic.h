#ifndef _IIC_H_
#define _IIC_H_
#include "stm32f0xx.h"


void IIC1_Init(void);
uint8_t IIC_Check_Slave(uint8_t Addr);
uint8_t IIC_Read(uint8_t Addr,uint8_t Reg,uint8_t Num,uint8_t* Data_Buff);

void IIC_Write(uint8_t Addr,uint8_t Reg,uint8_t Num,uint8_t* Data_Buff);
void IIC_Fill_Write(uint8_t Addr,uint8_t Reg,uint8_t Num,uint8_t Data);
#endif
