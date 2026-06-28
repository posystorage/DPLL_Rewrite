set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set out_dir [file join $repo_root reports vivado_single_clock_core_stage_a_synth_check]

file mkdir $out_dir

create_project -in_memory -part xc7z010clg400-1
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL frontend dc_blocker_valid_stage_a.v]
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL frontend iq_mixer_stage_a.v]
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL iq_cic post_iq_cic_stage_a.v]
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL detector_fll fll_phase_difference_stage_a.v]
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL hybrid_loop loop_state_manager_stage_a.v]
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL hybrid_loop hybrid_fll_pll_filter_stage_a.v]
read_verilog [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL core dpll_single_clock_core_stage_a.v]
synth_design -top dpll_single_clock_core_stage_a -mode out_of_context
create_clock -period 8.000 -name clk_125m [get_ports clk_125m]
report_utilization -file [file join $out_dir utilization_ooc.rpt]
report_timing_summary -file [file join $out_dir timing_ooc.rpt]
close_project
