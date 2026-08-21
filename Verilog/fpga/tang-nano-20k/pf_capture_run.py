#!/usr/bin/env python3
"""
pf_capture_run.py - boot the Tang to the ERRFATAL halt and collect the
                    page-fault freeze readout.

Full path:
  /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/pf_capture_run.py

WHAT IT DOES
  1. Opens the console (/dev/ttyUSB1, 9600 8N1).
  2. Sends the Winchester mass load '20500&', one character at a time with a
     gap - this console DROPS characters if a string is written at once.
  3. Logs everything with timestamps until either
       - 'ERRFATAL' appears (the halt we are chasing), or
       - the dumper seizes the TX pin and starts streaming hex records, or
       - the deadline expires.
  4. Decodes the freeze readout out of the dumped ring and PRINTS THE FIELDS.

WHAT THE ANSWER LOOKS LIKE
  The frozen word is 78 bits, emitted as six 13-bit slices with a 3-bit slice
  index in the top bits of each 16-bit sample (slice = readout[15:13]):

    frozen[ 6: 0] PT_15_9 AT the faulting edge   [6]=WPM [5]=RPM [4]=FPM
    frozen[    7] VACC
    frozen[21: 8] LA_23_10      -> page table = LA[19:16], page = LA[15:10]
    frozen[25:22] TVEC
    frozen[   26] PVIOL         [27] RESTR
    frozen[   28] ptram CS_n    [29] ptram OE_n  (MEANINGLESS unless bit 31 = 1)
    frozen[   30] captured
    frozen[   31] ptram strobes valid
    frozen[55:32] cycle counter
    frozen[63:57] PT one capturing edge BEFORE the fault
    frozen[70:64] PT one capturing edge AFTER  the fault
    frozen[   71] that later sample was actually taken

  THE DECISION THIS SETTLES, with no inference:
    PT grants permission (any of WPM/RPM/FPM)   -> the trap did NOT come from
                                                   PGF; both hypotheses dead
    PT zero at the edge, GRANTING one edge later -> the entry ARRIVED LATE and
                                                   the trap read an idle bus:
                                                   SPURIOUS
    PT zero at the edge and still zero after     -> the entry really is
                                                   unmapped: REAL

  The before/after samples replaced routing the page-table RAM strobes up
  through four levels of hierarchy. Without them the most likely outcome -
  PT all zero with VACC high - was NOT DECIDABLE.

USAGE
    python3 pf_capture_run.py [--port /dev/ttyUSB1] [--minutes 45]
    python3 pf_capture_run.py --decode-file <log>   # decode an existing log

21-AUG-2026  Ronny Hansen
"""

import argparse
import re
import sys
import time

BOOT_CMD = "20500&"
CHAR_GAP = 0.30  # this console drops characters without a gap


def extract_samples(text):
    """The ring dumper prints each 20-bit record as FIVE hex digits, one per
    line. s_cap_src = {4'd0, readout[15:0]}, so the low 16 bits are ours.
    Parsing 4-digit tokens finds nothing at all - measured 21-AUG-2026."""
    out = []
    for h in re.findall(r"(?m)^\s*([0-9a-fA-F]{4,5})\s*$", text):
        out.append(int(h, 16) & 0xFFFF)
    return out


def stale_slice_check(samples):
    """Refuse a word whose slice 0 is a PRE-capture leftover.

    The readout holds slice 0 until a fault is frozen, so the ring fills with
    hundreds of identical slice-0 records BEFORE the capture. If the dump ends
    before the rotation wraps back to 0, the only slice-0 present is that stale
    one - and slice 0 carries c_pt and c_vacc. Measured 21-AUG-2026: 501 copies
    of slice 0 = 0x0000 at indices 0..500, then slices 1..5 once each, and the
    reconstructed word claimed PVIOL=1 with VACC=0, which is impossible.

    A trustworthy dump has a slice-0 record AFTER the first slice-1 record.
    """
    first = {}
    last = {}
    for i, v in enumerate(samples):
        idx = (v >> 13) & 0x7
        if idx > 5:
            continue
        first.setdefault(idx, i)
        last[idx] = i
    if 0 not in last or 1 not in first:
        return "slices 0 and 1 were not both present"
    if last[0] < first[1]:
        return ("slice 0 appears ONLY before slice 1 (last slice-0 at index %d, "
                "first slice-1 at index %d) - it is a PRE-CAPTURE leftover, so "
                "c_pt and c_vacc were never measured" % (last[0], first[1]))
    return None


