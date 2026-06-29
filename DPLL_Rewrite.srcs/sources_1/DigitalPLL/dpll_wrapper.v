`timescale 1ns / 1ps
// Digital-PLL wrapper
// Single-clock active DPLL path, ABI v1 compatible register shell.

`default_nettype none
`include "dpll_build_id.vh"

module dpll_wrapper(
    input  wire               clk1,
    input  wire               rst,
    input  wire               sys_clk,
    input  wire               sys_rstn,

    input  wire signed [15:0] ADCraw0,
    input  wire signed [15:0] ADCraw1,
    output wire signed [15:0] DACout0,
    output wire signed [15:0] DACout1,

    input  wire [31:0]        sys_addr,
    input  wire [31:0]        sys_wdata,
    input  wire [3:0]         sys_sel,
    input  wire               sys_wen,
    input  wire               sys_ren,
    output reg  [31:0]        sys_rdata,
    output reg                sys_err,
    output reg                sys_ack,

    output wire [6:0]         led
);

localparam [31:0] ABI_VERSION       = `DPLL_GENERATED_ABI_VERSION;
localparam [31:0] CONFIG_VERSION    = `DPLL_GENERATED_CONFIG_VERSION;
localparam [31:0] FPGA_BUILD_ID     = `DPLL_GENERATED_BUILD_ID;
localparam [31:0] FPGA_GIT_HASH     = `DPLL_GENERATED_GIT_HASH;
localparam [31:0] DEFAULT_POS_LIMIT = 32'h7FFF_FFFF;
localparam [31:0] DEFAULT_NEG_LIMIT = 32'h8000_0000;
localparam [31:0] DEFAULT_DAC_AMP   = 32'h0000_7FFF;
localparam [31:0] DEFAULT_FREQ_MUL  = 32'h0000_0001;
localparam [31:0] DEFAULT_FREQ_DIV  = 32'h0000_0001;
localparam [31:0] DEFAULT_PHASE_THR = 32'h0000_7FFF;
localparam [31:0] DEFAULT_FREQ_THR  = 32'h0000_7FFF;
localparam [31:0] DEFAULT_MAG_ENTER = 32'h0000_0100;
localparam [31:0] DEFAULT_MAG_EXIT  = 32'h0000_0040;
localparam [31:0] DEFAULT_DWELL     = 32'h0000_0004;
localparam [31:0] DEFAULT_HOLDOVER  = 32'h0013_12D0; // 10 ms at 125 MHz
localparam [31:0] DEFAULT_MEAS_TIMEOUT = 32'h0000_0000; // zero selects 120*R+256

wire [15:0] cmd_addr;
wire [31:0] cmd_datain;
wire        cmd_trig;
reg         config_apply_busy;

assign cmd_trig   = sys_wen && !config_apply_busy;
assign cmd_addr   = sys_addr[17:2];
assign cmd_datain = sys_wdata;

wire ok_reset;
wire [31:0] Centre_Freq;
wire [3:0]  angleSelect_0;
wire        pll0_lock_i;
wire        pll0_lock;
wire [31:0] pll0_gainp;
wire [31:0] pll0_gaini;
wire [31:0] pll0_gainii;
wire [31:0] fll_kf_blend;
wire [31:0] fll_kf_track;
wire [31:0] pll_kp_blend;
wire [31:0] pll_ki_blend;
wire signed [31:0] positive_limit_dac0;
wire signed [31:0] negative_limit_dac0;
wire signed [31:0] manual_offset_dac0;
wire signed [13:0] VCO_Voffset0;
wire signed [15:0] VCO_Vamplitude0;
wire [15:0] VCO_Mul_Factor0;
wire [15:0] VCO_Div_Factor0;
wire signed [13:0] debug_dac_offset;
wire signed [15:0] debug_dac_gain;
wire [31:0] debug_dac_source;
wire [31:0] debug_dac_format;
wire [31:0] Phase_Residuals_Threshold0;
wire [31:0] Phase_Residuals_Offset0;
wire [31:0] Freq_Residuals_Threshold0;
wire [31:0] Magnitude_Enter_Threshold0;
wire [31:0] Magnitude_Exit_Threshold0;
wire [31:0] Acquire_Dwell0;
wire [31:0] Blend_Dwell0;
wire [31:0] Loss_Dwell0;
wire [31:0] Holdover_Timeout0;
wire [31:0] Measurement_Timeout0;
wire [8:0]  post_iq_cic_rate_r;
wire [5:0]  post_iq_cic_shift;
wire [1:0]  fll_delay_sel;
wire [15:0] warmup_samples;
wire        config_apply_flag;

wire unused_sys_sel = |sys_sel;
wire unused_adc1 = |ADCraw1;
wire unused_angle = |angleSelect_0;

parallel_bus_register_32bits_or_less #(
    .REGISTER_SIZE(8),
    .REGISTER_DEFAULT_VALUE(0),
    .ADDRESS(16'h0000)
) reg_ok_reset (
    .clk(sys_clk),
    .bus_strobe(cmd_trig),
    .bus_address(cmd_addr),
    .bus_data(cmd_datain),
    .register_output(),
    .update_flag(ok_reset)
);

parallel_bus_register_32bits_or_less #(
    .REGISTER_SIZE(32),
    .REGISTER_DEFAULT_VALUE(0),
    .ADDRESS(16'h0010)
) reg_center_freq (
    .clk(sys_clk),
    .bus_strobe(cmd_trig),
    .bus_address(cmd_addr),
    .bus_data(cmd_datain),
    .register_output(Centre_Freq),
    .update_flag()
);

parallel_bus_register_32bits_or_less #(
    .REGISTER_SIZE(4),
    .REGISTER_DEFAULT_VALUE(0),
    .ADDRESS(16'h0011)
) reg_angle_select (
    .clk(sys_clk),
    .bus_strobe(cmd_trig),
    .bus_address(cmd_addr),
    .bus_data(cmd_datain),
    .register_output(angleSelect_0),
    .update_flag()
);

parallel_bus_register_32bits_or_less #(
    .REGISTER_SIZE(1),
    .REGISTER_DEFAULT_VALUE(0),
    .ADDRESS(16'h0020)
) reg_pll_lock (
    .clk(sys_clk),
    .bus_strobe(cmd_trig),
    .bus_address(cmd_addr),
    .bus_data(cmd_datain),
    .register_output(pll0_lock_i),
    .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0021)) reg_kp (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gainp), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(2), .ADDRESS(16'h0022)) reg_ki (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gaini), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(8), .ADDRESS(16'h0023)) reg_kf (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gainii), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0024)) reg_kf_blend (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(fll_kf_blend), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(1), .ADDRESS(16'h0025)) reg_kf_track (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(fll_kf_track), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(2), .ADDRESS(16'h0026)) reg_kp_blend (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll_kp_blend), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(1), .ADDRESS(16'h0027)) reg_ki_blend (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll_ki_blend), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_POS_LIMIT), .ADDRESS(16'h0028)) reg_pos_limit (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(positive_limit_dac0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0029)) reg_neg_limit (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(negative_limit_dac0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h002A)) reg_manual_offset (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(manual_offset_dac0), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(14), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0030)) reg_dac0_offset (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Voffset0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DAC_AMP), .ADDRESS(16'h0031)) reg_dac0_amp (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Vamplitude0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_FREQ_MUL), .ADDRESS(16'h0032)) reg_freq_mul (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Mul_Factor0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_FREQ_DIV), .ADDRESS(16'h0033)) reg_freq_div (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Div_Factor0), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(14), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0040)) reg_debug_offset (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_offset), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DAC_AMP), .ADDRESS(16'h0041)) reg_debug_gain (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_gain), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0042)) reg_debug_source (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_source), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0043)) reg_debug_format (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_format), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_PHASE_THR), .ADDRESS(16'h0050)) reg_phase_thr (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Phase_Residuals_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0051)) reg_phase_offset (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Phase_Residuals_Offset0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_FREQ_THR), .ADDRESS(16'h0052)) reg_freq_thr (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Freq_Residuals_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_MAG_ENTER), .ADDRESS(16'h0053)) reg_mag_enter (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Magnitude_Enter_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_MAG_EXIT), .ADDRESS(16'h0054)) reg_mag_exit (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Magnitude_Exit_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_DWELL), .ADDRESS(16'h0055)) reg_acquire_dwell (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Acquire_Dwell0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_DWELL), .ADDRESS(16'h0056)) reg_blend_dwell (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Blend_Dwell0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_DWELL), .ADDRESS(16'h0057)) reg_loss_dwell (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Loss_Dwell0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_HOLDOVER), .ADDRESS(16'h0058)) reg_holdover_timeout (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Holdover_Timeout0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_MEAS_TIMEOUT), .ADDRESS(16'h0059)) reg_measurement_timeout (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Measurement_Timeout0), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(9), .REGISTER_DEFAULT_VALUE(8), .ADDRESS(16'h0060)) reg_cic_rate (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(post_iq_cic_rate_r), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(6), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0061)) reg_cic_shift (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(post_iq_cic_shift), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(2), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0062)) reg_fll_delay (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(fll_delay_sel), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0063)) reg_warmup_samples (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(warmup_samples), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(1), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h006F)) reg_config_apply (
    .clk(sys_clk), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(), .update_flag(config_apply_flag)
);

(* ASYNC_REG = "TRUE" *) reg pll0_lock_meta;
(* ASYNC_REG = "TRUE" *) reg pll0_lock_sync;
assign pll0_lock = pll0_lock_sync;

wire rst_125m_stage_a;
wire [15:0] pre_cic_sample;
wire        pre_cic_valid;
wire        pre_cic_ready;

reg rst_125m_meta;
reg rst_125m_sync;
reg reset_toggle_sys;
(* ASYNC_REG = "TRUE" *) reg reset_meta_clk;
(* ASYNC_REG = "TRUE" *) reg reset_sync_clk;
reg reset_seen_clk;
wire reset_pulse_clk = reset_sync_clk ^ reset_seen_clk;
(* keep = "true", dont_touch = "true" *) reg rst_debug_r;
(* keep = "true", dont_touch = "true" *) reg rst_status_r;
always @(posedge clk1 or negedge rst) begin
    if (!rst) begin
        rst_125m_meta <= 1'b1;
        rst_125m_sync <= 1'b1;
        rst_debug_r <= 1'b1;
        rst_status_r <= 1'b1;
    end else begin
        rst_125m_meta <= reset_pulse_clk;
        rst_125m_sync <= rst_125m_meta;
        rst_debug_r <= rst_125m_sync;
        rst_status_r <= rst_125m_sync;
    end
end
assign rst_125m_stage_a = rst_125m_sync;

pre_iq_cic_40_125m_v1 pre_iq_cic_40_inst (
    .aclk(clk1),
    .s_axis_data_tdata(ADCraw0),
    .s_axis_data_tvalid(~rst_125m_stage_a),
    .s_axis_data_tready(pre_cic_ready),
    .m_axis_data_tdata(pre_cic_sample),
    .m_axis_data_tvalid(pre_cic_valid)
);

wire [47:0] dpll_tracking_word;
wire        dpll_tracking_valid;
wire signed [17:0] dpll_phase_error;
wire signed [17:0] dpll_cordic_phase;
wire signed [21:0] dpll_freq_error;
wire        dpll_freq_error_valid;
wire signed [19:0] dpll_i_baseband;
wire signed [19:0] dpll_q_baseband;
wire        dpll_iq_valid;
wire signed [55:0] dpll_freq_state;
wire signed [55:0] dpll_freq_correction;
wire [15:0] dpll_magnitude;
wire [3:0]  dpll_loop_state;
wire [3:0]  dpll_loss_reason;
wire        dpll_signal_present;
wire        dpll_phase_locked;
wire        dpll_frequency_locked;
wire        dpll_locked;
wire [8:0]  dpll_active_cic_rate_r;
wire [5:0]  dpll_active_cic_shift;
wire        dpll_cic_overflow;
wire        dpll_cic_illegal;
wire signed [15:0] dpll_lo_cos;
wire signed [15:0] dpll_lo_sin;

wire [47:0] shadow_center_word = {Centre_Freq, 16'h0000};
wire signed [31:0] shadow_negative_limit_effective =
    (negative_limit_dac0 == 32'h0000_0000) ? $signed(DEFAULT_NEG_LIMIT) : negative_limit_dac0;
wire signed [55:0] shadow_correction_limit_pos = {{24{positive_limit_dac0[31]}}, positive_limit_dac0};
wire signed [55:0] shadow_correction_limit_neg = {{24{shadow_negative_limit_effective[31]}}, shadow_negative_limit_effective};
localparam [7:0] APPLY_ERR_NONE       = 8'h00;
localparam [7:0] APPLY_ERR_CIC_RATE   = 8'h01;
localparam [7:0] APPLY_ERR_CIC_SHIFT  = 8'h02;
localparam [7:0] APPLY_ERR_FLL_DELAY  = 8'h03;
localparam [7:0] APPLY_ERR_MUL_DIV    = 8'h04;
localparam [7:0] APPLY_ERR_LIMITS     = 8'h05;
localparam [7:0] APPLY_ERR_MAGNITUDE  = 8'h06;
localparam [7:0] APPLY_ERR_DWELL      = 8'h07;
localparam [7:0] APPLY_ERR_MEAS_TIME  = 8'h08;
localparam [7:0] APPLY_ERR_HOLDOVER   = 8'h09;

function [5:0] expected_cic_shift;
    input [8:0] rate_r;
    begin
        if (rate_r <= 9'd8) expected_cic_shift = 6'd4;
        else if (rate_r <= 9'd16) expected_cic_shift = 6'd7;
        else if (rate_r <= 9'd31) expected_cic_shift = 6'd10;
        else if (rate_r <= 9'd78) expected_cic_shift = 6'd13;
        else if (rate_r <= 9'd156) expected_cic_shift = 6'd16;
        else expected_cic_shift = 6'd19;
    end
endfunction

wire [5:0] shadow_expected_cic_shift = expected_cic_shift(post_iq_cic_rate_r);
wire [23:0] shadow_measurement_min = (24'd120 * post_iq_cic_rate_r) + 24'd256;
wire [63:0] shadow_vco_product = shadow_center_word * VCO_Mul_Factor0;
wire [63:0] shadow_vco_max_product = 48'hffff_ffff_ffff * VCO_Div_Factor0;
wire shadow_cic_rate_legal = (post_iq_cic_rate_r >= 9'd8) && (post_iq_cic_rate_r <= 9'd312);
wire shadow_cic_shift_legal = (post_iq_cic_shift + 6'd2 >= shadow_expected_cic_shift) &&
                              (post_iq_cic_shift <= shadow_expected_cic_shift + 6'd2);
wire shadow_fll_delay_legal = (fll_delay_sel <= 2'd3);
wire shadow_vco_mul_div_legal = (VCO_Mul_Factor0 != 16'h0000) &&
                                (VCO_Div_Factor0 != 16'h0000) &&
                                (shadow_vco_product <= shadow_vco_max_product);
wire shadow_limits_legal = !positive_limit_dac0[31] && shadow_negative_limit_effective[31] &&
                           ($signed(positive_limit_dac0) >= $signed(shadow_negative_limit_effective));
wire shadow_magnitude_legal = Magnitude_Enter_Threshold0[15:0] >= Magnitude_Exit_Threshold0[15:0];
wire shadow_dwell_legal = (Acquire_Dwell0[15:0] != 16'd0) &&
                          (Blend_Dwell0[15:0] != 16'd0) &&
                          (Loss_Dwell0[15:0] != 16'd0);
wire shadow_measurement_timeout_legal = (Measurement_Timeout0[23:0] == 24'd0) ||
                                        (Measurement_Timeout0[23:0] >= shadow_measurement_min);
wire shadow_holdover_legal = Holdover_Timeout0[23:0] != 24'd0;
wire [15:0] shadow_rejected_mask = {7'd0, !shadow_holdover_legal,
    !shadow_measurement_timeout_legal, !shadow_dwell_legal, !shadow_magnitude_legal,
    !shadow_limits_legal, !shadow_vco_mul_div_legal, !shadow_fll_delay_legal,
    !shadow_cic_shift_legal, !shadow_cic_rate_legal};
wire shadow_config_legal = shadow_rejected_mask == 16'd0;
wire [7:0] shadow_apply_error_code =
    !shadow_cic_rate_legal ? APPLY_ERR_CIC_RATE :
    !shadow_cic_shift_legal ? APPLY_ERR_CIC_SHIFT :
    !shadow_fll_delay_legal ? APPLY_ERR_FLL_DELAY :
    !shadow_vco_mul_div_legal ? APPLY_ERR_MUL_DIV :
    !shadow_limits_legal ? APPLY_ERR_LIMITS :
    !shadow_magnitude_legal ? APPLY_ERR_MAGNITUDE :
    !shadow_dwell_legal ? APPLY_ERR_DWELL :
    !shadow_measurement_timeout_legal ? APPLY_ERR_MEAS_TIME :
    !shadow_holdover_legal ? APPLY_ERR_HOLDOVER : APPLY_ERR_NONE;

reg [47:0] active_center_word;
reg signed [23:0] active_kf;
reg signed [23:0] active_ki;
reg signed [23:0] active_kp;
reg signed [23:0] active_kf_blend;
reg signed [23:0] active_kf_track;
reg signed [23:0] active_kp_blend;
reg signed [23:0] active_ki_blend;
reg signed [17:0] active_phase_setpoint;
reg [17:0] active_phase_lock_threshold;
reg [21:0] active_freq_lock_threshold;
reg [15:0] active_mag_enter_threshold;
reg [15:0] active_mag_exit_threshold;
reg [15:0] active_acquire_dwell;
reg [15:0] active_blend_dwell;
reg [15:0] active_loss_dwell;
reg [23:0] active_holdover_timeout;
reg [23:0] active_measurement_timeout;
reg [15:0] active_warmup_samples;
reg signed [55:0] active_correction_limit_pos;
reg signed [55:0] active_correction_limit_neg;
reg [8:0] active_post_iq_cic_rate_r;
reg [5:0] active_post_iq_cic_shift;
reg [1:0] active_fll_delay_sel;
reg signed [31:0] active_manual_offset_dac0;
reg signed [13:0] active_vco_offset;
reg signed [15:0] active_vco_amplitude;
reg signed [13:0] active_debug_dac_offset;
reg signed [15:0] active_debug_dac_gain;
reg [31:0] active_debug_dac_source;
reg [31:0] active_debug_dac_format;
reg [15:0] active_vco_mul_factor;
reg [15:0] active_vco_div_factor;
reg config_apply_core_pulse;
reg config_apply_error;
reg [7:0] config_apply_error_code;
reg [15:0] config_apply_rejected_mask;
reg [7:0] config_apply_sequence;
reg config_commit_toggle_sys;
(* ASYNC_REG = "TRUE" *) reg config_commit_meta_clk;
(* ASYNC_REG = "TRUE" *) reg config_commit_sync_clk;
reg config_commit_seen_clk;
reg config_ack_toggle_clk;
(* ASYNC_REG = "TRUE" *) reg config_ack_meta_sys;
(* ASYNC_REG = "TRUE" *) reg config_ack_sync_sys;
reg config_ack_seen_sys;
wire config_commit_pulse_clk = config_commit_sync_clk ^ config_commit_seen_clk;

reg status_request_toggle_sys;
reg [15:0] status_request_addr_sys;
reg status_request_pending_sys;
(* ASYNC_REG = "TRUE" *) reg status_request_meta_clk;
(* ASYNC_REG = "TRUE" *) reg status_request_sync_clk;
reg status_request_seen_clk;
reg status_response_toggle_clk;
reg [31:0] status_response_data_clk;
(* ASYNC_REG = "TRUE" *) reg status_response_meta_sys;
(* ASYNC_REG = "TRUE" *) reg status_response_sync_sys;
reg status_response_seen_sys;

always @(posedge sys_clk or negedge sys_rstn) begin
    if (!sys_rstn) begin
        config_apply_busy <= 1'b0;
        config_apply_error <= 1'b0;
        config_apply_error_code <= APPLY_ERR_NONE;
        config_apply_rejected_mask <= 16'd0;
        config_apply_sequence <= 8'd0;
        config_commit_toggle_sys <= 1'b0;
        config_ack_meta_sys <= 1'b0;
        config_ack_sync_sys <= 1'b0;
        config_ack_seen_sys <= 1'b0;
        reset_toggle_sys <= 1'b0;
    end else begin
        config_ack_meta_sys <= config_ack_toggle_clk;
        config_ack_sync_sys <= config_ack_meta_sys;
        if (ok_reset) reset_toggle_sys <= ~reset_toggle_sys;
        if (config_apply_flag && !config_apply_busy) begin
            config_apply_error <= !shadow_config_legal;
            config_apply_error_code <= shadow_apply_error_code;
            config_apply_rejected_mask <= shadow_rejected_mask;
            if (shadow_config_legal) begin
                config_apply_busy <= 1'b1;
                config_commit_toggle_sys <= ~config_commit_toggle_sys;
            end
        end
        if (config_ack_sync_sys != config_ack_seen_sys) begin
            config_ack_seen_sys <= config_ack_sync_sys;
            config_apply_busy <= 1'b0;
            config_apply_sequence <= config_apply_sequence + 1'b1;
        end
    end
end

always @(posedge clk1 or negedge rst) begin
    if (!rst) begin
        config_commit_meta_clk <= 1'b0;
        config_commit_sync_clk <= 1'b0;
        config_commit_seen_clk <= 1'b0;
        config_ack_toggle_clk <= 1'b0;
        reset_meta_clk <= 1'b0;
        reset_sync_clk <= 1'b0;
        reset_seen_clk <= 1'b0;
        pll0_lock_meta <= 1'b0;
        pll0_lock_sync <= 1'b0;
        config_apply_core_pulse <= 1'b0;
        active_center_word <= 48'h0000_0000_0000;
        active_kf <= 24'sd8;
        active_ki <= 24'sd2;
        active_kp <= 24'sd4;
        active_kf_blend <= 24'sd4;
        active_kf_track <= 24'sd1;
        active_kp_blend <= 24'sd2;
        active_ki_blend <= 24'sd1;
        active_phase_setpoint <= 18'sd0;
        active_phase_lock_threshold <= DEFAULT_PHASE_THR[17:0];
        active_freq_lock_threshold <= DEFAULT_FREQ_THR[21:0];
        active_mag_enter_threshold <= DEFAULT_MAG_ENTER[15:0];
        active_mag_exit_threshold <= DEFAULT_MAG_EXIT[15:0];
        active_acquire_dwell <= DEFAULT_DWELL[15:0];
        active_blend_dwell <= DEFAULT_DWELL[15:0];
        active_loss_dwell <= DEFAULT_DWELL[15:0];
        active_holdover_timeout <= DEFAULT_HOLDOVER[23:0];
        active_measurement_timeout <= (24'd120 * 9'd8) + 24'd256;
        active_warmup_samples <= 16'd4;
        active_correction_limit_pos <= {{24{DEFAULT_POS_LIMIT[31]}}, DEFAULT_POS_LIMIT};
        active_correction_limit_neg <= {{24{DEFAULT_NEG_LIMIT[31]}}, DEFAULT_NEG_LIMIT};
        active_post_iq_cic_rate_r <= 9'd8;
        active_post_iq_cic_shift <= 6'd4;
        active_fll_delay_sel <= 2'd0;
        active_manual_offset_dac0 <= 32'sd0;
        active_vco_offset <= 14'sd0;
        active_vco_amplitude <= DEFAULT_DAC_AMP[15:0];
        active_debug_dac_offset <= 14'sd0;
        active_debug_dac_gain <= DEFAULT_DAC_AMP[15:0];
        active_debug_dac_source <= 32'd0;
        active_debug_dac_format <= 32'd0;
        active_vco_mul_factor <= DEFAULT_FREQ_MUL[15:0];
        active_vco_div_factor <= DEFAULT_FREQ_DIV[15:0];
    end else begin
        config_commit_meta_clk <= config_commit_toggle_sys;
        config_commit_sync_clk <= config_commit_meta_clk;
        reset_meta_clk <= reset_toggle_sys;
        reset_sync_clk <= reset_meta_clk;
        pll0_lock_meta <= pll0_lock_i;
        pll0_lock_sync <= pll0_lock_meta;
        config_apply_core_pulse <= 1'b0;
        if (reset_pulse_clk) reset_seen_clk <= reset_sync_clk;
        if (config_commit_pulse_clk) begin
            config_commit_seen_clk <= config_commit_sync_clk;
            config_ack_toggle_clk <= ~config_ack_toggle_clk;
            config_apply_core_pulse <= 1'b1;
            active_center_word <= shadow_center_word;
            active_kf <= pll0_gainii[23:0];
            active_ki <= pll0_gaini[23:0];
            active_kp <= pll0_gainp[23:0];
            active_kf_blend <= fll_kf_blend[23:0];
            active_kf_track <= fll_kf_track[23:0];
            active_kp_blend <= pll_kp_blend[23:0];
            active_ki_blend <= pll_ki_blend[23:0];
            active_phase_setpoint <= Phase_Residuals_Offset0[17:0];
            active_phase_lock_threshold <= Phase_Residuals_Threshold0[17:0];
            active_freq_lock_threshold <= Freq_Residuals_Threshold0[21:0];
            active_mag_enter_threshold <= Magnitude_Enter_Threshold0[15:0];
            active_mag_exit_threshold <= Magnitude_Exit_Threshold0[15:0];
            active_acquire_dwell <= Acquire_Dwell0[15:0];
            active_blend_dwell <= Blend_Dwell0[15:0];
            active_loss_dwell <= Loss_Dwell0[15:0];
            active_holdover_timeout <= Holdover_Timeout0[23:0];
            active_measurement_timeout <= (Measurement_Timeout0[23:0] == 24'd0)
                ? shadow_measurement_min : Measurement_Timeout0[23:0];
            active_warmup_samples <= warmup_samples;
            active_correction_limit_pos <= shadow_correction_limit_pos;
            active_correction_limit_neg <= shadow_correction_limit_neg;
            active_post_iq_cic_rate_r <= post_iq_cic_rate_r;
            active_post_iq_cic_shift <= post_iq_cic_shift;
            active_fll_delay_sel <= fll_delay_sel;
            active_manual_offset_dac0 <= manual_offset_dac0;
            active_vco_offset <= VCO_Voffset0;
            active_vco_amplitude <= VCO_Vamplitude0;
            active_debug_dac_offset <= debug_dac_offset;
            active_debug_dac_gain <= debug_dac_gain;
            active_debug_dac_source <= debug_dac_source;
            active_debug_dac_format <= debug_dac_format;
            active_vco_mul_factor <= VCO_Mul_Factor0;
            active_vco_div_factor <= VCO_Div_Factor0;
        end
    end
end
wire signed [55:0] correction_limit_pos = active_correction_limit_pos;
wire signed [55:0] correction_limit_neg = active_correction_limit_neg;

dpll_single_clock_core_stage_a dpll_single_clock_core_stage_a_inst (
    .clk_125m(clk1),
    .rst_125m(rst_125m_stage_a),
    .sample_valid(pre_cic_valid),
    .loop_enable(pll0_lock),
    .adc_sample(pre_cic_sample),
    .center_word(active_center_word),
    .config_apply(config_apply_core_pulse),
    .cic_rate_r(active_post_iq_cic_rate_r),
    .cic_output_shift(active_post_iq_cic_shift),
    .cic_flush(reset_pulse_clk),
    .fll_delay_sel(active_fll_delay_sel),
    .kf(active_kf),
    .ki(active_ki),
    .kp(active_kp),
    .kf_blend(active_kf_blend),
    .kf_track(active_kf_track),
    .kp_blend(active_kp_blend),
    .ki_blend(active_ki_blend),
    .phase_setpoint(active_phase_setpoint),
    .phase_lock_threshold(active_phase_lock_threshold),
    .freq_lock_threshold(active_freq_lock_threshold),
    .mag_enter_threshold(active_mag_enter_threshold),
    .mag_exit_threshold(active_mag_exit_threshold),
    .acquire_dwell(active_acquire_dwell),
    .blend_dwell(active_blend_dwell),
    .loss_dwell(active_loss_dwell),
    .measurement_timeout(active_measurement_timeout),
    .holdover_timeout(active_holdover_timeout),
    .warmup_samples(active_warmup_samples),
    .positive_limit(correction_limit_pos),
    .negative_limit(correction_limit_neg),
    .tracking_word(dpll_tracking_word),
    .tracking_valid(dpll_tracking_valid),
    .cordic_phase_out(dpll_cordic_phase),
    .phase_error(dpll_phase_error),
    .freq_error(dpll_freq_error),
    .freq_error_valid(dpll_freq_error_valid),
    .i_baseband(dpll_i_baseband),
    .q_baseband(dpll_q_baseband),
    .iq_valid(dpll_iq_valid),
    .freq_state(dpll_freq_state),
    .freq_correction(dpll_freq_correction),
    .magnitude(dpll_magnitude),
    .loop_state(dpll_loop_state),
    .loss_reason(dpll_loss_reason),
    .signal_present(dpll_signal_present),
    .phase_locked(dpll_phase_locked),
    .frequency_locked(dpll_frequency_locked),
    .locked(dpll_locked),
    .active_cic_rate_r(dpll_active_cic_rate_r),
    .active_cic_output_shift(dpll_active_cic_shift),
    .cic_overflow_seen(dpll_cic_overflow),
    .cic_illegal_config_seen(dpll_cic_illegal),
    .lo_cos(dpll_lo_cos),
    .lo_sin(dpll_lo_sin)
);

wire signed [49:0] manual_offset_sum =
    $signed({2'b00, dpll_tracking_word}) +
    $signed({{18{active_manual_offset_dac0[31]}}, active_manual_offset_dac0});
wire manual_offset_underflow = manual_offset_sum < 50'sd0;
wire manual_offset_positive_saturation =
    manual_offset_sum > $signed({2'b00, 48'hffff_ffff_ffff});
wire manual_offset_overflow = manual_offset_underflow || manual_offset_positive_saturation;
wire [47:0] vco_tracking_word = manual_offset_underflow ? 48'd0 :
    (manual_offset_positive_saturation
        ? 48'hffff_ffff_ffff : manual_offset_sum[47:0]);
wire [47:0] VCO_Input0;
wire signed [47:0] debug_tracking_delta =
    $signed(dpll_tracking_word) - $signed(active_center_word);
wire signed [47:0] debug_output_delta =
    $signed(VCO_Input0) - $signed(dpll_tracking_word);
wire        vco_mul_div_runtime_config_error;
wire        vco_mul_div_config_error = vco_mul_div_runtime_config_error;

PLL_VCO_MUL_DIV PLL_VCO_MUL_DIV_inst (
    .clk(clk1),
    .rst(rst_125m_stage_a),
    .sample_valid(dpll_tracking_valid),
    .data_in(vco_tracking_word),
    .data_out(VCO_Input0),
    .PLL_Mul_factor(active_vco_mul_factor),
    .PLL_Div_factor(active_vco_div_factor),
    .config_error(vco_mul_div_runtime_config_error)
);

VCO_48bits VCO_inst0 (
    .clk(clk1),
    .VCO_input(VCO_Input0),
    .VCO_offset(active_vco_offset),
    .VCO_amplitude(active_vco_amplitude),
    .VCO_DAC_out(DACout0)
);

function [31:0] abs18_extend;
    input signed [17:0] value;
    reg signed [31:0] extended;
    begin
        extended = {{14{value[17]}}, value};
        abs18_extend = extended[31] ? (~extended + 32'd1) : extended;
    end
endfunction

function [31:0] abs22_extend;
    input signed [21:0] value;
    reg signed [31:0] extended;
    begin
        extended = {{10{value[21]}}, value};
        abs22_extend = extended[31] ? (~extended + 32'd1) : extended;
    end
endfunction

function signed [31:0] debug_source_mux;
    input [3:0] sel;
    begin
        case (sel)
            4'h0: debug_source_mux = dpll_freq_correction[55:24];
            4'h1: debug_source_mux = debug_tracking_delta[47:16];
            4'h2: debug_source_mux = dpll_freq_state[55:24];
            4'h3: debug_source_mux = {{14{dpll_phase_error[17]}}, dpll_phase_error};
            4'h4: debug_source_mux = {{10{dpll_freq_error[21]}}, dpll_freq_error};
            4'h5: debug_source_mux = {{12{dpll_i_baseband[19]}}, dpll_i_baseband};
            4'h6: debug_source_mux = {{12{dpll_q_baseband[19]}}, dpll_q_baseband};
            4'h7: debug_source_mux = {{14{dpll_cordic_phase[17]}}, dpll_cordic_phase};
            4'h8: debug_source_mux = {16'h0000, dpll_magnitude};
            4'h9: debug_source_mux = debug_output_delta[47:16];
            4'hA: debug_source_mux = {28'h0, dpll_loop_state};
            default: debug_source_mux = {{14{dpll_phase_error[17]}}, dpll_phase_error};
        endcase
    end
endfunction

reg signed [31:0] debug_word_r;

always @(posedge clk1) begin
    if (rst_debug_r) begin
        debug_word_r <= 32'sd0;
    end else begin
        debug_word_r <= debug_source_mux(active_debug_dac_source[3:0]);
    end
end

debug_dac_formatter_stage_a debug_dac_formatter_inst (
    .clk_125m(clk1),
    .rst_125m(rst_debug_r),
    .source_valid(1'b1),
    .source_word(debug_word_r),
    .format_word(active_debug_dac_format),
    .gain(active_debug_dac_gain),
    .offset({{2{active_debug_dac_offset[13]}}, active_debug_dac_offset}),
    .dac_sample(DACout1)
);

wire [31:0] phase_abs = abs18_extend(dpll_phase_error);
wire [31:0] freq_abs = abs22_extend(dpll_freq_error);
wire residuals0_are_above_threshold_phase = ~dpll_phase_locked;
wire residuals0_are_above_threshold_freq = ~dpll_frequency_locked;
wire dac0_railed_positive = dpll_freq_correction >= correction_limit_pos;
wire dac0_railed_negative = dpll_freq_correction <= correction_limit_neg;
wire pll0_locked_instant = dpll_locked;
reg residuals0_are_above_threshold;
reg LED_G0;
reg LED_R0;
reg [23:0] status_counter;

always @(posedge clk1) begin
    if (rst_status_r) begin
        residuals0_are_above_threshold <= 1'b0;
        LED_G0 <= 1'b0;
        LED_R0 <= 1'b1;
        status_counter <= 24'h0;
    end else begin
        residuals0_are_above_threshold <= residuals0_are_above_threshold_phase |
                                           residuals0_are_above_threshold_freq;
        status_counter <= status_counter + 24'h1;
        LED_G0 <= dpll_locked;
        LED_R0 <= ~dpll_locked;
    end
end

assign led = {status_counter[23], dpll_cic_illegal, dpll_cic_overflow, dpll_signal_present,
              dpll_locked, LED_R0, LED_G0};

function status_snapshot_address;
    input [15:0] address;
    begin
        status_snapshot_address = ((address >= 16'h0100) && (address <= 16'h010C)) ||
                                  ((address >= 16'h0110) && (address <= 16'h011C));
    end
endfunction

always @(posedge clk1 or negedge rst) begin
    if (!rst) begin
        status_request_meta_clk <= 1'b0;
        status_request_sync_clk <= 1'b0;
        status_request_seen_clk <= 1'b0;
        status_response_toggle_clk <= 1'b0;
        status_response_data_clk <= 32'd0;
    end else begin
        status_request_meta_clk <= status_request_toggle_sys;
        status_request_sync_clk <= status_request_meta_clk;
        if (status_request_sync_clk != status_request_seen_clk) begin
            status_request_seen_clk <= status_request_sync_clk;
            case (status_request_addr_sys)
                16'h0100: status_response_data_clk <= {24'h0, residuals0_are_above_threshold,
                    residuals0_are_above_threshold_freq, residuals0_are_above_threshold_phase,
                    dac0_railed_negative, dac0_railed_positive, pll0_locked_instant, LED_R0, LED_G0};
                16'h0101: status_response_data_clk <= {16'h0, dpll_magnitude};
                16'h0102: status_response_data_clk <= {{14{dpll_phase_error[17]}}, dpll_phase_error};
                16'h0103: status_response_data_clk <= {{10{dpll_freq_error[21]}}, dpll_freq_error};
                16'h0104: status_response_data_clk <= dpll_freq_correction[31:0];
                16'h0105: status_response_data_clk <= dpll_tracking_word[31:0];
                16'h0106: status_response_data_clk <= {{14{dpll_phase_error[17]}}, dpll_phase_error};
                16'h0107: status_response_data_clk <= dpll_freq_state[31:0];
                16'h0108: status_response_data_clk <= {13'h0, manual_offset_overflow, vco_mul_div_config_error,
                    dpll_loop_state, dpll_loss_reason, dpll_signal_present, dpll_phase_locked,
                    dpll_frequency_locked, dpll_locked, dpll_tracking_valid, dpll_freq_error_valid,
                    dpll_iq_valid, dpll_cic_illegal, dpll_cic_overflow};
                16'h0109: status_response_data_clk <= {17'h0, dpll_active_cic_shift, dpll_active_cic_rate_r};
                16'h010A: status_response_data_clk <= {16'h0, dpll_tracking_word[47:32]};
                16'h010B: status_response_data_clk <= VCO_Input0[31:0];
                16'h010C: status_response_data_clk <= {16'h0, VCO_Input0[47:32]};
                16'h0110: status_response_data_clk <= active_center_word[47:16];
                16'h0111: status_response_data_clk <= {17'h0, active_post_iq_cic_shift, active_post_iq_cic_rate_r};
                16'h0112: status_response_data_clk <= {active_vco_mul_factor, active_vco_div_factor};
                16'h0113: status_response_data_clk <= {8'h0, active_kp};
                16'h0114: status_response_data_clk <= {8'h0, active_ki};
                16'h0115: status_response_data_clk <= {8'h0, active_kf};
                16'h0116: status_response_data_clk <= {8'h0, active_kf_blend};
                16'h0117: status_response_data_clk <= {8'h0, active_kf_track};
                16'h0118: status_response_data_clk <= {8'h0, active_kp_blend};
                16'h0119: status_response_data_clk <= {8'h0, active_ki_blend};
                16'h011A: status_response_data_clk <= {8'h0, active_measurement_timeout};
                16'h011B: status_response_data_clk <= {8'h0, active_holdover_timeout};
                16'h011C: status_response_data_clk <= ABI_VERSION;
                default:  status_response_data_clk <= 32'd0;
            endcase
            status_response_toggle_clk <= ~status_response_toggle_clk;
        end
    end
end

always @(posedge sys_clk or negedge sys_rstn) begin
    if (!sys_rstn) begin
        sys_err <= 1'b0;
        sys_ack <= 1'b0;
        sys_rdata <= 32'd0;
        status_request_toggle_sys <= 1'b0;
        status_request_addr_sys <= 16'd0;
        status_request_pending_sys <= 1'b0;
        status_response_meta_sys <= 1'b0;
        status_response_sync_sys <= 1'b0;
        status_response_seen_sys <= 1'b0;
    end else begin
        sys_err <= 1'b0;
        sys_ack <= 1'b0;
        status_response_meta_sys <= status_response_toggle_clk;
        status_response_sync_sys <= status_response_meta_sys;
        if (status_response_sync_sys != status_response_seen_sys) begin
            status_response_seen_sys <= status_response_sync_sys;
            sys_rdata <= status_response_data_clk;
            sys_ack <= 1'b1;
            status_request_pending_sys <= 1'b0;
        end else if (sys_wen) begin
            sys_ack <= 1'b1;
            sys_err <= config_apply_busy;
        end else if (sys_ren && !status_request_pending_sys) begin
            if (status_snapshot_address(cmd_addr)) begin
                status_request_addr_sys <= cmd_addr;
                status_request_toggle_sys <= ~status_request_toggle_sys;
                status_request_pending_sys <= 1'b1;
            end else begin
                sys_ack <= 1'b1;
                case (cmd_addr)
                    16'h0000: sys_rdata <= 32'h0000_0000;
                    16'h0010: sys_rdata <= Centre_Freq;
                    16'h0011: sys_rdata <= {28'h0, angleSelect_0};
                    16'h0020: sys_rdata <= {31'h0, pll0_lock_i};
                    16'h0021: sys_rdata <= pll0_gainp;
                    16'h0022: sys_rdata <= pll0_gaini;
                    16'h0023: sys_rdata <= pll0_gainii;
                    16'h0024: sys_rdata <= fll_kf_blend;
                    16'h0025: sys_rdata <= fll_kf_track;
                    16'h0026: sys_rdata <= pll_kp_blend;
                    16'h0027: sys_rdata <= pll_ki_blend;
                    16'h0028: sys_rdata <= positive_limit_dac0;
                    16'h0029: sys_rdata <= shadow_negative_limit_effective;
                    16'h002A: sys_rdata <= manual_offset_dac0;
                    16'h0030: sys_rdata <= {{18{VCO_Voffset0[13]}}, VCO_Voffset0};
                    16'h0031: sys_rdata <= {{16{VCO_Vamplitude0[15]}}, VCO_Vamplitude0};
                    16'h0032: sys_rdata <= {16'h0, VCO_Mul_Factor0};
                    16'h0033: sys_rdata <= {16'h0, VCO_Div_Factor0};
                    16'h0040: sys_rdata <= {{18{debug_dac_offset[13]}}, debug_dac_offset};
                    16'h0041: sys_rdata <= {{16{debug_dac_gain[15]}}, debug_dac_gain};
                    16'h0042: sys_rdata <= debug_dac_source;
                    16'h0043: sys_rdata <= debug_dac_format;
                    16'h0050: sys_rdata <= Phase_Residuals_Threshold0;
                    16'h0051: sys_rdata <= Phase_Residuals_Offset0;
                    16'h0052: sys_rdata <= Freq_Residuals_Threshold0;
                    16'h0053: sys_rdata <= Magnitude_Enter_Threshold0;
                    16'h0054: sys_rdata <= Magnitude_Exit_Threshold0;
                    16'h0055: sys_rdata <= Acquire_Dwell0;
                    16'h0056: sys_rdata <= Blend_Dwell0;
                    16'h0057: sys_rdata <= Loss_Dwell0;
                    16'h0058: sys_rdata <= Holdover_Timeout0;
                    16'h0059: sys_rdata <= Measurement_Timeout0;
                    16'h0060: sys_rdata <= {23'h0, post_iq_cic_rate_r};
                    16'h0061: sys_rdata <= {26'h0, post_iq_cic_shift};
                    16'h0062: sys_rdata <= {30'h0, fll_delay_sel};
                    16'h0063: sys_rdata <= {16'h0, warmup_samples};
                    16'h006F: sys_rdata <= {16'h0000, config_apply_sequence,
                        config_apply_error_code[3:0], 2'b00, config_apply_error, config_apply_busy};
                    16'h0070: sys_rdata <= {16'h0000, config_apply_rejected_mask};
                    16'h010D: sys_rdata <= CONFIG_VERSION;
                    16'h010E: sys_rdata <= ABI_VERSION;
                    16'h010F: sys_rdata <= FPGA_BUILD_ID;
                    16'h011D: sys_rdata <= FPGA_GIT_HASH;
                    default:  sys_rdata <= 32'h0000_0000;
                endcase
            end
        end
    end
end
endmodule

`default_nettype wire
