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

#ifndef CONTROL_DCC_LOG_ENABLE
#define CONTROL_DCC_LOG_ENABLE 0
#endif

#if CONTROL_DCC_LOG_ENABLE
#define CONTROL_DCC_LOG(...) xil_printf(__VA_ARGS__)
#else
#define CONTROL_DCC_LOG(...) do { } while (0)
#endif



XUartPs XUartPs_uart0;
XUartPs XUartPs_uart1;
XScuGic XPS_XScuGic;
uint8_t PLL_Lock_Status;

static uint8_t Control_Bank[CTRL_BANK_SIZE];
static uint8_t Control_Debug_Preset_Seen = CTRL_DEBUG_DAC_PRESET_MANUAL;
static uint8_t Control_Freq_Meter_Reset_Request_Seen;
static uint8_t Control_DPLL_Enabled;

#define CONTROL_FREQ_METER_RESET_REQUEST 0xFEU

static uint8_t Control_Link_Startup(void);
static void Control_Link_Service(void);
static uint8_t Control_Apply_Persistent(const uint8_t *data);
static uint8_t Control_Save_Active(void);
static uint8_t control_restore_persistent(const uint8_t *previous,
		uint8_t original_error, uint8_t sync_bridge);
static uint8_t Control_Set_MWS_Enable(uint8_t enable);
static uint8_t Control_Set_DPLL_Enable(uint8_t enable);
static void Control_Reset_Frequency_Meter(void);
static void Control_Reset_Both(void);
static void control_put_u32(uint8_t offset, uint32_t value);
static uint8_t control_uart_write(uint8_t offset, uint8_t length, const uint8_t *data);
static uint8_t control_apply_bank(void);
static uint8_t Control_Apply_Debug_DAC_Preset(uint8_t preset);
static uint8_t Control_Set_Debug_DAC_Preset(uint8_t preset);

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
#define PC_CMD_READ_DPLL_DEBUG_CONFIG		0x1E


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
#define PC_ERR_DPLL_APPLY_REJECTED        0xF6U
#define PC_ERR_DPLL_APPLY_VERIFY          0xF7U
#define DPLL_ABI_RETRY_COUNT              100U
#define DPLL_ABI_RETRY_DELAY_US           100U
#define PC_HOST_MAX_FRAME_BYTES           128U
#define DPLL_ADV_CONFIG_PAYLOAD_BYTES     90U
#define DPLL_DEBUG_CONFIG_PAYLOAD_BYTES   12U
#define DPLL_DEBUG_PRESET_PAYLOAD_BYTES   1U
#define FREQ_METER_D_FILTER_COEFF          0x0000FFFFU

typedef struct {
	uint32_t source;
	uint32_t format;
	uint16_t offset;
	uint16_t gain;
} debug_dac_preset_t;

typedef struct {
	uint32_t center_word;
	uint32_t phase_threshold;
	uint16_t frequency_threshold;
	uint32_t positive_limit;
	uint32_t negative_limit;
	uint32_t gain_p;
	uint32_t gain_i;
	uint32_t gain_i2;
	uint32_t gain_d;
	uint32_t manual_offset;
	uint32_t phase_offset;
	uint32_t gate_time_low;
	uint16_t gate_time_high;
	uint32_t fast_interval_cycles;
} freq_meter_config_t;

static const debug_dac_preset_t
Debug_DAC_Presets[CTRL_DEBUG_DAC_PRESET_MAX + 1U] = {
	{0U, 0x0100U, 0U, 0x5000U},
	{1U, 0x0000U, 0U, 0x7FFFU},
	{2U, 0x0100U, 0U, 0x5000U},
	{3U, 0x0000U, 0U, 0x7FFFU},
	{4U, 0x0000U, 0U, 0x7FFFU},
	{5U, 0x0006U, 0U, 0x7FFFU},
	{6U, 0x0006U, 0U, 0x7FFFU},
	{7U, 0x0004U, 0U, 0x7FFFU},
	{8U, 0x0207U, 0U, 0x7FFFU}
};

static uint8_t dpll_abi_ready = 0;
static uint8_t dpll_driver_initialized = 0;
static dpll_driver_t dpll_driver;
static dpll_config_t DPLL_Committed_Config;
static uint8_t DPLL_Committed_Config_Valid;
static uint32_t DPLL_Committed_Signature;
static freq_meter_config_t Freq_Meter_Committed_Config;
static uint8_t Freq_Meter_Committed_Config_Valid;
static debug_dac_preset_t Debug_DAC_Committed_Config;
static uint8_t Debug_DAC_Committed_Config_Valid;