def decode_slices(samples):
    """samples: list of 16-bit ints. Returns (frozen, seen_mask) or (None, mask)."""
    frozen = 0
    seen = 0
    for v in samples:
        idx = (v >> 13) & 0x7
        if idx > 7:
            continue                      # not one of ours
        payload = v & 0x1FFF
        frozen &= ~(0x1FFF << (13 * idx)) & ((1 << 104) - 1)
        frozen |= payload << (13 * idx)
        seen |= 1 << idx
    return (frozen if seen == 0xFF else None), seen


SW_XOR = 0o1400   # raw RAM index -> software table number (see below)


def sw_pnumb(raw):
    """The RAM index's top two table bits are COMPLEMENTED in hardware and the
    microcode un-inverts them (TRA PGS XORs 0o1400). Software - and therefore
    SINTRAN's WNDN5 comparison - sees this value, not the raw one."""
    return raw ^ SW_XOR


def fmt_pnumb(raw):
    sw = sw_pnumb(raw & 0x3FF)
    return ("raw %06o -> software %06o (page table %o, page %o)"
            % (raw, sw, (sw >> 6) & 0xF, sw & 0x3F))


def report(frozen):
    pt = frozen & 0x7F
    vacc = (frozen >> 7) & 1
    la = (frozen >> 8) & 0x3FFF
    tvec = (frozen >> 22) & 0xF
    pviol = (frozen >> 26) & 1
    restr = (frozen >> 27) & 1
    cs_n = (frozen >> 28) & 1
    oe_n = (frozen >> 29) & 1
    captured = (frozen >> 30) & 1
    strobes_ok = (frozen >> 31) & 1
    pgs_at_read = (frozen >> 32) & 0x3FFF
    pgs_valid = (frozen >> 46) & 1
    pt_prev = (frozen >> 57) & 0x7F
    pt_next = (frozen >> 64) & 0x7F
    next_valid = (frozen >> 71) & 1
    n_faults = (frozen >> 78) & 0xFF
    last_la = (frozen >> 86) & 0x3FFF
    armed = (frozen >> 100) & 1
    census_ready = (frozen >> 101) & 1

    print("")
    print("=" * 62)
    print(" PAGE-FAULT FREEZE READOUT")
    print("=" * 62)
    if not captured:
        print(" captured = 0  -> no fault at the TARGETED page was frozen.")
        print(" The freeze fields below are meaningless; the CENSUS is not.")
        print("")
        print(" CENSUS (independent of the targeted freeze)")
        print("   armed=%d  census_ready=%d" % (armed, census_ready))
        print("   page-fault vector transitions since arming : %d%s"
              % (n_faults, "  (SATURATED)" if n_faults == 0xFF else ""))
        print("   LA of the most recent one                  : %s" % fmt_pnumb(last_la))
        print("")
        if not armed:
            print(" VERDICT: NOT ARMED - the capture was still inside its arm window,")
            print(" so n_faults says NOTHING. This run is inconclusive.")
        elif n_faults == 0:
            print(" VERDICT: ARMED, and the trap logic latched NO page fault at all,")
            print(" yet SINTRAN halted in ERRFATAL reporting IIC 3. The halt does not")
            print(" come from a page-fault vector raised in this window.")
        else:
            print(" VERDICT: %d page fault(s) occurred, but NONE at the targeted page" % n_faults)
            print(" 0o760 (page table 7, page 60 - the ND-500 window). SINTRAN's")
            print(" ERRFATAL branch fires only when the page it reads equals that, so")
            print(" the value it reads is NOT the address that faulted.")
        return
    print(" captured   : 1")
    print(" PGS the handler would read : %s"
          % ("%06o  -> page table %o, page %o"
             % (pgs_at_read, (pgs_at_read >> 6) & 0xF, pgs_at_read & 0x3F)
             if pgs_valid else "(no EPGS read seen yet)"))
    print("")
    print(" PT_15_9    : %s   WPM=%d RPM=%d FPM=%d"
          % (format(pt, "07b"), (pt >> 6) & 1, (pt >> 5) & 1, (pt >> 4) & 1))
    print(" VACC       : %d" % vacc)
    print(" LA_23_10   : %s" % fmt_pnumb(la))
    print(" TVEC       : %d      PVIOL=%d  RESTR=%d" % (tvec, pviol, restr))
    print(" PT one edge BEFORE : %s" % format(pt_prev, "07b"))
    print(" PT one edge AFTER  : %s%s"
          % (format(pt_next, "07b"),
             "" if next_valid else "   (NOT TAKEN - no later edge occurred)"))
    if strobes_ok:
        print(" ptram      : CS_n=%d OE_n=%d  (driving = CS_n 0 and OE_n 0)"
              % (cs_n, oe_n))
    else:
        print(" ptram      : NOT ROUTED - CS_n/OE_n carry NO INFORMATION")
    print("")
    print("")
    print(" CENSUS (not frozen - counts every page fault, any address)")
    print("   page-fault vector transitions since arming : %d%s"
          % (n_faults, "  (SATURATED)" if n_faults == 0xFF else ""))
    print("   LA of the most recent one                  : %s" % fmt_pnumb(last_la))
    if n_faults and not captured:
        print("   -> faults DID occur, but none at the targeted page. The address")
        print("      SINTRAN reports is therefore NOT the address that faulted.")
    elif n_faults == 0:
        print("   -> the trap logic latched NO page fault at all since arming.")
    print("")
    if pgs_valid:
        print("")
        print(" PHASE 4b - PGS OVERWRITE TEST")
        if pgs_at_read != la:
            print("   faulting LA          : %06o  -> table %o, page %o"
                  % (la, (la >> 6) & 0xF, la & 0x3F))
            print("   PGS at the EPGS read : %06o  -> table %o, page %o"
                  % (pgs_at_read, (pgs_at_read >> 6) & 0xF, pgs_at_read & 0x3F))
            print("   *** THEY DIFFER - PGS WAS OVERWRITTEN between the fault and")
            print("       the handler reading it. SINTRAN acts on the wrong address. ***")
        else:
            print("   PGS at the read MATCHES the faulting LA (%06o)." % la)
            print("   -> no overwrite. The handler saw the true faulting address,")
            print("      so the overwrite hypothesis is DEAD.")
    print("")
    print(" VERDICT")
    grants = (pt >> 4) & 0x7
    if grants:
        print("   PT GRANTS permission (one of WPM/RPM/FPM set).")
        print("   -> PGF cannot have been the cause. Something else raised the")
        print("      trap. Both current hypotheses are DEAD.")
    elif vacc == 0:
        print("   PT all zero and VACC was LOW at the capturing edge.")
        print("   -> no translated access was even in progress. The vector was")
        print("      latched without a memory reference behind it.")
    else:
        print("   PT all zero with VACC high.")
        if not next_valid:
            print("   -> the following edge was never taken, so late arrival")
            print("      cannot be ruled in or out. NOT DECIDABLE.")
        elif (pt_next >> 4) & 0x7:
            print("   -> PT was ZERO at the faulting edge and GRANTS PERMISSION")
            print("      one edge later. The page-table entry ARRIVED LATE and")
            print("      the trap decoded an idle bus.")
            print("   *** SPURIOUS PAGE FAULT. ***")
        else:
            print("   -> PT is still all zero one edge later, so this is not a")
            print("      late arrival. The entry really is unmapped.")
            print("   *** REAL PAGE FAULT. *** The MMU is reporting correctly;")
            print("       the question moves to why that page is not mapped.")
    print("=" * 62)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB1")
    ap.add_argument("--baud", type=int, default=9600)
    ap.add_argument("--minutes", type=float, default=45.0)
    ap.add_argument("--log", default="pf_capture_run.log")
    ap.add_argument("--decode-file")
    args = ap.parse_args()

    if args.decode_file:
        text = open(args.decode_file, "r", errors="replace").read()
        samples = extract_samples(text)
        stale = stale_slice_check(samples)
        if stale:
            print("REFUSING TO DECODE: %s" % stale)
            print("The dump must contain a COMPLETE post-capture rotation.")
            return 1
        frozen, seen = decode_slices(samples)
        if frozen is None:
            print("Only slices %s of 0..7 were present - cannot rebuild the word."
                  % format(seen, "08b"))
            print("(samples parsed: %d)" % len(samples))
            return 1
        report(frozen)
        return 0

    import serial  # imported here so --decode-file works without pyserial

    s = serial.Serial(args.port, args.baud, timeout=0.5)
    log = open(args.log, "w", buffering=1)

    def emit(line):
        stamp = time.strftime("%H:%M:%S")
        print("%s %s" % (stamp, line), flush=True)
        log.write("%s %s\n" % (stamp, line))

    emit("port %s @ %d, deadline %.0f min" % (args.port, args.baud, args.minutes))

    time.sleep(1.0)
    s.reset_input_buffer()
    emit("sending %r one character at a time (%.2fs gap)" % (BOOT_CMD, CHAR_GAP))
    for ch in BOOT_CMD:
        s.write(ch.encode())
        s.flush()
        time.sleep(CHAR_GAP)
    s.write(b"\r")
    s.flush()

    deadline = time.time() + args.minutes * 60
    buf = ""
    raw = []
    saw_errfatal = False
    # A reflash re-enumerates the FTDI, and any USB hiccup raises
    # SerialException("device reports readiness to read but returned no data").
    # A 45-minute run must not die on that - reopen and carry on.
    reopens = 0
    while time.time() < deadline:
        try:
            chunk = s.read(256)
        except Exception as exc:                      # noqa: BLE001
            reopens += 1
            emit("serial error (%s) - reopening, attempt %d" % (exc.__class__.__name__, reopens))
            try:
                s.close()
            except Exception:
                pass
            time.sleep(2.0)
            try:
                s = serial.Serial(args.port, args.baud, timeout=0.5)
            except Exception as exc2:                 # noqa: BLE001
                emit("reopen failed: %s" % exc2)
                time.sleep(3.0)
            continue
        if not chunk:
            continue
        text = chunk.decode("latin-1", errors="replace")
        raw.append(text)
        log.write(text)
        buf += text
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            line = line.rstrip("\r")
            if line.strip():
                print(time.strftime("%H:%M:%S") + " | " + line, flush=True)
            if "ERRFATAL" in line:
                saw_errfatal = True
                emit(">>> ERRFATAL seen - the dumper should take the TX pin next")

    s.close()
    emit("collection finished (errfatal_seen=%s)" % saw_errfatal)

    all_text = "".join(raw)
    samples = extract_samples(all_text)
    stale = stale_slice_check(samples)
    if stale:
        emit("REFUSING TO DECODE: %s" % stale)
        emit("The dump must contain a COMPLETE post-capture rotation.")
        return 1
    emit("hex samples collected: %d" % len(samples))
    frozen, seen = decode_slices(samples)
    if frozen is None:
        emit("slices seen: %s of 0..3 - the word could not be rebuilt" % format(seen, "04b"))
        emit("log kept at %s - rerun with --decode-file to retry the decode" % args.log)
        return 1
    report(frozen)
    return 0


if __name__ == "__main__":
    sys.exit(main())
