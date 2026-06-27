// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Thu Sep 10 14:59:06 2020
// Host        : LeakyShip running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               d:/FPGA_DPLL/DPLL_Rewrite/DPLL_Rewrite.srcs/sources_1/DigitalPLL/VCO/mult_gen_pll/mult_gen_pll_sim_netlist.v
// Design      : mult_gen_pll
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "mult_gen_pll,mult_gen_v12_0_14,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "mult_gen_v12_0_14,Vivado 2018.3" *) 
(* NotValidForBitStream *)
module mult_gen_pll
   (CLK,
    A,
    B,
    P);
  (* x_interface_info = "xilinx.com:signal:clock:1.0 clk_intf CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME clk_intf, ASSOCIATED_BUSIF p_intf:b_intf:a_intf, ASSOCIATED_RESET sclr, ASSOCIATED_CLKEN ce, FREQ_HZ 10000000, PHASE 0.000, INSERT_VIP 0" *) input CLK;
  (* x_interface_info = "xilinx.com:signal:data:1.0 a_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME a_intf, LAYERED_METADATA undef" *) input [47:0]A;
  (* x_interface_info = "xilinx.com:signal:data:1.0 b_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME b_intf, LAYERED_METADATA undef" *) input [15:0]B;
  (* x_interface_info = "xilinx.com:signal:data:1.0 p_intf DATA" *) (* x_interface_parameter = "XIL_INTERFACENAME p_intf, LAYERED_METADATA undef" *) output [63:0]P;

  wire [47:0]A;
  wire [15:0]B;
  wire CLK;
  wire [63:0]P;
  wire [47:0]NLW_U0_PCASC_UNCONNECTED;
  wire [1:0]NLW_U0_ZERO_DETECT_UNCONNECTED;

  (* C_A_TYPE = "1" *) 
  (* C_A_WIDTH = "48" *) 
  (* C_B_TYPE = "1" *) 
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
  (* C_OUT_HIGH = "63" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "zynq" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  mult_gen_pll_mult_gen_v12_0_14 U0
       (.A(A),
        .B(B),
        .CE(1'b1),
        .CLK(CLK),
        .P(P),
        .PCASC(NLW_U0_PCASC_UNCONNECTED[47:0]),
        .SCLR(1'b0),
        .ZERO_DETECT(NLW_U0_ZERO_DETECT_UNCONNECTED[1:0]));
endmodule

(* C_A_TYPE = "1" *) (* C_A_WIDTH = "48" *) (* C_B_TYPE = "1" *) 
(* C_B_VALUE = "10000001" *) (* C_B_WIDTH = "16" *) (* C_CCM_IMP = "0" *) 
(* C_CE_OVERRIDES_SCLR = "0" *) (* C_HAS_CE = "0" *) (* C_HAS_SCLR = "0" *) 
(* C_HAS_ZERO_DETECT = "0" *) (* C_LATENCY = "1" *) (* C_MODEL_TYPE = "0" *) 
(* C_MULT_TYPE = "1" *) (* C_OPTIMIZE_GOAL = "1" *) (* C_OUT_HIGH = "63" *) 
(* C_OUT_LOW = "0" *) (* C_ROUND_OUTPUT = "0" *) (* C_ROUND_PT = "0" *) 
(* C_VERBOSITY = "0" *) (* C_XDEVICEFAMILY = "zynq" *) (* ORIG_REF_NAME = "mult_gen_v12_0_14" *) 
(* downgradeipidentifiedwarnings = "yes" *) 
module mult_gen_pll_mult_gen_v12_0_14
   (CLK,
    A,
    B,
    CE,
    SCLR,
    ZERO_DETECT,
    P,
    PCASC);
  input CLK;
  input [47:0]A;
  input [15:0]B;
  input CE;
  input SCLR;
  output [1:0]ZERO_DETECT;
  output [63:0]P;
  output [47:0]PCASC;

  wire \<const0> ;
  wire [47:0]A;
  wire [15:0]B;
  wire CLK;
  wire [63:0]P;
  wire [47:0]PCASC;
  wire [1:0]NLW_i_mult_ZERO_DETECT_UNCONNECTED;

  assign ZERO_DETECT[1] = \<const0> ;
  assign ZERO_DETECT[0] = \<const0> ;
  GND GND
       (.G(\<const0> ));
  (* C_A_TYPE = "1" *) 
  (* C_A_WIDTH = "48" *) 
  (* C_B_TYPE = "1" *) 
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
  (* C_OUT_HIGH = "63" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "zynq" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  mult_gen_pll_mult_gen_v12_0_14_viv i_mult
       (.A(A),
        .B(B),
        .CE(1'b0),
        .CLK(CLK),
        .P(P),
        .PCASC(PCASC),
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
OHwYh6MU4cv5Gl4u+to4xHWgdRr+S5umgpocm7XOpylVrbD0d12JuCdWosQV8wj9ujHTdd23iWXl
nZnwA+eLJaw/p+5th0FnOFJfkYvom0YudcU84YbLCGPgspMnhV5yO4xKmb456cADMyOiEpZIGs+e
V/nn35X2GrLX1NQLPbwEC1T2J0iKo8IYcxMhOzA7pd3ApxpwTFFZLdyte/nplDFlc8PISLo/cgqq
AVDMI0Ao0KOMt6YHvEiEOs4YJBUBKsVGSiiY/1dVTLMpT7RxUPfe/aHwtcP6c0khlS5RyxFp/2gl
Ng783vc8xRFLnKyKRY8jehQGC+0AnyXgvFETLQ==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
DB+DTlL0GFe5itNE1Ma62A7SAnl4ZeWn2G60xYVaK7NJVc56z9I5OkrkHuVG2hrhinqhbMJDB60e
+bZ5VVe9BqWGdTlDQDcL4XGuKlw/z2AnkLJU7N2fBrGfwIDqwQHMGW4yFSfLP+//OyYnX7Zknr36
WNu1U7bLEc42z/VOO6CBP1iZyjdx6EF/iYDNiWhkKGan2NmhxbW8aFqqrqe81FTCQO0TUOKAyUUK
5bDAJ6LTNlcLFWIwQgq6mHUDzEGO+lMo6JZGlw6Wjx9CNYJGePwUk1n7O0W2Ol8vlUjA3YjsgtlE
mwxRMzYZNxnNZZmchM54FBhV6ID/FTODwqDKLw==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 22144)
`pragma protect data_block
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
RdufUz4o3rqP6ty3dPDg+Sk1cnI6eO3N1iJFqA==
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
