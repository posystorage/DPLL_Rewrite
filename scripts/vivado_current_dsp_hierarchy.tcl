set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set checkpoint [file join $repo_root DPLL_Rewrite.runs synth_1 red_pitaya_top.dcp]
set out_dir [file join $repo_root reports vivado_dsp]

file mkdir $out_dir
open_checkpoint $checkpoint
report_utilization -hierarchical -hierarchical_depth 12 \
    -file [file join $out_dir current_synth_utilization_hier.rpt]
close_design
