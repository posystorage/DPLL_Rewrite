# Vivado 2018.3 focused timing reports for non-excluded failing clock pairs.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/vivado_nonexcluded_timing_reports.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_file [file join $repo_root DPLL_Rewrite.xpr]
set out_dir [file join $repo_root reports vivado_full_impl]

file mkdir $out_dir

open_project $project_file
open_run impl_1

report_timing \
    -from [get_clocks adc_clk] \
    -to [get_clocks adc_clk] \
    -max_paths 20 \
    -sort_by slack \
    -file [file join $out_dir timing_adc_to_adc.rpt]

report_timing \
    -from [get_clocks pll_adc_clk] \
    -to [get_clocks pll_adc_clk] \
    -max_paths 40 \
    -sort_by slack \
    -file [file join $out_dir timing_pll_adc_to_pll_adc.rpt]

report_timing \
    -from [get_clocks pll_clk_adc_2x] \
    -to [get_clocks pll_clk_adc_2x] \
    -max_paths 20 \
    -sort_by slack \
    -file [file join $out_dir timing_pll_clk_adc_2x.rpt]

report_timing \
    -from [get_clocks clk_fpga_3] \
    -to [get_clocks clk_fpga_3] \
    -max_paths 20 \
    -sort_by slack \
    -file [file join $out_dir timing_clk_fpga_3.rpt]

close_project
