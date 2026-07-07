/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "Peripherals.h"
#include "dpll_driver.h"
#include "dpll_build_id.h"
#include "sleep.h"
#include "xil_types.h"
#include "xparameters.h"
#include "xparameters_ps.h"
#include "xscugic.h"
#include "xuartps.h"
#include "xuartps_hw.h"



XUartPs XUartPs_uart0;
XUartPs XUartPs_uart1;
XScuGic XPS_XScuGic;
uint8_t PLL_Lock_Status;

void XPS_Core_init(void)
{
	XScuGic_Config *XScuGic_Config_ps;
	XScuGic_Config_ps = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
	XScuGic_CfgInitialize(&XPS_XScuGic,XScuGic_Config_ps,XScuGic_Config_ps->CpuBaseAddress);

	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,(Xil_ExceptionHandler)XScuGic_InterruptHandler,(void *)&XPS_XScuGic);
	Xil_ExceptionEnable();
}



/*********************************UART0  PC-USBCOM****************************/
#define PC_CMD_READ_MWS_SETTING				0x01
#define PC_CMD_READ_MWS_STATUS				0x02
#define PC_CMD_READ_PLL_FREQ_SETTING		0x03
#define PC_CMD_READ_PLL_MUL_DIV_SETTING		0x04
#define PC_CMD_READ_PLL_THRESHOLD_SETTING	0x05
#define PC_CMD_READ_PLL_LIMIT_SETTING		0x06
#define PC_CMD_READ_DPLL_LOOP_BASIC_SETTING			0x07
#define PC_CMD_READ_PLL_AMP_SETTING			0x08
#define PC_CMD_READ_PLL_STATUS				0x09

#define PC_CMD_READ_VERSION					0x0A
#define PC_CMD_READ_DATA_LOG				0x0C

#define PC_CMD_READ_DPLL_ID_STATUS			0x18
#define PC_CMD_READ_DPLL_ADV_CONFIG			0x19
#define PC_CMD_READ_FREQMETER_FREQ_SETTING			0x10
#define PC_CMD_READ_FREQMETER_THRESHOLD_SETTING		0x11
#define PC_CMD_READ_FREQMETER_LIMIT_SETTING			0x12
#define PC_CMD_READ_FREQMETER_PID_SETTING			0x13
#define PC_CMD_READ_FREQMETER_STATUS				0x14
#define PC_CMD_READ_FREQMETER_RUN_STATUS			0x15
#define PC_CMD_READ_FREQMETER_TIMER_SETTING			0x16
#define PC_CMD_READ_FREQMETER_CNT					0x17


#define PC_CMD_VBIAS_READ_DAC	 			0x1A
#define PC_CMD_VBIAS_READ_ADC	 			0x1B

#define PC_CMD_WRITE_MWS_FREQ_PWR			0x81
#define PC_CMD_WRITE_PLL_FREQ				0x82
#define PC_CMD_WRITE_PLL_MUL_DIV			0x83
#define PC_CMD_WRITE_PLL_THRESHOLD			0x84
#define PC_CMD_WRITE_PLL_LIMIT				0x85
#define PC_CMD_WRITE_DPLL_LOOP_BASIC				0x86
#define PC_CMD_WRITE_PLL_AMP				0x87
#define PC_CMD_WRITE_MWS_ON					0x88
#define PC_CMD_WRITE_MWS_OFF				0x89
#define PC_CMD_WRITE_PLL_ON					0x8A
#define PC_CMD_WRITE_PLL_OFF				0x8B
#define PC_CMD_LOAD_EEPROM					0x8C
#define PC_CMD_SAVE_EEPROM					0x8D
#define PC_CMD_PLL_RESET					0x8E

#define PC_CMD_WRITE_DPLL_ADV_CONFIG		0x8F
#define PC_CMD_FREQMETER_FREQ				0x90
#define PC_CMD_FREQMETER_THRESHOLD			0x91
#define PC_CMD_FREQMETER_LIMIT				0x92
#define PC_CMD_FREQMETER_PID				0x93
#define PC_CMD_FREQMETER_TIMER				0x94
#define PC_CMD_FREQMETER_TRIG				0x95
#define PC_CMD_FREQMETER_RESET	 			0x96

#define PC_CMD_WRITE_DPLL_DEBUG_CONFIG		0x97
#define PC_CMD_VBIAS_WRITE_DAC	 			0x9A

uint8_t Uart0_RX_Buff[512];
uint8_t Uart0_TX_Buff[512];
uint8_t PC_HOST_CMD_data_Buff[512];
uint32_t Uart0_RX_Num;
uint8_t PC_HOST_CMD_ASK;
uint8_t PC_HOST_CMD_GET;
uint8_t PC_HOST_CMD_RX_Mark = 0;
uint64_t Freq_meter_gate_time_cache = 0;

#define ARM_EXPECTED_DPLL_ABI_VERSION     DPLL_GENERATED_ABI_VERSION
#define ARM_EXPECTED_DPLL_CONFIG_VERSION  DPLL_GENERATED_CONFIG_VERSION
#define ARM_EXPECTED_DPLL_FPGA_BUILD_ID   DPLL_GENERATED_BUILD_ID
#define ARM_EXPECTED_DPLL_GIT_HASH        DPLL_GENERATED_GIT_HASH
#define PC_ERR_DPLL_ABI_MISMATCH          0xF3U
#define PC_ERR_DPLL_APPLY_TIMEOUT         0xF5U
#define PC_ERR_DPLL_APPLY_REJECTED        0xF6U
#define PC_ERR_DPLL_APPLY_VERIFY          0xF7U
#define DPLL_APPLY_POLL_LIMIT             1024U
#define DPLL_ABI_RETRY_COUNT              100U
#define DPLL_ABI_RETRY_DELAY_US           100U
#define PC_HOST_MAX_FRAME_BYTES           128U
#define DPLL_ADV_CONFIG_PAYLOAD_BYTES     90U
#define DPLL_DEBUG_CONFIG_PAYLOAD_BYTES   12U

static uint8_t dpll_abi_ready = 0;
static uint8_t dpll_driver_initialized = 0;
static dpll_driver_t dpll_driver;

static const dpll_reg_map_t dpll_register_map = {
	PLL0_Lock_Ctrl_Addr,
	DPLL_CONFIG_APPLY_Addr,
	DPLL_CONFIG_REJECTED_MASK_Addr,
	DPLL_ABI_VERSION_Addr,
	DPLL_CONFIG_VERSION_Addr,
	DPLL_FPGA_BUILD_ID_Addr,
	DPLL_GIT_HASH_Addr,
	DAC0_Centre_Frequency_Addr,
	DPLL_POST_IQ_CIC_R_Addr,
	DPLL_POST_IQ_CIC_SHIFT_Addr,
	VOC_Fre_Mul_Addr,
	VOC_Fre_Div_Addr,
	DPLL_PLL_KP_TRACK_Addr,
	DPLL_PLL_KI_TRACK_Addr,
	DPLL_FLL_KF_ACQUIRE_Addr,
	DPLL_FLL_KF_BLEND_Addr,
	DPLL_FLL_KF_TRACK_Addr,
	DPLL_PLL_KP_BLEND_Addr,
	DPLL_PLL_KI_BLEND_Addr,
	DAC0_Phase_Residuals_Threshold_Addr,
	DAC0_Phase_Residuals_Offset_Addr,
	DAC0_Freq_Residuals_Threshold_Addr,
	DPLL_MAG_ENTER_THRESHOLD_Addr,
	DPLL_MAG_EXIT_THRESHOLD_Addr,
	DPLL_ACQUIRE_DWELL_Addr,
	DPLL_BLEND_DWELL_Addr,
	DPLL_LOSS_DWELL_Addr,
	DPLL_HOLDOVER_TIMEOUT_Addr,
	DPLL_MEASUREMENT_TIMEOUT_Addr,
	DPLL_FLL_DELAY_SEL_Addr,
	DPLL_WARMUP_SAMPLES_Addr,
	DPLL_POST_IIR_CONFIG_Addr,
	DPLL_POST_IIR_ACQ_B0_Addr,
	DPLL_POST_IIR_ACQ_B1_Addr,
	DPLL_POST_IIR_ACQ_B2_Addr,
	DPLL_POST_IIR_ACQ_A1_Addr,
	DPLL_POST_IIR_ACQ_A2_Addr,
	DPLL_POST_IIR_TRACK_B0_Addr,
	DPLL_POST_IIR_TRACK_B1_Addr,
	DPLL_POST_IIR_TRACK_B2_Addr,
	DPLL_POST_IIR_TRACK_A1_Addr,
	DPLL_POST_IIR_TRACK_A2_Addr,
	DPLL_FREQ_POS_LIMIT_Addr,
	DPLL_FREQ_NEG_LIMIT_Addr,
	VCO_Freq_Manual_Offset_Addr,
	DAC0_VCO_Offset_Addr,
	DAC0_VOC_Amplitude_Addr,
	DPLL_DEBUG_DAC_OFFSET_ADDR,
	DPLL_DEBUG_DAC_GAIN_ADDR,
	DPLL_DEBUG_DAC_SOURCE_ADDR,
	DPLL_DEBUG_DAC_FORMAT_ADDR,
	DPLL_ACTIVE_CENTER_Addr,
	DPLL_ACTIVE_CIC_CONFIG_Addr,
	DPLL_ACTIVE_MUL_DIV_Addr,
	DPLL_ACTIVE_KP_TRACK_Addr,
	DPLL_ACTIVE_KI_TRACK_Addr,
	DPLL_ACTIVE_KF_ACQUIRE_Addr,
	DPLL_ACTIVE_KF_BLEND_Addr,
	DPLL_ACTIVE_KF_TRACK_Addr,
	DPLL_ACTIVE_KP_BLEND_Addr,
	DPLL_ACTIVE_KI_BLEND_Addr,
	DPLL_ACTIVE_POST_IIR_CONFIG_Addr,
	DPLL_ACTIVE_POST_IIR_ACQ_B0_Addr,
	DPLL_ACTIVE_POST_IIR_ACQ_B1_Addr,
	DPLL_ACTIVE_POST_IIR_ACQ_B2_Addr,
	DPLL_ACTIVE_POST_IIR_ACQ_A1_Addr,
	DPLL_ACTIVE_POST_IIR_ACQ_A2_Addr,
	DPLL_ACTIVE_POST_IIR_TRACK_B0_Addr,
	DPLL_ACTIVE_POST_IIR_TRACK_B1_Addr,
	DPLL_ACTIVE_POST_IIR_TRACK_B2_Addr,
	DPLL_ACTIVE_POST_IIR_TRACK_A1_Addr,
	DPLL_ACTIVE_POST_IIR_TRACK_A2_Addr,
	DPLL_APPLIED_ABI_VERSION_Addr,
	DPLL_ACTIVE_CONFIG_CRC_Addr
};

