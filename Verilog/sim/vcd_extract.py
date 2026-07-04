#!/usr/bin/env python3
"""
Fast VCD signal extractor for ND-120 simulation analysis.

Usage:
    # Extract specific signals to CSV
    python3 vcd_extract.py waveform.fst -s "MCLK" "MA_12_0" "P_REG_2"

    # Extract signals matching patterns (substring match)
    python3 vcd_extract.py waveform.fst -p "CYC.*CLK" "WRF.*REG"

    # Extract signals from .gtkw file
    python3 vcd_extract.py waveform.fst --gtkw top_3202d.gtkw

    # Limit time range (in ps)
    python3 vcd_extract.py waveform.fst -s "MCLK" --tstart 2000 --tend 5000

    # Output as JSON for programmatic use
    python3 vcd_extract.py waveform.fst -s "MCLK" --json

    # List all available signals
    python3 vcd_extract.py waveform.fst --list

    # Dump a human-readable table
    python3 vcd_extract.py waveform.fst -s "MCLK" "CLK" --table

    # Use --shortest to pick the shortest-path alias for each signal ID
    python3 vcd_extract.py waveform.fst -s "MCLK" --shortest --table
"""

import sys
import re
import json
import csv
import argparse
from fst import open_wave
from collections import defaultdict


