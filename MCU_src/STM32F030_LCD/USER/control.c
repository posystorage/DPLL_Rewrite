#include "control.h"
#include "STM8Slave.h"
#include "display.h"
#include "ENCODER.h"

#define PAGE0_MAX_ADJ_INDEX 7U
#define PAGE1_MAX_ADJ_INDEX 9U

typedef enum
{
	Blink = 0,
	Cursor_Left,
	Cursor_Right,
	Value_Add,
	Value_Sub,
	Value_Fast_Add,
	Value_Fast_Sub
} Ctrl_Cursor_Enum;

static const uint32_t POW10[8] = {0U, 1U, 10U, 100U, 1000U,
	                              10000U, 100000U, 1000000U};

static uint8_t Adjust_Index0;
static uint8_t Adjust_Index1;
static uint8_t Page_Num;
static uint8_t Cursor_MWS_Frequency;
static uint8_t Cursor_Center;
static uint8_t Cursor_Mul;
static uint8_t Cursor_Div;
static uint8_t Cursor_Gain[4];
static uint8_t Cursor_Limit[2];
static uint8_t Cursor_Phase;
static uint8_t Cursor_Amplitude_Frequency;
static uint16_t Refresh_Timer_Cnt;

static uint8_t is_add(Ctrl_Cursor_Enum option)
{
	return option == Value_Add || option == Value_Fast_Add;
}

static uint8_t is_sub(Ctrl_Cursor_Enum option)
{
	return option == Value_Sub || option == Value_Fast_Sub;
}

static void apply_pll_change(void)
{
	if (STM8_Slave_Send_PLL_Cfg() && STM8_Slave_Wait_Status() &&
	    STM8_Control_Bank[CTRL_REG_LAST_ERROR] == CTRL_ERROR_NONE)
		STM8_Slave_EEPROM_Write_Trigger();
}

static void CtrlP0I0_Microwave_Source_Enable(Ctrl_Cursor_Enum option)
{
	if (is_add(option) || is_sub(option)) {
		if (STM8_Control_Bank[CTRL_REG_MWS_STATUS] & CTRL_MWS_STATUS_ENABLED) {
			STM8_Control_Bank[CTRL_REG_MWS_STATUS] &= (uint8_t)~CTRL_MWS_STATUS_ENABLED;
			STM8Slave_MAX2871_OFF_CMD();
		} else {
			STM8_Control_Bank[CTRL_REG_MWS_STATUS] |= CTRL_MWS_STATUS_ENABLED;
			STM8Slave_MAX2871_ON_CMD();
		}
		STM8_Slave_Read_Status();
	}
	Display_UI_Microwave_Source_Status(1U);
}

static void CtrlP0I1_Microwave_Source_Power(Ctrl_Cursor_Enum option)
{
	uint8_t power = STM8_Control_Bank[CTRL_REG_MWS_POWER] & 0x03U;
	if (is_add(option) && power < 3U) power++;
	if (is_sub(option) && power > 0U) power--;
	if (is_add(option) || is_sub(option)) {
		STM8_Control_Bank[CTRL_REG_MWS_POWER] = power;
		STM8_Slave_Set_MAX2871_Freq_Power();
		STM8_Slave_EEPROM_Write_Trigger();
	}
	Display_UI_Microwave_Source_Power(1U);
}

static void CtrlP0I2_Microwave_Source_Frequency(Ctrl_Cursor_Enum option)
{
	uint32_t value = STM8_Bank_Get_U32(CTRL_REG_MWS_FREQ_KHZ);
	uint32_t step = POW10[Cursor_MWS_Frequency];
	if (is_add(option) && value + step <= CTRL_MWS_FREQ_MAX_KHZ) value += step;
	if (is_sub(option) && value >= CTRL_MWS_FREQ_MIN_KHZ + step) value -= step;
	if (is_add(option) || is_sub(option)) {
		STM8_Bank_Put_U32(CTRL_REG_MWS_FREQ_KHZ, value);
		STM8_Slave_Set_MAX2871_Freq_Power();
		STM8_Slave_EEPROM_Write_Trigger();
	} else if (option == Cursor_Left) {
		if (++Cursor_MWS_Frequency > 7U) Cursor_MWS_Frequency = 2U;
	} else if (option == Cursor_Right) {
		if (Cursor_MWS_Frequency <= 2U) Cursor_MWS_Frequency = 7U;
		else Cursor_MWS_Frequency--;
	}
	Display_UI_Microwave_Source_Freq(Cursor_MWS_Frequency);
}