static const dpll_identity_t dpll_expected_identity = {
	ARM_EXPECTED_DPLL_ABI_VERSION,
	ARM_EXPECTED_DPLL_CONFIG_VERSION,
	ARM_EXPECTED_DPLL_FPGA_BUILD_ID,
	ARM_EXPECTED_DPLL_GIT_HASH
};

static uint32_t dpll_arm_read32(void *context, uint32_t address)
{
	(void)context;
	return Xil_In32(address);
}

static void dpll_arm_write32(void *context, uint32_t address, uint32_t value)
{
	(void)context;
	Xil_Out32(address, value);
}

static void dpll_arm_delay_us(void *context, uint32_t delay_us)
{
	(void)context;
	usleep(delay_us);
}

static void dpll_driver_ensure_initialized(void)
{
	dpll_io_t io;
	if (dpll_driver_initialized) return;
	io.read32 = dpll_arm_read32;
	io.write32 = dpll_arm_write32;
	io.delay_us = dpll_arm_delay_us;
	io.context = 0;
	dpll_driver_init(&dpll_driver, &io, &dpll_register_map,
	                 &dpll_expected_identity, DPLL_ABI_RETRY_COUNT,
	                 DPLL_ABI_RETRY_DELAY_US, DPLL_APPLY_POLL_LIMIT);
	dpll_driver_initialized = 1;
}

static void dpll_invalidate_abi(void)
{
	dpll_driver_ensure_initialized();
	dpll_driver_invalidate_abi(&dpll_driver);
	dpll_abi_ready = 0;
}

void PC_HOST_Send_ASK_Only(uint8_t Ask);

static uint32_t pc_get_u32(uint32_t offset)
{
	return ((uint32_t)PC_HOST_CMD_data_Buff[offset]) |
	       ((uint32_t)PC_HOST_CMD_data_Buff[offset + 1] << 8) |
	       ((uint32_t)PC_HOST_CMD_data_Buff[offset + 2] << 16) |
	       ((uint32_t)PC_HOST_CMD_data_Buff[offset + 3] << 24);
}

static uint16_t pc_get_u16(uint32_t offset)
{
	return ((uint16_t)PC_HOST_CMD_data_Buff[offset]) |
	       ((uint16_t)PC_HOST_CMD_data_Buff[offset + 1] << 8);
}


static uint8_t pc_payload_len(void)
{
	return PC_HOST_CMD_data_Buff[3];
}
static void pc_put_u32(uint32_t offset, uint32_t value)
{
	Uart0_TX_Buff[offset] = value & 0xFF;
	Uart0_TX_Buff[offset + 1] = (value >> 8) & 0xFF;
	Uart0_TX_Buff[offset + 2] = (value >> 16) & 0xFF;
	Uart0_TX_Buff[offset + 3] = (value >> 24) & 0xFF;
}

static uint8_t dpll_initialize_abi(void)
{
	int status;
	dpll_driver_ensure_initialized();
	status = dpll_driver_check_abi(&dpll_driver);
	dpll_abi_ready = dpll_driver.abi_ready;
	if (status == DPLL_DRIVER_OK) {
		xil_printf("DPLL ABI ready abi=0x%08lx config=0x%08lx build=0x%08lx git=0x%08lx attempts=%lu\r\n",
		           (unsigned long)dpll_driver.actual.abi_version,
		           (unsigned long)dpll_driver.actual.config_version,
		           (unsigned long)dpll_driver.actual.build_id,
		           (unsigned long)dpll_driver.actual.git_hash,
		           (unsigned long)dpll_driver.abi_attempts);
		return 1;
	}
	xil_printf("DPLL ABI timeout actual abi=0x%08lx config=0x%08lx build=0x%08lx git=0x%08lx "
	           "expected abi=0x%08lx config=0x%08lx build=0x%08lx git=0x%08lx attempts=%lu\r\n",
	           (unsigned long)dpll_driver.actual.abi_version,
	           (unsigned long)dpll_driver.actual.config_version,
	           (unsigned long)dpll_driver.actual.build_id,
	           (unsigned long)dpll_driver.actual.git_hash,
	           (unsigned long)dpll_driver.expected.abi_version,
	           (unsigned long)dpll_driver.expected.config_version,
	           (unsigned long)dpll_driver.expected.build_id,
	           (unsigned long)dpll_driver.expected.git_hash,
	           (unsigned long)dpll_driver.abi_attempts);
	return 0;
}
static int dpll_apply_config_result(dpll_apply_result_t *result)
{
	int status;
	dpll_driver_ensure_initialized();
	if (!dpll_abi_ready) dpll_driver_invalidate_abi(&dpll_driver);
	status = dpll_driver_apply(&dpll_driver, result);
	dpll_abi_ready = dpll_driver.abi_ready;
	if (status == DPLL_DRIVER_ERR_ABI) PLL_Lock_Status = 0x00;
	return status;
}
static int dpll_apply_config(void)
{
	dpll_apply_result_t result;
	return dpll_apply_config_result(&result);
}
static void pc_send_dpll_apply_result(int apply_status)
{
	if (apply_status == -1) {
		PC_HOST_Send_ASK_Only(PC_ERR_DPLL_ABI_MISMATCH);
		return;
	}
	if (apply_status == -2) {
		PC_HOST_Send_ASK_Only(PC_ERR_DPLL_APPLY_TIMEOUT);
		return;
	}
	if (apply_status == -3) {
		PC_HOST_Send_ASK_Only(PC_ERR_DPLL_APPLY_REJECTED);
		return;
	}
	if (apply_status != 0) {
		PC_HOST_Send_ASK_Only(PC_ERR_DPLL_APPLY_VERIFY);
		return;
	}
	PC_HOST_Send_ASK_Only(0);
}
static int dpll_set_enable(uint32_t enable)
{
	int status;
	dpll_driver_ensure_initialized();
	if (!dpll_abi_ready) dpll_driver_invalidate_abi(&dpll_driver);
	status = dpll_driver_set_enable(&dpll_driver, enable);
	dpll_abi_ready = dpll_driver.abi_ready;
	PLL_Lock_Status = (status == DPLL_DRIVER_OK && enable) ? 0x20 : 0x00;
	return status;
}
void PC_HOST_CMD_Get(void);

void Uart0_Handler(void *CallBackRef)
{
	u32 IsrStatus;
	u32 RX_Num;

	IsrStatus =  XUartPs_ReadReg(XUartPs_uart0.Config.BaseAddress, XUARTPS_IMR_OFFSET);
	IsrStatus &= XUartPs_ReadReg(XUartPs_uart0.Config.BaseAddress, XUARTPS_ISR_OFFSET);

	if((IsrStatus & (u32)XUARTPS_IXR_RXOVR)!=0)
	{
		XUartPs_WriteReg(XUartPs_uart0.Config.BaseAddress, XUARTPS_ISR_OFFSET, XUARTPS_IXR_RXOVR);
		RX_Num=XUartPs_Recv(&XUartPs_uart0,&Uart0_RX_Buff[Uart0_RX_Num],512-Uart0_RX_Num);
		Uart0_RX_Num+=RX_Num;
	}
	if((IsrStatus & (u32)XUARTPS_IXR_TOUT)!=0)
	{
		XUartPs_WriteReg(XUartPs_uart0.Config.BaseAddress, XUARTPS_ISR_OFFSET, XUARTPS_IXR_TOUT);
		RX_Num=XUartPs_Recv(&XUartPs_uart0,&Uart0_RX_Buff[Uart0_RX_Num],512-Uart0_RX_Num);
		Uart0_RX_Num+=RX_Num;
		if(Uart0_RX_Num!=0)PC_HOST_CMD_Get();
		Uart0_RX_Num=0;
	}
}

void Uart0PS_Init(void)
{
	XUartPs_Config *XUartPs_Config_uart0;
	XUartPsFormat XUartPsFormat_uart0;

	int status;

	XUartPs_Config_uart0 = XUartPs_LookupConfig(XPAR_PS7_UART_0_DEVICE_ID);//获得串口1配置信息
	status = XUartPs_CfgInitialize(&XUartPs_uart0,XUartPs_Config_uart0,XUartPs_Config_uart0->BaseAddress);
	if(status != XST_SUCCESS)
	{
		print("Initialize uart1 fail\n");
	}
	XUartPs_SetOperMode(&XUartPs_uart0, XUARTPS_OPER_MODE_NORMAL);
	XUartPsFormat_uart0.BaudRate = 921600;//波特率921600
	XUartPsFormat_uart0.DataBits = XUARTPS_FORMAT_8_BITS;
	XUartPsFormat_uart0.Parity = XUARTPS_FORMAT_NO_PARITY;
	XUartPsFormat_uart0.StopBits = XUARTPS_FORMAT_1_STOP_BIT;
	status = XUartPs_SetDataFormat(&XUartPs_uart0,&XUartPsFormat_uart0);
	if(status != XST_SUCCESS)
	{
		print("set Buad Rate fail\n");
	}
	XUartPs_SetFifoThreshold(&XUartPs_uart0,32);
	XUartPs_SetRecvTimeout(&XUartPs_uart0,4);//4*4=16 timeout IXR
	XUartPs_SetInterruptMask(&XUartPs_uart0,XUARTPS_IXR_RXOVR|XUARTPS_IXR_TOUT);//开中断

	XScuGic_Disable(&XPS_XScuGic,XPS_UART0_INT_ID);
	//XScuGic_SetPriorityTriggerType(&XPS_XScuGic,XPS_UART0_INT_ID,16,1);
	XScuGic_Connect(&XPS_XScuGic,XPS_UART0_INT_ID,(Xil_ExceptionHandler)Uart0_Handler,(void *)&XUartPs_uart0);//入口
	XScuGic_Enable(&XPS_XScuGic,XPS_UART0_INT_ID);

	Uart0_RX_Num=0;
}

