#include "STM8Slave.h"
#include "iic.h"
#include "delay.h"

#define STM8_SLAVE_ADDR                 0x4AU
#define STM8_BUSY_POLL_LIMIT            5000U
#define STM8_EEPROM_WRITE_TIME          10000U
#define STM8_STATUS_RETRY_LIMIT         60U
#define STM8_WRITE_VERIFY_RETRY_LIMIT   3U

uint8_t STM8_Control_Bank[CTRL_BANK_SIZE];
static uint8_t STM8_Control_Snapshot[CTRL_BANK_SIZE];
static uint16_t STM8_EEPROM_Write_Cnt;
static uint8_t STM8_Link_State = STM8_LINK_STM8_OFFLINE;

uint16_t STM8_Bank_Get_U16(uint8_t offset)
{
	return (uint16_t)STM8_Control_Bank[offset] |
	       ((uint16_t)STM8_Control_Bank[offset + 1U] << 8);
}

uint32_t STM8_Bank_Get_U32(uint8_t offset)
{
	return (uint32_t)STM8_Control_Bank[offset] |
	       ((uint32_t)STM8_Control_Bank[offset + 1U] << 8) |
	       ((uint32_t)STM8_Control_Bank[offset + 2U] << 16) |
	       ((uint32_t)STM8_Control_Bank[offset + 3U] << 24);
}

int32_t STM8_Bank_Get_S32(uint8_t offset)
{
	return (int32_t)STM8_Bank_Get_U32(offset);
}

void STM8_Bank_Put_U16(uint8_t offset, uint16_t value)
{
	STM8_Control_Bank[offset] = (uint8_t)value;
	STM8_Control_Bank[offset + 1U] = (uint8_t)(value >> 8);
}

void STM8_Bank_Put_U32(uint8_t offset, uint32_t value)
{
	STM8_Control_Bank[offset] = (uint8_t)value;
	STM8_Control_Bank[offset + 1U] = (uint8_t)(value >> 8);
	STM8_Control_Bank[offset + 2U] = (uint8_t)(value >> 16);
	STM8_Control_Bank[offset + 3U] = (uint8_t)(value >> 24);
}

static uint8_t STM8Slave_Wait_Busy(void)
{
	uint8_t status;
	uint32_t poll;
	for (poll = 0U; poll < STM8_BUSY_POLL_LIMIT; ++poll) {
		if (IIC_Read(STM8_SLAVE_ADDR, CTRL_REG_BRIDGE_STATUS, 1U, &status) == 1U &&
		    (status & CTRL_BRIDGE_STATUS_BUSY) == 0U) return 1U;
		delay_us(200U);
	}
	return 0U;
}

static uint8_t STM8Slave_Command(uint8_t command, uint16_t delay_ms_after)
{
	if (!STM8Slave_Wait_Busy()) return 0U;
	IIC_Write(STM8_SLAVE_ADDR, command, 0U, 0);
	if (delay_ms_after) delay_ms(delay_ms_after);
	return STM8Slave_Wait_Busy();
}

static uint8_t STM8Slave_Write_Verified(uint8_t offset, uint8_t length,
		uint8_t *data)
{
	uint8_t index;
	uint8_t retry;
	for (retry = 0U; retry < STM8_WRITE_VERIFY_RETRY_LIMIT; ++retry) {
		if (!STM8Slave_Wait_Busy()) goto retry_write;
		IIC_Write(STM8_SLAVE_ADDR, offset, length, data);
		if (IIC_Read(STM8_SLAVE_ADDR, offset, length,
		             &STM8_Control_Snapshot[offset]) != length) goto retry_write;
		for (index = 0U; index < length; ++index) {
			if (data[index] != STM8_Control_Snapshot[offset + index])
				goto retry_write;
		}
		return 1U;
	retry_write:
		delay_ms(2U);
	}
	return 0U;
}

