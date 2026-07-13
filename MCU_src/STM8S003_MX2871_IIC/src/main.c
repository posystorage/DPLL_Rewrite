#include "max2891_pll_conf.h"


uint32_t Set_Freq;

void sys_init(void)
{
  CLK->ECKR=0;//关hse
  CLK->CKDIVR=0;//不分频
  CLK->PCKENR1=0;//吧外设都关掉，后面再只打开用的到的
  CLK->PCKENR2=0;
  
  IIC_Slave_Init();
  RedPitaya_Uart_Init();
  MAX2871_Init();
  TIM4_Init();
  asm("rim");    //开总中断
}  



void IIC_CMD_Service(void)
{
  if((IIC_CMD>=0xC0)&&(IIC_CMD<=0xC9))
  {
    switch(IIC_CMD)
    {
    case 0xC0:
      ((uint8_t*)&Set_Freq)[0]=IIC_Reg_Buff[7];
      ((uint8_t*)&Set_Freq)[1]=IIC_Reg_Buff[6];
      ((uint8_t*)&Set_Freq)[2]=IIC_Reg_Buff[5];
      ((uint8_t*)&Set_Freq)[3]=IIC_Reg_Buff[4];       
      max2871_Set_Freq_10M(Set_Freq,IIC_Reg_Buff[3]&0x03);
      MAX2871_RFOUT_ON();
      IIC_Reg_Buff[1] |= 0x01;
      break;
    case 0xC1:
      MAX2871_RFOUT_OFF();
      IIC_Reg_Buff[1] &=~ 0x01;      
      break;    
    case 0xC2:
      EEPROM_Read_Data();
      break;   
    case 0xC3:
      EEPROM_Store_Data();
      break;
    case 0xC4:
      RedPitaya_CMD_WRITE_CFG_DATA();      
      break;    
    case 0xC5:
      RedPitaya_CMD_READ_STATUS_DATA();
      break;   
    case 0xC7:
      RedPitaya_CMD_PLL_ON();
      break;
    case 0xC8:
      RedPitaya_CMD_PLL_OFF();
      break;
    case 0xC9:
      RedPitaya_CMD_CMD_RESET();
      break;
    default:
      break;
    }
    IIC_Reg_Buff[1] &= ~0x04;
    IIC_CMD = 0;
  }
}

void PLL_Lock_Read(void)
{
  if((MAX2871_LD_PORT->IDR&MAX2871_LD_PIN)==MAX2871_LD_PIN)
  {
    IIC_Reg_Buff[1] |= 0x02;
  }
  else
  {
    IIC_Reg_Buff[1] &=~ 0x02;
  }
}

void main(void)
{
  sys_init();
  delay_ms(50);
  //EEPROM_Read_Data();
  while(1)
  {
    IIC_CMD_Service();
    PLL_Lock_Read();
  }
}

