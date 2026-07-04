# XDC constraints to tie unused input signals for xc7a35tcpg236
# Use this in addition to constraints_minimal_cpg236.xdc

## Tie unused input signals to safe values
## This prevents them from floating and consuming pins

# Tie bus input to all 1's (pulled high - inactive state)
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets BD_23_0_n_IN*]

# If BD_23_0_n_IN is input-only in your design, you can set it as constant
# Uncomment if needed:
# set_case_analysis 1 [get_ports BD_23_0_n_IN[*]]

# Tie unused interrupt inputs high (inactive)
# Uncomment the ones you don't physically connect:
# set_case_analysis 1 [get_ports BINT10_n]
# set_case_analysis 1 [get_ports BINT11_n]
# set_case_analysis 1 [get_ports BINT12_n]
# set_case_analysis 1 [get_ports BINT13_n]
# set_case_analysis 1 [get_ports BINT15_n]

# Tie other unused inputs
# set_case_analysis 1 [get_ports BREQ_n]
# set_case_analysis 1 [get_ports POWSENSE_n]
# set_case_analysis 0 [get_ports DEBUGFLAG]

## For OUTPUT signals like CSA_12_0 and BD_23_0_n_OUT:
## - They won't consume pins if not mapped
## - Synthesis will optimize them away if truly unused
## - Use Mark Debug attribute to probe with ILA instead

# Example: Mark signals for ILA debugging (doesn't use physical pins)
# set_property MARK_DEBUG true [get_nets {CSA_12_0[*]}]
# set_property MARK_DEBUG true [get_nets {BD_23_0_n_OUT[*]}]
