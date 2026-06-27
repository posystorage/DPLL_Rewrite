// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Sat Mar 28 17:48:08 2020
// Host        : LeakyShip running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim {D:/dual-comb spectroscopy/Frequency-comb-DPLL-master/Firmware Vivado
//               Project/redpitaya.srcs/sources_1/ip/input_multiplier/input_multiplier_sim_netlist.v}
// Design      : input_multiplier
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "input_multiplier,mult_gen_v12_0_14,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "mult_gen_v12_0_14,Vivado 2018.3" *) 
(* NotValidForBitStream *)
module input_multiplier
   (CLK,
    A,
    B,
    P);
  (* x_interface_info = "xilinx.com:signal:clock:1.0 clk_intf CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME clk_intf, ASSOCIATED_BUSIF p_intf:b_intf:a_intf, ASSOCIATED_RESET sclr, ASSOCIATED_CLKEN ce, FREQ_HZ 10000000, PHASE 0.000, INSERT_VIP 0" *) input CLK;
  (* x_interface_info = "xilinx.com:signal:data:1.0 a_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME a_intf, LAYERED_METADATA undef" *) input [15:0]A;
  (* x_interface_info = "xilinx.com:signal:data:1.0 b_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME b_intf, LAYERED_METADATA undef" *) input [15:0]B;
  (* x_interface_info = "xilinx.com:signal:data:1.0 p_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME p_intf, LAYERED_METADATA undef" *) output [31:0]P;

  wire [15:0]A;
  wire [15:0]B;
  wire CLK;
  wire [31:0]P;
  wire [47:0]NLW_U0_PCASC_UNCONNECTED;
  wire [1:0]NLW_U0_ZERO_DETECT_UNCONNECTED;

  (* C_A_TYPE = "0" *) 
  (* C_A_WIDTH = "16" *) 
  (* C_B_TYPE = "0" *) 
  (* C_B_VALUE = "10000001" *) 
  (* C_B_WIDTH = "16" *) 
  (* C_CCM_IMP = "0" *) 
  (* C_CE_OVERRIDES_SCLR = "0" *) 
  (* C_HAS_CE = "0" *) 
  (* C_HAS_SCLR = "0" *) 
  (* C_HAS_ZERO_DETECT = "0" *) 
  (* C_LATENCY = "1" *) 
  (* C_MODEL_TYPE = "0" *) 
  (* C_MULT_TYPE = "1" *) 
  (* C_OPTIMIZE_GOAL = "1" *) 
  (* C_OUT_HIGH = "31" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "zynq" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  input_multiplier_mult_gen_v12_0_14 U0
       (.A(A),
        .B(B),
        .CE(1'b1),
        .CLK(CLK),
        .P(P),
        .PCASC(NLW_U0_PCASC_UNCONNECTED[47:0]),
        .SCLR(1'b0),
        .ZERO_DETECT(NLW_U0_ZERO_DETECT_UNCONNECTED[1:0]));
endmodule

(* C_A_TYPE = "0" *) (* C_A_WIDTH = "16" *) (* C_B_TYPE = "0" *) 
(* C_B_VALUE = "10000001" *) (* C_B_WIDTH = "16" *) (* C_CCM_IMP = "0" *) 
(* C_CE_OVERRIDES_SCLR = "0" *) (* C_HAS_CE = "0" *) (* C_HAS_SCLR = "0" *) 
(* C_HAS_ZERO_DETECT = "0" *) (* C_LATENCY = "1" *) (* C_MODEL_TYPE = "0" *) 
(* C_MULT_TYPE = "1" *) (* C_OPTIMIZE_GOAL = "1" *) (* C_OUT_HIGH = "31" *) 
(* C_OUT_LOW = "0" *) (* C_ROUND_OUTPUT = "0" *) (* C_ROUND_PT = "0" *) 
(* C_VERBOSITY = "0" *) (* C_XDEVICEFAMILY = "zynq" *) (* ORIG_REF_NAME = "mult_gen_v12_0_14" *) 
(* downgradeipidentifiedwarnings = "yes" *) 
module input_multiplier_mult_gen_v12_0_14
   (CLK,
    A,
    B,
    CE,
    SCLR,
    ZERO_DETECT,
    P,
    PCASC);
  input CLK;
  input [15:0]A;
  input [15:0]B;
  input CE;
  input SCLR;
  output [1:0]ZERO_DETECT;
  output [31:0]P;
  output [47:0]PCASC;

  wire \<const0> ;
  wire [15:0]A;
  wire [15:0]B;
  wire CLK;
  wire [31:0]P;
  wire [47:0]NLW_i_mult_PCASC_UNCONNECTED;
  wire [1:0]NLW_i_mult_ZERO_DETECT_UNCONNECTED;

  assign PCASC[47] = \<const0> ;
  assign PCASC[46] = \<const0> ;
  assign PCASC[45] = \<const0> ;
  assign PCASC[44] = \<const0> ;
  assign PCASC[43] = \<const0> ;
  assign PCASC[42] = \<const0> ;
  assign PCASC[41] = \<const0> ;
  assign PCASC[40] = \<const0> ;
  assign PCASC[39] = \<const0> ;
  assign PCASC[38] = \<const0> ;
  assign PCASC[37] = \<const0> ;
  assign PCASC[36] = \<const0> ;
  assign PCASC[35] = \<const0> ;
  assign PCASC[34] = \<const0> ;
  assign PCASC[33] = \<const0> ;
  assign PCASC[32] = \<const0> ;
  assign PCASC[31] = \<const0> ;
  assign PCASC[30] = \<const0> ;
  assign PCASC[29] = \<const0> ;
  assign PCASC[28] = \<const0> ;
  assign PCASC[27] = \<const0> ;
  assign PCASC[26] = \<const0> ;
  assign PCASC[25] = \<const0> ;
  assign PCASC[24] = \<const0> ;
  assign PCASC[23] = \<const0> ;
  assign PCASC[22] = \<const0> ;
  assign PCASC[21] = \<const0> ;
  assign PCASC[20] = \<const0> ;
  assign PCASC[19] = \<const0> ;
  assign PCASC[18] = \<const0> ;
  assign PCASC[17] = \<const0> ;
  assign PCASC[16] = \<const0> ;
  assign PCASC[15] = \<const0> ;
  assign PCASC[14] = \<const0> ;
  assign PCASC[13] = \<const0> ;
  assign PCASC[12] = \<const0> ;
  assign PCASC[11] = \<const0> ;
  assign PCASC[10] = \<const0> ;
  assign PCASC[9] = \<const0> ;
  assign PCASC[8] = \<const0> ;
  assign PCASC[7] = \<const0> ;
  assign PCASC[6] = \<const0> ;
  assign PCASC[5] = \<const0> ;
  assign PCASC[4] = \<const0> ;
  assign PCASC[3] = \<const0> ;
  assign PCASC[2] = \<const0> ;
  assign PCASC[1] = \<const0> ;
  assign PCASC[0] = \<const0> ;
  assign ZERO_DETECT[1] = \<const0> ;
  assign ZERO_DETECT[0] = \<const0> ;
  GND GND
       (.G(\<const0> ));
  (* C_A_TYPE = "0" *) 
  (* C_A_WIDTH = "16" *) 
  (* C_B_TYPE = "0" *) 
  (* C_B_VALUE = "10000001" *) 
  (* C_B_WIDTH = "16" *) 
  (* C_CCM_IMP = "0" *) 
  (* C_CE_OVERRIDES_SCLR = "0" *) 
  (* C_HAS_CE = "0" *) 
  (* C_HAS_SCLR = "0" *) 
  (* C_HAS_ZERO_DETECT = "0" *) 
  (* C_LATENCY = "1" *) 
  (* C_MODEL_TYPE = "0" *) 
  (* C_MULT_TYPE = "1" *) 
  (* C_OPTIMIZE_GOAL = "1" *) 
  (* C_OUT_HIGH = "31" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "zynq" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  input_multiplier_mult_gen_v12_0_14_viv i_mult
       (.A(A),
        .B(B),
        .CE(1'b0),
        .CLK(CLK),
        .P(P),
        .PCASC(NLW_i_mult_PCASC_UNCONNECTED[47:0]),
        .SCLR(1'b0),
        .ZERO_DETECT(NLW_i_mult_ZERO_DETECT_UNCONNECTED[1:0]));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2015"
`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="cds_rsa_key", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=64)
`pragma protect key_block
g7azmhtm6FcP7uNFjuXJjN8Z6yccOPk3SSjzvKB27peFKmnPmQmov5+YTGwYqqN9LpdyiUExk8K6
vPnJqontvQ==

`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
MFrqn2K0Cr7TmQ5al162oDGiY83d+AkTWOgFyXPYrTNznygR/tx44RAp24ytphNK9p6shs2EFMg/
Qqz0l8DCWiVEoJ/T8vMpnAn7Y+poGVGS1qAR3qE2njrl81VcGBZJeFaWIudhfr/DLTuuf2T/dWDU
YpelM3KbfYNPPiPy8PU=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
FZca5XZouG+/BYoQ8qrJTmnJanku4IprIWRkO6VciHehE5WehR0wsZJhfKlqLEeY1oTPA4bXaxmY
NjYkrop4EOwW8t47/hj2kFLI1OKUAE/TAhCGg/aNSOViUbB3dUomG/y+TBuDt9L6g0Arj1vb/5Pt
IChc5ZdEfRr1lJMTpFfP+5qmEH6lePPdzgPZATPB4Zrj0P6EyiEsU1FKBuAKd9iYNGiLCxVomaz0
3/RwK2Nl+/l4mc7PJt5Hso+4s1qHb4s2wD+OgbIwdH26ZkEnKVFpaLiuWQKu9uhDLGnsBMPf7XDE
p29f+mrvP9Zi/3nonA2aBKrTwR7XuH+ZYoakxA==

`pragma protect key_keyowner="ATRENTA", key_keyname="ATR-SG-2015-RSA-3", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
jP68OjlYJglq3zpmKrXOhq7Sex8XNW8fQKp4hUNmuw06OOoKhQASNTnjtyVjAIk/VXb64ViBu1ds
cNMJybDSWBhnChfJq4h9PNybShGJXxSm3NDOo5wUHKf10Eti3fSotB9rVks+tNdTEZo4O97kgfdD
G1FNOqlsYcQiShEGLLiEQ2yYtgJBxJ+jc8mFjIEfPhAYy1ElrvtFEpnhkNS2LfE7xdWOQdO/XoKK
ibeY08pgncTI3pvO6TMbXushf0AX2S7hgfk8ysZrT+0gktqFrJnyR6oljS6VVPLtRNW2vo/cC8XQ
Bzvwwt4cpSo5KLS4XxB6qClZipItck2AUEdIbQ==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2017_05", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
o7jAZIoXlFbFtDYmtXhfRBlb07dhBb6Wp03mlT4T0FXtvccSHWhWZgc+VUNwt6TohLihOwvSipPP
XVXpGL4pUVYNdQBCVpFzhMkt6jhyUgsF5t10yI5Of6YEfQrDHigceoBukM3+/zJHPprrPQE6FUvC
wXSGhBCXnHJs1R+n4l0714w8/WftPQhlD9QGQp1qT2VARQXUKBRxcRjxe9TcLfs0P4xnN7uHu0R6
JTmV+MHmhGpetSZGx+B2Wa1MQofUPURqwE70IwBoUhdXH8+39DT5I6x2+wMY6RcVATnhNd2BCgPd
RzAhwfrcqRiU9aB+eNNdFR8ve9M2nGMmV2JxZg==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
Cl1Dz+fZIDYEIQuUd0pSg+5jknmtX/JERd+yOZ2SRaVra/4pU/eCTjEXMzhz4VFGYB6dgUxMsGBk
nL2WNdn/uaSPpi6mNF0UHQvZik4pUkYPrnRbFveVqW8i1t95SG0RW96uD19206lWrp5U1lqc4fH7
sfKHi8ZpU3MAg0DOO0E=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Qqp76m2aV9ue8Qai7QUavb+lhRYdu/txrnwYLzwTe0vS0S2OD1vxr8VeIT3bF/ZuXlTGm4S/UCSF
bgOPp7VqEOeGNfsSPK+VpQ+foQMENCQYccwKquBDSg/sLjpPK9uuoGLBLxjw2OwsRzplVFXiPcRN
LYK1/FmCP7RJBNgmhh/ti99a+WSl6i2YIIRGocNplQlG8FXq8ZTTHd/x2Gtdf/zGvJOy/fNsos6S
Oq9yJ0rMmbGeWbri5c04gZM08pUmXBsivgOHm2IVEZZFM4SBqrsi0xa52hs2kelc3iKJcWiTvU3X
0fJP9qNFuIjXBPPZvEYwhVtIh6DwiIC2viSscQ==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-PREC-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
VA+VEbOAeg0xh1M6d3q5LM3udyM+v5bkW6XS1VHLVbj1Bo9lGsq17JSmFIpK6cMtPs4JQ9uRIk/J
vda8YfsI5mzadPaSSb1upeNyNeTKYBL3nnFejzC0GxC6J+0WhygodiBqTzddvbPVY8wtQJal6iMd
IjhujwGbfMZg/K1LB2USq+vENwe62qN8/qQJLwbFabFG8TYAdepbHMSJ9EUqLH/KHIfAFqfOHI4J
+vnCnOpRYo9C2CMYAXuU/wIvU/DVXNVI0N218B2VJeI3pmoYGjNyq5EAWswk4F7YOLcfiOyvj5Cz
wQEqW0yHs6EXtIucGauTumd3FYa9uzcC+UZAMQ==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
QHTzxDxaVTD4w00Fu0lrbS3H7tSUDLQRQXEqLKfuOB93hhXXcmLnmhqX6HVXNVZGQUckTohnQ6+Y
aKVdWo7DlB+Ws7K0NgFL6WU88EHzYsRhzj0yVYKDVdCodNsHvvQh3uEXVwkZf/dPWEmkLR2mnVTq
WTix/jZNLSZo/CsEpFwLHCTdmo6zNIvzfsIbEUMyrqUMstWO6jPZoAQM2wsVBK7S4ZrdOxBd96UR
CUKEB52beOhgeiJRXOqGepwFzZykCkZM3SmAJmGjPeJR0JvjU+LzJ3gTcRydwVUyXZ27Gd4qLrMi
58ozK2sM3A5SK4CGeL44aaPmoPcteopulVlwgQ==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 7248)
`pragma protect data_block
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
lhv7s2kE9Qc0
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule
`endif
