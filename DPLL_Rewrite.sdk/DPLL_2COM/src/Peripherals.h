#ifndef _Peripherals_h_
#define _Peripherals_h_


#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"

#define M_AXI_GP0_Base_Addr 0x40000000
#define FREQ_METER_BASE_ADDR (M_AXI_GP0_Base_Addr+0x200000)
#define DPLL_BASE_ADDR (M_AXI_GP0_Base_Addr+0x600000)




#define Freq_Meter_Reset_Trigger_Addr (FREQ_METER_BASE_ADDR|(0x0000<<2))

#define Freq_Meter_Centre_Frequency_Addr (FREQ_METER_BASE_ADDR|(0x0010<<2))//32bit

#define Freq_Meter_Lock_Ctrl_Addr (FREQ_METER_BASE_ADDR|(0x0020<<2))//1bit
#define Freq_Meter_PID_GainP_Addr (FREQ_METER_BASE_ADDR|(0x0021<<2))//32bit-div13
#define Freq_Meter_PID_GainI_Addr (FREQ_METER_BASE_ADDR|(0x0022<<2))//32bit-div24
#define Freq_Meter_PID_GainI2_Addr (FREQ_METER_BASE_ADDR|(0x0023<<2))//32bit-div35
#define Freq_Meter_PID_GainD_Addr (FREQ_METER_BASE_ADDR|(0x0024<<2))//32bit-div0
#define Freq_Meter_Coefd_Filter_Addr (FREQ_METER_BASE_ADDR|(0x0025<<2))//18Bit

#define Freq_Meter_Freq_Pos_Limit_Addr (FREQ_METER_BASE_ADDR|(0x0028<<2))//16bit positive_limit_dac0
#define Freq_Meter_Freq_Neg_Limit_Addr (FREQ_METER_BASE_ADDR|(0x0029<<2))//16bit negative_limit_dac0
#define Freq_Meter_Freq_Manual_Offset_Addr (FREQ_METER_BASE_ADDR|(0x002A<<2))//16bit

#define Freq_Meter_Phase_Residuals_Threshold_Addr (FREQ_METER_BASE_ADDR|(0x0050<<2))//Phase_Residuals 32bit
#define Freq_Meter_Phase_Residuals_Offset_Addr (FREQ_METER_BASE_ADDR|(0x0051<<2))//Phase_Residuals 32bit
#define Freq_Meter_Freq_Residuals_Threshold_Addr (FREQ_METER_BASE_ADDR|(0x0052<<2))//Frequency_Residuals 10bit


#define Freq_Meter_Gate_Time_L_Addr (FREQ_METER_BASE_ADDR|(0x0070<<2))
#define Freq_Meter_Gate_Time_H_Addr (FREQ_METER_BASE_ADDR|(0x0071<<2))
#define Freq_Meter_Run_Trigger_Addr (FREQ_METER_BASE_ADDR|(0x0072<<2))

#define Freq_Meter_System_Statue_Addr   (FREQ_METER_BASE_ADDR|(0x0100<<2))// LED_R0,LED_G0,dac0_railed_positive,dac0_railed_negative,residuals0_are_above_threshold_freq,residuals0_are_above_threshold_phase
#define Freq_Meter_Amplitude_Addr   (FREQ_METER_BASE_ADDR|(0x0101<<2))//16bits
#define Freq_Meter_wrapped_phase_Addr   (FREQ_METER_BASE_ADDR|(0x0102<<2))//14bits
#define Freq_Meter_inst_frequency_Addr   (FREQ_METER_BASE_ADDR|(0x0103<<2))//14bits

#define Freq_Meter_PLL_Output_Addr  		 (FREQ_METER_BASE_ADDR|(0x0104<<2))//32bits
#define Freq_Meter_PLL_Output_Limit_Addr    (FREQ_METER_BASE_ADDR|(0x0105<<2))//32bits
#define Freq_Meter_PLL_phase_residuals_Addr    (FREQ_METER_BASE_ADDR|(0x0106<<2))//32bits
#define Freq_Meter_PLL_DDC_phase_Add_Addr    (FREQ_METER_BASE_ADDR|(0x0107<<2))//32bits


