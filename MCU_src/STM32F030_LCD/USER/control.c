#include "stm32f0xx.h"
#include "control.h"
#include "delay.h"
#include "STM8Slave.h"
#include "display.h"
#include "ENCODER.h"


uint32_t Set_Frequency;
uint32_t Set_Amplitude;
int32_t Set_UpperLimit;
int32_t Set_LowerLimit;
uint8_t Adjust_Index0;
uint8_t Adjust_Index1 = 3;
uint8_t Pgae_Num;
#define PAGE0_MAX_ADJ_INDEX 10
#define PAGE1_MAX_ADJ_INDEX 9

typedef enum
{
	Blink = 0,
	Cursor_Left,
	Cursor_Right,
	Value_Add,
	Value_Sub,
	Value_Fast_Add,
	Value_Fast_Sub	
}Ctrl_Cursor_Enum;
uint8_t CtrlP0I2_Cursor;
uint8_t CtrlP0I4_Cursor;
uint8_t CtrlP0I5_Cursor;
uint8_t CtrlP0I6_Cursor;
uint8_t CtrlP0I7_Cursor;
uint8_t CtrlP0I8_Cursor;
uint8_t CtrlP0I9_Cursor;

uint8_t CtrlP1I3_Cursor;
uint8_t CtrlP1I4_Cursor;
uint8_t CtrlP1I5_Cursor;
uint8_t CtrlP1I6_Cursor;
uint8_t CtrlP1I7_Cursor;
uint8_t CtrlP1I8_Cursor;

const uint32_t POW10[11]=
{
	0,1,10,100,1000,10000,
	100000,1000000,10000000,100000000,1000000000
};

uint32_t PLL_Freq2Hex(uint32_t Freq)
{
	return (uint32_t)((uint64_t)Freq*0x100000000/(uint64_t)3125000000u);
}
uint32_t PLL_Hex2Freq(uint32_t Hex)
{
	return (uint32_t)((uint64_t)Hex*(uint64_t)3125000000u/0x100000000)+1;
}


void CtrlP0I0_Microwave_Source_Enable(Ctrl_Cursor_Enum COpt)
{
	switch(COpt)
	{
		case Value_Add:
		case Value_Sub:
		case Value_Fast_Add:	
		case Value_Fast_Sub:		
			if((STM8_Slave_Data.Data_Struct.Microwave_Source_Status&0x01)==0x01)
			{
				STM8Slave_MAX2871_OFF_CMD();
			}
			else
			{
				STM8Slave_MAX2871_ON_CMD();
			}
			STM8_Slave_Read_Status();
		case Blink:
		case Cursor_Left:
		case Cursor_Right:
			Display_UI_Microwave_Source_Status(1);
			break;
		default:break;
	}
}
void CtrlP0I1_Microwave_Source_Power(Ctrl_Cursor_Enum COpt)
{
	uint8_t Cache;
	Cache = STM8_Slave_Data.Data_Struct.Microwave_Source_Power&0x03;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			if(Cache<3)Cache++;
			STM8_Slave_Data.Data_Struct.Microwave_Source_Power = Cache;
			STM8_Slave_Set_MAX2871_Freq_Power();
			Display_UI_Microwave_Source_Power(1);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(Cache>0)Cache--;	
			STM8_Slave_Data.Data_Struct.Microwave_Source_Power = Cache;
			STM8_Slave_Set_MAX2871_Freq_Power();
			Display_UI_Microwave_Source_Power(1);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Blink:
		case Cursor_Left:
		case Cursor_Right:
			Display_UI_Microwave_Source_Power(1);
			break;
		default:break;
	}	
}


