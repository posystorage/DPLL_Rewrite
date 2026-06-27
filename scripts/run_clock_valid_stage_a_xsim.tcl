set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set out_dir [file join $repo_root reports xsim clock_valid_stage_a]

file mkdir $out_dir
cd $out_dir

create_project clock_valid_stage_a ./clock_valid_stage_a -part xc7z010clg400-1 -force
add_files [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL clocking dpll_clock_valid_stage_a.v]
add_files -fileset sim_1 [file join $repo_root verification rtl dpll_clock_valid_stage_a_tb.v]
set_property top dpll_clock_valid_stage_a_tb [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
