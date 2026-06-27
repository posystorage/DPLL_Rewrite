`timescale 1ns / 1ps
`default_nettype none

module loop_state_manager_stage_a #(
    parameter integer PHASE_WIDTH = 18,
    parameter integer FERR_WIDTH = 22,
    parameter integer MAG_WIDTH = 16,
    parameter integer COEFF_WIDTH = 24,
    parameter integer DWELL_WIDTH = 16,
    parameter integer TIMEOUT_WIDTH = 24
) (
    input  wire                                  clk_125m,
    input  wire                                  rst_125m,
    input  wire                                  loop_enable,
    input  wire                                  config_apply,
    input  wire                                  measurement_valid,
    input  wire [PHASE_WIDTH-1:0]                phase_abs,
    input  wire [FERR_WIDTH-1:0]                 freq_abs,
    input  wire [MAG_WIDTH-1:0]                  magnitude,
    input  wire                                  cic_fault,
    input  wire                                  correction_saturated,
    input  wire [PHASE_WIDTH-1:0]                phase_lock_threshold,
    input  wire [FERR_WIDTH-1:0]                 freq_lock_threshold,
    input  wire [MAG_WIDTH-1:0]                  mag_enter_threshold,
    input  wire [MAG_WIDTH-1:0]                  mag_exit_threshold,
    input  wire [DWELL_WIDTH-1:0]                acquire_dwell,
    input  wire [DWELL_WIDTH-1:0]                blend_dwell,
    input  wire [DWELL_WIDTH-1:0]                loss_dwell,
    input  wire [TIMEOUT_WIDTH-1:0]              holdover_timeout,
    input  wire [DWELL_WIDTH-1:0]                warmup_samples,
    input  wire signed [COEFF_WIDTH-1:0]         kf_acquire,
    input  wire signed [COEFF_WIDTH-1:0]         kf_blend,
    input  wire signed [COEFF_WIDTH-1:0]         kf_track,
    input  wire signed [COEFF_WIDTH-1:0]         kp_blend,
    input  wire signed [COEFF_WIDTH-1:0]         ki_blend,
    input  wire signed [COEFF_WIDTH-1:0]         kp_track,
    input  wire signed [COEFF_WIDTH-1:0]         ki_track,
    output reg                                   enable_fll,
    output reg                                   enable_pll_i,
    output reg                                   enable_pll_p,
    output reg signed [COEFF_WIDTH-1:0]          active_kf,
    output reg signed [COEFF_WIDTH-1:0]          active_ki,
    output reg signed [COEFF_WIDTH-1:0]          active_kp,
    output reg [3:0]                             loop_state,
    output reg [3:0]                             loss_reason,
    output reg                                   signal_present,
    output reg                                   phase_locked,
    output reg                                   frequency_locked,
    output reg                                   locked
);

    localparam [3:0] ST_RESET         = 4'd0;
    localparam [3:0] ST_DISABLED      = 4'd1;
    localparam [3:0] ST_CONFIGURE     = 4'd2;
    localparam [3:0] ST_WARMUP        = 4'd3;
    localparam [3:0] ST_FLL_ACQUIRE   = 4'd4;
    localparam [3:0] ST_FLL_PLL_BLEND = 4'd5;
    localparam [3:0] ST_PLL_TRACK     = 4'd6;
    localparam [3:0] ST_HOLDOVER      = 4'd7;
    localparam [3:0] ST_REACQUIRE     = 4'd8;
    localparam [3:0] ST_FAULT         = 4'd9;

    localparam [3:0] LOSS_NONE        = 4'd0;
    localparam [3:0] LOSS_SIGNAL      = 4'd1;
    localparam [3:0] LOSS_PHASE       = 4'd2;
    localparam [3:0] LOSS_FREQUENCY   = 4'd3;
    localparam [3:0] LOSS_CIC         = 4'd4;
    localparam [3:0] LOSS_SATURATION  = 4'd5;
    localparam [3:0] LOSS_TIMEOUT     = 4'd6;

    reg [DWELL_WIDTH-1:0] good_count;
    reg [DWELL_WIDTH-1:0] bad_count;
    reg [DWELL_WIDTH-1:0] warmup_count;
    reg [TIMEOUT_WIDTH-1:0] holdover_count;

    wire phase_ok = phase_abs <= phase_lock_threshold;
    wire freq_ok = freq_abs <= freq_lock_threshold;
    wire mag_enter_ok = (mag_enter_threshold == {MAG_WIDTH{1'b0}}) ||
                        (magnitude >= mag_enter_threshold);
    wire mag_exit_bad = (mag_exit_threshold != {MAG_WIDTH{1'b0}}) &&
                        (magnitude <= mag_exit_threshold);
    wire loop_ok = signal_present && phase_ok && freq_ok && !correction_saturated;
    wire signal_bad = !signal_present;
    wire loss_sample = signal_bad || !phase_ok || !freq_ok || correction_saturated;

    function [DWELL_WIDTH-1:0] nonzero_dwell;
        input [DWELL_WIDTH-1:0] value;
        begin
            nonzero_dwell = (value == {DWELL_WIDTH{1'b0}}) ? {{(DWELL_WIDTH-1){1'b0}}, 1'b1} : value;
        end
    endfunction

    function [TIMEOUT_WIDTH-1:0] nonzero_timeout;
        input [TIMEOUT_WIDTH-1:0] value;
        begin
            nonzero_timeout = (value == {TIMEOUT_WIDTH{1'b0}}) ? {{(TIMEOUT_WIDTH-1){1'b0}}, 1'b1} : value;
        end
    endfunction

    always @* begin
        enable_fll = 1'b0;
        enable_pll_i = 1'b0;
        enable_pll_p = 1'b0;
        active_kf = {COEFF_WIDTH{1'b0}};
        active_ki = {COEFF_WIDTH{1'b0}};
        active_kp = {COEFF_WIDTH{1'b0}};

        case (loop_state)
            ST_FLL_ACQUIRE, ST_REACQUIRE: begin
                enable_fll = 1'b1;
                active_kf = kf_acquire;
            end
            ST_FLL_PLL_BLEND: begin
                enable_fll = 1'b1;
                enable_pll_i = 1'b1;
                enable_pll_p = 1'b1;
                active_kf = kf_blend;
                active_ki = ki_blend;
                active_kp = kp_blend;
            end
            ST_PLL_TRACK: begin
                enable_fll = 1'b1;
                enable_pll_i = 1'b1;
                enable_pll_p = 1'b1;
                active_kf = kf_track;
                active_ki = ki_track;
                active_kp = kp_track;
            end
            default: begin
                enable_fll = 1'b0;
                enable_pll_i = 1'b0;
                enable_pll_p = 1'b0;
            end
        endcase
    end

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            loop_state <= ST_RESET;
            loss_reason <= LOSS_NONE;
            signal_present <= 1'b0;
            phase_locked <= 1'b0;
            frequency_locked <= 1'b0;
            locked <= 1'b0;
            good_count <= {DWELL_WIDTH{1'b0}};
            bad_count <= {DWELL_WIDTH{1'b0}};
            warmup_count <= {DWELL_WIDTH{1'b0}};
            holdover_count <= {TIMEOUT_WIDTH{1'b0}};
        end else begin
            locked <= (loop_state == ST_PLL_TRACK) && loop_ok;

            if (!loop_enable) begin
                loop_state <= ST_DISABLED;
                loss_reason <= LOSS_NONE;
                good_count <= {DWELL_WIDTH{1'b0}};
                bad_count <= {DWELL_WIDTH{1'b0}};
                warmup_count <= {DWELL_WIDTH{1'b0}};
                holdover_count <= {TIMEOUT_WIDTH{1'b0}};
            end else if (cic_fault) begin
                loop_state <= ST_FAULT;
                loss_reason <= LOSS_CIC;
                good_count <= {DWELL_WIDTH{1'b0}};
                bad_count <= {DWELL_WIDTH{1'b0}};
            end else if (config_apply) begin
                loop_state <= ST_CONFIGURE;
                loss_reason <= LOSS_NONE;
                good_count <= {DWELL_WIDTH{1'b0}};
                bad_count <= {DWELL_WIDTH{1'b0}};
                warmup_count <= {DWELL_WIDTH{1'b0}};
                holdover_count <= {TIMEOUT_WIDTH{1'b0}};
            end else begin
                case (loop_state)
                    ST_RESET, ST_DISABLED: begin
                        loop_state <= ST_CONFIGURE;
                        loss_reason <= LOSS_NONE;
                    end

                    ST_CONFIGURE: begin
                        loop_state <= ST_WARMUP;
                        warmup_count <= {DWELL_WIDTH{1'b0}};
                    end

                    ST_WARMUP: begin
                        if (measurement_valid) begin
                            if (warmup_count >= nonzero_dwell(warmup_samples) - 1'b1) begin
                                loop_state <= ST_FLL_ACQUIRE;
                                warmup_count <= {DWELL_WIDTH{1'b0}};
                            end else begin
                                warmup_count <= warmup_count + 1'b1;
                            end
                        end
                    end

                    ST_FLL_ACQUIRE, ST_REACQUIRE: begin
                        if (measurement_valid) begin
                            if (signal_present && freq_ok && !correction_saturated) begin
                                bad_count <= {DWELL_WIDTH{1'b0}};
                                if (good_count >= nonzero_dwell(acquire_dwell) - 1'b1) begin
                                    loop_state <= ST_FLL_PLL_BLEND;
                                    good_count <= {DWELL_WIDTH{1'b0}};
                                end else begin
                                    good_count <= good_count + 1'b1;
                                end
                            end else begin
                                good_count <= {DWELL_WIDTH{1'b0}};
                                bad_count <= bad_count + 1'b1;
                                if (correction_saturated) begin
                                    loss_reason <= LOSS_SATURATION;
                                end else if (!signal_present) begin
                                    loss_reason <= LOSS_SIGNAL;
                                end else begin
                                    loss_reason <= LOSS_FREQUENCY;
                                end
                            end
                        end
                    end

                    ST_FLL_PLL_BLEND: begin
                        if (measurement_valid) begin
                            if (loop_ok) begin
                                bad_count <= {DWELL_WIDTH{1'b0}};
                                if (good_count >= nonzero_dwell(blend_dwell) - 1'b1) begin
                                    loop_state <= ST_PLL_TRACK;
                                    loss_reason <= LOSS_NONE;
                                    good_count <= {DWELL_WIDTH{1'b0}};
                                end else begin
                                    good_count <= good_count + 1'b1;
                                end
                            end else begin
                                good_count <= {DWELL_WIDTH{1'b0}};
                                if (bad_count >= nonzero_dwell(loss_dwell) - 1'b1) begin
                                    loop_state <= signal_present ? ST_REACQUIRE : ST_HOLDOVER;
                                    loss_reason <= signal_present ? (!freq_ok ? LOSS_FREQUENCY : LOSS_PHASE) : LOSS_SIGNAL;
                                    bad_count <= {DWELL_WIDTH{1'b0}};
                                end else begin
                                    bad_count <= bad_count + 1'b1;
                                end
                            end
                        end
                    end

                    ST_PLL_TRACK: begin
                        if (measurement_valid) begin
                            if (loss_sample) begin
                                good_count <= {DWELL_WIDTH{1'b0}};
                                if (bad_count >= nonzero_dwell(loss_dwell) - 1'b1) begin
                                    if (correction_saturated) begin
                                        loop_state <= ST_REACQUIRE;
                                        loss_reason <= LOSS_SATURATION;
                                    end else if (!signal_present) begin
                                        loop_state <= ST_HOLDOVER;
                                        loss_reason <= LOSS_SIGNAL;
                                    end else if (!freq_ok) begin
                                        loop_state <= ST_REACQUIRE;
                                        loss_reason <= LOSS_FREQUENCY;
                                    end else begin
                                        loop_state <= ST_REACQUIRE;
                                        loss_reason <= LOSS_PHASE;
                                    end
                                    bad_count <= {DWELL_WIDTH{1'b0}};
                                end else begin
                                    bad_count <= bad_count + 1'b1;
                                end
                            end else begin
                                bad_count <= {DWELL_WIDTH{1'b0}};
                                loss_reason <= LOSS_NONE;
                            end
                        end
                    end

                    ST_HOLDOVER: begin
                        if (measurement_valid && signal_present) begin
                            loop_state <= ST_REACQUIRE;
                            holdover_count <= {TIMEOUT_WIDTH{1'b0}};
                        end else if (holdover_count >= nonzero_timeout(holdover_timeout) - 1'b1) begin
                            loop_state <= ST_FAULT;
                            loss_reason <= LOSS_TIMEOUT;
                        end else begin
                            holdover_count <= holdover_count + 1'b1;
                        end
                    end

                    ST_FAULT: begin
                        if (config_apply) begin
                            loop_state <= ST_CONFIGURE;
                            loss_reason <= LOSS_NONE;
                        end
                    end

                    default: begin
                        loop_state <= ST_FAULT;
                        loss_reason <= LOSS_TIMEOUT;
                    end
                endcase
            end

            if (measurement_valid) begin
                phase_locked <= phase_ok;
                frequency_locked <= freq_ok;
                if (mag_exit_bad) begin
                    signal_present <= 1'b0;
                end else if (mag_enter_ok) begin
                    signal_present <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
