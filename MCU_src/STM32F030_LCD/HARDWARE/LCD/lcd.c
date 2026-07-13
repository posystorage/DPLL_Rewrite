#include "lcd.h"
#include "font.h"
#include "buaa_logo.h"

uint16_t BACK_COLOR;

//-----------------LCD端口定义---------------- 

#define	FLASH_CS_SET  GPIOA->BSRR=1<<2    //片选端口		PA2 
#define	FLASH_CS_CLR  GPIOA->BRR=1<<2     //片选端口		PA2

#define	LCD_CS_SET  GPIOA->BSRR=1<<4    //片选端口		PA4 
#define	LCD_CS_CLR  GPIOA->BRR=1<<4     //片选端口		PA4

#define	LCD_RW_SET	GPIOA->BSRR=1<<3    //DATA		PA3
#define	LCD_RW_CLR	GPIOA->BRR=1<<3     //CMD		PA3

#define	LCD_RST_CLR	GPIOB->BRR=1<<0     //RST				PB0	
#define	LCD_RST_SET	GPIOB->BSRR=1<<0    //RST				PB0


#define SPI1_DR_ADDR *(__IO uint8_t *)((uint32_t)SPI1+0x0c)
#define DATAOUT(x)  SPI1_DR_ADDR=x;

#define SPI1_Wait_Busy while((SPI1->SR&SPI_SR_BSY)==SPI_SR_BSY){}
#define SPI1_Wait_TX_Buffer_Not_Empty while((SPI1->SR&SPI_SR_TXE)==0){}
#define SPI1_Wait_TX_FIFO_Full while((SPI1->SR&SPI_SR_FTLVL)==SPI_SR_FTLVL){}
#define SPI1_Wait_TX_FIFO_Half_Full while((SPI1->SR&SPI_SR_FTLVL)>=SPI_SR_FTLVL_1){}
	
	

//写寄存器函数
//data:寄存器值
void LCD_WR_REG(uint8_t data)
{
		LCD_CS_CLR;
	  LCD_RW_CLR;//写地址
    DATAOUT(data);
	  SPI1_Wait_Busy;
    LCD_CS_SET;
}
//写数据函数
//可以替代LCD_WR_DATAX宏,拿时间换空间.
//data:寄存器值
void LCD_WR_DATA(uint8_t data)
{
    LCD_CS_CLR;
  	LCD_RW_SET;
    DATAOUT(data);		
	  SPI1_Wait_Busy;
    LCD_CS_SET;
}
void LCD_WR_DATA16(uint16_t data)
{
    LCD_CS_CLR;
  	LCD_RW_SET;	
		SPI1->DR= __REV16(data);
	  SPI1_Wait_Busy;
    LCD_CS_SET;
}


//写寄存器
//LCD_Reg:寄存器编号
//LCD_RegValue:要写入的值
void LCD_WriteReg(uint8_t LCD_Reg,uint8_t LCD_RegValue)
{
    LCD_WR_REG(LCD_Reg);
    LCD_WR_DATA(LCD_RegValue);
}

void LCD_WriteRAM_Prepare(void)
{
    LCD_WR_REG(0x2C);
}

