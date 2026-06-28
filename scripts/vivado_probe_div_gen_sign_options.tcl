set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_file [file join $repo_root DPLL_Rewrite.xpr]
set out_dir [file join $repo_root reports review2_ip_config_regen]

file mkdir $out_dir

proc write_lines {path lines} {
    set fh [open $path w]
    foreach line $lines {
        puts $fh $line
    }
    close $fh
}

open_project $project_file

set lines [list "Divider Generator operand sign probe" "project_file=$project_file"]
foreach ip_name [list div_gen_pll div_gen_pll_u] {
    set ip_obj [get_ips -quiet $ip_name]
    if {[llength $ip_obj] == 1} {
        lappend lines "$ip_name.exists=1"
        foreach prop [list CONFIG.algorithm_type CONFIG.remainder_type CONFIG.operand_sign CONFIG.dividend_and_quotient_width CONFIG.divisor_width CONFIG.fractional_width CONFIG.latency CONFIG.latency_configuration CONFIG.FlowControl MODELPARAM_VALUE.SIGNED_B] {
            set value ""
            if {[catch {set value [get_property $prop $ip_obj]} err]} {
                set value "ERROR:$err"
            }
            lappend lines "$ip_name.$prop=$value"
        }
        foreach alg [list High_Radix Radix2 LutMult] {
            set before_alg [get_property CONFIG.algorithm_type $ip_obj]
            set before_sign [get_property CONFIG.operand_sign $ip_obj]
            set result "ok"
            if {[catch {
                set_property CONFIG.algorithm_type $alg $ip_obj
                set_property CONFIG.operand_sign Unsigned $ip_obj
            } err]} {
                set result "ERROR:$err"
            }
            lappend lines "$ip_name.try.$alg.result=$result"
            lappend lines "$ip_name.try.$alg.algorithm_type=[get_property CONFIG.algorithm_type $ip_obj]"
            lappend lines "$ip_name.try.$alg.operand_sign=[get_property CONFIG.operand_sign $ip_obj]"
            catch {set_property CONFIG.algorithm_type $before_alg $ip_obj}
            catch {set_property CONFIG.operand_sign $before_sign $ip_obj}
        }
    } else {
        lappend lines "$ip_name.exists=0"
    }
}

write_lines [file join $out_dir div_gen_sign_probe.txt] $lines
close_project
