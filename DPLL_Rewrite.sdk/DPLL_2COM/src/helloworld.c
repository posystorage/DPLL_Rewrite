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
#include <string.h>
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
#include "control_protocol.h"



XUartPs XUartPs_uart0;
XUartPs XUartPs_uart1;
XScuGic XPS_XScuGic;
uint8_t PLL_Lock_Status;

static uint8_t Control_Bank[CTRL_BANK_SIZE];

static uint8_t Control_Link_Startup(void);
static void Control_Link_Service(void);
static uint8_t Control_Apply_Persistent(const uint8_t *data);
static uint8_t Control_Save_Active(void);
static uint8_t control_restore_persistent(const uint8_t *previous,
		uint8_t original_error, uint8_t sync_bridge);
static uint8_t Control_Set_MWS_Enable(uint8_t enable);
static uint8_t Control_Set_DPLL_Enable(uint8_t enable);
static void Control_Reset_Both(void);
static void control_put_u32(uint8_t offset, uint32_t value);
static uint8_t control_uart_write(uint8_t offset, uint8_t length, const uint8_t *data);
static uint8_t control_apply_bank(void);

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
#define PC_CMD_READ_FREQMETER_FAST_REFERENCE		0x1C
#define PC_CMD_READ_CONTROL_BANK			0x1D


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
#define PC_CMD_FREQMETER_FAST_INTERVAL		0x98
#define PC_CMD_APPLY_CONTROL_BANK		0x99
#define PC_CMD_VBIAS_WRITE_DAC	 			0x9A
#define PC_CMD_SAVE_CONTROL_BANK			0x9B

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

static int dpll_write_center_filter_profile(uint32_t center_word_hi)
{
	dpll_filter_profile_t profile;
	dpll_profile_validation_t validation;
	const char *support_name;
	int status;

	dpll_driver_ensure_initialized();
	status = dpll_compute_filter_profile_checked(center_word_hi, &profile, &validation);
	if (status != DPLL_DRIVER_OK) {
		xil_printf("DPLL profile rejected center_word=0x%08lx errors=0x%08lx\r\n",
		           (unsigned long)center_word_hi,
		           (unsigned long)validation.errors);
		return DPLL_DRIVER_ERR_VERIFY;
	}
	status = dpll_driver_stage_profile(&dpll_driver, center_word_hi,
	                                   &profile, &validation);
	if (status != DPLL_DRIVER_OK) return status;

	support_name = profile.support == DPLL_PROFILE_SUPPORT_VERIFIED ? "verified" :
	               profile.support == DPLL_PROFILE_SUPPORT_STANDARD ? "standard" :
	               "extended-unverified";
	xil_printf("DPLL profile center=%luHz support=%s limit=+/-20%% R=%u shift=%u L=%u image=%luHz acq=%luHz track=%luHz\r\n",
	           (unsigned long)profile.center_hz,
	           support_name,
	           (unsigned int)profile.cic_r,
	           (unsigned int)profile.cic_shift,
	           (unsigned int)(1U << profile.fll_delay_sel),
	           (unsigned long)profile.mirror_alias_hz,
	           (unsigned long)profile.acquire_cutoff_hz,
	           (unsigned long)profile.track_cutoff_hz);
	return DPLL_DRIVER_OK;
}
void PC_HOST_CMD_Get(void);

