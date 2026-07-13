#include "display.h"
#include "lcd.h"
#include "STM8Slave.h"
#include "control.h"
#include "ADC.h"

typedef struct
{
	uint16_t X;
	uint16_t Y;
	uint16_t Wide;
	uint16_t Show_Color;
	uint16_t Back_Color;
	uint8_t Blink_Timer;
	uint8_t Blink_Cnt;
	uint8_t Str[8];
}Display_UI_Blink_TypeDef;

Display_UI_Blink_TypeDef Display_UI_Blink_Data;
#define Blink_Times 12
#define Blink_Cycle 150

void Display_UI_Blink_Show(uint8_t Show)
{
	uint16_t Color_Cache;
	if(Show)
	{
		Color_Cache = BACK_COLOR;
		BACK_COLOR = Display_UI_Blink_Data.Back_Color;
		LCD_16ShowString_hanzi(Display_UI_Blink_Data.X,Display_UI_Blink_Data.Y,Display_UI_Blink_Data.Str,Display_UI_Blink_Data.Show_Color);
		BACK_COLOR = Color_Cache;
	}
	else
	{
		LCD_Show_Square(Display_UI_Blink_Data.X,Display_UI_Blink_Data.Y,Display_UI_Blink_Data.Wide,16,Display_UI_Blink_Data.Back_Color);
	}
}

void Display_UI_Blink_Show_Stop(void)
{
	Display_UI_Blink_Data.Blink_Timer = 0;
	if(Display_UI_Blink_Data.Blink_Cnt)
	{
		Display_UI_Blink_Show(1);
	}
	Display_UI_Blink_Data.Blink_Cnt = 0;
}

void Display_UI_Blink_Show_Register(uint16_t x,uint16_t y,uint8_t* Str,uint16_t color)
{
	uint32_t i;
	Display_UI_Blink_Show_Stop();
	Display_UI_Blink_Data.Show_Color = color;
	Display_UI_Blink_Data.Back_Color = BACK_COLOR;
	Display_UI_Blink_Data.X = x;
	Display_UI_Blink_Data.Y = y;
	for(i=0;i<7;i++)
	{
		Display_UI_Blink_Data.Str[i] = Str[i];
		if(Str[i] == '\0')break;
	}
	Display_UI_Blink_Data.Str[7] = '\0';
	Display_UI_Blink_Data.Wide = i*8;
	Display_UI_Blink_Data.Blink_Cnt = Blink_Times*2;
	Display_UI_Blink_Data.Blink_Timer = 250;
	Display_UI_Blink_Show(1);
}

void Display_UI_Timer_Service(void)
{
	if(Display_UI_Blink_Data.Blink_Cnt)
	{
		if(Display_UI_Blink_Data.Blink_Timer)Display_UI_Blink_Data.Blink_Timer--;
	}
}

void Display_UI_Show_Modulator_Vbias(void);

void Display_UI_Show_Service(void)
{
	if(Display_UI_Blink_Data.Blink_Cnt)
	{
		if(Display_UI_Blink_Data.Blink_Timer == 0)
		{
			Display_UI_Blink_Data.Blink_Timer = Blink_Cycle;
			Display_UI_Blink_Show(Display_UI_Blink_Data.Blink_Cnt&0x01);
			Display_UI_Blink_Data.Blink_Cnt--;
		}
	}
	if(ADC_Value_Valid)
	{
		Display_UI_Show_Modulator_Vbias();
		ADC_Value_Valid = 0;
	}		
}
//get blink status
uint32_t Display_UI_Get_Status(void)
{
	return Display_UI_Blink_Data.Blink_Cnt;
}

uint8_t U32_Dec_Buff[10];
__asm uint32_t Fun_Div10(uint32_t Data,uint8_t* Out_Buff)
{
	PUSH {R1}
	MOVS R1,R0
	
	LSRS R0,R0,#2
	SUBS R0,R1,R0
	LSRS R2,R0,#4
	ADDS R0,R2,R0
	LSRS R2,R0,#8
	ADDS R0,R2,R0
	LSRS R2,R0,#16
	ADDS R0,R2,R0
	
	LSRS R0,R0,#3
	LSLS R2,R0,#2
	ADDS R2,R2,R0
	LSLS R2,R2,#1
	SUBS R1,R1,R2
	
//	CMP	R1,#0x0A
//	BCC No_fix_up
//	SUBS R1,R1,#0x0A
//	ADDS R0,R0,#1	
//	No_fix_up
	POP	{R2}
	STRB R1,[R2]
	BX LR
}

