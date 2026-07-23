open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set hw [get_hw_devices xc7a35t_0]
current_hw_device $hw
set_property PROBES.FILE      {F:/Xilinx/ND120/ND3202D/output/ND120_TOP.ltx} $hw
set_property FULL_PROBES.FILE {F:/Xilinx/ND120/ND3202D/output/ND120_TOP.ltx} $hw
refresh_hw_device $hw
set ila [get_hw_ilas -of_objects $hw]
foreach p [get_hw_probes -of_objects $ila] { puts "PROBENAME=[get_property NAME $p]" }
close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