void PC_HOST_ASK_Pack(uint32_t Data_Size)
{
	uint32_t i;
	uint32_t checksum = 0;
	Uart0_TX_Buff[0] = 0xA2;
	Uart0_TX_Buff[3] = Data_Size;
	for(i=2;i<(Data_Size+4);i++)
	{
		checksum += Uart0_TX_Buff[i];
	}
	Uart0_TX_Buff[1] = checksum;
	for(i=0;i<(Data_Size+4);i++)XUartPs_SendByte(XUartPs_uart0.Config.BaseAddress,Uart0_TX_Buff[i]);
}

void PC_HOST_Send_ASK(uint8_t CMD,uint8_t Ask)
{
	Uart0_TX_Buff[2] = CMD;
	Uart0_TX_Buff[4] = Ask;
	PC_HOST_ASK_Pack(1);
}
void PC_HOST_Send_ASK_Only(uint8_t Ask)
{
	Uart0_TX_Buff[4] = Ask;
	PC_HOST_ASK_Pack(1);
}

void PC_HOST_CMD_Get(void)
{
	u32 i;
	u32 CheckSm=0;
	PC_HOST_CMD_RX_Mark = 1;
	if(Uart0_RX_Buff[0]!=0xC6)
	{
		PC_HOST_CMD_ASK = 0xF0;
		//print("Err F0 Head\r\n");
		//printf("M %.2X %.2X %.2X %.2X %.2X %.2X\r\n",Uart0_RX_Buff[0],Uart0_RX_Buff[1],Uart0_RX_Buff[2],Uart0_RX_Buff[3],Uart0_RX_Buff[4],Uart0_RX_Buff[5]);
		return;
	}
	if((Uart0_RX_Num<4)||(Uart0_RX_Num>PC_HOST_MAX_FRAME_BYTES))
	{
		PC_HOST_CMD_ASK = 0xF1;
		//print("Err F1 Length\r\n");
		return;
	}
	if(Uart0_RX_Buff[3]!=(Uart0_RX_Num-4))
	{
		PC_HOST_CMD_ASK = 0xF2;
		//print("Err F2 nums\r\n");
		return;
	}
	if(((Uart0_RX_Buff[2]<0x80)&&(Uart0_RX_Buff[2]>0x1B))||(Uart0_RX_Buff[2]>0x9A))
	{
		PC_HOST_CMD_ASK = 0xF3;
		//print("Err F3 cmd\r\n");
		return;
	}
	for(i=2;i<(Uart0_RX_Num);i++)
	{
		CheckSm += Uart0_RX_Buff[i];
	}
	if(Uart0_RX_Buff[1]!=(CheckSm&0xFF))
	{
		PC_HOST_CMD_ASK = 0xF4;
		//print("Err F4 checksum\r\n");
		return;
	}
	PC_HOST_CMD_GET = Uart0_RX_Buff[2];
	if(Uart0_RX_Buff[3]>1)
	for(i=0;i<Uart0_RX_Num;i++)
	{
		PC_HOST_CMD_data_Buff[i] = Uart0_RX_Buff[i];
	}
	PC_HOST_CMD_ASK = 0x00;
}

//void CMD_01_READ_MWS_SETTING(void)
//{
//	uint32_t Error_Code;
//	uint32_t Freq;
//	uint8_t pwr;
//	Error_Code = Uart1_STM8_Get_MWS_CFG(&Freq,&pwr);
//	if(Error_Code)
//	{
//		PC_HOST_Send_ASK(0xFE,Error_Code);
//		return;
//	}
//	Uart0_TX_Buff[4] = Freq&0xFF;
//	Uart0_TX_Buff[5] = (Freq>>8)&0xFF;
//	Uart0_TX_Buff[6] = (Freq>>16)&0xFF;
//	Uart0_TX_Buff[7] = (Freq>>24)&0xFF;
//	Uart0_TX_Buff[8] = pwr;
//	PC_HOST_ASK_Pack(5);
//}
//void CMD_02_READ_MWS_STATUS(void)
//{
//	uint32_t Error_Code;
//	uint8_t sta;
//	Error_Code = Uart1_STM8_Read_MWS_Status(&sta);
//	if(Error_Code)
//	{
//		Uart0_TX_Buff[4] = 0x80;
//		PC_HOST_ASK_Pack(1);
//		return;
//	}
//	Uart0_TX_Buff[4] = sta;
//	PC_HOST_ASK_Pack(1);
//
//}
void CMD_03_READ_PLL_FREQ_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(DAC0_Centre_Frequency_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	PC_HOST_ASK_Pack(4);
}
void CMD_04_READ_PLL_MUL_DIV_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(VOC_Fre_Mul_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	i = Xil_In32(VOC_Fre_Div_Addr);
	Uart0_TX_Buff[6] = i&0xFF;
	Uart0_TX_Buff[7] = (i>>8)&0xFF;

	PC_HOST_ASK_Pack(4);
}
void CMD_05_READ_PLL_THRESHOLD_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(DAC0_Phase_Residuals_Threshold_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	i = Xil_In32(DAC0_Freq_Residuals_Threshold_Addr);
	Uart0_TX_Buff[6] = i&0xFF;
	Uart0_TX_Buff[7] = (i>>8)&0xFF;

	PC_HOST_ASK_Pack(4);
}
void CMD_06_READ_PLL_LIMIT_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(DPLL_FREQ_POS_LIMIT_Addr);
	Uart0_TX_Buff[4] = (i>>16)&0xFF;
	Uart0_TX_Buff[5] = (i>>24)&0xFF;
	i = Xil_In32(DPLL_FREQ_NEG_LIMIT_Addr);
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	PC_HOST_ASK_Pack(4);
}
void CMD_07_READ_DPLL_LOOP_BASIC_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(DPLL_PLL_KP_TRACK_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;
	i = Xil_In32(DPLL_PLL_KI_TRACK_Addr);
	Uart0_TX_Buff[8] = i&0xFF;
	Uart0_TX_Buff[9] = (i>>8)&0xFF;
	Uart0_TX_Buff[10] = (i>>16)&0xFF;
	Uart0_TX_Buff[11] = (i>>24)&0xFF;
	i = Xil_In32(DPLL_FLL_KF_ACQUIRE_Addr);
	Uart0_TX_Buff[12] = i&0xFF;
	Uart0_TX_Buff[13] = (i>>8)&0xFF;
	Uart0_TX_Buff[14] = (i>>16)&0xFF;
	Uart0_TX_Buff[15] = (i>>24)&0xFF;
	i = Xil_In32(DPLL_FLL_KF_BLEND_Addr);
	Uart0_TX_Buff[16] = i&0xFF;
	Uart0_TX_Buff[17] = (i>>8)&0xFF;
	Uart0_TX_Buff[18] = (i>>16)&0xFF;
	Uart0_TX_Buff[19] = (i>>24)&0xFF;

	PC_HOST_ASK_Pack(16);
}
void CMD_08_READ_PLL_AMP_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(DAC0_VOC_Amplitude_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;

	PC_HOST_ASK_Pack(2);
}
void CMD_09_PLL_STATUS(void)
{
	uint32_t i,data;
	i = Xil_In32(PLL0_Output_Limit_Average);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	i = Xil_In32(PLL0_phase_residuals);
	Uart0_TX_Buff[8] = i&0xFF;
	Uart0_TX_Buff[9] = (i>>8)&0xFF;
	Uart0_TX_Buff[10] = (i>>16)&0xFF;
	Uart0_TX_Buff[11] = (i>>24)&0xFF;

	i = Xil_In32(DDC0_inst_frequency);
	Uart0_TX_Buff[12] = (i>>0)&0xFF;
	Uart0_TX_Buff[13] = (i>>8)&0xFF;

	i = Xil_In32(System_Statue);
	data = i&0x3F;
	Uart0_TX_Buff[14] = PLL_Lock_Status|data;

	PC_HOST_ASK_Pack(11);
}

void CMD_0A_READ_VERSION(void)
{
	Uart0_TX_Buff[4] = 1;
	PC_HOST_ASK_Pack(1);
}


uint16_t DataLog_Buff[2048];

//void CMD_0C_DataLog_Read(void)
//{
//	uint32_t i,checksum = 0;
//
//	Xil_Out32(ADC_LOG_Trigger_Addr,1);
//	usleep(100);
//
//	for(i=0;i<2048;i++)
//	{
//		DataLog_Buff[i] = Xil_In32(ADC_LOG_Buff_Begin_Addr + i*4);
//		checksum += DataLog_Buff[i]&0xFF;
//		checksum += (DataLog_Buff[i]>>8)&0xFF;
//	}
//	Uart0_TX_Buff[4] = 0x00;
//	Uart0_TX_Buff[5] = 0x10;
//	Uart0_TX_Buff[6] = 0x00;
//	Uart0_TX_Buff[7] = 0x00;
//
//	Uart0_TX_Buff[8] = checksum&0xFF;
//	Uart0_TX_Buff[9] = (checksum>>8)&0xFF;
//
//	PC_HOST_ASK_Pack(6);
//	for(i=0;i<2048;i++)
//	{
//		XUartPs_SendByte(XUartPs_uart0.Config.BaseAddress,DataLog_Buff[i]);
//		XUartPs_SendByte(XUartPs_uart0.Config.BaseAddress,DataLog_Buff[i]>>8);
//	}
//
//}