void Uart0_Handler(void *CallBackRef)
{
	u32 IsrStatus;
	u32 RX_Num;
	(void)CallBackRef;

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
	if(((Uart0_RX_Buff[2]<0x80)&&(Uart0_RX_Buff[2]>0x1D))||(Uart0_RX_Buff[2]>0x9B))
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
	Uart0_TX_Buff[4] = CTRL_PROTOCOL_VERSION;
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

void CMD_1C_READ_FREQMETER_FAST_REFERENCE(void)
{
	uint32_t status_before;
	uint32_t status_after;
	uint32_t data_l;
	uint32_t data_m;
	uint32_t data_h;
	uint32_t result_interval;
	uint32_t retry_count = 0;

	do {
		status_before = Xil_In32(Freq_Meter_Fast_Status_Addr);
		data_l = Xil_In32(Freq_Meter_Fast_DataL_Output_Addr);
		data_m = Xil_In32(Freq_Meter_Fast_DataM_Output_Addr);
		data_h = Xil_In32(Freq_Meter_Fast_DataH_Output_Addr);
		result_interval = Xil_In32(Freq_Meter_Fast_Result_Interval_Addr);
		status_after = Xil_In32(Freq_Meter_Fast_Status_Addr);
		retry_count++;
	} while ((status_before != status_after) && (retry_count < 4U));

	pc_put_u32(4, status_after);
	pc_put_u32(8, data_l);
	pc_put_u32(12, data_m);
	Uart0_TX_Buff[16] = data_h & 0xFFU;
	Uart0_TX_Buff[17] = (data_h >> 8) & 0xFFU;
	pc_put_u32(18, result_interval);
	pc_put_u32(22, Xil_In32(Freq_Meter_Fast_Interval_Addr));

	PC_HOST_ASK_Pack(22);
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
	Xil_Out32(Freq_Meter_Centre_Frequency_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[4]));//中心频率
	PC_HOST_Send_ASK_Only(0);
}
void CMD_91_WRITE_FREQMETER_THRESHOLD(void)
{
    Xil_Out32(Freq_Meter_Freq_Residuals_Threshold_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[4]));//14Bit
    Xil_Out32(Freq_Meter_Phase_Residuals_Threshold_Addr,*((uint16_t*)&PC_HOST_CMD_data_Buff[6]));//32Bit
	PC_HOST_Send_ASK_Only(0);
}
void CMD_92_WRITE_FREQMETER_LIMIT(void)
{
	uint32_t data;

    //Xil_Out32(Freq_Meter_Freq_Pos_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit
    //Xil_Out32(Freq_Meter_Freq_Neg_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit

	data = *((uint16_t*)&PC_HOST_CMD_data_Buff[4]);
	if(data > 0x7FFF) data = 0x3FFF;
    Xil_Out32(Freq_Meter_Freq_Pos_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit

	data = *((uint16_t*)&PC_HOST_CMD_data_Buff[6]);
	if(data < 0xA000) data = 0xA000;
    Xil_Out32(Freq_Meter_Freq_Neg_Limit_Addr,data<<16);//上位机储存和传入参数为高16bit写入到FPGA内部为32Bit

	PC_HOST_Send_ASK_Only(0);
}
void CMD_93_WRITE_FREQMETER_PID(void)
{
    Xil_Out32(Freq_Meter_PID_GainP_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[4]));
    Xil_Out32(Freq_Meter_PID_GainI_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[8]));
    Xil_Out32(Freq_Meter_PID_GainI2_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[12]));
    Xil_Out32(Freq_Meter_PID_GainD_Addr,*((uint32_t*)&PC_HOST_CMD_data_Buff[16]));
	PC_HOST_Send_ASK_Only(0);
}
void CMD_94_WRITE_FREQMETER_TIMER(void)
{
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

void CMD_98_WRITE_FREQMETER_FAST_INTERVAL(void)
{
	uint8_t candidate[CTRL_PERSIST_END - CTRL_PERSIST_BEGIN];
	uint8_t status;
	uint16_t interval_ms;
	uint8_t index = CTRL_REG_FAST_INTERVAL_MS - CTRL_PERSIST_BEGIN;

	if (pc_payload_len() != 2U) {
		PC_HOST_Send_ASK_Only(0xF2);
		return;
	}
	interval_ms = pc_get_u16(4);
	if (interval_ms < CTRL_FAST_INTERVAL_MIN_MS ||
	    interval_ms > CTRL_FAST_INTERVAL_MAX_MS) {
		PC_HOST_Send_ASK_Only(CTRL_ERROR_RANGE);
		return;
	}
	memcpy(candidate, &Control_Bank[CTRL_PERSIST_BEGIN], sizeof(candidate));
	candidate[index] = (uint8_t)interval_ms;
	candidate[index + 1U] = (uint8_t)(interval_ms >> 8);
	status = Control_Apply_Persistent(candidate);
	PC_HOST_Send_ASK_Only(status);
}

void CMD_1D_READ_CONTROL_BANK(void)
{
	memcpy(&Uart0_TX_Buff[4], Control_Bank, CTRL_BANK_SIZE);
	PC_HOST_ASK_Pack(CTRL_BANK_SIZE);
}

void CMD_81_WRITE_MWS_FREQ_PWR(void)
{
	uint32_t frequency_khz;
	if (pc_payload_len() < 5U) {
		PC_HOST_Send_ASK_Only(0xF2);
		return;
	}
	frequency_khz = pc_get_u32(4);
	if (frequency_khz < CTRL_MWS_FREQ_MIN_KHZ ||
	    frequency_khz > CTRL_MWS_FREQ_MAX_KHZ) {
		PC_HOST_Send_ASK_Only(CTRL_ERROR_RANGE);
		return;
	}
	control_put_u32(CTRL_REG_MWS_FREQ_KHZ, frequency_khz);
	Control_Bank[CTRL_REG_MWS_POWER] = PC_HOST_CMD_data_Buff[8] & 0x03U;
	PC_HOST_Send_ASK_Only(control_uart_write(CTRL_REG_MWS_FREQ_KHZ, 5U,
	                                           &Control_Bank[CTRL_REG_MWS_FREQ_KHZ]) ? 0U :
	                                           CTRL_ERROR_PROTOCOL);
}

void CMD_99_APPLY_CONTROL_BANK(void)
{
	uint8_t status;
	if (pc_payload_len() != (CTRL_PERSIST_END - CTRL_PERSIST_BEGIN)) {
		PC_HOST_Send_ASK_Only(0xF2);
		return;
	}
	status = Control_Apply_Persistent(&PC_HOST_CMD_data_Buff[4]);
	PC_HOST_Send_ASK_Only(status);
}

void CMD_9B_SAVE_CONTROL_BANK(void)
{
	PC_HOST_Send_ASK_Only(Control_Save_Active() ? 0U : CTRL_ERROR_PROTOCOL);
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
			case PC_CMD_READ_FREQMETER_FAST_REFERENCE:
				CMD_1C_READ_FREQMETER_FAST_REFERENCE();
				break;
			case PC_CMD_READ_CONTROL_BANK:
				CMD_1D_READ_CONTROL_BANK();
				break;
//			case PC_CMD_VBIAS_READ_DAC:
//				CMD_1A_READ_VBIAS_DAC();
//				break;
//			case PC_CMD_VBIAS_READ_ADC:
//				CMD_1B_READ_VBIAS_ADC();
//				break;


			case PC_CMD_WRITE_MWS_FREQ_PWR:
				CMD_81_WRITE_MWS_FREQ_PWR();
				break;
			case PC_CMD_WRITE_PLL_FREQ:
			case PC_CMD_WRITE_PLL_MUL_DIV:
			case PC_CMD_WRITE_PLL_THRESHOLD:
			case PC_CMD_WRITE_PLL_LIMIT:
			case PC_CMD_WRITE_DPLL_LOOP_BASIC:
			case PC_CMD_WRITE_PLL_AMP:
				PC_HOST_Send_ASK_Only(CTRL_ERROR_PROTOCOL);
				break;
			case PC_CMD_WRITE_MWS_ON:
				PC_HOST_Send_ASK_Only(Control_Set_MWS_Enable(1U) ? 0U : CTRL_ERROR_PROTOCOL);
				break;
			case PC_CMD_WRITE_MWS_OFF:
				PC_HOST_Send_ASK_Only(Control_Set_MWS_Enable(0U) ? 0U : CTRL_ERROR_PROTOCOL);
				break;
			case PC_CMD_WRITE_PLL_ON:
				PC_HOST_Send_ASK_Only(Control_Set_DPLL_Enable(1U) ? 0U : CTRL_ERROR_APPLY);
				break;
			case PC_CMD_WRITE_PLL_OFF:
				PC_HOST_Send_ASK_Only(Control_Set_DPLL_Enable(0U) ? 0U : CTRL_ERROR_APPLY);
				break;
//			case PC_CMD_LOAD_EEPROM:
//				CMD_8C_LOAD_EEPROM();
//				break;
//			case PC_CMD_SAVE_EEPROM:
//				CMD_8D_SAVE_EEPROM();
//				break;
			case PC_CMD_PLL_RESET:
				Control_Reset_Both();
				dpll_invalidate_abi();
				if (dpll_initialize_abi() && control_apply_bank()) {
					PC_HOST_Send_ASK_Only(0U);
				} else {
					PC_HOST_Send_ASK_Only(PC_ERR_DPLL_ABI_MISMATCH);
				}
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
			case PC_CMD_FREQMETER_FAST_INTERVAL:
				CMD_98_WRITE_FREQMETER_FAST_INTERVAL();
				break;
			case PC_CMD_APPLY_CONTROL_BANK:
				CMD_99_APPLY_CONTROL_BANK();
				break;
			case PC_CMD_SAVE_CONTROL_BANK:
				CMD_9B_SAVE_CONTROL_BANK();
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




/*********************************UART1  STM8 CONTROL BANK****************************/

#define CONTROL_UART_BUFFER_SIZE       128U
#define CONTROL_UART_TIMEOUT_LOOPS     1000U
#define CONTROL_SERVICE_PERIOD_LOOPS   50U

static volatile uint8_t Control_Uart_RX[CONTROL_UART_BUFFER_SIZE];
static volatile uint32_t Control_Uart_RX_Count;
static volatile uint8_t Control_Uart_Frame_Ready;
static uint8_t Control_Uart_TX[CONTROL_UART_BUFFER_SIZE];
static uint8_t Control_Request_Seen;
static uint8_t Control_DPLL_Enabled;
static uint8_t Control_Last_Error;
static uint32_t Control_Service_Divider;

static uint16_t control_get_u16(uint8_t offset)
{
	return (uint16_t)Control_Bank[offset] |
	       ((uint16_t)Control_Bank[offset + 1U] << 8);
}

static uint32_t control_get_u32(uint8_t offset)
{
	return (uint32_t)Control_Bank[offset] |
	       ((uint32_t)Control_Bank[offset + 1U] << 8) |
	       ((uint32_t)Control_Bank[offset + 2U] << 16) |
	       ((uint32_t)Control_Bank[offset + 3U] << 24);
}

static int32_t control_get_s32(uint8_t offset)
{
	return (int32_t)control_get_u32(offset);
}

static void control_put_u32(uint8_t offset, uint32_t value)
{
	Control_Bank[offset] = (uint8_t)value;
	Control_Bank[offset + 1U] = (uint8_t)(value >> 8);
	Control_Bank[offset + 2U] = (uint8_t)(value >> 16);
	Control_Bank[offset + 3U] = (uint8_t)(value >> 24);
}

static uint8_t control_checksum(const uint8_t *data, uint32_t length)
{
	uint32_t index;
	uint8_t sum = 0U;
	for (index = 0U; index < length; ++index) sum = (uint8_t)(sum + data[index]);
	return (uint8_t)(0U - sum);
}

void Uart1_Handler(void *CallBackRef)
{
	u32 isr_status;
	u32 received;
	(void)CallBackRef;

	isr_status = XUartPs_ReadReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_IMR_OFFSET);
	isr_status &= XUartPs_ReadReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_ISR_OFFSET);

	if ((isr_status & (u32)XUARTPS_IXR_RXOVR) != 0U) {
		XUartPs_WriteReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_ISR_OFFSET,
		                 XUARTPS_IXR_RXOVR);
		received = XUartPs_Recv(&XUartPs_uart1,
		                        (uint8_t *)&Control_Uart_RX[Control_Uart_RX_Count],
		                        CONTROL_UART_BUFFER_SIZE - Control_Uart_RX_Count);
		Control_Uart_RX_Count += received;
	}
	if ((isr_status & (u32)XUARTPS_IXR_TOUT) != 0U) {
		XUartPs_WriteReg(XUartPs_uart1.Config.BaseAddress, XUARTPS_ISR_OFFSET,
		                 XUARTPS_IXR_TOUT);
		received = XUartPs_Recv(&XUartPs_uart1,
		                        (uint8_t *)&Control_Uart_RX[Control_Uart_RX_Count],
		                        CONTROL_UART_BUFFER_SIZE - Control_Uart_RX_Count);
		Control_Uart_RX_Count += received;
		Control_Uart_Frame_Ready = 1U;
	}
}

