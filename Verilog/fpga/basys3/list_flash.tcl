# List available flash parts matching Basys3
puts "=== S25FL parts ==="
foreach p [get_cfgmem_parts *s25fl*] { puts "  $p" }
puts "\n=== All 32Mbit SPI parts ==="
foreach p [get_cfgmem_parts *-spi-*] {
    if {[string match "*32*" $p]} { puts "  $p" }
}
exit 0