void CMD_10_READ_FREQMETER_FREQ_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(Freq_Meter_Centre_Frequency_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	PC_HOST_ASK_Pack(4);
}

void CMD_11_READ_FREQMETER_THRESHOLD_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(Freq_Meter_Phase_Residuals_Threshold_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	i = Xil_In32(Freq_Meter_Freq_Residuals_Threshold_Addr);
	Uart0_TX_Buff[6] = i&0xFF;
	Uart0_TX_Buff[7] = (i>>8)&0xFF;

	PC_HOST_ASK_Pack(4);
}
void CMD_12_READ_FREQMETER_LIMIT_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(Freq_Meter_Freq_Pos_Limit_Addr);
	Uart0_TX_Buff[4] = (i>>16)&0xFF;
	Uart0_TX_Buff[5] = (i>>24)&0xFF;
	i = Xil_In32(Freq_Meter_Freq_Neg_Limit_Addr);
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	PC_HOST_ASK_Pack(4);
}
void CMD_13_READ_FREQMETER_PID_SETTING(void)
{
	uint32_t i;
	i = Xil_In32(Freq_Meter_PID_GainP_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;
	i = Xil_In32(Freq_Meter_PID_GainI_Addr);
	Uart0_TX_Buff[8] = i&0xFF;
	Uart0_TX_Buff[9] = (i>>8)&0xFF;
	Uart0_TX_Buff[10] = (i>>16)&0xFF;
	Uart0_TX_Buff[11] = (i>>24)&0xFF;
	i = Xil_In32(Freq_Meter_PID_GainI2_Addr);
	Uart0_TX_Buff[12] = i&0xFF;
	Uart0_TX_Buff[13] = (i>>8)&0xFF;
	Uart0_TX_Buff[14] = (i>>16)&0xFF;
	Uart0_TX_Buff[15] = (i>>24)&0xFF;
	i = Xil_In32(Freq_Meter_PID_GainD_Addr);
	Uart0_TX_Buff[16] = i&0xFF;
	Uart0_TX_Buff[17] = (i>>8)&0xFF;
	Uart0_TX_Buff[18] = (i>>16)&0xFF;
	Uart0_TX_Buff[19] = (i>>24)&0xFF;

	PC_HOST_ASK_Pack(16);
}
void CMD_14_READ_FREQMETER_STATUS(void)
{
	uint32_t i,data;

	i = Xil_In32(Freq_Meter_PLL_phase_residuals_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	i = Xil_In32(Freq_Meter_inst_frequency_Addr);
	Uart0_TX_Buff[8] = (i>>0)&0xFF;
	Uart0_TX_Buff[9] = (i>>8)&0xFF;

	i = Xil_In32(Freq_Meter_System_Statue_Addr);
	data = i&0x3F;
	Uart0_TX_Buff[10] = 0x20|data;

	PC_HOST_ASK_Pack(7);
}

void CMD_15_READ_FREQMETER_RUN_STATUS(void)
{
	uint32_t data;

	data = Xil_In32(Freq_Meter_Run_Statue_Addr);
	if(data != 0)Uart0_TX_Buff[4] = 1;
	else Uart0_TX_Buff[4] = 0;

	PC_HOST_ASK_Pack(1);
}

void CMD_16_READ_FREQMETER_TIMER(void)
{
	uint32_t i;
	i = Xil_In32(Freq_Meter_Gate_Time_L_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	i = Xil_In32(Freq_Meter_Gate_Time_H_Addr);
	Uart0_TX_Buff[8] = i&0xFF;
	Uart0_TX_Buff[9] = (i>>8)&0xFF;

	PC_HOST_ASK_Pack(6);
}

void CMD_17_READ_FREQMETER_CNT(void)
{
	uint32_t i;
	i = Xil_In32(Freq_Meter_DataL_Output_Addr);
	Uart0_TX_Buff[4] = i&0xFF;
	Uart0_TX_Buff[5] = (i>>8)&0xFF;
	Uart0_TX_Buff[6] = (i>>16)&0xFF;
	Uart0_TX_Buff[7] = (i>>24)&0xFF;

	i = Xil_In32(Freq_Meter_DataM_Output_Addr);
	Uart0_TX_Buff[8] = i&0xFF;
	Uart0_TX_Buff[9] = (i>>8)&0xFF;
	Uart0_TX_Buff[10] = (i>>16)&0xFF;
	Uart0_TX_Buff[11] = (i>>24)&0xFF;

	i = Xil_In32(Freq_Meter_DataH_Output_Addr);
	Uart0_TX_Buff[12] = i&0xFF;
	Uart0_TX_Buff[13] = (i>>8)&0xFF;

	Uart0_TX_Buff[14] = Freq_meter_gate_time_cache&0xFF;
	Uart0_TX_Buff[15] = (Freq_meter_gate_time_cache>>8)&0xFF;
	Uart0_TX_Buff[16] = (Freq_meter_gate_time_cache>>16)&0xFF;
	Uart0_TX_Buff[17] = (Freq_meter_gate_time_cache>>24)&0xFF;
	Uart0_TX_Buff[18] = (Freq_meter_gate_time_cache>>32)&0xFF;
	Uart0_TX_Buff[19] = (Freq_meter_gate_time_cache>>40)&0xFF;

	PC_HOST_ASK_Pack(16);
}

void CMD_18_READ_DPLL_ID_STATUS(void)
{
	pc_put_u32(4, Xil_In32(DPLL_ABI_VERSION_Addr));
	pc_put_u32(8, Xil_In32(DPLL_FPGA_BUILD_ID_Addr));
	pc_put_u32(12, Xil_In32(DPLL_CONFIG_VERSION_Addr));
	pc_put_u32(16, Xil_In32(DPLL_CORE_FLAGS_Addr));
	pc_put_u32(20, Xil_In32(DPLL_ACTIVE_CIC_CONFIG_Addr));
	pc_put_u32(24, Xil_In32(DPLL_TRACKING_WORD_HI_Addr));
	pc_put_u32(28, Xil_In32(DPLL_VCO_WORD_LO_Addr));
	pc_put_u32(32, Xil_In32(DPLL_VCO_WORD_HI_Addr));
	pc_put_u32(36, Xil_In32(DPLL_GIT_HASH_Addr));
	pc_put_u32(40, DPLL_GENERATED_DIRTY);

	PC_HOST_ASK_Pack(40);
}

void CMD_19_READ_DPLL_ADV_CONFIG(void)
{
	pc_put_u32(4, Xil_In32(DPLL_FLL_KF_TRACK_Addr));
	pc_put_u32(8, Xil_In32(DPLL_PLL_KP_BLEND_Addr));
	pc_put_u32(12, Xil_In32(DPLL_PLL_KI_BLEND_Addr));
	pc_put_u32(16, Xil_In32(DPLL_MAG_ENTER_THRESHOLD_Addr));
	pc_put_u32(20, Xil_In32(DPLL_MAG_EXIT_THRESHOLD_Addr));
	pc_put_u32(24, Xil_In32(DPLL_ACQUIRE_DWELL_Addr));
	pc_put_u32(28, Xil_In32(DPLL_BLEND_DWELL_Addr));
	pc_put_u32(32, Xil_In32(DPLL_LOSS_DWELL_Addr));
	pc_put_u32(36, Xil_In32(DPLL_HOLDOVER_TIMEOUT_Addr));
	pc_put_u32(40, Xil_In32(DPLL_POST_IQ_CIC_R_Addr));
	pc_put_u32(44, Xil_In32(DPLL_POST_IQ_CIC_SHIFT_Addr));
	pc_put_u32(48, Xil_In32(DPLL_FLL_DELAY_SEL_Addr));
	pc_put_u32(52, Xil_In32(DPLL_WARMUP_SAMPLES_Addr));
	pc_put_u32(56, Xil_In32(DPLL_MEASUREMENT_TIMEOUT_Addr));
	pc_put_u32(60, Xil_In32(DPLL_POST_IIR_CONFIG_Addr));
	pc_put_u32(64, Xil_In32(DPLL_POST_IIR_ACQ_B0_Addr));
	pc_put_u32(68, Xil_In32(DPLL_POST_IIR_ACQ_B1_Addr));
	pc_put_u32(72, Xil_In32(DPLL_POST_IIR_ACQ_B2_Addr));
	pc_put_u32(76, Xil_In32(DPLL_POST_IIR_ACQ_A1_Addr));
	pc_put_u32(80, Xil_In32(DPLL_POST_IIR_ACQ_A2_Addr));
	pc_put_u32(84, Xil_In32(DPLL_POST_IIR_TRACK_B0_Addr));
	pc_put_u32(88, Xil_In32(DPLL_POST_IIR_TRACK_B1_Addr));
	pc_put_u32(92, Xil_In32(DPLL_POST_IIR_TRACK_B2_Addr));
	pc_put_u32(96, Xil_In32(DPLL_POST_IIR_TRACK_A1_Addr));
	pc_put_u32(100, Xil_In32(DPLL_POST_IIR_TRACK_A2_Addr));

	PC_HOST_ASK_Pack(100);
}
void CMD_1A_READ_VBIAS_DAC(void)
{
	Uart0_TX_Buff[4] = 0;
	Uart0_TX_Buff[5] = 0;

	Uart0_TX_Buff[6] = 0;
	Uart0_TX_Buff[7] = 0;

	PC_HOST_ASK_Pack(4);
}

void CMD_1B_READ_VBIAS_ADC(void)
{
	Uart0_TX_Buff[4] = 0;
	Uart0_TX_Buff[5] = 0;

	Uart0_TX_Buff[6] = 0;
	Uart0_TX_Buff[7] = 0;

	PC_HOST_ASK_Pack(4);
}


//void CMD_81_WRITE_MWS_FREQ_PWR(void)
//{
//	uint32_t Error_Code;
//	uint32_t freq;
//	uint8_t pwr = PC_HOST_CMD_data_Buff[8];
//	freq = PC_HOST_CMD_data_Buff[4]|((uint8_t)PC_HOST_CMD_data_Buff[5]<<8)|((uint8_t)PC_HOST_CMD_data_Buff[6]<<16)|((uint8_t)PC_HOST_CMD_data_Buff[7]<<24);
//	Error_Code = Uart1_STM8_Set_MWS_CFG(freq,pwr);
//	PC_HOST_Send_ASK_Only(Error_Code);
//}
void CMD_82_WRITE_PLL_FREQ(void)
{
	//*((uint32_t*)&STM8_EEPROM_Data[0+8]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
	Xil_Out32(DAC0_Centre_Frequency_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[4]));//中心频率
	pc_send_dpll_apply_result(dpll_apply_config());
}
void CMD_83_WRITE_PLL_MUL_DIV(void)
{
	//*((uint32_t*)&STM8_EEPROM_Data[4+8]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
	Xil_Out32(VOC_Fre_Mul_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[4]));//MUL
	Xil_Out32(VOC_Fre_Div_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[6]));//DIV
	pc_send_dpll_apply_result(dpll_apply_config());
}
void CMD_84_WRITE_PLL_THRESHOLD(void)
{
	//*((uint32_t*)&STM8_EEPROM_Data[28+8]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
    Xil_Out32(DAC0_Freq_Residuals_Threshold_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[4]));//14Bit
    Xil_Out32(DAC0_Phase_Residuals_Threshold_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[6]));//32Bit
	pc_send_dpll_apply_result(dpll_apply_config());
}
void CMD_85_WRITE_PLL_LIMIT(void)
{
	uint32_t data;
	data = *((uint16_t*)&PC_HOST_CMD_data_Buff[4]);
	if(data > 0x7FFF) data = 0x7FFF;
	//*((uint16_t*)&STM8_EEPROM_Data[24+8]) = data;
    Xil_Out32(DPLL_FREQ_POS_LIMIT_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit

	data = *((uint16_t*)&PC_HOST_CMD_data_Buff[6]);
	if(data < 0x8000) data = 0x8000;
	//*((uint16_t*)&STM8_EEPROM_Data[26+8]) = data;
    Xil_Out32(DPLL_FREQ_NEG_LIMIT_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit
	pc_send_dpll_apply_result(dpll_apply_config());
}
void CMD_86_WRITE_DPLL_LOOP_BASIC(void)
{
	//*((uint32_t*)&STM8_EEPROM_Data[8+8]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
	//*((uint32_t*)&STM8_EEPROM_Data[12+8]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[8]);
	//*((uint32_t*)&STM8_EEPROM_Data[16+8]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[12]);
	//*((uint32_t*)&STM8_EEPROM_Data[20+8]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[16]);
    Xil_Out32(DPLL_PLL_KP_TRACK_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[4]));
    Xil_Out32(DPLL_PLL_KI_TRACK_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[8]));
    Xil_Out32(DPLL_FLL_KF_ACQUIRE_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[12]));
    Xil_Out32(DPLL_FLL_KF_BLEND_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[16]));
	pc_send_dpll_apply_result(dpll_apply_config());
}
void CMD_87_WRITE_PLL_AMP(void)
{
	//*((uint16_t*)&STM8_EEPROM_Data[32+8]) = *((uint16_t*)&PC_HOST_CMD_data_Buff[4]);
	Xil_Out32(DAC0_VOC_Amplitude_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[4]));//amplitude 15bit;
	pc_send_dpll_apply_result(dpll_apply_config());
}
//void CMD_88_WRITE_MWS_ON(void)
//{
//	uint32_t Error_Code;
//	Error_Code = Uart1_STM8_Set_RF_ON();
//	PC_HOST_Send_ASK_Only(Error_Code);
//}
//void CMD_89_WRITE_MWS_OFF(void)
//{
//	uint32_t Error_Code;
//	Error_Code = Uart1_STM8_Set_RF_OFF();
//	PC_HOST_Send_ASK_Only(Error_Code);
//}
//void CMD_8C_LOAD_EEPROM(void)
//{
//	uint32_t Error_Code;
//	Error_Code = Uart1_STM8_Read_EEPROM();
//	Write_PLL_Data_From_EEPROM();
//	PC_HOST_Send_ASK_Only(Error_Code);
//}
//void CMD_8D_SAVE_EEPROM(void)
//{
//	uint32_t Error_Code;
//	Error_Code = Uart1_STM8_Save_EEPROM();
//	PC_HOST_Send_ASK_Only(Error_Code);
//}

