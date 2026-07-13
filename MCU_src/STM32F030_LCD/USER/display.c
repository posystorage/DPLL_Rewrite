#include "display.h"
#include "lcd.h"
#include "STM8Slave.h"
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
} Display_UI_Blink_TypeDef;

#define BLINK_TIMES 12U
#define BLINK_CYCLE 150U

static Display_UI_Blink_TypeDef Display_UI_Blink_Data;
static uint8_t U32_Dec_Buff[10];

void Display_U32toDec(uint32_t data);

static void Display_UI_Blink_Show(uint8_t show)
{
	uint16_t color_cache;
	if (show) {
		color_cache = BACK_COLOR;
		BACK_COLOR = Display_UI_Blink_Data.Back_Color;
		LCD_16ShowString_hanzi(Display_UI_Blink_Data.X, Display_UI_Blink_Data.Y,
		                       Display_UI_Blink_Data.Str,
		                       Display_UI_Blink_Data.Show_Color);
		BACK_COLOR = color_cache;
	} else {
		LCD_Show_Square(Display_UI_Blink_Data.X, Display_UI_Blink_Data.Y,
		                Display_UI_Blink_Data.Wide, 16U,
		                Display_UI_Blink_Data.Back_Color);
	}
}

void Display_UI_Blink_Show_Stop(void)
{
	Display_UI_Blink_Data.Blink_Timer = 0U;
	if (Display_UI_Blink_Data.Blink_Cnt) Display_UI_Blink_Show(1U);
	Display_UI_Blink_Data.Blink_Cnt = 0U;
}

static void Display_UI_Blink_Show_Register(uint16_t x, uint16_t y,
		uint8_t *text, uint16_t color)
{
	uint32_t index;
	Display_UI_Blink_Show_Stop();
	Display_UI_Blink_Data.Show_Color = color;
	Display_UI_Blink_Data.Back_Color = BACK_COLOR;
	Display_UI_Blink_Data.X = x;
	Display_UI_Blink_Data.Y = y;
	for (index = 0U; index < 7U; ++index) {
		Display_UI_Blink_Data.Str[index] = text[index];
		if (text[index] == '\0') break;
	}
	Display_UI_Blink_Data.Str[7] = '\0';
	Display_UI_Blink_Data.Wide = (uint16_t)(index * 8U);
	Display_UI_Blink_Data.Blink_Cnt = BLINK_TIMES * 2U;
	Display_UI_Blink_Data.Blink_Timer = 250U;
	Display_UI_Blink_Show(1U);
}

void Display_UI_Timer_Service(void)
{
	if (Display_UI_Blink_Data.Blink_Cnt && Display_UI_Blink_Data.Blink_Timer)
		Display_UI_Blink_Data.Blink_Timer--;
}

void Display_UI_Show_Service(void)
{
	if (Display_UI_Blink_Data.Blink_Cnt && Display_UI_Blink_Data.Blink_Timer == 0U) {
		Display_UI_Blink_Data.Blink_Timer = BLINK_CYCLE;
		Display_UI_Blink_Show(Display_UI_Blink_Data.Blink_Cnt & 0x01U);
		Display_UI_Blink_Data.Blink_Cnt--;
	}
	if (ADC_Value_Valid) {
		int16_t vbias = ADC_VBIAS_Voltage;
		BACK_COLOR = WHITE;
		if (vbias < 0) {
			LCD_SHOW_ASCII_0806(132U, 9U, 11U, INDIANRED);
			vbias = (int16_t)-vbias;
		} else LCD_SHOW_ASCII_0806(132U, 9U, 10U, INDIANRED);
		Display_U32toDec((uint32_t)vbias);
		LCD_SHOW_ASCII_0806(144U, 9U, 12U, INDIANRED);
		LCD_SHOW_ASCII_0806(138U, 9U, U32_Dec_Buff[3], INDIANRED);
		LCD_SHOW_ASCII_0806(148U, 9U, U32_Dec_Buff[2], INDIANRED);
		ADC_Value_Valid = 0U;
	}
}

uint32_t Display_UI_Get_Status(void)
{
	return Display_UI_Blink_Data.Blink_Cnt;
}

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
	POP {R2}
	STRB R1,[R2]
	BX LR
}