void Uart1PS_Init(void)
{
	XUartPs_Config *config;
	XUartPsFormat format;
	int status;

	config = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
	status = XUartPs_CfgInitialize(&XUartPs_uart1, config, config->BaseAddress);
	if (status != XST_SUCCESS) print("Initialize uart1 fail\n");

	XUartPs_SetOperMode(&XUartPs_uart1, XUARTPS_OPER_MODE_NORMAL);
	/* STM8 uses the verified original 16 MHz / 1 Mbps UART configuration. */
	format.BaudRate = 1000000;
	format.DataBits = XUARTPS_FORMAT_8_BITS;
	format.Parity = XUARTPS_FORMAT_NO_PARITY;
	format.StopBits = XUARTPS_FORMAT_1_STOP_BIT;
	status = XUartPs_SetDataFormat(&XUartPs_uart1, &format);
	if (status != XST_SUCCESS) print("set uart1 baud rate fail\n");

	XUartPs_SetFifoThreshold(&XUartPs_uart1, 32);
	XUartPs_SetRecvTimeout(&XUartPs_uart1, 4);
	XUartPs_SetInterruptMask(&XUartPs_uart1, XUARTPS_IXR_RXOVR | XUARTPS_IXR_TOUT);
	XScuGic_Disable(&XPS_XScuGic, XPS_UART1_INT_ID);
	XScuGic_Connect(&XPS_XScuGic, XPS_UART1_INT_ID,
	                (Xil_ExceptionHandler)Uart1_Handler, (void *)&XUartPs_uart1);
	XScuGic_Enable(&XPS_XScuGic, XPS_UART1_INT_ID);
	Control_Uart_RX_Count = 0U;
	Control_Uart_Frame_Ready = 0U;
}