void CMD_8F_WRITE_DPLL_ADV_CONFIG(void)
{
	if (pc_payload_len() < DPLL_ADV_CONFIG_PAYLOAD_BYTES) {
		PC_HOST_Send_ASK_Only(0xF2);
		return;
	}
	Xil_Out32(DPLL_FLL_KF_TRACK_Addr, pc_get_u32(4));
	Xil_Out32(DPLL_PLL_KP_BLEND_Addr, pc_get_u32(8));
	Xil_Out32(DPLL_PLL_KI_BLEND_Addr, pc_get_u32(12));
	Xil_Out32(DPLL_MAG_ENTER_THRESHOLD_Addr, pc_get_u32(16));
	Xil_Out32(DPLL_MAG_EXIT_THRESHOLD_Addr, pc_get_u32(20));
	Xil_Out32(DPLL_ACQUIRE_DWELL_Addr, pc_get_u32(24));
	Xil_Out32(DPLL_BLEND_DWELL_Addr, pc_get_u32(28));
	Xil_Out32(DPLL_LOSS_DWELL_Addr, pc_get_u32(32));
	Xil_Out32(DPLL_HOLDOVER_TIMEOUT_Addr, pc_get_u32(36));
	Xil_Out32(DPLL_POST_IQ_CIC_R_Addr, pc_get_u16(40));
	Xil_Out32(DPLL_POST_IQ_CIC_SHIFT_Addr, PC_HOST_CMD_data_Buff[42]);
	Xil_Out32(DPLL_FLL_DELAY_SEL_Addr, PC_HOST_CMD_data_Buff[43]);
	Xil_Out32(DPLL_WARMUP_SAMPLES_Addr, pc_get_u16(44));
	Xil_Out32(DPLL_MEASUREMENT_TIMEOUT_Addr, pc_get_u32(46));
	Xil_Out32(DPLL_POST_IIR_CONFIG_Addr, pc_get_u32(50));
	Xil_Out32(DPLL_POST_IIR_ACQ_B0_Addr, pc_get_u32(54));
	Xil_Out32(DPLL_POST_IIR_ACQ_B1_Addr, pc_get_u32(58));
	Xil_Out32(DPLL_POST_IIR_ACQ_B2_Addr, pc_get_u32(62));
	Xil_Out32(DPLL_POST_IIR_ACQ_A1_Addr, pc_get_u32(66));
	Xil_Out32(DPLL_POST_IIR_ACQ_A2_Addr, pc_get_u32(70));
	Xil_Out32(DPLL_POST_IIR_TRACK_B0_Addr, pc_get_u32(74));
	Xil_Out32(DPLL_POST_IIR_TRACK_B1_Addr, pc_get_u32(78));
	Xil_Out32(DPLL_POST_IIR_TRACK_B2_Addr, pc_get_u32(82));
	Xil_Out32(DPLL_POST_IIR_TRACK_A1_Addr, pc_get_u32(86));
	Xil_Out32(DPLL_POST_IIR_TRACK_A2_Addr, pc_get_u32(90));
	pc_send_dpll_apply_result(dpll_apply_config());
}
void CMD_90_WRITE_FREQMETER_FREQ(void)
{
	//*((uint32_t*)&STM8_EEPROM_Data[0+44]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
	Xil_Out32(Freq_Meter_Centre_Frequency_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[4]));//中心频率
	PC_HOST_Send_ASK_Only(0);
}
void CMD_91_WRITE_FREQMETER_THRESHOLD(void)
{
	//*((uint32_t*)&STM8_EEPROM_Data[4+44]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
    Xil_Out32(Freq_Meter_Freq_Residuals_Threshold_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[4]));//14Bit
    Xil_Out32(Freq_Meter_Phase_Residuals_Threshold_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[6]));//32Bit
	PC_HOST_Send_ASK_Only(0);
}
void CMD_92_WRITE_FREQMETER_LIMIT(void)
{
	uint32_t data;

	//*((uint16_t*)&STM8_EEPROM_Data[8+44]) = *((uint16_t*)&PC_HOST_CMD_data_Buff[4]);
	//*((uint16_t*)&STM8_EEPROM_Data[10+44]) = *((uint16_t*)&PC_HOST_CMD_data_Buff[6]);
    //data = *((uint16_t*)&STM8_EEPROM_Data[8+44]);
    //Xil_Out32(Freq_Meter_Freq_Pos_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit
    //data = *((uint16_t*)&STM8_EEPROM_Data[10+44]);
    //Xil_Out32(Freq_Meter_Freq_Neg_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit

	data = *((uint16_t*)&PC_HOST_CMD_data_Buff[4]);
	if(data > 0x7FFF) data = 0x3FFF;
	//*((uint16_t*)&STM8_EEPROM_Data[8+44]) = data;
    Xil_Out32(Freq_Meter_Freq_Pos_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit

	data = *((uint16_t*)&PC_HOST_CMD_data_Buff[6]);
	if(data < 0xA000) data = 0xA000;
	//*((uint16_t*)&STM8_EEPROM_Data[10+44]) = data;
    Xil_Out32(Freq_Meter_Freq_Neg_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit

	PC_HOST_Send_ASK_Only(0);
}
void CMD_93_WRITE_FREQMETER_PID(void)
{
//	*((uint32_t*)&STM8_EEPROM_Data[12+44]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
//	*((uint32_t*)&STM8_EEPROM_Data[16+44]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[8]);
//	*((uint32_t*)&STM8_EEPROM_Data[20+44]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[12]);
//	*((uint32_t*)&STM8_EEPROM_Data[24+44]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[16]);
    Xil_Out32(Freq_Meter_PID_GainP_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[4]));
    Xil_Out32(Freq_Meter_PID_GainI_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[8]));
    Xil_Out32(Freq_Meter_PID_GainI2_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[12]));
    Xil_Out32(Freq_Meter_PID_GainD_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[16]));
	PC_HOST_Send_ASK_Only(0);
}
void CMD_94_WRITE_FREQMETER_TIMER(void)
{
	//*((uint32_t*)&STM8_EEPROM_Data[28+44]) = *((uint32_t*)&PC_HOST_CMD_data_Buff[4]);
	Xil_Out32(Freq_Meter_Gate_Time_L_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[4]));//中心频率
	Xil_Out32(Freq_Meter_Gate_Time_H_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[8]));//中心频率
	PC_HOST_Send_ASK_Only(0);
}

