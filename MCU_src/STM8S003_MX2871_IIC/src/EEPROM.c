#include "EEPROM.h"
#include "IIC.h"
#define EEPROM_Write_Addr 0x04240

const uint8_t Default_EEPROM_Data[44]=
{
  0xA5,0x00,0x00,0x03,
  0xA0,0x25,0x26,0x00,//2.5GHz
  0xA3,0x70,0x3D,0x0A,//125KHZ?不太确定
  0x01,0x00,0x01,0x00,//MUL=1 DIV=1
  0x00,0x00,0x00,0x07,//P
  0x00,0x00,0x00,0x01,//I
  0x00,0x00,0x00,0x01,//II
  0x00,0x00,0x10,0x00,//D
  0x89,0x41,0x76,0xBE,//上下限
  0x64,0x00,0x0A,0x00,//相位、频率残差阈值
  0xFF,0x7F//DAC输出幅度
};


__ramfunc void EEPROM_Store_Data(void)
{
  uint8_t i,check_sum = 0;
  for(i=3;i<44;i++)
  {
    check_sum += IIC_Reg_Buff[i];
  }
  asm("sim");    //关总中断
  do
  {
    FLASH->DUKR = 0xae;// 写入第一个密钥
    FLASH->DUKR = 0x56;// 写入第二个密钥
  } 
  while(!(FLASH->IAPSR&FLASH_IAPSR_DUL));// 等待解锁  
  FLASH->CR2 |= FLASH_CR2_PRG;
  FLASH->NCR2 &=~FLASH_NCR2_NPRG;
  
  *((unsigned char *)EEPROM_Write_Addr+0) = 0xA5;
  *((unsigned char *)EEPROM_Write_Addr+1) = check_sum;
  *((unsigned char *)EEPROM_Write_Addr+2) = 0xFF;
  for(i=3;i<44;i++)
  {
    *((unsigned char *)EEPROM_Write_Addr+i) = IIC_Reg_Buff[i];
  }  
  for(;i<64;i++)
  {
    *((unsigned char *)EEPROM_Write_Addr+i) = 0xFF;
  }
  while((FLASH->IAPSR & FLASH_IAPSR_EOP) == 0);
  FLASH->IAPSR = 0;
  asm("rim");    //开总中断
}


void EEPROM_Read_Data(void)
{
  uint8_t i,check_sum = 0;
  for(i=3;i<44;i++)
  {
    IIC_Reg_Buff[i] = *((unsigned char *)EEPROM_Write_Addr+i);
  }
  for(i=3;i<44;i++)
  {
    check_sum += IIC_Reg_Buff[i];
  }  
  if((*((unsigned char *)EEPROM_Write_Addr)==0xA5)&&(check_sum==*((unsigned char *)EEPROM_Write_Addr+1)))
  {
    IIC_Reg_Buff[2] = 0;
    return;
  }   
  for(i=0;i<44;i++)
  {
    IIC_Reg_Buff[i] = Default_EEPROM_Data[i];
  }  
  EEPROM_Store_Data();
}