//设置光标位置
//Xpos:横坐标
//Ypos:纵坐标
void LCD_Set_Cursor(uint8_t Xpos, uint8_t Ypos)
{
    LCD_WR_REG(0X2A);//0x2A
    LCD_WR_DATA(0x00);
    LCD_WR_DATA(Xpos);
    LCD_WR_DATA(0x00);
    LCD_WR_DATA(160-1);//160
	
	  LCD_WR_REG(0X2B);//0x2B
    LCD_WR_DATA(0x00);
    LCD_WR_DATA(Ypos);
    LCD_WR_DATA(0x00);
    LCD_WR_DATA(128-1);//80
}
void LCD_Set_Cursor_Fast(uint8_t Xpos, uint8_t Ypos)
{
		LCD_CS_CLR;
		LCD_RW_CLR;
		DATAOUT(0X2A);
		SPI1_Wait_Busy;
	
		LCD_RW_SET;		
		SPI1->DR = __REV16(Xpos);
		SPI1->DR = __REV16(160-1);
//		DATAOUT(0);
//		DATAOUT(Xpos);
//		DATAOUT(0);
//		DATAOUT(160-1);
		SPI1_Wait_Busy;

		LCD_RW_CLR;
		DATAOUT(0X2B);
		SPI1_Wait_Busy;
	
		LCD_RW_SET;		
		SPI1->DR = __REV16(Ypos);
		SPI1->DR = __REV16(128-1);
//		DATAOUT(0);
//		DATAOUT(Ypos);
//		DATAOUT(0);
//		DATAOUT(128-1);
		SPI1_Wait_Busy;

		LCD_CS_SET;
}
//设置光标位置
//Xpos:横坐标
//Ypos:纵坐标
void LCD_Set_Windows(uint8_t Xs, uint8_t Ys , uint8_t Xe, uint8_t Ye)
{
		LCD_CS_CLR;
		LCD_RW_CLR;
		DATAOUT(0X2A);
		SPI1_Wait_Busy;
	
		LCD_RW_SET;		
		SPI1->DR = __REV16(Xs);
		SPI1->DR = __REV16(Xe-1);
//		DATAOUT(0);
//		DATAOUT(Xs);
//		DATAOUT(0);
//		DATAOUT(Xe-1);
		SPI1_Wait_Busy;

		LCD_RW_CLR;
		DATAOUT(0X2B);
		SPI1_Wait_Busy;
	
		LCD_RW_SET;		
		SPI1->DR = __REV16(Ys);
		SPI1->DR = __REV16(Ye-1);
//		DATAOUT(0);
//		DATAOUT(Ys);
//		DATAOUT(0);
//		DATAOUT(Ye-1);
		SPI1_Wait_Busy;

		LCD_CS_SET;	
//    LCD_WR_REG(0X2A);//0x2A
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(Xs);
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(Xe);//239
//	
//	  LCD_WR_REG(0X2B);//0x2B
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(Ys);
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(Ye);//239
}


//画点
//x,y:坐标
//POINT_COLOR:此点的颜色
void LCD_DrawPoint(uint16_t x,uint16_t y,uint16_t color)
{
    LCD_Set_Cursor(x,y);     //设置光标位置
    LCD_WriteRAM_Prepare(); //开始写入GRAM
    LCD_WR_DATA(color);
}
//快速画点
//x,y:坐标
//color:颜色
void LCD_Fast_DrawPoint(uint16_t x,uint16_t y,uint16_t color)
{
//    LCD_WR_REG(0X2A);//0x2A
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(x);
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(0xEF);//239
//	
//	  LCD_WR_REG(0X2B);//0x2B
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(y);
//    LCD_WR_DATA(0x00);
//    LCD_WR_DATA(0xEF);//239
		LCD_Set_Cursor_Fast(x,y);
	
    LCD_WR_REG(0x2C);    //写指令
		color	= __REV16(color);
    LCD_WR_DATA16(color);     //写数据
}


//清屏函数
//color:要清屏的填充色
void LCD_Clear(uint16_t color)
{
    uint32_t index=0;  	
		color	= __REV16(color);
		LCD_Set_Cursor_Fast(0,0);
	  //LCD_Set_Cursor(0x00,0x00);   	 //设置光标位
    LCD_WriteRAM_Prepare();					 //开始写入GRAM
		LCD_CS_CLR;
		LCD_RW_SET;
    for(index=0; index<128*160; index++)//160*80
    {	
			SPI1_Wait_TX_FIFO_Full;
			SPI1->DR= color;
    }
		SPI1_Wait_Busy;
		LCD_CS_SET;
}


