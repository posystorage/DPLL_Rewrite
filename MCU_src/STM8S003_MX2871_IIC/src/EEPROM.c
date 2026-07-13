#include "EEPROM.h"
#include "IIC.h"

#define EEPROM_Write_Addr 0x04240
#define EEPROM_MAGIC 0xA5

static void bank_put_u16(uint8_t offset, uint16_t value)
{
  IIC_Reg_Buff[offset] = (uint8_t)value;
  IIC_Reg_Buff[offset + 1] = (uint8_t)(value >> 8);
}

static void bank_put_u32(uint8_t offset, uint32_t value)
{
  IIC_Reg_Buff[offset] = (uint8_t)value;
  IIC_Reg_Buff[offset + 1] = (uint8_t)(value >> 8);
  IIC_Reg_Buff[offset + 2] = (uint8_t)(value >> 16);
  IIC_Reg_Buff[offset + 3] = (uint8_t)(value >> 24);
}

static uint16_t eeprom_crc16(const uint8_t *data, uint8_t length)
{
  uint8_t i;
  uint8_t bit;
  uint16_t crc = 0xFFFF;
  for(i = 0; i < length; i++)
  {
    crc ^= (uint16_t)data[i] << 8;
    for(bit = 0; bit < 8; bit++)
    {
      if(crc & 0x8000) crc = (uint16_t)((crc << 1) ^ 0x1021);
      else crc <<= 1;
    }
  }
  return crc;
}

void EEPROM_Load_Defaults(void)
{
  uint8_t i;
  for(i = CTRL_PERSIST_BEGIN; i < CTRL_PERSIST_END; i++) IIC_Reg_Buff[i] = 0;

  bank_put_u32(CTRL_REG_MWS_FREQ_100KHZ, 25000UL);
  IIC_Reg_Buff[CTRL_REG_MWS_POWER] = 3;
  bank_put_u32(CTRL_REG_CENTER_FREQ_DHZ, 220000UL);
  bank_put_u16(CTRL_REG_OUTPUT_MUL, 1);
  bank_put_u16(CTRL_REG_OUTPUT_DIV, 1);
  bank_put_u32(CTRL_REG_KP_TRACK, 6000000UL);
  bank_put_u32(CTRL_REG_KI_TRACK, 180000UL);
  bank_put_u32(CTRL_REG_KF_ACQUIRE, 8000000UL);
  bank_put_u32(CTRL_REG_KF_BLEND, 1500000UL);
  bank_put_u32(CTRL_REG_POS_LIMIT_HZ, 4400UL);
  bank_put_u32(CTRL_REG_NEG_LIMIT_HZ, (uint32_t)(int32_t)-4400);
  bank_put_u16(CTRL_REG_PHASE_THRESHOLD_CDEG, 800);
  bank_put_u16(CTRL_REG_DAC_AMPLITUDE_MV, 2000);
  bank_put_u16(CTRL_REG_FREQ_THRESHOLD_HZ, 100);
  bank_put_u16(CTRL_REG_FAST_INTERVAL_MS, 500);
}

static __ramfunc void eeprom_store_crc(uint16_t crc)
{
  uint8_t i;
  asm("sim");
  do
  {
    FLASH->DUKR = 0xae;
    FLASH->DUKR = 0x56;
  }
  while(!(FLASH->IAPSR & FLASH_IAPSR_DUL));

  FLASH->CR2 |= FLASH_CR2_PRG;
  FLASH->NCR2 &= (uint8_t)~FLASH_NCR2_NPRG;

  *((unsigned char *)EEPROM_Write_Addr + 0) = EEPROM_MAGIC;
  *((unsigned char *)EEPROM_Write_Addr + 1) = CTRL_PROTOCOL_VERSION;
  *((unsigned char *)EEPROM_Write_Addr + 2) = (uint8_t)crc;
  *((unsigned char *)EEPROM_Write_Addr + 3) = (uint8_t)(crc >> 8);
  for(i = CTRL_PERSIST_BEGIN; i < CTRL_PERSIST_END; i++)
  {
    *((unsigned char *)EEPROM_Write_Addr + i) = IIC_Reg_Buff[i];
  }

  while((FLASH->IAPSR & FLASH_IAPSR_EOP) == 0);
  FLASH->IAPSR = 0;
  asm("rim");
}

void EEPROM_Store_Data(void)
{
  uint16_t crc = eeprom_crc16(&IIC_Reg_Buff[CTRL_PERSIST_BEGIN],
                              CTRL_PERSIST_END - CTRL_PERSIST_BEGIN);
  eeprom_store_crc(crc);
}

void EEPROM_Read_Data(void)
{
  uint8_t i;
  uint16_t stored_crc;
  uint16_t calculated_crc;

  IIC_Reg_Buff[CTRL_REG_ID] = EEPROM_MAGIC;
  IIC_Reg_Buff[CTRL_REG_PROTOCOL_VERSION] = CTRL_PROTOCOL_VERSION;
  IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ] = 0;
  IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] = 0;

  for(i = CTRL_PERSIST_BEGIN; i < CTRL_PERSIST_END; i++)
  {
    IIC_Reg_Buff[i] = *((unsigned char *)EEPROM_Write_Addr + i);
  }

  stored_crc = *((unsigned char *)EEPROM_Write_Addr + 2);
  stored_crc |= (uint16_t)(*((unsigned char *)EEPROM_Write_Addr + 3)) << 8;
  calculated_crc = eeprom_crc16(&IIC_Reg_Buff[CTRL_PERSIST_BEGIN],
                                CTRL_PERSIST_END - CTRL_PERSIST_BEGIN);

  if((*((unsigned char *)EEPROM_Write_Addr + 0) == EEPROM_MAGIC) &&
     (*((unsigned char *)EEPROM_Write_Addr + 1) == CTRL_PROTOCOL_VERSION) &&
     (stored_crc == calculated_crc))
  {
    return;
  }

  EEPROM_Load_Defaults();
  EEPROM_Store_Data();
}