static const dpll_reg_map_t dpll_register_map = {
	.lock_ctrl = PLL0_Lock_Ctrl_Addr,
	.reconfigure = DPLL_RECONFIGURE_Addr,
	.abi_version = DPLL_ABI_VERSION_Addr,
	.config_version = DPLL_CONFIG_VERSION_Addr,
	.build_id = DPLL_FPGA_BUILD_ID_Addr,
	.git_hash = DPLL_GIT_HASH_Addr,
	.center = DAC0_Centre_Frequency_Addr,
	.cic_r = DPLL_POST_IQ_CIC_R_Addr,
	.cic_shift = DPLL_POST_IQ_CIC_SHIFT_Addr,
	.mul = VOC_Fre_Mul_Addr,
	.div = VOC_Fre_Div_Addr,
	.kp_track = DPLL_PLL_KP_TRACK_Addr,
	.ki_track = DPLL_PLL_KI_TRACK_Addr,
	.kf_acquire = DPLL_FLL_KF_ACQUIRE_Addr,
	.kf_blend = DPLL_FLL_KF_BLEND_Addr,
	.kf_track = DPLL_FLL_KF_TRACK_Addr,
	.kp_blend = DPLL_PLL_KP_BLEND_Addr,
	.ki_blend = DPLL_PLL_KI_BLEND_Addr,
	.phase_threshold = DAC0_Phase_Residuals_Threshold_Addr,
	.phase_setpoint = DAC0_Phase_Residuals_Offset_Addr,
	.freq_threshold = DAC0_Freq_Residuals_Threshold_Addr,
	.mag_enter = DPLL_MAG_ENTER_THRESHOLD_Addr,
	.mag_exit = DPLL_MAG_EXIT_THRESHOLD_Addr,
	.acquire_dwell = DPLL_ACQUIRE_DWELL_Addr,
	.blend_dwell = DPLL_BLEND_DWELL_Addr,
	.loss_dwell = DPLL_LOSS_DWELL_Addr,
	.holdover_timeout = DPLL_HOLDOVER_TIMEOUT_Addr,
	.measurement_timeout = DPLL_MEASUREMENT_TIMEOUT_Addr,
	.fll_delay = DPLL_FLL_DELAY_SEL_Addr,
	.warmup_samples = DPLL_WARMUP_SAMPLES_Addr,
	.post_iir_config = DPLL_POST_IIR_CONFIG_Addr,
	.post_iir_acq_b0 = DPLL_POST_IIR_ACQ_B0_Addr,
	.post_iir_acq_b1 = DPLL_POST_IIR_ACQ_B1_Addr,
	.post_iir_acq_b2 = DPLL_POST_IIR_ACQ_B2_Addr,
	.post_iir_acq_a1 = DPLL_POST_IIR_ACQ_A1_Addr,
	.post_iir_acq_a2 = DPLL_POST_IIR_ACQ_A2_Addr,
	.post_iir_track_b0 = DPLL_POST_IIR_TRACK_B0_Addr,
	.post_iir_track_b1 = DPLL_POST_IIR_TRACK_B1_Addr,
	.post_iir_track_b2 = DPLL_POST_IIR_TRACK_B2_Addr,
	.post_iir_track_a1 = DPLL_POST_IIR_TRACK_A1_Addr,
	.post_iir_track_a2 = DPLL_POST_IIR_TRACK_A2_Addr,
	.positive_limit = DPLL_FREQ_POS_LIMIT_Addr,
	.negative_limit = DPLL_FREQ_NEG_LIMIT_Addr,
	.manual_offset = VCO_Freq_Manual_Offset_Addr,
	.dac0_offset = DAC0_VCO_Offset_Addr,
	.dac0_amplitude = DAC0_VOC_Amplitude_Addr
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
	                 DPLL_ABI_RETRY_DELAY_US);
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
		CONTROL_DCC_LOG("DPLL ABI ready abi=0x%08lx config=0x%08lx build=0x%08lx git=0x%08lx attempts=%lu\r\n",
		           (unsigned long)dpll_driver.actual.abi_version,
		           (unsigned long)dpll_driver.actual.config_version,
		           (unsigned long)dpll_driver.actual.build_id,
		           (unsigned long)dpll_driver.actual.git_hash,
		           (unsigned long)dpll_driver.abi_attempts);
		return 1;
	}
	CONTROL_DCC_LOG("DPLL ABI timeout actual abi=0x%08lx config=0x%08lx build=0x%08lx git=0x%08lx "
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
static void pc_send_dpll_config_result(int apply_status)
{
	if (apply_status == -1) {
		PC_HOST_Send_ASK_Only(PC_ERR_DPLL_ABI_MISMATCH);
		return;
	}
	if (apply_status == DPLL_DRIVER_ERR_CONFIG) {
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

static int dpll_commit_candidate(const dpll_config_t *candidate)
{
	dpll_config_validation_t validation;
	int status;

	dpll_driver_ensure_initialized();
	if (dpll_validate_config(candidate, &validation) != DPLL_DRIVER_OK) {
		CONTROL_DCC_LOG("DPLL candidate rejected errors=0x%08lx profile=0x%08lx\r\n",
		                (unsigned long)validation.errors,
		                (unsigned long)validation.profile.errors);
		return DPLL_DRIVER_ERR_CONFIG;
	}
	status = dpll_driver_write_config(
		&dpll_driver, candidate,
		DPLL_Committed_Config_Valid ? &DPLL_Committed_Config : 0,
		&validation);
	dpll_abi_ready = dpll_driver.abi_ready;
	if (status != DPLL_DRIVER_OK) return status;
	DPLL_Committed_Config = *candidate;
	DPLL_Committed_Config_Valid = 1U;
	DPLL_Committed_Signature = dpll_config_signature(candidate);
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

	XUartPs_Config_uart0 = XUartPs_LookupConfig(XPAR_PS7_UART_0_DEVICE_ID);//鑾峰緱涓插彛1閰嶇疆淇℃伅
	status = XUartPs_CfgInitialize(&XUartPs_uart0,XUartPs_Config_uart0,XUartPs_Config_uart0->BaseAddress);
	if(status != XST_SUCCESS)
	{
		CONTROL_DCC_LOG("Initialize uart1 fail\n");
	}
	XUartPs_SetOperMode(&XUartPs_uart0, XUARTPS_OPER_MODE_NORMAL);
	XUartPsFormat_uart0.BaudRate = 921600;//娉㈢壒鐜�921600
	XUartPsFormat_uart0.DataBits = XUARTPS_FORMAT_8_BITS;
	XUartPsFormat_uart0.Parity = XUARTPS_FORMAT_NO_PARITY;
	XUartPsFormat_uart0.StopBits = XUARTPS_FORMAT_1_STOP_BIT;
	status = XUartPs_SetDataFormat(&XUartPs_uart0,&XUartPsFormat_uart0);
	if(status != XST_SUCCESS)
	{
		CONTROL_DCC_LOG("set Buad Rate fail\n");
	}
	XUartPs_SetFifoThreshold(&XUartPs_uart0,32);
	XUartPs_SetRecvTimeout(&XUartPs_uart0,4);//4*4=16 timeout IXR
	XUartPs_SetInterruptMask(&XUartPs_uart0,XUARTPS_IXR_RXOVR|XUARTPS_IXR_TOUT);//寮�涓柇

	XScuGic_Disable(&XPS_XScuGic,XPS_UART0_INT_ID);
	//XScuGic_SetPriorityTriggerType(&XPS_XScuGic,XPS_UART0_INT_ID,16,1);
	XScuGic_Connect(&XPS_XScuGic,XPS_UART0_INT_ID,(Xil_ExceptionHandler)Uart0_Handler,(void *)&XUartPs_uart0);//鍏ュ彛
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


static uint8_t freq_meter_validate_config(const freq_meter_config_t *config)
{
	int32_t positive_limit;
	int32_t negative_limit;
	if (config == 0) return 0U;
	positive_limit = (int32_t)config->positive_limit;
	negative_limit = (int32_t)config->negative_limit;
	if (config->center_word == 0U || config->frequency_threshold > 0x03FFU ||
	    positive_limit <= 0 || negative_limit >= 0 ||
	    (config->gate_time_low == 0U && config->gate_time_high == 0U) ||
	    config->fast_interval_cycles <
	        (uint32_t)CTRL_FAST_INTERVAL_MIN_MS * 125000UL ||
	    config->fast_interval_cycles >
	        (uint32_t)CTRL_FAST_INTERVAL_MAX_MS * 125000UL)
		return 0U;
	return 1U;
}

static uint8_t freq_meter_commit_candidate(const freq_meter_config_t *candidate)
{
	if (!freq_meter_validate_config(candidate)) return 0U;
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->center_word != Freq_Meter_Committed_Config.center_word)
		Xil_Out32(Freq_Meter_Centre_Frequency_Addr, candidate->center_word);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->phase_threshold != Freq_Meter_Committed_Config.phase_threshold)
		Xil_Out32(Freq_Meter_Phase_Residuals_Threshold_Addr, candidate->phase_threshold);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->frequency_threshold != Freq_Meter_Committed_Config.frequency_threshold)
		Xil_Out32(Freq_Meter_Freq_Residuals_Threshold_Addr, candidate->frequency_threshold);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->positive_limit != Freq_Meter_Committed_Config.positive_limit)
		Xil_Out32(Freq_Meter_Freq_Pos_Limit_Addr, candidate->positive_limit);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->negative_limit != Freq_Meter_Committed_Config.negative_limit)
		Xil_Out32(Freq_Meter_Freq_Neg_Limit_Addr, candidate->negative_limit);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->gain_p != Freq_Meter_Committed_Config.gain_p)
		Xil_Out32(Freq_Meter_PID_GainP_Addr, candidate->gain_p);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->gain_i != Freq_Meter_Committed_Config.gain_i)
		Xil_Out32(Freq_Meter_PID_GainI_Addr, candidate->gain_i);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->gain_i2 != Freq_Meter_Committed_Config.gain_i2)
		Xil_Out32(Freq_Meter_PID_GainI2_Addr, candidate->gain_i2);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->gain_d != Freq_Meter_Committed_Config.gain_d)
		Xil_Out32(Freq_Meter_PID_GainD_Addr, candidate->gain_d);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->manual_offset != Freq_Meter_Committed_Config.manual_offset)
		Xil_Out32(Freq_Meter_Freq_Manual_Offset_Addr, candidate->manual_offset);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->phase_offset != Freq_Meter_Committed_Config.phase_offset)
		Xil_Out32(Freq_Meter_Phase_Residuals_Offset_Addr, candidate->phase_offset);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->gate_time_low != Freq_Meter_Committed_Config.gate_time_low)
		Xil_Out32(Freq_Meter_Gate_Time_L_Addr, candidate->gate_time_low);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->gate_time_high != Freq_Meter_Committed_Config.gate_time_high)
		Xil_Out32(Freq_Meter_Gate_Time_H_Addr, candidate->gate_time_high);
	if (!Freq_Meter_Committed_Config_Valid ||
	    candidate->fast_interval_cycles != Freq_Meter_Committed_Config.fast_interval_cycles)
		Xil_Out32(Freq_Meter_Fast_Interval_Addr, candidate->fast_interval_cycles);
	Freq_Meter_Committed_Config = *candidate;
	Freq_Meter_Committed_Config_Valid = 1U;
	return 1U;
}

