#include "iic.h"
#include "delay.h"

#define FLAG_TIMEOUT         ((uint32_t)0x1000)
#define LONG_TIMEOUT         ((uint32_t)(10 * FLAG_TIMEOUT))

#define CR1_CLEAR_MASK          ((uint32_t)0x00CFE0FF)  /*<! I2C CR1 clear register Mask */
void IIC1_Init(void)
{	
	RCC->AHBENR |= RCC_AHBENR_GPIOBEN;
	RCC->APB1ENR |= RCC_APB1ENR_I2C1EN;	
	
	
	GPIOB->OTYPER|=GPIO_OTYPER_OT_6|GPIO_OTYPER_OT_7;//OD
	GPIOB->OSPEEDR|=GPIO_OSPEEDR_OSPEEDR6|GPIO_OSPEEDR_OSPEEDR7;//50M
	GPIOB->MODER&=~(GPIO_MODER_MODER6|GPIO_MODER_MODER7);
	GPIOB->PUPDR&=~(GPIO_PUPDR_PUPDR6|GPIO_PUPDR_PUPDR7);
	GPIOB->MODER|=GPIO_MODER_MODER6_1|GPIO_MODER_MODER7_1;//复用
	GPIOB->PUPDR|=GPIO_PUPDR_PUPDR6_0|GPIO_PUPDR_PUPDR7_0;//pull-up
	GPIOB->AFR[0]&=~(GPIO_AFRL_AFR6|GPIO_AFRL_AFR7);
	GPIOB->AFR[0]|=(1<<6*4)|(1<<7*4);//PB6/7 AF2 IIC
	
	//Disable I2Cx Peripheral
  I2C1->CR1 &= ((uint32_t)~((uint32_t)I2C_CR1_PE))&CR1_CLEAR_MASK;
	//EN AnalogFilter
	I2C1->CR1 &=~ I2C_CR1_ANFOFF;
	//Configure I2Cx: Timing
  I2C1->TIMINGR = 0x00210507;//381K
	//I2C1->TIMINGR = 0x00322026;//100K
  //Enable I2Cx Peripheral
  I2C1->CR1 |= I2C_CR1_PE;		
}

/**
  *            @arg I2C_FLAG_TXE: Transmit data register empty
  *            @arg I2C_FLAG_TXIS: Transmit interrupt status
  *            @arg I2C_FLAG_RXNE: Receive data register not empty
  *            @arg I2C_FLAG_ADDR: Address matched (slave mode)
  *            @arg I2C_FLAG_NACKF: NACK received flag
  *            @arg I2C_FLAG_STOPF: STOP detection flag
  *            @arg I2C_FLAG_TC: Transfer complete (master mode)
  *            @arg I2C_FLAG_TCR: Transfer complete reload
  *            @arg I2C_FLAG_BERR: Bus error
  *            @arg I2C_FLAG_ARLO: Arbitration lost
  *            @arg I2C_FLAG_OVR: Overrun/Underrun
  *            @arg I2C_FLAG_PECERR: PEC error in reception
  *            @arg I2C_FLAG_TIMEOUT: Timeout or Tlow detection flag
  *            @arg I2C_FLAG_ALERT: SMBus Alert
  *            @arg I2C_FLAG_BUSY: Bus busy
  */
#ifndef __STM32F0XX_I2C_H
	#define  I2C_FLAG_TXE                   I2C_ISR_TXE
	#define  I2C_FLAG_TXIS                  I2C_ISR_TXIS
	#define  I2C_FLAG_RXNE                  I2C_ISR_RXNE
	#define  I2C_FLAG_ADDR                  I2C_ISR_ADDR
	#define  I2C_FLAG_NACKF                 I2C_ISR_NACKF
	#define  I2C_FLAG_STOPF                 I2C_ISR_STOPF
	#define  I2C_FLAG_TC                    I2C_ISR_TC
	#define  I2C_FLAG_TCR                   I2C_ISR_TCR
	#define  I2C_FLAG_BERR                  I2C_ISR_BERR
	#define  I2C_FLAG_ARLO                  I2C_ISR_ARLO
	#define  I2C_FLAG_OVR                   I2C_ISR_OVR
	#define  I2C_FLAG_PECERR                I2C_ISR_PECERR
	#define  I2C_FLAG_TIMEOUT               I2C_ISR_TIMEOUT
	#define  I2C_FLAG_ALERT                 I2C_ISR_ALERT
	#define  I2C_FLAG_BUSY                  I2C_ISR_BUSY
#endif

//返回1为失败 0为正常
uint8_t IIC_Wait(uint32_t I2C_FLAG)
{
	uint32_t Timeout;
	Timeout = LONG_TIMEOUT;  
  //while(I2C_GetFlagStatus(I2C1, I2C_ISR_TXIS) == RESET)
	while((I2C1->ISR&I2C_FLAG)==0)
  {
    if((Timeout--) == 0) 
			return 1;
		if(I2C1->ISR&I2C_ISR_TIMEOUT)
			return 1;
  }
	if(I2C1->ISR&I2C_ISR_NACKF)
	{
		I2C1->ICR = I2C_ICR_NACKCF;
		return 1;//收到nak
	}		
	return 0;
}