static uint8_t Control_Uart_Transaction(uint8_t command, uint8_t offset,
		uint8_t length, const uint8_t *write_data, uint8_t *read_data)
{
	uint32_t index;
	uint32_t tx_length;
	uint32_t expected;
	uint32_t wait_loop;
	uint8_t response_length;
	uint8_t checksum;

	Control_Uart_TX[0] = CTRL_UART_REQ;
	Control_Uart_TX[1] = command;
	Control_Uart_TX[2] = offset;
	Control_Uart_TX[3] = length;
	tx_length = 4U;
	if (command == CTRL_UART_CMD_WRITE) {
		for (index = 0U; index < length; ++index) Control_Uart_TX[tx_length++] = write_data[index];
	}
	Control_Uart_TX[tx_length] = control_checksum(&Control_Uart_TX[1], tx_length - 1U);
	Control_Uart_TX[tx_length + 1U] = CTRL_UART_ETX;
	tx_length += 2U;

	Control_Uart_RX_Count = 0U;
	Control_Uart_Frame_Ready = 0U;
	for (index = 0U; index < tx_length; ++index)
		XUartPs_SendByte(XUartPs_uart1.Config.BaseAddress, Control_Uart_TX[index]);

	for (wait_loop = 0U; wait_loop < CONTROL_UART_TIMEOUT_LOOPS; ++wait_loop) {
		if (Control_Uart_Frame_Ready != 0U) break;
		usleep(100U);
	}
	if (Control_Uart_Frame_Ready == 0U || Control_Uart_RX_Count < 5U) return 0U;
	if (Control_Uart_RX[0] != CTRL_UART_RESP) return 0U;
	response_length = Control_Uart_RX[2];
	expected = (uint32_t)response_length + 5U;
	if (Control_Uart_RX_Count != expected || Control_Uart_RX[expected - 1U] != CTRL_UART_ETX)
		return 0U;
	checksum = control_checksum((const uint8_t *)&Control_Uart_RX[1],
	                            (uint32_t)response_length + 2U);
	if (Control_Uart_RX[3U + response_length] != checksum ||
	    Control_Uart_RX[1] != CTRL_UART_STATUS_OK) return 0U;

	if (command == CTRL_UART_CMD_READ) {
		if (response_length != length || read_data == 0) return 0U;
		for (index = 0U; index < length; ++index) read_data[index] = Control_Uart_RX[3U + index];
	} else if (command == CTRL_UART_CMD_PING) {
		if (response_length != 1U || read_data == 0) return 0U;
		read_data[0] = Control_Uart_RX[3];
	} else if (response_length != 0U) {
		return 0U;
	}
	return 1U;
}

static uint8_t control_uart_read(uint8_t offset, uint8_t length, uint8_t *data)
{
	return Control_Uart_Transaction(CTRL_UART_CMD_READ, offset, length, 0, data);
}

static uint8_t control_uart_write(uint8_t offset, uint8_t length, const uint8_t *data)
{
	return Control_Uart_Transaction(CTRL_UART_CMD_WRITE, offset, length, data, 0);
}

static int32_t control_div_round_signed(int64_t numerator, int64_t denominator)
{
	if (numerator >= 0) return (int32_t)((numerator + denominator / 2) / denominator);
	return (int32_t)(-((-numerator + denominator / 2) / denominator));
}

static uint32_t control_center_word(uint32_t frequency_dhz)
{
	return (uint32_t)(((uint64_t)frequency_dhz * 0x100000000ULL + 625000000ULL) /
	                  1250000000ULL);
}