void Display_U32toDec(uint32_t Data)
{
	uint32_t i;
	for(i=0;i<10;i++)
	{
		Data = Fun_Div10(Data,U32_Dec_Buff+i);
		if(U32_Dec_Buff[i]>=10)
		{
			U32_Dec_Buff[i] -= 10;
			Data++;
		}
		//U32_Dec_Buff[i] = Data%10;
		//Data = Data/10;
		if(Data == 0){i++; break;}
	}
	for(;i<10;i++)U32_Dec_Buff[i] = 0;
}

void Display_UI_Microwave_Source_Refresh_Status(void)
{
	BACK_COLOR = WHITE;
	if((STM8_Slave_Data.Data_Struct.Microwave_Source_Status&0x03)==0x03)
	{
		LCD_SHOW_Icon_1612(146,16,0,DARKGREEN);//Lock		
	}
	else
	{
		LCD_SHOW_Icon_1612(146,16,1,BRRED);//Unlock		
	}	
}

void Display_UI_Microwave_Source_Status(uint32_t Blink)
{
	BACK_COLOR = WHITE;
	if((STM8_Slave_Data.Data_Struct.Microwave_Source_Status&0x01)==0x01)
	{
		LCD_16ShowString_hanzi(64,0,"开",GREEN);
		if(Blink)Display_UI_Blink_Show_Register(64,0,"开",GREEN);
		if((STM8_Slave_Data.Data_Struct.Microwave_Source_Status&0x02)==0x02)
		{
			LCD_SHOW_Icon_1612(146,16,0,DARKGREEN);//Lock		
		}
		else
		{
			LCD_SHOW_Icon_1612(146,16,1,BRRED);//Unlock		
		}
	}
	else
	{
		LCD_16ShowString_hanzi(64,0,"关",RED);
		if(Blink)Display_UI_Blink_Show_Register(64,0,"关",RED);
		LCD_SHOW_Icon_1612(146,16,1,BRRED);//Unlock		
	}
	//LCD_Show_Square(146,17,16,1,LGRAY);
}

const uint8_t Power_Char[]="弱\0小\0中\0大";
void Display_UI_Microwave_Source_Power(uint32_t Blink)
{
	uint8_t Cache;
	BACK_COLOR = WHITE;
	Cache = STM8_Slave_Data.Data_Struct.Microwave_Source_Power&0x03;
	Cache = Cache*3;
	LCD_16ShowString_hanzi(112,0,(uint8_t*)&Power_Char[Cache],BLUE);
	if(Blink)Display_UI_Blink_Show_Register(112,0,(uint8_t*)&Power_Char[Cache],BLUE);
}

//Blink_Bit 7-1GHz ---> 1-1KHz
void Display_UI_Microwave_Source_Freq(uint32_t Blink_Bit)
{
	uint32_t i,Last_Bit_x = 54+48+4;
	uint8_t Blink_Cache[2];
	BACK_COLOR = WHITE;
	Display_U32toDec(STM8_Slave_Data.Data_Struct.Microwave_Source_Frequency);
	for(i=0;i<7;i++)
	{
		LCD_SHOW_ASCII_1608(Last_Bit_x,16,U32_Dec_Buff[i]+'0',DARKBLUE);
		if(Blink_Bit == (i+1))
		{
			Blink_Cache[0] = U32_Dec_Buff[i]+'0';
			Blink_Cache[1] = '\0';
			Display_UI_Blink_Show_Register(Last_Bit_x,16,Blink_Cache,DARKBLUE);
		}
		Last_Bit_x -=8;
		if(i == 5)Last_Bit_x -=4;
		if(i == 4)LCD_SHOW_ASCII_1608(Last_Bit_x-4,16,'.',DARKBLUE);
	}
}

void Display_UI_Show_Modulator_Vbias(void)
{
	int16_t Vbias = ADC_VBIAS_Voltage;
	BACK_COLOR = WHITE;
	if(Vbias<0)
	{
		LCD_SHOW_ASCII_0806(132,9,11,INDIANRED);//-
		Vbias = -Vbias;
	}
	else
	{
		LCD_SHOW_ASCII_0806(132,9,10,INDIANRED);//+
	}
	Display_U32toDec(Vbias);
	LCD_SHOW_ASCII_0806(144,9,12,INDIANRED);//.
	LCD_SHOW_ASCII_0806(138,9,U32_Dec_Buff[3],INDIANRED);
	LCD_SHOW_ASCII_0806(148,9,U32_Dec_Buff[2],INDIANRED);
	
}

