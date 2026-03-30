#!/bin/bash

# Script to run all testbenches
# Can be used with iverilog (preferred) or Verilator

echo "========================================"
echo "Vivado Warning Fixes - Test Suite"
echo "========================================"
echo ""

# Check for simulation tools
if command -v iverilog &> /dev/null; then
    echo "Using Icarus Verilog (iverilog)"
    make clean
    make all
elif command -v verilator &> /dev/null; then
    echo "Using Verilator"
    echo "Note: Verilator requires C++ testbenches. Please use iverilog for these Verilog testbenches."
    echo "Or run synthesis tests with Vivado."
    exit 1
else
    echo "ERROR: No Verilog simulator found!"
    echo ""
    echo "Please install one of:"
    echo "  - Icarus Verilog (iverilog): sudo apt-get install iverilog"
    echo "  - Verilator: sudo apt-get install verilator"
    echo ""
    echo "Or run the tests in Vivado simulator."
    exit 1
fi

echo ""
echo "========================================"
echo "Test Suite Complete"
echo "========================================"
