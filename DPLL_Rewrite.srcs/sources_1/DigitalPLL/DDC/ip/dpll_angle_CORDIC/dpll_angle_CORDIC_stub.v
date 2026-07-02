// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Thu Jul  2 19:19:08 2026
// Host        : DESKTOP-MRF396F running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/dpll_angle_CORDIC/dpll_angle_CORDIC_stub.v
// Design      : dpll_angle_CORDIC
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "cordic_v6_0_14,Vivado 2018.3" *)
module dpll_angle_CORDIC(aclk, aresetn, s_axis_cartesian_tvalid, 
  s_axis_cartesian_tready, s_axis_cartesian_tdata, m_axis_dout_tvalid, 
  m_axis_dout_tready, m_axis_dout_tdata)
/* synthesis syn_black_box black_box_pad_pin="aclk,aresetn,s_axis_cartesian_tvalid,s_axis_cartesian_tready,s_axis_cartesian_tdata[47:0],m_axis_dout_tvalid,m_axis_dout_tready,m_axis_dout_tdata[47:0]" */;
  input aclk;
  input aresetn;
  input s_axis_cartesian_tvalid;
  output s_axis_cartesian_tready;
  input [47:0]s_axis_cartesian_tdata;
  output m_axis_dout_tvalid;
  input m_axis_dout_tready;
  output [47:0]m_axis_dout_tdata;
endmodule
