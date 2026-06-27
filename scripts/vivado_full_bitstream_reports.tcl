# Vivado 2018.3 full implementation and bitstream report flow.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/vivado_full_bitstream_reports.tcl
#
# Optional variables:
#   vivado -mode batch -source scripts/vivado_full_bitstream_reports.tcl -tclargs <project> <out_dir>

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]

set project_file [file join $repo_root DPLL_Rewrite.xpr]
set out_dir [file join $repo_root reports vivado_full_impl]
set synth_run synth_1
set impl_run impl_1

if {$argc >= 1} {
    set project_file [file normalize [lindex $argv 0]]
}
if {$argc >= 2} {
    set out_dir [file normalize [lindex $argv 1]]
}

file mkdir $out_dir

proc write_lines {path lines} {
    set fh [open $path w]
    foreach line $lines {
        puts $fh $line
    }
    close $fh
}

set manifest [file join $out_dir manifest.txt]
write_lines $manifest [list \
    "Vivado full implementation manifest" \
    "project_file=$project_file" \
    "synth_run=$synth_run" \
    "impl_run=$impl_run" \
    "out_dir=$out_dir" \
    "generated_at=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]" \
]

open_project $project_file
update_compile_order -fileset sources_1

reset_run $synth_run
launch_runs $impl_run -to_step write_bitstream
wait_on_run $impl_run

set synth_status [get_property STATUS [get_runs $synth_run]]
set impl_status [get_property STATUS [get_runs $impl_run]]
set impl_progress [get_property PROGRESS [get_runs $impl_run]]

set bitstream [file join [get_property DIRECTORY [get_runs $impl_run]] red_pitaya_top.bit]
set bitstream_exists [file exists $bitstream]

write_lines $manifest [list \
    "Vivado full implementation manifest" \
    "project_file=$project_file" \
    "synth_run=$synth_run" \
    "synth_status=$synth_status" \
    "impl_run=$impl_run" \
    "impl_status=$impl_status" \
    "impl_progress=$impl_progress" \
    "bitstream=$bitstream" \
    "bitstream_exists=$bitstream_exists" \
    "out_dir=$out_dir" \
    "generated_at=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]" \
]

if {![regexp {write_bitstream Complete} $impl_status] || !$bitstream_exists} {
    close_project
    error "Full implementation did not complete bitstream generation. impl_status=$impl_status bitstream_exists=$bitstream_exists"
}

open_run $impl_run

report_timing_summary \
    -max_paths 50 \
    -warn_on_violation \
    -file [file join $out_dir timing_summary.rpt]

report_timing \
    -sort_by group \
    -max_paths 100 \
    -file [file join $out_dir timing_paths.rpt]

report_utilization \
    -hierarchical \
    -file [file join $out_dir utilization_hier.rpt]

report_clock_utilization \
    -file [file join $out_dir clock_utilization.rpt]

if {[catch {
    report_clock_interaction \
        -delay_type min_max \
        -file [file join $out_dir clock_interaction.rpt]
} clock_interaction_error]} {
    write_lines [file join $out_dir clock_interaction.ERROR.txt] [list $clock_interaction_error]
}

if {[catch {
    report_cdc \
        -details \
        -file [file join $out_dir cdc.rpt]
} cdc_error]} {
    write_lines [file join $out_dir cdc.ERROR.txt] [list $cdc_error]
}

report_drc \
    -file [file join $out_dir drc.rpt]

report_methodology \
    -file [file join $out_dir methodology.rpt]

report_route_status \
    -file [file join $out_dir route_status.rpt]

if {[catch {
    report_bus_skew \
        -warn_on_violation \
        -file [file join $out_dir bus_skew.rpt]
} bus_skew_error]} {
    write_lines [file join $out_dir bus_skew.ERROR.txt] [list $bus_skew_error]
}

close_project
