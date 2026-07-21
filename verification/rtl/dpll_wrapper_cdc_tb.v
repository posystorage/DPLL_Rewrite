`timescale 1ns/1ps

module pre_iq_cic_40_125m_v1(
    input aclk, input [15:0] s_axis_data_tdata, input s_axis_data_tvalid,
    output s_axis_data_tready, output [15:0] m_axis_data_tdata,
    output m_axis_data_tvalid);
    assign s_axis_data_tready = 1'b1;
    assign m_axis_data_tdata = s_axis_data_tdata;
    assign m_axis_data_tvalid = s_axis_data_tvalid;
endmodule

module dpll_single_clock_core_stage_a(
    input clk_125m, input rst_125m, input sample_valid, input loop_enable,
    input status_clear, input signed [15:0] adc_sample, input [47:0] center_word,
    input controller_reacquire, input detector_reconfigure,
    input [8:0] cic_rate_r, input [5:0] cic_output_shift, input cic_flush,
    input [1:0] fll_delay_sel, input [1:0] post_iir_mode,
    input signed [31:0] post_iir_acq_b0, post_iir_acq_b1, post_iir_acq_b2,
    input signed [31:0] post_iir_acq_a1, post_iir_acq_a2,
    input signed [31:0] post_iir_track_b0, post_iir_track_b1, post_iir_track_b2,
    input signed [31:0] post_iir_track_a1, post_iir_track_a2,
    input signed [23:0] kf, ki, kp, kf_blend, kf_track, kp_blend, ki_blend,
    input signed [17:0] phase_setpoint, input [17:0] phase_lock_threshold,
    input [21:0] freq_lock_threshold, input [19:0] mag_enter_threshold,
    input [19:0] mag_exit_threshold, input [15:0] acquire_dwell,
    input [15:0] blend_dwell, input [15:0] loss_dwell,
    input [23:0] measurement_timeout, input [23:0] holdover_timeout,
    input [15:0] warmup_samples, input signed [55:0] positive_limit,
    input signed [55:0] negative_limit,
    output reg [47:0] tracking_word, output tracking_valid,
    output signed [17:0] cordic_phase_out, output signed [17:0] phase_error,
    output signed [21:0] freq_error, output freq_error_valid,
    output signed [19:0] i_baseband, output signed [19:0] q_baseband,
    output iq_valid, output signed [55:0] freq_state,
    output signed [55:0] freq_correction, output [19:0] magnitude,
    output [3:0] loop_state, output [3:0] loss_reason, output signal_present,
    output phase_locked, output frequency_locked, output locked,
    output [8:0] active_cic_rate_r, output [5:0] active_cic_output_shift,
    output post_iir_active_bypass, output post_iir_active_use_track,
    output cic_overflow_seen, output cordic_input_overrun_seen,
    output cordic_input_out_of_range_seen, output cordic_output_format_error_seen,
    output signed [15:0] lo_cos, output signed [15:0] lo_sin);
    reg [31:0] reacquire_count = 0;
    reg [31:0] detector_count = 0;
    always @(posedge clk_125m) begin
        if (controller_reacquire) begin
            tracking_word <= center_word;
            reacquire_count <= reacquire_count + 1;
        end
        if (detector_reconfigure) detector_count <= detector_count + 1;
    end
    initial tracking_word = 0;
    assign tracking_valid = controller_reacquire;
    assign cordic_phase_out = 0; assign phase_error = 0; assign freq_error = 0;
    assign freq_error_valid = 0; assign i_baseband = 0; assign q_baseband = 0;
    assign iq_valid = 0; assign freq_state = 0; assign freq_correction = 0;
    assign magnitude = 0; assign loop_state = 0; assign loss_reason = 0;
    assign signal_present = 0; assign phase_locked = 0; assign frequency_locked = 0;
    assign locked = 0; assign active_cic_rate_r = cic_rate_r;
    assign active_cic_output_shift = cic_output_shift;
    assign post_iir_active_bypass = (post_iir_mode == 0);
    assign post_iir_active_use_track = (post_iir_mode == 2);
    assign cic_overflow_seen = 0; assign cordic_input_overrun_seen = 0;
    assign cordic_input_out_of_range_seen = 0; assign cordic_output_format_error_seen = 0;
    assign lo_cos = 0; assign lo_sin = 0;
endmodule

module PLL_VCO_MUL_DIV(input clk,input rst,input sample_valid,input [47:0] data_in,
    output reg [47:0] data_out,input [15:0] PLL_Mul_factor,input [15:0] PLL_Div_factor);
    initial data_out=0; always @(posedge clk) if(sample_valid) data_out<=data_in;
endmodule
module VCO_48bits(input clk,input [47:0] VCO_input,input [13:0] VCO_offset,
    input [15:0] VCO_amplitude,output [15:0] VCO_DAC_out); assign VCO_DAC_out=0; endmodule
module debug_dac_formatter_stage_a(input clk_125m,input rst_125m,input source_valid,
    input signed [31:0] source_word,input [31:0] format_word,input signed [15:0] gain,
    input signed [15:0] offset,output signed [15:0] dac_sample); assign dac_sample=0; endmodule

module dpll_wrapper_cdc_tb;
    reg clk1=0,sys_clk=0,rst=0,sys_rstn=0;
    always #4 clk1=~clk1; always #5.5 sys_clk=~sys_clk;
    reg signed [15:0] ADCraw0=0; wire signed [15:0] DACout0,DACout1;
    reg [31:0] sys_addr=0,sys_wdata=0; reg [3:0] sys_sel=4'hf;
    reg sys_wen=0,sys_ren=0; wire [31:0] sys_rdata; wire sys_err,sys_ack;
    wire [6:0] led;
    dpll_wrapper dut(.clk1(clk1),.rst(rst),.sys_clk(sys_clk),.sys_rstn(sys_rstn),
        .ADCraw0(ADCraw0),.DACout0(DACout0),.DACout1(DACout1),.sys_addr(sys_addr),
        .sys_wdata(sys_wdata),.sys_sel(sys_sel),.sys_wen(sys_wen),.sys_ren(sys_ren),
        .sys_rdata(sys_rdata),.sys_err(sys_err),.sys_ack(sys_ack),.led(led));

    task wr; input [15:0] a; input [31:0] d; integer n; begin
        @(negedge sys_clk); sys_addr={14'd0,a,2'b00}; sys_wdata=d; sys_wen=1; n=0;
        while(!sys_ack && n<20) begin @(posedge sys_clk); #1; n=n+1; end
        if(!sys_ack || sys_err) begin $display("FAIL: write addr=%h ack=%b err=%b",a,sys_ack,sys_err);$finish;end
        @(negedge sys_clk); sys_wen=0;
    end endtask
    task rd; input [15:0] a; output [31:0] d; integer n; begin
        @(negedge sys_clk); sys_addr={14'd0,a,2'b00}; sys_ren=1; n=0;
        while(!sys_ack && n<20) begin @(posedge sys_clk); #1; n=n+1; end
        if(!sys_ack) begin $display("FAIL: read timeout addr=%h",a);$finish;end
        d=sys_rdata; @(negedge sys_clk); sys_ren=0;
    end endtask

    reg [31:0] v; reg [31:0] before_reacquire; reg [31:0] before_detector;
    initial begin
        repeat(4)@(posedge clk1); rst=1; sys_rstn=1; repeat(4)@(posedge sys_clk);
        rd(16'h010e,v); if(v!==`DPLL_GENERATED_ABI_VERSION) $finish;
        rd(16'h010f,v); if(v!==`DPLL_GENERATED_BUILD_ID) $finish;

        wr(16'h0010,32'h12345678); rd(16'h0010,v);
        if(v!==32'h12345678 || dut.active_center_word!==48'h123456780000) begin
            $display("FAIL: direct center write/read %h %h",v,dut.active_center_word);$finish;end

        before_reacquire=dut.dpll_single_clock_core_stage_a_inst.reacquire_count;
        wr(16'h0050,32'h1234); repeat(3)@(posedge clk1);
        if(dut.dpll_single_clock_core_stage_a_inst.reacquire_count!==before_reacquire) begin
            $display("FAIL: threshold write restarted controller");$finish;end

        wr(16'h0021,32'hff800001); repeat(3)@(posedge clk1);
        if(dut.active_kp!==24'h800001 ||
           dut.dpll_single_clock_core_stage_a_inst.reacquire_count!==before_reacquire+1) begin
            $display("FAIL: gain write did not locally reacquire");$finish;end
        rd(16'h0021,v);
        if(v!==32'hff800001) begin
            $display("FAIL: signed 24-bit gain readback %h",v);$finish;end

        wr(16'h0030,32'hffffffff); rd(16'h0030,v);
        if(v!==32'hffffffff) begin
            $display("FAIL: signed 14-bit DAC offset readback %h",v);$finish;end

        wr(16'h0043,32'h00000f3f); rd(16'h0043,v);
        if(v!==32'h00000f3f) begin
            $display("FAIL: 12-bit debug format readback %h",v);$finish;end

        before_reacquire=dut.dpll_single_clock_core_stage_a_inst.reacquire_count;
        before_detector=dut.dpll_single_clock_core_stage_a_inst.detector_count;
        wr(16'h0060,78); repeat(3)@(posedge clk1);
        if(dut.active_post_iq_cic_rate_r!==78 ||
           dut.dpll_single_clock_core_stage_a_inst.detector_count!==before_detector+1 ||
           dut.dpll_single_clock_core_stage_a_inst.reacquire_count!==before_reacquire+1) begin
            $display("FAIL: structural write did not reconfigure detector/controller");$finish;end

        before_reacquire=dut.dpll_single_clock_core_stage_a_inst.reacquire_count;
        wr(16'h0042,32'h7); repeat(3)@(posedge clk1);
        if(dut.live_debug_dac_source!==7 ||
           dut.dpll_single_clock_core_stage_a_inst.reacquire_count!==before_reacquire) begin
            $display("FAIL: debug write disturbed controller");$finish;end

        wr(16'h006f,1); repeat(3)@(posedge clk1);
        if(dut.dpll_single_clock_core_stage_a_inst.reacquire_count!==before_reacquire+1) begin
            $display("FAIL: explicit controller reconfigure command");$finish;end

        wr(16'h0028,32'h00000100); wr(16'h0029,32'hffffff00); wr(16'h0020,1);
        force dut.dpll_freq_correction=dut.active_correction_limit_pos;
        repeat(3)@(posedge clk1); release dut.dpll_freq_correction;
        if(!led[4]) begin $display("FAIL: saturation window did not assert LED4");$finish;end
        dut.saturation_window_count=26'd33554432; repeat(2)@(posedge clk1);
        if(led[4]) begin $display("FAIL: saturation window did not clear");$finish;end

        $display("PASS: dpll_wrapper_cdc_tb"); $finish;
    end
endmodule