void Display_UI_Microwave_Source_Init(void)
{
	BACK_COLOR = LIGHTCYAN;
	LCD_16ShowString_hanzi(14,0,"微波源",BLACK);	
	BACK_COLOR = WHITE;
	LCD_16ShowString_hanzi(80,0,"功率",BLACK);	
	LCD_16ShowString_hanzi(14,16,"频率:",BLACK);
	LCD_16ShowString_hanzi(116,16,"GHz",BLACK);	
	
	LCD_SHOW_ASCII_0806(130,0,13,GRAYBLUE);//V
	LCD_SHOW_ASCII_0806(136,0,14,GRAYBLUE);//B
	LCD_SHOW_ASCII_0806(142,0,15,GRAYBLUE);//I
	LCD_SHOW_ASCII_0806(148,0,16,GRAYBLUE);//A
	LCD_SHOW_ASCII_0806(154,0,17,GRAYBLUE);//S
	LCD_SHOW_ASCII_0806(154,9,13,GRAYBLUE);//V
	LCD_Show_Square(128,0,1,17,LGRAY);
	LCD_Show_Square(128,17,32,1,LGRAY);
	
	Display_UI_Microwave_Source_Status(0);
	Display_UI_Microwave_Source_Power(0);
	Display_UI_Microwave_Source_Freq(0);
	Display_UI_Show_Modulator_Vbias();
	
	//LCD_16ShowString_hanzi(128,0,"+9.5V",BLACK);		
}

//Blink_Bit 7-100KHz ---> 1-0.1Hz
//input frequency-->1mHz
void Display_UI_Show_PLL_Set_Freq(uint32_t Blink_Bit)
{
	uint32_t i,First_Bit_x;
	uint8_t Blink_Cache[2];
	uint32_t EnShow = 0;
	Display_U32toDec(Set_Frequency);
	BACK_COLOR = WHITE;
	i=7;
	First_Bit_x = 84;
	while(i)
	{
		i--;
		if(U32_Dec_Buff[i+2]!=0)EnShow = 1;
		if(i==1)EnShow = 1;
		if(Blink_Bit>i)EnShow = 1;
		if(EnShow)
		{
			LCD_SHOW_ASCII_1608(First_Bit_x,49,U32_Dec_Buff[i+2]+'0',DARKBLUE);
			if(Blink_Bit == (i+1))
			{
				Blink_Cache[0] = U32_Dec_Buff[i+2]+'0';
				Blink_Cache[1] = '\0';
				Display_UI_Blink_Show_Register(First_Bit_x,49,Blink_Cache,DARKBLUE);
			}			
		}
		else
		{
			LCD_SHOW_ASCII_1608(First_Bit_x,49,' ',DARKBLUE);
		}		
		First_Bit_x +=8;
		if(i == 1)
		{
			LCD_SHOW_ASCII_1608(First_Bit_x,49,'.',DARKBLUE);
			First_Bit_x += 4;
		}
	}
}

void Display_UI_Show_Num(uint16_t x,uint16_t y,uint32_t Num,uint32_t length,uint32_t Blink_Bit,uint16_t Color)
{
	uint32_t i = length;
	uint8_t Blink_Cache[2];
	uint32_t EnShow = 0;
	Display_U32toDec(Num);
	BACK_COLOR = WHITE;
	while(i)
	{
		i--;
		if(U32_Dec_Buff[i]!=0)EnShow = 1;
		if(i==0)EnShow = 1;
		if(Blink_Bit>i)EnShow = 1;
		if(EnShow)
		{
			LCD_SHOW_ASCII_1608(x,y,U32_Dec_Buff[i]+'0',Color);
			if(Blink_Bit == (i+1))
			{
				Blink_Cache[0] = U32_Dec_Buff[i]+'0';
				Blink_Cache[1] = '\0';
				Display_UI_Blink_Show_Register(x,y,Blink_Cache,Color);
			}			
		}
		else
		{
			LCD_SHOW_ASCII_1608(x,y,' ',Color);
		}		
		x +=8;
	}	

}


