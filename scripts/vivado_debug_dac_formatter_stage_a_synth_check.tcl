set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set out_dir [file join $repo_root reports vivado_debug_dac_formatter_stage_a_synth_check]

file mkdir $out_dir

create_project -in_memory -part xc7z010clg400-1
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL debug debug_dac_formatter_stage_a.v]
synth_design -top debug_dac_formatter_stage_a -mode out_of_context
create_clock -period 8.000 -name clk_125m [get_ports clk_125m]
report_utilization -file [file join $out_dir utilization_ooc.rpt]
report_timing_summary -file [file join $out_dir timing_ooc.rpt]
close_project