static int32_t control_limit_word(int32_t frequency_hz)
{
	return control_div_round_signed((int64_t)frequency_hz * 0x100000000LL,
	                                125000000LL);
}

static uint32_t control_phase_raw(uint16_t centidegrees)
{
	return ((uint32_t)centidegrees * 262144UL + 18000UL) / 36000UL;
}

static uint32_t control_frequency_raw(uint16_t frequency_hz)
{
	return ((uint64_t)frequency_hz * 67108864ULL + 1562500ULL) / 3125000ULL;
}

static uint32_t control_amplitude_raw(uint16_t millivolts)
{
	return ((uint32_t)millivolts * 32767UL + 1000UL) / 2000UL;
}

static uint8_t control_output_ratio_valid(uint32_t center_dhz,
		uint16_t multiplier, uint16_t divider)
{
	if (multiplier == 0U || divider == 0U) return 0U;
	return (uint64_t)center_dhz * multiplier <=
	       (uint64_t)CTRL_DPLL_OUTPUT_MAX_DHZ * divider;
}

static uint8_t control_validate_bank(void)
{
	uint32_t center = control_get_u32(CTRL_REG_CENTER_FREQ_DHZ);
	uint32_t microwave_khz = control_get_u32(CTRL_REG_MWS_FREQ_KHZ);
	int32_t positive_limit = control_get_s32(CTRL_REG_POS_LIMIT_HZ);
	int32_t negative_limit = control_get_s32(CTRL_REG_NEG_LIMIT_HZ);
	if (Control_Bank[CTRL_REG_ID] != 0xA5U ||
	    Control_Bank[CTRL_REG_PROTOCOL_VERSION] != CTRL_PROTOCOL_VERSION) return 0U;
	if (microwave_khz < CTRL_MWS_FREQ_MIN_KHZ ||
	    microwave_khz > CTRL_MWS_FREQ_MAX_KHZ) return 0U;
	if (center < 40000UL || center > 1250000UL) return 0U;
	if (!control_output_ratio_valid(center,
	                                control_get_u16(CTRL_REG_OUTPUT_MUL),
	                                control_get_u16(CTRL_REG_OUTPUT_DIV))) return 0U;
	if (control_get_u32(CTRL_REG_KP_TRACK) > 0x007FFFFFUL ||
	    control_get_u32(CTRL_REG_KI_TRACK) > 0x007FFFFFUL ||
	    control_get_u32(CTRL_REG_KF_ACQUIRE) > 0x007FFFFFUL ||
	    control_get_u32(CTRL_REG_KF_BLEND) > 0x007FFFFFUL) return 0U;
	if (positive_limit < 0 || negative_limit > 0) return 0U;
	if (control_get_u16(CTRL_REG_PHASE_THRESHOLD_CDEG) > 18000U ||
	    control_get_u16(CTRL_REG_DAC_AMPLITUDE_MV) > 2000U ||
	    control_get_u16(CTRL_REG_FAST_INTERVAL_MS) < CTRL_FAST_INTERVAL_MIN_MS ||
	    control_get_u16(CTRL_REG_FAST_INTERVAL_MS) > CTRL_FAST_INTERVAL_MAX_MS) return 0U;
	return 1U;
}

static uint8_t control_apply_bank(void)
{
	uint32_t center_word;
	uint32_t interval_cycles;
	int apply_status;
	if (!control_validate_bank()) {
		Control_Last_Error = CTRL_ERROR_RANGE;
		dpll_set_enable(0U);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}

	center_word = control_center_word(control_get_u32(CTRL_REG_CENTER_FREQ_DHZ));
	if (dpll_write_center_filter_profile(center_word) != DPLL_DRIVER_OK) {
		Control_Last_Error = CTRL_ERROR_APPLY;
		dpll_set_enable(0U);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}

	Xil_Out32(VOC_Fre_Mul_Addr, control_get_u16(CTRL_REG_OUTPUT_MUL));
	Xil_Out32(VOC_Fre_Div_Addr, control_get_u16(CTRL_REG_OUTPUT_DIV));
	Xil_Out32(DPLL_PLL_KP_TRACK_Addr, control_get_u32(CTRL_REG_KP_TRACK));
	Xil_Out32(DPLL_PLL_KI_TRACK_Addr, control_get_u32(CTRL_REG_KI_TRACK));
	Xil_Out32(DPLL_FLL_KF_ACQUIRE_Addr, control_get_u32(CTRL_REG_KF_ACQUIRE));
	Xil_Out32(DPLL_FLL_KF_BLEND_Addr, control_get_u32(CTRL_REG_KF_BLEND));
	Xil_Out32(DPLL_FREQ_POS_LIMIT_Addr,
	          (uint32_t)control_limit_word(control_get_s32(CTRL_REG_POS_LIMIT_HZ)));
	Xil_Out32(DPLL_FREQ_NEG_LIMIT_Addr,
	          (uint32_t)control_limit_word(control_get_s32(CTRL_REG_NEG_LIMIT_HZ)));
	Xil_Out32(DAC0_Phase_Residuals_Threshold_Addr,
	          control_phase_raw(control_get_u16(CTRL_REG_PHASE_THRESHOLD_CDEG)));
	Xil_Out32(DAC0_Freq_Residuals_Threshold_Addr,
	          control_frequency_raw(control_get_u16(CTRL_REG_FREQ_THRESHOLD_HZ)));
	Xil_Out32(DAC0_VOC_Amplitude_Addr,
	          control_amplitude_raw(control_get_u16(CTRL_REG_DAC_AMPLITUDE_MV)));
	interval_cycles = (uint32_t)control_get_u16(CTRL_REG_FAST_INTERVAL_MS) * 125000UL;
	Xil_Out32(Freq_Meter_Fast_Interval_Addr, interval_cycles);

	apply_status = dpll_apply_config();
	if (apply_status != DPLL_DRIVER_OK) {
		Control_Last_Error = (apply_status == DPLL_DRIVER_ERR_ABI) ?
		                     CTRL_ERROR_ABI : CTRL_ERROR_APPLY;
		dpll_set_enable(0U);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}

	Control_DPLL_Enabled =
		(Control_Bank[CTRL_REG_CONTROL_FLAGS] & CTRL_FLAG_DPLL_ENABLE) ? 1U : 0U;
	if (dpll_set_enable(Control_DPLL_Enabled) != DPLL_DRIVER_OK) {
		Control_Last_Error = CTRL_ERROR_ABI;
		Control_DPLL_Enabled = 0U;
		return 0U;
	}
	Control_Last_Error = CTRL_ERROR_NONE;
	return 1U;
}