static void CtrlP0I3_PLL_Enable(Ctrl_Cursor_Enum option)
{
	if (is_add(option) || is_sub(option)) {
		if (STM8_Control_Bank[CTRL_REG_DPLL_STATUS] & CTRL_DPLL_STATUS_ENABLED)
			STM8Slave_PLL_OFF_CMD();
		else {
			if (STM8_Slave_Send_PLL_Cfg() && STM8_Slave_Wait_Status() &&
			    STM8_Control_Bank[CTRL_REG_LAST_ERROR] == CTRL_ERROR_NONE)
				STM8Slave_PLL_ON_CMD();
		}
		STM8_Slave_Read_Status();
	}
	Display_UI_PLL_Enable(1U);
}

static void CtrlP0I4_PLL_Frequency(Ctrl_Cursor_Enum option)
{
	uint32_t value = STM8_Bank_Get_U32(CTRL_REG_CENTER_FREQ_DHZ);
	uint32_t step = POW10[Cursor_Center];
	if (is_add(option) && value + step <= 1250000UL) value += step;
	if (is_sub(option) && value >= 40000UL + step) value -= step;
	if (is_add(option) || is_sub(option)) {
		STM8_Bank_Put_U32(CTRL_REG_CENTER_FREQ_DHZ, value);
		apply_pll_change();
	} else if (option == Cursor_Left) {
		if (++Cursor_Center > 7U) Cursor_Center = 1U;
	} else if (option == Cursor_Right) {
		if (Cursor_Center <= 1U) Cursor_Center = 7U;
		else Cursor_Center--;
	}
	Display_UI_Show_PLL_Set_Freq(Cursor_Center);
}

static void adjust_mul_div(Ctrl_Cursor_Enum option, uint8_t offset,
		uint8_t *cursor, uint8_t is_div)
{
	uint32_t value = STM8_Bank_Get_U16(offset);
	uint32_t step = POW10[*cursor];
	if (is_add(option) && value + step <= 9999U) value += step;
	if (is_sub(option) && value > step) value -= step;
	if (is_add(option) || is_sub(option)) {
		STM8_Bank_Put_U16(offset, (uint16_t)value);
		apply_pll_change();
	} else if (option == Cursor_Left) {
		if (++(*cursor) > 4U) *cursor = 1U;
	} else if (option == Cursor_Right) {
		if (*cursor <= 1U) *cursor = 4U;
		else (*cursor)--;
	}
	Display_UI_Show_PLL_Mux_Div_Index(is_div ? 0U : *cursor,
	                                  is_div ? *cursor : 0U);
}

static void CtrlP0I5_PLL_Mul(Ctrl_Cursor_Enum option)
{
	adjust_mul_div(option, CTRL_REG_OUTPUT_MUL, &Cursor_Mul, 0U);
}

static void CtrlP0I6_PLL_Div(Ctrl_Cursor_Enum option)
{
	adjust_mul_div(option, CTRL_REG_OUTPUT_DIV, &Cursor_Div, 1U);
}

static void adjust_gain(Ctrl_Cursor_Enum option, uint8_t row)
{
	uint8_t offset = (uint8_t)(CTRL_REG_KP_TRACK + row * 4U);
	uint32_t value = STM8_Bank_Get_U32(offset);
	uint32_t step = POW10[Cursor_Gain[row]];
	if (is_add(option) && value + step <= 0x007FFFFFUL) value += step;
	if (is_sub(option) && value >= step) value -= step;
	if (is_add(option) || is_sub(option)) {
		STM8_Bank_Put_U32(offset, value);
		apply_pll_change();
	} else if (option == Cursor_Left) {
		if (++Cursor_Gain[row] > 7U) Cursor_Gain[row] = 1U;
	} else if (option == Cursor_Right) {
		if (Cursor_Gain[row] <= 1U) Cursor_Gain[row] = 7U;
		else Cursor_Gain[row]--;
	}
	Display_UI_Show_PLL_Gain(row, Cursor_Gain[row]);
}

