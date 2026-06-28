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

proc require_one_ip {name} {
    set ip_obj [get_ips -quiet $name]
    if {[llength $ip_obj] != 1} {
        error "Expected one IP named $name, found [llength $ip_obj]"
    }
    return $ip_obj
}

proc require_one_file {path} {
    set file_obj [get_files -quiet $path]
    if {[llength $file_obj] != 1} {
        error "Expected one IP file at $path, found [llength $file_obj]"
    }
    return $file_obj
}

open_project $project_file

set lo_ip [require_one_ip LO_DDS_H]
set lo_file [require_one_file [file join $repo_root DPLL_Rewrite.srcs sources_1 Freq_Meter DDC ip LO_DDS_H LO_DDS_H.xci]]
set cic_ip [require_one_ip cic_compiler_0]
set div_ip [require_one_ip div_gen_pll]

set before [list \
    "before.cic.Clock_Frequency=[get_property CONFIG.Clock_Frequency $cic_ip]" \
    "before.lo.DDS_Clock_Rate=[get_property CONFIG.DDS_Clock_Rate $lo_ip]" \
    "before.lo.Phase_Increment=[get_property CONFIG.Phase_Increment $lo_ip]" \
    "before.lo.Phase_Width=[get_property CONFIG.Phase_Width $lo_ip]" \
    "before.div.operand_sign=[get_property CONFIG.operand_sign $div_ip]" \
    "before.div.latency=[get_property CONFIG.latency $div_ip]" \
]

set_property CONFIG.DDS_Clock_Rate {125} $lo_ip
set_property CONFIG.Phase_Width {48} $lo_ip

generate_target all $lo_file
export_ip_user_files -of_objects $lo_file -no_script -sync -force -quiet

set after [list \
    "after.cic.Clock_Frequency=[get_property CONFIG.Clock_Frequency $cic_ip]" \
    "after.cic.Fixed_Or_Initial_Rate=[get_property CONFIG.Fixed_Or_Initial_Rate $cic_ip]" \
    "after.lo.DDS_Clock_Rate=[get_property CONFIG.DDS_Clock_Rate $lo_ip]" \
    "after.lo.Phase_Increment=[get_property CONFIG.Phase_Increment $lo_ip]" \
    "after.lo.Phase_Width=[get_property CONFIG.Phase_Width $lo_ip]" \
    "after.div.operand_sign=[get_property CONFIG.operand_sign $div_ip]" \
    "after.div.latency=[get_property CONFIG.latency $div_ip]" \
    "note.cic.Clock_Frequency disabled in existing Vivado 2018.3 IP instance; replacement/regeneration remains separate work" \
    "note.div.operand_sign disabled in existing Vivado 2018.3 IP instance; replacement/regeneration remains separate work" \
    "generated_at=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]" \
]

if {[get_property CONFIG.DDS_Clock_Rate $lo_ip] ne "125"} {
    close_project
    error "LO_DDS_H DDS_Clock_Rate did not update to 125"
}
if {[get_property CONFIG.Phase_Increment $lo_ip] ne "Streaming"} {
    close_project
    error "LO_DDS_H Phase_Increment is not Streaming"
}
if {[get_property CONFIG.Phase_Width $lo_ip] ne "48"} {
    close_project
    error "LO_DDS_H Phase_Width did not remain 48"
}

write_lines [file join $out_dir manifest.txt] [concat \
    [list "Review2 IP metadata/config regeneration" "project_file=$project_file"] \
    $before \
    $after \
]

close_project