static uint8_t debug_dac_validate_config(const debug_dac_preset_t *config)
{
	uint32_t mode;
	uint32_t amount;
	int16_t offset;
	if (config == 0 || config->source > 0x0AU ||
	    (config->format & ~0x00000F3FU) != 0U)
		return 0U;
	mode = (config->format >> 8) & 0x03U;
	amount = config->format & 0x3FU;
	offset = (int16_t)config->offset;
	if (mode > 2U || (mode == 0U && amount > 16U) ||
	    (mode != 0U && amount > 31U) || offset < -8192 || offset > 8191)
		return 0U;
	return 1U;
}

static uint8_t debug_dac_commit_candidate(const debug_dac_preset_t *candidate)
{
	if (!debug_dac_validate_config(candidate)) return 0U;
	Xil_Out32(DPLL_DEBUG_DAC_OFFSET_ADDR, candidate->offset);
	Xil_Out32(DPLL_DEBUG_DAC_GAIN_ADDR, candidate->gain);
	Xil_Out32(DPLL_DEBUG_DAC_FORMAT_ADDR, candidate->format);
	Xil_Out32(DPLL_DEBUG_DAC_SOURCE_ADDR, candidate->source);
	Debug_DAC_Committed_Config = *candidate;
	Debug_DAC_Committed_Config_Valid = 1U;
	return 1U;
}

