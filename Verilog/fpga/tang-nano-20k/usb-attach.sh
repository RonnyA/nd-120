#!/bin/bash
###############################################################################
# usb-attach.sh - bring the Tang Nano 20K USB device into WSL as serial ports
#
# Does the whole dance in one shot:
#   1. finds the Tang's FTDI (0403:6010) busid on the Windows host via usbipd
#      (the device must already be "Shared" once: usbipd bind --busid <id>,
#      done from an elevated Windows prompt - that part is one-time)
#   2. attaches it to WSL
#   3. opens the raw USB node permissions (needed by openFPGALoader/JTAG)
#   4. loads the ftdi_sio serial driver and opens /dev/ttyUSB* permissions
#
# Result: /dev/ttyUSB0 = JTAG side (interface A), /dev/ttyUSB1 = console
# (interface B, OPCOM at 9600 8N1).
#
# Usage: ./usb-attach.sh          (or: make usb)
###############################################################################
set -u

VIDPID="0403:6010"

# --- 1. locate the shared Tang FTDI on the Windows host ---------------------
LIST=$(powershell.exe -Command "usbipd list" 2>/dev/null | tr -d '\r')
# TWO BOARDS ON THIS MACHINE SHARE 0403:6010 - the Tang Nano 20K and the
# Nexys 4 DDR. Taking the first match picks whichever sorts first, and on
# 21-AUG-2026 that was the NEXYS: the script announced "Tang FTDI at busid 2-1"
# and tried to detach the Nexys from Windows while Vivado was using it.
#
# Selection order:
#   1. $TANG_BUSID if set          - explicit wins, and keeps a machine-specific
#                                    busid OUT of this repo
#   2. the one already Attached    - only one FTDI can be attached to WSL
#   3. exactly one Shared candidate
#   4. otherwise REFUSE and list them - guessing detaches someone else's board
CANDS=$(echo "$LIST" | awk -v vp="$VIDPID" '$2==vp && /Shared|Attached/ {print $1}')
ATTACHED=$(echo "$LIST" | awk -v vp="$VIDPID" '$2==vp && /Attached/ {print $1}')

if [ -n "${TANG_BUSID:-}" ]; then
    BUSID="${TANG_BUSID:-}"
elif [ "$(echo "$ATTACHED" | grep -c .)" = "1" ]; then
    BUSID="$ATTACHED"
elif [ "$(echo "$CANDS" | grep -c .)" = "1" ]; then
    BUSID="$CANDS"
else
    echo "ERROR: more than one $VIDPID device and none attached - refusing to guess." >&2
    echo "Both the Tang Nano 20K and the Nexys 4 DDR use $VIDPID." >&2
    echo "Set TANG_BUSID to the right one and re-run, e.g.  TANG_BUSID=2-4 $0" >&2
    echo "$LIST" | awk -v vp="$VIDPID" '$2==vp {print "  candidate: " $0}' >&2
    exit 1
fi

if [ -z "$BUSID" ]; then
    echo "ERROR: no shared $VIDPID device found in 'usbipd list'." >&2
    echo "One-time fix (elevated Windows prompt): usbipd bind --busid <busid>" >&2
    echo "$LIST" | sed -n '1,15p' >&2
    exit 1
fi
echo "Tang FTDI $VIDPID at busid $BUSID"

# --- 2. attach to WSL (idempotent: already-attached is fine) ----------------
if echo "$LIST" | awk -v b="$BUSID" '$1==b' | grep -q Attached; then
    echo "already attached to WSL"
else
    powershell.exe -Command "usbipd attach --wsl --busid $BUSID" 2>&1 | tail -2
fi

# --- 3. wait for the device, open raw-USB permissions (JTAG needs this) -----
for i in $(seq 1 20); do
    lsusb -d "$VIDPID" >/dev/null 2>&1 && break
    sleep 0.5
done
if ! lsusb -d "$VIDPID" >/dev/null 2>&1; then
    echo "ERROR: device did not appear in WSL (lsusb)" >&2
    exit 1
fi
DEVPATH=$(lsusb -d "$VIDPID" | sed -n 's/^Bus \([0-9]*\) Device \([0-9]*\).*/\/dev\/bus\/usb\/\1\/\2/p' | head -1)
sudo chmod 666 "$DEVPATH" && echo "raw USB node: $DEVPATH (rw)"

# --- 4. serial driver + tty permissions --------------------------------------
sudo modprobe ftdi_sio
for i in $(seq 1 20); do
    ls /dev/ttyUSB* >/dev/null 2>&1 && break
    sleep 0.5
done
if ls /dev/ttyUSB* >/dev/null 2>&1; then
    sudo chmod 666 /dev/ttyUSB*
    echo "serial ready: $(ls /dev/ttyUSB* | tr '\n' ' ')(ttyUSB1 = console, 9600 8N1)"
else
    echo "ERROR: no /dev/ttyUSB* appeared (ftdi_sio)" >&2
    exit 1
fi
