# ND-120 device address map

**Full path:** `Verilog/docs/device-address-map.md`

Every ND-BUS device in this tree: its IOX address, ident code, interrupt
level and where the registers are defined. All addresses are **OCTAL** -
that is the ND convention and mixing it up with hex is a recurring source of
wasted time (a testbench written with `16'h504` instead of `16'o504` looks
like a dead controller).

The values below are read out of the RTL parameters, not from memory or from
a manual, so they cannot drift from what the hardware actually decodes.

## The map

| Device | IOX base | Ident | Level | Module | Backing store |
|--------|----------|-------|-------|--------|---------------|
| Paper tape reader, device 400 | `400` | `2` | 12 | `ND-BUS-DEVICES/TAPE-400/circuit/ND_TAPE_400.v` | `BOOT.TAP` (Tang) / `BOOT.BPUN` |
| Winchester disc (ST506/3041) | `500` | `1` | 11 | `ND-BUS-DEVICES/WINCHESTER/circuit/ND_WINCHESTER.v` | `WD0.IMG`, `WD1.IMG` |
| SMD disc controller, 15 MHz | `1540` | `17` | 11 | `ND-BUS-DEVICES/SMD/circuit/ND_SMD.v` | `SMD0.IMG` .. `SMD2.IMG` |
| Floppy, DMA (3112) | `1560` | `21` | 11 | `ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v` | `FLOPPY1.IMG`, `FLOPPY2.IMG` |
| Floppy, PIO (3106, older) | `1560` | `21` | 11 | `ND-BUS-DEVICES/FLOPPY/circuit/ND_FLOPPY_PIO.v` | same |

The two floppy cores share address 1560, ident 21 and level 11 on purpose:
they are the same device slot at two different controller generations, and
only one is built into any given configuration.

## Boot / mass-load commands

The console command that loads from each device. The leading digits are the
device address; **bit 13 (the leading `2`) selects MASS storage load** rather
than the byte-stream (BPUN) load.

| Command | Meaning |
|---------|---------|
| `400$` | load a BPUN byte stream from the paper tape reader |
| `1560&` | floppy, stream load (BPUN) - the working floppy boot |
| `21560&` | floppy, MASS load - not implemented on either side |
| `500&` | Winchester, stream load - this card does not serve it |
| `20500&` | Winchester, MASS load - the SINTRAN boot path |
| `1540&` | SMD, stream load |

## Disc geometry

The Winchester and SMD are within 0.5% of the same capacity with completely
different geometries (72 vs 90 sectors per cylinder), which makes them easy to
confuse and impossible to substitute. Full table, where the parameters live,
and how to sanity-check them against a running machine:
`Verilog/ND-BUS-DEVICES/README.md`, section "Disc geometry - Winchester vs SMD".

## Register layouts

Each controller's own header block is the authority for its registers, and
each cites the manual section it was transcribed from:

| Device | Manual | Registers documented in |
|--------|--------|-------------------------|
| Winchester | ND-11.015.01 sec 2.1, 3.1-3.5, 4.1 | `ND_WINCHESTER.v` header |
| SMD | ND-11.020.01 sec 2.5 | `ND_SMD.v` header |
| Floppy DMA | ND-11.021.01 sec 3.1-3.9 | `ND_FLOPPY_DMA.v` header, plus `docs/floppy-3112-register-spec-ND-11.021.md` |
| Paper tape | (no controller manual - modelled on the C reference) | `ND_TAPE_400.v` header |

## Storage failure reporting

All four controllers map SD-FAT failures onto status bits their own manuals
define. The reason codes and the full per-controller mapping table are in
`Verilog/SD-FAT/circuit/nd_storage_status.vh`.

The paper tape reader is the exception: it has no error bit anywhere in its
four registers, so it stays silent (indistinguishable from end of tape to the
guest) and publishes the reason on the `TDISK_FAULT` / `TDISK_ERR_CODE`
diagnostic seam instead. The reasoning is written out in `ND_TAPE_400.v`.

## Keeping this file honest

The table is generated from the RTL. To re-derive it after adding a device:

```bash
cd Verilog
for f in ND-BUS-DEVICES/*/circuit/ND_*.v; do
  n=$(basename "$f" .v)
  b=$(grep -oE "BASE_ADDR *= *16'o[0-7]+"  "$f" | head -1 | grep -oE "[0-7]+$")
  i=$(grep -oE "IDENT_CODE *= *16'o[0-7]+" "$f" | head -1 | grep -oE "[0-7]+$")
  l=$(grep -oE "INT_LEVEL *= *4'd[0-9]+"   "$f" | head -1 | grep -oE "[0-9]+$")
  [ -n "$b" ] && printf "%-22s base=%-8s ident=%-8s level=%s\n" "$n" "$b" "$i" "$l"
done
```