void CMD_8F_WRITE_DPLL_ADV_CONFIG(void)
{
	dpll_config_t candidate;
	int status;
	if (pc_payload_len() != DPLL_ADV_CONFIG_PAYLOAD_BYTES) {
		PC_HOST_Send_ASK_Only(0xF2);
		return;
	}
	if (!DPLL_Committed_Config_Valid) {
		PC_HOST_Send_ASK_Only(PC_ERR_DPLL_APPLY_REJECTED);
		return;
	}
	if (pc_get_u32(24) > 0xFFFFU || pc_get_u32(28) > 0xFFFFU ||
	    pc_get_u32(32) > 0xFFFFU || pc_get_u32(50) > 0xFFU) {
		PC_HOST_Send_ASK_Only(PC_ERR_DPLL_APPLY_REJECTED);
		return;
	}
	candidate = DPLL_Committed_Config;
	candidate.profile.kf_track = (int32_t)pc_get_u32(4);
	candidate.profile.kp_blend = (int32_t)pc_get_u32(8);
	candidate.profile.ki_blend = (int32_t)pc_get_u32(12);
	candidate.profile.magnitude_enter = pc_get_u32(16);
	candidate.profile.magnitude_exit = pc_get_u32(20);
	candidate.profile.acquire_dwell = (uint16_t)pc_get_u32(24);
	candidate.profile.blend_dwell = (uint16_t)pc_get_u32(28);
	candidate.profile.loss_dwell = (uint16_t)pc_get_u32(32);
	candidate.profile.holdover_timeout = pc_get_u32(36);
	candidate.profile.cic_r = pc_get_u16(40);
	candidate.profile.cic_shift = PC_HOST_CMD_data_Buff[42];
	candidate.profile.fll_delay_sel = PC_HOST_CMD_data_Buff[43];
	candidate.profile.warmup_samples = pc_get_u16(44);
	candidate.profile.measurement_timeout = pc_get_u32(46);
	candidate.profile.post_iir_mode = (uint8_t)pc_get_u32(50);
	candidate.profile.acquire_b0 = (int32_t)pc_get_u32(54);
	candidate.profile.acquire_b1 = (int32_t)pc_get_u32(58);
	candidate.profile.acquire_b2 = (int32_t)pc_get_u32(62);
	candidate.profile.acquire_a1 = (int32_t)pc_get_u32(66);
	candidate.profile.acquire_a2 = (int32_t)pc_get_u32(70);
	candidate.profile.track_b0 = (int32_t)pc_get_u32(74);
	candidate.profile.track_b1 = (int32_t)pc_get_u32(78);
	candidate.profile.track_b2 = (int32_t)pc_get_u32(82);
	candidate.profile.track_a1 = (int32_t)pc_get_u32(86);
	candidate.profile.track_a2 = (int32_t)pc_get_u32(90);
	status = dpll_commit_candidate(&candidate);
	pc_send_dpll_config_result(status);
}
void CMD_90_WRITE_FREQMETER_FREQ(void)
{
	freq_meter_config_t candidate = Freq_Meter_Committed_Config;
	if (pc_payload_len() != 4U || !Freq_Meter_Committed_Config_Valid) {
		PC_HOST_Send_ASK_Only(0xF2U);
		return;
	}
	candidate.center_word = pc_get_u32(4);
	PC_HOST_Send_ASK_Only(freq_meter_commit_candidate(&candidate) ? 0U : CTRL_ERROR_RANGE);
}
void CMD_91_WRITE_FREQMETER_THRESHOLD(void)
{
	freq_meter_config_t candidate = Freq_Meter_Committed_Config;
	if (pc_payload_len() != 4U || !Freq_Meter_Committed_Config_Valid) {
		PC_HOST_Send_ASK_Only(0xF2U);
		return;
	}
	candidate.frequency_threshold = pc_get_u16(4);
	candidate.phase_threshold = pc_get_u16(6);
	PC_HOST_Send_ASK_Only(freq_meter_commit_candidate(&candidate) ? 0U : CTRL_ERROR_RANGE);
}
void CMD_92_WRITE_FREQMETER_LIMIT(void)
{
	freq_meter_config_t candidate = Freq_Meter_Committed_Config;
	if (pc_payload_len() != 4U || !Freq_Meter_Committed_Config_Valid) {
		PC_HOST_Send_ASK_Only(0xF2U);
		return;
	}
	candidate.positive_limit = (uint32_t)pc_get_u16(4) << 16;
	candidate.negative_limit = (uint32_t)pc_get_u16(6) << 16;
	PC_HOST_Send_ASK_Only(freq_meter_commit_candidate(&candidate) ? 0U : CTRL_ERROR_RANGE);
}
void CMD_93_WRITE_FREQMETER_PID(void)
{
	freq_meter_config_t candidate = Freq_Meter_Committed_Config;
	if (pc_payload_len() != 16U || !Freq_Meter_Committed_Config_Valid) {
		PC_HOST_Send_ASK_Only(0xF2U);
		return;
	}
	candidate.gain_p = pc_get_u32(4);
	candidate.gain_i = pc_get_u32(8);
	candidate.gain_i2 = pc_get_u32(12);
	candidate.gain_d = pc_get_u32(16);
	PC_HOST_Send_ASK_Only(freq_meter_commit_candidate(&candidate) ? 0U : CTRL_ERROR_RANGE);
}
void CMD_94_WRITE_FREQMETER_TIMER(void)
{
	freq_meter_config_t candidate = Freq_Meter_Committed_Config;
	if (pc_payload_len() != 6U || !Freq_Meter_Committed_Config_Valid) {
		PC_HOST_Send_ASK_Only(0xF2U);
		return;
	}
	candidate.gate_time_low = pc_get_u32(4);
	candidate.gate_time_high = pc_get_u16(8);
	PC_HOST_Send_ASK_Only(freq_meter_commit_candidate(&candidate) ? 0U : CTRL_ERROR_RANGE);
}

static uint8_t Control_Apply_Debug_DAC_Preset(uint8_t preset)
{
	const debug_dac_preset_t *config;
	if (preset > CTRL_DEBUG_DAC_PRESET_MAX) return 0U;
	config = &Debug_DAC_Presets[preset];
	return debug_dac_commit_candidate(config);
}

static uint8_t Control_Set_Debug_DAC_Preset(uint8_t preset)
{
	uint8_t previous = Control_Bank[CTRL_REG_DEBUG_DAC_PRESET];
	if (preset > CTRL_DEBUG_DAC_PRESET_MAX) return 0U;
	Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = preset;
	if (!control_uart_write(CTRL_REG_DEBUG_DAC_PRESET, 1U,
	                        &Control_Bank[CTRL_REG_DEBUG_DAC_PRESET])) {
		Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = previous;
		return 0U;
	}
	Control_Apply_Debug_DAC_Preset(preset);
	Control_Debug_Preset_Seen = preset;
	return 1U;
}

