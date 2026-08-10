###############################################################################
# iverilog.mk - shared include paths for the unit testbench Makefiles
#
# Full path: Verilog/mk/iverilog.mk
#
# WHY THIS EXISTS
#
# Every sim/ Makefile used to spell out its own iverilog include paths, and
# they had drifted into four different shapes across 80 Makefiles. The cost is
# not cosmetic: adding one `include "nd_storage_status.vh"` to the storage
# controllers on 09-AUG-2026 broke SEVEN Makefiles at once, each with the same
# "Include file ... not found" error, and each had to be found and fixed by
# hand. Shared paths mean a new shared header is a one-line change here.
#
# WHAT THIS DELIBERATELY DOES NOT DO
#
# It does NOT set the -g language level. The tree is split 95 recipes on
# -g2012 and 41 on -g2005, and at least three testbenches genuinely need 2012
# syntax (CGA_TRAP_TVGEN_tb.v, nd_storage_cache_tb.v,
# AM29833A_parity_regen_tb.v). Flattening that is a separate change with its
# own before/after `make test`, so that a regression in the 188-entry suite
# stays attributable to one thing at a time.
#
# USAGE
#
#   VERILOG_ROOT = ../..            # however deep this sim/ dir is
#   include $(VERILOG_ROOT)/mk/iverilog.mk
#   ...
#   $(IVERILOG) -g2012 $(ND_INC) -o $@ $^
#
# ND_INC is the shared set. Add directory-specific paths after it:
#
#   $(IVERILOG) -g2005 $(ND_INC) -I../circuit -o $@ $^
#
# Ronny Hansen, 09-AUG-2026
###############################################################################

ifndef VERILOG_ROOT
$(error iverilog.mk: define VERILOG_ROOT (path to Verilog/) before including)
endif

IVERILOG ?= iverilog
VVP      ?= vvp

# Directories holding headers and shared modules that testbenches across the
# tree reach for. Keep this list SHORT - it is a fallback for genuinely shared
# code, not a substitute for naming a module's own dependencies.
ND_INC = -I$(VERILOG_ROOT)/Shared/logisim \
         -I$(VERILOG_ROOT)/Shared/ndlib \
         -I$(VERILOG_ROOT)/Shared/support \
         -I$(VERILOG_ROOT)/PAL \
         -I$(VERILOG_ROOT)/SD-FAT/circuit
