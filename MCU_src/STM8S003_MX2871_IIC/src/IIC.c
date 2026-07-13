#include "IIC.h"



uint8_t IIC_Reg_Addr_Point;
uint8_t IIC_Reg_Buff[IIC_REG_SIZE];
uint8_t IIC_Reg_Addr_Get;//标记获得了地址位
uint8_t IIC_CMD;

void IIC_Slave_Init(void)
{
  CLK->PCKENR1 |= CLK_PCKENR1_I2C;
  
  GPIOB->ODR |= GPIO_PIN_4|GPIO_PIN_5;
  GPIOB->DDR &=~ (GPIO_PIN_5|GPIO_PIN_4);

  I2C->CR1 = I2C_CR1_PE;
  I2C->CR2 = I2C_CR2_ACK;
  I2C->FREQR = 16;
  
  I2C->OARL = 0x4A;//Address
  I2C->OARH = I2C_OARH_ADDCONF;
  
  I2C->ITR = I2C_ITR_ITBUFEN | I2C_ITR_ITEVTEN;
  ITC->ISPR5 |= 0xC0;
  IIC_Reg_Addr_Point = 0;
  IIC_Reg_Buff[0] = 0xA5;//固定识别头
  IIC_Reg_Buff[1] = 0x00;//状态位
  IIC_Reg_Addr_Get = 0;
  IIC_CMD = 0;
}


void IIC_Slave_RX_Byte(uint8_t Last_Event_SR1)
{
  uint8_t Cache;
  if((Last_Event_SR1 & I2C_SR1_RXNE) == I2C_SR1_RXNE)
  {
    Cache = I2C->DR;
    if(IIC_Reg_Addr_Get)
    {
      if((IIC_Reg_Addr_Point>0x02)&&(IIC_Reg_Addr_Point<0x2A))//0\1\2\2a\2b\2c\2d寄存器是只读
      {
        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
        IIC_Reg_Addr_Point++;
      }
    }
    else
    {
      IIC_Reg_Addr_Get = 1;
      if(Cache < IIC_REG_SIZE)//Data
      {
        IIC_Reg_Addr_Point = Cache;
      }
      else//CMD
      {
        if((Cache>=0xC0)&&(Cache<=0xC9))
        {
          
          IIC_CMD = Cache;
          IIC_Reg_Buff[1] |= 0x04;//busy
          
        }
        IIC_Reg_Addr_Point = IIC_REG_SIZE;
      }
    }   
  }  
}

INTERRUPT_HANDLER(I2C_IRQHandler, 19)
{
  uint8_t Last_Event_SR1 = I2C->SR1;
  uint8_t Last_Event_SR3 = I2C->SR3;
  if((Last_Event_SR3 & I2C_SR3_BUSY) == I2C_SR3_BUSY)
  {
    if((Last_Event_SR1 & I2C_SR1_ADDR) == I2C_SR1_ADDR)
    {
      if((Last_Event_SR3 & I2C_SR3_TRA) == I2C_SR3_TRA)
      {
        if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)I2C->DR = 0xA5;
        else
        {
          I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
          IIC_Reg_Addr_Point++;
          if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;         
        }
      }
      else
      {
        IIC_Reg_Addr_Get = 0;
      }
    }  
    if(((Last_Event_SR3 & I2C_SR3_TRA) == I2C_SR3_TRA) && ((Last_Event_SR1 & I2C_SR1_TXE) == I2C_SR1_TXE))
    {
      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)I2C->DR = 0xA5;
      else
      {
        I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
        IIC_Reg_Addr_Point++;
        if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;  
      }
    }
    IIC_Slave_RX_Byte(Last_Event_SR1); 
  }

  if((I2C->SR1&I2C_SR1_STOPF) == I2C_SR1_STOPF)
  {
    I2C->CR2 = I2C_CR2_ACK;  
    IIC_Slave_RX_Byte(I2C->SR1);
  }
  
  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
  {
    I2C->SR2 &=~ I2C_SR2_AF;
  }
  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
  {
    I2C->SR2 &=~ I2C_SR2_BERR;
  } 
}



