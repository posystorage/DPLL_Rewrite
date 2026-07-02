// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Wed Jul  1 15:48:30 2026
// Host        : DESKTOP-MRF396F running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/DAC_DDS0/DAC_DDS0_stub.v
// Design      : DAC_DDS0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "dds_compiler_v6_0_17,Vivado 2018.3" *)
module DAC_DDS0(aclk, s_axis_phase_tvalid, 
  s_axis_phase_tdata, m_axis_data_tvalid, m_axis_data_tdata)
/* synthesis syn_black_box black_box_pad_pin="aclk,s_axis_phase_tvalid,s_axis_phase_tdata[47:0],m_axis_data_tvalid,m_axis_data_tdata[15:0]" */;
  input aclk;
  input s_axis_phase_tvalid;
  input [47:0]s_axis_phase_tdata;
  output m_axis_data_tvalid;
  output [15:0]m_axis_data_tdata;
endmodule
