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

set ip_parent_dir [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL VCO div_gen_pll_u]
set ip_dir [file join $ip_parent_dir div_gen_pll_u]
file mkdir $ip_parent_dir

set existing [get_ips -quiet div_gen_pll_u]
if {[llength $existing] == 0} {
    create_ip -name div_gen -vendor xilinx.com -library ip -version 5.1 -module_name div_gen_pll_u -dir $ip_parent_dir
    set div_ip [get_ips div_gen_pll_u]
} elseif {[llength $existing] == 1} {
    set div_ip $existing
} else {
    close_project
    error "Expected zero or one div_gen_pll_u IP, found [llength $existing]"
}

set_property -dict [list \
    CONFIG.algorithm_type {Radix2} \
    CONFIG.FlowControl {NonBlocking} \
    CONFIG.OptimizeGoal {Performance} \
    CONFIG.OutTready {false} \
    CONFIG.OutTLASTBehv {Null} \
    CONFIG.ACLKEN {false} \
    CONFIG.ARESETN {false} \
    CONFIG.divide_by_zero_detect {false} \
    CONFIG.dividend_and_quotient_width {64} \
    CONFIG.divisor_width {16} \
    CONFIG.fractional_width {16} \
    CONFIG.latency_configuration {Manual} \
    CONFIG.latency {32} \
    CONFIG.operand_sign {Unsigned} \
    CONFIG.remainder_type {Fractional} \
    CONFIG.clocks_per_division {1} \
    CONFIG.dividend_has_tlast {false} \
    CONFIG.divisor_has_tlast {false} \
    CONFIG.dividend_has_tuser {false} \
    CONFIG.divisor_has_tuser {false} \
] $div_ip

set div_file [get_files -quiet [file join $ip_dir div_gen_pll_u.xci]]
if {[llength $div_file] != 1} {
    close_project
    error "Expected generated div_gen_pll_u.xci, found [llength $div_file]"
}

generate_target all $div_file
export_ip_user_files -of_objects $div_file -no_script -sync -force -quiet

set sign [get_property CONFIG.operand_sign $div_ip]
set latency [get_property CONFIG.latency $div_ip]
set flow [get_property CONFIG.FlowControl $div_ip]
if {$sign ne "Unsigned"} {
    close_project
    error "div_gen_pll_u operand_sign is $sign, expected Unsigned"
}
if {$latency ne "32"} {
    close_project
    error "div_gen_pll_u latency is $latency, expected 32"
}

write_lines [file join $out_dir div_gen_pll_u_manifest.txt] [list \
    "Unsigned divider replacement IP" \
    "project_file=$project_file" \
    "ip_file=$div_file" \
    "operand_sign=$sign" \
    "latency=$latency" \
    "FlowControl=$flow" \
    "generated_at=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]" \
]

close_project