void LCD_BK_PWM_Init(void)
{
	RCC->AHBENR |= RCC_AHBENR_GPIOBEN;
	RCC->APB1ENR |= RCC_APB1ENR_TIM14EN;

	GPIOB->MODER &=~ GPIO_MODER_MODER1;
	GPIOB->MODER |= GPIO_MODER_MODER1_1;//PB1  Alternate function mode
	GPIOB->AFR[0] &=~ GPIO_AFRL_AFR1; //PB1 AF0
	//GPIOB->AFR[0] |= (0<<(1)*4);
	GPIOB->OTYPER &=~ GPIO_OTYPER_OT_1;//PP
	GPIOB->ODR |= GPIO_OSPEEDR_OSPEEDR1;//High speed
	
	TIM14->PSC = 48-1; //Set prescaler to 48
	TIM14->ARR = 100-1; //100
	TIM14->CCR1 = 0;//Turn off heating by default
	
	TIM14->CCMR1 |= TIM_CCMR1_OC1M_2 | TIM_CCMR1_OC1M_1; //Select PWM mode 1 on OC2
	TIM14->CCER |= TIM_CCER_CC1E; // enable the output on OC2
	TIM14->BDTR |= TIM_BDTR_MOE; //Enable output	
	TIM14->CR1 |= TIM_CR1_CEN; //Enable counter
	TIM14->EGR |= TIM_EGR_UG; //Force update generation	
}
void LCD_Set_BK_PWM(uint8_t Duty_Cycle)
{
	if(Duty_Cycle>99)Duty_Cycle = 99;
	TIM14->CCR1 = 99-Duty_Cycle;
}

void LCD_HW_Init(void)
{
	RCC->APB2ENR |= RCC_APB2ENR_SPI1EN;

	RCC->AHBENR |= RCC_AHBENR_GPIOAEN|RCC_AHBENR_GPIOBEN;
	LCD_RST_CLR;
  FLASH_CS_SET;
  LCD_CS_SET;
	LCD_RW_SET;
	//PB0/1
	GPIOB->MODER &=~ 0x0F;
	GPIOB->MODER |=  0x05;
	GPIOB->OSPEEDR |= 0x05;
	GPIOB->OTYPER &=~ 0x05;

	//PA2-7
	GPIOA->MODER &=~ 0xFFF0;
	GPIOA->OSPEEDR|= 0xFFF0;
	GPIOA->MODER |=  0xA950;//PA5-SCK AF0_SPI1_SCK PA6-SDA AF0_SPI11_MISO PA7-SDA AF0_SPI11_MOSI 
	GPIOA->OTYPER &=~ 0xFC;	

	GPIOA->AFR[0] &=~ 0xFFF00000;
	
	SPI1->CR1 = SPI_CR1_BIDIMODE | SPI_CR1_BIDIOE| SPI_CR1_MSTR | SPI_CR1_SSM | SPI_CR1_SSI;
	SPI1->CR2 = ((8-1)<<8);//8bit
	SPI1->CR1 |= SPI_CR1_SPE;
}

