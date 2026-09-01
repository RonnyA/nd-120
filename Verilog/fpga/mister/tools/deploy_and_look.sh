#!/bin/bash
#############################################################################
#  deploy_and_look.sh - flash the MiSTer and read the screen back           #
#                                                                           #
#  WHY (31-AUG-2026)                                                        #
#  ----------------                                                         #
#  Bring-up on this board was "build for 15 minutes, flash it, then ask      #
#  someone what is on the monitor". That is a terrible loop: it needs a      #
#  person in front of the screen for every attempt, and what comes back is   #
#  a description rather than the pixels.                                     #
#                                                                           #
#  MiSTer's main binary accepts a "screenshot" command on /dev/MiSTer_cmd    #
#  and writes a PNG under /media/fat/screenshots/<CORE>/. So the whole loop  #
#  can run over ssh: copy the bitstream, load the core, wait for it to boot, #
#  screenshot, pull the PNG back. Nobody has to look at anything.            #
#                                                                           #
#  USAGE                                                                    #
#    export MISTER_PASS=...                # required, never store it here   #
#    ./tools/deploy_and_look.sh            # deploy, load, screenshot        #
#    ./tools/deploy_and_look.sh --look     # screenshot only, no reflash     #
#                                                                           #
#  Override the host with MISTER_HOST, the settle time with MISTER_SETTLE    #
#  (seconds to wait after loading the core before the screenshot - the CPU   #
#  needs time to get somewhere before its screen is worth reading).          #
#############################################################################
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOST="${MISTER_HOST:-MisterPi.HackerCorp.no}"
USER_AT="root@${HOST}"
SETTLE="${MISTER_SETTLE:-12}"
RBF="${HERE}/../output_files/nd120.rbf"
CORE_PATH="/media/fat/_Computer/ND120.rbf"
OUTDIR="${MISTER_SHOTDIR:-${HERE}/../shots}"

if [ -z "${MISTER_PASS:-}" ]; then
    echo "MISTER_PASS is not set. Export the board's root password first." >&2
    echo "It is deliberately not stored in this repo." >&2
    exit 2
fi

SSH="sshpass -p ${MISTER_PASS} ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR"
SCP="sshpass -p ${MISTER_PASS} scp -o StrictHostKeyChecking=no -o LogLevel=ERROR"

LOOK_ONLY=0
[ "${1:-}" = "--look" ] && LOOK_ONLY=1

if [ "$LOOK_ONLY" -eq 0 ]; then
    [ -f "$RBF" ] || { echo "No bitstream at $RBF - run 'make build' first." >&2; exit 1; }
    echo "==> deploying $(basename "$RBF") ($(stat -c%s "$RBF") bytes)"
    $SCP "$RBF" "${USER_AT}:${CORE_PATH}"
    echo "==> loading core"
    $SSH "$USER_AT" "echo \"load_core ${CORE_PATH}\" > /dev/MiSTer_cmd"
    echo "==> settling ${SETTLE}s"
    sleep "$SETTLE"
fi

# Clear old shots first, so "the newest PNG" is unambiguous rather than a
# guess based on timestamps that may not even be set on this board.
echo "==> screenshot"
SHOT=$($SSH "$USER_AT" '
rm -f /media/fat/screenshots/*/*.png 2>/dev/null
echo "screenshot" > /dev/MiSTer_cmd
sleep 3
find /media/fat/screenshots -name "*.png" | head -1
')

if [ -z "$SHOT" ]; then
    echo "The board produced no screenshot. Is a core actually loaded?" >&2
    exit 1
fi

mkdir -p "$OUTDIR"
LOCAL="${OUTDIR}/$(basename "$SHOT")"
$SCP "${USER_AT}:${SHOT}" "$LOCAL"
echo "==> $LOCAL"
