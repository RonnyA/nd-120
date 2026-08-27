#!/bin/bash
###############################################################################
# Build a FAT16 SD card image carrying a REAL Winchester disc image, for the
# Verilator SINTRAN boot that runs through the in-RTL SD-FAT stack
# (sim/ target `probe-wd-sd`, i.e. ND120_SD_STORAGE + ND120_SD_WD).
#
# WHY THIS EXISTS
#   Until now no Verilator run put the SD/FAT/cache path under a SINTRAN boot.
#   The boot harness (`probe-wd`) hands the disc image to the C file server in
#   simDevices/NDBus.cpp, so sd_card_ctrl, sd_file_reader, nd_storage_engine,
#   nd_storage_cache and nd_storage_disc_adapter never execute. The storage
#   testbenches DO exercise them, but against a 16384-byte stand-in WD0.IMG -
#   about 1/4800th of a real image, and never with SINTRAN's access pattern.
#   Every defect in that stack is therefore invisible in simulation and only
#   shows up on the Tang. This card closes that hole.
#
# PRODUCES (in this directory unless told otherwise)
#   nd_wd_card.img   FAT16 "superfloppy", sized to fit the image, containing
#                      WD0.IMG     the Winchester image (contiguous)
#                      BOOT.BPUN   optional, only if a source BPUN is given
#
# CONTIGUITY: nd_storage v1 requires every served file to be CONTIGUOUS with an
# intact end-of-chain (SDFAT_STORAGE_CHECK refuses to open anything else). A
# fresh mkfs plus a single mcopy per file guarantees it; the script re-walks
# both FATs afterwards and REFUSES to emit the image (deletes it, exit 1) if
# that did not hold, or if fsck.vfat -n is unhappy. A testbench that passes
# against an accidentally-broken card proves nothing.
#
# ROOT DIRECTORY IS KEPT SMALL (-r 16, one sector). sd_file_reader scans the
# root linearly and the fewer entries there are, the shorter every mount is.
#
# Usage: make_wd_card.sh <WD_IMAGE> [OUTPUT_IMG] [BOOT_BPUN]
#
#   WD_IMAGE    REQUIRED. Path to the Winchester image (e.g. a 78,643,200-byte
#               WD0.IMG). No default: this file lives outside the repo and the
#               script must never guess which one is meant.
#   OUTPUT_IMG  card image to write (default nd_wd_card.img, in this directory)
#   BOOT_BPUN   optional BPUN to also place on the card as BOOT.BPUN, so the
#               same card can feed the paper-tape client (client 0).
#
# On success the last line printed is
#   make_wd_card.sh: CARD_BYTES=<n>
# which is exactly the value to pass as ND120_SD_CARD_BYTES - sd_card_model.v
# slurps the whole card into a byte array at time 0 and reads every sector
# past MAX_BYTES back as 0xFF.
#
# Requires dosfstools (mkfs.vfat, fsck.vfat), mtools (mcopy) and python3 - no
# root, no loop mount.
#
# Ronny Hansen
###############################################################################
set -e