void STM8Slave_MAX2871_ON_CMD(void)
{
	STM8Slave_Command(0xC0U, 1U);
}

void STM8Slave_MAX2871_OFF_CMD(void)
{
	STM8Slave_Command(0xC1U, 0U);
}

void STM8Slave_PLL_ON_CMD(void)
{
	STM8Slave_Command(0xC7U, 1U);
}

void STM8Slave_PLL_OFF_CMD(void)
{
	STM8Slave_Command(0xC8U, 1U);
}

void STM8Slave_Init(void)
{
	IIC1_Init();
	STM8_Slave_Read_Status();
}

void STM8_Slave_Set_MAX2871_Freq_Power(void)
{
	IIC_Write(STM8_SLAVE_ADDR, CTRL_REG_MWS_FREQ_KHZ, 5U,
	          &STM8_Control_Bank[CTRL_REG_MWS_FREQ_KHZ]);
	if (STM8_Control_Bank[CTRL_REG_MWS_STATUS] & CTRL_MWS_STATUS_ENABLED)
		STM8Slave_MAX2871_ON_CMD();
	else
		STM8Slave_MAX2871_OFF_CMD();
}

uint8_t STM8_Slave_Set_Debug_DAC_Preset(uint8_t preset)
{
	uint8_t previous = STM8_Control_Bank[CTRL_REG_DEBUG_DAC_PRESET];
	if (preset > CTRL_DEBUG_DAC_PRESET_MAX) return 0U;
	STM8_Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = preset;
	if (!STM8Slave_Write_Verified(CTRL_REG_DEBUG_DAC_PRESET, 1U,
	                            &STM8_Control_Bank[CTRL_REG_DEBUG_DAC_PRESET])) {
		STM8_Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = previous;
		return 0U;
	}
	return 1U;
}

uint8_t STM8_Slave_Send_PLL_Cfg(void)
{
	uint8_t sequence_before;
	uint8_t sequence_after;
	if (IIC_Read(STM8_SLAVE_ADDR, CTRL_REG_REQUEST_SEQ, 1U,
	             &sequence_before) != 1U) return 0U;
	if (!STM8Slave_Write_Verified(CTRL_PERSIST_BEGIN,
			CTRL_PERSIST_END - CTRL_PERSIST_BEGIN,
			&STM8_Control_Bank[CTRL_PERSIST_BEGIN])) return 0U;
	if (!STM8Slave_Command(0xC4U, 2U)) return 0U;
	if (IIC_Read(STM8_SLAVE_ADDR, CTRL_REG_REQUEST_SEQ, 1U,
	             &sequence_after) != 1U) return 0U;
	return sequence_after == (uint8_t)(sequence_before + 1U);
}

