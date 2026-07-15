#ifndef _IIC_H_
#define _IIC_H_
#include "max2891_pll_conf.h"
#include "control_protocol.h"



void IIC_Slave_Init(void);



#define IIC_REG_SIZE CTRL_BANK_SIZE
extern volatile uint8_t IIC_CMD;
extern volatile uint8_t IIC_Reg_Buff[IIC_REG_SIZE];





#endif
