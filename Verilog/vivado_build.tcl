# ND-120 Vivado Build Script
# Usage: vivado -mode batch -source vivado_build.tcl
#
# Or from PowerShell:
#   & "C:\Xilinx\Vivado\2024.1\bin\vivado.bat" -mode batch -source E:\Dev\Repos\Ronny\nd-120\Verilog\vivado_build.tcl

# Configuration
set project_dir "F:/Xilinx/ND120/ND3202D"
set top_module "ND120_TOP"
set part "xc7a35tcpg236-1"
set verilog_dir "E:/Dev/Repos/Ronny/nd-120/Verilog"
set constraints_file "${verilog_dir}/vivado_constraints_basys3.xdc"
set output_dir "${project_dir}/output"

# Create output directory
file mkdir $output_dir

puts "============================================"
puts " ND-120 Vivado Build"
puts " Part: $part"
puts " Top:  $top_module"
puts "============================================"

# Open existing project or create new
if {[file exists "${project_dir}/ND3202D.xpr"]} {
    puts "Opening existing project..."
    open_project "${project_dir}/ND3202D.xpr"
} else {
    puts "ERROR: Project not found at ${project_dir}/ND3202D.xpr"
    puts "Please create the project in Vivado GUI first."
    exit 1
}

# Run Synthesis
puts "\n=== SYNTHESIS ==="
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"

if {$synth_status != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# Open synthesized design for reports
open_run synth_1

# Report utilization
report_utilization -file "${output_dir}/utilization_synth.rpt"
puts "Utilization report: ${output_dir}/utilization_synth.rpt"

# Run Implementation
puts "\n=== IMPLEMENTATION ==="
launch_runs impl_1 -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"

if {$impl_status != "route_design Complete!"} {
    puts "WARNING: Implementation may have issues: $impl_status"
}

# Open implemented design
open_run impl_1

# Apply combinational loop constraints (in case XDC didn't catch them)
catch {set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -quiet -filter {NAME =~ *CPU_BOARD*}]}

# Report timing
report_timing_summary -file "${output_dir}/timing_impl.rpt"
puts "Timing report: ${output_dir}/timing_impl.rpt"

# Report utilization
report_utilization -file "${output_dir}/utilization_impl.rpt"
puts "Utilization report: ${output_dir}/utilization_impl.rpt"

# Report DRC
report_drc -file "${output_dir}/drc.rpt"
puts "DRC report: ${output_dir}/drc.rpt"

# Generate Bitstream
puts "\n=== BITSTREAM ==="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check for bitstream
set bit_file "${project_dir}/ND3202D.runs/impl_1/${top_module}.bit"
if {[file exists $bit_file]} {
    file copy -force $bit_file "${output_dir}/${top_module}.bit"
    puts "\nSUCCESS: Bitstream generated!"
    puts "Output: ${output_dir}/${top_module}.bit"
} else {
    puts "\nERROR: Bitstream not generated. Check DRC report."
    puts "Try running in Vivado GUI to see detailed errors."
    exit 1
}

puts "\n=== BUILD COMPLETE ==="
close_project
exit 0