static uint64_t control_divide_u80_u32(uint16_t high, uint32_t middle,
		uint32_t low, uint32_t divisor)
{
	int bit;
	uint64_t quotient = 0U;
	uint64_t remainder = 0U;
	uint8_t quotient_bit;
	uint8_t input_bit;
	uint8_t overflow = 0U;

	for (bit = 79; bit >= 0; --bit) {
		if (bit >= 64) input_bit = (uint8_t)((high >> (bit - 64)) & 1U);
		else if (bit >= 32) input_bit = (uint8_t)((middle >> (bit - 32)) & 1U);
		else input_bit = (uint8_t)((low >> bit) & 1U);
		remainder = (remainder << 1) | input_bit;
		quotient_bit = 0U;
		if (remainder >= divisor) {
			remainder -= divisor;
			quotient_bit = 1U;
		}
		if (bit >= 64) {
			if (quotient_bit) overflow = 1U;
		} else if (quotient_bit) {
			quotient |= (uint64_t)1U << bit;
		}
	}
	return overflow ? 0xFFFFFFFFFFFFFFFFULL : quotient;
}

static uint32_t control_fast_meter_hz(void)
{
	uint32_t status_before;
	uint32_t status_after;
	uint32_t interval;
	uint32_t low;
	uint32_t middle;
	uint32_t high;
	uint64_t quotient;
	uint64_t frequency;
	uint32_t retry;

	for (retry = 0U; retry < 4U; ++retry) {
		status_before = Xil_In32(Freq_Meter_Fast_Status_Addr);
		low = Xil_In32(Freq_Meter_Fast_DataL_Output_Addr);
		middle = Xil_In32(Freq_Meter_Fast_DataM_Output_Addr);
		high = Xil_In32(Freq_Meter_Fast_DataH_Output_Addr) & 0xFFFFU;
		interval = Xil_In32(Freq_Meter_Fast_Result_Interval_Addr);
		status_after = Xil_In32(Freq_Meter_Fast_Status_Addr);
		if (status_before == status_after) break;
	}
	control_put_u32(CTRL_REG_FAST_METER_SEQ, status_after >> 1);
	if ((status_after & 1U) == 0U || interval == 0U || status_before != status_after) return 0U;
	quotient = control_divide_u80_u32((uint16_t)high, middle, low, interval);
	if (quotient > (0xFFFFFFFFFFFFFFFFULL - 0x100000000ULL) / 125000000ULL)
		return 0xFFFFFFFFUL;
	frequency = (quotient * 125000000ULL + 0x100000000ULL) >> 33;
	return frequency > 0xFFFFFFFFULL ? 0xFFFFFFFFUL : (uint32_t)frequency;
}

static uint32_t control_dpll_output_hz(void)
{
	uint32_t high_before;
	uint32_t high_after;
	uint32_t low;
	uint32_t word_hi32;
	uint32_t retry;
	for (retry = 0U; retry < 4U; ++retry) {
		high_before = Xil_In32(DPLL_TRACKING_WORD_HI_Addr) & 0xFFFFU;
		low = Xil_In32(PLL0_Output_Limit);
		high_after = Xil_In32(DPLL_TRACKING_WORD_HI_Addr) & 0xFFFFU;
		if (high_before == high_after) break;
	}
	if (high_before != high_after) return 0U;
	word_hi32 = (high_after << 16) | (low >> 16);
	return (uint32_t)(((uint64_t)word_hi32 * 125000000ULL + 0x80000000ULL) >> 32);
}

