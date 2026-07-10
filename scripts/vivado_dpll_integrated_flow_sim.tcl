# Add and launch the DigitalPLL integrated flow testbench in the Vivado project.
#
# Usage from repo root:
#   vivado -mode gui   -source scripts/vivado_dpll_integrated_flow_sim.tcl
#   vivado -mode batch -source scripts/vivado_dpll_integrated_flow_sim.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_path [file join $repo_root DPLL_Rewrite.xpr]
set tb_path [file join $repo_root verification rtl dpll_integrated_flow_tb.v]
set post_iir_path [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL DDC post_iir_stage_a.v]
set include_dir [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL]
set compile_only [expr {[llength $argv] > 0 && [lindex $argv 0] eq "compile_only"}]

if {![file exists $project_path]} {
    error "Project not found: $project_path"
}
if {![file exists $tb_path]} {
    error "Testbench not found: $tb_path"
}
if {![file exists $post_iir_path]} {
    error "post-IIR source not found: $post_iir_path"
}

open_project $project_path

set simset [get_filesets sim_1]
set srcset [get_filesets sources_1]

set_property include_dirs [list $include_dir] $srcset
set_property include_dirs [list $include_dir] $simset

if {[llength [get_files -quiet $post_iir_path]] == 0} {
    add_files -fileset sources_1 -norecurse $post_iir_path
}
if {[llength [get_files -quiet $tb_path]] == 0} {
    add_files -fileset sim_1 -norecurse $tb_path
}

set_property used_in_synthesis true [get_files $post_iir_path]
set_property used_in_implementation true [get_files $post_iir_path]
set_property used_in_simulation true [get_files $post_iir_path]
set_property used_in_synthesis false [get_files $tb_path]
set_property used_in_implementation false [get_files $tb_path]
set_property used_in_simulation true [get_files $tb_path]
set_property top dpll_integrated_flow_tb $simset
set_property top_lib xil_defaultlib $simset
set_property top_auto_set false $simset
set_property xsim.simulate.runtime 0ns $simset
set_property xsim.elaborate.debug_level all $simset

foreach ip_name {DAC_DDS0 LO_DDS_H dpll_angle_CORDIC pre_iq_cic_40_125m_v1 mult_gen_pll div_gen_pll_u} {
    set ip_obj [get_ips -quiet $ip_name]
    if {[llength $ip_obj] > 0} {
        generate_target simulation $ip_obj
    }
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation

if {[llength [get_objects -quiet /dpll_integrated_flow_tb/clk1]] > 0} {
    add_wave /dpll_integrated_flow_tb/clk1
    add_wave /dpll_integrated_flow_tb/sys_clk
    add_wave /dpll_integrated_flow_tb/rst
    add_wave /dpll_integrated_flow_tb/sys_rstn

    add_wave /dpll_integrated_flow_tb/sys_addr
    add_wave /dpll_integrated_flow_tb/sys_wdata
    add_wave /dpll_integrated_flow_tb/sys_wen
    add_wave /dpll_integrated_flow_tb/sys_ren
    add_wave /dpll_integrated_flow_tb/sys_ack
    add_wave /dpll_integrated_flow_tb/sys_err
    add_wave /dpll_integrated_flow_tb/sys_rdata

    add_wave /dpll_integrated_flow_tb/adc_dds_valid
    add_wave /dpll_integrated_flow_tb/adc_sample
    add_wave /dpll_integrated_flow_tb/adc_sample_count

    add_wave /dpll_integrated_flow_tb/dut/active_center_word
    add_wave /dpll_integrated_flow_tb/dut/dpll_tracking_valid
    add_wave /dpll_integrated_flow_tb/dut/dpll_tracking_word
    add_wave /dpll_integrated_flow_tb/dut/dpll_phase_error
    add_wave /dpll_integrated_flow_tb/dut/dpll_freq_error
    add_wave /dpll_integrated_flow_tb/dut/dpll_freq_error_valid
    add_wave /dpll_integrated_flow_tb/dut/dpll_magnitude
    add_wave /dpll_integrated_flow_tb/dut/dpll_loop_state
    add_wave /dpll_integrated_flow_tb/dut/dpll_loss_reason
    add_wave /dpll_integrated_flow_tb/dut/dpll_signal_present
    add_wave /dpll_integrated_flow_tb/dut/dpll_phase_locked
    add_wave /dpll_integrated_flow_tb/dut/dpll_frequency_locked
    add_wave /dpll_integrated_flow_tb/dut/dpll_locked

    add_wave /dpll_integrated_flow_tb/dac0_out
    add_wave /dpll_integrated_flow_tb/dac1_debug_out
    add_wave /dpll_integrated_flow_tb/led

    if {$compile_only} {
        puts "DPLL integrated flow compile-only snapshot loaded"
    } else {
        run all
    }
}
