#!/usr/bin/env python3
# Tristate-integrity gate for the SD pad drivers (12-JUL-2026).
#
# Born from a silicon failure: the DAT1-3 pad expression used 1'bz in the
# INNER branch of a nested ternary, an idiom yosys cannot map to an IOBUF.
# It silently collapsed to an always-driving OBUF, the FPGA fought the card
# on DAT1-3 through every 4-bit read data phase, and every 4-bit read
# failed on hardware - while both simulators, which honor z-semantics,
# passed everything. Simulation CANNOT catch this class of bug; only the
# synthesized structure can, so this gate inspects it.
#
# Driven by the Makefile target test-tristate: yosys elaborates the top
# (read_verilog + hierarchy + proc + opt + tribuf + write_json) and this
# script then asserts, for every SD pad that is ever read:
#   1. the port direction is inout (not collapsed to output), and
#   2. every cell driving the pad bit is a $tribuf (a real tristate driver)
# Any always-driving pad or lost direction is a hard FAIL.
#
# Usage: check_tristate.py <yosys_json> <top_module> <port> [<port> ...]

import json
import sys


def main():
    if len(sys.argv) < 4:
        print("usage: check_tristate.py <json> <top> <port> [...]")
        return 2
    with open(sys.argv[1]) as f:
        design = json.load(f)
    top = design["modules"][sys.argv[2]]
    ports = top["ports"]
    errors = 0
    for pname in sys.argv[3:]:
        if pname not in ports:
            print("FAIL: port %s not found in %s" % (pname, sys.argv[2]))
            errors += 1
            continue
        port = ports[pname]
        bits = set(b for b in port["bits"] if isinstance(b, int))
        drivers = []
        for cname, cell in top["cells"].items():
            dirs = cell.get("port_directions", {})
            for cport, cbits in cell["connections"].items():
                if dirs.get(cport) == "output" and any(
                        b in bits for b in cbits if isinstance(b, int)):
                    drivers.append((cname, cell["type"]))
        bad = [d for d in drivers if d[1] != "$tribuf"]
        if port["direction"] != "inout":
            print("FAIL: %s direction is '%s' (tristate collapsed - the pad"
                  " would drive the card continuously)"
                  % (pname, port["direction"]))
            errors += 1
        elif bad:
            print("FAIL: %s driven by non-tristate cell(s): %s"
                  % (pname, ", ".join("%s(%s)" % d for d in bad)))
            errors += 1
        else:
            print("ok:   %s inout, drivers: %s"
                  % (pname, ", ".join(t for _, t in drivers) or "none"))
    if errors:
        print("TB_RESULT: FAIL %d pad(s) lost their tristate" % errors)
        return 1
    print("TB_RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
