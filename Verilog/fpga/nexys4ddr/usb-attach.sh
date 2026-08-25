#!/bin/bash
###############################################################################
# usb-attach.sh - bring the Nexys 4 DDR USB device into WSL as serial ports
#
# Same dance as the Tang Nano 20K script
# (Verilog/fpga/tang-nano-20k/usb-attach.sh), with ONE critical difference:
#
#   BOTH boards enumerate as 0403:6010. The Tang script picks the first
#   0403:6010 it finds, so running it while the Nexys is plugged in can grab
#   the WRONG board. This script selects by FTDI SERIAL NUMBER instead.
#   Digilent serials start with "210" (Ronny's Nexys 4 DDR: 210292A4BE00B);
#   the Tang's onboard debugger reports a plain numeric serial.
#
# The Nexys FT2232 has two interfaces: A = USB-JTAG, B = USB-UART console.
# Attaching hands the WHOLE device to WSL, so while it is attached the board
# disappears from Windows and Vivado can no longer program it over JTAG.
# Detach (see below) before running a Vivado build that programs the board,
# or read the console from Windows with console.ps1 instead.
#
# One-time, from an ELEVATED Windows prompt:
#     usbipd bind --busid <busid>
#
# Usage:
#     ./usb-attach.sh                 # attach, set permissions, report ports
#     ./usb-attach.sh --detach        # give the board back to Windows
#     SERIAL_PREFIX=2102 ./usb-attach.sh
###############################################################################
set -u

SERIAL_PREFIX="${SERIAL_PREFIX:-210}"   # Digilent FTDI serials
VIDPID="0403:6010"

# --- locate the board on the Windows host, BY SERIAL ------------------------
# 'usbipd list' does not print serials, so ask Windows PnP for the FTDI device
# whose serial matches, then map it back to a busid via its location.
find_busid() {
    powershell.exe -NoProfile -Command "
        \$m = Get-CimInstance Win32_PnPEntity |
              Where-Object { \$_.DeviceID -like 'FTDIBUS*VID_0403+PID_6010+${SERIAL_PREFIX}*' } |
              Select-Object -First 1
        if (\$m) { usbipd list } " 2>/dev/null | tr -d '\r'
}

LIST=$(powershell.exe -NoProfile -Command "usbipd list" 2>/dev/null | tr -d '\r')
WIN_SERIAL=$(powershell.exe -NoProfile -Command "
    Get-CimInstance Win32_PnPEntity |
      Where-Object { \$_.DeviceID -like 'FTDIBUS*VID_0403+PID_6010+${SERIAL_PREFIX}*' } |
      ForEach-Object { (\$_.DeviceID -split '\+')[2] -split '\\\\' } |
      Select-Object -First 1" 2>/dev/null | tr -d '\r' | head -1)

if [ "${1:-}" = "--detach" ]; then
    BUSID=$(echo "$LIST" | awk -v vp="$VIDPID" '$2==vp && /Attached/ {print $1}' | head -1)
    if [ -z "$BUSID" ]; then
        echo "Nothing with $VIDPID is attached to WSL."
        exit 0
    fi
    echo "Detaching busid $BUSID (the board returns to Windows / Vivado)"
    powershell.exe -NoProfile -Command "usbipd detach --busid $BUSID" 2>&1 | tail -2
    exit 0
fi

if [ -n "$WIN_SERIAL" ]; then
    echo "Nexys FTDI serial on the Windows side: $WIN_SERIAL"
else
    echo "WARNING: no FTDI with a '${SERIAL_PREFIX}*' serial found on Windows."
    echo "         It may already be attached to WSL (Windows cannot see it then)."
fi

# Candidate busids: every 0403:6010 that is NOT already attached. With the Tang
# also plugged in there can be two - the one Windows still owns is this board,
# because an attached device disappears from the Windows side.
CANDIDATES=$(echo "$LIST" | awk -v vp="$VIDPID" '$2==vp && !/Attached/ {print $1}')
COUNT=$(echo "$CANDIDATES" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
    echo "No unattached $VIDPID device. Already attached? Current /dev/ttyUSB*:"
    ls -l /dev/ttyUSB* 2>/dev/null || echo "  (none)"
    exit 0
fi
if [ "$COUNT" -gt 1 ]; then
    echo "ERROR: more than one unattached $VIDPID device:" >&2
    echo "$CANDIDATES" >&2
    echo "Unplug the other FTDI board, or pass the busid by hand:" >&2
    echo "  powershell.exe -Command 'usbipd attach --wsl --busid <busid>'" >&2
    exit 1
fi
BUSID=$(echo "$CANDIDATES" | head -1)
echo "Nexys 4 DDR at busid $BUSID"

BEFORE=$(ls /dev/ttyUSB* 2>/dev/null | tr '\n' ' ')

powershell.exe -NoProfile -Command "usbipd attach --wsl --busid $BUSID" 2>&1 | tail -2

for i in $(seq 1 20); do
    lsusb -d "$VIDPID" >/dev/null 2>&1 && break
    sleep 0.5
done
sudo modprobe ftdi_sio
for i in $(seq 1 20); do
    NOW=$(ls /dev/ttyUSB* 2>/dev/null | tr '\n' ' ')
    [ "$NOW" != "$BEFORE" ] && break
    sleep 0.5
done

sudo chmod 666 /dev/ttyUSB* 2>/dev/null
NEW=$(comm -13 <(echo "$BEFORE" | tr ' ' '\n' | sort -u) \
               <(ls /dev/ttyUSB* 2>/dev/null | sort -u) | grep . || true)

if [ -z "$NEW" ]; then
    echo "ERROR: no new /dev/ttyUSB* appeared." >&2
    exit 1
fi
echo "new serial ports: $(echo $NEW | tr '\n' ' ')"
echo "  lower node = interface A (JTAG), higher node = interface B (CONSOLE, 9600 8N1)"
echo
echo "Read the console with, e.g.:"
echo "  picocom -b 9600 $(echo "$NEW" | tail -1)"
echo
echo "Give the board back to Vivado on Windows with:  ./usb-attach.sh --detach"