//检查制定地址的从机设备是否存在 0存在 1没有
uint8_t IIC_Check_Slave(uint8_t Addr)
{
	uint32_t tmpreg;
	//if(IIC_Wait(I2C_ISR_BUSY))return 1;//总线忙
	tmpreg=I2C1->CR2;
	tmpreg&= (uint32_t)~((uint32_t)(I2C_CR2_SADD | I2C_CR2_NBYTES | I2C_CR2_RELOAD | I2C_CR2_AUTOEND | I2C_CR2_RD_WRN | I2C_CR2_START | I2C_CR2_STOP));
	tmpreg|=Addr|I2C_CR2_START|I2C_CR2_STOP;
	I2C1->CR2 = tmpreg;  
	return IIC_Wait(I2C_FLAG_STOPF);
}

//返回实际读取数量
uint8_t IIC_Read(uint8_t Addr,uint8_t Reg,uint8_t Num,uint8_t* Data_Buff)
{
	uint32_t tmpreg,Pointer=0;
	if(Num==0)return 0;
	if(I2C1->ISR & (I2C_ISR_TIMEOUT|I2C_ISR_PECERR|I2C_ISR_ARLO|I2C_ISR_BERR|I2C_ISR_NACKF))
	{
		I2C1->ICR = I2C_ICR_TIMOUTCF|I2C_ICR_PECCF|I2C_ICR_ARLOCF|I2C_ICR_BERRCF|I2C_ICR_NACKCF;
	}

	tmpreg=I2C1->CR2;
	tmpreg&= (uint32_t)~((uint32_t)(I2C_CR2_SADD | I2C_CR2_NBYTES | I2C_CR2_RELOAD | I2C_CR2_AUTOEND | I2C_CR2_RD_WRN | I2C_CR2_START | I2C_CR2_STOP));
	tmpreg|=Addr|I2C_CR2_START|(1<<16);//数量	
	I2C1->CR2 = tmpreg;  
	if(IIC_Wait(I2C_ISR_TXIS))return 0;
	//Send memory address
	I2C1->TXDR=Reg;
	if(IIC_Wait(I2C_ISR_TC))return 0;
	
	tmpreg=I2C1->CR2;
	tmpreg&= (uint32_t)~((uint32_t)(I2C_CR2_SADD | I2C_CR2_NBYTES | I2C_CR2_RELOAD | I2C_CR2_AUTOEND | I2C_CR2_RD_WRN | I2C_CR2_START | I2C_CR2_STOP));
	tmpreg|=Addr|I2C_CR2_START | I2C_CR2_RD_WRN|I2C_CR2_AUTOEND|(Num<<16);
	I2C1->CR2 = tmpreg;
	while(Num)
	{
		if(IIC_Wait(I2C_FLAG_RXNE))return Pointer;
		Data_Buff[Pointer]=I2C1->RXDR;
		Pointer++;
		Num--;
	}
	return Pointer;
}


void IIC_Write(uint8_t Addr,uint8_t Reg,uint8_t Num,uint8_t* Data_Buff)
{
	uint32_t tmpreg,Pointer=0;
	//if(Num==0)return;
	if(I2C1->ISR & (I2C_ISR_TIMEOUT|I2C_ISR_PECERR|I2C_ISR_ARLO|I2C_ISR_BERR|I2C_ISR_NACKF))
	{
		I2C1->ICR = I2C_ICR_TIMOUTCF|I2C_ICR_PECCF|I2C_ICR_ARLOCF|I2C_ICR_BERRCF|I2C_ICR_NACKCF;
	}	
	tmpreg=I2C1->CR2;
	tmpreg&= (uint32_t)~((uint32_t)(I2C_CR2_SADD | I2C_CR2_NBYTES | I2C_CR2_RELOAD | I2C_CR2_AUTOEND | I2C_CR2_RD_WRN | I2C_CR2_START | I2C_CR2_STOP));
	tmpreg|=Addr|I2C_CR2_START|I2C_CR2_AUTOEND|((Num+1)<<16);//数量	
	I2C1->CR2 = tmpreg;  
	if(IIC_Wait(I2C_ISR_TXE))return;
	//Send memory address
	I2C1->TXDR=Reg;	
	while(Num)
	{
		if(IIC_Wait(I2C_ISR_TXE))return;
		I2C1->TXDR=Data_Buff[Pointer];
		Pointer++;
		Num--;
	}
	IIC_Wait(I2C_ISR_TXE);
	return;
}

//填充式写入 刷屏用
//void IIC_Fill_Write(uint8_t Addr,uint8_t Reg,uint8_t Num,uint8_t Data)
//{
//	uint32_t tmpreg;
//	if(Num==0)return;
//	tmpreg=I2C1->CR2;
//	tmpreg&= (uint32_t)~((uint32_t)(I2C_CR2_SADD | I2C_CR2_NBYTES | I2C_CR2_RELOAD | I2C_CR2_AUTOEND | I2C_CR2_RD_WRN | I2C_CR2_START | I2C_CR2_STOP));
//	tmpreg|=Addr|I2C_CR2_START|I2C_CR2_AUTOEND|((Num+1)<<16);//数量	
//	I2C1->CR2 = tmpreg;  
//	if(IIC_Wait(I2C_ISR_TXE))return;
//	//Send memory address
//	I2C1->TXDR=Reg;	
//	while(Num)
//	{
//		if(IIC_Wait(I2C_ISR_TXE))return;
//		I2C1->TXDR=Data;
//		Num--;
//	}
//	IIC_Wait(I2C_ISR_TXE);
//	return;
//}
