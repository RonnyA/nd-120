#!/bin/bash
###############################################################################
# Build the FAT16 card image for the streaming-dump testbench
# (sd_fat_block_tb.v - menu commands 8 BLOCK and 9 SECTOR).
#
# Usage: make_block_image.sh [IMG] [MB]
#   IMG  output image name   (default blockdump.img)
#   MB   image size in MB    (default 8)
#
# Produces:
#   $IMG        FAT16 "superfloppy" (no partition table) holding
#                 BIG.BPUN   BIG_KB kilobytes of block-numbered pattern
#                 BOOT.BPUN  a small file, so the compile-time default name
#                            still resolves on this image
#   big.bin     the same pattern bytes, for reference when a dump looks wrong
#
# BIG.BPUN is deliberately LARGER THAN THE 64 KB DUMP BUFFER: proving that the
# block dump works on a file the buffered dump (menu 2) cannot even open is the
# whole reason these commands exist. Its content is
#
#   16-bit big-endian word w of the file  =  w mod 65536
#
# i.e. every word carries its own position. Any 16 bytes of a dump name the
# place they came from, and - the reason for this exact choice - the RANGE
# command's running word checksum CHANGES if a block is read from the wrong
# place. An earlier per-block ramp pattern summed to the same value for every
# block, so a checksum over it could not have caught a misplaced read at all.
#
# 1 sector per cluster on a freshly made filesystem: mcopy lays the file down
# in consecutive clusters, which is what "block N is at first sector + 4*N"
# assumes. Requires dosfstools (mkfs.vfat), mtools (mcopy) and python3.
###############################################################################
set -e
cd "$(dirname "$0")"

IMG="${1:-blockdump.img}"
MB="${2:-8}"
BIG_KB=320          # 160 blocks: block 100 sits at byte 204800, far past 64 KB

python3 - "$BIG_KB" <<'PYEOF'
import sys
kb = int(sys.argv[1])
data = bytearray(kb * 1024)
for w in range(len(data) // 2):
    v = w & 0xFFFF
    data[2 * w] = v >> 8       # big-endian, like every ND-120 word on disc
    data[2 * w + 1] = v & 0xFF
open("big.bin", "wb").write(data)
PYEOF

printf 'small boot payload\n' > small.bin

rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count=0 seek="$MB" status=none
mkfs.vfat -F 16 -s 1 -n ND120 "$IMG" > /dev/null
mcopy -i "$IMG" big.bin ::BIG.BPUN
mcopy -i "$IMG" small.bin ::BOOT.BPUN
rm -f small.bin

echo "$IMG ready ($(stat -c%s "$IMG") bytes, FAT16, 1 sec/cluster), BIG.BPUN $(stat -c%s big.bin) bytes"
mdir -i "$IMG" ::