void LCD_Init(void)
{
	LCD_HW_Init();
	delay_ms(1);
	LCD_RST_SET;
	delay_ms(30);
	
	LCD_WR_REG(0x11);
	delay_ms(10);
	
//	LCD_WR_REG(0xC5); //VCOM
//	LCD_WR_DATA(0x12);

////------------------------------------ST7735S Gamma Sequence-----------------------------------------//
//	LCD_WR_REG(0xE0);
//	LCD_WR_DATA(0x04);
//	LCD_WR_DATA(0x22);
//	LCD_WR_DATA(0x07);
//	LCD_WR_DATA(0x0A);
//	LCD_WR_DATA(0x2E);
//	LCD_WR_DATA(0x30);
//	LCD_WR_DATA(0x25);
//	LCD_WR_DATA(0x2A);
//	LCD_WR_DATA(0x28);
//	LCD_WR_DATA(0x26);
//	LCD_WR_DATA(0x2E);
//	LCD_WR_DATA(0x3A);
//	LCD_WR_DATA(0x00);
//	LCD_WR_DATA(0x01);
//	LCD_WR_DATA(0x03);
//	LCD_WR_DATA(0x13);
//	LCD_WR_REG(0xE1);
//	LCD_WR_DATA(0x04);
//	LCD_WR_DATA(0x16);
//	LCD_WR_DATA(0x06);
//	LCD_WR_DATA(0x0D);
//	LCD_WR_DATA(0x2D);
//	LCD_WR_DATA(0x26);
//	LCD_WR_DATA(0x23);
//	LCD_WR_DATA(0x27);
//	LCD_WR_DATA(0x27);
//	LCD_WR_DATA(0x25);
//	LCD_WR_DATA(0x2D);
//	LCD_WR_DATA(0x3B);
//	LCD_WR_DATA(0x00);
//	LCD_WR_DATA(0x01);
//	LCD_WR_DATA(0x04);
//	LCD_WR_DATA(0x13);	
	
	//--------------------------------Display and color format setting-------------------

	LCD_WR_REG(0x36);
	LCD_WR_DATA(0x60);	
	LCD_WR_REG(0x3A);
	LCD_WR_DATA(0x05);

	LCD_Set_Windows(0,0,160,128);
	
	LCD_WR_REG(0x29);//Display On
  LCD_Clear(WHITE);		
	LCD_BK_PWM_Init();
	LCD_Set_BK_PWM(99);
	BACK_COLOR = WHITE;
}


void LCD_Show_Buaa_Logo(void)
{
	uint32_t i,j;
	uint32_t Show_Buff;
	LCD_Set_Windows(16,0,144,128);
	LCD_WriteRAM_Prepare();					 //开始写入GRAM
	LCD_CS_CLR;
	LCD_RW_SET;
	for(i=0;i<2048;i++)
	{
		Show_Buff = gImage_buaa_logo[i];
		for(j=0;j<8;j++)
		{
			SPI1_Wait_TX_FIFO_Full;
			if(Show_Buff&0x80)
				SPI1->DR= 0x1F7C;
			else
				SPI1->DR= 0xFFFF;
			Show_Buff<<=1;
		}	
	}
	SPI1_Wait_Busy;
  LCD_CS_SET;
}

void LCD_SHOW_ASCII_0806(uint16_t x,uint16_t y,uint8_t data,uint16_t color)
{
	uint32_t j;
	uint8_t Show_Buff;
	uint8_t Mark = 0x01;
	color	= __REV16(color);
	LCD_Set_Windows(x,y,x+6,y+8);
	LCD_WriteRAM_Prepare();					 //开始写入GRAM
	LCD_CS_CLR;
	LCD_RW_SET;
	while(Mark)
	{
		for(j=0;j<6;j++)
		{
			Show_Buff = asc2_0608[data][j];
			SPI1_Wait_TX_FIFO_Full;
			if(Show_Buff&Mark)
				SPI1->DR= color;
			else
				SPI1->DR= __REV16(BACK_COLOR);
			Show_Buff>>=1;
		}	
		Mark <<=1;
	}
	SPI1_Wait_Busy;
  LCD_CS_SET;
}

void LCD_SHOW_ASCII_1608(uint16_t x,uint16_t y,uint8_t data,uint16_t color)
{
	uint32_t i,j;
	uint32_t Show_Buff;
	data = data - ' ';
	color	= __REV16(color);
	LCD_Set_Windows(x,y,x+8,y+16);
	LCD_WriteRAM_Prepare();					 //开始写入GRAM
	LCD_CS_CLR;
	LCD_RW_SET;
	for(i=0;i<16;i+=4)
	{
		//Show_Buff = asc2_0816[data][i];
		Show_Buff = *((uint32_t*)&asc2_0816[data][i]);
		for(j=0;j<32;j++)
		{
			SPI1_Wait_TX_FIFO_Full;
			if(Show_Buff&0x01)
				SPI1->DR= color;
			else
				SPI1->DR= __REV16(BACK_COLOR);
			Show_Buff>>=1;
		}	
	}
	SPI1_Wait_Busy;
  LCD_CS_SET;
}

