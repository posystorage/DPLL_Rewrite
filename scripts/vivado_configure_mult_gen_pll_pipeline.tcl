set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_file [file join $repo_root DPLL_Rewrite.xpr]
set ip_path [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL VCO mult_gen_pll mult_gen_pll.xci]

open_project $project_file
set ip_obj [get_ips mult_gen_pll]
if {[llength $ip_obj] != 1} {
    close_project
    error "Expected one mult_gen_pll IP, found [llength $ip_obj]"
}
set ip_file [get_files -quiet $ip_path]
if {[llength $ip_file] != 1} {
    close_project
    error "Expected one mult_gen_pll XCI at $ip_path, found [llength $ip_file]"
}

set_property CONFIG.PipeStages {8} $ip_obj
generate_target all $ip_file
export_ip_user_files -of_objects $ip_file -no_script -sync -force -quiet

set pipe_stages [get_property CONFIG.PipeStages $ip_obj]
if {$pipe_stages != 8} {
    close_project
    error "mult_gen_pll PipeStages is $pipe_stages, expected 8"
}

set ip_run [get_runs -quiet mult_gen_pll_synth_1]
if {[llength $ip_run] != 1} {
    close_project
    error "Expected existing mult_gen_pll_synth_1 run, found [llength $ip_run]"
}

reset_run $ip_run
launch_runs $ip_run
wait_on_run $ip_run

set run_status [get_property STATUS $ip_run]
if {![regexp {synth_design Complete} $run_status]} {
    close_project
    error "mult_gen_pll_synth_1 did not complete: $run_status"
}

close_project