static void CtrlP1I0_Gain(Ctrl_Cursor_Enum option) { adjust_gain(option, 0U); }
static void CtrlP1I1_Gain(Ctrl_Cursor_Enum option) { adjust_gain(option, 1U); }
static void CtrlP1I2_Gain(Ctrl_Cursor_Enum option) { adjust_gain(option, 2U); }
static void CtrlP1I3_Gain(Ctrl_Cursor_Enum option) { adjust_gain(option, 3U); }

static void adjust_limit(Ctrl_Cursor_Enum option, uint8_t row)
{
	uint8_t offset = row ? CTRL_REG_NEG_LIMIT_HZ : CTRL_REG_POS_LIMIT_HZ;
	int32_t signed_value = STM8_Bank_Get_S32(offset);
	uint32_t magnitude = row ? (uint32_t)(-signed_value) : (uint32_t)signed_value;
	uint32_t step = POW10[Cursor_Limit[row]];
	if (is_add(option) && magnitude + step <= 97000UL) magnitude += step;
	if (is_sub(option) && magnitude >= step) magnitude -= step;
	if (is_add(option) || is_sub(option)) {
		STM8_Bank_Put_U32(offset, row ? (uint32_t)(-(int32_t)magnitude) : magnitude);
		apply_pll_change();
	} else if (option == Cursor_Left) {
		if (++Cursor_Limit[row] > 5U) Cursor_Limit[row] = 1U;
	} else if (option == Cursor_Right) {
		if (Cursor_Limit[row] <= 1U) Cursor_Limit[row] = 5U;
		else Cursor_Limit[row]--;
	}
	Display_UI_Show_PLL_Limit(row, Cursor_Limit[row]);
}

static void CtrlP1I4_Positive_Limit(Ctrl_Cursor_Enum option) { adjust_limit(option, 0U); }
static void CtrlP1I5_Negative_Limit(Ctrl_Cursor_Enum option) { adjust_limit(option, 1U); }

static void CtrlP1I6_Phase_Threshold(Ctrl_Cursor_Enum option)
{
	uint32_t value = STM8_Bank_Get_U16(CTRL_REG_PHASE_THRESHOLD_CDEG);
	uint32_t step = POW10[Cursor_Phase];
	if (is_add(option) && value + step <= 18000U) value += step;
	if (is_sub(option) && value >= step) value -= step;
	if (is_add(option) || is_sub(option)) {
		STM8_Bank_Put_U16(CTRL_REG_PHASE_THRESHOLD_CDEG, (uint16_t)value);
		apply_pll_change();
	} else if (option == Cursor_Left) {
		if (++Cursor_Phase > 5U) Cursor_Phase = 1U;
	} else if (option == Cursor_Right) {
		if (Cursor_Phase <= 1U) Cursor_Phase = 5U;
		else Cursor_Phase--;
	}
	Display_UI_Show_Phase_Threshold(Cursor_Phase);
}

static void CtrlP1I7_Debug_DAC(Ctrl_Cursor_Enum option)
{
	uint8_t preset = STM8_Control_Bank[CTRL_REG_DEBUG_DAC_PRESET];
	if (is_add(option)) {
		preset = preset >= CTRL_DEBUG_DAC_PRESET_MAX ?
		         CTRL_DEBUG_DAC_PRESET_MIN : (uint8_t)(preset + 1U);
	} else if (is_sub(option)) {
		preset = preset > CTRL_DEBUG_DAC_PRESET_MAX ||
		         preset == CTRL_DEBUG_DAC_PRESET_MIN ?
		         CTRL_DEBUG_DAC_PRESET_MAX : (uint8_t)(preset - 1U);
	}
	if (is_add(option) || is_sub(option))
		STM8_Slave_Set_Debug_DAC_Preset(preset);
	Display_UI_Show_Debug_DAC_Preset(1U);
}