# Resolve the caller's paths BEFORE cd'ing to this script's directory, so a
# path relative to the caller's working directory still means what they typed.
# Only the DEFAULT output name is relative to this directory.
abspath() { case "$1" in /*) printf '%s\n' "$1";; *) printf '%s\n' "$PWD/$1";; esac; }

SRC_WD="${1:+$(abspath "$1")}"
IMG_ARG="${2:+$(abspath "$2")}"
SRC_BPUN="${3:+$(abspath "$3")}"

cd "$(dirname "$0")"

IMG="${IMG_ARG:-nd_wd_card.img}"

if [ -z "$SRC_WD" ]; then
    echo "make_wd_card.sh: usage: make_wd_card.sh <WD_IMAGE> [OUTPUT_IMG] [BOOT_BPUN]" >&2
    echo "make_wd_card.sh: the Winchester image path is REQUIRED (it lives outside the repo)" >&2
    exit 1
fi
if [ ! -f "$SRC_WD" ]; then
    echo "make_wd_card.sh: Winchester image not found: $SRC_WD" >&2
    exit 1
fi
if [ -n "$SRC_BPUN" ] && [ ! -f "$SRC_BPUN" ]; then
    echo "make_wd_card.sh: BPUN not found: $SRC_BPUN" >&2
    exit 1
fi

WD_BYTES=$(stat -c%s "$SRC_WD")
BPUN_BYTES=0
[ -n "$SRC_BPUN" ] && BPUN_BYTES=$(stat -c%s "$SRC_BPUN")

# nd_storage addresses a client image in 2048-byte BLOCKS with a 16-bit block
# number, so 65536 blocks = 128 MB is the hard ceiling on any served file.
MAX_IMAGE_BYTES=$((65536 * 2048))
if [ "$WD_BYTES" -gt "$MAX_IMAGE_BYTES" ]; then
    echo "make_wd_card.sh: $SRC_WD is $WD_BYTES bytes; nd_storage's 16-bit block number caps a served file at $MAX_IMAGE_BYTES" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Card geometry.
#
# Payload plus 4 MB of slack for the reserved sectors, both FATs, the root
# directory and cluster round-up; then rounded up to a whole MB. FAT16 tops
# out just under 65525 data clusters, so pick the smallest power-of-two
# sectors-per-cluster that keeps the count under a 60000 safety margin.
# 2048-byte clusters (spc=4) line up exactly with an nd_storage block, which
# is the common case for a 75 MB image on a ~80 MB card.
# ---------------------------------------------------------------------------
CARD_MB=$(( (WD_BYTES + BPUN_BYTES + 4 * 1024 * 1024 + 1048575) / 1048576 ))
CARD_SECTORS=$(( CARD_MB * 2048 ))
SPC=1
while [ $(( CARD_SECTORS / SPC )) -ge 60000 ]; do
    SPC=$(( SPC * 2 ))
    if [ "$SPC" -gt 64 ]; then
        echo "make_wd_card.sh: $CARD_MB MB needs more than 64 sectors/cluster - too big for FAT16" >&2
        exit 1
    fi
done
CARD_BYTES=$(( CARD_MB * 1048576 ))

echo "make_wd_card.sh: WD0.IMG = $WD_BYTES bytes -> $CARD_MB MB card, $SPC sectors/cluster"

rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count=0 seek="$CARD_MB" status=none
mkfs.vfat -F 16 -s "$SPC" -r 16 -n NDWDCARD "$IMG" > /dev/null

# Fresh filesystem + one mcopy per file = contiguous, in the order written.
# WD0.IMG goes on FIRST so it lands at the start of the data region.
mcopy -i "$IMG" "$SRC_WD" ::WD0.IMG
if [ -n "$SRC_BPUN" ]; then
    mcopy -i "$IMG" "$SRC_BPUN" ::BOOT.BPUN
fi

# ---------------------------------------------------------------------------
# Verify: every file contiguous, intact end-of-chain, exact expected size.
# Refuses to emit otherwise - nd_storage would fail the open at run time and
# the boot would look like a CPU fault instead of a bad card.
# ---------------------------------------------------------------------------
if ! python3 - "$IMG" "$WD_BYTES" "$BPUN_BYTES" <<'EOF'
import struct, sys

img_path = sys.argv[1]
wd_want  = int(sys.argv[2])
bp_want  = int(sys.argv[3])

data = bytearray(open(img_path, "rb").read())

bps   = struct.unpack_from("<H", data, 11)[0]
spc   = data[13]
rsvd  = struct.unpack_from("<H", data, 14)[0]
nfats = data[16]
rootn = struct.unpack_from("<H", data, 17)[0]
spf   = struct.unpack_from("<H", data, 22)[0]
fat0  = rsvd
root_s = rsvd + nfats * spf

def die(msg):
    sys.stderr.write("make_wd_card.sh: card verify FAILED: %s\n" % msg)
    sys.exit(1)

if bps != 512:
    die("bytes-per-sector is %d; sd_file_reader requires 512" % bps)

def fat_get(c):
    return struct.unpack_from("<H", data, fat0 * bps + c * 2)[0]

# Find a root entry by the name the FAT READER sees. sd_file_reader matches
# the VFAT long name when a valid LFN chain precedes the entry, else the 8.3
# short name - so this must do the same. It matters here: "BOOT.BPUN" has a
# FOUR-character extension, which is not a legal 8.3 name at all, so mcopy
# stores it as an LFN with a mangled short entry ("BOOT~1.BPU" or similar).
# Matching the raw 11-byte short field would silently never find it.
def lfn_units(off):
    """Reconstruct the long name from the LFN entries preceding a short one."""
    parts, i = [], (off - root_s * bps) // 32 - 1
    while i >= 0:
        e = root_s * bps + i * 32
        if data[e + 11] != 0x0F or data[e] in (0x00, 0xE5):
            break
        raw = b""
        for lo in (1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30):
            raw += bytes(data[e + lo:e + lo + 2])
        txt = ""
        for k in range(0, len(raw), 2):
            u = raw[k] | (raw[k + 1] << 8)
            if u in (0x0000, 0xFFFF):
                break
            txt += chr(u)
        parts.insert(0, txt)
        if data[e] & 0x40:          # last-logical LFN entry, chain complete
            return "".join(parts)
        i -= 1
    return None

def short_name(off):
    base = bytes(data[off:off + 8]).decode("latin-1").rstrip(" ")
    ext  = bytes(data[off + 8:off + 11]).decode("latin-1").rstrip(" ")
    return base + ("." + ext if ext else "")

def dirent(want_name):
    want = want_name.upper()
    for i in range(rootn):
        off = root_s * bps + i * 32
        if data[off] in (0x00, 0xE5):
            continue
        attr = data[off + 11]
        if attr == 0x0F or (attr & 0x08):     # LFN fragment / volume label
            continue
        if (lfn_units(off) or "").upper() == want or short_name(off).upper() == want:
            return off
    return None

def walk(first, size):
    n = (size + spc * bps - 1) // (spc * bps)
    chain, c = [], first
    while len(chain) < n:
        chain.append(c)
        c = fat_get(c)
        if len(chain) < n and (c < 2 or c >= 0xFFF7):
            die("chain of length %d ended early at hop %d (entry 0x%04X)"
                % (n, len(chain), c))
    if c < 0xFFF7:
        die("chain missing end-of-chain mark (last entry 0x%04X)" % c)
    return chain

def check(name, want):
    ent = dirent(name)
    if ent is None:
        die("%s not found in the root directory" % name)
    size  = struct.unpack_from("<I", data, ent + 28)[0]
    first = struct.unpack_from("<H", data, ent + 26)[0]
    if size != want:
        die("%s is %d bytes on the card, want %d" % (name, size, want))
    chain = walk(first, size)
    if not all(chain[i + 1] == chain[i] + 1 for i in range(len(chain) - 1)):
        die("%s is NOT contiguous - nd_storage would refuse to open it" % name)
    return len(chain)

nclu = check("WD0.IMG", wd_want)
print("make_wd_card.sh: WD0.IMG verified contiguous (%d clusters of %d bytes)"
      % (nclu, spc * bps))
if bp_want:
    n2 = check("BOOT.BPUN", bp_want)
    print("make_wd_card.sh: BOOT.BPUN verified contiguous (%d clusters)" % n2)
EOF
then
    rm -f "$IMG"
    exit 1
fi

if ! fsck.vfat -n "$IMG" > /dev/null; then
    echo "make_wd_card.sh: fsck.vfat rejects $IMG - refusing to emit" >&2
    rm -f "$IMG"
    exit 1
fi

echo "make_wd_card.sh: built $IMG"
echo "make_wd_card.sh: CARD_BYTES=$CARD_BYTES"
