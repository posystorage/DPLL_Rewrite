#include "max2891_pll_conf.h"
#include "control_protocol.h"

static uint32_t bank_get_u32(uint8_t offset)
{
  uint32_t value;
  value = IIC_Reg_Buff[offset];
  value |= (uint32_t)IIC_Reg_Buff[offset + 1] << 8;
  value |= (uint32_t)IIC_Reg_Buff[offset + 2] << 16;
  value |= (uint32_t)IIC_Reg_Buff[offset + 3] << 24;
  return value;
}

void sys_init(void)
{
  CLK->ECKR = 0;
  CLK->CKDIVR = 0;
  CLK->PCKENR1 = 0;
  CLK->PCKENR2 = 0;

  IIC_Slave_Init();
  RedPitaya_Uart_Init();
  MAX2871_Init();
  MAX2871_RFOUT_OFF();
  TIM4_Init();
  EEPROM_Read_Data();

  IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] = 0;
  IIC_Reg_Buff[CTRL_REG_DPLL_STATUS] = 0;
  IIC_Reg_Buff[CTRL_REG_MWS_STATUS] = 0;
  IIC_Reg_Buff[CTRL_REG_LAST_ERROR] = CTRL_ERROR_NONE;
  asm("rim");
}

void IIC_CMD_Service(void)
{
  uint32_t frequency;

  if((IIC_CMD < 0xC0) || (IIC_CMD > 0xC9)) return;

  switch(IIC_CMD)
  {
  case 0xC0:
    frequency = bank_get_u32(CTRL_REG_MWS_FREQ_100KHZ);
    max2871_Set_Freq_10M(frequency, IIC_Reg_Buff[CTRL_REG_MWS_POWER] & 0x03);
    MAX2871_RFOUT_ON();
    IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] |= CTRL_FLAG_MWS_ENABLE;
    IIC_Reg_Buff[CTRL_REG_MWS_STATUS] |= CTRL_MWS_STATUS_ENABLED;
    break;

  case 0xC1:
    MAX2871_RFOUT_OFF();
    IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] &= (uint8_t)~CTRL_FLAG_MWS_ENABLE;
    IIC_Reg_Buff[CTRL_REG_MWS_STATUS] &= (uint8_t)~CTRL_MWS_STATUS_ENABLED;
    break;

  case 0xC2:
    EEPROM_Read_Data();
    break;

  case 0xC3:
    EEPROM_Store_Data();
    break;

  case 0xC4:
    IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ]++;
    break;

  case 0xC5:
    break;

  case 0xC7:
    IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] |= CTRL_FLAG_DPLL_ENABLE;
    IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ]++;
    break;

  case 0xC8:
    IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] &= (uint8_t)~CTRL_FLAG_DPLL_ENABLE;
    IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ]++;
    break;

  case 0xC9:
    break;

  default:
    break;
  }

  IIC_Reg_Buff[CTRL_REG_BRIDGE_STATUS] &= (uint8_t)(~CTRL_BRIDGE_STATUS_BUSY);
  IIC_CMD = 0;
}

void PLL_Lock_Read(void)
{
  if((MAX2871_LD_PORT->IDR & MAX2871_LD_PIN) == MAX2871_LD_PIN)
  {
    IIC_Reg_Buff[CTRL_REG_MWS_STATUS] |= CTRL_MWS_STATUS_LOCKED;
  }
  else
  {
    IIC_Reg_Buff[CTRL_REG_MWS_STATUS] &= (uint8_t)~CTRL_MWS_STATUS_LOCKED;
  }
}

void main(void)
{
  sys_init();
  while(1)
  {
    IIC_CMD_Service();
    RedPitaya_Service();
    PLL_Lock_Read();
  }
}