void CMD_97_WRITE_DPLL_DEBUG_CONFIG(void)
{
	if (pc_payload_len() < DPLL_DEBUG_CONFIG_PAYLOAD_BYTES) {
		PC_HOST_Send_ASK_Only(0xF2);
		return;
	}
	Xil_Out32(DPLL_DEBUG_DAC_SOURCE_ADDR, pc_get_u32(4));
	Xil_Out32(DPLL_DEBUG_DAC_FORMAT_ADDR, pc_get_u32(8));
	Xil_Out32(DPLL_DEBUG_DAC_OFFSET_ADDR, pc_get_u16(12));
	Xil_Out32(DPLL_DEBUG_DAC_GAIN_ADDR, pc_get_u16(14));
	PC_HOST_Send_ASK_Only(0);
}
void CMD_9A_WRITE_VBIAS_DAC(void)
{
	PC_HOST_Send_ASK_Only(0);
}


void PC_HOST_CMD_Respond(void)
{
	uint32_t i;
	if(PC_HOST_CMD_RX_Mark)
	{
		usleep(200);
		if(PC_HOST_CMD_ASK == 0x00)
		{
			//printf("OK_0x%.2XR\r\n",PC_HOST_CMD_GET);
			Uart0_TX_Buff[2] = PC_HOST_CMD_GET;
			switch(PC_HOST_CMD_GET)
			{
//			case PC_CMD_READ_MWS_SETTING:
//				CMD_01_READ_MWS_SETTING();
//				break;
//			case PC_CMD_READ_MWS_STATUS:
//				CMD_02_READ_MWS_STATUS();
//				break;
			case PC_CMD_READ_PLL_FREQ_SETTING:
				CMD_03_READ_PLL_FREQ_SETTING();
				break;
			case PC_CMD_READ_PLL_MUL_DIV_SETTING:
				CMD_04_READ_PLL_MUL_DIV_SETTING();
				break;
			case PC_CMD_READ_PLL_THRESHOLD_SETTING:
				CMD_05_READ_PLL_THRESHOLD_SETTING();
				break;
			case PC_CMD_READ_PLL_LIMIT_SETTING:
				CMD_06_READ_PLL_LIMIT_SETTING();
				break;
			case PC_CMD_READ_DPLL_LOOP_BASIC_SETTING:
				CMD_07_READ_DPLL_LOOP_BASIC_SETTING();
				break;
			case PC_CMD_READ_PLL_AMP_SETTING:
				CMD_08_READ_PLL_AMP_SETTING();
				break;
			case PC_CMD_READ_PLL_STATUS:
				CMD_09_PLL_STATUS();
				break;
			case PC_CMD_READ_VERSION:
				CMD_0A_READ_VERSION();
				break;

//			case PC_CMD_READ_DATA_LOG:
//				CMD_0C_DataLog_Read();
//				break;

			case PC_CMD_READ_DPLL_ID_STATUS:
				CMD_18_READ_DPLL_ID_STATUS();
				break;
			case PC_CMD_READ_DPLL_ADV_CONFIG:
				CMD_19_READ_DPLL_ADV_CONFIG();
				break;
			case PC_CMD_READ_FREQMETER_FREQ_SETTING:
				CMD_10_READ_FREQMETER_FREQ_SETTING();
				break;
			case PC_CMD_READ_FREQMETER_THRESHOLD_SETTING:
				CMD_11_READ_FREQMETER_THRESHOLD_SETTING();
				break;
			case PC_CMD_READ_FREQMETER_LIMIT_SETTING:
				CMD_12_READ_FREQMETER_LIMIT_SETTING();
				break;
			case PC_CMD_READ_FREQMETER_PID_SETTING:
				CMD_13_READ_FREQMETER_PID_SETTING();
				break;
			case PC_CMD_READ_FREQMETER_STATUS:
				CMD_14_READ_FREQMETER_STATUS();
				break;
			case PC_CMD_READ_FREQMETER_RUN_STATUS:
				CMD_15_READ_FREQMETER_RUN_STATUS();
				break;
			case PC_CMD_READ_FREQMETER_TIMER_SETTING:
				CMD_16_READ_FREQMETER_TIMER();
				break;
			case PC_CMD_READ_FREQMETER_CNT:
				CMD_17_READ_FREQMETER_CNT();
				break;
//			case PC_CMD_VBIAS_READ_DAC:
//				CMD_1A_READ_VBIAS_DAC();
//				break;
//			case PC_CMD_VBIAS_READ_ADC:
//				CMD_1B_READ_VBIAS_ADC();
//				break;


//			case PC_CMD_WRITE_MWS_FREQ_PWR:
//				CMD_81_WRITE_MWS_FREQ_PWR();
//				break;
			case PC_CMD_WRITE_PLL_FREQ:
				CMD_82_WRITE_PLL_FREQ();
				break;
			case PC_CMD_WRITE_PLL_MUL_DIV:
				CMD_83_WRITE_PLL_MUL_DIV();
				break;
			case PC_CMD_WRITE_PLL_THRESHOLD:
				CMD_84_WRITE_PLL_THRESHOLD();
				break;
			case PC_CMD_WRITE_PLL_LIMIT:
				CMD_85_WRITE_PLL_LIMIT();
				break;
			case PC_CMD_WRITE_DPLL_LOOP_BASIC:
				CMD_86_WRITE_DPLL_LOOP_BASIC();
				break;
			case PC_CMD_WRITE_PLL_AMP:
				CMD_87_WRITE_PLL_AMP();
				break;
//			case PC_CMD_WRITE_MWS_ON:
//				CMD_88_WRITE_MWS_ON();
//				break;
//			case PC_CMD_WRITE_MWS_OFF:
//				CMD_89_WRITE_MWS_OFF();
//				break;
			case PC_CMD_WRITE_PLL_ON:
				if (dpll_set_enable(1) != 0) {
					PC_HOST_Send_ASK_Only(PC_ERR_DPLL_ABI_MISMATCH);
				} else {
					PC_HOST_Send_ASK_Only(0);
				}
				break;
			case PC_CMD_WRITE_PLL_OFF:
				dpll_set_enable(0);
				PC_HOST_Send_ASK_Only(0);
				break;
//			case PC_CMD_LOAD_EEPROM:
//				CMD_8C_LOAD_EEPROM();
//				break;
//			case PC_CMD_SAVE_EEPROM:
//				CMD_8D_SAVE_EEPROM();
//				break;
			case PC_CMD_PLL_RESET:
				Xil_Out32(Opal_Kelly_Reset_Trigger_Addr,0);
				dpll_invalidate_abi();
				dpll_initialize_abi();
				PC_HOST_Send_ASK_Only(dpll_abi_ready ? 0 : PC_ERR_DPLL_ABI_MISMATCH);
				break;

			case PC_CMD_WRITE_DPLL_ADV_CONFIG:
				CMD_8F_WRITE_DPLL_ADV_CONFIG();
				break;
			case PC_CMD_FREQMETER_FREQ:
				CMD_90_WRITE_FREQMETER_FREQ();
				break;
			case PC_CMD_FREQMETER_THRESHOLD:
				CMD_91_WRITE_FREQMETER_THRESHOLD();
				break;
			case PC_CMD_FREQMETER_LIMIT:
				CMD_92_WRITE_FREQMETER_LIMIT();
				break;
			case PC_CMD_FREQMETER_PID:
				CMD_93_WRITE_FREQMETER_PID();
				break;
			case PC_CMD_FREQMETER_TIMER:
				CMD_94_WRITE_FREQMETER_TIMER();
				break;
			case PC_CMD_FREQMETER_TRIG:
				Xil_Out32(Freq_Meter_Run_Trigger_Addr,0);
				Freq_meter_gate_time_cache = Xil_In32(Freq_Meter_Gate_Time_L_Addr);
				i = Xil_In32(Freq_Meter_Gate_Time_H_Addr);
				Freq_meter_gate_time_cache |= (uint64_t)i<<32;
				PC_HOST_Send_ASK_Only(0);
				break;
			case PC_CMD_FREQMETER_RESET:
				PC_HOST_Send_ASK_Only(0);
				Xil_Out32(Freq_Meter_Lock_Ctrl_Addr,0);
				Xil_Out32(Freq_Meter_Reset_Trigger_Addr,0);
				Xil_Out32(Freq_Meter_Lock_Ctrl_Addr,0);
				break;

			case PC_CMD_WRITE_DPLL_DEBUG_CONFIG:
				CMD_97_WRITE_DPLL_DEBUG_CONFIG();
				break;
//			case PC_CMD_VBIAS_WRITE_DAC:
//				CMD_9A_WRITE_VBIAS_DAC();
//				break;

			}
		}
		else
		{
			PC_HOST_Send_ASK(PC_HOST_CMD_GET,PC_HOST_CMD_ASK);
		}
		PC_HOST_CMD_RX_Mark = 0;
	}
}




/*********************************UART1  STM8COM****************************/



#define PACKAGE_SOH 0xA1
#define PACKAGE_STX 0xA2
#define PACKAGE_ETX 0xA3

