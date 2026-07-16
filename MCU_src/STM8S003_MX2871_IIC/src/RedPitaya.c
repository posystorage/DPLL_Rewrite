#include "RedPitaya.h"
#include "IIC.h"
#include "EEPROM.h"
#include "control_protocol.h"
#include "MAX2871.h"

#define CTRL_UART_RX_SIZE 72
#define CTRL_UART_TX_SIZE 101
#define CTRL_ARM_TIMEOUT_TICKS 1000

static volatile uint8_t uart_rx_buff[CTRL_UART_RX_SIZE];
static volatile uint8_t uart_rx_count;
static volatile uint8_t uart_frame_ready;
static volatile uint16_t arm_timeout_ticks;
static uint8_t uart_tx_buff[CTRL_UART_TX_SIZE];

static uint32_t bank_get_u32(uint8_t offset)
{
  uint32_t value = IIC_Reg_Buff[offset];
  value |= (uint32_t)IIC_Reg_Buff[offset + 1] << 8;
  value |= (uint32_t)IIC_Reg_Buff[offset + 2] << 16;
  value |= (uint32_t)IIC_Reg_Buff[offset + 3] << 24;
  return value;
}

static uint8_t ranges_overlap(uint8_t offset, uint8_t length,
                              uint8_t field, uint8_t field_length)
{
  return (offset < (uint8_t)(field + field_length)) &&
         (field < (uint8_t)(offset + length));
}

static void apply_microwave_write(uint8_t offset, uint8_t length)
{
  if(!ranges_overlap(offset, length, CTRL_REG_CONTROL_FLAGS, 1) &&
     !ranges_overlap(offset, length, CTRL_REG_MWS_FREQ_KHZ, 5)) return;

  if(IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] & CTRL_FLAG_MWS_ENABLE)
  {
    max2871_Set_Freq_10M(bank_get_u32(CTRL_REG_MWS_FREQ_KHZ),
                         IIC_Reg_Buff[CTRL_REG_MWS_POWER] & 0x03);
    MAX2871_RFOUT_ON();
    IIC_Reg_Buff[CTRL_REG_MWS_STATUS] |= CTRL_MWS_STATUS_ENABLED;
  }
  else
  {
    MAX2871_RFOUT_OFF();
    IIC_Reg_Buff[CTRL_REG_MWS_STATUS] &= (uint8_t)~CTRL_MWS_STATUS_ENABLED;
  }
}
static uint8_t frame_checksum(const volatile uint8_t *data, uint8_t length)
{
  uint8_t i;
  uint8_t sum = 0;
  for(i = 0; i < length; i++) sum = (uint8_t)(sum + data[i]);
  return (uint8_t)(0U - sum);
}

void RedPitaya_Uart_Init(void)
{
  /* The verified original STM8S003 design uses this misnamed library bit. */
  CLK->PCKENR1 |= CLK_PCKENR1_UART2;

  GPIOD->ODR |= GPIO_PIN_5;
  GPIOD->DDR |= GPIO_PIN_5;
  GPIOD->CR1 |= GPIO_PIN_5 | GPIO_PIN_6;
  GPIOD->CR2 |= GPIO_PIN_5;
  GPIOD->CR2 &= (uint8_t)~GPIO_PIN_6;
  GPIOD->DDR &= (uint8_t)~GPIO_PIN_6;

  UART1->CR1 = 0x00;
  UART1->CR2 = 0x00;
  UART1->CR3 = 0x00;
  UART1->BRR2 = 0x00;
  UART1->BRR1 = 0x01;

  /* Keep UART and I2C at level 3 so neither ISR can preempt the other. */
  ITC->ISPR5 |= 0x30;
  UART1->CR2 = UART1_CR2_RIEN | UART1_CR2_TEN | UART1_CR2_REN;

  uart_rx_count = 0;
  uart_frame_ready = 0;
  arm_timeout_ticks = 0;
}

static void uart_send(const uint8_t *data, uint8_t length)
{
  while(length)
  {
    while((UART1->SR & UART1_SR_TXE) == 0);
    UART1->DR = *data;
    data++;
    length--;
  }
  while((UART1->SR & UART1_SR_TC) == 0);
}

