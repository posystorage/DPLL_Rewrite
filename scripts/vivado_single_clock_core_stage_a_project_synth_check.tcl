# Vivado 2018.3 project synthesis smoke check for the Stage A single-clock
# shadow core integration.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_file [file join $repo_root DPLL_Rewrite.xpr]
set out_dir [file join $repo_root reports vivado_single_clock_core_stage_a_project_synth]
set synth_run synth_1

if {[catch {
    exec python [file join $repo_root scripts generate_dpll_build_id.py]
} build_id_error]} {
    error "Failed to generate DPLL build identity: $build_id_error"
}

file mkdir $out_dir

proc write_lines {path lines} {
    set fh [open $path w]
    foreach line $lines {
        puts $fh $line
    }
    close $fh
}

open_project $project_file
set dpll_cordic [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL DDC ip dpll_angle_CORDIC synth dpll_angle_CORDIC.vhd]
set dpll_input_multiplier [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL DDC ip dpll_input_multiplier synth dpll_input_multiplier.vhd]
set cordic_adapter [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL detector_fll cordic_word_serial_adapter.v]
if {[llength [get_files -quiet $dpll_cordic]] == 0} {
    add_files -fileset sources_1 $dpll_cordic
}
if {[llength [get_files -quiet $dpll_input_multiplier]] == 0} {
    add_files -fileset sources_1 $dpll_input_multiplier
}
if {[llength [get_files -quiet $cordic_adapter]] == 0} {
    add_files -fileset sources_1 $cordic_adapter
}
update_compile_order -fileset sources_1

reset_run $synth_run
launch_runs $synth_run
wait_on_run $synth_run

set synth_status [get_property STATUS [get_runs $synth_run]]
set synth_progress [get_property PROGRESS [get_runs $synth_run]]
set synth_dir [get_property DIRECTORY [get_runs $synth_run]]

write_lines [file join $out_dir manifest.txt] [list \
    "Vivado project synthesis smoke check" \
    "project_file=$project_file" \
    "synth_run=$synth_run" \
    "synth_status=$synth_status" \
    "synth_progress=$synth_progress" \
    "synth_dir=$synth_dir" \
    "generated_at=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]" \
]

if {![regexp {synth_design Complete} $synth_status]} {
    close_project
    error "Project synthesis did not complete. synth_status=$synth_status"
}

open_run $synth_run
report_timing_summary -max_paths 20 -warn_on_violation -file [file join $out_dir timing_summary_synth.rpt]
report_utilization -hierarchical -file [file join $out_dir utilization_synth.rpt]
close_project