void LCD_SHOW_HANZI(uint16_t x,uint16_t y,uint8_t data_Num,uint16_t color)
{
	uint32_t i,j;
	uint32_t Show_Buff;
	color	= __REV16(color);
	LCD_Set_Windows(x,y,x+16,y+16);
	LCD_WriteRAM_Prepare();					 //开始写入GRAM
	LCD_CS_CLR;
	LCD_RW_SET;
	for(i=0;i<32;i+=4)
	{
		Show_Buff = *((uint32_t*)&HanZi_1616[data_Num][i]);
		for(j=0;j<32;j++)
		{
			SPI1_Wait_TX_FIFO_Full;
			if(Show_Buff&0x01)
				SPI1->DR= color;
			else
				SPI1->DR= __REV16(BACK_COLOR);
			Show_Buff>>=1;
		}	
	}
	SPI1_Wait_Busy;
  LCD_CS_SET;
}

void LCD_SHOW_Icon_1612(uint16_t x,uint16_t y,uint8_t data,uint16_t color)
{
	uint32_t i,j;
	uint32_t Show_Buff;
	color	= __REV16(color);
	if(data<2)
	{
		LCD_Set_Windows(x,y+2,x+12,y+15);
		i = 4;
	}
	else
	{
		LCD_Set_Windows(x,y,x+12,y+16);
		i = 0;
	}	
	LCD_WriteRAM_Prepare();					 //开始写入GRAM
	LCD_CS_CLR;
	LCD_RW_SET;
	for(;i<32;i+=2)
	{
		Show_Buff = *((uint16_t*)&Icon_1616[data][i]);
		for(j=0;j<12;j++)
		{
			SPI1_Wait_TX_FIFO_Full;
			if(Show_Buff&0x01)
				SPI1->DR= color;
			else
				SPI1->DR= __REV16(BACK_COLOR);
			Show_Buff>>=1;
		}	
	}
	SPI1_Wait_Busy;
  LCD_CS_SET;
}

void LCD_ShowString(uint16_t x,uint16_t y,uint8_t *p,uint16_t color)
{
    while((*p<='~')&&(*p>=' '))
    {
        LCD_SHOW_ASCII_1608(x,y,*p,color);
        x+=8;
        p++;
    }
}

void LCD_16ShowString_hanzi(uint16_t x,uint16_t y,uint8_t *p,uint16_t color)
{
		uint16_t addr,i;
    while(*p!= '\0')
    {
			addr=0xff;
			i=0;
				while(HanZi_Index[i] !='\0')
				{
					if(HanZi_Index[i] == *p)
					{
						if(HanZi_Index[i + 1] == *(p+1))
						{
							addr = i>>1;
							break;
						}
					}
					i += 2;			
				}
				if(addr != 0xff)
				{
				
					LCD_SHOW_HANZI(x,y,addr,color);
					x+=16;
					p+=2;				
				}
				else
				{
					LCD_SHOW_ASCII_1608(x,y,*p,color);
					x+=8;
					p++;
				}
    }
}

void LCD_Show_Square(uint16_t x,uint16_t y,uint16_t wide,uint16_t high,uint16_t color)
{
	uint32_t i,nums = wide*high;
	color	= __REV16(color);
	LCD_Set_Windows(x,y,x+wide,y+high);
	LCD_WriteRAM_Prepare();					 //开始写入GRAM
	LCD_CS_CLR;
	LCD_RW_SET;
	for(i=0;i<nums;i++)
	{
		SPI1_Wait_TX_FIFO_Full;
		SPI1->DR= color;
	}	
	SPI1_Wait_Busy;
  LCD_CS_SET;	
}