void Display_U32toDec(uint32_t data)
{
	uint32_t index;
	for (index = 0U; index < 10U; ++index) {
		data = Fun_Div10(data, U32_Dec_Buff + index);
		if (U32_Dec_Buff[index] >= 10U) {
			U32_Dec_Buff[index] -= 10U;
			data++;
		}
		if (data == 0U) { index++; break; }
	}
	for (; index < 10U; ++index) U32_Dec_Buff[index] = 0U;
}

static void display_digit_blink(uint16_t x, uint16_t y, uint8_t digit,
		uint16_t color)
{
	uint8_t text[2];
	text[0] = (uint8_t)('0' + digit);
	text[1] = '\0';
	Display_UI_Blink_Show_Register(x, y, text, color);
}

static void display_unsigned(uint16_t x, uint16_t y, uint32_t value,
		uint8_t length, uint8_t blink_power, uint16_t color)
{
	uint8_t power;
	uint8_t show = 0U;
	Display_U32toDec(value);
	for (power = length; power > 0U; --power) {
		if (U32_Dec_Buff[power - 1U] != 0U || power == 1U || blink_power >= power)
			show = 1U;
		LCD_SHOW_ASCII_1608(x, y,
		                       show ? (uint8_t)('0' + U32_Dec_Buff[power - 1U]) : ' ',
		                       color);
		if (blink_power == power)
			display_digit_blink(x, y, U32_Dec_Buff[power - 1U], color);
		x += 8U;
	}
}

static uint8_t append_u32(uint8_t *text, uint8_t index, uint32_t value)
{
	uint8_t power = 10U;
	uint8_t started = 0U;
	Display_U32toDec(value);
	while (power > 0U) {
		power--;
		if (U32_Dec_Buff[power] != 0U || power == 0U) started = 1U;
		if (started) text[index++] = (uint8_t)('0' + U32_Dec_Buff[power]);
	}
	return index;
}

static void display_phase(uint16_t x, uint16_t y, int32_t centidegrees,
		uint8_t show_sign, uint8_t blink, uint16_t color)
{
	uint8_t text[8];
	uint8_t index = 0U;
	uint32_t magnitude;
	uint32_t scaled;
	LCD_Show_Square(x, y, 56U, 16U, WHITE);
	if (centidegrees < 0) {
		text[index++] = '-';
		magnitude = (uint32_t)(-centidegrees);
	} else {
		magnitude = (uint32_t)centidegrees;
		if (show_sign) text[index++] = '+';
	}
	if (magnitude >= 10000U) {
		index = append_u32(text, index, (magnitude + 50U) / 100U);
	} else if (magnitude >= 1000U) {
		scaled = (magnitude + 5U) / 10U;
		index = append_u32(text, index, scaled / 10U);
		text[index++] = '.';
		text[index++] = (uint8_t)('0' + scaled % 10U);
	} else {
		index = append_u32(text, index, magnitude / 100U);
		text[index++] = '.';
		text[index++] = (uint8_t)('0' + (magnitude / 10U) % 10U);
		text[index++] = (uint8_t)('0' + magnitude % 10U);
	}
	text[index++] = '~';
	text[index] = '\0';
	BACK_COLOR = WHITE;
	LCD_16ShowString_hanzi(x, y, text, color);
	if (blink) Display_UI_Blink_Show_Register(x, y, text, color);
}

void Display_UI_Microwave_Source_Refresh_Status(void)
{
	BACK_COLOR = WHITE;
	if ((STM8_Control_Bank[CTRL_REG_MWS_STATUS] &
	     (CTRL_MWS_STATUS_ENABLED | CTRL_MWS_STATUS_LOCKED)) ==
	    (CTRL_MWS_STATUS_ENABLED | CTRL_MWS_STATUS_LOCKED))
		LCD_SHOW_Icon_1612(146U, 16U, 0U, DARKGREEN);
	else LCD_SHOW_Icon_1612(146U, 16U, 1U, BRRED);
}

void Display_UI_Microwave_Source_Status(uint32_t blink)
{
	uint8_t *text;
	uint16_t color;
	BACK_COLOR = WHITE;
	if (STM8_Control_Bank[CTRL_REG_MWS_STATUS] & CTRL_MWS_STATUS_ENABLED) {
		text = "开";
		color = GREEN;
	} else {
		text = "关";
		color = RED;
	}
	LCD_16ShowString_hanzi(64U, 0U, text, color);
	if (blink) Display_UI_Blink_Show_Register(64U, 0U, text, color);
	Display_UI_Microwave_Source_Refresh_Status();
}

