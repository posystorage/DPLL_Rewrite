// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Sun Jun 28 21:34:23 2026
// Host        : MiaoZhi-PC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               E:/FPGA/DPLL_Rewrite/DPLL_Rewrite_THbox_T3/DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/pre_iq_cic_40_125m_v1/pre_iq_cic_40_125m_v1/pre_iq_cic_40_125m_v1_stub.v
// Design      : pre_iq_cic_40_125m_v1
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "cic_compiler_v4_0_13,Vivado 2018.3" *)
module pre_iq_cic_40_125m_v1(aclk, s_axis_data_tdata, s_axis_data_tvalid, 
  s_axis_data_tready, m_axis_data_tdata, m_axis_data_tvalid)
/* synthesis syn_black_box black_box_pad_pin="aclk,s_axis_data_tdata[15:0],s_axis_data_tvalid,s_axis_data_tready,m_axis_data_tdata[15:0],m_axis_data_tvalid" */;
  input aclk;
  input [15:0]s_axis_data_tdata;
  input s_axis_data_tvalid;
  output s_axis_data_tready;
  output [15:0]m_axis_data_tdata;
  output m_axis_data_tvalid;
endmodule