void Display_UI_PLL_Enable(uint32_t Blink)
{
	BACK_COLOR = WHITE;
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x20)==0x20)
	{
		LCD_16ShowString_hanzi(64,33,"开",GREEN);
		if(Blink)Display_UI_Blink_Show_Register(64,33,"开",GREEN);
	}
	else
	{
		LCD_16ShowString_hanzi(64,33,"关",RED);
		if(Blink)Display_UI_Blink_Show_Register(64,33,"关",RED);
	}
}
void Display_UI_Show_PLL_Amplitude(uint32_t Blink_Bit)
{
	uint32_t i,First_Bit_x;
	uint8_t Blink_Cache[2];
	//uint32_t Ampt = (STM8_Slave_Data.Data_Struct.PLL_DAC_Amplitude)*2000/32768+1;//0~32768
	//Display_U32toDec(Ampt);
	Display_U32toDec(Set_Amplitude);
	i=3;
	First_Bit_x = 48;
	while(i)
	{
		i--;
		LCD_SHOW_ASCII_1608(First_Bit_x,81,U32_Dec_Buff[i+1]+'0',DARKBLUE);
		if(Blink_Bit == (i+1))
		{
			Blink_Cache[0] = U32_Dec_Buff[i+1]+'0';
			Blink_Cache[1] = '\0';
			Display_UI_Blink_Show_Register(First_Bit_x,81,Blink_Cache,DARKBLUE);
		}	
		First_Bit_x +=8;
		if(i == 2)
		{
			LCD_SHOW_ASCII_1608(First_Bit_x,81,'.',DARKBLUE);
			First_Bit_x += 4;
		}
	}		
	
}

uint32_t PLL_Hex2Freq(uint32_t Hex);

void Display_UI_Show_PLL_Out_Freq(void)
{
	uint32_t i,First_Bit_x;
	uint32_t EnShow = 0;
	int32_t PID_OUT;
	uint32_t Frequency;//mHz
	PID_OUT = STM8_Slave_Data.Data_Struct.PLL_PID_OUT;
	PID_OUT/=16;
	Frequency = STM8_Slave_Data.Data_Struct.PLL_Center_Frequency + PID_OUT;
	Frequency = PLL_Hex2Freq(Frequency);
	Display_U32toDec(Frequency);
	BACK_COLOR = WHITE;
	i=10;
	First_Bit_x = 48;
	while(i)
	{
		i--;
		if(U32_Dec_Buff[i]!=0)EnShow = 1;
		if(i==1)EnShow = 1;
		if(EnShow)
		{
			LCD_SHOW_ASCII_1608(First_Bit_x,112,U32_Dec_Buff[i]+'0',INDIANRED);		
		}
		else
		{
			LCD_SHOW_ASCII_1608(First_Bit_x,112,' ',INDIANRED);
		}		
		First_Bit_x +=8;
		if(i == 3)
		{
			LCD_SHOW_ASCII_1608(First_Bit_x,112,'.',INDIANRED);
			First_Bit_x += 4;
		}
	}
}

void Display_UI_Show_PLL_Mux_Div_Index(uint32_t Blink_Bit_Mul ,uint32_t Blink_Bit_Div)
{	
	Display_UI_Show_Num(88,65,STM8_Slave_Data.Data_Struct.PLL_Mul_Index,4,Blink_Bit_Mul,DARKBLUE);//Mul
	Display_UI_Show_Num(128,65,STM8_Slave_Data.Data_Struct.PLL_Div_Index,4,Blink_Bit_Div,DARKBLUE);//Div
}

void Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(uint32_t Blink_Bit_Freq ,uint32_t Blink_Bit_Phase)
{
	Display_UI_Show_Num(132,81,STM8_Slave_Data.Data_Struct.PLL_Freq_Residuals_Threshold,3,Blink_Bit_Freq,DARKBLUE);//Freq Residuals Threshold
	Display_UI_Show_Num(56,97,STM8_Slave_Data.Data_Struct.PLL_Phase_Residuals_Threshold,4,Blink_Bit_Phase,DARKBLUE);//Phase Residuals Threshold	
}

