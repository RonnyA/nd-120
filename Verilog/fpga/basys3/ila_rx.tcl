open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set hw [get_hw_devices xc7a35t_0]
current_hw_device $hw
set_property PROBES.FILE      {F:/Xilinx/ND120/ND3202D/output/ND120_TOP.ltx} $hw
set_property FULL_PROBES.FILE {F:/Xilinx/ND120/ND3202D/output/ND120_TOP.ltx} $hw
refresh_hw_device $hw
set ila [get_hw_ilas -of_objects $hw]
set rxp [get_hw_probes -of_objects $ila *uartRx*]
set_property TRIGGER_COMPARE_VALUE eq1'b0 $rxp
set_property CONTROL.TRIGGER_POSITION 128 $ila
set_property CONTROL.DATA_DEPTH 1024 $ila
run_hw_ila $ila
puts "ARMED_TYPE_NOW"
flush stdout
# Blocking wait: returns the instant uartRx sees a start bit (user typing).
# Bounded externally by a hard kill if no RX ever arrives.
wait_on_hw_ila $ila
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file {E:/Dev/Repos/Ronny/nd-120/Verilog/fpga/basys3/logs/ila_rx.csv} [current_hw_ila_data]
puts "RX_CAPTURED"
close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