void CMD_97_WRITE_DPLL_DEBUG_CONFIG(void)
{
	uint8_t length = pc_payload_len();
	uint8_t previous_preset;
	debug_dac_preset_t candidate;
	if (length == DPLL_DEBUG_PRESET_PAYLOAD_BYTES) {
		if (!Control_Set_Debug_DAC_Preset(PC_HOST_CMD_data_Buff[4])) {
			PC_HOST_Send_ASK_Only(
				PC_HOST_CMD_data_Buff[4] > CTRL_DEBUG_DAC_PRESET_MAX ?
				CTRL_ERROR_RANGE : CTRL_ERROR_PROTOCOL);
			return;
		}
		PC_HOST_Send_ASK_Only(0U);
		return;
	}
	if (length != DPLL_DEBUG_CONFIG_PAYLOAD_BYTES) {
		PC_HOST_Send_ASK_Only(0xF2);
		return;
	}
	previous_preset = Control_Bank[CTRL_REG_DEBUG_DAC_PRESET];
	Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = CTRL_DEBUG_DAC_PRESET_MANUAL;
	if (!control_uart_write(CTRL_REG_DEBUG_DAC_PRESET, 1U,
	                        &Control_Bank[CTRL_REG_DEBUG_DAC_PRESET])) {
		Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = previous_preset;
		PC_HOST_Send_ASK_Only(CTRL_ERROR_PROTOCOL);
		return;
	}
	candidate.source = pc_get_u32(4);
	candidate.format = pc_get_u32(8);
	candidate.offset = pc_get_u16(12);
	candidate.gain = pc_get_u16(14);
	if (!debug_dac_commit_candidate(&candidate)) {
		Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = previous_preset;
		control_uart_write(CTRL_REG_DEBUG_DAC_PRESET, 1U,
		                   &Control_Bank[CTRL_REG_DEBUG_DAC_PRESET]);
		PC_HOST_Send_ASK_Only(CTRL_ERROR_RANGE);
		return;
	}
	Control_Debug_Preset_Seen = CTRL_DEBUG_DAC_PRESET_MANUAL;
	PC_HOST_Send_ASK_Only(0U);
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

void CMD_1E_READ_DPLL_DEBUG_CONFIG(void)
{
	debug_dac_preset_t config;
	if (Debug_DAC_Committed_Config_Valid) {
		config = Debug_DAC_Committed_Config;
	} else {
		config.offset = (uint16_t)Xil_In32(DPLL_DEBUG_DAC_OFFSET_ADDR);
		config.gain = (uint16_t)Xil_In32(DPLL_DEBUG_DAC_GAIN_ADDR);
		config.source = Xil_In32(DPLL_DEBUG_DAC_SOURCE_ADDR);
		config.format = Xil_In32(DPLL_DEBUG_DAC_FORMAT_ADDR);
	}
	Uart0_TX_Buff[4] = Control_Bank[CTRL_REG_DEBUG_DAC_PRESET];
	pc_put_u32(5U, config.source);
	pc_put_u32(9U, config.format);
	Uart0_TX_Buff[13] = (uint8_t)config.offset;
	Uart0_TX_Buff[14] = (uint8_t)(config.offset >> 8);
	Uart0_TX_Buff[15] = (uint8_t)config.gain;
	Uart0_TX_Buff[16] = (uint8_t)(config.gain >> 8);
	PC_HOST_ASK_Pack(13U);
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
			case PC_CMD_READ_DPLL_DEBUG_CONFIG:
				CMD_1E_READ_DPLL_DEBUG_CONFIG();
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
				if (freq_meter_commit_candidate(&Freq_Meter_Committed_Config) &&
				    dpll_initialize_abi() && control_apply_bank() &&
				    Control_Set_Debug_DAC_Preset(CTRL_DEBUG_DAC_PRESET_DEFAULT)) {
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
				Control_Reset_Frequency_Meter();
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
#define CONTROL_UART_RETRY_COUNT       3U
#define CONTROL_SERVICE_PERIOD_LOOPS   50U
#define CONTROL_ERROR_HOLD_LOOPS       3000U

static volatile uint8_t Control_Uart_RX[CONTROL_UART_BUFFER_SIZE];
static volatile uint32_t Control_Uart_RX_Count;
static volatile uint8_t Control_Uart_Frame_Ready;
static uint8_t Control_Uart_TX[CONTROL_UART_BUFFER_SIZE];
static uint8_t Control_Request_Seen;
static uint8_t Control_Last_Error;
static uint32_t Control_Service_Divider;
static uint32_t Control_Error_Hold_Loops;

static void control_report_error(uint8_t error)
{
	Control_Last_Error = error;
	Control_Error_Hold_Loops = CONTROL_ERROR_HOLD_LOOPS;
}

static void control_error_hold_service(void)
{
	if (Control_Error_Hold_Loops == 0U) return;
	Control_Error_Hold_Loops--;
	if (Control_Error_Hold_Loops == 0U) Control_Last_Error = CTRL_ERROR_NONE;
}

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

static void control_uart_update_frame_ready(void)
{
	uint32_t expected;
	if (Control_Uart_RX_Count < 3U) return;
	if (Control_Uart_RX[0] != CTRL_UART_RESP) {
		if (Control_Uart_RX_Count >= 5U) Control_Uart_Frame_Ready = 1U;
		return;
	}
	expected = (uint32_t)Control_Uart_RX[2] + 5U;
	if (expected > CONTROL_UART_BUFFER_SIZE || Control_Uart_RX_Count >= expected)
		Control_Uart_Frame_Ready = 1U;
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
	}
	/* An RX timeout may be only an inter-byte gap while STM8 services I2C. */
	control_uart_update_frame_ready();
}

void Uart1PS_Init(void)
{
	XUartPs_Config *config;
	XUartPsFormat format;
	int status;
	u32 base_address;

	config = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
	status = XUartPs_CfgInitialize(&XUartPs_uart1, config, config->BaseAddress);
	if (status != XST_SUCCESS) CONTROL_DCC_LOG("Initialize uart1 fail\n");

	XUartPs_SetOperMode(&XUartPs_uart1, XUARTPS_OPER_MODE_NORMAL);
	/* The 2018.3 driver limits this API to 921600; set exact 1 Mbps below. */
	format.BaudRate = 921600;
	format.DataBits = XUARTPS_FORMAT_8_BITS;
	format.Parity = XUARTPS_FORMAT_NO_PARITY;
	format.StopBits = XUARTPS_FORMAT_1_STOP_BIT;
	status = XUartPs_SetDataFormat(&XUartPs_uart1, &format);
	if (status != XST_SUCCESS) CONTROL_DCC_LOG("set uart1 baud rate fail\n");

	base_address = XUartPs_uart1.Config.BaseAddress;
	XUartPs_DisableUart(&XUartPs_uart1);
	XUartPs_WriteReg(base_address, XUARTPS_BAUDGEN_OFFSET, 20U);
	XUartPs_WriteReg(base_address, XUARTPS_BAUDDIV_OFFSET, 4U);
	XUartPs_WriteReg(base_address, XUARTPS_CR_OFFSET,
	                 XUARTPS_CR_TXRST | XUARTPS_CR_RXRST);
	XUartPs_EnableUart(&XUartPs_uart1);
	XUartPs_uart1.BaudRate = 1000000U;

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

static uint8_t Control_Uart_Transaction_Once(uint8_t command, uint8_t offset,
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

static uint8_t Control_Uart_Transaction(uint8_t command, uint8_t offset,
		uint8_t length, const uint8_t *write_data, uint8_t *read_data)
{
	uint32_t retry;
	for (retry = 0U; retry <= CONTROL_UART_RETRY_COUNT; ++retry) {
		if (Control_Uart_Transaction_Once(command, offset, length,
		                                  write_data, read_data)) return 1U;
		if (retry < CONTROL_UART_RETRY_COUNT) usleep(2000U);
	}
	control_report_error(CTRL_ERROR_PROTOCOL);
	return 0U;
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

static uint8_t control_validate_bank(void)
{
	uint32_t center = control_get_u32(CTRL_REG_CENTER_FREQ_DHZ);
	uint32_t microwave_khz = control_get_u32(CTRL_REG_MWS_FREQ_KHZ);
	int32_t positive_limit = control_get_s32(CTRL_REG_POS_LIMIT_HZ);
	int32_t negative_limit = control_get_s32(CTRL_REG_NEG_LIMIT_HZ);
	uint16_t multiplier = control_get_u16(CTRL_REG_OUTPUT_MUL);
	uint16_t divider = control_get_u16(CTRL_REG_OUTPUT_DIV);
	if (Control_Bank[CTRL_REG_ID] != 0xA5U ||
	    Control_Bank[CTRL_REG_PROTOCOL_VERSION] != CTRL_PROTOCOL_VERSION) return 0U;
	if (microwave_khz < CTRL_MWS_FREQ_MIN_KHZ ||
	    microwave_khz > CTRL_MWS_FREQ_MAX_KHZ) return 0U;
	if (center < CTRL_DPLL_CENTER_MIN_DHZ ||
	    center > CTRL_DPLL_CENTER_MAX_DHZ) return 0U;
	if (multiplier == 0U || divider == 0U) return 0U;
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

static int dpll_build_control_candidate(uint32_t center_word,
		dpll_config_t *candidate)
{
	dpll_filter_profile_t generated;
	dpll_profile_validation_t validation;
	if (candidate == 0 ||
	    dpll_compute_filter_profile_checked(center_word, &generated,
	                                        &validation) != DPLL_DRIVER_OK)
		return DPLL_DRIVER_ERR_CONFIG;

	if (DPLL_Committed_Config_Valid &&
	    DPLL_Committed_Config.center_word_hi == center_word) {
		*candidate = DPLL_Committed_Config;
	} else {
		memset(candidate, 0, sizeof(*candidate));
		candidate->center_word_hi = center_word;
		candidate->profile = generated;
		candidate->mul_factor = 1U;
		candidate->div_factor = 1U;
		if (DPLL_Committed_Config_Valid) {
			candidate->profile.kf_track = DPLL_Committed_Config.profile.kf_track;
			candidate->profile.kp_blend = DPLL_Committed_Config.profile.kp_blend;
			candidate->profile.ki_blend = DPLL_Committed_Config.profile.ki_blend;
			candidate->profile.phase_setpoint =
				DPLL_Committed_Config.profile.phase_setpoint;
			candidate->profile.magnitude_enter =
				DPLL_Committed_Config.profile.magnitude_enter;
			candidate->profile.magnitude_exit =
				DPLL_Committed_Config.profile.magnitude_exit;
			candidate->profile.acquire_dwell =
				DPLL_Committed_Config.profile.acquire_dwell;
			candidate->profile.blend_dwell =
				DPLL_Committed_Config.profile.blend_dwell;
			candidate->profile.loss_dwell =
				DPLL_Committed_Config.profile.loss_dwell;
			candidate->profile.warmup_samples =
				DPLL_Committed_Config.profile.warmup_samples;
			candidate->profile.holdover_timeout =
				DPLL_Committed_Config.profile.holdover_timeout;
			candidate->profile.post_iir_mode =
				DPLL_Committed_Config.profile.post_iir_mode;
			candidate->manual_offset = DPLL_Committed_Config.manual_offset;
			candidate->dac0_offset = DPLL_Committed_Config.dac0_offset;
		}
	}

	candidate->center_word_hi = center_word;
	candidate->mul_factor = control_get_u16(CTRL_REG_OUTPUT_MUL);
	candidate->div_factor = control_get_u16(CTRL_REG_OUTPUT_DIV);
	candidate->profile.kp_track = (int32_t)control_get_u32(CTRL_REG_KP_TRACK);
	candidate->profile.ki_track = (int32_t)control_get_u32(CTRL_REG_KI_TRACK);
	candidate->profile.kf_acquire = (int32_t)control_get_u32(CTRL_REG_KF_ACQUIRE);
	candidate->profile.kf_blend = (int32_t)control_get_u32(CTRL_REG_KF_BLEND);
	candidate->profile.correction_limit_pos_hi =
		control_limit_word(control_get_s32(CTRL_REG_POS_LIMIT_HZ));
	candidate->profile.correction_limit_neg_hi =
		control_limit_word(control_get_s32(CTRL_REG_NEG_LIMIT_HZ));
	candidate->profile.phase_threshold =
		control_phase_raw(control_get_u16(CTRL_REG_PHASE_THRESHOLD_CDEG));
	candidate->profile.freq_threshold =
		control_frequency_raw(control_get_u16(CTRL_REG_FREQ_THRESHOLD_HZ));
	candidate->dac0_amplitude =
		(int16_t)control_amplitude_raw(control_get_u16(CTRL_REG_DAC_AMPLITUDE_MV));
	return DPLL_DRIVER_OK;
}

static uint8_t control_apply_bank(void)
{
	uint32_t center_word;
	uint32_t interval_cycles;
	dpll_config_t candidate;
	freq_meter_config_t meter_candidate;
	int apply_status;
	if (!control_validate_bank()) {
		control_report_error(CTRL_ERROR_RANGE);
		dpll_set_enable(0U);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}

	center_word = control_center_word(control_get_u32(CTRL_REG_CENTER_FREQ_DHZ));
	if (dpll_build_control_candidate(center_word, &candidate) != DPLL_DRIVER_OK) {
		control_report_error(CTRL_ERROR_APPLY);
		dpll_set_enable(0U);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}
	interval_cycles = (uint32_t)control_get_u16(CTRL_REG_FAST_INTERVAL_MS) * 125000UL;
	if (!Freq_Meter_Committed_Config_Valid) {
		control_report_error(CTRL_ERROR_APPLY);
		return 0U;
	}
	meter_candidate = Freq_Meter_Committed_Config;
	meter_candidate.fast_interval_cycles = interval_cycles;
	if (!freq_meter_validate_config(&meter_candidate)) {
		control_report_error(CTRL_ERROR_RANGE);
		return 0U;
	}

	apply_status = dpll_commit_candidate(&candidate);
	if (apply_status != DPLL_DRIVER_OK) {
		control_report_error((apply_status == DPLL_DRIVER_ERR_ABI) ?
		                     CTRL_ERROR_ABI : CTRL_ERROR_APPLY);
		dpll_set_enable(0U);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}
	if (!freq_meter_commit_candidate(&meter_candidate)) {
		control_report_error(CTRL_ERROR_RANGE);
		dpll_set_enable(0U);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}

	Control_DPLL_Enabled =
		(Control_Bank[CTRL_REG_CONTROL_FLAGS] & CTRL_FLAG_DPLL_ENABLE) ? 1U : 0U;
	if (dpll_set_enable(Control_DPLL_Enabled) != DPLL_DRIVER_OK) {
		control_report_error(CTRL_ERROR_ABI);
		Control_DPLL_Enabled = 0U;
		return 0U;
	}
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

static uint32_t control_dpll_output_millihz(void)
{
	uint32_t high_before;
	uint32_t high_after;
	uint32_t low;
	uint64_t scaled_high;
	uint64_t remainder;
	uint64_t millihz;
	uint32_t retry;
	for (retry = 0U; retry < 4U; ++retry) {
		high_before = Xil_In32(DPLL_TRACKING_WORD_HI_Addr) & 0xFFFFU;
		low = Xil_In32(PLL0_Output_Limit);
		high_after = Xil_In32(DPLL_TRACKING_WORD_HI_Addr) & 0xFFFFU;
		if (high_before == high_after) break;
	}
	if (high_before != high_after) return 0U;

	/* 125000000000 / 2^48 reduces to 244140625 / 2^39. */
	scaled_high = (uint64_t)high_after * 244140625ULL;
	millihz = scaled_high >> 7;
	remainder = ((scaled_high & 0x7FULL) << 32) +
	            (uint64_t)low * 244140625ULL;
	millihz += (remainder + (1ULL << 38)) >> 39;
	return millihz > 0xFFFFFFFFULL ? 0xFFFFFFFFUL : (uint32_t)millihz;
}

static void control_collect_runtime(void)
{
	uint32_t system_status = Xil_In32(System_Statue);
	uint32_t freq_meter_status = Xil_In32(Freq_Meter_System_Statue_Addr);
	uint32_t core_flags = Xil_In32(DPLL_CORE_FLAGS_Addr);
	uint32_t fast_meter_sequence;
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
	control_put_u32(CTRL_REG_OUTPUT_FREQ_MILLIHZ, control_dpll_output_millihz());
	control_put_u32(CTRL_REG_FAST_METER_HZ, control_fast_meter_hz());
	fast_meter_sequence = control_get_u32(CTRL_REG_FAST_METER_SEQ) &
	                      CTRL_FAST_METER_SEQ_MASK;
	if (freq_meter_status & 0x10U)
		fast_meter_sequence |= CTRL_FREQ_METER_LOCKED_MASK;
	control_put_u32(CTRL_REG_FAST_METER_SEQ, fast_meter_sequence);
	control_put_u32(CTRL_REG_ACTIVE_CONFIG_CRC, DPLL_Committed_Signature);
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

static void Control_Reset_Frequency_Meter(void)
{
	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 0U);
	Xil_Out32(Freq_Meter_Reset_Trigger_Addr, 0U);
	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 1U);
}

static void Control_Reset_Both(void)
{
	dpll_set_enable(0U);
	Control_DPLL_Enabled = 0U;
	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 0U);
	Xil_Out32(Opal_Kelly_Reset_Trigger_Addr, 0U);
	Xil_Out32(Freq_Meter_Reset_Trigger_Addr, 0U);
	usleep(100U);
	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 1U);
	Freq_Meter_Committed_Config_Valid = 0U;
	Debug_DAC_Committed_Config_Valid = 0U;
	dpll_invalidate_abi();
}

static void freq_meter_initialize_defaults(void)
{
	memset(&Freq_Meter_Committed_Config, 0,
	       sizeof(Freq_Meter_Committed_Config));
	Freq_Meter_Committed_Config.center_word = 0x51EB851EU;
	Freq_Meter_Committed_Config.phase_threshold = 1000U;
	Freq_Meter_Committed_Config.frequency_threshold = 500U;
	Freq_Meter_Committed_Config.positive_limit = 0x4FFFFFFFU;
	Freq_Meter_Committed_Config.negative_limit = 0xB0000000U;
	Freq_Meter_Committed_Config.gain_p = 0x00400000U;
	Freq_Meter_Committed_Config.gain_i = 0x00100000U;
	Freq_Meter_Committed_Config.gain_i2 = 0x00000100U;
	Xil_Out32(Freq_Meter_Coefd_Filter_Addr, FREQ_METER_D_FILTER_COEFF);
	Freq_Meter_Committed_Config.gate_time_low = 125000000U;
	Freq_Meter_Committed_Config.fast_interval_cycles = 62500000U;
	Freq_Meter_Committed_Config_Valid = 0U;
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
	Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = CTRL_DEBUG_DAC_PRESET_DEFAULT;
	if (!control_uart_write(CTRL_REG_DEBUG_DAC_PRESET, 1U,
	                        &Control_Bank[CTRL_REG_DEBUG_DAC_PRESET])) return 0U;
	Control_Debug_Preset_Seen = CTRL_DEBUG_DAC_PRESET_MANUAL;
	Control_Reset_Both();
	if (!freq_meter_commit_candidate(&Freq_Meter_Committed_Config)) {
		control_report_error(CTRL_ERROR_RANGE);
		return 0U;
	}
	if (!dpll_initialize_abi()) {
		control_report_error(CTRL_ERROR_ABI);
	} else {
		control_apply_bank();
		Control_Apply_Debug_DAC_Preset(CTRL_DEBUG_DAC_PRESET_DEFAULT);
		Control_Debug_Preset_Seen = CTRL_DEBUG_DAC_PRESET_DEFAULT;
	}
	Control_Request_Seen = Control_Bank[CTRL_REG_REQUEST_SEQ];
	Control_Bank[CTRL_REG_RESPONSE_SEQ] = Control_Request_Seen;
	control_collect_runtime();
	return control_publish_runtime();
}

static void Control_Link_Service(void)
{
	uint8_t header[CTRL_REG_DEBUG_DAC_PRESET - CTRL_REG_REQUEST_SEQ + 1U];
	uint8_t previous[CTRL_PERSIST_END - CTRL_PERSIST_BEGIN];
	uint8_t request_sequence;
	uint8_t debug_preset;
	uint8_t apply_error;
	if (++Control_Service_Divider < CONTROL_SERVICE_PERIOD_LOOPS) return;
	Control_Service_Divider = 0U;
	if (!control_uart_read(CTRL_REG_REQUEST_SEQ, sizeof(header), header)) {
		return;
	}
	request_sequence = header[0];
	debug_preset = header[CTRL_REG_DEBUG_DAC_PRESET - CTRL_REG_REQUEST_SEQ];
	Control_Bank[CTRL_REG_CONTROL_FLAGS] =
		header[CTRL_REG_CONTROL_FLAGS - CTRL_REG_REQUEST_SEQ];
	Control_Bank[CTRL_REG_MWS_STATUS] =
		header[CTRL_REG_MWS_STATUS - CTRL_REG_REQUEST_SEQ];
	if (request_sequence != Control_Request_Seen) {
		memcpy(previous, &Control_Bank[CTRL_PERSIST_BEGIN], sizeof(previous));
		memcpy(&Control_Bank[CTRL_REG_REQUEST_SEQ], header,
		       CTRL_PERSIST_END - CTRL_REG_REQUEST_SEQ);
		Control_Request_Seen = request_sequence;
		if (!control_apply_bank()) {
			apply_error = Control_Last_Error;
			control_restore_persistent(previous, apply_error, 1U);
		}
		Control_Bank[CTRL_REG_RESPONSE_SEQ] = Control_Request_Seen;
	}
	if (debug_preset == CONTROL_FREQ_METER_RESET_REQUEST) {
		if (!Control_Freq_Meter_Reset_Request_Seen) {
			Control_Freq_Meter_Reset_Request_Seen = 1U;
			Control_Reset_Frequency_Meter();
		}
		Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = Control_Debug_Preset_Seen;
		control_uart_write(CTRL_REG_DEBUG_DAC_PRESET, 1U,
		                   &Control_Bank[CTRL_REG_DEBUG_DAC_PRESET]);
	} else if (debug_preset != Control_Debug_Preset_Seen) {
		Control_Freq_Meter_Reset_Request_Seen = 0U;
		if (debug_preset <= CTRL_DEBUG_DAC_PRESET_MAX) {
			Control_Apply_Debug_DAC_Preset(debug_preset);
			Control_Bank[CTRL_REG_DEBUG_DAC_PRESET] = debug_preset;
			Control_Debug_Preset_Seen = debug_preset;
		} else {
			control_uart_write(CTRL_REG_DEBUG_DAC_PRESET, 1U,
			                   &Control_Bank[CTRL_REG_DEBUG_DAC_PRESET]);
		}
	} else {
		Control_Freq_Meter_Reset_Request_Seen = 0U;
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
		return 0U;
	}
	control_report_error(original_error);
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
	freq_meter_initialize_defaults();

	while (!Control_Link_Startup()) {
		CONTROL_DCC_LOG("control link startup failed, retrying\r\n");
		usleep(100000U);
	}

	Xil_Out32(Freq_Meter_Lock_Ctrl_Addr, 1U);

    XUartPs_SendByte(XUartPs_uart0.Config.BaseAddress,'C');


	while(1)
	{
		PC_HOST_CMD_Respond();
		control_error_hold_service();
		Control_Link_Service();
		usleep(1000U);
    }
    cleanup_platform();
    return 0;
}
