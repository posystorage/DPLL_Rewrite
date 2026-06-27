// Digital-PLL wrapper
// Single-clock active DPLL path, ABI v1 compatible register shell.

`default_nettype none

module dpll_wrapper(
    input  wire               clk1,
    input  wire               rst,

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

localparam [31:0] ABI_VERSION       = 32'h0000_0001;
localparam [31:0] CONFIG_VERSION    = 32'h0001_0000;
localparam [31:0] FPGA_BUILD_ID     = 32'hD911_0002;
localparam [31:0] DEFAULT_POS_LIMIT = 32'h7FFF_FFFF;
localparam [31:0] DEFAULT_NEG_LIMIT = 32'h8000_0000;
localparam [31:0] DEFAULT_DAC_AMP   = 32'h0000_7FFF;
localparam [31:0] DEFAULT_FREQ_MUL  = 32'h0000_0001;
localparam [31:0] DEFAULT_FREQ_DIV  = 32'h0000_0001;
localparam [31:0] DEFAULT_PHASE_THR = 32'h0000_7FFF;
localparam [31:0] DEFAULT_FREQ_THR  = 32'h0000_7FFF;

wire [15:0] cmd_addr;
wire [31:0] cmd_datain;
wire        cmd_trig;

assign cmd_trig   = sys_wen;
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
wire [31:0] pll0_gaind;
wire [17:0] pll0_coefdfilter;
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
wire [8:0]  post_iq_cic_rate_r;
wire [5:0]  post_iq_cic_shift;
wire [1:0]  fll_delay_sel;
wire        config_apply_flag;

wire unused_sys_sel = |sys_sel;
wire unused_adc1 = |ADCraw1;
wire unused_angle = |angleSelect_0;
wire unused_gaind = |pll0_gaind;
wire unused_coef = |pll0_coefdfilter;
wire unused_phase_offset = |Phase_Residuals_Offset0;
wire unused_debug_format = |debug_dac_format;

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

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(4), .ADDRESS(16'h0021)) reg_kp (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gainp), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(2), .ADDRESS(16'h0022)) reg_ki (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gaini), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(8), .ADDRESS(16'h0023)) reg_kf (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gainii), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0024)) reg_gain_d_compat (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_gaind), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(18), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0025)) reg_coef_compat (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(pll0_coefdfilter), .update_flag()
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
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_offset), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(16), .REGISTER_DEFAULT_VALUE(DEFAULT_DAC_AMP), .ADDRESS(16'h0041)) reg_debug_gain (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_gain), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0042)) reg_debug_source (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_source), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0043)) reg_debug_format (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(debug_dac_format), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_PHASE_THR), .ADDRESS(16'h0050)) reg_phase_thr (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Phase_Residuals_Threshold0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0051)) reg_phase_offset (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Phase_Residuals_Offset0), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(32), .REGISTER_DEFAULT_VALUE(DEFAULT_FREQ_THR), .ADDRESS(16'h0052)) reg_freq_thr (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(Freq_Residuals_Threshold0), .update_flag()
);

parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(9), .REGISTER_DEFAULT_VALUE(8), .ADDRESS(16'h0060)) reg_cic_rate (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(post_iq_cic_rate_r), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(6), .REGISTER_DEFAULT_VALUE(9), .ADDRESS(16'h0061)) reg_cic_shift (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(post_iq_cic_shift), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(2), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h0062)) reg_fll_delay (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(fll_delay_sel), .update_flag()
);
parallel_bus_register_32bits_or_less #(.REGISTER_SIZE(1), .REGISTER_DEFAULT_VALUE(0), .ADDRESS(16'h006F)) reg_config_apply (
    .clk(clk1), .bus_strobe(cmd_trig), .bus_address(cmd_addr), .bus_data(cmd_datain), .register_output(), .update_flag(config_apply_flag)
);

assign pll0_lock = pll0_lock_i;

wire rst_125m_stage_a;
wire sample_3m125_valid_stage_a;

dpll_clock_valid_stage_a #(
    .G_SAMPLE_DIV(40)
) dpll_clock_valid_stage_a_inst (
    .clk_125m(clk1),
    .rst_n_async(rst),
    .sw_reset_pulse(ok_reset),
    .rst_125m(rst_125m_stage_a),
    .sample_valid(sample_3m125_valid_stage_a)
);

wire [47:0] dpll_tracking_word;
wire        dpll_tracking_valid;
wire signed [17:0] dpll_phase_error;
wire signed [21:0] dpll_freq_error;
wire        dpll_freq_error_valid;
wire signed [19:0] dpll_i_baseband;
wire signed [19:0] dpll_q_baseband;
wire        dpll_iq_valid;
wire signed [55:0] dpll_freq_state;
wire signed [55:0] dpll_freq_correction;
wire [8:0]  dpll_active_cic_rate_r;
wire [5:0]  dpll_active_cic_shift;
wire        dpll_cic_overflow;
wire        dpll_cic_illegal;
wire signed [15:0] dpll_lo_cos;
wire signed [15:0] dpll_lo_sin;

wire signed [31:0] effective_negative_limit_dac0 =
    (negative_limit_dac0 == 32'sd0) ? $signed(DEFAULT_NEG_LIMIT) : negative_limit_dac0;
wire signed [55:0] correction_limit_pos = {{24{positive_limit_dac0[31]}}, positive_limit_dac0};
wire signed [55:0] correction_limit_neg = {{24{effective_negative_limit_dac0[31]}}, effective_negative_limit_dac0};
wire        config_apply_pulse = ok_reset | config_apply_flag;

dpll_single_clock_core_stage_a dpll_single_clock_core_stage_a_inst (
    .clk_125m(clk1),
    .rst_125m(rst_125m_stage_a),
    .sample_valid(sample_3m125_valid_stage_a),
    .loop_enable(pll0_lock),
    .adc_sample(ADCraw0),
    .center_word({Centre_Freq, 16'h0000}),
    .config_apply(config_apply_pulse),
    .cic_rate_r(post_iq_cic_rate_r),
    .cic_output_shift(post_iq_cic_shift),
    .cic_flush(ok_reset),
    .fll_delay_sel(fll_delay_sel),
    .kf(pll0_gainii[23:0]),
    .ki(pll0_gaini[23:0]),
    .kp(pll0_gainp[23:0]),
    .positive_limit(correction_limit_pos),
    .negative_limit(correction_limit_neg),
    .tracking_word(dpll_tracking_word),
    .tracking_valid(dpll_tracking_valid),
    .phase_error(dpll_phase_error),
    .freq_error(dpll_freq_error),
    .freq_error_valid(dpll_freq_error_valid),
    .i_baseband(dpll_i_baseband),
    .q_baseband(dpll_q_baseband),
    .iq_valid(dpll_iq_valid),
    .freq_state(dpll_freq_state),
    .freq_correction(dpll_freq_correction),
    .active_cic_rate_r(dpll_active_cic_rate_r),
    .active_cic_output_shift(dpll_active_cic_shift),
    .cic_overflow_seen(dpll_cic_overflow),
    .cic_illegal_config_seen(dpll_cic_illegal),
    .lo_cos(dpll_lo_cos),
    .lo_sin(dpll_lo_sin)
);

wire [47:0] manual_offset_word = {{16{manual_offset_dac0[31]}}, manual_offset_dac0};
wire [47:0] vco_tracking_word = dpll_tracking_word + manual_offset_word;
wire [47:0] VCO_Input0;
wire [15:0] vco_divisor_safe = (VCO_Div_Factor0 == 16'h0000) ? 16'h0001 : VCO_Div_Factor0;
wire [15:0] vco_mul_safe = (VCO_Mul_Factor0 == 16'h0000) ? 16'h0001 : VCO_Mul_Factor0;

PLL_VCO_MUL_DIV PLL_VCO_MUL_DIV_inst (
    .clk(clk1),
    .sample_valid(sample_3m125_valid_stage_a),
    .data_in(vco_tracking_word),
    .data_out(VCO_Input0),
    .PLL_Mul_factor(vco_mul_safe),
    .PLL_Div_factor(vco_divisor_safe)
);

VCO_48bits VCO_inst0 (
    .clk(clk1),
    .VCO_input(VCO_Input0),
    .VCO_offset(VCO_Voffset0),
    .VCO_amplitude(VCO_Vamplitude0),
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
            4'h1: debug_source_mux = {16'h0000, vco_tracking_word[47:32]};
            4'h2: debug_source_mux = dpll_freq_state[55:24];
            4'h3: debug_source_mux = {{14{dpll_phase_error[17]}}, dpll_phase_error};
            4'h4: debug_source_mux = {{10{dpll_freq_error[21]}}, dpll_freq_error};
            4'h5: debug_source_mux = {{12{dpll_i_baseband[19]}}, dpll_i_baseband};
            4'h6: debug_source_mux = {{12{dpll_q_baseband[19]}}, dpll_q_baseband};
            4'h7: debug_source_mux = {{16{dpll_lo_cos[15]}}, dpll_lo_cos};
            4'h8: debug_source_mux = {{16{dpll_lo_sin[15]}}, dpll_lo_sin};
            default: debug_source_mux = {{14{dpll_phase_error[17]}}, dpll_phase_error};
        endcase
    end
endfunction

wire signed [31:0] debug_word = debug_source_mux(debug_dac_source[3:0]);
wire signed [47:0] debug_scaled = debug_word * debug_dac_gain;
wire signed [31:0] debug_shifted = debug_scaled[46:15] + {{18{debug_dac_offset[13]}}, debug_dac_offset};
assign DACout1 = debug_shifted[31] ?
                 ((debug_shifted < -32'sd32768) ? -16'sd32768 : debug_shifted[15:0]) :
                 ((debug_shifted >  32'sd32767) ?  16'sd32767 : debug_shifted[15:0]);

wire [31:0] phase_abs = abs18_extend(dpll_phase_error);
wire [31:0] freq_abs = abs22_extend(dpll_freq_error);
wire residuals0_are_above_threshold_phase = phase_abs > Phase_Residuals_Threshold0;
wire residuals0_are_above_threshold_freq = freq_abs > Freq_Residuals_Threshold0;
wire dac0_railed_positive = dpll_freq_correction >= correction_limit_pos;
wire dac0_railed_negative = dpll_freq_correction <= correction_limit_neg;
wire pll0_locked_instant = pll0_lock & ~(residuals0_are_above_threshold_phase |
                                          residuals0_are_above_threshold_freq |
                                          dpll_cic_illegal);
reg residuals0_are_above_threshold;
reg LED_G0;
reg LED_R0;
reg [23:0] status_counter;

always @(posedge clk1) begin
    if (rst_125m_stage_a) begin
        residuals0_are_above_threshold <= 1'b0;
        LED_G0 <= 1'b0;
        LED_R0 <= 1'b1;
        status_counter <= 24'h0;
    end else begin
        residuals0_are_above_threshold <= residuals0_are_above_threshold_phase |
                                           residuals0_are_above_threshold_freq;
        status_counter <= status_counter + 24'h1;
        LED_G0 <= pll0_locked_instant;
        LED_R0 <= ~pll0_locked_instant;
    end
end

assign led = {status_counter[23], dpll_cic_illegal, dpll_cic_overflow, pll0_lock,
              pll0_locked_instant, LED_R0, LED_G0};

always @(posedge clk1) begin
    if (rst == 1'b0) begin
        sys_err <= 1'b0;
        sys_ack <= 1'b0;
        sys_rdata <= 32'h0000_0000;
    end else begin
        sys_err <= 1'b0;
        sys_ack <= sys_wen | sys_ren;
        if (sys_ren) begin
            case (cmd_addr)
                16'h0000: sys_rdata <= 32'h0000_0000;
                16'h0010: sys_rdata <= Centre_Freq;
                16'h0011: sys_rdata <= {28'h0, angleSelect_0};
                16'h0020: sys_rdata <= {31'h0, pll0_lock};
                16'h0021: sys_rdata <= pll0_gainp;
                16'h0022: sys_rdata <= pll0_gaini;
                16'h0023: sys_rdata <= pll0_gainii;
                16'h0024: sys_rdata <= pll0_gaind;
                16'h0025: sys_rdata <= {14'h0, pll0_coefdfilter};
                16'h0028: sys_rdata <= positive_limit_dac0;
                16'h0029: sys_rdata <= effective_negative_limit_dac0;
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
                16'h0060: sys_rdata <= {23'h0, post_iq_cic_rate_r};
                16'h0061: sys_rdata <= {26'h0, post_iq_cic_shift};
                16'h0062: sys_rdata <= {30'h0, fll_delay_sel};
                16'h006F: sys_rdata <= 32'h0000_0000;
                16'h0100: sys_rdata <= {24'h0, residuals0_are_above_threshold,
                                          residuals0_are_above_threshold_freq,
                                          residuals0_are_above_threshold_phase,
                                          dac0_railed_negative,
                                          dac0_railed_positive,
                                          pll0_locked_instant, LED_R0, LED_G0};
                16'h0101: sys_rdata <= {12'h0, dpll_i_baseband[19] ? (~dpll_i_baseband + 20'd1) : dpll_i_baseband} +
                                        {12'h0, dpll_q_baseband[19] ? (~dpll_q_baseband + 20'd1) : dpll_q_baseband};
                16'h0102: sys_rdata <= {{14{dpll_phase_error[17]}}, dpll_phase_error};
                16'h0103: sys_rdata <= {{10{dpll_freq_error[21]}}, dpll_freq_error};
                16'h0104: sys_rdata <= dpll_freq_correction[31:0];
                16'h0105: sys_rdata <= dpll_tracking_word[31:0];
                16'h0106: sys_rdata <= {{14{dpll_phase_error[17]}}, dpll_phase_error};
                16'h0107: sys_rdata <= dpll_freq_state[31:0];
                16'h0108: sys_rdata <= {27'h0, dpll_tracking_valid, dpll_freq_error_valid,
                                          dpll_iq_valid, dpll_cic_illegal, dpll_cic_overflow};
                16'h0109: sys_rdata <= {17'h0, dpll_active_cic_shift, dpll_active_cic_rate_r};
                16'h010A: sys_rdata <= {16'h0, dpll_tracking_word[47:32]};
                16'h010B: sys_rdata <= VCO_Input0[31:0];
                16'h010C: sys_rdata <= {16'h0, VCO_Input0[47:32]};
                16'h010D: sys_rdata <= CONFIG_VERSION;
                16'h010E: sys_rdata <= ABI_VERSION;
                16'h010F: sys_rdata <= FPGA_BUILD_ID;
                default:  sys_rdata <= 32'h0000_0000;
            endcase
        end
    end
end

endmodule

`default_nettype wire