#define Freq_Meter_Run_Statue_Addr  		 (FREQ_METER_BASE_ADDR|(0x0110<<2))//1bits
#define Freq_Meter_DataL_Output_Addr  		 (FREQ_METER_BASE_ADDR|(0x0111<<2))//32bits
#define Freq_Meter_DataM_Output_Addr  		 (FREQ_METER_BASE_ADDR|(0x0112<<2))//32bits
#define Freq_Meter_DataH_Output_Addr  		 (FREQ_METER_BASE_ADDR|(0x0113<<2))//16bits






#define Opal_Kelly_Reset_Trigger_Addr (DPLL_BASE_ADDR|(0x0000<<2))

#define DAC0_Centre_Frequency_Addr (DPLL_BASE_ADDR|(0x0010<<2))//32bit
   /* wrapped_phase_internal <= wrapped_phase_cordic(wrapped_phase_internal'range) when b"0000",
                              Q_quantized                                        when b"0001",
                              Q_limited                                          when b"0010",
                              I_quantized                                        when b"0011",
                              I_limited                                          when b"0100",
                              (others => '0')                                    when others;
  */
#define DAC0_DDC_Angle_Select_Addr (DPLL_BASE_ADDR|(0x0011<<2))//4bit angleSelect_0


//DPLL v1 loop control.
#define PLL0_Lock_Ctrl_Addr (DPLL_BASE_ADDR|(0x0020<<2))//1bit
#define DPLL_PLL_KP_TRACK_Addr (DPLL_BASE_ADDR|(0x0021<<2))//DPLL_KP_TRACK[23:0]
#define DPLL_PLL_KI_TRACK_Addr (DPLL_BASE_ADDR|(0x0022<<2))//DPLL_KI_TRACK[23:0]
#define DPLL_FLL_KF_ACQUIRE_Addr (DPLL_BASE_ADDR|(0x0023<<2))//DPLL_KF_ACQUIRE[23:0]
#define DPLL_FLL_KF_BLEND_Addr (DPLL_BASE_ADDR|(0x0024<<2))//DPLL_KF_BLEND[23:0]
#define DPLL_FLL_KF_TRACK_Addr (DPLL_BASE_ADDR|(0x0025<<2))//DPLL_KF_TRACK[23:0]
#define DPLL_PLL_KP_BLEND_Addr (DPLL_BASE_ADDR|(0x0026<<2))//DPLL_KP_BLEND[23:0]
#define DPLL_PLL_KI_BLEND_Addr (DPLL_BASE_ADDR|(0x0027<<2))//DPLL_KI_BLEND[23:0]

#define DPLL_FREQ_POS_LIMIT_Addr (DPLL_BASE_ADDR|(0x0028<<2))//32bit positive_limit_dac0
#define DPLL_FREQ_NEG_LIMIT_Addr (DPLL_BASE_ADDR|(0x0029<<2))//32bit negative_limit_dac0
#define VCO_Freq_Manual_Offset_Addr (DPLL_BASE_ADDR|(0x002A<<2))//16bit

//DAC0
#define DAC0_VCO_Offset_Addr (DPLL_BASE_ADDR|(0x0030<<2))//offset 14bit;
#define DAC0_VOC_Amplitude_Addr (DPLL_BASE_ADDR|(0x0031<<2))//amplitude 15bit;
#define VOC_Fre_Mul_Addr (DPLL_BASE_ADDR|(0x0032<<2))//amplitude 15bit;
#define VOC_Fre_Div_Addr (DPLL_BASE_ADDR|(0x0033<<2))//amplitude 15bit;

//DAC1 is a debug output only, not a second DPLL.
#define DAC1_DDS_Offset_Addr (DPLL_BASE_ADDR|(0x0040<<2))//debug offset 14bit;
#define DAC1_DDS_Amplitude_Addr (DPLL_BASE_ADDR|(0x0041<<2))//debug gain 16bit;
#define DAC1_DDS_Frequency_Addr (DPLL_BASE_ADDR|(0x0042<<2))//debug source select;
#define DAC1_DDS_Phase_Addr (DPLL_BASE_ADDR|(0x0043<<2))//debug format/reserved


