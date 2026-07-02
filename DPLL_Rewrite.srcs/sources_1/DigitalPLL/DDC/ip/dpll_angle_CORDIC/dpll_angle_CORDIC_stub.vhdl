-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
-- Date        : Thu Jul  2 19:19:08 2026
-- Host        : DESKTOP-MRF396F running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               E:/JiangSiyi/FPGA/DPLL_Low_Freq_Track/DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/dpll_angle_CORDIC/dpll_angle_CORDIC_stub.vhdl
-- Design      : dpll_angle_CORDIC
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z010clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity dpll_angle_CORDIC is
  Port ( 
    aclk : in STD_LOGIC;
    aresetn : in STD_LOGIC;
    s_axis_cartesian_tvalid : in STD_LOGIC;
    s_axis_cartesian_tready : out STD_LOGIC;
    s_axis_cartesian_tdata : in STD_LOGIC_VECTOR ( 47 downto 0 );
    m_axis_dout_tvalid : out STD_LOGIC;
    m_axis_dout_tready : in STD_LOGIC;
    m_axis_dout_tdata : out STD_LOGIC_VECTOR ( 47 downto 0 )
  );

end dpll_angle_CORDIC;

architecture stub of dpll_angle_CORDIC is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "aclk,aresetn,s_axis_cartesian_tvalid,s_axis_cartesian_tready,s_axis_cartesian_tdata[47:0],m_axis_dout_tvalid,m_axis_dout_tready,m_axis_dout_tdata[47:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "cordic_v6_0_14,Vivado 2018.3";
begin
end;
