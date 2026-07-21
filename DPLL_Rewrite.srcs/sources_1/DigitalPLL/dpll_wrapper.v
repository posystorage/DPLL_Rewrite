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
// Correction-limit registers use the same high-word format as Centre_Freq:
// each signed register LSB is 2^16 DDS tuning-word LSBs.  The low 16 bits of
// the effective 48-bit correction limit are intentionally zero because a
// sub-0.03 Hz limit resolution is already much finer than the loop needs.
localparam integer CORRECTION_LIMIT_LOW_BITS = 16;
localparam [31:0] DEFAULT_DAC_AMP   = 32'h0000_7FFF;
localparam [31:0] DEFAULT_FREQ_MUL  = 32'h0000_0001;
localparam [31:0] DEFAULT_FREQ_DIV  = 32'h0000_0001;
localparam [31:0] DEFAULT_PHASE_THR = 32'h0000_7FFF;
localparam [31:0] DEFAULT_FREQ_THR  = 32'h0000_7FFF;
localparam [31:0] DEFAULT_MAG_ENTER = 32'h0000_1000;
localparam [31:0] DEFAULT_MAG_EXIT  = 32'h0000_0400;
localparam [31:0] DEFAULT_DWELL     = 32'h0000_0004;
localparam [31:0] DEFAULT_HOLDOVER  = 32'h0013_12D0; // 10 ms at 125 MHz
localparam [31:0] DEFAULT_MEAS_TIMEOUT = 32'h0000_0000; // zero selects 120*R+256
localparam [1:0] DEFAULT_POST_IIR_MODE = 2'd3; // auto: acquire in FLL, track in blend/PLL
localparam signed [31:0] DEFAULT_POST_IIR_ACQ_B0 = 32'sd138975519;   // 15 kHz at 3.125 MSPS / 31, Q2.30
localparam signed [31:0] DEFAULT_POST_IIR_ACQ_B1 = 32'sd277951039;
localparam signed [31:0] DEFAULT_POST_IIR_ACQ_B2 = 32'sd138975519;
localparam signed [31:0] DEFAULT_POST_IIR_ACQ_A1 = -32'sd812870960;
localparam signed [31:0] DEFAULT_POST_IIR_ACQ_A2 = 32'sd295031213;
localparam signed [31:0] DEFAULT_POST_IIR_TRACK_B0 = 32'sd48851600;   // 8 kHz at 3.125 MSPS / 31, Q2.30
localparam signed [31:0] DEFAULT_POST_IIR_TRACK_B1 = 32'sd97703199;
localparam signed [31:0] DEFAULT_POST_IIR_TRACK_B2 = 32'sd48851600;
localparam signed [31:0] DEFAULT_POST_IIR_TRACK_A1 = -32'sd1409400772;
localparam signed [31:0] DEFAULT_POST_IIR_TRACK_A2 = 32'sd531065347;

wire [15:0] sys_cmd_addr = sys_addr[17:2];
reg  [15:0] cmd_addr;
reg  [31:0] cmd_datain;
reg         write_request_toggle_sys;
reg         write_request_pending_sys;
(* ASYNC_REG = "TRUE" *) reg write_request_meta_clk;
(* ASYNC_REG = "TRUE" *) reg write_request_sync_clk;
reg         write_request_seen_clk;
reg         write_ack_toggle_clk;
(* ASYNC_REG = "TRUE" *) reg write_ack_meta_sys;
(* ASYNC_REG = "TRUE" *) reg write_ack_sync_sys;
reg         write_ack_seen_sys;
wire        cmd_trig = write_request_sync_clk ^ write_request_seen_clk;

wire ok_reset;
wire [31:0] Centre_Freq;
wire [3:0]  angleSelect_0;
wire        pll0_lock_i;
wire        pll0_lock;
wire signed [23:0] pll0_gainp;
wire signed [23:0] pll0_gaini;
wire signed [23:0] pll0_gainii;
wire signed [23:0] fll_kf_blend;
wire signed [23:0] fll_kf_track;
wire signed [23:0] pll_kp_blend;
wire signed [23:0] pll_ki_blend;
wire signed [31:0] positive_limit_dac0;
wire signed [31:0] negative_limit_dac0;
wire signed [31:0] manual_offset_dac0;
wire signed [13:0] VCO_Voffset0;
wire [15:0] VCO_Vamplitude0;
wire [15:0] VCO_Mul_Factor0;
wire [15:0] VCO_Div_Factor0;
wire signed [13:0] debug_dac_offset;
wire signed [15:0] debug_dac_gain;
wire [3:0] debug_dac_source;
wire [11:0] debug_dac_format;
wire        debug_dac_offset_update;
wire        debug_dac_gain_update;
wire        debug_dac_source_update;
wire        debug_dac_format_update;
wire [17:0] Phase_Residuals_Threshold0;
wire signed [17:0] Phase_Residuals_Offset0;
wire [21:0] Freq_Residuals_Threshold0;
wire [19:0] Magnitude_Enter_Threshold0;
wire [19:0] Magnitude_Exit_Threshold0;
wire [15:0] Acquire_Dwell0;
wire [15:0] Blend_Dwell0;
wire [15:0] Loss_Dwell0;
wire [23:0] Holdover_Timeout0;
wire [23:0] Measurement_Timeout0;
wire [8:0] post_iq_cic_rate_r;
wire [5:0] post_iq_cic_shift;
wire [1:0] fll_delay_sel;
wire [15:0] warmup_samples;
reg [1:0] post_iir_mode;
reg signed [31:0] post_iir_acq_b0;
reg signed [31:0] post_iir_acq_b1;
reg signed [31:0] post_iir_acq_b2;
reg signed [31:0] post_iir_acq_a1;
reg signed [31:0] post_iir_acq_a2;
reg signed [31:0] post_iir_track_b0;
reg signed [31:0] post_iir_track_b1;
reg signed [31:0] post_iir_track_b2;
reg signed [31:0] post_iir_track_a1;
reg signed [31:0] post_iir_track_a2;
wire unused_sys_sel = |sys_sel;
wire unused_angle = |angleSelect_0;