static const uint8_t Power_Char[] = "弱\0小\0中\0大";

void Display_UI_Microwave_Source_Power(uint32_t blink)
{
	uint8_t index = (STM8_Control_Bank[CTRL_REG_MWS_POWER] & 0x03U) * 3U;
	BACK_COLOR = WHITE;
	LCD_16ShowString_hanzi(112U, 0U, (uint8_t *)&Power_Char[index], BLUE);
	if (blink) Display_UI_Blink_Show_Register(112U, 0U,
	                                          (uint8_t *)&Power_Char[index], BLUE);
}

void Display_UI_Microwave_Source_Freq(uint32_t blink_bit)
{
	uint32_t index;
	uint16_t x = 106U;
	uint32_t value = STM8_Bank_Get_U32(CTRL_REG_MWS_FREQ_KHZ);
	Display_U32toDec(value);
	BACK_COLOR = WHITE;
	for (index = 0U; index < 7U; ++index) {
		LCD_SHOW_ASCII_1608(x, 16U, (uint8_t)('0' + U32_Dec_Buff[index]), DARKBLUE);
		if (blink_bit == index + 1U)
			display_digit_blink(x, 16U, U32_Dec_Buff[index], DARKBLUE);
		x -= 8U;
		if (index == 5U) x -= 4U;
		if (index == 4U) LCD_SHOW_ASCII_1608(x - 4U, 16U, '.', DARKBLUE);
	}
}

static void Display_UI_Microwave_Source_Init(void)
{
	BACK_COLOR = LIGHTCYAN;
	LCD_16ShowString_hanzi(14U, 0U, "微波源", BLACK);
	BACK_COLOR = WHITE;
	LCD_16ShowString_hanzi(80U, 0U, "功率", BLACK);
	LCD_16ShowString_hanzi(14U, 16U, "频率:", BLACK);
	LCD_16ShowString_hanzi(116U, 16U, "GHz", BLACK);
	LCD_SHOW_ASCII_0806(130U, 0U, 13U, GRAYBLUE);
	LCD_SHOW_ASCII_0806(136U, 0U, 14U, GRAYBLUE);
	LCD_SHOW_ASCII_0806(142U, 0U, 15U, GRAYBLUE);
	LCD_SHOW_ASCII_0806(148U, 0U, 16U, GRAYBLUE);
	LCD_SHOW_ASCII_0806(154U, 0U, 17U, GRAYBLUE);
	LCD_SHOW_ASCII_0806(154U, 9U, 13U, GRAYBLUE);
	LCD_Show_Square(128U, 0U, 1U, 17U, LGRAY);
	LCD_Show_Square(128U, 17U, 32U, 1U, LGRAY);
	Display_UI_Microwave_Source_Status(0U);
	Display_UI_Microwave_Source_Power(0U);
	Display_UI_Microwave_Source_Freq(0U);
}

void Display_UI_PLL_Enable(uint32_t blink)
{
	uint8_t *text;
	uint16_t color;
	BACK_COLOR = WHITE;
	if (STM8_Control_Bank[CTRL_REG_DPLL_STATUS] & CTRL_DPLL_STATUS_ENABLED) {
		text = "开";
		color = GREEN;
	} else {
		text = "关";
		color = RED;
	}
	LCD_16ShowString_hanzi(64U, 33U, text, color);
	if (blink) Display_UI_Blink_Show_Register(64U, 33U, text, color);
}

