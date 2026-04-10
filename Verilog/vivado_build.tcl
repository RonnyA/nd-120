# ND-120 Vivado Build Script
# Usage: vivado -mode batch -source vivado_build.tcl -tclargs [flags...]
#
# Flags (any order):
#   full_synth       — REQUIRED for a ~1h full re-synthesis (reset_run + launch). Without this flag, the script REUSES
#                      the existing synth_1 checkpoint and does NOT restart synthesis (safe to source from GUI).
#   skip_program     — do not open Hardware Manager / JTAG / SPI flash
#   skip_synth       — (legacy) same as default — reuse existing synth_1 checkpoint
#   no_reset_synth   — only with full_synth: do not call reset_run synth_1 before launch_runs
#   backup_bit       — only with full_synth: copy output/ND120_TOP.bit to ND120_TOP.before_synth.bit if it exists
#
# From PowerShell:
#   .\vivado_build.ps1

# Configuration
set project_dir "F:/Xilinx/ND120/ND3202D"
set top_module "ND120_TOP"
set part "xc7a35tcpg236-1"
set verilog_dir "E:/Dev/Repos/Ronny/nd-120/Verilog"
set output_dir "${project_dir}/output"

# Create output directory
file mkdir $output_dir

# Verify microcode hex files are present (PS1 should have copied them)
foreach hex {AM27256_45132L.hex AM27256_45133L.hex} {
    if {![file exists "${project_dir}/${hex}"]} {
        puts "ERROR: Microcode file missing: ${project_dir}/${hex}"
        puts "The ROM will be empty without this file. Aborting."
        exit 1
    }
    puts "Microcode OK: $hex ([file size ${project_dir}/${hex}] bytes)"
}

puts "============================================"
puts " ND-120 Vivado Build"
puts " Part: $part"
puts " Top:  $top_module"
puts "============================================"

# Open existing project (GUI may already have it open — do not fail)
if {![file exists "${project_dir}/ND3202D.xpr"]} {
    puts "ERROR: Project not found at ${project_dir}/ND3202D.xpr"
    puts "Please create the project in Vivado GUI first."
    exit 1
}
puts "Opening existing project..."
if {[catch {open_project "${project_dir}/ND3202D.xpr"} err]} {
    if {[string match -nocase *already*open* $err]} {
        puts "Project already open in this session — continuing."
    } else {
        puts "ERROR: $err"
        exit 1
    }
}

########################################################################
# Suppress known harmless synthesis warnings
#  - Synth 8-3936: register trimming (R81/L4/L8/R41P fewer bits than width)
#  - Synth 8-5837: dual async set/reset (D_FLIPFLOP/F617/F714)
########################################################################
set_msg_config -id {Synth 8-3936} -suppress
set_msg_config -id {Synth 8-5837} -suppress

########################################################################
# SYNTHESIS
########################################################################
puts "\n=== SYNTHESIS ==="
# Default: reuse synth checkpoint (no 1h wait). Pass full_synth to force reset_run + launch_runs.
if {[lsearch $argv full_synth] >= 0} {
    # reset_run synth_1 deletes the previous synth run up front — use no_reset_synth to skip that.
    if {[lsearch $argv backup_bit] >= 0} {
        set prev_bit "${output_dir}/${top_module}.bit"
        if {[file exists $prev_bit]} {
            set bak "${output_dir}/${top_module}.before_synth.bit"
            file copy -force $prev_bit $bak
            puts "backup_bit: saved previous bitstream as $bak"
        }
    }
    if {[lsearch $argv no_reset_synth] >= 0} {
        puts "no_reset_synth: skipping reset_run synth_1 (previous run not cleared before launch)."
    } else {
        reset_run synth_1
    }
    launch_runs synth_1 -jobs 12
    if {[catch {wait_on_run synth_1} err]} {
        puts "WARNING: wait_on_run returned error: $err"
        puts "Checking if synthesis completed anyway..."
    }

    set synth_status [get_property STATUS [get_runs synth_1]]
    set synth_progress [get_property PROGRESS [get_runs synth_1]]
    puts "Synthesis status: $synth_status  progress: $synth_progress"

    # Check if synthesis succeeded by trying to open the run
    # (more reliable than checking STATUS string which varies across Vivado versions)
    if {[catch {open_run synth_1} err]} {
        puts "ERROR: Synthesis failed - could not open synthesized design"
        puts "  Status: $synth_status"
        puts "  Error: $err"
        exit 1
    }
    puts "Synthesized design opened successfully"
} else {
    puts "DEFAULT: NOT re-running synthesis (no full_synth flag) — opening existing synth_1 checkpoint."
    puts "  To force full synthesis (~1h), add:  -tclargs full_synth  (and other flags as needed)"
    if {[catch {open_run synth_1} err]} {
        puts "ERROR: Could not open synth_1 — no checkpoint yet."
        puts "  Run once with full synthesis, e.g.:"
        puts "    set argv { full_synth skip_program }"
        puts "    source -notrace {<path>/vivado_build.tcl}"
        puts "  Details: $err"
        exit 1
    }
    puts "Synthesized design opened successfully (from checkpoint)"
}

