# Per-domain path extraction from a post-route checkpoint.
# Usage: vivado -mode batch -source report_cpu_paths.tcl -tclargs <rundir>
set rundir [lindex $argv 0]
open_checkpoint [file join $rundir post_route.dcp]
report_timing -delay_type max -group clk_cpu_pre -max_paths 100 -nworst 1 \
    -input_pins -file [file join $rundir setup_paths_cpu_group.rpt]
report_timing -delay_type max -group clk_stor_pre -max_paths 30 -nworst 1 \
    -input_pins -file [file join $rundir setup_paths_stor_group.rpt]
report_design_analysis -logic_level_distribution \
    -of_timing_paths [get_timing_paths -group clk_cpu_pre -max_paths 100 -setup] \
    -file [file join $rundir design_analysis_cpu.rpt]
puts "CPU-GROUP REPORTS DONE"
exit 0