static void CtrlP1I8_Amplitude_Frequency(Ctrl_Cursor_Enum option)
{
	uint8_t frequency_selected = Cursor_Amplitude_Frequency > 3U;
	uint8_t digit = frequency_selected ? Cursor_Amplitude_Frequency - 3U :
	                                 Cursor_Amplitude_Frequency;
	uint32_t step = frequency_selected ? POW10[digit] : POW10[digit + 1U];
	uint32_t value;
	uint8_t offset;
	uint32_t maximum;

	offset = frequency_selected ? CTRL_REG_FREQ_THRESHOLD_HZ : CTRL_REG_DAC_AMPLITUDE_MV;
	maximum = frequency_selected ? 999U : 2000U;
	value = STM8_Bank_Get_U16(offset);
	if (is_add(option) && value + step <= maximum) value += step;
	if (is_sub(option) && value >= step) value -= step;
	if (is_add(option) || is_sub(option)) {
		STM8_Bank_Put_U16(offset, (uint16_t)value);
		apply_pll_change();
	} else if (option == Cursor_Left) {
		if (++Cursor_Amplitude_Frequency > 6U) Cursor_Amplitude_Frequency = 1U;
	} else if (option == Cursor_Right) {
		if (Cursor_Amplitude_Frequency <= 1U) Cursor_Amplitude_Frequency = 6U;
		else Cursor_Amplitude_Frequency--;
	}
	Display_UI_Show_Amplitude_Freq_Threshold(
		Cursor_Amplitude_Frequency <= 3U ? Cursor_Amplitude_Frequency : 0U,
		Cursor_Amplitude_Frequency > 3U ? Cursor_Amplitude_Frequency - 3U : 0U);
}

static void (*CtrlP0_Fun[PAGE0_MAX_ADJ_INDEX])(Ctrl_Cursor_Enum) = {
	CtrlP0I0_Microwave_Source_Enable,
	CtrlP0I1_Microwave_Source_Power,
	CtrlP0I2_Microwave_Source_Frequency,
	CtrlP0I3_PLL_Enable,
	CtrlP0I4_PLL_Frequency,
	CtrlP0I5_PLL_Mul,
	CtrlP0I6_PLL_Div
};

static void (*CtrlP1_Fun[PAGE1_MAX_ADJ_INDEX])(Ctrl_Cursor_Enum) = {
	CtrlP1I0_Gain, CtrlP1I1_Gain, CtrlP1I2_Gain, CtrlP1I3_Gain,
	CtrlP1I4_Positive_Limit, CtrlP1I5_Negative_Limit,
	CtrlP1I6_Phase_Threshold, CtrlP1I7_Debug_DAC,
	CtrlP1I8_Amplitude_Frequency
};

