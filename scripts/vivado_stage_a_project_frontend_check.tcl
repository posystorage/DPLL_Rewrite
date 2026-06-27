set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set out_dir [file join $repo_root reports vivado_stage_a_project_frontend]

file mkdir $out_dir
open_project [file join $repo_root DPLL_Rewrite.xpr]
update_compile_order -fileset sources_1
set compile_order [get_files -compile_order sources -used_in synthesis]
set out_file [file join $out_dir compile_order_sources.txt]
set fh [open $out_file w]
foreach f $compile_order {
    puts $fh $f
}
close $fh

if {[llength [get_files -quiet *dpll_clock_valid_stage_a.v]] == 0} {
    error "dpll_clock_valid_stage_a.v is not registered in sources_1"
}

close_project