//用于锁定指示
#define DAC0_Phase_Residuals_Threshold_Addr (DPLL_BASE_ADDR|(0x0050<<2))//Phase_Residuals 32bit
#define DAC0_Phase_Residuals_Offset_Addr (DPLL_BASE_ADDR|(0x0051<<2))//Phase_Residuals 32bit
#define DAC0_Freq_Residuals_Threshold_Addr (DPLL_BASE_ADDR|(0x0052<<2))//Frequency_Residuals 10bit
#define DPLL_MAG_ENTER_THRESHOLD_Addr (DPLL_BASE_ADDR|(0x0053<<2))
#define DPLL_MAG_EXIT_THRESHOLD_Addr (DPLL_BASE_ADDR|(0x0054<<2))
#define DPLL_ACQUIRE_DWELL_Addr (DPLL_BASE_ADDR|(0x0055<<2))
#define DPLL_BLEND_DWELL_Addr (DPLL_BASE_ADDR|(0x0056<<2))
#define DPLL_LOSS_DWELL_Addr (DPLL_BASE_ADDR|(0x0057<<2))
#define DPLL_HOLDOVER_TIMEOUT_Addr (DPLL_BASE_ADDR|(0x0058<<2))

//DPLL v1 post-IQ CIC/FLL configuration. R/shift writes are shadowed; write
//DPLL_CONFIG_APPLY_Addr to atomically apply them in the DPLL clock-valid domain.
#define DPLL_POST_IQ_CIC_R_Addr (DPLL_BASE_ADDR|(0x0060<<2))
#define DPLL_POST_IQ_CIC_SHIFT_Addr (DPLL_BASE_ADDR|(0x0061<<2))
#define DPLL_FLL_DELAY_SEL_Addr (DPLL_BASE_ADDR|(0x0062<<2))
#define DPLL_WARMUP_SAMPLES_Addr (DPLL_BASE_ADDR|(0x0063<<2))
#define DPLL_CONFIG_APPLY_Addr (DPLL_BASE_ADDR|(0x006F<<2))



//只读
#define System_Statue   (DPLL_BASE_ADDR|(0x0100<<2))// LED_R0,LED_G0,dac0_railed_positive,dac0_railed_negative,residuals0_are_above_threshold_freq,residuals0_are_above_threshold_phase
#define DDC0_Amplitude   (DPLL_BASE_ADDR|(0x0101<<2))//16bits
#define DDC0_wrapped_phase   (DPLL_BASE_ADDR|(0x0102<<2))//DPLL phase_error sign-extended
#define DDC0_inst_frequency   (DPLL_BASE_ADDR|(0x0103<<2))//DPLL freq_error sign-extended

#define PLL0_Output          (DPLL_BASE_ADDR|(0x0104<<2))//freq_correction[31:0]
#define PLL0_Output_Limit    (DPLL_BASE_ADDR|(0x0105<<2))//tracking_word[31:0]
#define PLL0_phase_residuals    (DPLL_BASE_ADDR|(0x0106<<2))//phase_error sign-extended
#define PLL0_Output_Limit_Average    (DPLL_BASE_ADDR|(0x0107<<2))//freq_state[31:0]

#define DPLL_CORE_FLAGS_Addr (DPLL_BASE_ADDR|(0x0108<<2))
#define DPLL_LOOP_STATE_LOSS_REASON_Addr DPLL_CORE_FLAGS_Addr
#define DPLL_ACTIVE_CIC_CONFIG_Addr (DPLL_BASE_ADDR|(0x0109<<2))
#define DPLL_TRACKING_WORD_HI_Addr (DPLL_BASE_ADDR|(0x010A<<2))
#define DPLL_VCO_WORD_LO_Addr (DPLL_BASE_ADDR|(0x010B<<2))
#define DPLL_VCO_WORD_HI_Addr (DPLL_BASE_ADDR|(0x010C<<2))
#define DPLL_CONFIG_VERSION_Addr (DPLL_BASE_ADDR|(0x010D<<2))
#define DPLL_ABI_VERSION_Addr (DPLL_BASE_ADDR|(0x010E<<2))
#define DPLL_FPGA_BUILD_ID_Addr (DPLL_BASE_ADDR|(0x010F<<2))
#define PLL0_Test_Reg DPLL_FPGA_BUILD_ID_Addr

#endif
