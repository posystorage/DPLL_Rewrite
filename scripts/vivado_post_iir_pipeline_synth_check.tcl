set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set out_dir [file join $repo_root reports vivado_post_iir_pipeline_synth_check]

file mkdir $out_dir
create_project -in_memory -part xc7z010clg400-1
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL DDC post_iir_stage_a.v]
synth_design -top post_iir_stage_a -mode out_of_context
create_clock -period 8.000 -name clk_125m [get_ports clk_125m]

set util_file [file join $out_dir post_iir_utilization_ooc.rpt]
set timing_file [file join $out_dir post_iir_timing_ooc.rpt]
report_utilization -hierarchical -file $util_file
report_timing_summary -warn_on_violation -file $timing_file

set dsp_cells [get_cells -hierarchical -filter {REF_NAME == DSP48E1}]
set dsp_count [llength $dsp_cells]
set timing_paths [get_timing_paths -delay_type max -max_paths 1]
set wns 0.0
if {[llength $timing_paths] != 0} {
    set wns [get_property SLACK [lindex $timing_paths 0]]
}
puts "POST_IIR_DSP_COUNT=$dsp_count"
puts "POST_IIR_WNS=$wns"
if {$dsp_count > 4} {
    error "post_iir_stage_a uses $dsp_count DSP48E1 cells; limit is 4"
}
if {$wns < 0.0} {
    error "post_iir_stage_a timing WNS is $wns ns"
}
close_project
