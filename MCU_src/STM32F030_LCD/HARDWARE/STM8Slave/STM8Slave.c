#include "STM8Slave.h"
#include "LCD.h"
#include "iic.h"
#include "delay.h"
#define STM8_Slave_Addr 0x4A

union STM8_Slave_Data_Union STM8_Slave_Data;
uint16_t STM8_Slave_EERPOM_Write_Cnt;
#define STM8_Slave_EEPROM_Write_Time 10000//10Ãë

void STM8Slave_Wait_Busy(void)
{
	uint8_t Slave_Cache;
	//uint32_t i=0;
	while(1)
	{
		//i++;
		IIC_Read(STM8_Slave_Addr,1,1,&Slave_Cache);
		if((Slave_Cache&0x04)==0)return;	
		delay_us(200);
	}
}

void STM8Slave_MAX2871_ON_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC0,0,0);
	delay_us(100);
	STM8Slave_Wait_Busy();
}

void STM8Slave_MAX2871_OFF_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC1,0,0);
	STM8Slave_Wait_Busy();
}

void STM8Slave_Read_EEPROM_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC2,0,0);
	STM8Slave_Wait_Busy();
}

void STM8Slave_Write_EEPROM_CMD(void)
{
	STM8Slave_Wait_Busy();
	IIC_Write(STM8_Slave_Addr,0xC3,0,0);	
	delay_ms(6);
	STM8Slave_Wait_Busy();
}

void STM8Slave_Write_PLL_CFG_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC4,0,0);
	delay_ms(2);
	STM8Slave_Wait_Busy();
}

void STM8Slave_Read_PLL_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC5,0,0);
	delay_ms(1);
	STM8Slave_Wait_Busy();
}

void STM8Slave_Auto_Read_PLL_ON_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC6,0,0);
	STM8Slave_Wait_Busy();
}

void STM8Slave_PLL_ON_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC7,0,0);
	delay_ms(1);
	STM8Slave_Wait_Busy();
}

void STM8Slave_PLL_OFF_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC8,0,0);
	delay_ms(1);
	STM8Slave_Wait_Busy();
}
void STM8Slave_PLL_RESET_CMD(void)
{
	IIC_Write(STM8_Slave_Addr,0xC9,0,0);
	delay_ms(1);
	STM8Slave_Wait_Busy();
}

void STM8Slave_Init(void)
{
	uint8_t Slave_Cache;
	IIC1_Init();
	while(1)
	{
		if(IIC_Check_Slave(STM8_Slave_Addr) == 0)
		{
			if(IIC_Read(STM8_Slave_Addr,0,1,&Slave_Cache))
			{
				if(Slave_Cache == 0xA5)break;
			}
		}
		LCD_Clear(WHITE);
		delay_ms(100);
		LCD_ShowString(0,0,"IIC CHECK ERROR!",RED);
		delay_ms(400);
	}
	STM8Slave_Read_EEPROM_CMD();
	IIC_Read(STM8_Slave_Addr,0,52,STM8_Slave_Data.IIC_Buff);
	STM8Slave_PLL_RESET_CMD();
	STM8Slave_Write_PLL_CFG_CMD();
}

void STM8_Slave_Set_MAX2871_Freq_Power(void)
{
	IIC_Write(STM8_Slave_Addr,0x03,5,&(STM8_Slave_Data.IIC_Buff[3]));
	if((STM8_Slave_Data.Data_Struct.Microwave_Source_Status&0x01)==0x01)
	{
		STM8Slave_MAX2871_ON_CMD();
	}
	else
	{
		STM8Slave_MAX2871_OFF_CMD();
	}
}

void STM8_Slave_Send_PLL_Cfg(void)
{
	IIC_Write(STM8_Slave_Addr,0x08,34,&(STM8_Slave_Data.IIC_Buff[0x08]));	
	STM8Slave_Write_PLL_CFG_CMD();
}

void STM8_Slave_Read_Status(void)
{
	STM8Slave_Read_PLL_CMD();
	IIC_Read(STM8_Slave_Addr,0x01,2,&(STM8_Slave_Data.IIC_Buff[0x01]));	
	IIC_Read(STM8_Slave_Addr,0x2A,10,&(STM8_Slave_Data.IIC_Buff[0x2A]));	
}

void STM8_Slave_EEPROM_Write_Trigger(void)
{
	STM8_Slave_EERPOM_Write_Cnt = 1;
}
void STM8_Slave_EEPROM_Writer_Time_Service(void)
{
	if(STM8_Slave_EERPOM_Write_Cnt)
	{
		STM8_Slave_EERPOM_Write_Cnt++;
		if(STM8_Slave_EERPOM_Write_Cnt>STM8_Slave_EEPROM_Write_Time)STM8_Slave_EERPOM_Write_Cnt = STM8_Slave_EEPROM_Write_Time;
	}
}
void STM8_Slave_EEPROM_Write_Service(void)
{
	if(STM8_Slave_EERPOM_Write_Cnt>=STM8_Slave_EEPROM_Write_Time)
	{
		STM8Slave_Write_EEPROM_CMD();
		STM8_Slave_EERPOM_Write_Cnt = 0;
	}
}

