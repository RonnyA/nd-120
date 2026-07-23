open_checkpoint F:/Xilinx/ND120/ND3202D/ND3202D.runs/impl_1/ND120_TOP_routed.dcp
foreach p [get_timing_paths -max_paths 7 -nworst 1 -hold -slack_lesser_than 0] {
  set s [get_property STARTPOINT_PIN $p]
  set d [get_property ENDPOINT_PIN $p]
  set sc [get_property STARTPOINT_CLOCK $p]
  set ec [get_property ENDPOINT_CLOCK $p]
  puts "HOLD [format %.3f [get_property SLACK $p]]  srcclk=$sc dstclk=$ec"
  puts "     $s"
  puts "  -> $d"
}
close_project
exit 0