#define STATUS_NACK                     0x03
#define STATUS_COMMAND_NUMBER_ERROR     0x04
#define STATUS_PARAMETER_ERROR          0x05
#define STATUS_ACK                      0x06
#define STATUS_CHECKSUM_ERROR           0x07

#define CMD_WRITE_CFG_DATA      0xC4
#define CMD_READ_STATUS_DATA    0xC5
#define CMD_PLL_ON              0xC7
#define CMD_PLL_OFF             0xC8
#define CMD_RESET               0xC9

unsigned char Uart_TX_Buff[512];
unsigned char Uart_RX_Buff[512];
u32 STM_HOST_CMD_ASK = 0;
u32 STM_HOST_CMD_GET = 0;
unsigned char STM_HOST_CMD_data_Buff[64];
u32 Uart_RX_Num=0;


void STM_HOST_CMD_Get(void)
{
	u32 i;
	u32 CheckSm=0;
	if(Uart_RX_Buff[0]!=PACKAGE_SOH)
	{
		STM_HOST_CMD_ASK = STATUS_COMMAND_NUMBER_ERROR;
		return;
	}
	if((Uart_RX_Num<5)||(Uart_RX_Num>48))
	{
		STM_HOST_CMD_ASK = STATUS_COMMAND_NUMBER_ERROR;
		return;
	}
	if(Uart_RX_Buff[1]!=(Uart_RX_Num-4))
	{
		STM_HOST_CMD_ASK = STATUS_PARAMETER_ERROR;
		return;
	}
	if(Uart_RX_Buff[Uart_RX_Num-1]!=PACKAGE_ETX)
	{
		STM_HOST_CMD_ASK = STATUS_PARAMETER_ERROR;
		return;
	}
	if((Uart_RX_Buff[2]<0xC4)||(Uart_RX_Buff[2]>0xC9))
	{
		STM_HOST_CMD_ASK = STATUS_NACK;
		return;
	}
	for(i=1;i<(Uart_RX_Num-2);i++)
	{
		CheckSm -= Uart_RX_Buff[i];
	}
	if(Uart_RX_Buff[Uart_RX_Num-2]!=(CheckSm&0xFF))
	{
		STM_HOST_CMD_ASK = STATUS_CHECKSUM_ERROR;
		return;
	}
	STM_HOST_CMD_GET = Uart_RX_Buff[2];
	if(Uart_RX_Buff[1]>1)
	for(i=0;i<Uart_RX_Buff[1]-1;i++)
	{
		STM_HOST_CMD_data_Buff[i] = Uart_RX_Buff[3+i];
	}
	STM_HOST_CMD_ASK = STATUS_ACK;
}

void Uart1_Handler(void *CallBackRef)
{
	u32 IsrStatus;
	u32 RX_Num;

	IsrStatus =  XUartPs_ReadReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_IMR_OFFSET);
	IsrStatus &= XUartPs_ReadReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_ISR_OFFSET);

	if((IsrStatus & (u32)XUARTPS_IXR_RXOVR)!=0)
	{
		XUartPs_WriteReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_ISR_OFFSET, XUARTPS_IXR_RXOVR);
		RX_Num=XUartPs_Recv(&XUartPs_uart1,&Uart_RX_Buff[Uart_RX_Num],512-Uart_RX_Num);
		Uart_RX_Num+=RX_Num;
	}
	if((IsrStatus & (u32)XUARTPS_IXR_TOUT)!=0)
	{
		XUartPs_WriteReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_ISR_OFFSET, XUARTPS_IXR_TOUT);
		RX_Num=XUartPs_Recv(&XUartPs_uart1,&Uart_RX_Buff[Uart_RX_Num],512-Uart_RX_Num);
		Uart_RX_Num+=RX_Num;
		//for(IsrStatus=0;IsrStatus<Uart_RX_Num;IsrStatus++)XUartPs_SendByte(XUartPs_uart0.Config.BaseAddress,Uart_RX_Buff[IsrStatus]);
		STM_HOST_CMD_Get();
		Uart_RX_Num=0;
	}
}

void Uart1PS_Init(void)
{
	XUartPs_Config *XUartPs_Config_uart1;
	XUartPsFormat XUartPsFormat_uart1;

	XScuGic_Config *XScuGic_Config_ps;

	int status;

	XUartPs_Config_uart1 = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);//获得串口1配置信息
	status = XUartPs_CfgInitialize(&XUartPs_uart1,XUartPs_Config_uart1,XUartPs_Config_uart1->BaseAddress);
	if(status != XST_SUCCESS)
	{
		print("Initialize uart1 fail\n");
	}
	XUartPs_SetOperMode(&XUartPs_uart1, XUARTPS_OPER_MODE_NORMAL);
	XUartPsFormat_uart1.BaudRate = 921600;//波特率921600
	XUartPsFormat_uart1.DataBits = XUARTPS_FORMAT_8_BITS;
	XUartPsFormat_uart1.Parity = XUARTPS_FORMAT_NO_PARITY;
	XUartPsFormat_uart1.StopBits = XUARTPS_FORMAT_1_STOP_BIT;
	status = XUartPs_SetDataFormat(&XUartPs_uart1,&XUartPsFormat_uart1);
	if(status != XST_SUCCESS)
	{
		print("set Buad Rate fail\n");
	}
	XUartPs_SetFifoThreshold(&XUartPs_uart1,32);
	XUartPs_SetRecvTimeout(&XUartPs_uart1,4);//4*4=16 timeout IXR
	XUartPs_SetInterruptMask(&XUartPs_uart1,XUARTPS_IXR_RXOVR|XUARTPS_IXR_TOUT);//开中断

	//XScuGic_Config_ps = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
	//XScuGic_CfgInitialize(&XPS_XScuGic,XScuGic_Config_ps,XScuGic_Config_ps->CpuBaseAddress);

	//Xil_ExceptionInit();
	//Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,(Xil_ExceptionHandler)XScuGic_InterruptHandler,(void *)&XPS_XScuGic);
	//Xil_ExceptionEnable();

	XScuGic_Disable(&XPS_XScuGic,XPS_UART1_INT_ID);
	//XScuGic_SetPriorityTriggerType(&XPS_XScuGic,XPS_UART0_INT_ID,16,1);
	XScuGic_Connect(&XPS_XScuGic,XPS_UART1_INT_ID,(Xil_ExceptionHandler)Uart1_Handler,(void *)&XUartPs_uart1);//入口
	XScuGic_Enable(&XPS_XScuGic,XPS_UART1_INT_ID);

	Uart_RX_Num=0;
}

//unsigned char PLL_Lock_Status = 0;

void STM_HOST_ASK_Status(uint8_t ASK)
{
	u32 CheckSm=0,i;
	Uart_TX_Buff[0] = PACKAGE_STX;
	Uart_TX_Buff[1] = 1;
	Uart_TX_Buff[2] = ASK;
	CheckSm -= 1+ASK;
	Uart_TX_Buff[3] = CheckSm&0xFF;
	Uart_TX_Buff[4] = PACKAGE_ETX;
	for(i=0;i<5;i++)XUartPs_SendByte(XUartPs_uart1.Config.BaseAddress,Uart_TX_Buff[i]);
}
void STM_HOST_Respond_Data(void)
{
	u32 CheckSm=0,i,data;
	Uart_TX_Buff[0] = PACKAGE_STX;
	Uart_TX_Buff[1] = 12;
	Uart_TX_Buff[2] = STATUS_ACK;
	i = Xil_In32(System_Statue);
	//if((i&0x50)==0x10)data = i&0x3F;
	//else data = i&0x2F;
	data = i&0x3F;
	Uart_TX_Buff[3] = PLL_Lock_Status|data;
	i = Xil_In32(DDC0_inst_frequency);
	Uart_TX_Buff[4] = (i>>0)&0xFF;
	Uart_TX_Buff[5] = (i>>8)&0xFF;
	i = Xil_In32(PLL0_phase_residuals);
	Uart_TX_Buff[6] = i&0xFF;
	Uart_TX_Buff[7] = (i>>8)&0xFF;
	Uart_TX_Buff[8] = (i>>16)&0xFF;
	Uart_TX_Buff[9] = (i>>24)&0xFF;
	//i = Xil_In32(PLL0_Output_Limit);
	i = Xil_In32(PLL0_Output_Limit_Average);
	Uart_TX_Buff[10] = i&0xFF;
	Uart_TX_Buff[11] = (i>>8)&0xFF;
	Uart_TX_Buff[12] = (i>>16)&0xFF;
	Uart_TX_Buff[13] = (i>>24)&0xFF;
	for(i=1;i<14;i++)CheckSm -= Uart_TX_Buff[i];
	Uart_TX_Buff[14] = CheckSm&0xFF;
	Uart_TX_Buff[15] = PACKAGE_ETX;
	for(i=0;i<16;i++)XUartPs_SendByte(XUartPs_uart1.Config.BaseAddress,Uart_TX_Buff[i]);
}