void Display_UI_Show_PLL_Set_Freq(uint32_t blink_bit)
{
	uint32_t value = STM8_Bank_Get_U32(CTRL_REG_CENTER_FREQ_DHZ);
	uint32_t frequency_hz = value / 10U;
	uint8_t digit;
	uint16_t blink_x = 0U;
	LCD_Show_Square(88U, 49U, 56U, 16U, WHITE);
	BACK_COLOR = WHITE;
	if (frequency_hz >= 100000UL) {
		Display_U32toDec(frequency_hz);
		for (digit = 6U; digit > 0U; --digit)
			LCD_SHOW_ASCII_1608((uint16_t)(88U + (6U - digit) * 8U), 49U,
			                       (uint8_t)('0' + U32_Dec_Buff[digit - 1U]), DARKBLUE);
		if (blink_bit >= 2U && blink_bit <= 7U) {
			blink_x = (uint16_t)(128U - (blink_bit - 2U) * 8U);
			display_digit_blink(blink_x, 49U, U32_Dec_Buff[blink_bit - 2U], DARKBLUE);
		}
	} else {
		Display_U32toDec(frequency_hz);
		display_unsigned(88U, 49U, frequency_hz, 5U, 0U, DARKBLUE);
		LCD_SHOW_ASCII_1608(128U, 49U, '.', DARKBLUE);
		LCD_SHOW_ASCII_1608(136U, 49U, (uint8_t)('0' + value % 10U), DARKBLUE);
		if (blink_bit == 1U) display_digit_blink(136U, 49U, (uint8_t)(value % 10U), DARKBLUE);
		else if (blink_bit >= 2U && blink_bit <= 6U) {
			blink_x = (uint16_t)(120U - (blink_bit - 2U) * 8U);
			display_digit_blink(blink_x, 49U, U32_Dec_Buff[blink_bit - 2U], DARKBLUE);
		}
	}
}

void Display_UI_Show_PLL_Mux_Div_Index(uint32_t blink_mul, uint32_t blink_div)
{
	display_unsigned(54U, 65U, STM8_Bank_Get_U16(CTRL_REG_OUTPUT_MUL),
	                 4U, (uint8_t)blink_mul, DARKBLUE);
	display_unsigned(126U, 65U, STM8_Bank_Get_U16(CTRL_REG_OUTPUT_DIV),
	                 4U, (uint8_t)blink_div, DARKBLUE);
}

static void display_signed_integer(uint16_t x, uint16_t y, int32_t value,
		uint8_t digits, uint16_t color)
{
	uint32_t magnitude;
	LCD_SHOW_ASCII_1608(x, y, value < 0 ? '-' : '+', color);
	magnitude = value < 0 ? (uint32_t)(-value) : (uint32_t)value;
	display_unsigned((uint16_t)(x + 8U), y, magnitude, digits, 0U, color);
}

static void display_fast_meter(void)
{
	uint32_t frequency = STM8_Bank_Get_U32(CTRL_REG_FAST_METER_HZ);
	uint32_t integer = frequency / 1000000UL;
	uint32_t fraction = frequency % 1000000UL;
	uint8_t power;
	Display_U32toDec(integer);
	LCD_SHOW_ASCII_1608(48U, 112U, U32_Dec_Buff[2] ? (uint8_t)('0' + U32_Dec_Buff[2]) : ' ', INDIANRED);
	LCD_SHOW_ASCII_1608(56U, 112U, (U32_Dec_Buff[2] || U32_Dec_Buff[1]) ?
	                       (uint8_t)('0' + U32_Dec_Buff[1]) : ' ', INDIANRED);
	LCD_SHOW_ASCII_1608(64U, 112U, (uint8_t)('0' + U32_Dec_Buff[0]), INDIANRED);
	LCD_SHOW_ASCII_1608(72U, 112U, '.', INDIANRED);
	Display_U32toDec(fraction);
	for (power = 6U; power > 0U; --power)
		LCD_SHOW_ASCII_1608((uint16_t)(80U + (6U - power) * 8U), 112U,
		                       (uint8_t)('0' + U32_Dec_Buff[power - 1U]), INDIANRED);
}