static void control_collect_runtime(void)
{
	uint32_t system_status = Xil_In32(System_Statue);
	uint32_t core_flags = Xil_In32(DPLL_CORE_FLAGS_Addr);
	int32_t frequency_raw = (int32_t)Xil_In32(DDC0_inst_frequency);
	int32_t phase_raw = (int32_t)Xil_In32(PLL0_phase_residuals);
	uint8_t dpll_status = CTRL_DPLL_STATUS_ARM_ONLINE;

	if (Control_DPLL_Enabled) dpll_status |= CTRL_DPLL_STATUS_ENABLED;
	if (system_status & 0x01U) dpll_status |= CTRL_DPLL_STATUS_LOCKED;
	if (system_status & 0x20U) dpll_status |= CTRL_DPLL_STATUS_PHASE_OUT;
	if (system_status & 0x40U) dpll_status |= CTRL_DPLL_STATUS_FREQ_OUT;
	if (system_status & 0x08U) dpll_status |= CTRL_DPLL_STATUS_POS_RAIL;
	if (system_status & 0x10U) dpll_status |= CTRL_DPLL_STATUS_NEG_RAIL;
	if (Control_Last_Error != CTRL_ERROR_NONE) dpll_status |= CTRL_DPLL_STATUS_ERROR;
	Control_Bank[CTRL_REG_DPLL_STATUS] = dpll_status;
	Control_Bank[CTRL_REG_LAST_ERROR] = Control_Last_Error;
	Control_Bank[CTRL_REG_LOOP_STATE] = (uint8_t)((core_flags >> 13) & 0x0FU);
	Control_Bank[CTRL_REG_LOSS_REASON] = (uint8_t)((core_flags >> 9) & 0x0FU);
	control_put_u32(CTRL_REG_FREQ_ERROR_HZ,
	                (uint32_t)control_div_round_signed((int64_t)frequency_raw * 3125000LL,
	                                                   67108864LL));
	control_put_u32(CTRL_REG_PHASE_ERROR_CDEG,
	                (uint32_t)control_div_round_signed((int64_t)phase_raw * 36000LL,
	                                                   262144LL));
	control_put_u32(CTRL_REG_OUTPUT_FREQ_HZ, control_dpll_output_hz());
	control_put_u32(CTRL_REG_FAST_METER_HZ, control_fast_meter_hz());
	control_put_u32(CTRL_REG_ACTIVE_CONFIG_CRC, Xil_In32(DPLL_ACTIVE_CONFIG_CRC_Addr));
}

static uint8_t control_publish_runtime(void)
{
	uint8_t ok = 1U;
	uint8_t final_sequence = Control_Bank[CTRL_REG_RESPONSE_SEQ];
	uint8_t update_sequence = final_sequence ^ 0x80U;
	ok &= control_uart_write(CTRL_REG_RESPONSE_SEQ, 1U, &update_sequence);
	ok &= control_uart_write(CTRL_REG_DPLL_STATUS, 1U,
	                         &Control_Bank[CTRL_REG_DPLL_STATUS]);
	ok &= control_uart_write(CTRL_REG_LAST_ERROR, 3U,
	                         &Control_Bank[CTRL_REG_LAST_ERROR]);
	ok &= control_uart_write(CTRL_REG_FREQ_ERROR_HZ, 24U,
	                         &Control_Bank[CTRL_REG_FREQ_ERROR_HZ]);
	ok &= control_uart_write(CTRL_REG_RESPONSE_SEQ, 1U,
	                         &final_sequence);
	return ok;
}

static void Control_Reset_Both(void)
{
	dpll_set_enable(0U);
	Control_DPLL_Enabled = 0U;
	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 0U);
	Xil_Out32(Opal_Kelly_Reset_Trigger_Addr, 0U);
	Xil_Out32(Freq_Meter_Reset_Trigger_Addr, 0U);
	usleep(100U);
	dpll_invalidate_abi();
}

static uint8_t Control_Link_Startup(void)
{
	uint8_t version = 0U;
	uint32_t retry;
	for (retry = 0U; retry < 200U; ++retry) {
		if (Control_Uart_Transaction(CTRL_UART_CMD_PING, 0U, 0U, 0, &version) &&
		    version == CTRL_PROTOCOL_VERSION &&
		    control_uart_read(0U, CTRL_BANK_SIZE, Control_Bank)) break;
		usleep(10000U);
	}
	if (retry == 200U) return 0U;

	Control_Bank[CTRL_REG_CONTROL_FLAGS] = 0U;
	if (!control_uart_write(CTRL_REG_CONTROL_FLAGS, 1U,
	                        &Control_Bank[CTRL_REG_CONTROL_FLAGS])) return 0U;
	Control_Reset_Both();
	if (!dpll_initialize_abi()) {
		Control_Last_Error = CTRL_ERROR_ABI;
	} else {
		control_apply_bank();
	}
	Control_Request_Seen = Control_Bank[CTRL_REG_REQUEST_SEQ];
	Control_Bank[CTRL_REG_RESPONSE_SEQ] = Control_Request_Seen;
	control_collect_runtime();
	return control_publish_runtime();
}

static void Control_Link_Service(void)
{
	uint8_t header[67];
	uint8_t previous[CTRL_PERSIST_END - CTRL_PERSIST_BEGIN];
	uint8_t apply_error;
	if (++Control_Service_Divider < CONTROL_SERVICE_PERIOD_LOOPS) return;
	Control_Service_Divider = 0U;
	memcpy(previous, &Control_Bank[CTRL_PERSIST_BEGIN], sizeof(previous));
	if (!control_uart_read(CTRL_REG_REQUEST_SEQ, sizeof(header), header)) {
		Control_Last_Error = CTRL_ERROR_PROTOCOL;
		return;
	}
	memcpy(&Control_Bank[CTRL_REG_REQUEST_SEQ], header, sizeof(header));
	if (Control_Bank[CTRL_REG_REQUEST_SEQ] != Control_Request_Seen) {
		Control_Request_Seen = Control_Bank[CTRL_REG_REQUEST_SEQ];
		if (!control_apply_bank()) {
			apply_error = Control_Last_Error;
			control_restore_persistent(previous, apply_error, 1U);
		}
		Control_Bank[CTRL_REG_RESPONSE_SEQ] = Control_Request_Seen;
	}
	control_collect_runtime();
	control_publish_runtime();
}

