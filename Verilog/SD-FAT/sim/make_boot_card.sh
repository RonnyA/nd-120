#!/bin/bash
###############################################################################
# Build the BOOT SD card image for the ND120 Verilog paper-tape boot path
# (nd_storage FILE0 = BOOT.BPUN, served to ND_TAPE_400 via
# nd_storage_tape_adapter). This is the card the '400$' boot reads from when
# the Verilog-tape-over-SD-FAT source is selected (both the runSim Verilator
# harness, which preloads this image into the SDRAM mem model, and a real SD
# card on the Tang).
#
# Produces (in this directory):
#   nd_boot_card.img   4 MB FAT16 "superfloppy" (mkfs.vfat -F 16 -s 1, the
#                      proven recipe) containing ONE contiguous file:
#                        BOOT.BPUN   = a copy of the source BPUN
#                                      (default ../../runSim/INSTRUCTION-B.BPUN)
#
# nd_storage v1 requires every served file to be CONTIGUOUS with an intact
# end-of-chain; a fresh mkfs + single mcopy guarantees that. The script
# re-walks the FAT and REFUSES to emit (deletes the image, exit 1) unless
# BOOT.BPUN is verifiably contiguous and fsck.vfat -n is clean.
#
# Usage: make_boot_card.sh [SOURCE_BPUN] [OUTPUT_IMG]
#
# Requires dosfstools (mkfs.vfat, fsck.vfat), mtools (mcopy), python3 - no root.
#
# Ronny Hansen
###############################################################################
set -e
cd "$(dirname "$0")"

SRC="${1:-../../runSim/INSTRUCTION-B.BPUN}"
IMG="${2:-nd_boot_card.img}"

if [ ! -f "$SRC" ]; then
    echo "make_boot_card.sh: source BPUN not found: $SRC" >&2
    exit 1
fi

SRC_BYTES=$(stat -c%s "$SRC")
# SLOT0 is 32 blocks x 2048 = 65536 bytes in the nd_storage default slot map.
if [ "$SRC_BYTES" -gt 65536 ]; then
    echo "make_boot_card.sh: $SRC is $SRC_BYTES bytes, larger than the 65536-byte tape slot (SLOT0=32 blocks)" >&2
    exit 1
fi

rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count=0 seek=4 status=none
mkfs.vfat -F 16 -s 1 -r 112 -n NDBOOT "$IMG" > /dev/null
mcopy -i "$IMG" "$SRC" ::BOOT.BPUN

# ---- verify BOOT.BPUN is contiguous with an intact end-of-chain ----
if ! python3 - "$IMG" "$SRC_BYTES" <<'EOF'
import struct, sys
img_path, want = sys.argv[1], int(sys.argv[2])
data = bytearray(open(img_path, "rb").read())
bps   = struct.unpack_from("<H", data, 11)[0]
spc   = data[13]
rsvd  = struct.unpack_from("<H", data, 14)[0]
nfats = data[16]
rootn = struct.unpack_from("<H", data, 17)[0]
spf   = struct.unpack_from("<H", data, 22)[0]
fat0  = rsvd
root_s = rsvd + nfats * spf

def die(m):
    sys.stderr.write("make_boot_card.sh: verify FAILED: %s\n" % m); sys.exit(1)

def fat_get(c):
    return struct.unpack_from("<H", data, fat0 * bps + c * 2)[0]

# BOOT.BPUN has a 4-char extension, so it is stored as a long filename with
# a mangled 8.3 short entry (like TAPE.BPUN). Find the ONE real file entry
# (skip long-filename 0x0F and volume-label 0x08 entries) rather than match
# a short name that mcopy mangled.
def only_real_file():
    found = None
    for i in range(rootn):
        off = root_s * bps + i * 32
        if data[off] in (0x00, 0xE5):
            continue
        attr = data[off + 11]
        if attr == 0x0F or (attr & 0x08):
            continue
        if struct.unpack_from("<I", data, off + 28)[0] == 0:
            continue
        if found is not None:
            die("expected exactly one file on the boot card, found >1")
        found = off
    return found

ent = only_real_file()
if ent is None:
    die("no BOOT.BPUN file entry found")
first = struct.unpack_from("<H", data, ent + 26)[0]
size  = struct.unpack_from("<I", data, ent + 28)[0]
if size != want:
    die("BOOT.BPUN size %d != source %d" % (size, want))
n = (size + spc * bps - 1) // (spc * bps)
chain, c = [], first
while len(chain) < n:
    chain.append(c)
    c = fat_get(c)
    if len(chain) < n and (c < 2 or c >= 0xFFF7):
        die("chain ended early at hop %d of %d" % (len(chain), n))
if c < 0xFFF7:
    die("chain missing end-of-chain mark (0x%04X)" % c)
if not all(chain[i + 1] == chain[i] + 1 for i in range(len(chain) - 1)):
    die("BOOT.BPUN is NOT contiguous: %s" % chain)
print("make_boot_card.sh: BOOT.BPUN contiguous OK (%d bytes, %d FAT clusters %d..%d)"
      % (size, n, chain[0], chain[-1]))
EOF
then
    rm -f "$IMG"
    exit 1
fi

if ! fsck.vfat -n "$IMG" > /dev/null; then
    echo "make_boot_card.sh: fsck.vfat rejects $IMG - refusing to emit" >&2
    rm -f "$IMG"
    exit 1
fi

echo "make_boot_card.sh: built $IMG (BOOT.BPUN = $SRC, $SRC_BYTES bytes)"