void Display_UI_PLL_Refresh_Status(void)
{
	int32_t Cache;
	//Phase Residuals
	Cache = (int32_t)STM8_Slave_Data.Data_Struct.PLL_Phase_Residuals;
	if(Cache<0)
	{
		LCD_SHOW_ASCII_1608(100,97,'-',INDIANRED);
		Cache = -Cache;
	}
	else
	{
		LCD_SHOW_ASCII_1608(100,97,'+',INDIANRED);
	}	
	Display_UI_Show_Num(108,97,Cache,6,0,INDIANRED);
	Display_UI_PLL_Enable(0);
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x80)==0x80)//offline
	{
		LCD_Show_Square(82,33,72,16,WHITE);
		LCD_SHOW_Icon_1612(82,33,14,BRRED);
		return;
	}
	else
	{
		LCD_Show_Square(82,33,12,16,WHITE);//OK	
	}
	
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x10)==0x10)
	{
		LCD_SHOW_Icon_1612(82,33,0,DARKGREEN);//Lock
	}
	else
	{
		LCD_SHOW_Icon_1612(82,33,1,BRRED);//Unlock		
	}		
	
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x01)==0x01)
	{
		LCD_SHOW_Icon_1612(94,33,6,RED);//phase out	
	}
	else
	{
		LCD_Show_Square(94,33,12,16,WHITE);//OK	
	}	
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x02)==0x02)
	{
		LCD_SHOW_Icon_1612(106,33,7,RED);//freq out	
	}
	else
	{
		LCD_Show_Square(106,33,12,16,WHITE);//OK	
	}	
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x04)==0x04)
	{
		LCD_SHOW_Icon_1612(130,33,9,RED);//down out	
	}
	else
	{
		LCD_Show_Square(130,33,12,16,WHITE);//OK	
	}	
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x08)==0x08)
	{
		LCD_SHOW_Icon_1612(118,33,8,RED);//up out	
	}
	else
	{
		LCD_Show_Square(118,33,12,16,WHITE);//OK	
	}	
	if((STM8_Slave_Data.Data_Struct.PLL_Status&0x40)==0x40)
	{
		LCD_SHOW_Icon_1612(142,33,15,RED);//Communication error
	}
	else
	{
		LCD_Show_Square(142,33,12,16,WHITE);//OK	
	}	
	Display_UI_Show_PLL_Out_Freq();
}

void Display_UI_PLL_Main_Page_Init(void)
{
	LCD_Show_Square(14,33,146,95,WHITE);
	BACK_COLOR = LIGHTCYAN;
	LCD_16ShowString_hanzi(14,33,"锁相环",BLACK);	
	BACK_COLOR = WHITE;
//LCD_16ShowString_hanzi(64,33,"关",RED);	
	LCD_16ShowString_hanzi(14,49,"中心频率:",BLACK);	
	LCD_16ShowString_hanzi(144,49,"Hz",BLACK);		
	
	LCD_SHOW_ASCII_1608(59,65,':',BLACK);
	LCD_16ShowString_hanzi(14,65,"倍除频",BLACK);
	LCD_16ShowString_hanzi(64,65,"40%    &",BLACK);
	//LCD_SHOW_ASCII_1608(117,65,':',BLACK);	
//LCD_16ShowString_hanzi(48,65,"99999",BLACK);
	//LCD_16ShowString_hanzi(88,65,"除频",BLACK);	
//LCD_16ShowString_hanzi(124,65,"9999",BLACK);
	
	LCD_SHOW_ASCII_1608(43,81,':',BLACK);
	LCD_SHOW_ASCII_1608(125,81,':',BLACK);
	LCD_16ShowString_hanzi(14,81,"幅度",BLACK);
	LCD_SHOW_ASCII_1608(76,81,'V',BLACK);	
	LCD_16ShowString_hanzi(88,81,"频残T",BLACK);
//LCD_16ShowString_hanzi(132,81,"999",BLACK);
	LCD_SHOW_ASCII_1608(51,97,':',BLACK);	
	LCD_16ShowString_hanzi(14,97,"相残T",BLACK);	
//LCD_16ShowString_hanzi(56,97,"9999",BLACK);
	LCD_SHOW_ASCII_1608(93,97,':',GRAYBLUE);	
	LCD_SHOW_ASCII_1608(88,97,'N',GRAYBLUE);	
//LCD_16ShowString_hanzi(100,97,"-999999",BLACK);

	LCD_SHOW_ASCII_1608(43,112,':',GRAYBLUE);
	LCD_16ShowString_hanzi(14,112,"输出",GRAYBLUE);	
	LCD_16ShowString_hanzi(132,112,"Hz",GRAYBLUE);	
	
	
	Display_UI_PLL_Enable(0);
	Display_UI_Show_PLL_Set_Freq(0);
	Display_UI_Show_PLL_Mux_Div_Index(0,0);
	Display_UI_Show_PLL_Freq_Phase_Residuals_Threshold(0,0);
	Display_UI_Show_PLL_Amplitude(0);
	Display_UI_PLL_Refresh_Status();
}


