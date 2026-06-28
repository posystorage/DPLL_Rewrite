// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Sun Jun 28 11:18:03 2026
// Host        : MiaoZhi-PC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               E:/FPGA/DPLL_Rewrite/DPLL_Rewrite_THbox_T3/DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/mult_gen_pll/mult_gen_pll_stub.v
// Design      : mult_gen_pll
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "mult_gen_v12_0_14,Vivado 2018.3" *)
module mult_gen_pll(CLK, A, B, P)
/* synthesis syn_black_box black_box_pad_pin="CLK,A[47:0],B[15:0],P[63:0]" */;
  input CLK;
  input [47:0]A;
  input [15:0]B;
  output [63:0]P;
endmodule