void CtrlP0I2_Microwave_Source_Frequency(Ctrl_Cursor_Enum COpt)
{
	uint32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = STM8_Slave_Data.Data_Struct.Microwave_Source_Frequency + POW10[CtrlP0I2_Cursor];
			if(Cache<=6400000)
			{
				STM8_Slave_Data.Data_Struct.Microwave_Source_Frequency = Cache;
				STM8_Slave_Set_MAX2871_Freq_Power();			
			}
			Display_UI_Microwave_Source_Freq(CtrlP0I2_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			Cache = POW10[CtrlP0I2_Cursor] + 23500;
			if(STM8_Slave_Data.Data_Struct.Microwave_Source_Frequency>Cache)	
			{
				STM8_Slave_Data.Data_Struct.Microwave_Source_Frequency -= POW10[CtrlP0I2_Cursor];
				STM8_Slave_Set_MAX2871_Freq_Power();
			}
			Display_UI_Microwave_Source_Freq(CtrlP0I2_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP0I2_Cursor++;
			if(CtrlP0I2_Cursor>7)CtrlP0I2_Cursor = 2;
			Display_UI_Microwave_Source_Freq(CtrlP0I2_Cursor);
			break;
		case Cursor_Right:
			CtrlP0I2_Cursor--;
			if(CtrlP0I2_Cursor<2)CtrlP0I2_Cursor = 7;
			Display_UI_Microwave_Source_Freq(CtrlP0I2_Cursor);
			break;
		case Blink:
			Display_UI_Microwave_Source_Freq(CtrlP0I2_Cursor);
			break;
		default:break;
	}		
}
void CtrlP0I3_PLL_Enable(Ctrl_Cursor_Enum COpt)
{
	switch(COpt)
	{
		case Value_Add:
		case Value_Sub:
		case Value_Fast_Add:	
		case Value_Fast_Sub:		
			if((STM8_Slave_Data.Data_Struct.PLL_Status&0x20)==0x20)
			{
				STM8Slave_PLL_OFF_CMD();
			}
			else
			{
				STM8_Slave_Send_PLL_Cfg();
				STM8Slave_PLL_ON_CMD();
			}
			STM8_Slave_Read_Status();
		case Blink:
		case Cursor_Left:
		case Cursor_Right:
			Display_UI_PLL_Enable(1);
			break;
		default:break;
	}	
}
void CtrlP0I4_PLL_Frequency(Ctrl_Cursor_Enum COpt)
{
	uint32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = Set_Frequency + POW10[CtrlP0I4_Cursor];
			if(Cache<=999999000)
			{
				Set_Frequency = Cache;				
				STM8_Slave_Data.Data_Struct.PLL_Center_Frequency = PLL_Freq2Hex(Set_Frequency);
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Set_Freq(CtrlP0I4_Cursor-2);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(Set_Frequency>POW10[CtrlP0I4_Cursor])	
			{
				Set_Frequency -= POW10[CtrlP0I4_Cursor];	
				STM8_Slave_Data.Data_Struct.PLL_Center_Frequency = PLL_Freq2Hex(Set_Frequency);
				STM8_Slave_Send_PLL_Cfg();
			}
			Display_UI_Show_PLL_Set_Freq(CtrlP0I4_Cursor-2);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP0I4_Cursor++;
			if(CtrlP0I4_Cursor>9)CtrlP0I4_Cursor = 3;
			Display_UI_Show_PLL_Set_Freq(CtrlP0I4_Cursor-2);
			break;
		case Cursor_Right:
			CtrlP0I4_Cursor--;
			if(CtrlP0I4_Cursor<3)CtrlP0I4_Cursor = 9;
			Display_UI_Show_PLL_Set_Freq(CtrlP0I4_Cursor-2);
			break;
		case Blink:
			Display_UI_Show_PLL_Set_Freq(CtrlP0I4_Cursor-2);
			break;
		default:break;
	}				
}
void CtrlP0I5_PLL_Mul(Ctrl_Cursor_Enum COpt)
{
	uint32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = STM8_Slave_Data.Data_Struct.PLL_Mul_Index + POW10[CtrlP0I5_Cursor];
			if(Cache<10000)
			{
				STM8_Slave_Data.Data_Struct.PLL_Mul_Index = Cache;				
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Mux_Div_Index(CtrlP0I5_Cursor,0);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(STM8_Slave_Data.Data_Struct.PLL_Mul_Index>(POW10[CtrlP0I5_Cursor]))	
			{
				STM8_Slave_Data.Data_Struct.PLL_Mul_Index -= POW10[CtrlP0I5_Cursor];	
				STM8_Slave_Send_PLL_Cfg();
			}
			Display_UI_Show_PLL_Mux_Div_Index(CtrlP0I5_Cursor,0);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP0I5_Cursor++;
			if(CtrlP0I5_Cursor>4)CtrlP0I5_Cursor = 1;
			Display_UI_Show_PLL_Mux_Div_Index(CtrlP0I5_Cursor,0);
			break;
		case Cursor_Right:
			CtrlP0I5_Cursor--;
			if(CtrlP0I5_Cursor==0)CtrlP0I5_Cursor = 4;
			Display_UI_Show_PLL_Mux_Div_Index(CtrlP0I5_Cursor,0);
			break;
		case Blink:
			Display_UI_Show_PLL_Mux_Div_Index(CtrlP0I5_Cursor,0);
			break;
		default:break;
	}		
}
void CtrlP0I6_PLL_Div(Ctrl_Cursor_Enum COpt)
{
	uint32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = STM8_Slave_Data.Data_Struct.PLL_Div_Index + POW10[CtrlP0I6_Cursor];
			if(Cache<10000)
			{
				STM8_Slave_Data.Data_Struct.PLL_Div_Index = Cache;				
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Mux_Div_Index(0,CtrlP0I6_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(STM8_Slave_Data.Data_Struct.PLL_Div_Index>(POW10[CtrlP0I6_Cursor]))	
			{
				STM8_Slave_Data.Data_Struct.PLL_Div_Index -= POW10[CtrlP0I6_Cursor];	
				STM8_Slave_Send_PLL_Cfg();
			}
			Display_UI_Show_PLL_Mux_Div_Index(0,CtrlP0I6_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP0I6_Cursor++;
			if(CtrlP0I6_Cursor>4)CtrlP0I6_Cursor = 1;
			Display_UI_Show_PLL_Mux_Div_Index(0,CtrlP0I6_Cursor);
			break;
		case Cursor_Right:
			CtrlP0I6_Cursor--;
			if(CtrlP0I6_Cursor==0)CtrlP0I6_Cursor = 4;
			Display_UI_Show_PLL_Mux_Div_Index(0,CtrlP0I6_Cursor);
			break;
		case Blink:
			Display_UI_Show_PLL_Mux_Div_Index(0,CtrlP0I6_Cursor);
			break;
		default:break;
	}
}
void CtrlP0I7_PLL_DAC_Amplitude(Ctrl_Cursor_Enum COpt)
{
	uint32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = Set_Amplitude + POW10[CtrlP0I7_Cursor];
			if(Cache<=2000)
			{
				Set_Amplitude = Cache;
				STM8_Slave_Data.Data_Struct.PLL_DAC_Amplitude = (Set_Amplitude-1)*32768/2000;				
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Amplitude(CtrlP0I7_Cursor-1);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(Set_Amplitude>(POW10[CtrlP0I7_Cursor]+10))	
			{
				Set_Amplitude -= POW10[CtrlP0I7_Cursor];
				STM8_Slave_Data.Data_Struct.PLL_DAC_Amplitude = (Set_Amplitude-1)*32768/2000;	
				STM8_Slave_Send_PLL_Cfg();
			}
			Display_UI_Show_PLL_Amplitude(CtrlP0I7_Cursor-1);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP0I7_Cursor++;
			if(CtrlP0I7_Cursor>4)CtrlP0I7_Cursor = 2;
			Display_UI_Show_PLL_Amplitude(CtrlP0I7_Cursor-1);
			break;
		case Cursor_Right:
			CtrlP0I7_Cursor--;
			if(CtrlP0I7_Cursor<2)CtrlP0I7_Cursor = 4;
			Display_UI_Show_PLL_Amplitude(CtrlP0I7_Cursor-1);
			break;
		case Blink:
			Display_UI_Show_PLL_Amplitude(CtrlP0I7_Cursor-1);
			break;
		default:break;
	}
}
void CtrlP0I8_Freq_Residuals_Threshold(Ctrl_Cursor_Enum COpt)
{
	uint32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = STM8_Slave_Data.Data_Struct.PLL_Freq_Residuals_Threshold + POW10[CtrlP0I8_Cursor];
			if(Cache<10000)
			{
				STM8_Slave_Data.Data_Struct.PLL_Freq_Residuals_Threshold = Cache;				
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(CtrlP0I8_Cursor,0);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(STM8_Slave_Data.Data_Struct.PLL_Freq_Residuals_Threshold>POW10[CtrlP0I8_Cursor])	
			{
				STM8_Slave_Data.Data_Struct.PLL_Freq_Residuals_Threshold -= POW10[CtrlP0I8_Cursor];	
				STM8_Slave_Send_PLL_Cfg();
			}
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(CtrlP0I8_Cursor,0);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP0I8_Cursor++;
			if(CtrlP0I8_Cursor>4)CtrlP0I8_Cursor = 1;
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(CtrlP0I8_Cursor,0);
			break;
		case Cursor_Right:
			CtrlP0I8_Cursor--;
			if(CtrlP0I8_Cursor==0)CtrlP0I8_Cursor = 4;
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(CtrlP0I8_Cursor,0);
			break;
		case Blink:
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(CtrlP0I8_Cursor,0);
			break;
		default:break;
	}		
}
void CtrlP0I9_Phase_Residuals_Threshold(Ctrl_Cursor_Enum COpt)
{
	uint32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = STM8_Slave_Data.Data_Struct.PLL_Phase_Residuals_Threshold + POW10[CtrlP0I9_Cursor];
			if(Cache<10000)
			{
				STM8_Slave_Data.Data_Struct.PLL_Phase_Residuals_Threshold = Cache;				
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(0,CtrlP0I9_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(STM8_Slave_Data.Data_Struct.PLL_Phase_Residuals_Threshold>POW10[CtrlP0I9_Cursor])	
			{
				STM8_Slave_Data.Data_Struct.PLL_Phase_Residuals_Threshold -= POW10[CtrlP0I9_Cursor];	
				STM8_Slave_Send_PLL_Cfg();
			}
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(0,CtrlP0I9_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP0I9_Cursor++;
			if(CtrlP0I9_Cursor>4)CtrlP0I9_Cursor = 1;
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(0,CtrlP0I9_Cursor);
			break;
		case Cursor_Right:
			CtrlP0I9_Cursor--;
			if(CtrlP0I9_Cursor==0)CtrlP0I9_Cursor = 4;
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(0,CtrlP0I9_Cursor);
			break;
		case Blink:
			Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(0,CtrlP0I9_Cursor);
			break;
		default:break;
	}	
}



void (*CtrlP0_Fun[PAGE0_MAX_ADJ_INDEX])(Ctrl_Cursor_Enum)=
{
	CtrlP0I0_Microwave_Source_Enable,
	CtrlP0I1_Microwave_Source_Power,
	CtrlP0I2_Microwave_Source_Frequency,
	CtrlP0I3_PLL_Enable,
	CtrlP0I4_PLL_Frequency,
	CtrlP0I5_PLL_Mul,
	CtrlP0I6_PLL_Div,
	CtrlP0I7_PLL_DAC_Amplitude,
	CtrlP0I8_Freq_Residuals_Threshold,
	CtrlP0I9_Phase_Residuals_Threshold
};


void CtrlP1I3_6_PLL_PID_Value(Ctrl_Cursor_Enum COpt,uint32_t* Value,uint8_t* Cursor)
{
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			if(((uint64_t)*Value + (uint64_t)POW10[*Cursor])<0x100000000)
			{
				*Value = *Value + POW10[*Cursor];				
				STM8_Slave_Send_PLL_Cfg();			
			}
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(*Value>POW10[*Cursor])	
			{
				*Value -= POW10[*Cursor];	
				STM8_Slave_Send_PLL_Cfg();
			}
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			*Cursor = *Cursor + 1;
			if(*Cursor>9)*Cursor = 1;
			break;
		case Cursor_Right:
			*Cursor = *Cursor - 1;
			if(*Cursor==0)*Cursor = 9;
			break;
		default:break;
	}	
}

void CtrlP1I3_PLL_P_Value(Ctrl_Cursor_Enum COpt)
{
	CtrlP1I3_6_PLL_PID_Value(COpt,&STM8_Slave_Data.Data_Struct.PLL_Gain_P,&CtrlP1I3_Cursor);
	Display_UI_Show_PLL_PID_Value(CtrlP1I3_Cursor,0,0,0);
}
void CtrlP1I4_PLL_I_Value(Ctrl_Cursor_Enum COpt)
{
	CtrlP1I3_6_PLL_PID_Value(COpt,&STM8_Slave_Data.Data_Struct.PLL_Gain_I,&CtrlP1I4_Cursor);
	Display_UI_Show_PLL_PID_Value(0,CtrlP1I4_Cursor,0,0);
}
void CtrlP1I5_PLL_II_Value(Ctrl_Cursor_Enum COpt)
{
	CtrlP1I3_6_PLL_PID_Value(COpt,&STM8_Slave_Data.Data_Struct.PLL_Gain_II,&CtrlP1I5_Cursor);
	Display_UI_Show_PLL_PID_Value(0,0,CtrlP1I5_Cursor,0);
}
void CtrlP1I6_PLL_D_Value(Ctrl_Cursor_Enum COpt)
{
	CtrlP1I3_6_PLL_PID_Value(COpt,&STM8_Slave_Data.Data_Struct.PLL_Gain_D,&CtrlP1I6_Cursor);
	Display_UI_Show_PLL_PID_Value(0,0,0,CtrlP1I6_Cursor);
}

void CtrlP1I7_PLL_Up_Limit(Ctrl_Cursor_Enum COpt)
{
	int32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = Set_UpperLimit + POW10[CtrlP1I7_Cursor];
			if(Cache<=97000)
			{
				Set_UpperLimit = Cache;	
				Cache = (int64_t)Set_UpperLimit*0x100000/3125000;
				STM8_Slave_Data.Data_Struct.PLL_Upper_Limit = Cache;
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Up_Down_Limit(CtrlP1I7_Cursor,0);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			if(Set_UpperLimit>POW10[CtrlP1I7_Cursor])	
			{
				Set_UpperLimit -= POW10[CtrlP1I7_Cursor];	
				Cache = (int64_t)Set_UpperLimit*0x100000/3125000;
				STM8_Slave_Data.Data_Struct.PLL_Upper_Limit = Cache;
				STM8_Slave_Send_PLL_Cfg();
			}
			Display_UI_Show_PLL_Up_Down_Limit(CtrlP1I7_Cursor,0);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP1I7_Cursor++;
			if(CtrlP1I7_Cursor>5)CtrlP1I7_Cursor = 2;
			Display_UI_Show_PLL_Up_Down_Limit(CtrlP1I7_Cursor,0);
			break;
		case Cursor_Right:
			CtrlP1I7_Cursor--;
			if(CtrlP1I7_Cursor<2)CtrlP1I7_Cursor = 5;
			Display_UI_Show_PLL_Up_Down_Limit(CtrlP1I7_Cursor,0);
			break;
		case Blink:
			Display_UI_Show_PLL_Up_Down_Limit(CtrlP1I7_Cursor,0);
			break;
		default:break;
	}	
}
void CtrlP1I8_PLL_Down_Limit(Ctrl_Cursor_Enum COpt)
{
	int32_t Cache;
	switch(COpt)
	{
		case Value_Add:
		case Value_Fast_Add:	
			Cache = Set_LowerLimit - POW10[CtrlP1I8_Cursor];
			if(Cache>=-97000)	
			{
				Set_LowerLimit -= POW10[CtrlP1I8_Cursor];	
				Cache = (int64_t)Set_LowerLimit*0x100000/3125000;
				STM8_Slave_Data.Data_Struct.PLL_Lower_Limit = Cache;
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Up_Down_Limit(0,CtrlP1I8_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Value_Sub:
		case Value_Fast_Sub:	
			Cache = Set_LowerLimit + POW10[CtrlP1I8_Cursor];
			if(Cache<0)
			{
				Set_LowerLimit = Cache;	
				Cache = (int64_t)Set_LowerLimit*0x100000/3125000;
				STM8_Slave_Data.Data_Struct.PLL_Lower_Limit = Cache;
				STM8_Slave_Send_PLL_Cfg();			
			}
			Display_UI_Show_PLL_Up_Down_Limit(0,CtrlP1I8_Cursor);
			STM8_Slave_EEPROM_Write_Trigger();
			break;
		case Cursor_Left:
			CtrlP1I8_Cursor++;
			if(CtrlP1I8_Cursor>5)CtrlP1I8_Cursor = 2;
			Display_UI_Show_PLL_Up_Down_Limit(0,CtrlP1I8_Cursor);
			break;
		case Cursor_Right:
			CtrlP1I8_Cursor--;
			if(CtrlP1I8_Cursor<2)CtrlP1I8_Cursor = 5;
			Display_UI_Show_PLL_Up_Down_Limit(0,CtrlP1I8_Cursor);
			break;
		case Blink:
			Display_UI_Show_PLL_Up_Down_Limit(0,CtrlP1I8_Cursor);
			break;
		default:break;
	}	
}
void (*CtrlP1_Fun[PAGE0_MAX_ADJ_INDEX])(Ctrl_Cursor_Enum)=
{
	CtrlP0I0_Microwave_Source_Enable,
	CtrlP0I1_Microwave_Source_Power,
	CtrlP0I2_Microwave_Source_Frequency,
	CtrlP1I3_PLL_P_Value,
	CtrlP1I4_PLL_I_Value,
	CtrlP1I5_PLL_II_Value,
	CtrlP1I6_PLL_D_Value,
	CtrlP1I7_PLL_Up_Limit,
	CtrlP1I8_PLL_Down_Limit
};
//CtrlP0I0_Microwave_Source_Enable(Ctrl_Cursor_Enum COpt)
void Ctrl_KEY_Response_Service(void)
{
	if(Key_Value&KEY1_Long_Press)
	{
		CtrlP0I0_Microwave_Source_Enable(Value_Add);
		Key_Value &= ~KEY1_Long_Press;
	}
	if(Key_Value&KEY2_Long_Press)
	{
		if(Pgae_Num == 0)
		{			
			CtrlP0I3_PLL_Enable(Value_Add);
		}
		Key_Value &= ~KEY2_Long_Press;
	}	
	if(Key_Value&KEY3_Long_Press)
	{
		if(Pgae_Num)
		{			
			Display_UI_Blink_Show_Stop();
			Display_UI_PLL_Main_Page_Init();
			Pgae_Num = 0;
			if(Adjust_Index1 < 3)Adjust_Index0 = Adjust_Index1;
		}
		Key_Value = 0;
	}
	if(Key_Value&KEY4_Long_Press)
	{
		if(Pgae_Num == 0)
		{
			Display_UI_Blink_Show_Stop();
			Display_UI_PLL_Vice_Page_Init();
			Pgae_Num = 1;
			if(Adjust_Index0 < 3)Adjust_Index1 = Adjust_Index0;
		}	
		Key_Value = 0;		
	}	
	
	if(Key_Value&(KEY1_Short_Press|KEY2_Short_Press))
	{
		if(Pgae_Num)//page1
		{
			if(Key_Value&KEY1_Short_Press)//left
			{
				CtrlP1_Fun[Adjust_Index1](Cursor_Left);
			}
			if(Key_Value&KEY2_Short_Press)//right
			{
				CtrlP1_Fun[Adjust_Index1](Cursor_Right);
			}			
		}
		else
		{
			if(Key_Value&KEY1_Short_Press)//left
			{
				CtrlP0_Fun[Adjust_Index0](Cursor_Left);
			}
			if(Key_Value&KEY2_Short_Press)//right
			{
				CtrlP0_Fun[Adjust_Index0](Cursor_Right);
			}				
		}
		Key_Value &= ~(KEY1_Short_Press|KEY2_Short_Press);
	}
	
	if(Key_Value&(KEY3_Short_Press|KEY4_Short_Press))
	{
		if(Pgae_Num)//page1
		{
			if(Key_Value&KEY3_Short_Press)//Up
			{
				if(Adjust_Index1 == 0)Adjust_Index1 = PAGE1_MAX_ADJ_INDEX;
				Adjust_Index1--;
			}
			if(Key_Value&KEY4_Short_Press)//Down
			{
				Adjust_Index1++;
				if(Adjust_Index1 == PAGE1_MAX_ADJ_INDEX)Adjust_Index1 = 0;
			}	
			CtrlP1_Fun[Adjust_Index1](Blink);	
		}
		else
		{
			if(Key_Value&KEY3_Short_Press)//Up
			{
				if(Adjust_Index0 == 0)Adjust_Index0 = PAGE0_MAX_ADJ_INDEX;
				Adjust_Index0--;
			}
			if(Key_Value&KEY4_Short_Press)//Down
			{
				Adjust_Index0++;
				if(Adjust_Index0 == PAGE0_MAX_ADJ_INDEX)Adjust_Index0 = 0;
			}	
			CtrlP0_Fun[Adjust_Index0](Blink);
		}		
		Key_Value &= ~(KEY3_Short_Press|KEY4_Short_Press);
	}
	if(Key_Value&KEY5_Short_Press)
	{
		if(Pgae_Num)			
		{
			CtrlP1_Fun[Adjust_Index1](Blink);
		}
		else
		{
			CtrlP0_Fun[Adjust_Index0](Blink);
		}
		Key_Value &= ~KEY5_Short_Press;		
	}	
	if(Key_Value&Econder_State_UP)
	{
		if(Pgae_Num)			
		{
			if(Display_UI_Get_Status())CtrlP1_Fun[Adjust_Index1](Value_Add);
			else CtrlP1_Fun[Adjust_Index1](Blink);		
		}
		else
		{			
			if(Display_UI_Get_Status())CtrlP0_Fun[Adjust_Index0](Value_Add);
			else CtrlP0_Fun[Adjust_Index0](Blink);
		}
		Key_Value &= ~Econder_State_UP;		
	}	
	if(Key_Value&Econder_State_DOWN)
	{
		if(Pgae_Num)			
		{
			if(Display_UI_Get_Status())CtrlP1_Fun[Adjust_Index1](Value_Sub);
			else CtrlP1_Fun[Adjust_Index1](Blink);		
		}
		else
		{
			if(Display_UI_Get_Status())CtrlP0_Fun[Adjust_Index0](Value_Sub);
			else CtrlP0_Fun[Adjust_Index0](Blink);
		}
		Key_Value &= ~Econder_State_DOWN;		
	}	
}


//int32_t Set_UpLimit;
//int32_t Set_DownLimit;
void Ctrl_Data_Init(void)
{
	Set_Amplitude = (STM8_Slave_Data.Data_Struct.PLL_DAC_Amplitude)*2000/32768+1;//0~32768
	Set_Frequency = PLL_Hex2Freq(STM8_Slave_Data.Data_Struct.PLL_Center_Frequency);
	Set_UpperLimit = (int64_t)STM8_Slave_Data.Data_Struct.PLL_Upper_Limit*3125000/0x100000;
	Set_UpperLimit = (Set_UpperLimit+5)/10;
	Set_LowerLimit = (int64_t)((int16_t)STM8_Slave_Data.Data_Struct.PLL_Lower_Limit)*3125000/0x100000;
	Set_LowerLimit = (Set_LowerLimit-5)/10;
	Set_UpperLimit *=10;
	Set_LowerLimit *=10;
	
	Adjust_Index0 = 2;
	Adjust_Index1 = 0;
	Pgae_Num = 0;
  CtrlP0I2_Cursor = 5;
  CtrlP0I4_Cursor = 7;
  CtrlP0I5_Cursor = 1;
  CtrlP0I6_Cursor = 1;
  CtrlP0I7_Cursor = 3;
  CtrlP0I8_Cursor = 1;
  CtrlP0I9_Cursor = 3;	
	
	
  CtrlP1I3_Cursor = 6;
  CtrlP1I4_Cursor = 6;
  CtrlP1I5_Cursor = 6;
  CtrlP1I6_Cursor = 6;
  CtrlP1I7_Cursor = 4;
  CtrlP1I8_Cursor = 4;
}

uint16_t Refresh_Timer_Cnt = 0;
void Ctrl_Dispaly_Refresh_Timer_Service(void)
{
	Refresh_Timer_Cnt++;
}

void Ctrl_Dispaly_Refresh_Show_Status(void)
{
	if(Refresh_Timer_Cnt>300)
	{
		Refresh_Timer_Cnt = 0;
		STM8_Slave_Read_Status();
		Display_UI_Microwave_Source_Refresh_Status();
		if(Pgae_Num == 0)
		{
			Display_UI_PLL_Refresh_Status();
		}
	}		
}

