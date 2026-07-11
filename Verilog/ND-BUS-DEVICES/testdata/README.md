# Device test images (NOT in git)

The real disk images used by the device testbenches are large and stay
out of git (.gitignore covers *.img/*.IMG here). The testbenches print
a SKIP notice and still pass on their synthetic phases when an image is
missing; copy the files below to enable the real-image phases.

| File | Source | Used by |
|---|---|---|
| 210523I01-XX-01D.img | D:\ND\S\testprog\210523I01-XX-01D.img | FLOPPY-DMA/sim (1261568 bytes, ND distribution diskette, 77x2x8x1024) |
| BIGDISK0-L2-100.IMG | F:\RC\RonnyTest\HDLC1\BIGDISK0-L2-100.IMG | SMD/sim (78643200 bytes = 75 MB SMD disk 0; windowed loading, the tb reads start/middle/end windows) |