# Report utilization after synthesis
report_utilization -file "${output_dir}/utilization_synth.rpt"
report_ram_utilization -detail -file "${output_dir}/ram_utilization.rpt"
puts "Utilization report: ${output_dir}/utilization_synth.rpt"
puts "RAM report: ${output_dir}/ram_utilization.rpt"

# Verify BRAM count - microcode ROM should use at least 8 BRAMs
set bram_count [llength [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ BMEM.*}]]
puts "BRAM cells used: $bram_count"
if {$bram_count < 8} {
    puts "WARNING: Only $bram_count BRAMs - microcode ROM may be empty!"
}

# Dump BRAM INIT values to verify microcode ROM is populated
set rom_cells [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ BMEM.* && NAME =~ *rom_lo* || NAME =~ *rom_hi*}]
set rom_report_file "${output_dir}/rom_init_check.txt"
set fp [open $rom_report_file w]
puts $fp "=== Microcode ROM BRAM INIT Check ==="
puts $fp "Date: [clock format [clock seconds]]"
puts $fp ""
foreach cell $rom_cells {
    puts $fp "Cell: $cell"
    set init0 [get_property INIT_00 $cell]
    set init1 [get_property INIT_01 $cell]
    puts $fp "  INIT_00: $init0"
    puts $fp "  INIT_01: $init1"
    if {$init0 eq "256'h0000000000000000000000000000000000000000000000000000000000000000"
        || $init0 eq ""} {
        puts $fp "  ** WARNING: INIT_00 is all zeros - ROM may be empty!"
    } else {
        puts $fp "  OK: INIT_00 has non-zero data"
    }
    puts $fp ""
}
close $fp
puts "ROM init check: ${rom_report_file}"

########################################################################
# SET UP ILA DEBUG CORE
# Recreated after every synthesis because net names may change.
# Probes all mark_debug signals from ND120_TOP.
########################################################################
puts "\n=== SETTING UP ILA DEBUG CORE ==="

# Remove any existing debug cores from previous runs
catch {delete_debug_core -quiet [get_debug_cores -quiet]}

# Create ILA core
create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]

# Connect ILA clock
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list sysclk_IBUF_BUFG]]

# Helper: connect a probe to nets that actually exist after synthesis.
# If some bits were optimized away, the probe is sized to match what's available.
proc connect_probe {probe_port net_pattern probe_name} {
    set nets [get_nets -quiet $net_pattern]
    set count [llength $nets]
    if {$count == 0} {
        puts "WARNING: No nets found for $probe_name ($net_pattern) - skipping probe"
        # Connect to a dummy 1-bit signal to avoid unconnected probe errors
        set_property port_width 1 [get_debug_ports $probe_port]
        connect_debug_port $probe_port [get_nets [list sysclk_IBUF_BUFG]]
        return
    }
    puts "  $probe_name: $count nets found"
    set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports $probe_port]
    set_property port_width $count [get_debug_ports $probe_port]
    connect_debug_port $probe_port $nets
}

# probe0: MIC address (CSA_12_0)
connect_probe u_ila_0/probe0 {s_debug_csa[*]} "CSA"

# probe1: CPU run state
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe1 {s_run} "RUN"

# probe2: Cycle state {TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe2 {s_debug_cc_term[*]} "CC_TERM"

# probe3: LCS_n (microcode loaded)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe3 {s_debug_lcs_n} "LCS_n"

# probe4: UART TX
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe4 {s_debug_uartTx} "UART_TX"

# probe5: Memory clock
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe5 {s_debug_mclk} "MCLK"

# probe6: UART RX
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe6 {s_debug_uartRx} "UART_RX"

