# Vivado 2018.3 audit report collection for DPLL refactor phases.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/vivado_audit_reports.tcl
#
# Optional variables:
#   vivado -mode batch -source scripts/vivado_audit_reports.tcl -tclargs <project> <run> <out_dir>

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]

set project_file [file join $repo_root DPLL_Rewrite.xpr]
set run_name impl_1
set out_dir [file join $repo_root reports vivado_audit]

if {$argc >= 1} {
    set project_file [file normalize [lindex $argv 0]]
}
if {$argc >= 2} {
    set run_name [lindex $argv 1]
}
if {$argc >= 3} {
    set out_dir [file normalize [lindex $argv 2]]
}

if {[catch {
    exec python [file join $repo_root scripts generate_dpll_build_id.py]
} build_id_error]} {
    error "Failed to generate DPLL build identity: $build_id_error"
}

file mkdir $out_dir

proc write_note {path lines} {
    set fh [open $path w]
    foreach line $lines {
        puts $fh $line
    }
    close $fh
}

set manifest [file join $out_dir manifest.txt]
write_note $manifest [list \
    "Vivado audit report manifest" \
    "project_file=$project_file" \
    "run_name=$run_name" \
    "out_dir=$out_dir" \
    "generated_at=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]" \
]

open_project $project_file

if {[catch {open_run $run_name} open_run_error]} {
    puts "open_run $run_name failed: $open_run_error"
    puts "Attempting launch_runs $run_name -to_step route_design"
    launch_runs $run_name -to_step route_design
    wait_on_run $run_name
    open_run $run_name
}

report_timing_summary \
    -max_paths 50 \
    -warn_on_violation \
    -file [file join $out_dir audit_timing_summary.rpt]

report_timing \
    -sort_by group \
    -max_paths 100 \
    -file [file join $out_dir audit_timing_paths.rpt]

report_utilization \
    -hierarchical \
    -file [file join $out_dir audit_utilization_hier.rpt]

report_clock_utilization \
    -file [file join $out_dir audit_clock_utilization.rpt]

if {[catch {
    report_clock_interaction \
        -delay_type min_max \
        -file [file join $out_dir audit_clock_interaction.rpt]
} clock_interaction_error]} {
    write_note [file join $out_dir audit_clock_interaction.ERROR.txt] [list $clock_interaction_error]
}

if {[catch {
    report_cdc \
        -details \
        -file [file join $out_dir audit_cdc.rpt]
} cdc_error]} {
    write_note [file join $out_dir audit_cdc.ERROR.txt] [list $cdc_error]
}

report_drc \
    -file [file join $out_dir audit_drc.rpt]

report_methodology \
    -file [file join $out_dir audit_methodology.rpt]

report_route_status \
    -file [file join $out_dir audit_route_status.rpt]

if {[catch {
    report_bus_skew \
        -warn_on_violation \
        -file [file join $out_dir audit_bus_skew.rpt]
} bus_skew_error]} {
    write_note [file join $out_dir audit_bus_skew.ERROR.txt] [list $bus_skew_error]
}

close_project
