set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_file [file join $repo_root DPLL_Rewrite.xpr]
set out_dir [file join $repo_root reports review2_ip_config_regen]
set ip_parent_dir [file join $repo_root DPLL_Rewrite.srcs sources_1 DigitalPLL DDC ip pre_iq_cic_40_125m_v1]
set ip_name pre_iq_cic_40_125m_v1

file mkdir $out_dir
file mkdir $ip_parent_dir

proc write_lines {path lines} {
    set fh [open $path w]
    foreach line $lines {
        puts $fh $line
    }
    close $fh
}

open_project $project_file

set existing [get_ips -quiet $ip_name]
if {[llength $existing] != 0} {
    close_project
    error "IP $ip_name already exists; remove it intentionally before regenerating"
}

create_ip -name cic_compiler -vendor xilinx.com -library ip -version 4.0 -module_name $ip_name -dir $ip_parent_dir

set cic_ip [lindex [get_ips $ip_name] 0]

set_property -dict [list \
    CONFIG.Filter_Type {Decimation} \
    CONFIG.Number_Of_Stages {4} \
    CONFIG.Differential_Delay {2} \
    CONFIG.Sample_Rate_Changes {Fixed} \
    CONFIG.Fixed_Or_Initial_Rate {40} \
    CONFIG.Minimum_Rate {40} \
    CONFIG.Maximum_Rate {40} \
    CONFIG.Input_Data_Width {16} \
    CONFIG.Output_Data_Width {16} \
    CONFIG.Quantization {Truncation} \
    CONFIG.Number_Of_Channels {1} \
    CONFIG.Use_Xtreme_DSP_Slice {false} \
    CONFIG.Use_Streaming_Interface {true} \
    CONFIG.HAS_DOUT_TREADY {false} \
    CONFIG.HAS_ACLKEN {false} \
    CONFIG.HAS_ARESETN {false} \
    CONFIG.RateSpecification {Frequency_Specification} \
    CONFIG.Input_Sample_Frequency {125.0} \
    CONFIG.Clock_Frequency {125.0} \
] $cic_ip

generate_target all $cic_ip
export_ip_user_files -of_objects $cic_ip -no_script -sync -force -quiet

set lines [list \
    "pre-IQ CIC replacement IP" \
    "project_file=$project_file" \
    "ip_file=[get_property IP_FILE $cic_ip]" \
    "Clock_Frequency=[get_property CONFIG.Clock_Frequency $cic_ip]" \
    "Input_Sample_Frequency=[get_property CONFIG.Input_Sample_Frequency $cic_ip]" \
    "Fixed_Or_Initial_Rate=[get_property CONFIG.Fixed_Or_Initial_Rate $cic_ip]" \
    "Number_Of_Stages=[get_property CONFIG.Number_Of_Stages $cic_ip]" \
    "Differential_Delay=[get_property CONFIG.Differential_Delay $cic_ip]" \
    "Input_Data_Width=[get_property CONFIG.Input_Data_Width $cic_ip]" \
    "Output_Data_Width=[get_property CONFIG.Output_Data_Width $cic_ip]" \
    "HAS_DOUT_TREADY=[get_property CONFIG.HAS_DOUT_TREADY $cic_ip]" \
    "Use_Xtreme_DSP_Slice=[get_property CONFIG.Use_Xtreme_DSP_Slice $cic_ip]" \
    "generated_at=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]" \
]
write_lines [file join $out_dir pre_iq_cic_40_125m_manifest.txt] $lines

close_project
