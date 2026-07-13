set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set out_dir [file join $repo_root reports vivado_full_impl]
set project_file [file join $repo_root DPLL_Rewrite.xpr]

file mkdir $out_dir
open_project $project_file
set impl_run [get_runs impl_1]
set impl_status [get_property STATUS $impl_run]
set bitstream [file join [get_property DIRECTORY $impl_run] red_pitaya_top.bit]
if {![file exists $bitstream]} {
    close_project
    error "completed implementation bitstream is missing: $bitstream"
}
open_run $impl_run

report_timing_summary -max_paths 50 -warn_on_violation \
    -file [file join $out_dir timing_summary.rpt]
report_timing -sort_by group -max_paths 100 \
    -file [file join $out_dir timing_paths.rpt]
report_utilization -hierarchical \
    -file [file join $out_dir utilization_hier.rpt]
report_route_status -file [file join $out_dir route_status.rpt]
report_drc -file [file join $out_dir drc.rpt]
report_methodology -file [file join $out_dir methodology.rpt]
report_clock_utilization -file [file join $out_dir clock_utilization.rpt]

set fh [open [file join $out_dir completed_impl_summary.txt] w]
puts $fh "impl_status=$impl_status"
puts $fh "bitstream=$bitstream"
puts $fh "bitstream_exists=[file exists $bitstream]"
close $fh
close_project