parallel_bus_register_32bits_or_less #(
    .REGISTER_SIZE(8),
    .REGISTER_DEFAULT_VALUE(0),
    .ADDRESS(16'h0000)
) reg_ok_reset (
    .clk(clk1),
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
    .clk(clk1),
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
    .clk(clk1),
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
    .clk(clk1),
    .bus_strobe(cmd_trig),
    .bus_address(cmd_addr),
    .bus_data(cmd_datain),
    .register_output(pll0_lock_i),
    .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0021)) reg_kp (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gainp), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(2), .ADDRESS(16'h0022)) reg_ki (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gaini), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(8), .ADDRESS(16'h0023)) reg_kf (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gainii), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0024)) reg_kf_blend (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(fll_kf_blend), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(1), .ADDRESS(16'h0025)) reg_kf_track (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(fll_kf_track), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(2), .ADDRESS(16'h0026)) reg_kp_blend (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll_kp_blend), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(1), .ADDRESS(16'h0027)) reg_ki_blend (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll_ki_blend), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_POS_LIMIT), .ADDRESS(16'h0028)) reg_pos_limit (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(positive_limit_dac0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0029)) reg_neg_limit (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(negative_limit_dac0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h002A)) reg_manual_offset (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(manual_offset_dac0), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(14), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0030)) reg_dac0_offset (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Voffset0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DAC_AMP), .ADDRESS(16'h0031)) reg_dac0_amp (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Vamplitude0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_FREQ_MUL), .ADDRESS(16'h0032)) reg_freq_mul (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Mul_Factor0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_FREQ_DIV), .ADDRESS(16'h0033)) reg_freq_div (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(VCO_Div_Factor0), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(14), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0040)) reg_debug_offset (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_offset), .update_flag(debug_dac_offset_update)
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DAC_AMP), .ADDRESS(16'h0041)) reg_debug_gain (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_gain), .update_flag(debug_dac_gain_update)
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(4), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0042)) reg_debug_source (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_source), .update_flag(debug_dac_source_update)
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(12), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0043)) reg_debug_format (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_format), .update_flag(debug_dac_format_update)
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(18), .REGISTER_DEFAULT_VALUE(DEFAULT_PHASE_THR), .ADDRESS(16'h0050)) reg_phase_thr (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Phase_Residuals_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(18), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0051)) reg_phase_offset (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Phase_Residuals_Offset0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(22), .REGISTER_DEFAULT_VALUE(DEFAULT_FREQ_THR), .ADDRESS(16'h0052)) reg_freq_thr (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Freq_Residuals_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(20), .REGISTER_DEFAULT_VALUE(DEFAULT_MAG_ENTER), .ADDRESS(16'h0053)) reg_mag_enter (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Magnitude_Enter_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(20), .REGISTER_DEFAULT_VALUE(DEFAULT_MAG_EXIT), .ADDRESS(16'h0054)) reg_mag_exit (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Magnitude_Exit_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DWELL), .ADDRESS(16'h0055)) reg_acquire_dwell (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Acquire_Dwell0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DWELL), .ADDRESS(16'h0056)) reg_blend_dwell (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Blend_Dwell0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DWELL), .ADDRESS(16'h0057)) reg_loss_dwell (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Loss_Dwell0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(DEFAULT_HOLDOVER), .ADDRESS(16'h0058)) reg_holdover_timeout (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Holdover_Timeout0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(24), .REGISTER_DEFAULT_VALUE(DEFAULT_MEAS_TIMEOUT), .ADDRESS(16'h0059)) reg_measurement_timeout (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Measurement_Timeout0), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(9), .REGISTER_DEFAULT_VALUE(31), .ADDRESS(16'h0060)) reg_cic_rate (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(post_iq_cic_rate_r), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(6), .REGISTER_DEFAULT_VALUE(10), .ADDRESS(16'h0061)) reg_cic_shift (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(post_iq_cic_shift), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(2), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0062)) reg_fll_delay (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(fll_delay_sel), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0063)) reg_warmup_samples (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(warmup_samples), .update_flag()
);
always @(posedge clk1) begin
    if (!rst) begin
        post_iir_mode <= DEFAULT_POST_IIR_MODE;
        post_iir_acq_b0 <= DEFAULT_POST_IIR_ACQ_B0;
        post_iir_acq_b1 <= DEFAULT_POST_IIR_ACQ_B1;
        post_iir_acq_b2 <= DEFAULT_POST_IIR_ACQ_B2;
        post_iir_acq_a1 <= DEFAULT_POST_IIR_ACQ_A1;
        post_iir_acq_a2 <= DEFAULT_POST_IIR_ACQ_A2;
        post_iir_track_b0 <= DEFAULT_POST_IIR_TRACK_B0;
        post_iir_track_b1 <= DEFAULT_POST_IIR_TRACK_B1;
        post_iir_track_b2 <= DEFAULT_POST_IIR_TRACK_B2;
        post_iir_track_a1 <= DEFAULT_POST_IIR_TRACK_A1;
        post_iir_track_a2 <= DEFAULT_POST_IIR_TRACK_A2;
    end else if (cmd_trig) begin
        case (cmd_addr)
            16'h0064: post_iir_mode <= cmd_datain[1:0];
            16'h0065: post_iir_acq_b0 <= cmd_datain;
            16'h0066: post_iir_acq_b1 <= cmd_datain;
            16'h0067: post_iir_acq_b2 <= cmd_datain;
            16'h0068: post_iir_acq_a1 <= cmd_datain;
            16'h0069: post_iir_acq_a2 <= cmd_datain;
            16'h006A: post_iir_track_b0 <= cmd_datain;
            16'h006B: post_iir_track_b1 <= cmd_datain;
            16'h006C: post_iir_track_b2 <= cmd_datain;
            16'h006D: post_iir_track_a1 <= cmd_datain;
            16'h006E: post_iir_track_a2 <= cmd_datain;
            default: begin end
        endcase
    end
end

assign pll0_lock = pll0_lock_i;

wire rst_125m_stage_a;
wire [15:0] pre_cic_sample;
wire        pre_cic_valid;
wire        pre_cic_ready;

reg rst_125m_meta;
reg rst_125m_sync;
wire reset_pulse_clk = ok_reset;
(* keep = "true", dont_touch = "true" *) reg rst_debug_r;
(* keep = "true", dont_touch = "true" *) reg rst_status_r;
(* keep = "true", dont_touch = "true" *) reg rst_core_r;
(* keep = "true", dont_touch = "true" *) reg rst_vco_r;
always @(posedge clk1 or negedge rst) begin
    if (!rst) begin
        rst_125m_meta <= 1'b1;
        rst_125m_sync <= 1'b1;
        rst_debug_r <= 1'b1;
        rst_status_r <= 1'b1;
        rst_core_r <= 1'b1;
        rst_vco_r <= 1'b1;
    end else begin
        rst_125m_meta <= reset_pulse_clk;
        rst_125m_sync <= rst_125m_meta;
        rst_debug_r <= rst_125m_sync;
        rst_status_r <= rst_125m_sync;
        rst_core_r <= rst_125m_sync;
        rst_vco_r <= rst_125m_sync;
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
wire [19:0] dpll_magnitude;
wire [3:0]  dpll_loop_state;
wire [3:0]  dpll_loss_reason;
wire        dpll_signal_present;
wire        dpll_phase_locked;
wire        dpll_frequency_locked;
wire        dpll_locked;
wire [8:0]  dpll_active_cic_rate_r;
wire [5:0]  dpll_active_cic_shift;
wire        dpll_post_iir_active_bypass;
wire        dpll_post_iir_active_use_track;
wire        dpll_cic_overflow;
wire        dpll_cordic_input_overrun;
wire        dpll_cordic_input_out_of_range;
wire        dpll_cordic_output_format_error;
wire signed [15:0] dpll_lo_cos;
wire signed [15:0] dpll_lo_sin;

wire [47:0] active_center_word = {Centre_Freq, 16'h0000};
wire signed [55:0] active_correction_limit_pos =
    {{(56-32-CORRECTION_LIMIT_LOW_BITS){positive_limit_dac0[31]}},
     positive_limit_dac0, {CORRECTION_LIMIT_LOW_BITS{1'b0}}};
wire signed [55:0] active_correction_limit_neg =
    {{(56-32-CORRECTION_LIMIT_LOW_BITS){negative_limit_dac0[31]}},
     negative_limit_dac0, {CORRECTION_LIMIT_LOW_BITS{1'b0}}};
wire signed [23:0] active_kf = pll0_gainii;
wire signed [23:0] active_ki = pll0_gaini;
wire signed [23:0] active_kp = pll0_gainp;
wire signed [23:0] active_kf_blend = fll_kf_blend;
wire signed [23:0] active_kf_track = fll_kf_track;
wire signed [23:0] active_kp_blend = pll_kp_blend;
wire signed [23:0] active_ki_blend = pll_ki_blend;
wire signed [17:0] active_phase_setpoint = Phase_Residuals_Offset0;
wire [17:0] active_phase_lock_threshold = Phase_Residuals_Threshold0;
wire [21:0] active_freq_lock_threshold = Freq_Residuals_Threshold0;
wire [19:0] active_mag_enter_threshold = Magnitude_Enter_Threshold0;
wire [19:0] active_mag_exit_threshold = Magnitude_Exit_Threshold0;
wire [15:0] active_acquire_dwell = Acquire_Dwell0;
wire [15:0] active_blend_dwell = Blend_Dwell0;
wire [15:0] active_loss_dwell = Loss_Dwell0;
wire [23:0] active_holdover_timeout = Holdover_Timeout0;
wire [23:0] active_measurement_timeout = Measurement_Timeout0;
wire [15:0] active_warmup_samples = warmup_samples;
wire [8:0] active_post_iq_cic_rate_r = post_iq_cic_rate_r;
wire [5:0] active_post_iq_cic_shift = post_iq_cic_shift;
wire [1:0] active_fll_delay_sel = fll_delay_sel;
wire [1:0] active_post_iir_mode = post_iir_mode;
wire signed [31:0] active_post_iir_acq_b0 = post_iir_acq_b0;
wire signed [31:0] active_post_iir_acq_b1 = post_iir_acq_b1;
wire signed [31:0] active_post_iir_acq_b2 = post_iir_acq_b2;
wire signed [31:0] active_post_iir_acq_a1 = post_iir_acq_a1;
wire signed [31:0] active_post_iir_acq_a2 = post_iir_acq_a2;
wire signed [31:0] active_post_iir_track_b0 = post_iir_track_b0;
wire signed [31:0] active_post_iir_track_b1 = post_iir_track_b1;
wire signed [31:0] active_post_iir_track_b2 = post_iir_track_b2;
wire signed [31:0] active_post_iir_track_a1 = post_iir_track_a1;
wire signed [31:0] active_post_iir_track_a2 = post_iir_track_a2;
wire signed [31:0] active_manual_offset_dac0 = manual_offset_dac0;
wire signed [13:0] active_vco_offset = VCO_Voffset0;
wire signed [15:0] active_vco_amplitude = VCO_Vamplitude0;
wire [15:0] active_vco_mul_factor = VCO_Mul_Factor0;
wire [15:0] active_vco_div_factor = VCO_Div_Factor0;

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
wire signed [13:0] live_debug_dac_offset = debug_dac_offset;
wire signed [15:0] live_debug_dac_gain = debug_dac_gain;
wire [3:0] live_debug_dac_source = debug_dac_source;
wire [11:0] live_debug_dac_format = debug_dac_format;

always @(posedge clk1 or negedge rst) begin
    if (!rst) begin
        write_request_meta_clk <= 1'b0;
        write_request_sync_clk <= 1'b0;
        write_request_seen_clk <= 1'b0;
        write_ack_toggle_clk <= 1'b0;
    end else begin
        write_request_meta_clk <= write_request_toggle_sys;
        write_request_sync_clk <= write_request_meta_clk;
        if (cmd_trig) begin
            write_request_seen_clk <= write_request_sync_clk;
            write_ack_toggle_clk <= ~write_ack_toggle_clk;
        end
    end
end
wire signed [55:0] correction_limit_pos = active_correction_limit_pos;
wire signed [55:0] correction_limit_neg = active_correction_limit_neg;

dpll_single_clock_core_stage_a dpll_single_clock_core_stage_a_inst (
    .clk_125m(clk1),
    .rst_125m(rst_core_r),
    .sample_valid(pre_cic_valid),
    .loop_enable(pll0_lock),
    .status_clear(datapath_status_clear),
    .adc_sample(pre_cic_sample),
    .center_word(active_center_word),
    .controller_reacquire(controller_reacquire_pulse),
    .detector_reconfigure(detector_reconfigure_pulse),
    .cic_rate_r(active_post_iq_cic_rate_r),
    .cic_output_shift(active_post_iq_cic_shift),
    .cic_flush(reset_pulse_clk),
    .fll_delay_sel(active_fll_delay_sel),
    .post_iir_mode(active_post_iir_mode),
    .post_iir_acq_b0(active_post_iir_acq_b0),
    .post_iir_acq_b1(active_post_iir_acq_b1),
    .post_iir_acq_b2(active_post_iir_acq_b2),
    .post_iir_acq_a1(active_post_iir_acq_a1),
    .post_iir_acq_a2(active_post_iir_acq_a2),
    .post_iir_track_b0(active_post_iir_track_b0),
    .post_iir_track_b1(active_post_iir_track_b1),
    .post_iir_track_b2(active_post_iir_track_b2),
    .post_iir_track_a1(active_post_iir_track_a1),
    .post_iir_track_a2(active_post_iir_track_a2),
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
    .post_iir_active_bypass(dpll_post_iir_active_bypass),
    .post_iir_active_use_track(dpll_post_iir_active_use_track),
    .cic_overflow_seen(dpll_cic_overflow),
    .cordic_input_overrun_seen(dpll_cordic_input_overrun),
    .cordic_input_out_of_range_seen(dpll_cordic_input_out_of_range),
    .cordic_output_format_error_seen(dpll_cordic_output_format_error),
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
PLL_VCO_MUL_DIV PLL_VCO_MUL_DIV_inst (
    .clk(clk1),
    .rst(rst_vco_r),
    .sample_valid(dpll_tracking_valid),
    .data_in(vco_tracking_word),
    .data_out(VCO_Input0),
    .PLL_Mul_factor(active_vco_mul_factor),
    .PLL_Div_factor(active_vco_div_factor)
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
            4'h8: debug_source_mux = {12'h000, dpll_magnitude};
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
        debug_word_r <= debug_source_mux(live_debug_dac_source[3:0]);
    end
end

debug_dac_formatter_stage_a debug_dac_formatter_inst (
    .clk_125m(clk1),
    .rst_125m(rst_debug_r),
    .source_valid(1'b1),
    .source_word(debug_word_r),
    .format_word({20'h0, live_debug_dac_format}),
    .gain(live_debug_dac_gain),
    .offset({{2{live_debug_dac_offset[13]}}, live_debug_dac_offset}),
    .dac_sample(DACout1)
);

wire [31:0] phase_abs = abs18_extend(dpll_phase_error);
wire [31:0] freq_abs = abs22_extend(dpll_freq_error);
wire phase_residual_bad = ~dpll_phase_locked;
wire freq_residual_bad = ~dpll_frequency_locked;
wire dac0_railed_positive = dpll_freq_correction >= correction_limit_pos;
wire dac0_railed_negative = dpll_freq_correction <= correction_limit_neg;
wire pll0_locked_instant;
localparam [25:0] RESIDUAL_WINDOW_CYCLES = 26'd33554432; // 2^25 at 125 MHz
reg [25:0] phase_residual_window_count;
reg [25:0] freq_residual_window_count;
reg [25:0] saturation_window_count;
reg [25:0] datapath_fault_window_count;
reg phase_residual_window_bad;
reg freq_residual_window_bad;
reg saturation_window_bad;
reg datapath_fault_window_bad;
wire residuals0_are_above_threshold_phase = phase_residual_window_bad;
wire residuals0_are_above_threshold_freq = freq_residual_window_bad;
reg residuals0_are_above_threshold;
reg LED_G0;
reg LED_R0;
reg [23:0] status_counter;
wire output_saturation_event = dac0_railed_positive | dac0_railed_negative;
wire pre_cic_backpressure_seen = ~rst_125m_stage_a && !pre_cic_ready;
wire datapath_fault_event = dpll_cic_overflow |
                            dpll_cordic_input_overrun |
                            dpll_cordic_input_out_of_range |
                            dpll_cordic_output_format_error |
                            pre_cic_backpressure_seen;
wire datapath_status_clear = !pll0_lock || datapath_fault_event;
wire datapath_fault = datapath_fault_window_bad;
wire lock_qualification_bad = phase_residual_bad | freq_residual_bad |
                               phase_residual_window_bad |
                               freq_residual_window_bad |
                               output_saturation_event | saturation_window_bad |
                               datapath_fault_window_bad;
assign pll0_locked_instant = dpll_locked && !lock_qualification_bad;

always @(posedge clk1) begin
    if (rst_status_r) begin
        residuals0_are_above_threshold <= 1'b0;
        phase_residual_window_count <= 26'd0;
        freq_residual_window_count <= 26'd0;
        saturation_window_count <= 26'd0;
        datapath_fault_window_count <= 26'd0;
        phase_residual_window_bad <= 1'b0;
        freq_residual_window_bad <= 1'b0;
        saturation_window_bad <= 1'b0;
        datapath_fault_window_bad <= 1'b0;
        LED_G0 <= 1'b0;
        LED_R0 <= 1'b1;
        status_counter <= 24'h0;
    end else if (!pll0_lock) begin
        residuals0_are_above_threshold <= 1'b0;
        phase_residual_window_count <= 26'd0;
        freq_residual_window_count <= 26'd0;
        saturation_window_count <= 26'd0;
        datapath_fault_window_count <= 26'd0;
        phase_residual_window_bad <= 1'b0;
        freq_residual_window_bad <= 1'b0;
        saturation_window_bad <= 1'b0;
        datapath_fault_window_bad <= 1'b0;
        LED_G0 <= 1'b0;
        LED_R0 <= 1'b1;
        status_counter <= status_counter + 24'h1;
    end else begin
        if (phase_residual_bad) begin
            phase_residual_window_count <= 26'd0;
            phase_residual_window_bad <= 1'b1;
        end else if (phase_residual_window_bad) begin
            if (phase_residual_window_count < RESIDUAL_WINDOW_CYCLES)
                phase_residual_window_count <= phase_residual_window_count + 1'b1;
            else
                phase_residual_window_bad <= 1'b0;
        end
        if (freq_residual_bad) begin
            freq_residual_window_count <= 26'd0;
            freq_residual_window_bad <= 1'b1;
        end else if (freq_residual_window_bad) begin
            if (freq_residual_window_count < RESIDUAL_WINDOW_CYCLES)
                freq_residual_window_count <= freq_residual_window_count + 1'b1;
            else
                freq_residual_window_bad <= 1'b0;
        end
        if (output_saturation_event) begin
            saturation_window_count <= 26'd0;
            saturation_window_bad <= 1'b1;
        end else if (saturation_window_bad) begin
            if (saturation_window_count < RESIDUAL_WINDOW_CYCLES)
                saturation_window_count <= saturation_window_count + 1'b1;
            else
                saturation_window_bad <= 1'b0;
        end
        if (datapath_fault_event) begin
            datapath_fault_window_count <= 26'd0;
            datapath_fault_window_bad <= 1'b1;
        end else if (datapath_fault_window_bad) begin
            if (datapath_fault_window_count < RESIDUAL_WINDOW_CYCLES)
                datapath_fault_window_count <= datapath_fault_window_count + 1'b1;
            else
                datapath_fault_window_bad <= 1'b0;
        end
        residuals0_are_above_threshold <= phase_residual_window_bad |
                                           freq_residual_window_bad;
        status_counter <= status_counter + 24'h1;
        LED_G0 <= dpll_locked && !lock_qualification_bad &&
                  !phase_residual_window_bad && !freq_residual_window_bad;
        LED_R0 <= !(dpll_locked && !lock_qualification_bad &&
                    !phase_residual_window_bad && !freq_residual_window_bad);
    end
end

wire gain_update = cmd_trig && (cmd_addr >= 16'h0021) && (cmd_addr <= 16'h0027);
wire detector_config_update = cmd_trig &&
    (((cmd_addr >= 16'h0060) && (cmd_addr <= 16'h0062)) ||
     ((cmd_addr >= 16'h0064) && (cmd_addr <= 16'h006E)));
wire reconfigure_command = cmd_trig && (cmd_addr == 16'h006F);
wire detector_reconfigure_pulse = detector_config_update |
    (reconfigure_command && cmd_datain[1]);
wire controller_reacquire_pulse = gain_update | detector_reconfigure_pulse |
    (reconfigure_command && cmd_datain[0]);

// led[0..5] are mapped to physical LED0..LED5 by red_pitaya_top.
assign led = {1'b0, datapath_fault, saturation_window_bad,
              freq_residual_window_bad, phase_residual_window_bad,
              LED_R0, LED_G0};

function status_snapshot_address;
    input [15:0] address;
    begin
        status_snapshot_address = (address <= 16'h0070) ||
                                  ((address >= 16'h0100) && (address <= 16'h0135));
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
                16'h0000: status_response_data_clk <= 32'h0000_0000;
                16'h0010: status_response_data_clk <= Centre_Freq;
                16'h0011: status_response_data_clk <= {28'h0, angleSelect_0};
                16'h0020: status_response_data_clk <= {31'h0, pll0_lock_i};
                16'h0021: status_response_data_clk <= {{8{pll0_gainp[23]}}, pll0_gainp};
                16'h0022: status_response_data_clk <= {{8{pll0_gaini[23]}}, pll0_gaini};
                16'h0023: status_response_data_clk <= {{8{pll0_gainii[23]}}, pll0_gainii};
                16'h0024: status_response_data_clk <= {{8{fll_kf_blend[23]}}, fll_kf_blend};
                16'h0025: status_response_data_clk <= {{8{fll_kf_track[23]}}, fll_kf_track};
                16'h0026: status_response_data_clk <= {{8{pll_kp_blend[23]}}, pll_kp_blend};
                16'h0027: status_response_data_clk <= {{8{pll_ki_blend[23]}}, pll_ki_blend};
                16'h0028: status_response_data_clk <= positive_limit_dac0;
                16'h0029: status_response_data_clk <= negative_limit_dac0;
                16'h002A: status_response_data_clk <= manual_offset_dac0;
                16'h0030: status_response_data_clk <= {{18{VCO_Voffset0[13]}}, VCO_Voffset0};
                16'h0031: status_response_data_clk <= {16'h0, VCO_Vamplitude0};
                16'h0032: status_response_data_clk <= {16'h0, VCO_Mul_Factor0};
                16'h0033: status_response_data_clk <= {16'h0, VCO_Div_Factor0};
                16'h0040: status_response_data_clk <= {{18{debug_dac_offset[13]}}, debug_dac_offset};
                16'h0041: status_response_data_clk <= {{16{debug_dac_gain[15]}}, debug_dac_gain};
                16'h0042: status_response_data_clk <= {28'h0, debug_dac_source};
                16'h0043: status_response_data_clk <= {20'h0, debug_dac_format};
                16'h0050: status_response_data_clk <= {14'h0, Phase_Residuals_Threshold0};
                16'h0051: status_response_data_clk <= {{14{Phase_Residuals_Offset0[17]}}, Phase_Residuals_Offset0};
                16'h0052: status_response_data_clk <= {10'h0, Freq_Residuals_Threshold0};
                16'h0053: status_response_data_clk <= {12'h0, Magnitude_Enter_Threshold0};
                16'h0054: status_response_data_clk <= {12'h0, Magnitude_Exit_Threshold0};
                16'h0055: status_response_data_clk <= {16'h0, Acquire_Dwell0};
                16'h0056: status_response_data_clk <= {16'h0, Blend_Dwell0};
                16'h0057: status_response_data_clk <= {16'h0, Loss_Dwell0};
                16'h0058: status_response_data_clk <= {8'h0, Holdover_Timeout0};
                16'h0059: status_response_data_clk <= {8'h0, Measurement_Timeout0};
                16'h0060: status_response_data_clk <= {23'h0, post_iq_cic_rate_r};
                16'h0061: status_response_data_clk <= {26'h0, post_iq_cic_shift};
                16'h0062: status_response_data_clk <= {30'h0, fll_delay_sel};
                16'h0063: status_response_data_clk <= {16'h0, warmup_samples};
                16'h0064: status_response_data_clk <= {30'h0, post_iir_mode};
                16'h0065: status_response_data_clk <= post_iir_acq_b0;
                16'h0066: status_response_data_clk <= post_iir_acq_b1;
                16'h0067: status_response_data_clk <= post_iir_acq_b2;
                16'h0068: status_response_data_clk <= post_iir_acq_a1;
                16'h0069: status_response_data_clk <= post_iir_acq_a2;
                16'h006A: status_response_data_clk <= post_iir_track_b0;
                16'h006B: status_response_data_clk <= post_iir_track_b1;
                16'h006C: status_response_data_clk <= post_iir_track_b2;
                16'h006D: status_response_data_clk <= post_iir_track_a1;
                16'h006E: status_response_data_clk <= post_iir_track_a2;
                16'h006F: status_response_data_clk <= 32'h0000_0000;
                16'h0070: status_response_data_clk <= 32'h0000_0000;
                16'h0100: status_response_data_clk <= {24'h0, residuals0_are_above_threshold,
                    residuals0_are_above_threshold_freq, residuals0_are_above_threshold_phase,
                    dac0_railed_negative, dac0_railed_positive, pll0_locked_instant, LED_R0, LED_G0};
                16'h0101: status_response_data_clk <= {12'h0, dpll_magnitude};
                16'h0102: status_response_data_clk <= {{14{dpll_phase_error[17]}}, dpll_phase_error};
                16'h0103: status_response_data_clk <= {{10{dpll_freq_error[21]}}, dpll_freq_error};
                16'h0104: status_response_data_clk <= dpll_freq_correction[31:0];
                16'h0105: status_response_data_clk <= dpll_tracking_word[31:0];
                16'h0106: status_response_data_clk <= {{14{dpll_phase_error[17]}}, dpll_phase_error};
                16'h0107: status_response_data_clk <= dpll_freq_state[31:0];
                16'h0108: status_response_data_clk <= {7'h0, dpll_post_iir_active_use_track,
                    dpll_post_iir_active_bypass, dpll_cordic_output_format_error,
                    dpll_cordic_input_out_of_range, dpll_cordic_input_overrun, pre_cic_backpressure_seen,
                    manual_offset_overflow, 1'b0,
                    dpll_loop_state, dpll_loss_reason, dpll_signal_present, dpll_phase_locked,
                    dpll_frequency_locked, pll0_locked_instant, dpll_tracking_valid, dpll_freq_error_valid,
                    dpll_iq_valid, 1'b0, dpll_cic_overflow};
                16'h0109: status_response_data_clk <= {17'h0, dpll_active_cic_shift, dpll_active_cic_rate_r};
                16'h010A: status_response_data_clk <= {16'h0, dpll_tracking_word[47:32]};
                16'h010B: status_response_data_clk <= VCO_Input0[31:0];
                16'h010C: status_response_data_clk <= {16'h0, VCO_Input0[47:32]};
                16'h010D: status_response_data_clk <= CONFIG_VERSION;
                16'h010E: status_response_data_clk <= ABI_VERSION;
                16'h010F: status_response_data_clk <= FPGA_BUILD_ID;
                16'h0110: status_response_data_clk <= active_center_word[47:16];
                16'h0111: status_response_data_clk <= {17'h0, active_post_iq_cic_shift, active_post_iq_cic_rate_r};
                16'h0112: status_response_data_clk <= {active_vco_mul_factor, active_vco_div_factor};
                16'h0113: status_response_data_clk <= {{8{active_kp[23]}}, active_kp};
                16'h0114: status_response_data_clk <= {{8{active_ki[23]}}, active_ki};
                16'h0115: status_response_data_clk <= {{8{active_kf[23]}}, active_kf};
                16'h0116: status_response_data_clk <= {{8{active_kf_blend[23]}}, active_kf_blend};
                16'h0117: status_response_data_clk <= {{8{active_kf_track[23]}}, active_kf_track};
                16'h0118: status_response_data_clk <= {{8{active_kp_blend[23]}}, active_kp_blend};
                16'h0119: status_response_data_clk <= {{8{active_ki_blend[23]}}, active_ki_blend};
                16'h011A: status_response_data_clk <= {8'h0, active_measurement_timeout};
                16'h011B: status_response_data_clk <= {8'h0, active_holdover_timeout};
                16'h011C: status_response_data_clk <= ABI_VERSION;
                16'h011D: status_response_data_clk <= FPGA_GIT_HASH;
                16'h011E: status_response_data_clk <= 32'd0;
                16'h011F: status_response_data_clk <= {30'h0, active_post_iir_mode};
                16'h0120: status_response_data_clk <= active_post_iir_acq_b0;
                16'h0121: status_response_data_clk <= active_post_iir_acq_b1;
                16'h0122: status_response_data_clk <= active_post_iir_acq_b2;
                16'h0123: status_response_data_clk <= active_post_iir_acq_a1;
                16'h0124: status_response_data_clk <= active_post_iir_acq_a2;
                16'h0125: status_response_data_clk <= active_post_iir_track_b0;
                16'h0126: status_response_data_clk <= active_post_iir_track_b1;
                16'h0127: status_response_data_clk <= active_post_iir_track_b2;
                16'h0128: status_response_data_clk <= active_post_iir_track_a1;
                16'h0129: status_response_data_clk <= active_post_iir_track_a2;
                16'h012A: status_response_data_clk <= {{14{active_phase_setpoint[17]}}, active_phase_setpoint};
                16'h012B: status_response_data_clk <= {14'h0, active_phase_lock_threshold};
                16'h012C: status_response_data_clk <= {10'h0, active_freq_lock_threshold};
                16'h012D: status_response_data_clk <= {12'h0, active_mag_enter_threshold};
                16'h012E: status_response_data_clk <= {12'h0, active_mag_exit_threshold};
                16'h012F: status_response_data_clk <= {active_acquire_dwell, active_blend_dwell};
                16'h0130: status_response_data_clk <= {active_loss_dwell, active_warmup_samples};
                16'h0131: status_response_data_clk <= active_correction_limit_pos[47:16];
                16'h0132: status_response_data_clk <= active_correction_limit_neg[47:16];
                16'h0133: status_response_data_clk <= active_manual_offset_dac0;
                16'h0134: status_response_data_clk <=
                    {{2{active_vco_offset[13]}}, active_vco_offset, active_vco_amplitude};
                16'h0135: status_response_data_clk <= {30'h0, active_fll_delay_sel};
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
        cmd_addr <= 16'd0;
        cmd_datain <= 32'd0;
        write_request_toggle_sys <= 1'b0;
        write_request_pending_sys <= 1'b0;
        write_ack_meta_sys <= 1'b0;
        write_ack_sync_sys <= 1'b0;
        write_ack_seen_sys <= 1'b0;
    end else begin
        sys_err <= 1'b0;
        sys_ack <= 1'b0;
        status_response_meta_sys <= status_response_toggle_clk;
        status_response_sync_sys <= status_response_meta_sys;
        write_ack_meta_sys <= write_ack_toggle_clk;
        write_ack_sync_sys <= write_ack_meta_sys;
        if (status_response_sync_sys != status_response_seen_sys) begin
            status_response_seen_sys <= status_response_sync_sys;
            sys_rdata <= status_response_data_clk;
            sys_ack <= 1'b1;
            status_request_pending_sys <= 1'b0;
        end else if (write_ack_sync_sys != write_ack_seen_sys) begin
            write_ack_seen_sys <= write_ack_sync_sys;
            sys_ack <= 1'b1;
            write_request_pending_sys <= 1'b0;
        end else if (sys_wen && !write_request_pending_sys) begin
            cmd_addr <= sys_cmd_addr;
            cmd_datain <= sys_wdata;
            write_request_toggle_sys <= ~write_request_toggle_sys;
            write_request_pending_sys <= 1'b1;
        end else if (sys_ren && !status_request_pending_sys) begin
            if (status_snapshot_address(sys_cmd_addr)) begin
                status_request_addr_sys <= sys_cmd_addr;
                status_request_toggle_sys <= ~status_request_toggle_sys;
                status_request_pending_sys <= 1'b1;
            end else begin
                sys_ack <= 1'b1;
                sys_rdata <= 32'h0000_0000;
            end
        end
    end
end
endmodule

`default_nettype wire
