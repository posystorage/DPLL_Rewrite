`timescale 1ns / 1ps
`default_nettype none

module loop_state_manager_stage_a #(
    parameter integer PHASE_WIDTH = 18,
    parameter integer FERR_WIDTH = 22,
    parameter integer MAG_WIDTH = 16,
    parameter integer COEFF_WIDTH = 24,
    parameter integer DWELL_WIDTH = 16,
    parameter integer TIMEOUT_WIDTH = 24,
    parameter integer PREHEAT_BLOCKS = 4
) (
    input  wire                                  clk_125m,
    input  wire                                  rst_125m,
    input  wire                                  loop_enable,
    input  wire                                  controller_reacquire,
    input  wire                                  magnitude_valid,
    input  wire                                  phase_valid,
    input  wire                                  frequency_valid,
    input  wire                                  signal_present_in,
    input  wire                                  measurement_valid,
    input  wire [TIMEOUT_WIDTH-1:0]              measurement_timeout,
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
    output reg                                   track_iir_preheat,
    output reg [3:0]                             loop_state,
    output reg [3:0]                             loss_reason,
    output wire                                  signal_present,
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
    reg [TIMEOUT_WIDTH-1:0] measurement_gap_count;

    localparam [DWELL_WIDTH-1:0] PREHEAT_TARGET =
        (PREHEAT_BLOCKS < 1) ? {DWELL_WIDTH{1'b0}} : PREHEAT_BLOCKS - 1;

    reg [PHASE_WIDTH-1:0] phase_lock_threshold_r;
    reg [FERR_WIDTH-1:0] freq_lock_threshold_r;
    reg [MAG_WIDTH-1:0] mag_enter_threshold_r;
    reg [MAG_WIDTH-1:0] mag_exit_threshold_r;
    reg [DWELL_WIDTH-1:0] acquire_dwell_r;
    reg [DWELL_WIDTH-1:0] blend_dwell_r;
    reg [DWELL_WIDTH-1:0] loss_dwell_r;
    reg [TIMEOUT_WIDTH-1:0] holdover_timeout_r;
    reg [TIMEOUT_WIDTH-1:0] measurement_timeout_r;
    reg [DWELL_WIDTH-1:0] warmup_samples_r;
    reg [DWELL_WIDTH-1:0] warmup_target_r;
    reg [DWELL_WIDTH-1:0] acquire_target_r;
    reg [DWELL_WIDTH-1:0] blend_target_r;
    reg [DWELL_WIDTH-1:0] loss_target_r;
    reg [TIMEOUT_WIDTH-1:0] holdover_target_r;
    reg [TIMEOUT_WIDTH-1:0] measurement_timeout_target_r;

    wire phase_ok = phase_abs <= phase_lock_threshold_r;
    wire freq_ok = freq_abs <= freq_lock_threshold_r;
    assign signal_present = signal_present_in;
    // Magnitude is reported for diagnostics only.  Lock quality is decided by
    // phase/frequency residuals and output saturation so weak signals can be
    // captured instead of being rejected by a fixed amplitude gate.
    wire loop_ok = phase_ok && freq_ok && !correction_saturated;
    wire loss_sample = !phase_ok || !freq_ok || correction_saturated;

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
            phase_locked <= 1'b0;
            frequency_locked <= 1'b0;
            locked <= 1'b0;
            good_count <= {DWELL_WIDTH{1'b0}};
            bad_count <= {DWELL_WIDTH{1'b0}};
            warmup_count <= {DWELL_WIDTH{1'b0}};
            holdover_count <= {TIMEOUT_WIDTH{1'b0}};
            measurement_gap_count <= {TIMEOUT_WIDTH{1'b0}};
            track_iir_preheat <= 1'b0;
            phase_lock_threshold_r <= {PHASE_WIDTH{1'b0}};
            freq_lock_threshold_r <= {FERR_WIDTH{1'b0}};
            mag_enter_threshold_r <= {MAG_WIDTH{1'b0}};
            mag_exit_threshold_r <= {MAG_WIDTH{1'b0}};
            acquire_dwell_r <= {DWELL_WIDTH{1'b0}};
            blend_dwell_r <= {DWELL_WIDTH{1'b0}};
            loss_dwell_r <= {DWELL_WIDTH{1'b0}};
            holdover_timeout_r <= {TIMEOUT_WIDTH{1'b0}};
            measurement_timeout_r <= {TIMEOUT_WIDTH{1'b0}};
            warmup_samples_r <= {DWELL_WIDTH{1'b0}};
            warmup_target_r <= {DWELL_WIDTH{1'b0}};
            acquire_target_r <= {DWELL_WIDTH{1'b0}};
            blend_target_r <= {DWELL_WIDTH{1'b0}};
            loss_target_r <= {DWELL_WIDTH{1'b0}};
            holdover_target_r <= {TIMEOUT_WIDTH{1'b0}};
            measurement_timeout_target_r <= {TIMEOUT_WIDTH{1'b0}};
        end else begin
            phase_lock_threshold_r <= phase_lock_threshold;
            freq_lock_threshold_r <= freq_lock_threshold;
            mag_enter_threshold_r <= mag_enter_threshold;
            mag_exit_threshold_r <= mag_exit_threshold;
            acquire_dwell_r <= acquire_dwell;
            blend_dwell_r <= blend_dwell;
            loss_dwell_r <= loss_dwell;
            holdover_timeout_r <= holdover_timeout;
            measurement_timeout_r <= measurement_timeout;
            warmup_samples_r <= warmup_samples;
            warmup_target_r <= warmup_samples_r - 1'b1;
            acquire_target_r <= acquire_dwell_r - 1'b1;
            blend_target_r <= blend_dwell_r - 1'b1;
            loss_target_r <= loss_dwell_r - 1'b1;
            holdover_target_r <= holdover_timeout_r - 1'b1;
            measurement_timeout_target_r <= measurement_timeout_r - 1'b1;

            if (measurement_valid) begin
                measurement_gap_count <= {TIMEOUT_WIDTH{1'b0}};
            end else if (measurement_gap_count != {TIMEOUT_WIDTH{1'b1}}) begin
                measurement_gap_count <= measurement_gap_count + 1'b1;
            end

            locked <= (loop_state == ST_PLL_TRACK) && loop_ok;

            if (!loop_enable) begin
                loop_state <= ST_DISABLED;
                loss_reason <= LOSS_NONE;
                good_count <= {DWELL_WIDTH{1'b0}};
                bad_count <= {DWELL_WIDTH{1'b0}};
                warmup_count <= {DWELL_WIDTH{1'b0}};
                holdover_count <= {TIMEOUT_WIDTH{1'b0}};
                measurement_gap_count <= {TIMEOUT_WIDTH{1'b0}};
                track_iir_preheat <= 1'b0;
            end else if (controller_reacquire) begin
                loop_state <= ST_CONFIGURE;
                loss_reason <= LOSS_NONE;
                good_count <= {DWELL_WIDTH{1'b0}};
                bad_count <= {DWELL_WIDTH{1'b0}};
                warmup_count <= {DWELL_WIDTH{1'b0}};
                holdover_count <= {TIMEOUT_WIDTH{1'b0}};
                measurement_gap_count <= {TIMEOUT_WIDTH{1'b0}};
                track_iir_preheat <= 1'b0;
            end else if (cic_fault) begin
                loop_state <= ST_FAULT;
                loss_reason <= LOSS_CIC;
                good_count <= {DWELL_WIDTH{1'b0}};
                bad_count <= {DWELL_WIDTH{1'b0}};
                track_iir_preheat <= 1'b0;
            end else if ((loop_state == ST_FLL_ACQUIRE ||
                          loop_state == ST_FLL_PLL_BLEND ||
                          loop_state == ST_PLL_TRACK ||
                          loop_state == ST_REACQUIRE) &&
                         (measurement_gap_count >= measurement_timeout_target_r)) begin
                loop_state <= ST_HOLDOVER;
                loss_reason <= LOSS_TIMEOUT;
                good_count <= {DWELL_WIDTH{1'b0}};
                bad_count <= {DWELL_WIDTH{1'b0}};
                holdover_count <= {TIMEOUT_WIDTH{1'b0}};
                track_iir_preheat <= 1'b0;
            end else begin
                case (loop_state)
                    ST_RESET, ST_DISABLED: begin
                        loop_state <= ST_CONFIGURE;
                        loss_reason <= LOSS_NONE;
                        track_iir_preheat <= 1'b0;
                    end

                    ST_CONFIGURE: begin
                        loop_state <= ST_WARMUP;
                        warmup_count <= {DWELL_WIDTH{1'b0}};
                        track_iir_preheat <= 1'b0;
                    end

                    ST_WARMUP: begin
                        if (measurement_valid) begin
                            if (warmup_count >= warmup_target_r) begin
                                loop_state <= ST_FLL_ACQUIRE;
                                warmup_count <= {DWELL_WIDTH{1'b0}};
                                track_iir_preheat <= 1'b0;
                            end else begin
                                warmup_count <= warmup_count + 1'b1;
                            end
                        end
                    end

                    ST_FLL_ACQUIRE, ST_REACQUIRE: begin
                        if (measurement_valid) begin
                            if (freq_ok && !correction_saturated) begin
                                bad_count <= {DWELL_WIDTH{1'b0}};
                                loss_reason <= LOSS_NONE;
                                if (track_iir_preheat) begin
                                    if (good_count >= PREHEAT_TARGET) begin
                                        loop_state <= ST_FLL_PLL_BLEND;
                                        track_iir_preheat <= 1'b0;
                                        good_count <= {DWELL_WIDTH{1'b0}};
                                    end else begin
                                        good_count <= good_count + 1'b1;
                                    end
                                end else if (good_count >= acquire_target_r) begin
                                    // Switch to the TRACK IIR while control remains
                                    // FLL-only. Fresh detector blocks must arrive
                                    // before PI is allowed to enter state 5.
                                    track_iir_preheat <= 1'b1;
                                    good_count <= {DWELL_WIDTH{1'b0}};
                                end else begin
                                    good_count <= good_count + 1'b1;
                                end
                            end else begin
                                good_count <= {DWELL_WIDTH{1'b0}};
                                bad_count <= bad_count + 1'b1;
                                if (correction_saturated) begin
                                    loss_reason <= LOSS_SATURATION;
                                end else begin
                                    loss_reason <= LOSS_FREQUENCY;
                                end
                            end
                        end
                    end

                    ST_FLL_PLL_BLEND: begin
                        track_iir_preheat <= 1'b0;
                        if (measurement_valid) begin
                            if (freq_ok && !correction_saturated) begin
                                bad_count <= {DWELL_WIDTH{1'b0}};
                                loss_reason <= LOSS_NONE;
                                if (phase_ok) begin
                                    if (good_count >= blend_target_r) begin
                                        loop_state <= ST_PLL_TRACK;
                                        good_count <= {DWELL_WIDTH{1'b0}};
                                    end else begin
                                        good_count <= good_count + 1'b1;
                                    end
                                end else begin
                                    // BLEND is the phase-acquisition state. A phase
                                    // error outside the lock window is not a loss;
                                    // keep PI active until phase converges while
                                    // frequency and signal quality remain valid.
                                    good_count <= {DWELL_WIDTH{1'b0}};
                                end
                            end else begin
                                good_count <= {DWELL_WIDTH{1'b0}};
                                if (bad_count >= loss_target_r) begin
                                    loop_state <= ST_REACQUIRE;
                                    loss_reason <= correction_saturated ? LOSS_SATURATION :
                                                   (freq_ok ? LOSS_PHASE : LOSS_FREQUENCY);
                                    bad_count <= {DWELL_WIDTH{1'b0}};
                                end else begin
                                    bad_count <= bad_count + 1'b1;
                                end
                            end
                        end
                    end

                    ST_PLL_TRACK: begin
                        track_iir_preheat <= 1'b0;
                        if (measurement_valid) begin
                            if (loss_sample) begin
                                good_count <= {DWELL_WIDTH{1'b0}};
                                if (bad_count >= loss_target_r) begin
                                    if (correction_saturated) begin
                                        loop_state <= ST_REACQUIRE;
                                        loss_reason <= LOSS_SATURATION;
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
                        track_iir_preheat <= 1'b0;
                        if (measurement_valid) begin
                            loop_state <= ST_REACQUIRE;
                            holdover_count <= {TIMEOUT_WIDTH{1'b0}};
                        end else if (holdover_count >= holdover_target_r) begin
                            // A lost measurement is recoverable.  Reserve
                            // ST_FAULT for CIC/datapath faults and malformed
                            // state transitions that require APPLY/reset.
                            loop_state <= ST_REACQUIRE;
                            loss_reason <= LOSS_TIMEOUT;
                            holdover_count <= {TIMEOUT_WIDTH{1'b0}};
                            measurement_gap_count <= {TIMEOUT_WIDTH{1'b0}};
                        end else begin
                            holdover_count <= holdover_count + 1'b1;
                        end
                    end

                    ST_FAULT: begin
                        track_iir_preheat <= 1'b0;
                        if (controller_reacquire) begin
                            loop_state <= ST_CONFIGURE;
                            loss_reason <= LOSS_NONE;
                        end
                    end

                    default: begin
                        loop_state <= ST_FAULT;
                        loss_reason <= LOSS_TIMEOUT;
                        track_iir_preheat <= 1'b0;
                    end
                endcase
            end

            if (phase_valid) begin
                phase_locked <= phase_ok;
            end
            if (frequency_valid) begin
                frequency_locked <= freq_ok;
            end
        end
    end

    wire unused_magnitude_valid = magnitude_valid;
    wire unused_magnitude = |magnitude;
    wire unused_mag_thresholds = |mag_enter_threshold_r | |mag_exit_threshold_r;

endmodule

`default_nettype wire
