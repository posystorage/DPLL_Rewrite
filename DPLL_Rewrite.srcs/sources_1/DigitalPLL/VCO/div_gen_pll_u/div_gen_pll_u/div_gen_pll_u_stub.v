// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Sun Jun 28 21:16:15 2026
// Host        : MiaoZhi-PC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               E:/FPGA/DPLL_Rewrite/DPLL_Rewrite_THbox_T3/DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/div_gen_pll_u/div_gen_pll_u/div_gen_pll_u_stub.v
// Design      : div_gen_pll_u
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "div_gen_v5_1_14,Vivado 2018.3" *)
module div_gen_pll_u(aclk, s_axis_divisor_tvalid, 
  s_axis_divisor_tdata, s_axis_dividend_tvalid, s_axis_dividend_tdata, 
  m_axis_dout_tvalid, m_axis_dout_tdata)
/* synthesis syn_black_box black_box_pad_pin="aclk,s_axis_divisor_tvalid,s_axis_divisor_tdata[15:0],s_axis_dividend_tvalid,s_axis_dividend_tdata[63:0],m_axis_dout_tvalid,m_axis_dout_tdata[79:0]" */;
  input aclk;
  input s_axis_divisor_tvalid;
  input [15:0]s_axis_divisor_tdata;
  input s_axis_dividend_tvalid;
  input [63:0]s_axis_dividend_tdata;
  output m_axis_dout_tvalid;
  output [79:0]m_axis_dout_tdata;
endmodule
