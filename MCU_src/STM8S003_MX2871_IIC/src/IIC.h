#ifndef _IIC_H_
#define _IIC_H_
#include "max2891_pll_conf.h"



void IIC_Slave_Init(void);



#define IIC_REG_SIZE 48
extern uint8_t IIC_CMD;
extern uint8_t IIC_Reg_Buff[IIC_REG_SIZE];





#endif
