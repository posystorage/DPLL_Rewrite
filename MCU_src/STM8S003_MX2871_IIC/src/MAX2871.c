#include "MAX2871.h"

//uint32_t MAX2871_Reg_Data[6]={0x00000000,0x20017D01,0x10004D42,0x00001F23,0x608C8104,0x00458005};
uint32_t MAX2871_Reg_Data[6]={0x00000000,0x20017D01,0x10004D42,0x00001F23,0x608C8124,0x00458005};
const uint32_t MAX2871_Init_Reg_Data[6]={0x00790000,0x2000CE21,0x11009EC2,0x00000283,0x63E201FC,0x01440005};

void MAX2871_GPIO_Init(void)
{ 
  MAX2871_RE_EN_PORT->ODR &=~MAX2871_RE_EN_PIN;
  MAX2871_RE_EN_PORT->DDR |= MAX2871_RE_EN_PIN;//OUT
  MAX2871_RE_EN_PORT->CR1 |= MAX2871_RE_EN_PIN;//PP
  MAX2871_RE_EN_PORT->CR2 |= MAX2871_RE_EN_PIN;//10M 
  
  MAX2871_LE_PORT->ODR |= MAX2871_LE_PIN;
  MAX2871_LE_PORT->DDR |= MAX2871_LE_PIN;//OUT
  MAX2871_LE_PORT->CR1 |= MAX2871_LE_PIN;//PP
  MAX2871_LE_PORT->CR2 |= MAX2871_LE_PIN;//10M 
    
  MAX2871_CLK_PORT->ODR &=~MAX2871_CLK_PIN;
  MAX2871_CLK_PORT->DDR |= MAX2871_CLK_PIN;//OUT
  MAX2871_CLK_PORT->CR1 |= MAX2871_CLK_PIN;//PP
  MAX2871_CLK_PORT->CR2 |= MAX2871_CLK_PIN;//10M 
  
  MAX2871_DATA_PORT->DDR |= MAX2871_DATA_PIN;//OUT
  MAX2871_DATA_PORT->CR1 |= MAX2871_DATA_PIN;//PP
  MAX2871_DATA_PORT->CR2 |= MAX2871_DATA_PIN;//10M 
   
#if (Use_MAX2871_LD_PIN!=0)  
  //CFG->GCR |= 0x01;//disable SWIM interface
  MAX2871_LD_PORT->CR2 &=~ MAX2871_LD_PIN;//interrupt disable
  MAX2871_LD_PORT->CR1 &=~ MAX2871_LD_PIN;//Floating input
  MAX2871_LD_PORT->DDR &=~ MAX2871_LD_PIN;//Input mode
#endif
}

void MAX2871_SPI_TX_Byte(uint8_t Data)
{
  uint8_t i;
  for(i=0;i<8;i++)
  {
    MAX2871_CLK0();
    if(Data&0x80)
      MAX2871_DATA1();
    else
      MAX2871_DATA0();
    Data<<=1;
    MAX2871_CLK1();
  }
}

void MAX2871_Send_Data(uint32_t* Reg_Data)
{
  MAX2871_CLK0();
  MAX2871_LE0();

  MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[0]);
  MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[1]);
  MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[2]);
  MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[3]);

  MAX2871_CLK0();
  MAX2871_LE1();
}


void MAX2871_RFOUT_ON(void)
{
  MAX2871_RE1();
}

void MAX2871_RFOUT_OFF(void)
{
  MAX2871_RE0();
}

void MAX2871_Init(void)
{
  uint8_t i=6;
  MAX2871_GPIO_Init();
  while(i--)
  {
    MAX2871_Send_Data((uint32_t*)&MAX2871_Init_Reg_Data[i]);
  }
  //MAX2871_RFOUT_ON();
}

//参考频率10MHz
//小数模式
void max2871_Set_Freq_10M(uint32_t fre,uint8_t dbm)
{
  uint16_t N,F;
  uint8_t i,ADIV;
  
  ((uint16_t*)&MAX2871_Reg_Data[4])[1]= 0x8124 | (dbm<<6)| (dbm<<3);
  if(fre>3000000)
  {
          ADIV=0;
  }
  else if(fre>1500000)
  {
          fre=fre*2;
          ADIV=1;
  }
  else if(fre>750000)
  {
          fre=fre*4;
          ADIV=2;
  }
  else if(fre>375000)
  {
          fre=fre*8;
          ADIV=3;
  }
  else if(fre>187500)
  {
          fre=fre*16;
          ADIV=4;
  }
  else if(fre>93750)
  {
          fre=fre*32;
          ADIV=5;
  }
  else if(fre>46880)
  {
          fre=fre*64;
          ADIV=6;
  }
  else if(fre>23500)
  {
          fre=fre*128;
          ADIV=7;
  }
  ((uint16_t*)&MAX2871_Reg_Data[4])[0]= 0x608C | (ADIV<<4);
  N=fre/10000;
  F=(fre%10000)*2;//M=4000
  F/=5;  
  ((uint16_t*)&MAX2871_Reg_Data[0])[0]= N>>1;
  ((uint16_t*)&MAX2871_Reg_Data[0])[1]= (N<<15)|(F<<3);
  //MAX2871_Reg_Data[4] = 0x608C80E4|(ADIV<<20)|(dbm<<3);
  //MAX2871_Reg_Data[0] = 0x00000000|(N<<15)|(F<<3);
  i=6;
  while(i--)
  {
    MAX2871_Send_Data(&MAX2871_Reg_Data[i]);
  }
  
//  max2871_send_data(0x00458005);   //0000 0001 0100 0000 0000 0000 0000 0101
//  max2871_send_data(0x608C80E4|(ADIV<<20)|(dbm<<3));   //0000 0000 0000 0000 0001 1111 0010 0011
//  max2871_send_data(0x00001F23);   //0000 0000 0000 0000 0001 1111 0010 0011
//  //max2871_send_data(0x10005F42);   //0010 0000 0000 0000 1000 0011 0010 0001
//  max2871_send_data(0x10004D42);   //0010 0000 0000 0000 1000 0011 0010 0001
//  max2871_send_data(0x20017D01);   //0010 0000 0000 0000 1000 0011 0010 0001
//  max2871_send_data(0x00000000|(N<<15)|(F<<3));   //0000 0000 1001 0110 0000 0000 0000 0000
}



