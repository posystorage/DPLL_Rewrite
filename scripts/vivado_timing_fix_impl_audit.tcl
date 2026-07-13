set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_file [file join $repo_root DPLL_Rewrite.xpr]
set out_file [file join $repo_root reports vivado_full_impl timing_fix_audit.txt]

proc write_item {fh key value} {
    puts $fh "$key=$value"
    puts "$key=$value"
}

proc write_path {fh label paths} {
    if {[llength $paths] == 0} {
        write_item $fh "${label}_PATH_COUNT" 0
        return
    }

    set path [lindex $paths 0]
    set start_pin [get_property STARTPOINT_PIN $path]
    set end_pin [get_property ENDPOINT_PIN $path]
    write_item $fh "${label}_PATH_COUNT" [llength $paths]
    write_item $fh "${label}_SLACK_NS" [get_property SLACK $path]
    write_item $fh "${label}_START" [get_property NAME $start_pin]
    write_item $fh "${label}_END" [get_property NAME $end_pin]
}

open_project $project_file
open_run impl_1

file mkdir [file dirname $out_file]
set fh [open $out_file w]

set dna_clk_c [get_pins -quiet -hier -filter {
    NAME =~ *i_hk/dna_clk_reg/C
}]
set dna_clk_q [get_pins -quiet -hier -filter {
    NAME =~ *i_hk/dna_clk_reg/Q
}]
set status_addr_regs [get_cells -quiet -hier -filter {
    IS_SEQUENTIAL && NAME =~ *dpll_wrapper_inst/status_request_addr_sys_reg*
}]
set status_data_regs [get_cells -quiet -hier -filter {
    IS_SEQUENTIAL && NAME =~ *dpll_wrapper_inst/status_response_data_clk_reg*
}]

write_item $fh DNA_CLK_C_COUNT [llength $dna_clk_c]
write_item $fh DNA_CLK_Q_COUNT [llength $dna_clk_q]
write_item $fh STATUS_ADDR_REG_COUNT [llength $status_addr_regs]
write_item $fh STATUS_DATA_REG_COUNT [llength $status_data_regs]

set all_dsps [get_cells -quiet -hier -filter {REF_NAME == DSP48E1}]
set cross_dsps [get_cells -quiet -hier -filter {
    REF_NAME == DSP48E1 && NAME =~ *fll_cross_dot_inst/*
}]
set hybrid_dsps [get_cells -quiet -hier -filter {
    REF_NAME == DSP48E1 && NAME =~ *hybrid_loop_inst/*
}]
write_item $fh TOTAL_DSP48E1_COUNT [llength $all_dsps]
write_item $fh CROSS_DOT_DSP48E1_COUNT [llength $cross_dsps]
write_item $fh HYBRID_DSP48E1_COUNT [llength $hybrid_dsps]

foreach reset_name {rst_core_r rst_vco_r} {
    set reset_q [get_pins -quiet -hier -filter \
        "NAME =~ *dpll_wrapper_inst/${reset_name}_reg/Q"]
    set reset_endpoints [all_fanout -quiet -flat -endpoints_only -from $reset_q]
    write_item $fh "[string toupper $reset_name]_Q_COUNT" [llength $reset_q]
    write_item $fh "[string toupper $reset_name]_ENDPOINT_COUNT" \
        [llength $reset_endpoints]
    write_path $fh "[string toupper $reset_name]_FROM" \
        [get_timing_paths -quiet -delay_type max -from $reset_q -max_paths 1]
}

set cross_cells [get_cells -quiet -hier -filter {
    NAME =~ *dpll_single_clock_core_stage_a_inst/fll_cross_dot_inst/*
}]
set hybrid_cells [get_cells -quiet -hier -filter {
    NAME =~ *dpll_single_clock_core_stage_a_inst/hybrid_loop_inst/*
}]
set cross_d [get_pins -quiet -of_objects $cross_cells -filter {REF_PIN_NAME == D}]
set cross_q [get_pins -quiet -of_objects $cross_cells -filter {REF_PIN_NAME == Q}]
set hybrid_d [get_pins -quiet -of_objects $hybrid_cells -filter {REF_PIN_NAME == D}]
set hybrid_q [get_pins -quiet -of_objects $hybrid_cells -filter {REF_PIN_NAME == Q}]

write_path $fh CROSS_DOT_TO \
    [get_timing_paths -quiet -delay_type max -to $cross_d -max_paths 1]
write_path $fh CROSS_DOT_FROM \
    [get_timing_paths -quiet -delay_type max -from $cross_q -max_paths 1]
write_path $fh HYBRID_TO \
    [get_timing_paths -quiet -delay_type max -to $hybrid_d -max_paths 1]
write_path $fh HYBRID_FROM \
    [get_timing_paths -quiet -delay_type max -from $hybrid_q -max_paths 1]
write_path $fh STATUS_ADDR_TO_DATA \
    [get_timing_paths -quiet -delay_type max -from $status_addr_regs \
        -to $status_data_regs -max_paths 1]
write_path $fh OVERALL_SETUP \
    [get_timing_paths -quiet -delay_type max -max_paths 1]
write_path $fh OVERALL_HOLD \
    [get_timing_paths -quiet -delay_type min -max_paths 1]
write_path $fh PLL_ADC_CLK_SETUP \
    [get_timing_paths -quiet -delay_type max -group pll_adc_clk -max_paths 1]
write_path $fh PLL_ADC_CLK_HOLD \
    [get_timing_paths -quiet -delay_type min -group pll_adc_clk -max_paths 1]

close $fh
close_project