static uint8_t STM_HOST_Write_PLL_Data(void)
{
	u32 data;
	Xil_Out32(DAC0_Centre_Frequency_Addr,*((uint32_t*)&STM_HOST_CMD_data_Buff[0]));//中心频率
	Xil_Out32(VOC_Fre_Mul_Addr,*((uint16_t*)&STM_HOST_CMD_data_Buff[4]));//MUL
	Xil_Out32(VOC_Fre_Div_Addr,*((uint16_t*)&STM_HOST_CMD_data_Buff[6]));//DIV
    Xil_Out32(DPLL_PLL_KP_TRACK_Addr,*((uint32_t*)&STM_HOST_CMD_data_Buff[8]));
    Xil_Out32(DPLL_PLL_KI_TRACK_Addr,*((uint32_t*)&STM_HOST_CMD_data_Buff[12]));
    Xil_Out32(DPLL_FLL_KF_ACQUIRE_Addr,*((uint32_t*)&STM_HOST_CMD_data_Buff[16]));
    Xil_Out32(DPLL_FLL_KF_BLEND_Addr,*((uint32_t*)&STM_HOST_CMD_data_Buff[20]));
    data = *((uint16_t*)&STM_HOST_CMD_data_Buff[24]);
    Xil_Out32(DPLL_FREQ_POS_LIMIT_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit
    data = *((uint16_t*)&STM_HOST_CMD_data_Buff[26]);
    Xil_Out32(DPLL_FREQ_NEG_LIMIT_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit
    Xil_Out32(DAC0_Freq_Residuals_Threshold_Addr,*((uint16_t*)&STM_HOST_CMD_data_Buff[28]));//14Bit
    Xil_Out32(DAC0_Phase_Residuals_Threshold_Addr,*((uint16_t*)&STM_HOST_CMD_data_Buff[30]));//32Bit
    Xil_Out32(DAC0_VOC_Amplitude_Addr,*((uint16_t*)&STM_HOST_CMD_data_Buff[32]));//amplitude 15bit;
    return (dpll_apply_config() == 0) ? STATUS_ACK : STATUS_NACK;
}
void STM_HOST_CMD_Respond(void)
{
	uint8_t action_status;

	if(STM_HOST_CMD_ASK)
	{
		usleep(200);
		if(STM_HOST_CMD_ASK == STATUS_ACK)
		{
			//printf("C:%X\n",(u32)STM_HOST_CMD_ASK);
			action_status = STATUS_ACK;
			switch(STM_HOST_CMD_GET)
			{
			case CMD_WRITE_CFG_DATA:
				action_status = STM_HOST_Write_PLL_Data();
				break;
			case CMD_READ_STATUS_DATA:
				usleep(100);
				STM_HOST_Respond_Data();
				action_status = 0;
				break;
			case CMD_PLL_ON:
				action_status = (dpll_set_enable(1) == 0) ? STATUS_ACK : STATUS_NACK;
				break;
			case CMD_PLL_OFF:
				action_status = (dpll_set_enable(0) == 0) ? STATUS_ACK : STATUS_NACK;
				break;
			case CMD_RESET:
				Xil_Out32(Opal_Kelly_Reset_Trigger_Addr,0);
				dpll_invalidate_abi();
				action_status = dpll_initialize_abi() ? STATUS_ACK : STATUS_NACK;
				break;
			}
			if (action_status != 0) {
				STM_HOST_ASK_Status(action_status);
			}
		}
		else
		{
			STM_HOST_ASK_Status(STM_HOST_CMD_ASK);
		}
		STM_HOST_CMD_ASK = 0;
	}
}
int main()
{
init_platform();

    XPS_Core_init();
    Uart0PS_Init();
    Uart1PS_Init();

    Xil_Out32(Opal_Kelly_Reset_Trigger_Addr,0);//rst;
    if (!dpll_initialize_abi()) return -1;
    dpll_set_enable(0);
    Xil_Out32(DAC0_VCO_Offset_Addr,0);//offset 14bit;
    Xil_Out32(DAC0_VOC_Amplitude_Addr,0x7fff);//amplitude 15bit;
    //Xil_Out32(DAC0_VOC_Amplitude_Addr,0x0001);//amplitude 15bit;
    Xil_Out32(DAC0_Centre_Frequency_Addr,0x051EB851);//中心频率 120KHz@fs=3.125MHz

    Xil_Out32(DAC0_DDC_Angle_Select_Addr,0);//wrapped_phase_cordic

//    Xil_Out32(DPLL_DEBUG_DAC_OFFSET_ADDR,0);//offset 14bit;
//    Xil_Out32(DPLL_DEBUG_DAC_GAIN_ADDR,0x7fff);//amplitude 15bit;
//    //Xil_Out32(DPLL_DEBUG_DAC_SOURCE_ADDR,0x03126E97);//Fre 31bit; 1.5Mhz
//    //Xil_Out32(DPLL_DEBUG_DAC_SOURCE_ADDR,0x0020C49B);//Fre 31bit; 125KHz
//    Xil_Out32(DPLL_DEBUG_DAC_SOURCE_ADDR,0x00418000);//Fre 31bit; 125KHz
//    Xil_Out32(DPLL_DEBUG_DAC_FORMAT_ADDR,0x0);//Phase 32bit

    Xil_Out32(DPLL_FREQ_POS_LIMIT_Addr,0x7FFFFFFE);//32Bit
    Xil_Out32(DPLL_FREQ_NEG_LIMIT_Addr,0x80000001);//32Bit
    Xil_Out32(VCO_Freq_Manual_Offset_Addr,0);//offset 10bit;
    Xil_Out32(VOC_Fre_Mul_Addr,1);//mul 16bit;
    Xil_Out32(VOC_Fre_Div_Addr,1);//div 16bit;

    Xil_Out32(DAC0_Freq_Residuals_Threshold_Addr,100);//14Bit
    Xil_Out32(DAC0_Phase_Residuals_Threshold_Addr,1000);//32Bit
    Xil_Out32(DAC0_Phase_Residuals_Offset_Addr,0);//32Bit

    Xil_Out32(DPLL_PLL_KP_TRACK_Addr,40000);
    Xil_Out32(DPLL_PLL_KI_TRACK_Addr,117200);
    Xil_Out32(DPLL_FLL_KF_ACQUIRE_Addr,78900);//减少残差 加快最后的慢收敛
    Xil_Out32(DPLL_FLL_KF_BLEND_Addr,100000);
    //Xil_Out32(DPLL_FLL_KF_TRACK_Addr,0x0ffff);//DPLL_KF_TRACK[23:0]
    Xil_Out32(DPLL_FLL_KF_TRACK_Addr,0x0002F);//DPLL_KF_TRACK[23:0]



    Xil_Out32(DPLL_PLL_KP_BLEND_Addr,40000);
    Xil_Out32(DPLL_PLL_KI_BLEND_Addr,117200);
    Xil_Out32(DPLL_MAG_ENTER_THRESHOLD_Addr,16384);
    Xil_Out32(DPLL_MAG_EXIT_THRESHOLD_Addr,8192);
    Xil_Out32(DPLL_ACQUIRE_DWELL_Addr,16);
    Xil_Out32(DPLL_BLEND_DWELL_Addr,16);
    Xil_Out32(DPLL_LOSS_DWELL_Addr,16);
    Xil_Out32(DPLL_HOLDOVER_TIMEOUT_Addr,1250000);
    Xil_Out32(DPLL_MEASUREMENT_TIMEOUT_Addr,0);
    Xil_Out32(DPLL_POST_IQ_CIC_R_Addr,31);
    Xil_Out32(DPLL_POST_IQ_CIC_SHIFT_Addr,10);
    Xil_Out32(DPLL_FLL_DELAY_SEL_Addr,2);
    Xil_Out32(DPLL_WARMUP_SAMPLES_Addr,64);
    Xil_Out32(DPLL_POST_IIR_CONFIG_Addr,3);
    Xil_Out32(DPLL_POST_IIR_ACQ_B0_Addr,138975519);
    Xil_Out32(DPLL_POST_IIR_ACQ_B1_Addr,277951039);
    Xil_Out32(DPLL_POST_IIR_ACQ_B2_Addr,138975519);
    Xil_Out32(DPLL_POST_IIR_ACQ_A1_Addr,0xCF8C92D0);
    Xil_Out32(DPLL_POST_IIR_ACQ_A2_Addr,295031213);
    Xil_Out32(DPLL_POST_IIR_TRACK_B0_Addr,48851600);
    Xil_Out32(DPLL_POST_IIR_TRACK_B1_Addr,97703199);
    Xil_Out32(DPLL_POST_IIR_TRACK_B2_Addr,48851600);
    Xil_Out32(DPLL_POST_IIR_TRACK_A1_Addr,0xABFE403C);
    Xil_Out32(DPLL_POST_IIR_TRACK_A2_Addr,531065347);
    if (dpll_apply_config() != 0) return -1;

    Xil_Out32(Freq_Meter_Reset_Trigger_Addr,0);//rst;
    Xil_Out32(Freq_Meter_Lock_Ctrl_Addr,0);

    Xil_Out32(Freq_Meter_Centre_Frequency_Addr,0x51EB851E); //40MHz
    //Xil_Out32(Freq_Meter_Centre_Frequency_Addr,0x51F12345); //40MHz test

    Xil_Out32(Freq_Meter_PID_GainP_Addr,0x00400000);
    Xil_Out32(Freq_Meter_PID_GainI_Addr,0x00100000);
    Xil_Out32(Freq_Meter_PID_GainI2_Addr,0x00000100);
    Xil_Out32(Freq_Meter_PID_GainD_Addr,0);
    Xil_Out32(Freq_Meter_Coefd_Filter_Addr,0x0FFFF);
    Xil_Out32(Freq_Meter_Freq_Pos_Limit_Addr,0x4Fffffff);
    Xil_Out32(Freq_Meter_Freq_Neg_Limit_Addr,0xB0000000);
    Xil_Out32(Freq_Meter_Freq_Manual_Offset_Addr,0);
    Xil_Out32(Freq_Meter_Gate_Time_H_Addr,0);

    Xil_Out32(Freq_Meter_Phase_Residuals_Threshold_Addr,1000);
    Xil_Out32(Freq_Meter_Phase_Residuals_Offset_Addr,0);
    Xil_Out32(Freq_Meter_Freq_Residuals_Threshold_Addr,500);
	usleep(50);

    // Keep the legacy frequency-meter PLL disabled; the single DPLL lives at DPLL_BASE_ADDR.
    Xil_Out32(Freq_Meter_Lock_Ctrl_Addr,0);

    XUartPs_SendByte(XUartPs_uart0.Config.BaseAddress,'C');


    while(1)
    {
    	STM_HOST_CMD_Respond();
    	PC_HOST_CMD_Respond();
        //STM_HOST_ASK_Status(0x06);
    	//print("hello\n");
    	//usleep(1000);
    }
    cleanup_platform();
    return 0;
}