uint8_t STM8_Slave_Read_Status(void)
{
	uint8_t identity[2];
	uint8_t sequence_before;
	uint8_t sequence_after;
	uint8_t persistent_changed;
	uint8_t index;
	uint8_t applied;

	if (IIC_Check_Slave(STM8_SLAVE_ADDR) != 0U ||
	    IIC_Read(STM8_SLAVE_ADDR, CTRL_REG_ID, 2U, identity) != 2U) {
		STM8_Link_State = STM8_LINK_STM8_OFFLINE;
		STM8_Control_Bank[CTRL_REG_DPLL_STATUS] &=
			(uint8_t)~CTRL_DPLL_STATUS_ARM_ONLINE;
		return 0U;
	}
	if (identity[0] != 0xA5U || identity[1] != CTRL_PROTOCOL_VERSION) {
		STM8_Link_State = STM8_LINK_PROTOCOL_ERROR;
		return 0U;
	}
	if (IIC_Read(STM8_SLAVE_ADDR, CTRL_REG_RESPONSE_SEQ, 1U,
	             &sequence_before) != 1U ||
	    IIC_Read(STM8_SLAVE_ADDR, 0U, CTRL_BANK_SIZE,
	             STM8_Control_Snapshot) != CTRL_BANK_SIZE ||
	    IIC_Read(STM8_SLAVE_ADDR, CTRL_REG_RESPONSE_SEQ, 1U,
	             &sequence_after) != 1U) {
		STM8_Link_State = STM8_LINK_STM8_OFFLINE;
		STM8_Control_Bank[CTRL_REG_DPLL_STATUS] &=
			(uint8_t)~CTRL_DPLL_STATUS_ARM_ONLINE;
		return 0U;
	}
	if (sequence_before != sequence_after ||
	    STM8_Control_Snapshot[CTRL_REG_RESPONSE_SEQ] != sequence_after)
		return 0U;
	if (STM8_Control_Snapshot[CTRL_REG_ID] != 0xA5U ||
	    STM8_Control_Snapshot[CTRL_REG_PROTOCOL_VERSION] != CTRL_PROTOCOL_VERSION) {
		STM8_Link_State = STM8_LINK_PROTOCOL_ERROR;
		return 0U;
	}

	applied = STM8_Control_Snapshot[CTRL_REG_REQUEST_SEQ] == sequence_after;
	if (applied) {
		persistent_changed = 0U;
		for (index = CTRL_PERSIST_BEGIN; index < CTRL_PERSIST_END; ++index) {
			if (STM8_Control_Bank[index] != STM8_Control_Snapshot[index]) {
				persistent_changed = 1U;
				break;
			}
		}
		if (persistent_changed) STM8_EEPROM_Write_Cnt = 0U;
		for (index = 0U; index < CTRL_BANK_SIZE; ++index)
			STM8_Control_Bank[index] = STM8_Control_Snapshot[index];
	} else {
		for (index = CTRL_REG_RESPONSE_SEQ; index < CTRL_BANK_SIZE; ++index)
			STM8_Control_Bank[index] = STM8_Control_Snapshot[index];
	}

	if (STM8_Control_Snapshot[CTRL_REG_BRIDGE_STATUS] &
	    CTRL_BRIDGE_STATUS_EEPROM_CRC_ERROR)
		STM8_Link_State = STM8_LINK_CRC_ERROR;
	else if ((STM8_Control_Snapshot[CTRL_REG_DPLL_STATUS] &
	          CTRL_DPLL_STATUS_ARM_ONLINE) == 0U)
		STM8_Link_State = STM8_LINK_ARM_OFFLINE;
	else
		STM8_Link_State = STM8_LINK_ONLINE;
	return applied && STM8_Link_State == STM8_LINK_ONLINE;
}

uint8_t STM8_Slave_Wait_Status(void)
{
	uint8_t retry;
	for (retry = 0U; retry < STM8_STATUS_RETRY_LIMIT; ++retry) {
		if (STM8_Slave_Read_Status()) return 1U;
		delay_ms(2U);
	}
	return 0U;
}

uint8_t STM8_Slave_Get_Link_State(void)
{
	return STM8_Link_State;
}

void STM8_Slave_EEPROM_Write_Trigger(void)
{
	STM8_EEPROM_Write_Cnt = 1U;
}

void STM8_Slave_EEPROM_Writer_Time_Service(void)
{
	if (STM8_EEPROM_Write_Cnt) {
		STM8_EEPROM_Write_Cnt++;
		if (STM8_EEPROM_Write_Cnt > STM8_EEPROM_WRITE_TIME)
			STM8_EEPROM_Write_Cnt = STM8_EEPROM_WRITE_TIME;
	}
}

void STM8_Slave_EEPROM_Write_Service(void)
{
	if (STM8_EEPROM_Write_Cnt >= STM8_EEPROM_WRITE_TIME) {
		if (STM8_Slave_Read_Status() &&
		    STM8_EEPROM_Write_Cnt >= STM8_EEPROM_WRITE_TIME)
			STM8Slave_Command(0xC3U, 6U);
		STM8_EEPROM_Write_Cnt = 0U;
	}
}
