#!/bin/bash
###############################################################################
# Build the FAT16/FAT32 test images for the SD-FAT testbenches.
#
# Usage: make_test_image.sh [PAYLOAD] [FS] [IMG] [SPC] [MB]
#   PAYLOAD  boot payload file             (default runSim/RTC.BPUN)
#   FS       16 or 32                      (default 16)
#   IMG      output image name             (default fat16.img)
#   SPC      sectors per cluster for mkfs  (default 1)
#   MB       image size in MB              (default 8 / 40 for FAT32)
#
# Produces:
#   $IMG         FAT "superfloppy" (no partition table) containing
#                  BOOT.BPUN   the payload (root)
#                  TEST.TXT    tiny pre-created COPY target (root)
#                  HDD/        subdirectory with hdd1.img (1 MB) and
#                              hdd2.img (2 MB) disk-image placeholders
#   payload.bin  copy of the payload (testbenches compare the dump/copy
#                against these exact bytes)
#
# The big-geometry variant (field-failure reproduction: 16 KB clusters like
# a real 16-32 GB SDHC card) is: make_test_image.sh <payload> 32 fat32big.img 32 1100
# 1100 MB / 16 KB = ~70000 clusters: a GENUINE FAT32 (>= 65525 clusters -
# anything smaller makes mtools refuse the volume), cluster numbers cross
# the 16-bit boundary, sectors_per_fat = 576. The image file is SPARSE
# (dd seek), so it costs well under 1 MB of actual disk.
#
# Same recipe as a real card (README.md), just against an image file.
# Requires dosfstools (mkfs.vfat) and mtools (mmd/mcopy) - no root needed.
###############################################################################
set -e
cd "$(dirname "$0")"

PAYLOAD="${1:-../../../../runSim/RTC.BPUN}"
FS="${2:-16}"          # 16 or 32
IMG="${3:-fat16.img}"
SPC="${4:-1}"          # sectors per cluster
DEFMB=8
if [ "$FS" = "32" ]; then DEFMB=40; fi
MB="${5:-$DEFMB}"

if [ ! -f "$PAYLOAD" ]; then
    echo "make_test_image.sh: payload $PAYLOAD not found" >&2
    exit 1
fi

# the WRBLK1 test needs BOOT.BPUN to span at least two 2048-byte blocks;
# RTC.BPUN alone is 2342 bytes, so serve it three times over (7026 bytes)
cat "$PAYLOAD" "$PAYLOAD" "$PAYLOAD" > payload.bin

# FAT16: 8 MB, 1 sector/cluster -> ~16000 clusters (a REAL FAT16;
# below 4085 clusters mkfs would silently make something FAT12-shaped).
# FAT32: 40 MB, 1 sector/cluster -> ~80000 clusters (above the FAT32
# minimum of 65525).
# Sparse image: allocate by size only, mkfs/mtools fill what they touch.
rm -f $IMG
dd if=/dev/zero of=$IMG bs=1M count=0 seek=$MB status=none
mkfs.vfat -F $FS -s $SPC -n ND120 $IMG > /dev/null

# root files: just the boot payload plus a TINY pre-existing COPY target
# (9 bytes, like a hand-made "test text" file - COPY must replace it).
# IO.DAT is deliberately ABSENT: command 6 must CREATE it from scratch.
mcopy -i $IMG payload.bin ::BOOT.BPUN
printf 'test txt\n' > TEST.TXT
mcopy -i $IMG TEST.TXT ::TEST.TXT
rm -f TEST.TXT

# HDD subdirectory with two disk-image placeholders
mmd -i $IMG ::HDD
dd if=/dev/zero of=hdd1.img bs=1M count=1 status=none
dd if=/dev/zero of=hdd2.img bs=1M count=2 status=none
mcopy -i $IMG hdd1.img ::HDD/hdd1.img
mcopy -i $IMG hdd2.img ::HDD/hdd2.img
rm -f hdd1.img hdd2.img

echo "$IMG ready ($(stat -c%s $IMG) bytes, FAT$FS, $SPC sec/cluster), payload $(stat -c%s payload.bin) bytes ($PAYLOAD)"
mdir -i $IMG ::
