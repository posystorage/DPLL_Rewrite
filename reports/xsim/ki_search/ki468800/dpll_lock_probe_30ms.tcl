set csv_path [file normalize "dpll_lock_probe_30ms.csv"]
set fd [open $csv_path w]

proc hv {path} {
    set v [get_value -radix hex $path]
    regsub -all {_} $v "" v
    regsub {^0x} $v "" v
    if {$v eq ""} { return "0" }
    if {[regexp {[xXzZ]} $v]} { return "0" }
    return $v
}

proc uv {path} {
    set h [hv $path]
    return [expr 0x$h]
}

proc sv {path width} {
    set u [uv $path]
    set sign [expr {1 << ($width - 1)}]
    set full [expr {1 << $width}]
    if {($u & $sign) != 0} { return [expr {$u - $full}] }
    return $u
}

proc sample {fd label} {
    set loop_state [uv /dpll_integrated_flow_tb/dut/dpll_loop_state]
    set loss_reason [uv /dpll_integrated_flow_tb/dut/dpll_loss_reason]
    set locked [uv /dpll_integrated_flow_tb/dut/dpll_locked]
    set phase_locked [uv /dpll_integrated_flow_tb/dut/dpll_phase_locked]
    set frequency_locked [uv /dpll_integrated_flow_tb/dut/dpll_frequency_locked]
    set phase_error [sv /dpll_integrated_flow_tb/dut/dpll_phase_error 18]
    set freq_error [sv /dpll_integrated_flow_tb/dut/dpll_freq_error 22]
    set freq_error_usable [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/freq_error_usable]
    set state_meas_valid [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/state_measurement_valid_r]
    set good_count [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/loop_state_manager_inst/good_count]
    set bad_count [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/loop_state_manager_inst/bad_count]
    set hybrid_fll [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_enable_fll_r]
    set hybrid_pi [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_enable_pll_i_r]
    set hybrid_pp [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_enable_pll_p_r]
    set hybrid_kf [sv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_kf_r 24]
    set hybrid_ki [sv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_ki_r 24]
    set hybrid_kp [sv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_kp_r 24]
    set fll_term [sv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_loop_inst/fll_term_r 56]
    set i_term [sv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_loop_inst/i_term_r 56]
    set p_term [sv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_loop_inst/p_term_r 56]
    set freq_state [sv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/hybrid_loop_inst/freq_state 56]
    set freq_corr [sv /dpll_integrated_flow_tb/dut/dpll_freq_correction 56]
    set corr_valid [uv /dpll_integrated_flow_tb/dut/dpll_single_clock_core_stage_a_inst/correction_valid]
    puts $fd "$label,$loop_state,$loss_reason,$locked,$phase_locked,$frequency_locked,$phase_error,$freq_error,$freq_error_usable,$state_meas_valid,$good_count,$bad_count,$hybrid_fll,$hybrid_pi,$hybrid_pp,$hybrid_kf,$hybrid_ki,$hybrid_kp,$fll_term,$i_term,$p_term,$freq_state,$freq_corr,$corr_valid"
    flush $fd
    puts "LOCK_30MS $label state=$loop_state loss=$loss_reason locked=$locked plock=$phase_locked flock=$frequency_locked phase=$phase_error freq=$freq_error usable=$freq_error_usable meas=$state_meas_valid good=$good_count bad=$bad_count hfll=$hybrid_fll hpi=$hybrid_pi hpp=$hybrid_pp kf=$hybrid_kf ki=$hybrid_ki kp=$hybrid_kp fll=$fll_term i=$i_term p=$p_term stateword=$freq_state corr=$freq_corr cvalid=$corr_valid"
}

puts $fd "label,loop_state,loss_reason,locked,phase_locked,frequency_locked,phase_error,freq_error,freq_error_usable,state_measurement_valid,good_count,bad_count,hybrid_fll,hybrid_pll_i,hybrid_pll_p,hybrid_kf,hybrid_ki,hybrid_kp,fll_term,i_term,p_term,freq_state,freq_correction,correction_valid"
sample $fd t0
foreach {delay label} {
    100 t100us
    100 t200us
    300 t500us
    500 t1ms
    1000 t2ms
    1000 t3ms
    1000 t4ms
    1000 t5ms
    1000 t6ms
    1000 t7ms
    1000 t8ms
    1000 t9ms
    1000 t10ms
    1000 t11ms
    1000 t12ms
    1000 t13ms
    1000 t14ms
    1000 t15ms
    1000 t16ms
    1000 t17ms
    1000 t18ms
    1000 t19ms
    1000 t20ms
    1000 t21ms
    1000 t22ms
    1000 t23ms
    1000 t24ms
    1000 t25ms
    1000 t26ms
    1000 t27ms
    1000 t28ms
    1000 t29ms
    1000 t30ms
} {
    run $delay us
    sample $fd $label
}
close $fd
puts "LOCK_30MS_CSV $csv_path"
quit