void Display_UI_Show_PLL_Up_Down_Limit(uint32_t Blink_Bit_Up ,uint32_t Blink_Bit_Down)
{	
	Display_UI_Show_Num(104,96,Set_UpperLimit,5,Blink_Bit_Up,DARKBLUE);//up
	Display_UI_Show_Num(104,112,-Set_LowerLimit,5,Blink_Bit_Down,DARKBLUE);//down
}

void Display_UI_Show_PLL_PID_Value(uint32_t Blink_Bit_P ,uint32_t Blink_Bit_I ,uint32_t Blink_Bit_II ,uint32_t Blink_Bit_D)
{
	Display_UI_Show_Num(80,33,STM8_Slave_Data.Data_Struct.PLL_Gain_P,10,Blink_Bit_P,DARKBLUE);//P
	Display_UI_Show_Num(80,49,STM8_Slave_Data.Data_Struct.PLL_Gain_I,10,Blink_Bit_I,DARKBLUE);//I
	Display_UI_Show_Num(80,64,STM8_Slave_Data.Data_Struct.PLL_Gain_II,10,Blink_Bit_II,DARKBLUE);//II
	Display_UI_Show_Num(80,81,STM8_Slave_Data.Data_Struct.PLL_Gain_D,10,Blink_Bit_D,DARKBLUE);//D
}

void Display_UI_PLL_Vice_Page_Init(void)
{
	LCD_Show_Square(14,33,146,95,WHITE);
	BACK_COLOR = LIGHTCYAN;
	LCD_16ShowString_hanzi(14,33,"锁",BLACK);	
	LCD_16ShowString_hanzi(14,49,"相",BLACK);	
	LCD_16ShowString_hanzi(14,65,"环",BLACK);	
	BACK_COLOR = WHITE;	
	
	LCD_SHOW_ASCII_1608(75,33,':',BLACK);
	LCD_SHOW_ASCII_1608(75,49,':',BLACK);
	LCD_SHOW_ASCII_1608(75,65,':',BLACK);
	LCD_SHOW_ASCII_1608(75,81,':',BLACK);
	LCD_16ShowString_hanzi(30,33,"P 参数",BLACK);
	LCD_16ShowString_hanzi(30,49,"I 参数",BLACK);
	LCD_16ShowString_hanzi(30,64,"II参数",BLACK);
	LCD_16ShowString_hanzi(30,81,"D 参数",BLACK);
	
	LCD_SHOW_ASCII_1608(91,96,':',BLACK);
	LCD_SHOW_ASCII_1608(91,112,':',BLACK);	
	LCD_SHOW_ASCII_1608(96,96,'+',BLACK);
	LCD_SHOW_ASCII_1608(96,112,'-',BLACK);
	LCD_16ShowString_hanzi(30,96,"输",BLACK);
	LCD_16ShowString_hanzi(46,97,"出上限",BLACK);
	//LCD_16ShowString_hanzi(30,97,"输出上限",BLACK);
	LCD_16ShowString_hanzi(30,112,"输出下限",BLACK);
	LCD_16ShowString_hanzi(144,96,"Hz",BLACK);
	LCD_16ShowString_hanzi(144,112,"Hz",BLACK);
	
	
	Display_UI_Show_PLL_Up_Down_Limit(0,0);
	Display_UI_Show_PLL_PID_Value(0,0,0,0);
}



void Display_UI_Init(void)
{
	LCD_Clear(WHITE);
	LCD_Show_Square(13,0,1,128,LGRAY);
	LCD_Show_Square(14,32,146,1,LGRAY);
	
	LCD_SHOW_Icon_1612(0,17,10, LGRAYBLUE);//ms
	LCD_SHOW_Icon_1612(0,51,11, LGRAYBLUE);//pll
	LCD_SHOW_Icon_1612(0,75,12, LGRAYBLUE);//P1
	LCD_SHOW_Icon_1612(0,112,13,LGRAYBLUE);//P2
	
	LCD_SHOW_Icon_1612(0,2,5,GRAY);//Left
	LCD_SHOW_Icon_1612(0,36,4,GRAY);//Right
	LCD_SHOW_Icon_1612(1,68,2,GRAY);//Up
	LCD_SHOW_Icon_1612(1,105,3,GRAY);//Down
	
	STM8_Slave_Read_Status();
	Display_UI_Microwave_Source_Init();
	Display_UI_PLL_Main_Page_Init();
}










