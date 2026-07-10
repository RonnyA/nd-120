#!/bin/bash
###############################################################################
# Build the FAT16 test image for the SD-FAT testbenches.
#
# Produces:
#   fat16.img    8 MB FAT16 "superfloppy" (no partition table) containing
#                  BOOT.BPUN   the payload (root)
#                  TEST.TXT    8 KB pre-created COPY target (root, contiguous)
#                  HDD/        subdirectory with hdd1.img (1 MB) and
#                              hdd2.img (2 MB) disk-image placeholders
#   payload.bin  copy of the payload (testbenches compare the dump/copy
#                against these exact bytes)
#
# Same recipe as a real card (README.md), just against an image file.
# Requires dosfstools (mkfs.vfat) and mtools (mmd/mcopy) - no root needed.
###############################################################################
set -e
cd "$(dirname "$0")"

PAYLOAD="${1:-../../../../runSim/RTC.BPUN}"

if [ ! -f "$PAYLOAD" ]; then
    echo "make_test_image.sh: payload $PAYLOAD not found" >&2
    exit 1
fi

# the WRBLK1 test needs BOOT.BPUN to span at least two 2048-byte blocks;
# RTC.BPUN alone is 2342 bytes, so serve it three times over (7026 bytes)
cat "$PAYLOAD" "$PAYLOAD" "$PAYLOAD" > payload.bin

# 8 MB, 1 sector/cluster -> ~16000 clusters, comfortably a REAL FAT16
# (below 4085 clusters mkfs would silently make something FAT12-shaped)
dd if=/dev/zero of=fat16.img bs=1M count=8 status=none
mkfs.vfat -F 16 -s 1 -n ND120 fat16.img > /dev/null

# root files: the boot payload and the pre-created contiguous COPY target
mcopy -i fat16.img payload.bin ::BOOT.BPUN
dd if=/dev/zero of=TEST.TXT bs=1024 count=8 status=none
mcopy -i fat16.img TEST.TXT ::TEST.TXT
rm -f TEST.TXT

# HDD subdirectory with two disk-image placeholders
mmd -i fat16.img ::HDD
dd if=/dev/zero of=hdd1.img bs=1M count=1 status=none
dd if=/dev/zero of=hdd2.img bs=1M count=2 status=none
mcopy -i fat16.img hdd1.img ::HDD/hdd1.img
mcopy -i fat16.img hdd2.img ::HDD/hdd2.img
rm -f hdd1.img hdd2.img

echo "fat16.img ready ($(stat -c%s fat16.img) bytes), payload $(stat -c%s payload.bin) bytes ($PAYLOAD)"
mdir -i fat16.img ::
