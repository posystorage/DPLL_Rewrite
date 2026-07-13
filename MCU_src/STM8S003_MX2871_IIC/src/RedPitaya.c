#include "RedPitaya.h"

#define PACKAGE_SOH 0xA1
#define PACKAGE_STX 0xA2
#define PACKAGE_ETX 0xA3

#define STATUS_NACK                     0x03
#define STATUS_COMMAND_NUMBER_ERROR     0x04
#define STATUS_PARAMETER_ERROR          0x05
#define STATUS_ACK                      0x06
#define STATUS_CHECKSUM_ERROR           0x07

#define CMD_WRITE_CFG_DATA      0xC4
#define CMD_READ_STATUS_DATA    0xC5
#define CMD_PLL_ON              0xC7
#define CMD_PLL_OFF             0xC8
#define CMD_RESET               0xC9

void RedPitaya_Uart_Init(void)
{
  CLK->PCKENR1 |= CLK_PCKENR1_UART2;//头文件有bug
  
  GPIOD->ODR |= GPIO_PIN_5;
  GPIOD->DDR |= GPIO_PIN_5;
  GPIOD->CR1 |= GPIO_PIN_5|GPIO_PIN_6;
  GPIOD->CR2 |= GPIO_PIN_5;
  GPIOD->CR2 &=~GPIO_PIN_6;
  GPIOD->DDR &=~GPIO_PIN_6;
  
    
  UART1->CR1=0x00;  
  UART1->CR2=0x00;  
  UART1->CR3=0x00;  
  // 必须先写BRR2  
  // 例如对于波特率位115200时，分频系数=16000000/115200=139  
  // 对应的十六进制数为008B，BBR1=08,BBR2=0B     
  //UART1->BRR2=0x0B;  
  //UART1->BRR1=0x08; 
  //波特率为1Mb，分频系数为16
  UART1->BRR2=0x00;  
  UART1->BRR1=0x01;  
  
  ITC->ISPR5 &=~ 0x30;  
  UART1->CR2=UART1_CR2_RIEN|UART1_CR2_TEN|UART1_CR2_REN;//允许接收，发送
}

uint8_t RedPitaya_TX_Buff[48];
uint8_t RedPitaya_RX_Buff[16];
uint32_t RedPitaya_RX_Wait_Num = 0;
uint8_t* RedPitaya_RX_Buff_Pointer;
uint8_t RedPitaya_Cache;

//0-ok
//1=timeout
uint8_t RedPitaya_Uart_TXRX_Frame(uint8_t* TX_Data,uint8_t* RX_Data,uint32_t TX_Nums,uint32_t RX_Nums)
{
  uint16_t RX_TimeOut;
  if(RX_Nums != 0)
  {
    RedPitaya_RX_Buff_Pointer = RX_Data;
    RedPitaya_RX_Wait_Num = RX_Nums;
  }
  while(TX_Nums)
  {
    while((UART1->SR&UART1_SR_TXE) == 0);
    UART1->DR = *TX_Data;
    TX_Nums--;
    TX_Data++;
  } 
  while((UART1->SR&UART1_SR_TC) == 0);
  if(RX_Nums == 0)return 0;
  RX_TimeOut = 5000;//50ms
  while(RX_TimeOut)
  {
    RX_TimeOut--;
    if(RedPitaya_RX_Wait_Num==0) return 0;
    delay_us(10);
  } 
  RedPitaya_RX_Wait_Num = 0;
  return 1;  
}

INTERRUPT_HANDLER(UART1_RX_IRQHandler, 18)
{
  uint8_t RX_Data = UART1->DR;
  if(RedPitaya_RX_Wait_Num)
  {
    *RedPitaya_RX_Buff_Pointer = RX_Data;
    RedPitaya_RX_Buff_Pointer++;
    RedPitaya_RX_Wait_Num--;    
  }
}

uint8_t RedPitaya_Send_CMD(uint8_t* CMD_Data_Buff,uint8_t CMD,uint32_t CMD_Data_Nums,uint32_t CMD_RX_Nums)
{
  uint8_t CheckSm = 0,i,Error_Code;
  RedPitaya_TX_Buff[0] = PACKAGE_SOH;
  RedPitaya_TX_Buff[1] = CMD_Data_Nums + 1;
  CheckSm -= RedPitaya_TX_Buff[1];
  RedPitaya_TX_Buff[2] = CMD;	
  CheckSm -= RedPitaya_TX_Buff[2];
  for(i=0;i<CMD_Data_Nums;i++)
  {
    RedPitaya_TX_Buff[3+i] = CMD_Data_Buff[i];
    CheckSm -= CMD_Data_Buff[i];
  }	
  RedPitaya_TX_Buff[3+CMD_Data_Nums] = CheckSm;
  RedPitaya_TX_Buff[4+CMD_Data_Nums] = PACKAGE_ETX;			
  Error_Code = RedPitaya_Uart_TXRX_Frame(RedPitaya_TX_Buff,RedPitaya_RX_Buff,CMD_Data_Nums+5,CMD_RX_Nums);
  if(Error_Code){IIC_Reg_Buff[2]|=0x80;return Error_Code;}//offline
  IIC_Reg_Buff[2]&=~0x80;
  if(RedPitaya_RX_Buff[0] != PACKAGE_STX){IIC_Reg_Buff[2]|=0x40; return 3;}
  if(RedPitaya_RX_Buff[1]>12){IIC_Reg_Buff[2]|=0x40; return 4;}
  CheckSm = 0;
  CheckSm -= RedPitaya_RX_Buff[1];
  for(i=0;i<RedPitaya_RX_Buff[1];i++)
  {
    CheckSm -= RedPitaya_RX_Buff[2+i];
  }		
  if(RedPitaya_RX_Buff[2+i] != (uint8_t)CheckSm){IIC_Reg_Buff[2]|=0x40;return 5;}
  if(RedPitaya_RX_Buff[2] != STATUS_ACK){IIC_Reg_Buff[2]|=0x40;return RedPitaya_RX_Buff[2]|0x80;}
  IIC_Reg_Buff[2]&=~0x40;
  return 0;	
}

uint8_t RedPitaya_CMD_WRITE_CFG_DATA(void)
{
  return RedPitaya_Send_CMD(&IIC_Reg_Buff[8],CMD_WRITE_CFG_DATA,34,5);
}

uint8_t RedPitaya_CMD_READ_STATUS_DATA(void)
{
  uint8_t Error_Code,i;
  Error_Code = RedPitaya_Send_CMD(0,CMD_READ_STATUS_DATA,0,12);//7个有效载荷数据+5个包头包尾ASK
  if(Error_Code)return Error_Code;
  IIC_Reg_Buff[2] = (IIC_Reg_Buff[2]&0xC0)|(RedPitaya_RX_Buff[3]&0x3F);
  for(i=0;i<6;i++)
  {
    IIC_Reg_Buff[0x2A+i] = RedPitaya_RX_Buff[4+i];
  }
  return 0;
}


uint8_t RedPitaya_CMD_PLL_ON(void)
{
  return RedPitaya_Send_CMD(0,CMD_PLL_ON,0,5);
}

uint8_t RedPitaya_CMD_PLL_OFF(void)
{
  return RedPitaya_Send_CMD(0,CMD_PLL_OFF,0,5);
}

uint8_t RedPitaya_CMD_CMD_RESET(void)
{
  return RedPitaya_Send_CMD(0,CMD_RESET,0,5);
}

