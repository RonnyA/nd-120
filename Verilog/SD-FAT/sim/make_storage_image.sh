#!/bin/bash
###############################################################################
# Build the FAT16 card image for the nd_storage mount testbenches
# (nd_storage_tb.v, target test-nds-mount, and nd_storage_fatchk_tb.v,
# target test-nds-fatchk).
#
# Produces (all in this directory):
#   nds_storage.img  4 MB FAT16 "superfloppy" (mkfs.vfat -F 16 -s 1, the
#                    same recipe as the proven sd-fat-test images, sized
#                    at the FAT16 minimum and with a SMALL root directory
#                    (-r 112 = 7 sectors), because the missing-file case
#                    walks EVERY root sector - keeps the registered
#                    iverilog gate fast) with:
#                      TAPE.BPUN     3001 bytes (odd size: exercises the
#                                    ceil(size/2048) block count AND the
#                                    zero-padded 32-bit tail word)
#                      FLOPPY1.IMG   4096 bytes (2 exact blocks; kept tiny
#                                    on purpose - full-stack iverilog speed;
#                                    big-image coverage belongs to the
#                                    step-6 Verilator system gate)
#                      FLOPPY2.IMG   deliberately ABSENT (the missing-file
#                                    open_err case)
#                      FRAG.IMG      2048 bytes, DELIBERATELY FRAGMENTED
#                                    (the fatchk open_err case): written
#                                    contiguously by mcopy, then a python3
#                                    FAT surgery relocates its second
#                                    cluster to a free cluster past the
#                                    chain (data moved, both FAT copies
#                                    patched) so FAT[first] != first+1.
#                                    The surgery RE-WALKS the chain and
#                                    REFUSES to emit the image (deletes it,
#                                    exit 1) unless the file verifiably
#                                    ended up fragmented with an intact
#                                    end-of-chain - and unless TAPE.BPUN
#                                    and FLOPPY1.IMG are still contiguous.
#                                    fsck.vfat -n must stay clean.
#   nds_tape.bin     the TAPE.BPUN payload (byte k =
#                      (k%256 + 37*((k/256)%256) + 129) % 256)
#   nds_flp1.bin     the FLOPPY1.IMG payload (byte k =
#                      (k%256 + 29*((k/256)%256) + 7) % 256)
#   nds_frag.bin     the FRAG.IMG payload (byte k =
#                      (k%256 + 53*((k/256)%256) + 201) % 256; no tb
#                      compares its content - the open must FAIL)
#
# The patterns are position-dependent with a NON-zero step across a
# 2048-byte shift (a plain linear k*a+b pattern aliases block-to-block,
# because 2048*a is always 0 mod 256). nd_storage_tb.v recomputes the
# same formulas for its byte-exact SDRAM/buffer compares - keep them in
# sync with the tb's pat_tape()/pat_flp() functions.
#
# Fresh image + sequential mcopy = contiguous files (the v1 requirement);
# FRAG.IMG is the one deliberate violation, made AFTER the good files.
# Requires dosfstools (mkfs.vfat, fsck.vfat), mtools (mcopy) and python3 -
# no root.
#
# Ronny Hansen, 11-JUL-2026
###############################################################################
set -e
cd "$(dirname "$0")"

TAPE_BYTES=3001
FLP_BYTES=4096
FRAG_BYTES=2048
# WD0.IMG: the Winchester client (client 6). It is a CACHED client
# (CACHE_MASK bit 6), and until 08-AUG-2026 NO card-image testbench ever
# opened a cached client through the real mount - every full-stack read here
# was tape or floppy, both DIRECT. 16384 bytes = 8 blocks, several clusters,
# enough to walk the FAT for a later block while block 0 needs no hop.
WD_BYTES=16384
IMG=nds_storage.img

