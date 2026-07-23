open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set hw [get_hw_devices xc7a35t_0]
current_hw_device $hw
set_property PROGRAM.FILE {F:/Xilinx/ND120/ND3202D/output/ND120_TOP.bit} $hw
set_property PROBES.FILE      {F:/Xilinx/ND120/ND3202D/output/ND120_TOP.ltx} $hw
set_property FULL_PROBES.FILE {F:/Xilinx/ND120/ND3202D/output/ND120_TOP.ltx} $hw
program_hw_devices $hw
refresh_hw_device $hw
set ila [get_hw_ilas -of_objects $hw]
set lcs [get_hw_probes -of_objects $ila s_debug_lcs_n]
# Armed while SW0 held (lcs_n=0). Fires when load completes (lcs_n->1) = self-test start.
set_property TRIGGER_COMPARE_VALUE eq1'h1 $lcs
set_property CONTROL.TRIGGER_POSITION 20 $ila
set_property CONTROL.DATA_DEPTH 1024 $ila
run_hw_ila $ila
puts "REALLY_ARMED_NOW"
flush stdout
wait_on_hw_ila $ila
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file {E:/Dev/Repos/Ronny/nd-120/Verilog/fpga/basys3/logs/ila_cold2.csv} [current_hw_ila_data]
puts "COLD2_CAPTURED"
close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
