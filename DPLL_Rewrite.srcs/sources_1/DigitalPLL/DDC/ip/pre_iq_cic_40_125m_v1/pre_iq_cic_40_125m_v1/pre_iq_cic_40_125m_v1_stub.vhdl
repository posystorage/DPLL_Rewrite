-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
-- Date        : Sun Jun 28 21:34:23 2026
-- Host        : MiaoZhi-PC running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               E:/FPGA/DPLL_Rewrite/DPLL_Rewrite_THbox_T3/DPLL_Rewrite.srcs/sources_1/DigitalPLL/DDC/ip/pre_iq_cic_40_125m_v1/pre_iq_cic_40_125m_v1/pre_iq_cic_40_125m_v1_stub.vhdl
-- Design      : pre_iq_cic_40_125m_v1
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z010clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pre_iq_cic_40_125m_v1 is
  Port ( 
    aclk : in STD_LOGIC;
    s_axis_data_tdata : in STD_LOGIC_VECTOR ( 15 downto 0 );
    s_axis_data_tvalid : in STD_LOGIC;
    s_axis_data_tready : out STD_LOGIC;
    m_axis_data_tdata : out STD_LOGIC_VECTOR ( 15 downto 0 );
    m_axis_data_tvalid : out STD_LOGIC
  );

end pre_iq_cic_40_125m_v1;

architecture stub of pre_iq_cic_40_125m_v1 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "aclk,s_axis_data_tdata[15:0],s_axis_data_tvalid,s_axis_data_tready,m_axis_data_tdata[15:0],m_axis_data_tvalid";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "cic_compiler_v4_0_13,Vivado 2018.3";
begin
end;