void Display_UI_PLL_Refresh_Status(void)
{
	uint8_t status = STM8_Control_Bank[CTRL_REG_DPLL_STATUS];
	Display_UI_PLL_Enable(0U);
	display_signed_integer(30U, 81U, STM8_Bank_Get_S32(CTRL_REG_FREQ_ERROR_HZ),
	                       5U, INDIANRED);
	display_phase(104U, 81U, STM8_Bank_Get_S32(CTRL_REG_PHASE_ERROR_CDEG),
	              1U, 0U, INDIANRED);
	display_unsigned(54U, 97U, STM8_Bank_Get_U32(CTRL_REG_OUTPUT_FREQ_HZ),
	                 7U, 0U, INDIANRED);
	display_fast_meter();
	if ((status & CTRL_DPLL_STATUS_ARM_ONLINE) == 0U) {
		LCD_SHOW_Icon_1612(142U, 33U, 15U, RED);
		return;
	}
	LCD_SHOW_Icon_1612(82U, 33U,
	                   (status & CTRL_DPLL_STATUS_LOCKED) ? 0U : 1U,
	                   (status & CTRL_DPLL_STATUS_LOCKED) ? DARKGREEN : BRRED);
	if (status & CTRL_DPLL_STATUS_PHASE_OUT) LCD_SHOW_Icon_1612(94U, 33U, 6U, RED);
	else LCD_Show_Square(94U, 33U, 12U, 16U, WHITE);
	if (status & CTRL_DPLL_STATUS_FREQ_OUT) LCD_SHOW_Icon_1612(106U, 33U, 7U, RED);
	else LCD_Show_Square(106U, 33U, 12U, 16U, WHITE);
	if (status & CTRL_DPLL_STATUS_POS_RAIL) LCD_SHOW_Icon_1612(118U, 33U, 8U, RED);
	else LCD_Show_Square(118U, 33U, 12U, 16U, WHITE);
	if (status & CTRL_DPLL_STATUS_NEG_RAIL) LCD_SHOW_Icon_1612(130U, 33U, 9U, RED);
	else LCD_Show_Square(130U, 33U, 12U, 16U, WHITE);
	if (status & CTRL_DPLL_STATUS_ERROR) LCD_SHOW_Icon_1612(142U, 33U, 15U, RED);
	else LCD_Show_Square(142U, 33U, 12U, 16U, WHITE);
}

void Display_UI_PLL_Main_Page_Init(void)
{
	Display_UI_Microwave_Source_Init();
	LCD_Show_Square(14U, 33U, 146U, 95U, WHITE);
	BACK_COLOR = LIGHTCYAN;
	LCD_16ShowString_hanzi(14U, 33U, "锁相环", BLACK);
	BACK_COLOR = WHITE;
	LCD_16ShowString_hanzi(14U, 49U, "中心频率:", BLACK);
	LCD_16ShowString_hanzi(144U, 49U, "Hz", BLACK);
	LCD_16ShowString_hanzi(14U, 65U, "倍频", BLACK);
	LCD_16ShowString_hanzi(94U, 65U, "除频", BLACK);
	LCD_16ShowString_hanzi(14U, 81U, "频", BLACK);
	LCD_16ShowString_hanzi(88U, 81U, "相", BLACK);
	LCD_16ShowString_hanzi(14U, 97U, "输出:", GRAYBLUE);
	LCD_16ShowString_hanzi(136U, 97U, "Hz", GRAYBLUE);
	LCD_16ShowString_hanzi(14U, 112U, "频率", GRAYBLUE);
	LCD_16ShowString_hanzi(136U, 112U, "MHz", GRAYBLUE);
	Display_UI_PLL_Enable(0U);
	Display_UI_Show_PLL_Set_Freq(0U);
	Display_UI_Show_PLL_Mux_Div_Index(0U, 0U);
	Display_UI_PLL_Refresh_Status();
}

void Display_UI_Show_PLL_Gain(uint8_t row, uint32_t blink_bit)
{
	static const uint8_t y[4] = {0U, 16U, 32U, 48U};
	display_unsigned(88U, y[row],
	                 STM8_Bank_Get_U32((uint8_t)(CTRL_REG_KP_TRACK + row * 4U)),
	                 7U, (uint8_t)blink_bit, DARKBLUE);
}

void Display_UI_Show_PLL_Limit(uint8_t row, uint32_t blink_bit)
{
	static const uint8_t y[2] = {64U, 80U};
	int32_t value = STM8_Bank_Get_S32(row ? CTRL_REG_NEG_LIMIT_HZ : CTRL_REG_POS_LIMIT_HZ);
	uint32_t magnitude = value < 0 ? (uint32_t)(-value) : (uint32_t)value;
	LCD_SHOW_ASCII_1608(88U, y[row], row ? '-' : '+', DARKBLUE);
	display_unsigned(96U, y[row], magnitude, 5U, (uint8_t)blink_bit, DARKBLUE);
}

void Display_UI_Show_Phase_Threshold(uint32_t blink_bit)
{
	display_phase(96U, 96U, (int32_t)STM8_Bank_Get_U16(CTRL_REG_PHASE_THRESHOLD_CDEG),
	              0U, blink_bit ? 1U : 0U, DARKBLUE);
}