void Ctrl_KEY_Response_Service(void)
{
	if (Key_Value & KEY1_Long_Press) {
		CtrlP0I0_Microwave_Source_Enable(Value_Add);
		Key_Value &= ~KEY1_Long_Press;
	}
	if (Key_Value & KEY2_Long_Press) {
		if (Page_Num == 0U) CtrlP0I3_PLL_Enable(Value_Add);
		Key_Value &= ~KEY2_Long_Press;
	}
	if (Key_Value & KEY3_Long_Press) {
		if (Page_Num) {
			Display_UI_Blink_Show_Stop();
			Display_UI_PLL_Main_Page_Init();
			Page_Num = 0U;
		}
		Key_Value = 0U;
	}
	if (Key_Value & KEY4_Long_Press) {
		if (Page_Num == 0U) {
			Display_UI_Blink_Show_Stop();
			Display_UI_PLL_Vice_Page_Init();
			Page_Num = 1U;
		}
		Key_Value = 0U;
	}

	if (Key_Value & (KEY1_Short_Press | KEY2_Short_Press)) {
		if (Page_Num) {
			if (Key_Value & KEY1_Short_Press) CtrlP1_Fun[Adjust_Index1](Cursor_Left);
			if (Key_Value & KEY2_Short_Press) CtrlP1_Fun[Adjust_Index1](Cursor_Right);
		} else {
			if (Key_Value & KEY1_Short_Press) CtrlP0_Fun[Adjust_Index0](Cursor_Left);
			if (Key_Value & KEY2_Short_Press) CtrlP0_Fun[Adjust_Index0](Cursor_Right);
		}
		Key_Value &= ~(KEY1_Short_Press | KEY2_Short_Press);
	}

	if (Key_Value & (KEY3_Short_Press | KEY4_Short_Press)) {
		if (Page_Num) {
			if (Key_Value & KEY3_Short_Press) {
				if (Adjust_Index1 == 0U) Adjust_Index1 = PAGE1_MAX_ADJ_INDEX;
				Adjust_Index1--;
			}
			if (Key_Value & KEY4_Short_Press) {
				if (++Adjust_Index1 == PAGE1_MAX_ADJ_INDEX) Adjust_Index1 = 0U;
			}
			CtrlP1_Fun[Adjust_Index1](Blink);
		} else {
			if (Key_Value & KEY3_Short_Press) {
				if (Adjust_Index0 == 0U) Adjust_Index0 = PAGE0_MAX_ADJ_INDEX;
				Adjust_Index0--;
			}
			if (Key_Value & KEY4_Short_Press) {
				if (++Adjust_Index0 == PAGE0_MAX_ADJ_INDEX) Adjust_Index0 = 0U;
			}
			CtrlP0_Fun[Adjust_Index0](Blink);
		}
		Key_Value &= ~(KEY3_Short_Press | KEY4_Short_Press);
	}

	if (Key_Value & KEY5_Short_Press) {
		if (Page_Num) CtrlP1_Fun[Adjust_Index1](Blink);
		else CtrlP0_Fun[Adjust_Index0](Blink);
		Key_Value &= ~KEY5_Short_Press;
	}
	if (Key_Value & Econder_State_UP) {
		if (Page_Num) CtrlP1_Fun[Adjust_Index1](Display_UI_Get_Status() ? Value_Add : Blink);
		else CtrlP0_Fun[Adjust_Index0](Display_UI_Get_Status() ? Value_Add : Blink);
		Key_Value &= ~Econder_State_UP;
	}
	if (Key_Value & Econder_State_DOWN) {
		if (Page_Num) CtrlP1_Fun[Adjust_Index1](Display_UI_Get_Status() ? Value_Sub : Blink);
		else CtrlP0_Fun[Adjust_Index0](Display_UI_Get_Status() ? Value_Sub : Blink);
		Key_Value &= ~Econder_State_DOWN;
	}
}

void Ctrl_Data_Init(void)
{
	Adjust_Index0 = 2U;
	Adjust_Index1 = 0U;
	Page_Num = 0U;
	Cursor_MWS_Frequency = 5U;
	Cursor_Center = 4U;
	Cursor_Mul = 1U;
	Cursor_Div = 1U;
	Cursor_Gain[0] = 6U;
	Cursor_Gain[1] = 6U;
	Cursor_Gain[2] = 6U;
	Cursor_Gain[3] = 6U;
	Cursor_Limit[0] = 3U;
	Cursor_Limit[1] = 3U;
	Cursor_Phase = 3U;
	Cursor_Amplitude_Frequency = 2U;
}

void Ctrl_Dispaly_Refresh_Timer_Service(void)
{
	Refresh_Timer_Cnt++;
}

void Ctrl_Dispaly_Refresh_Show_Status(void)
{
	if (Refresh_Timer_Cnt > 300U) {
		Refresh_Timer_Cnt = 0U;
		STM8_Slave_Read_Status();
		if (Page_Num == 0U) {
			Display_UI_Microwave_Source_Refresh_Status();
			Display_UI_PLL_Refresh_Status();
		}
		else if (Display_UI_Get_Status() == 0U)
			Display_UI_Show_Debug_DAC_Preset(0U);
	}
}