# probe7: CPU LED status
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe7 {s_debug_cpu_led[*]} "CPU_LED"

# probe8: FETCH
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe8 {s_debug_fetch} "FETCH"

# probe9: MR_n (Master Reset)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe9 {s_debug_mr_n} "MR_n"

# probe10: CLEAR_n
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe10 {s_debug_clear_n} "CLEAR_n"

# probe11: REFRQ_n (Refresh Request)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe11 {s_debug_refrq_n} "REFRQ_n"

# probe12: INTRQ_n (Interrupt Request)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe12 {s_debug_intrq_n} "INTRQ_n"

# probe13: POWFAIL_n
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe13 {s_debug_powfail_n} "POWFAIL_n"

# probe14: WCA_12_0 (Write Control Store Address)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe14 {CPU_BOARD/CPU/PROC/CGA/DELILAH/s_wca_12_0[*]} "WCA"

# probe15: CD_15_0 (CPU data bus output)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe15 {CPU_BOARD/s_cpu_cd_15_0_out[*]} "CD"

# probe16: CLOSC (power-on clear oscillator)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe16 {CPU_BOARD/IO/DCD/s_closc} "CLOSC"

# probe17: sys_rst_n
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe17 {CPU_BOARD/sys_rst_n} "SYS_RST_n"

# probe18: regPowerOnClear
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe18 {CPU_BOARD/IO/DCD/regPowerOnClear_reg_0} "PWR_ON_CLR"

# probe19: CLIRQ group
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe19 {CPU_BOARD/CPU/CGA/DELILAH/DCD/s_iclirq_group} "CLIRQ"

# probe20: FIDBO_15_0 (internal data bus, threaded through hierarchy)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe20 {s_debug_fidbo[*]} "FIDBO"

# probe21: PROM regData (microcode ROM output, mark_debug in CPU_CS_PROM_19.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe21 {CPU_BOARD/CPU/CS/PROM/regData[*]} "PROM_DATA"

# probe22: ALU Q register (mark_debug in CGA_ALU.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe22 {CPU_BOARD/CPU/PROC/CGA/DELILAH/ALU/s_q_15_0[*]} "ALU_Q"

# probe23: ALU F result (mark_debug in CGA_ALU.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe23 {CPU_BOARD/CPU/PROC/CGA/DELILAH/ALU/s_f_15_0[*]} "ALU_F"

# probe24: ALU Zero flag (mark_debug in CGA.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe24 {CPU_BOARD/CPU/PROC/CGA/DELILAH/s_zf} "ALU_ZF"

# probe25: ALU Carry (mark_debug in CGA.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe25 {CPU_BOARD/CPU/PROC/CGA/DELILAH/s_cry} "ALU_CRY"

# probe26: MIC condition output (mark_debug in CGA.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe26 {CPU_BOARD/CPU/PROC/CGA/DELILAH/s_cond} "COND"

# probe27: SC5/SC6 mux selector bits [3:2]=SC6/SC5, [1:0]=SC4/SC3 (mark_debug in CGA_MIC.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe27 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/s_sc_6_3_out[*]} "SC_6_3"

# probe28: CSEL latch output s_cond_n (mark_debug in CGA_MIC.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe28 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/s_cond_n} "MIC_COND_N"

# probe29: etrue / efalse (condition routing to SC5/SC6) (mark_debug in CGA_MIC.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe29 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/s_etrue} "ETRUE"
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe30 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/s_efalse} "EFALSE"

# probe31: CSEL latch D-input s_pcond_n (mark_debug in CGA_MIC_CSEL.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe31 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/CSEL/s_pcond_n} "CSEL_D"

# probe32: CSEL latch Q-output s_cond_n_out (mark_debug in CGA_MIC_CSEL.v)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe32 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/CSEL/s_cond_n_out} "CSEL_Q"

# probe33: LUA_12_0 — PROM address upper bits from ACAL (mark_debug in CPU_CS_16.v)
# Should equal CSA_12_0. If it doesn't, ACAL is latching the wrong CSA value via MACLK.
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe33 {CPU_BOARD/CPU/CS/s_LUA_12_0[*]} "LUA"

# probe34: MACLK — controls when ACAL latches CSA into LUA (from CYC_36 via CPU_CS_16)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe34 {CPU_BOARD/CPU/CS/ACAL/s_maclk} "MACLK"