def parse_gtkw_signals(gtkw_path):
    """Extract signal names from a .gtkw file."""
    signals = []
    with open(gtkw_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('TOP.'):
                sig = re.sub(r'\[.*\]$', '', line)
                if sig not in signals:
                    signals.append(sig)
            elif re.match(r'^\(\d+\)TOP\.', line):
                continue
    return signals


def parse_vcd_header(vcd_path):
    """Fast header-only parse.

    Returns:
        signals: {short_id: [(full_name, width), ...]}
            Each ID can have multiple aliases (Verilator reuses IDs for connected wires).
    """
    signals = defaultdict(list)
    scope_stack = []

    with open_wave(vcd_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('$scope'):
                parts = line.split()
                if len(parts) >= 3:
                    scope_stack.append(parts[2])
            elif line.startswith('$upscope'):
                if scope_stack:
                    scope_stack.pop()
            elif line.startswith('$var'):
                parts = line.split()
                if len(parts) >= 5:
                    width = int(parts[2])
                    short_id = parts[3]
                    name = parts[4]
                    full_name = '.'.join(scope_stack + [name])
                    signals[short_id].append((full_name, width))
            elif line.startswith('$enddefinitions'):
                break

    return dict(signals)


def find_matching_signals(all_signals, patterns=None, exact_names=None, substring_match=None, prefer_shortest=False):
    """Find signal IDs matching given criteria.

    Args:
        all_signals: {short_id: [(full_name, width), ...]}
        patterns: list of regex patterns
        exact_names: list of exact full signal names
        substring_match: list of substrings to match
        prefer_shortest: if True, for each matched ID pick shortest name

    Returns: {short_id: (chosen_name, width)} for matching signals
    """
    matched = {}

    for sid, aliases in all_signals.items():
        best_match = None

        for (name, width) in aliases:
            hit = False

            if exact_names:
                base_name = re.sub(r'\[\d+:\d+\]$', '', name)
                for en in exact_names:
                    en_base = re.sub(r'\[\d+:\d+\]$', '', en)
                    if base_name == en_base or name == en:
                        hit = True
                        break

            if not hit and patterns:
                for pat in patterns:
                    if re.search(pat, name):
                        hit = True
                        break

            if not hit and substring_match:
                for sub in substring_match:
                    if sub.lower() in name.lower():
                        hit = True
                        break

            if hit:
                if best_match is None:
                    best_match = (name, width)
                elif prefer_shortest and len(name) < len(best_match[0]):
                    best_match = (name, width)
                elif not prefer_shortest:
                    # Prefer the matching name (first match wins)
                    best_match = (name, width)

        if best_match:
            matched[sid] = best_match

    return matched


def flatten_signals(all_signals):
    """Flatten {id: [(name, width), ...]} to {id: (name, width)} using shortest name."""
    flat = {}
    for sid, aliases in all_signals.items():
        shortest = min(aliases, key=lambda x: len(x[0]))
        flat[sid] = shortest
    return flat


def extract_signals(vcd_path, target_ids, tstart=None, tend=None):
    """Stream through VCD data section extracting only target signal changes.

    Returns: {full_name: [(time, value), ...]}
    """
    results = defaultdict(list)
    current_time = 0
    in_data = False

    id_to_name = {sid: name for sid, (name, _) in target_ids.items()}

    with open_wave(vcd_path) as f:
        for line in f:
            if not in_data:
                if line.startswith('$enddefinitions'):
                    in_data = True
                continue

            line = line.rstrip('\n')
            if not line:
                continue

            if line[0] == '#':
                current_time = int(line[1:])
                if tend is not None and current_time > tend:
                    break
                continue

            if tstart is not None and current_time < tstart:
                continue

            if line[0] in '01xXzZ':
                value = line[0]
                sid = line[1:]
                if sid in id_to_name:
                    results[id_to_name[sid]].append((current_time, value))

            elif line[0] in 'bBrR':
                parts = line.split()
                if len(parts) == 2:
                    value = parts[0][1:]
                    sid = parts[1]
                    if sid in id_to_name:
                        results[id_to_name[sid]].append((current_time, value))

    return dict(results)


def format_value(value, width):
    """Format a VCD value for display."""
    if value in ('x', 'X', 'z', 'Z'):
        return value
    if width == 1:
        return value
    try:
        if any(c in value for c in 'xXzZ'):
            return f"0b{value}"
        int_val = int(value, 2)
        hex_width = (width + 3) // 4
        return f"0x{int_val:0{hex_width}x}"
    except ValueError:
        return value


def format_value_dec(value, width):
    """Format a VCD value as decimal."""
    if value in ('x', 'X', 'z', 'Z'):
        return value
    if width == 1:
        return value
    try:
        if any(c in value for c in 'xXzZ'):
            return f"0b{value}"
        return str(int(value, 2))
    except ValueError:
        return value


def ps_to_tick(t_ps):
    """Convert time in ps to clockTick number. clockTicks increments every 10ps."""
    return t_ps // 10 + 1


def format_time(t_ps, show_ticks=False):
    """Format time, optionally with clockTick."""
    if show_ticks:
        return f"t={t_ps:>12}ps tick={ps_to_tick(t_ps):>10}"
    return f"t={t_ps:>12}"


def output_table(results, target_ids, max_changes=30, show_ticks=False):
    """Print a human-readable table of signal changes."""
    id_to_info = {name: width for _, (name, width) in target_ids.items()}

    for name in sorted(results.keys()):
        changes = results[name]
        width = id_to_info.get(name, 1)
        print(f"\n=== {name} (width={width}) ===")
        print(f"  Total transitions: {len(changes)}")
        if changes:
            t0, t1 = changes[0][0], changes[-1][0]
            if show_ticks:
                print(f"  Time range: {t0}ps (tick {ps_to_tick(t0)}) - {t1}ps (tick {ps_to_tick(t1)})")
            else:
                print(f"  Time range: {t0} - {t1} ps")
            print(f"  First {min(max_changes, len(changes))} changes:")
            for t, v in changes[:max_changes]:
                print(f"    {format_time(t, show_ticks)} : {format_value(v, width)}")
            if len(changes) > max_changes:
                print(f"    ... ({len(changes) - max_changes} more)")


def output_csv(results, target_ids, outfile=None, show_ticks=False):
    """Output signal data as CSV."""
    all_times = set()
    for changes in results.values():
        for t, _ in changes:
            all_times.add(t)
    all_times = sorted(all_times)

    current = {name: 'x' for name in results}
    time_idx = {name: 0 for name in results}

    f = open(outfile, 'w', newline='') if outfile else sys.stdout
    writer = csv.writer(f)

    names = sorted(results.keys())
    short_names = [n.split('.')[-1] for n in names]
    header = ['time_ps', 'tick'] + short_names if show_ticks else ['time_ps'] + short_names
    writer.writerow(header)

    id_to_info = {name: width for _, (name, width) in target_ids.items()}

    for t in all_times:
        for name in names:
            changes = results[name]
            idx = time_idx[name]
            while idx < len(changes) and changes[idx][0] <= t:
                current[name] = changes[idx][1]
                idx += 1
            time_idx[name] = idx

        row = [t, ps_to_tick(t)] + [format_value(current[name], id_to_info.get(name, 1)) for name in names] if show_ticks else [t] + [format_value(current[name], id_to_info.get(name, 1)) for name in names]
        writer.writerow(row)

    if outfile:
        f.close()


def output_json(results, target_ids, show_ticks=False):
    """Output signal data as JSON."""
    id_to_info = {name: width for _, (name, width) in target_ids.items()}
    output = {}
    for name, changes in results.items():
        width = id_to_info.get(name, 1)
        if show_ticks:
            change_list = [
                {'time': t, 'tick': ps_to_tick(t), 'value': format_value(v, width)}
                for t, v in changes
            ]
        else:
            change_list = [
                {'time': t, 'value': format_value(v, width)}
                for t, v in changes
            ]
        output[name] = {
            'width': width,
            'transitions': len(changes),
            'changes': change_list
        }
    print(json.dumps(output, indent=2))


def output_summary(results, target_ids, show_ticks=False):
    """Quick summary of extracted signals."""
    id_to_info = {name: width for _, (name, width) in target_ids.items()}
    print(f"\nExtracted {len(results)} signals:\n")
    if show_ticks:
        print(f"{'Signal':<60} {'Width':>5} {'Changes':>10} {'First(ps)':>12} {'Tick':>10} {'Last(ps)':>12} {'Tick':>10}")
        print('-' * 125)
        for name in sorted(results.keys()):
            changes = results[name]
            width = id_to_info.get(name, 1)
            first_t = changes[0][0] if changes else 0
            last_t = changes[-1][0] if changes else 0
            ft_str = str(first_t) if changes else '-'
            lt_str = str(last_t) if changes else '-'
            ftk = str(ps_to_tick(first_t)) if changes else '-'
            ltk = str(ps_to_tick(last_t)) if changes else '-'
            print(f"{name:<60} {width:>5} {len(changes):>10} {ft_str:>12} {ftk:>10} {lt_str:>12} {ltk:>10}")
    else:
        print(f"{'Signal':<70} {'Width':>5} {'Changes':>10} {'First':>12} {'Last':>12}")
        print('-' * 115)
        for name in sorted(results.keys()):
            changes = results[name]
            width = id_to_info.get(name, 1)
            first_t = changes[0][0] if changes else '-'
            last_t = changes[-1][0] if changes else '-'
            print(f"{name:<70} {width:>5} {len(changes):>10} {str(first_t):>12} {str(last_t):>12}")


def main():
    parser = argparse.ArgumentParser(description='Fast VCD signal extractor for ND-120')
    parser.add_argument('vcd', help='Path to VCD file')
    parser.add_argument('-s', '--signals', nargs='+', help='Signal name substrings to match')
    parser.add_argument('-p', '--patterns', nargs='+', help='Regex patterns to match signal names')
    parser.add_argument('-e', '--exact', nargs='+', help='Exact signal full names')
    parser.add_argument('--gtkw', help='Extract signals listed in .gtkw file')
    parser.add_argument('--tstart', type=int, help='Start time in ps')
    parser.add_argument('--tend', type=int, help='End time in ps')
    parser.add_argument('--list', action='store_true', help='List all signals and exit')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    parser.add_argument('--csv', nargs='?', const='-', help='Output as CSV (optionally to file)')
    parser.add_argument('--table', action='store_true', help='Output as human-readable table')
    parser.add_argument('--summary', action='store_true', help='Output summary only (default)')
    parser.add_argument('--shortest', action='store_true', help='Prefer shortest signal name for aliases')
    parser.add_argument('--max-changes', type=int, default=30, help='Max changes to show in table mode')
    parser.add_argument('--ticks', action='store_true', help='Show clockTick alongside time_ps (tick = time_ps/10 + 1)')

    args = parser.parse_args()

    print(f"Parsing VCD header from {args.vcd}...", file=sys.stderr)
    all_signals = parse_vcd_header(args.vcd)
    total_names = sum(len(v) for v in all_signals.values())
    print(f"Found {len(all_signals)} unique signal IDs ({total_names} names including aliases).", file=sys.stderr)

    if args.list:
        for sid, aliases in sorted(all_signals.items(), key=lambda x: x[1][0][0]):
            for (name, width) in aliases:
                print(f"  [{width:>3}] {name}")
        return

    exact_names = None
    if args.gtkw:
        exact_names = parse_gtkw_signals(args.gtkw)
        print(f"Found {len(exact_names)} signals in .gtkw file.", file=sys.stderr)

    if args.exact:
        exact_names = (exact_names or []) + args.exact

    target_ids = find_matching_signals(
        all_signals,
        patterns=args.patterns,
        exact_names=exact_names,
        substring_match=args.signals,
        prefer_shortest=args.shortest,
    )

    if not target_ids:
        print("No matching signals found!", file=sys.stderr)
        sys.exit(1)

    print(f"Extracting {len(target_ids)} signals...", file=sys.stderr)

    results = extract_signals(args.vcd, target_ids, args.tstart, args.tend)
    print(f"Done. Got data for {len(results)} signals.", file=sys.stderr)

    if args.json:
        output_json(results, target_ids, show_ticks=args.ticks)
    elif args.csv:
        outfile = None if args.csv == '-' else args.csv
        output_csv(results, target_ids, outfile, show_ticks=args.ticks)
    elif args.table:
        output_table(results, target_ids, args.max_changes, show_ticks=args.ticks)
    else:
        output_summary(results, target_ids, show_ticks=args.ticks)


if __name__ == '__main__':
    main()