static uint8_t control_restore_persistent(const uint8_t *previous,
		uint8_t original_error, uint8_t sync_bridge)
{
	memcpy(&Control_Bank[CTRL_PERSIST_BEGIN], previous,
	       CTRL_PERSIST_END - CTRL_PERSIST_BEGIN);
	if (!control_apply_bank()) return 0U;
	if (sync_bridge &&
	    !control_uart_write(CTRL_PERSIST_BEGIN,
	                        CTRL_PERSIST_END - CTRL_PERSIST_BEGIN,
	                        &Control_Bank[CTRL_PERSIST_BEGIN])) {
		Control_Last_Error = CTRL_ERROR_PROTOCOL;
		return 0U;
	}
	Control_Last_Error = original_error;
	return 1U;
}

static uint8_t Control_Apply_Persistent(const uint8_t *data)
{
	uint8_t previous[CTRL_PERSIST_END - CTRL_PERSIST_BEGIN];
	uint8_t apply_error;
	memcpy(previous, &Control_Bank[CTRL_PERSIST_BEGIN], sizeof(previous));
	memcpy(&Control_Bank[CTRL_PERSIST_BEGIN], data,
	       CTRL_PERSIST_END - CTRL_PERSIST_BEGIN);
	if (!control_apply_bank()) {
		apply_error = Control_Last_Error;
		if (!control_restore_persistent(previous, apply_error, 0U))
			return Control_Last_Error;
		return apply_error;
	}
	if (!control_uart_write(CTRL_PERSIST_BEGIN,
	                        CTRL_PERSIST_END - CTRL_PERSIST_BEGIN,
	                        &Control_Bank[CTRL_PERSIST_BEGIN])) {
		if (!control_restore_persistent(previous, CTRL_ERROR_PROTOCOL, 1U))
			return Control_Last_Error;
		return CTRL_ERROR_PROTOCOL;
	}
	return CTRL_ERROR_NONE;
}

static uint8_t Control_Save_Active(void)
{
	return Control_Uart_Transaction(CTRL_UART_CMD_SAVE, 0U, 0U, 0, 0);
}

static uint8_t Control_Set_MWS_Enable(uint8_t enable)
{
	if (enable) Control_Bank[CTRL_REG_CONTROL_FLAGS] |= CTRL_FLAG_MWS_ENABLE;
	else Control_Bank[CTRL_REG_CONTROL_FLAGS] &= (uint8_t)~CTRL_FLAG_MWS_ENABLE;
	return control_uart_write(CTRL_REG_CONTROL_FLAGS, 1U,
	                          &Control_Bank[CTRL_REG_CONTROL_FLAGS]);
}

static uint8_t Control_Set_DPLL_Enable(uint8_t enable)
{
	if (dpll_set_enable(enable ? 1U : 0U) != DPLL_DRIVER_OK) return 0U;
	Control_DPLL_Enabled = enable ? 1U : 0U;
	if (enable) Control_Bank[CTRL_REG_CONTROL_FLAGS] |= CTRL_FLAG_DPLL_ENABLE;
	else Control_Bank[CTRL_REG_CONTROL_FLAGS] &= (uint8_t)~CTRL_FLAG_DPLL_ENABLE;
	return control_uart_write(CTRL_REG_CONTROL_FLAGS, 1U,
	                          &Control_Bank[CTRL_REG_CONTROL_FLAGS]);
}

int main()
{
	init_platform();

    XPS_Core_init();
    Uart0PS_Init();
    Uart1PS_Init();

	while (!Control_Link_Startup()) {
		print("control link startup failed, retrying\r\n");
		usleep(100000U);
	}

	Xil_Out32(DAC0_DDC_Angle_Select_Addr, 0U);
	Xil_Out32(DAC0_VCO_Offset_Addr, 0U);
	Xil_Out32(VCO_Freq_Manual_Offset_Addr, 0U);

	/* The original precision frequency-meter path remains independent. */
	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 0U);
	Xil_Out32(Freq_Meter_Centre_Frequency_Addr, 0x51EB851EU);
	Xil_Out32(Freq_Meter_PID_GainP_Addr, 0x00400000U);
	Xil_Out32(Freq_Meter_PID_GainI_Addr, 0x00100000U);
	Xil_Out32(Freq_Meter_PID_GainI2_Addr, 0x00000100U);
	Xil_Out32(Freq_Meter_PID_GainD_Addr, 0U);
	Xil_Out32(Freq_Meter_Coefd_Filter_Addr, 0x0FFFFU);
	Xil_Out32(Freq_Meter_Freq_Pos_Limit_Addr, 0x4FFFFFFFU);
	Xil_Out32(Freq_Meter_Freq_Neg_Limit_Addr, 0xB0000000U);
	Xil_Out32(Freq_Meter_Freq_Manual_Offset_Addr, 0U);
	Xil_Out32(Freq_Meter_Gate_Time_H_Addr, 0U);
	Xil_Out32(Freq_Meter_Phase_Residuals_Threshold_Addr, 1000U);
	Xil_Out32(Freq_Meter_Phase_Residuals_Offset_Addr, 0U);
	Xil_Out32(Freq_Meter_Freq_Residuals_Threshold_Addr, 500U);
	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 0U);

    XUartPs_SendByte(XUartPs_uart0.Config.BaseAddress,'C');


    while(1)
    {
		PC_HOST_CMD_Respond();
		Control_Link_Service();
		usleep(1000U);
    }
    cleanup_platform();
    return 0;
}