python3 - "$TAPE_BYTES" "$FLP_BYTES" "$FRAG_BYTES" "$WD_BYTES" <<'EOF'
import sys
tape_n = int(sys.argv[1])
flp_n = int(sys.argv[2])
frag_n = int(sys.argv[3])
wd_n = int(sys.argv[4])
with open("nds_tape.bin", "wb") as f:
    f.write(bytes(((k % 256) + 37 * ((k // 256) % 256) + 129) % 256
                  for k in range(tape_n)))
with open("nds_flp1.bin", "wb") as f:
    f.write(bytes(((k % 256) + 29 * ((k // 256) % 256) + 7) % 256
                  for k in range(flp_n)))
with open("nds_frag.bin", "wb") as f:
    f.write(bytes(((k % 256) + 53 * ((k // 256) % 256) + 201) % 256
                  for k in range(frag_n)))
with open("nds_wd0.bin", "wb") as f:
    f.write(bytes(((k % 256) + 61 * ((k // 256) % 256) + 83) % 256
                  for k in range(wd_n)))
EOF

# 4 MB sparse FAT16, 1 sector/cluster (~8000 clusters: a REAL FAT16),
# 112 root entries = 7 root sectors (fast missing-file scans)
rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count=0 seek=4 status=none
mkfs.vfat -F 16 -s 1 -r 112 -n NDSTOR "$IMG" > /dev/null

mcopy -i "$IMG" nds_tape.bin ::TAPE.BPUN
mcopy -i "$IMG" nds_flp1.bin ::FLOPPY1.IMG
mcopy -i "$IMG" nds_wd0.bin ::WD0.IMG
# FLOPPY2.IMG intentionally not created
mcopy -i "$IMG" nds_frag.bin ::FRAG.IMG

# ---------------------------------------------------------------------------
# Fragment FRAG.IMG: relocate its SECOND cluster to a free cluster two past
# the end of the (contiguous) chain, move the 512 data bytes, patch both FAT
# copies, then RE-WALK and verify. Refuses (deletes the image, exit 1) if
# the result is not verifiably fragmented - the testbench relies on it.
# ---------------------------------------------------------------------------
if ! python3 - "$IMG" <<'EOF'
import struct, sys

img_path = sys.argv[1]
data = bytearray(open(img_path, "rb").read())

# --- FAT16 superfloppy geometry from the boot sector ---
bps    = struct.unpack_from("<H", data, 11)[0]   # bytes per sector
spc    = data[13]                                # sectors per cluster
rsvd   = struct.unpack_from("<H", data, 14)[0]   # reserved sectors
nfats  = data[16]
rootn  = struct.unpack_from("<H", data, 17)[0]   # root dir entries
spf    = struct.unpack_from("<H", data, 22)[0]   # sectors per FAT
fat0   = rsvd
fat1   = rsvd + spf
root_s = rsvd + nfats * spf
root_n = (rootn * 32) // bps
data_s = root_s + root_n                          # first data sector (cl 2)

def die(msg):
    sys.stderr.write("make_storage_image.sh: FRAG surgery FAILED: %s\n" % msg)
    sys.exit(1)

def fat_get(c):
    return struct.unpack_from("<H", data, fat0 * bps + c * 2)[0]

def fat_set(c, v):
    for base in (fat0, fat1):                     # both FAT copies
        struct.pack_into("<H", data, base * bps + c * 2, v)

def clus_off(c):
    return (data_s + (c - 2) * spc) * bps

def dirent(name83):
    for i in range(rootn):
        off = root_s * bps + i * 32
        if data[off] in (0x00, 0xE5):
            continue
        if data[off:off + 11] == name83:
            return off
    return None

def walk(first, size):
    n = (size + spc * bps - 1) // (spc * bps)
    chain, c = [], first
    while len(chain) < n:
        chain.append(c)
        c = fat_get(c)
        if len(chain) < n and (c < 2 or c >= 0xFFF7):
            die("chain of length %d ended early at hop %d" % (n, len(chain)))
    if c < 0xFFF7:
        die("chain missing end-of-chain mark (last entry 0x%04X)" % c)
    return chain

def contiguous(chain):
    return all(chain[i + 1] == chain[i] + 1 for i in range(len(chain) - 1))

ent = dirent(b"FRAG    IMG")
if ent is None:
    die("FRAG.IMG root entry not found")
first = struct.unpack_from("<H", data, ent + 26)[0]
size  = struct.unpack_from("<I", data, ent + 28)[0]

chain = walk(first, size)
if len(chain) < 3:
    die("need >= 3 clusters to fragment, got %d" % len(chain))
if not contiguous(chain):
    die("FRAG.IMG not contiguous BEFORE surgery (unexpected mcopy layout)")

# destination: a free cluster two past the chain end (leaves a visible gap)
dest = chain[-1] + 2
while fat_get(dest) != 0x0000:
    dest += 1
victim = chain[1]

# move the data, then rewire: first -> dest -> chain[2] ... ; victim freed
data[clus_off(dest):clus_off(dest) + spc * bps] = \
    data[clus_off(victim):clus_off(victim) + spc * bps]
fat_set(chain[0], dest)
fat_set(dest, chain[2])
fat_set(victim, 0x0000)

# --- verify: FRAG.IMG fragmented but intact; good files untouched ---
chain2 = walk(first, size)
if contiguous(chain2):
    die("FRAG.IMG came out CONTIGUOUS after surgery - refusing to emit")
if chain2 != [chain[0], dest] + chain[2:]:
    die("unexpected post-surgery chain %s" % chain2)

# every OTHER real file (skip LFN entries, the volume label, FRAG itself)
# must still be contiguous - the good-open cases rely on it
others = 0
for i in range(rootn):
    off = root_s * bps + i * 32
    if data[off] in (0x00, 0xE5):
        continue
    attr = data[off + 11]
    if attr == 0x0F or (attr & 0x08):
        continue
    if off == ent:
        continue
    sz = struct.unpack_from("<I", data, off + 28)[0]
    if sz == 0:
        continue
    fc = struct.unpack_from("<H", data, off + 26)[0]
    if not contiguous(walk(fc, sz)):
        die("entry %r no longer contiguous - refusing to emit"
            % bytes(data[off:off + 11]))
    others += 1
if others != 3:
    die("expected 3 other files (TAPE.BPUN, FLOPPY1.IMG, WD0.IMG), found %d"
        % others)

open(img_path, "wb").write(data)
print("make_storage_image.sh: FRAG.IMG fragmented OK (chain %s -> %s)"
      % (chain, chain2))
EOF
then
    rm -f "$IMG"
    exit 1
fi

# post-surgery filesystem health (read-only check)
if ! fsck.vfat -n "$IMG" > /dev/null; then
    echo "make_storage_image.sh: fsck.vfat rejects the image - refusing to emit" >&2
    rm -f "$IMG"
    exit 1
fi

echo "make_storage_image.sh: built $IMG (TAPE.BPUN=$TAPE_BYTES B, FLOPPY1.IMG=$FLP_BYTES B, FLOPPY2.IMG absent, WD0.IMG=$WD_BYTES B, FRAG.IMG=$FRAG_BYTES B fragmented)"

###############################################################################
# Second image for the step-6 Verilator system gate (SD-FAT/sim target
# test-storage, harness test_nd_storage.cpp):
#
#   nds_storage_full.img  4 MB FAT16, same recipe, but with ALL THREE v1
#                         client files present (the concurrency + write-
#                         through tests need three good mounts):
#                           TAPE.BPUN     3001 bytes  (same payload/pattern
#                                         as above - nds_tape.bin)
#                           FLOPPY1.IMG   12288 bytes (6 blocks; same
#                                         formula as nds_flp1.bin, longer)
#                           FLOPPY2.IMG   8192 bytes  (4 blocks; byte k =
#                                         (k%256 + 41*((k/256)%256) + 63)
#                                         % 256)
#                         SMD0.IMG is deliberately ABSENT (the harness's
#                         missing-file open_err case, client 3).
#   nds_flp1full.bin / nds_flp2.bin  the payloads.
#
# Self-verification (same property as the first image): every file must be
# CONTIGUOUS with an intact end-of-chain and the exact expected size, and
# fsck.vfat -n must pass - otherwise the image is deleted and we exit 1.
# The write-path tests rely on contiguity (v1 requirement, spec section 6).
###############################################################################

FLP1_FULL_BYTES=12288
FLP2_BYTES=8192
IMG_FULL=nds_storage_full.img

python3 - "$FLP1_FULL_BYTES" "$FLP2_BYTES" <<'EOF'
import sys
f1_n = int(sys.argv[1])
f2_n = int(sys.argv[2])
with open("nds_flp1full.bin", "wb") as f:
    f.write(bytes(((k % 256) + 29 * ((k // 256) % 256) + 7) % 256
                  for k in range(f1_n)))
with open("nds_flp2.bin", "wb") as f:
    f.write(bytes(((k % 256) + 41 * ((k // 256) % 256) + 63) % 256
                  for k in range(f2_n)))
EOF

rm -f "$IMG_FULL"
dd if=/dev/zero of="$IMG_FULL" bs=1M count=0 seek=4 status=none
mkfs.vfat -F 16 -s 1 -r 112 -n NDSFULL "$IMG_FULL" > /dev/null

mcopy -i "$IMG_FULL" nds_tape.bin     ::TAPE.BPUN
mcopy -i "$IMG_FULL" nds_flp1full.bin ::FLOPPY1.IMG
mcopy -i "$IMG_FULL" nds_flp2.bin     ::FLOPPY2.IMG
# SMD0.IMG intentionally not created (missing-file open_err case)

if ! python3 - "$IMG_FULL" "$TAPE_BYTES" "$FLP1_FULL_BYTES" "$FLP2_BYTES" <<'EOF'
import struct, sys

img_path = sys.argv[1]
want_sizes = sorted(int(a) for a in sys.argv[2:5])
data = bytearray(open(img_path, "rb").read())

bps    = struct.unpack_from("<H", data, 11)[0]
spc    = data[13]
rsvd   = struct.unpack_from("<H", data, 14)[0]
nfats  = data[16]
rootn  = struct.unpack_from("<H", data, 17)[0]
spf    = struct.unpack_from("<H", data, 22)[0]
fat0   = rsvd
root_s = rsvd + nfats * spf
root_n = (rootn * 32) // bps

def die(msg):
    sys.stderr.write("make_storage_image.sh: FULL image verify FAILED: %s\n" % msg)
    sys.exit(1)

def fat_get(c):
    return struct.unpack_from("<H", data, fat0 * bps + c * 2)[0]

def walk(first, size):
    n = (size + spc * bps - 1) // (spc * bps)
    chain, c = [], first
    while len(chain) < n:
        chain.append(c)
        c = fat_get(c)
        if len(chain) < n and (c < 2 or c >= 0xFFF7):
            die("chain of length %d ended early at hop %d" % (n, len(chain)))
    if c < 0xFFF7:
        die("chain missing end-of-chain mark (last entry 0x%04X)" % c)
    return chain

sizes = []
for i in range(rootn):
    off = root_s * bps + i * 32
    if data[off] in (0x00, 0xE5):
        continue
    attr = data[off + 11]
    if attr == 0x0F or (attr & 0x08):
        continue
    sz = struct.unpack_from("<I", data, off + 28)[0]
    fc = struct.unpack_from("<H", data, off + 26)[0]
    if sz == 0:
        continue
    chain = walk(fc, sz)
    if not all(chain[k + 1] == chain[k] + 1 for k in range(len(chain) - 1)):
        die("entry %r is NOT contiguous - refusing to emit"
            % bytes(data[off:off + 11]))
    sizes.append(sz)

if sorted(sizes) != want_sizes:
    die("file sizes %s, want %s" % (sorted(sizes), want_sizes))

print("make_storage_image.sh: full image verified (3 contiguous files, sizes %s)"
      % sorted(sizes))
EOF
then
    rm -f "$IMG_FULL"
    exit 1
fi

if ! fsck.vfat -n "$IMG_FULL" > /dev/null; then
    echo "make_storage_image.sh: fsck.vfat rejects $IMG_FULL - refusing to emit" >&2
    rm -f "$IMG_FULL"
    exit 1
fi

echo "make_storage_image.sh: built $IMG_FULL (TAPE.BPUN=$TAPE_BYTES B, FLOPPY1.IMG=$FLP1_FULL_BYTES B, FLOPPY2.IMG=$FLP2_BYTES B, SMD0.IMG absent)"

###############################################################################
# Third image for the error-code testbench (nd_storage_errors_tb.v, targets
# test-nds-errors / test-nds-errors-fatchain):
#
#   nds_badfat.img  4 MB FAT16, same recipe, containing
#                     FLOPPY1.IMG  4096 bytes, CONTIGUOUS and intact (the
#                                  control: every error case must be able to
#                                  prove the stack still succeeds normally)
#                     BADFAT.IMG   4096 bytes, then DELIBERATELY BROKEN: the
#                                  FAT entry of its SECOND cluster is set to
#                                  0x0000 (free) in both FAT copies, so a
#                                  chain walk hits a free cluster (at hop 2
#                                  of the 8 the size demands) before it
#                                  reaches the target sector. That is the one
#                                  and only way to reach nd_storage_engine.v's
#                                  NDS_ERR_FATCHAIN arm - a fabricated c_err
#                                  input would prove nothing about the engine.
#
# TAPE.BPUN is deliberately ABSENT here (the missing-file NDS_ERR_NOTOPEN
# case reads through client 0).
#
# This image is BROKEN ON PURPOSE, so - unlike the other two - it is NOT
# handed to fsck.vfat: fsck would rightly reject it. What IS verified is
# that the damage is exactly the damage intended (FLOPPY1.IMG still walks
# clean, BADFAT.IMG's walk dies at hop 1 on a free cluster) - otherwise the
# image is deleted and the script exits 1, because a testbench that passes
# against an accidentally-healthy image proves nothing.
#
# The engine's own fatchk contiguity gate (SDFAT_STORAGE_CHECK) would refuse
# to OPEN BADFAT.IMG, which is a different (and also correct) failure. The
# fatchain target therefore compiles the testbench with -DSDFAT_NO_CHECK so
# the request reaches the engine's per-request FAT walk.
###############################################################################

BADFAT_BYTES=4096
IMG_BAD=nds_badfat.img

python3 - "$BADFAT_BYTES" <<'EOF'
import sys
n = int(sys.argv[1])
with open("nds_badfat.bin", "wb") as f:
    f.write(bytes(((k % 256) + 71 * ((k // 256) % 256) + 19) % 256
                  for k in range(n)))
EOF

rm -f "$IMG_BAD"
dd if=/dev/zero of="$IMG_BAD" bs=1M count=0 seek=4 status=none
mkfs.vfat -F 16 -s 1 -r 112 -n NDSBAD "$IMG_BAD" > /dev/null

mcopy -i "$IMG_BAD" nds_flp1.bin   ::FLOPPY1.IMG
mcopy -i "$IMG_BAD" nds_badfat.bin ::BADFAT.IMG
# TAPE.BPUN intentionally not created (the missing-file case)

if ! python3 - "$IMG_BAD" <<'EOF'
import struct, sys

img_path = sys.argv[1]
data = bytearray(open(img_path, "rb").read())

bps    = struct.unpack_from("<H", data, 11)[0]
spc    = data[13]
rsvd   = struct.unpack_from("<H", data, 14)[0]
nfats  = data[16]
rootn  = struct.unpack_from("<H", data, 17)[0]
spf    = struct.unpack_from("<H", data, 22)[0]
fat0   = rsvd
fat1   = rsvd + spf
root_s = rsvd + nfats * spf

def die(msg):
    sys.stderr.write("make_storage_image.sh: BADFAT surgery FAILED: %s\n" % msg)
    sys.exit(1)

def fat_get(c):
    return struct.unpack_from("<H", data, fat0 * bps + c * 2)[0]

def fat_set(c, v):
    for base in (fat0, fat1):
        struct.pack_into("<H", data, base * bps + c * 2, v)

def dirent(name83):
    for i in range(rootn):
        off = root_s * bps + i * 32
        if data[off] in (0x00, 0xE5):
            continue
        if data[off:off + 11] == name83:
            return off
    return None

def walk(first, size):
    """Walk the chain; return (chain, 'ok') or (partial, 'died at hop N')."""
    n = (size + spc * bps - 1) // (spc * bps)
    chain, c = [], first
    while len(chain) < n:
        chain.append(c)
        c = fat_get(c)
        if len(chain) < n and (c < 2 or c >= 0xFFF7):
            return chain, "died at hop %d (entry 0x%04X)" % (len(chain), c)
    return chain, "ok" if c >= 0xFFF7 else "no end-of-chain (0x%04X)" % c

ent = dirent(b"BADFAT  IMG")
if ent is None:
    die("BADFAT.IMG root entry not found")
first = struct.unpack_from("<H", data, ent + 26)[0]
size  = struct.unpack_from("<I", data, ent + 28)[0]

chain, verdict = walk(first, size)
if verdict != "ok":
    die("BADFAT.IMG was already broken before surgery: %s" % verdict)
if len(chain) < 3:
    die("need >= 3 clusters to break, got %d" % len(chain))

# Free the SECOND cluster. The walk appends chain[0], reads FAT[chain[0]]
# (still intact, so it appends chain[1]), then reads FAT[chain[1]] = 0x0000
# and stops - i.e. it dies at hop 2, having produced 2 of the 8 clusters the
# directory size demands. That is exactly the "chain ended before the target
# block" condition nd_storage_engine.v reports as NDS_ERR_FATCHAIN.
fat_set(chain[1], 0x0000)

chain2, verdict2 = walk(first, size)
if verdict2 != "died at hop 2 (entry 0x0000)":
    die("BADFAT.IMG did not break as intended: %s" % verdict2)

# the control file MUST still be intact - otherwise a passing testbench
# would only prove that everything fails
good = dirent(b"FLOPPY1 IMG")
if good is None:
    die("FLOPPY1.IMG root entry not found")
gfirst = struct.unpack_from("<H", data, good + 26)[0]
gsize  = struct.unpack_from("<I", data, good + 28)[0]
gchain, gverdict = walk(gfirst, gsize)
if gverdict != "ok":
    die("control file FLOPPY1.IMG is damaged too: %s" % gverdict)
if not all(gchain[i + 1] == gchain[i] + 1 for i in range(len(gchain) - 1)):
    die("control file FLOPPY1.IMG is not contiguous")

open(img_path, "wb").write(data)
print("make_storage_image.sh: BADFAT.IMG broken OK (chain %s, now %s; "
      "control FLOPPY1.IMG intact at %s)" % (chain, verdict2, gchain))
EOF
then
    rm -f "$IMG_BAD"
    exit 1
fi

echo "make_storage_image.sh: built $IMG_BAD (FLOPPY1.IMG=$FLP_BYTES B intact, BADFAT.IMG=$BADFAT_BYTES B chain broken at hop 2, TAPE.BPUN absent)"