//typedef enum
//{
//  I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED    = (uint16_t)0x0202,  /*!< BUSY and ADDR flags */
//  I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED = (uint16_t)0x0682,  /*!< TRA, BUSY, TXE and ADDR flags */
//  I2C_EVENT_SLAVE_GENERALCALLADDRESS_MATCHED  = (uint16_t)0x1200,  /*!< EV2: GENCALL and BUSY flags */
//  I2C_EVENT_SLAVE_BYTE_RECEIVED              = (uint16_t)0x0240,  /*!< BUSY and RXNE flags */
//  I2C_EVENT_SLAVE_STOP_DETECTED              = (uint16_t)0x0010,  /*!< STOPF flag */
//  I2C_EVENT_SLAVE_BYTE_TRANSMITTED           = (uint16_t)0x0684,  /*!< TRA, BUSY, TXE and BTF flags */
//  I2C_EVENT_SLAVE_BYTE_TRANSMITTING          = (uint16_t)0x0680,  /*!< TRA, BUSY and TXE flags */
//} I2C_Event_TypeDef;  

//INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//{
//  uint8_t Cache;
//  __IO uint16_t lastevent=0;
//  *((uint8_t*)&lastevent+1)=I2C->SR1;
//  *(uint8_t*)&lastevent=I2C->SR3;
//  GPIOD->ODR &=~ GPIO_PIN_5;
//  
//  if((lastevent&I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED)
//  {
//    I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//    GPIOD->ODR |= GPIO_PIN_5;
//    IIC_Reg_Addr_Point++;
//    if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//    GPIOD->ODR &=~ GPIO_PIN_5; 
//  }
//  else
//  if((lastevent&I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED)  
//  {
//    IIC_Reg_Addr_Get = 0;
//  }
//  if((lastevent&I2C_EVENT_SLAVE_BYTE_TRANSMITTING) == I2C_EVENT_SLAVE_BYTE_TRANSMITTING)
//  {
//      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//      IIC_Reg_Addr_Point++;
//      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  }
//  if((lastevent&I2C_EVENT_SLAVE_BYTE_RECEIVED) == I2C_EVENT_SLAVE_BYTE_RECEIVED)
//  {
//    Cache = I2C->DR;
//    if(IIC_Reg_Addr_Get)
//    {
//      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//      {
//        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//      }
//    }
//    else
//    {
//      if(Cache < IIC_REG_SIZE)//Data
//      {
//        IIC_Reg_Addr_Point = Cache;
//        IIC_Reg_Addr_Get = 1;
//      }
//      else//CMD
//      {
//      
//      }
//    }   
//  }
//  if((I2C->SR1&I2C_SR1_STOPF) == I2C_SR1_STOPF)
//  {
//    I2C->CR2 = I2C_CR2_ACK;    
//  }
//  
//  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  {
//    I2C->SR2 &=~ I2C_SR2_AF;
//  }
//  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  {
//    I2C->SR2 &=~ I2C_SR2_BERR;
//  }    
//  GPIOD->ODR |= GPIO_PIN_5;
//}


//INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//{
//  uint8_t Cache;
//  __IO uint16_t lastevent=0;
//  *((uint8_t*)&lastevent+1)=I2C->SR1&(*((uint8_t*)&I2C_Event+1));
//  *(uint8_t*)&lastevent=I2C->SR3&(*(uint8_t*)&I2C_Event);
//  
//  
//  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  {
//    I2C->SR2 &=~ I2C_SR2_AF;
//  
//  }
//  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  {
//    I2C->SR2 &=~ I2C_SR2_BERR;
//  
//  }
//  if(I2C_CheckEvent(I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED))
//  {
//    if(I2C_CheckEvent(I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED))
//    {
//      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//      IIC_Reg_Addr_Point++;
//      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//    }
//    else
//    {
//      IIC_Reg_Addr_Get = 0;
//    }
//  }
//  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_TRANSMITTING))
//  {
//      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//      IIC_Reg_Addr_Point++;
//      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  }
//  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_RECEIVED))
//  {
//    Cache = I2C->DR;
//    if(IIC_Reg_Addr_Get)
//    {
//      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//      {
//        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//      }
//    }
//    else
//    {
//      if(Cache < IIC_REG_SIZE)//Data
//      {
//        IIC_Reg_Addr_Point = Cache;
//        IIC_Reg_Addr_Get = 1;
//      }
//      else//CMD
//      {
//      
//      }
//    }   
//  }
//  
//}