void Display_UI_Show_Amplitude_Freq_Threshold(uint32_t amplitude_blink,
		uint32_t frequency_blink)
{
	uint32_t amplitude = STM8_Bank_Get_U16(CTRL_REG_DAC_AMPLITUDE_MV);
	uint32_t frequency = STM8_Bank_Get_U16(CTRL_REG_FREQ_THRESHOLD_HZ);
	uint8_t digit;
	LCD_SHOW_ASCII_1608(46U, 112U, (uint8_t)('0' + amplitude / 1000U), DARKBLUE);
	LCD_SHOW_ASCII_1608(54U, 112U, '.', DARKBLUE);
	LCD_SHOW_ASCII_1608(62U, 112U, (uint8_t)('0' + (amplitude / 100U) % 10U), DARKBLUE);
	LCD_SHOW_ASCII_1608(70U, 112U, (uint8_t)('0' + (amplitude / 10U) % 10U), DARKBLUE);
	LCD_SHOW_ASCII_1608(78U, 112U, 'V', BLACK);
	if (amplitude_blink == 1U) display_digit_blink(70U, 112U, (uint8_t)((amplitude / 10U) % 10U), DARKBLUE);
	if (amplitude_blink == 2U) display_digit_blink(62U, 112U, (uint8_t)((amplitude / 100U) % 10U), DARKBLUE);
	if (amplitude_blink == 3U) display_digit_blink(46U, 112U, (uint8_t)(amplitude / 1000U), DARKBLUE);
	Display_U32toDec(frequency);
	for (digit = 3U; digit > 0U; --digit)
		LCD_SHOW_ASCII_1608((uint16_t)(128U + (3U - digit) * 8U), 112U,
		                       (uint8_t)('0' + U32_Dec_Buff[digit - 1U]), DARKBLUE);
	if (frequency_blink)
		display_digit_blink((uint16_t)(128U + (3U - frequency_blink) * 8U), 112U,
		                    U32_Dec_Buff[frequency_blink - 1U], DARKBLUE);
}

void Display_UI_PLL_Vice_Page_Init(void)
{
	LCD_Show_Square(14U, 0U, 146U, 128U, WHITE);
	BACK_COLOR = WHITE;
	LCD_16ShowString_hanzi(14U, 0U, "追踪P", BLACK);
	LCD_16ShowString_hanzi(14U, 16U, "追踪I", BLACK);
	LCD_16ShowString_hanzi(14U, 32U, "捕获f", BLACK);
	LCD_16ShowString_hanzi(14U, 48U, "过渡f", BLACK);
	LCD_16ShowString_hanzi(14U, 64U, "输出上限", BLACK);
	LCD_16ShowString_hanzi(14U, 80U, "输出下限", BLACK);
	LCD_16ShowString_hanzi(14U, 96U, "相残限", BLACK);
	LCD_16ShowString_hanzi(14U, 112U, "幅度", BLACK);
	LCD_16ShowString_hanzi(88U, 112U, "频残", BLACK);
	Display_UI_Show_PLL_Gain(0U, 0U);
	Display_UI_Show_PLL_Gain(1U, 0U);
	Display_UI_Show_PLL_Gain(2U, 0U);
	Display_UI_Show_PLL_Gain(3U, 0U);
	Display_UI_Show_PLL_Limit(0U, 0U);
	Display_UI_Show_PLL_Limit(1U, 0U);
	Display_UI_Show_Phase_Threshold(0U);
	Display_UI_Show_Amplitude_Freq_Threshold(0U, 0U);
}

void Display_UI_Init(void)
{
	LCD_Clear(WHITE);
	LCD_Show_Square(13U, 0U, 1U, 128U, LGRAY);
	LCD_Show_Square(14U, 32U, 146U, 1U, LGRAY);
	LCD_SHOW_Icon_1612(0U, 17U, 10U, LGRAYBLUE);
	LCD_SHOW_Icon_1612(0U, 51U, 11U, LGRAYBLUE);
	LCD_SHOW_Icon_1612(0U, 75U, 12U, LGRAYBLUE);
	LCD_SHOW_Icon_1612(0U, 112U, 13U, LGRAYBLUE);
	LCD_SHOW_Icon_1612(0U, 2U, 5U, GRAY);
	LCD_SHOW_Icon_1612(0U, 36U, 4U, GRAY);
	LCD_SHOW_Icon_1612(1U, 68U, 2U, GRAY);
	LCD_SHOW_Icon_1612(1U, 105U, 3U, GRAY);
	Display_UI_PLL_Main_Page_Init();
}