# probe35: ALUCLK — controls CSEL latch enable (mark_debug or hierarchical net)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe35 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/CSEL/s_aluclk} "ALUCLK"

# probe36: sysclk — 100 MHz FPGA system clock, same net as ILA sample clock
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list sysclk_IBUF_BUFG]]

# probe37: LC — link counter (lower 4 bits), used for PANVC dispatch
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe37 {CPU_BOARD/CPU/PROC/CGA/DELILAH/MIC/s_lc_3_0[*]} "LC"

# probe38: CSIDBS_4_0 — microcode IDB source select (which IDB source we expect)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe38 {CPU_BOARD/IO/s_csidbs_4_0[*]} "CSIDBS"

# probe39: IDB_UART — output of IO_UART_42 (gated by EIOR_n / RUART_n)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe39 {CPU_BOARD/IO/s_idb_15_0_uart_out[*]} "IDB_UART"

# probe40: IDB_PANCAL — output of IO_PANCAL_40 (gated by EPANS_n)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe40 {CPU_BOARD/IO/s_idb_15_0_pancal_out[*]} "IDB_PANCAL"

# probe41: IDB_REG — output of IO_REG_41 (gated by RINR_n / TRAALD_n)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe41 {CPU_BOARD/IO/s_idb_15_0_reg_out[*]} "IDB_REG"

# probe42: IDB_DCD — output of IO_DCD_38 panel vector (8 bits, gated by EPAN_n)
create_debug_port u_ila_0 probe
connect_probe u_ila_0/probe42 {CPU_BOARD/IO/s_idb_7_0_dcd_out[*]} "IDB_DCD"

# Connect debug hub clock
set_property C_CLK_INPUT_FREQ_HZ 100000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets sysclk_IBUF_BUFG]

# Save the debug constraints
# NOTE: Do NOT use save_constraints here — it writes ILA definitions into the
# XDC file, which then conflict with this script on the next build.

puts "ILA debug core configured with 43 probes"

# Implementation reads the synth_1 checkpoint from disk. ILA above exists only in
# memory until we overwrite that checkpoint; otherwise impl has no debug cores and
# write_debug_probes does not produce ND120_TOP.ltx (Hardware Manager then errors).
set synth_run_dir [get_property DIRECTORY [get_runs synth_1]]
set main_dcp ""
foreach cand [list \
    [file join $synth_run_dir "${top_module}.dcp"] \
    [file join $synth_run_dir "${top_module}_synth.dcp"] ] {
    if {[file exists $cand]} {
        set main_dcp $cand
        break
    }
}
if {$main_dcp eq ""} {
    foreach dcp [glob -nocomplain [file join $synth_run_dir *.dcp]] {
        if {[string match *_pb.dcp [file tail $dcp]]} { continue }
        set main_dcp $dcp
        break
    }
}
if {$main_dcp eq ""} {
    puts "ERROR: No synthesis .dcp in $synth_run_dir — cannot save ILA for implementation"
    exit 1
}
puts "Saving synthesized design with ILA to checkpoint: $main_dcp"
write_checkpoint -force $main_dcp

# Close synthesized design before implementation
close_design

########################################################################
# IMPLEMENTATION
########################################################################
puts "\n=== IMPLEMENTATION ==="
reset_run impl_1
launch_runs impl_1 -jobs 12
if {[catch {wait_on_run impl_1} err]} {
    puts "WARNING: wait_on_run returned error: $err"
    puts "Checking if implementation completed anyway..."
}

set impl_status [get_property STATUS [get_runs impl_1]]
set impl_progress [get_property PROGRESS [get_runs impl_1]]
puts "Implementation status: $impl_status  progress: $impl_progress"

if {[catch {open_run impl_1} err]} {
    puts "ERROR: Implementation failed - could not open implemented design"
    puts "  Status: $impl_status"
    puts "  Error: $err"
    exit 1
}
puts "Implemented design opened successfully"

# Apply combinational loop constraints
catch {set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -quiet -filter {NAME =~ *CPU_BOARD*}]}

# Reports
report_timing_summary -file "${output_dir}/timing_impl.rpt"
report_utilization -file "${output_dir}/utilization_impl.rpt"
report_drc -file "${output_dir}/drc.rpt"
puts "Reports written to ${output_dir}/"

close_design

########################################################################
# BITSTREAM
########################################################################
puts "\n=== BITSTREAM ==="
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1

