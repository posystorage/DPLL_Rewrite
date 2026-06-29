`timescale 1ns/1ps
module pre_iq_cic_40_125m_v1(input aclk,input [15:0] s_axis_data_tdata,input s_axis_data_tvalid,output s_axis_data_tready,output [15:0] m_axis_data_tdata,output m_axis_data_tvalid); assign s_axis_data_tready=1'b1; assign m_axis_data_tdata=s_axis_data_tdata; assign m_axis_data_tvalid=s_axis_data_tvalid; endmodule
module dpll_single_clock_core_stage_a(
 input clk_125m,input rst_125m,input sample_valid,input loop_enable,input signed [15:0] adc_sample,input [47:0] center_word,input config_apply,input [8:0] cic_rate_r,input [5:0] cic_output_shift,input cic_flush,input [1:0] fll_delay_sel,input signed [23:0] kf,input signed [23:0] ki,input signed [23:0] kp,input signed [23:0] kf_blend,input signed [23:0] kf_track,input signed [23:0] kp_blend,input signed [23:0] ki_blend,input signed [17:0] phase_setpoint,input [17:0] phase_lock_threshold,input [21:0] freq_lock_threshold,input [15:0] mag_enter_threshold,input [15:0] mag_exit_threshold,input [15:0] acquire_dwell,input [15:0] blend_dwell,input [15:0] loss_dwell,input [23:0] measurement_timeout,input [23:0] holdover_timeout,input [15:0] warmup_samples,input signed [55:0] positive_limit,input signed [55:0] negative_limit,
 output reg [47:0] tracking_word,output tracking_valid,output signed [17:0] cordic_phase_out,output signed [17:0] phase_error,output signed [21:0] freq_error,output freq_error_valid,output signed [19:0] i_baseband,output signed [19:0] q_baseband,output iq_valid,output signed [55:0] freq_state,output signed [55:0] freq_correction,output [15:0] magnitude,output [3:0] loop_state,output [3:0] loss_reason,output signal_present,output phase_locked,output frequency_locked,output locked,output [8:0] active_cic_rate_r,output [5:0] active_cic_output_shift,output cic_overflow_seen,output cic_illegal_config_seen,output signed [15:0] lo_cos,output signed [15:0] lo_sin);
 initial tracking_word=0; always @(posedge clk_125m) if(config_apply) tracking_word<=center_word; assign tracking_valid=config_apply; assign cordic_phase_out=0; assign phase_error=0; assign freq_error=0; assign freq_error_valid=0; assign i_baseband=0; assign q_baseband=0; assign iq_valid=0; assign freq_state=0; assign freq_correction=0; assign magnitude=0; assign loop_state=0; assign loss_reason=0; assign signal_present=0; assign phase_locked=0; assign frequency_locked=0; assign locked=0; assign active_cic_rate_r=cic_rate_r; assign active_cic_output_shift=cic_output_shift; assign cic_overflow_seen=0; assign cic_illegal_config_seen=0; assign lo_cos=0; assign lo_sin=0; endmodule
module PLL_VCO_MUL_DIV(input clk,input rst,input sample_valid,input [47:0] data_in,output reg [47:0] data_out,input [15:0] PLL_Mul_factor,input [15:0] PLL_Div_factor,output reg config_error); initial begin data_out=0; config_error=0; end always @(posedge clk) if(sample_valid) data_out<=data_in; endmodule
module VCO_48bits(input clk,input [47:0] VCO_input,input [13:0] VCO_offset,input [15:0] VCO_amplitude,output [15:0] VCO_DAC_out); assign VCO_DAC_out=0; endmodule
module debug_dac_formatter_stage_a(input clk_125m,input rst_125m,input source_valid,input signed [31:0] source_word,input [31:0] format_word,input signed [15:0] gain,input signed [15:0] offset,output signed [15:0] dac_sample); assign dac_sample=0; endmodule

module dpll_wrapper_cdc_tb;
 reg clk1=0,sys_clk=0,rst=0,sys_rstn=0; always #4 clk1=~clk1; always #5.5 sys_clk=~sys_clk;
 reg signed [15:0] ADCraw0=0,ADCraw1=0; wire signed [15:0] DACout0,DACout1; reg [31:0] sys_addr=0,sys_wdata=0; reg [3:0] sys_sel=4'hf; reg sys_wen=0,sys_ren=0; wire [31:0] sys_rdata; wire sys_err,sys_ack; wire [6:0] led;
 dpll_wrapper dut(.clk1(clk1),.rst(rst),.sys_clk(sys_clk),.sys_rstn(sys_rstn),.ADCraw0(ADCraw0),.ADCraw1(ADCraw1),.DACout0(DACout0),.DACout1(DACout1),.sys_addr(sys_addr),.sys_wdata(sys_wdata),.sys_sel(sys_sel),.sys_wen(sys_wen),.sys_ren(sys_ren),.sys_rdata(sys_rdata),.sys_err(sys_err),.sys_ack(sys_ack),.led(led));
 task wr; input [15:0] a; input [31:0] d; begin @(negedge sys_clk); sys_addr={14'd0,a,2'b00}; sys_wdata=d; sys_wen=1; @(posedge sys_clk); #1; if(!sys_ack) begin $display("FAIL: write ack addr=%h",a);$finish;end @(negedge sys_clk);sys_wen=0; end endtask
 task wr_expect_err; input [15:0] a; input [31:0] d; begin @(negedge sys_clk); sys_addr={14'd0,a,2'b00}; sys_wdata=d; sys_wen=1; @(posedge sys_clk); #1; if(!sys_ack||!sys_err) begin $display("FAIL: busy write did not return err addr=%h ack=%b err=%b",a,sys_ack,sys_err);$finish;end @(negedge sys_clk);sys_wen=0; end endtask
 task rd; input [15:0] a; output [31:0] d; integer n; begin @(negedge sys_clk);sys_addr={14'd0,a,2'b00};sys_ren=1;@(posedge sys_clk);#1;@(negedge sys_clk);sys_ren=0;n=0;while(!sys_ack&&n<20)begin @(posedge sys_clk);#1;n=n+1;end if(!sys_ack)begin $display("FAIL: read timeout addr=%h",a);$finish;end d=sys_rdata;end endtask
 task wait_idle; integer n; reg [31:0] s; begin n=0;s=1;while((s[0]||s[15:8]==0)&&n<30)begin rd(16'h006f,s);n=n+1;end if(s[0])begin $display("FAIL: apply busy stuck");$finish;end end endtask
 function [31:0] crc_mix; input [31:0] crc; input [31:0] value; reg [31:0] mixed; begin mixed=crc^value; crc_mix={mixed[26:0],mixed[31:27]}^32'h9e37_79b9; end endfunction
 function [31:0] expected_active_crc; input dummy; reg [31:0] crc; begin
   crc=32'h4450_4c4c;
   crc=crc_mix(crc,32'h12345678); crc=crc_mix(crc,{17'h0,6'd13,9'd78}); crc=crc_mix(crc,{16'd1,16'd1});
   crc=crc_mix(crc,32'hff800001); crc=crc_mix(crc,32'h00000002); crc=crc_mix(crc,32'h00000008);
   crc=crc_mix(crc,32'h00000004); crc=crc_mix(crc,32'h00000001); crc=crc_mix(crc,32'h00000002);
   crc=crc_mix(crc,32'h00000001); crc=crc_mix(crc,32'h00000000); crc=crc_mix(crc,32'h00007fff);
   crc=crc_mix(crc,32'h00007fff); crc=crc_mix(crc,{16'h0100,16'h0040}); crc=crc_mix(crc,{16'd4,16'd4});
   crc=crc_mix(crc,{16'd4,16'd4}); crc=crc_mix(crc,32'd9616); crc=crc_mix(crc,32'd1250000);
   crc=crc_mix(crc,32'h7fffffff); crc=crc_mix(crc,32'h80000000); crc=crc_mix(crc,32'h00000000);
   crc=crc_mix(crc,32'h00007fff); crc=crc_mix(crc,32'h00123456); crc=crc_mix(crc,32'h89abcdef);
   expected_active_crc=crc_mix(crc,32'h10203040);
 end endfunction
 reg [31:0] v; reg [47:0] saved_center;
 initial begin repeat(4)@(posedge clk1); rst=1;sys_rstn=1;repeat(4)@(posedge sys_clk);
   rd(16'h010d,v);if(v!==`DPLL_GENERATED_CONFIG_VERSION)begin $display("FAIL: config version %h",v);$finish;end
   rd(16'h010e,v);if(v!==`DPLL_GENERATED_ABI_VERSION)begin $display("FAIL: ABI version %h",v);$finish;end
   rd(16'h010f,v);if(v!==`DPLL_GENERATED_BUILD_ID)begin $display("FAIL: build id %h",v);$finish;end
   rd(16'h011d,v);if(v!==`DPLL_GENERATED_GIT_HASH)begin $display("FAIL: git hash %h",v);$finish;end
   force dut.pre_cic_ready=1'b0;repeat(4)@(posedge clk1);release dut.pre_cic_ready;rd(16'h0108,v);if(!v[19])begin $display("FAIL: pre-CIC backpressure fault not latched flags=%h",v);$finish;end
   wr(16'h0010,32'h12345678);wr(16'h0021,32'hff800001);wr(16'h0040,32'h00000012);wr(16'h0041,32'h00003456);wr(16'h0042,32'h89abcdef);wr(16'h0043,32'h10203040);wr(16'h0060,78);wr(16'h0061,13);wr(16'h0058,1250000);wr(16'h0059,0);wr(16'h006f,1);wait_idle();
   if(dut.active_center_word!==48'h123456780000||dut.active_post_iq_cic_rate_r!==78||dut.active_kp!==24'h800001||dut.active_debug_dac_offset!==14'h0012||dut.active_debug_dac_gain!==16'h3456||dut.active_debug_dac_source!==32'h89abcdef||dut.active_debug_dac_format!==32'h10203040||dut.config_apply_sequence!==1)begin $display("FAIL: legal commit active=%h r=%0d kp=%h seq=%0d",dut.active_center_word,dut.active_post_iq_cic_rate_r,dut.active_kp,dut.config_apply_sequence);$finish;end
   rd(16'h0110,v);if(v!==32'h12345678)begin $display("FAIL: snapshot center %h",v);$finish;end saved_center=dut.active_center_word;
   rd(16'h011e,v);if(v!==expected_active_crc(1'b0))begin $display("FAIL: active config crc %h expected %h",v,expected_active_crc(1'b0));$finish;end
   wr(16'h0010,32'hdeadbeef);wr(16'h0060,7);wr(16'h006f,1);repeat(8)@(posedge sys_clk);rd(16'h006f,v);if(!v[1]||v[15:8]!==1||dut.active_center_word!==saved_center)begin $display("FAIL: rejected apply status=%h center=%h",v,dut.active_center_word);$finish;end rd(16'h0070,v);if(!v[0])begin $display("FAIL: rejected mask=%h",v);$finish;end
   wr(16'h0060,8);wr(16'h0061,4);wr(16'h0021,32'h01800001);wr(16'h006f,1);repeat(8)@(posedge sys_clk);rd(16'h006f,v);if(!v[1]||v[7:4]!==4'ha)begin $display("FAIL: illegal coefficient width accepted status=%h",v);$finish;end rd(16'h0070,v);if(!v[9])begin $display("FAIL: illegal width rejected mask=%h",v);$finish;end
   wr(16'h0021,32'hff800001);wr(16'h0053,32'h00000100);wr(16'h0054,32'h00000100);wr(16'h006f,1);repeat(8)@(posedge sys_clk);rd(16'h006f,v);if(!v[1]||v[7:4]!==4'h6)begin $display("FAIL: equal magnitude thresholds accepted status=%h",v);$finish;end
   wr(16'h0053,32'h00000100);wr(16'h0054,32'h00000040);wr(16'h0060,78);wr(16'h0061,12);wr(16'h006f,1);wait_idle();if(dut.active_post_iq_cic_shift!==12)begin $display("FAIL: conservative CIC shift legal value rejected shift=%0d",dut.active_post_iq_cic_shift);$finish;end
   wr(16'h0060,8);wr(16'h0061,4);wr(16'h0010,0);wr(16'h002a,32'hffffffec);wr(16'h006f,1);repeat(12)@(posedge clk1);if(dut.vco_tracking_word!==0||!dut.manual_offset_overflow)begin $display("FAIL: negative offset saturation word=%h ov=%b",dut.vco_tracking_word,dut.manual_offset_overflow);$finish;end
   wr(16'h0010,32'hffffffff);wr(16'h002a,32'h00010000);wr(16'h006f,1);repeat(12)@(posedge clk1);if(dut.vco_tracking_word!==48'hffff_ffff_ffff||!dut.manual_offset_overflow)begin $display("FAIL: positive offset saturation word=%h ov=%b",dut.vco_tracking_word,dut.manual_offset_overflow);$finish;end
   wr(16'h0010,32'h01000000);wr(16'h006f,1);wr_expect_err(16'h0010,32'h02000000);wait_idle();
   $display("PASS: dpll_wrapper_cdc_tb");$finish;end
endmodule