static void send_response(uint8_t status, uint8_t offset, uint8_t length)
{
  uint8_t i;
  uint8_t total;

  uart_tx_buff[0] = CTRL_UART_RESP;
  uart_tx_buff[1] = status;
  uart_tx_buff[2] = length;
  for(i = 0; i < length; i++) uart_tx_buff[3 + i] = IIC_Reg_Buff[offset + i];
  uart_tx_buff[3 + length] = frame_checksum(&uart_tx_buff[1], (uint8_t)(2 + length));
  uart_tx_buff[4 + length] = CTRL_UART_ETX;
  total = (uint8_t)(5 + length);
  uart_send(uart_tx_buff, total);
}

INTERRUPT_HANDLER(UART1_RX_IRQHandler, 18)
{
  uint8_t status = UART1->SR;
  uint8_t data = UART1->DR;
  uint8_t expected;

  if(status & (UART1_SR_OR | UART1_SR_NF | UART1_SR_FE | UART1_SR_PE))
  {
    if(!uart_frame_ready) uart_rx_count = 0;
    return;
  }

  if(uart_frame_ready) return;

  if(uart_rx_count == 0)
  {
    if(data == CTRL_UART_REQ)
    {
      uart_rx_buff[0] = data;
      uart_rx_count = 1;
    }
    return;
  }

  if(uart_rx_count >= CTRL_UART_RX_SIZE)
  {
    uart_rx_count = 0;
    return;
  }

  uart_rx_buff[uart_rx_count++] = data;
  if(uart_rx_count < 4) return;

  expected = 6;
  if(uart_rx_buff[1] == CTRL_UART_CMD_WRITE)
  {
    if(uart_rx_buff[3] > (CTRL_UART_RX_SIZE - 6))
    {
      uart_rx_count = 0;
      return;
    }
    expected = (uint8_t)(6 + uart_rx_buff[3]);
  }

  if(uart_rx_count == expected)
  {
    uart_frame_ready = 1;
  }
  else if(uart_rx_count > expected)
  {
    uart_rx_count = 0;
  }
}

void RedPitaya_2ms_Tick(void)
{
  if(arm_timeout_ticks)
  {
    arm_timeout_ticks--;
    if(arm_timeout_ticks == 0)
    {
      IIC_Reg_Buff[CTRL_REG_DPLL_STATUS] &= (uint8_t)~CTRL_DPLL_STATUS_ARM_ONLINE;
      IIC_Reg_Buff[CTRL_REG_DPLL_STATUS] |= CTRL_DPLL_STATUS_ERROR;
    }
  }
}

void RedPitaya_Service(void)
{
  uint8_t command;
  uint8_t offset;
  uint8_t length;
  uint8_t checksum_index;
  uint8_t status = CTRL_UART_STATUS_OK;
  uint8_t i;

  if(!uart_frame_ready) return;

  command = uart_rx_buff[1];
  offset = uart_rx_buff[2];
  length = uart_rx_buff[3];
  checksum_index = (command == CTRL_UART_CMD_WRITE) ? (uint8_t)(4 + length) : 4;

  if((uart_rx_buff[checksum_index + 1] != CTRL_UART_ETX) ||
     (uart_rx_buff[checksum_index] !=
      frame_checksum(&uart_rx_buff[1], (uint8_t)(checksum_index - 1))))
  {
    status = CTRL_UART_STATUS_BAD_FRAME;
  }
  else if(((uint16_t)offset + length) > CTRL_BANK_SIZE)
  {
    status = CTRL_UART_STATUS_RANGE;
  }
  else
  {
    arm_timeout_ticks = CTRL_ARM_TIMEOUT_TICKS;
  }

  if(status == CTRL_UART_STATUS_OK)
  {
    switch(command)
    {
    case CTRL_UART_CMD_READ:
      send_response(status, offset, length);
      break;

    case CTRL_UART_CMD_WRITE:
      if(offset < CTRL_REG_REQUEST_SEQ)
      {
        send_response(CTRL_UART_STATUS_RANGE, 0, 0);
      }
      else
      {
        for(i = 0; i < length; i++) IIC_Reg_Buff[offset + i] = uart_rx_buff[4 + i];
        apply_microwave_write(offset, length);
        send_response(status, 0, 0);
      }
      break;

    case CTRL_UART_CMD_SAVE:
      EEPROM_Store_Data();
      send_response(status, 0, 0);
      break;

    case CTRL_UART_CMD_PING:
      send_response(status, CTRL_REG_PROTOCOL_VERSION, 1);
      break;

    default:
      send_response(CTRL_UART_STATUS_COMMAND, 0, 0);
      break;
    }
  }
  else
  {
    send_response(status, 0, 0);
  }

  uart_rx_count = 0;
  uart_frame_ready = 0;
}