# Hardware Manager expects .ltx next to the bitstream for ILA auto-connect.
# write_bitstream does not emit this file; write_debug_probes does.
set impl_run_dir [get_property DIRECTORY [get_runs impl_1]]
set ltx_run [file join $impl_run_dir "${top_module}.ltx"]
open_run impl_1
if {[catch {write_debug_probes -force $ltx_run} dbg_err]} {
    puts "ERROR: write_debug_probes failed (no ILA in implemented design?): $dbg_err"
    close_design
    exit 1
}
close_design
if {![file exists $ltx_run]} {
    puts "ERROR: Debug probes file was not created: $ltx_run"
    exit 1
}
file copy -force $ltx_run "${output_dir}/${top_module}.ltx"
puts "Debug probes file: $ltx_run"
puts "  (copy) ${output_dir}/${top_module}.ltx — use this .ltx with ${output_dir}/${top_module}.bit in Hardware Manager if needed"

# Check for bitstream
set bit_file [file join $impl_run_dir "${top_module}.bit"]
if {[file exists $bit_file]} {
    file copy -force $bit_file "${output_dir}/${top_module}.bit"
    puts "\nSUCCESS: Bitstream generated!"
    puts "Output: ${output_dir}/${top_module}.bit"
} else {
    puts "\nERROR: Bitstream not generated. Check DRC report."
    puts "DRC report: ${output_dir}/drc.rpt"
    exit 1
}

########################################################################
# PROGRAM FPGA AND FLASH
########################################################################
# Skip programming if -tclargs skip_program was passed
if {[lsearch $argv "skip_program"] >= 0} {
    puts "\n=== SKIPPING PROGRAMMING (skip_program flag) ==="
    puts "\n=== BUILD COMPLETE ==="
    close_project
    exit 0
}

puts "\n=== PROGRAMMING FPGA ==="

# Open hardware manager
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

# Get the FPGA device
set hw_device [get_hw_devices xc7a35t_0]
current_hw_device $hw_device
set_property PROGRAM.FILE "${output_dir}/${top_module}.bit" $hw_device

# Program FPGA via JTAG (volatile - immediate test)
program_hw_devices $hw_device
puts "FPGA programmed via JTAG"

# Generate flash image and program SPI flash (non-volatile - survives power cycle)
puts "\n=== PROGRAMMING SPI FLASH ==="
set mcs_file "${output_dir}/${top_module}.mcs"
write_cfgmem -force -format mcs -interface SPIx4 -size 4 \
    -loadbit "up 0x0 ${output_dir}/${top_module}.bit" $mcs_file

# Create cfgmem object for the Basys3 flash (S25FL032P)
create_hw_cfgmem -hw_device $hw_device [lindex [get_cfgmem_parts {s25fl032p-spi-x1_x2_x4}] 0]
set hw_cfgmem [get_property PROGRAM.HW_CFGMEM $hw_device]
set_property PROGRAM.ADDRESS_RANGE  {use_file} $hw_cfgmem
set_property PROGRAM.FILES          [list $mcs_file] $hw_cfgmem
set_property PROGRAM.PRM_FILE       {} $hw_cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $hw_cfgmem
set_property PROGRAM.BLANK_CHECK    0 $hw_cfgmem
set_property PROGRAM.ERASE          1 $hw_cfgmem
set_property PROGRAM.CFG_PROGRAM    1 $hw_cfgmem
set_property PROGRAM.VERIFY         1 $hw_cfgmem
set_property PROGRAM.CHECKSUM       0 $hw_cfgmem

# CRITICAL: Generate the indirect-programming bitstream and load it into the FPGA.
# The FPGA must be programmed with a special SPI-proxy bitstream so that Vivado
# can communicate with the flash chip via JTAG-to-SPI bridging.  Without this,
# program_hw_cfgmem fails with "Failure to set flash parameters" (Labtools 27-3347).
create_hw_bitstream -hw_device $hw_device [get_property PROGRAM.HW_CFGMEM_BITFILE $hw_device]
program_hw_devices $hw_device

program_hw_cfgmem -hw_cfgmem $hw_cfgmem
puts "SPI flash programmed"

# Reboot FPGA from flash to verify
boot_hw_device [current_hw_device]
puts "FPGA rebooted from flash - bitstream will persist after power cycle"

close_hw_target
disconnect_hw_server
close_hw_manager

puts "\n=== BUILD COMPLETE ==="
close_project
exit 0
