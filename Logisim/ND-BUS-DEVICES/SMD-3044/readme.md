# SMD controller card 3044 - memory address and word count

A Logisim-Evolution 3.8.0 drawing of one block of the ND-632 15 MHz SMD disc
controller: card 3044, logic diagram sheet 3, block "MEMORY ADDRESS & WORD
COUNT" (manual ND-11.020.01, scan page 118). Every chip sits at the position
code the drawing gives it (14C, 12A, 3D ...), every connection is made on the
drawing's DIP pin number, and every net carries the drawing's signal name.

The block answers one question: what the ND-120 mass storage load (`21540&`)
leaves in the controller's word count, given that the microcode writes the
word count register only once while the manual says it takes two writes.

## Files

| File | What it is |
|---|---|
| `SMD3044-MA-WC.circ` | The drawing. Open it in Logisim-Evolution 3.8.0. Switches for the IOX strobes and the A register, probes for SELH, the 2942 instruction lines and clocks, and DB0-23. |
| `Am2942-datasheet.md` | AMD Am2942 data sheet (form 03574B), OCR with the OCR errors corrected against the scan. The Am2942 subcircuit is built from it. |
| `gen_3044.py` | Writes the drawing (`sheet`), writes the boot bench (`bench`), checks the bench output (`check`). |
| `parts.py` | The two subcircuits: Am2942 and 74LS54. |
| `lsgen.py` | Writes Logisim circuits from a net list: TTL parts and DIP-shaped subcircuits, joined by tunnels on the pins. |
| `tb_am2942.py` | Clocked test bench for the Am2942 subcircuit, with a reference model written from the data sheet tables. |
| `tb_ls54.py` | Checks the 74LS54 subcircuit on all 1024 input combinations. |

The `.circ` files are made by the scripts; change a script, not the `.circ`.

## Running the checks

From this folder, with Python 3 and Java (Logisim is run headless):

```
LOGISIM="java -jar <path to logisim-evolution-3.8.0-all.jar>"

python gen_3044.py sheet SMD3044-MA-WC.circ

python tb_ls54.py build tb_ls54.circ
$LOGISIM -t table tb_ls54.circ > ls54.log
python tb_ls54.py check ls54.log            # TB_RESULT: PASS, 1024 combinations

python tb_am2942.py build tb_am2942.circ
$LOGISIM -t table,halt tb_am2942.circ > am2942.log
python tb_am2942.py check am2942.log        # TB_RESULT: PASS, 246 clocked steps

python gen_3044.py bench tb_3044.circ
$LOGISIM -t table,halt tb_3044.circ > boot.log
python gen_3044.py check boot.log           # TB_RESULT: PASS
```

## What the boot bench shows

The bench plays the microcode's `MASS` routine (ND-120-DELILAH-L listing, CSA
002217-002235) as IOX strobes: memory address (+1) loaded with 0 twice, block
address (+3) with 0, word count (+7) with 002000 once, control word (+5) with
4. It then reads the registers back.

- Word count read back: DB0-15 = 002000 on the first read, DB0-7 = 000 (bits
  16-23) on the second. The word count is 00 002000.
- Memory address read back: 000000.

So one +7 write is enough on this card. The first write of a register pair
clocks all three Am2942 slices: the low slices (14C, 12C) are clocked on every
LMAR, WCS and LCW write (2D), the high slice (12A) only while SELH is in its
first state (2C), and the byte swapper 11B feeds it bits 0-7 of the same
word. One write of a value V leaves bits 0-7 of V in bits 16-23 and V in bits
0-15. The second write the manual describes only rewrites bits 0-15.

Removing the WCS term from the low slice clock (2D pin 11) makes the bench
fail with a word count of 000000, so the bench can tell the two apart.

## What is assumed, and what is open

The manual has no parts list, so where the drawing's symbol does not settle a
gate's type it was chosen by what the circuit has to do:

- 3E, 1G and 4C are AND gates; 4B is a NAND; 1C and 14F are inverters.
- 3E and 1C use the same symbol, and so does 3A. 3E has to be an AND (a NAND
  would hold 4E preset), and 3A has to invert (RREG1 must be the opposite of
  RREG0). So that symbol does not settle a gate's type on its own.
- R40, R39 and RN9 pin 8 on DB16-18: the far end is not drawn. They are shown
  as pull-downs, like the rest of RN9.
- C13 (220 pF on the 4E preset) is left out.
- 14C /ACI and /WCI (pins 3 and 1) use the same rail symbol as /IE (pin 8),
  which has to be ground or no instruction runs. So they are ground.

Open:

- **DWC0 must rest low** between transfers for any IOX load to clock the
  2942s: 2C/2D pins 1 and 2 are both DWC0, so DWC0 high holds the LS54 output
  low. Its 0 subscript would say active-low. DWC0 is made off this sheet and
  has not been traced. The bench holds it low.
- **Bus fight on DB16-23 during the first register read.** 11B (direction
  from 4C) and 12A both drive DB16-23. The boot read-back did not show it
  because both carried 0. It depends on 4C's gate type.
- **IOX timing.** The bench raises PIODRY1 after the decoded strobe, so the
  Am2942 instruction lines are settled before the clock rises (the data sheet
  asks for 46 ns). With PIODRY1 already high when the strobe arrives, the
  clock and the instruction change together and the 2942 can take an ENABLE
  COUNTERS instead.

Not modelled at all: the controller's own microcode ROM, which runs disc
transfers. It is not available. This block's register loads come straight
from the CPU's IOX strobes and do not pass through it; the transfer-time
signals it would drive (DWC0, ADREN1, INGRANT0, RFT1) are inputs here.

## The Am2942 subcircuit

The data sheet gives the chip as registers plus a function table (Figure 4),
not as gates, so the subcircuit is those registers driven by that table, built
from TTL parts. Two things in it are not in the data sheet:

- The /ACO and /WCO rule: low when the carry input is low and the counter is
  at its last value in its counting direction. The data sheet only says "full
  lookahead carry".
- D0-D7 are two-way on the chip. Logisim cannot make a subcircuit port both
  input and output, so the DIP pins D0-D7 are the inputs and Y0-Y7, beside the
  body, are the three-state outputs. Wherever the chip is used, Dk and Yk are
  tied to the same net.

Logisim-Evolution 3.8.0's 74377 and 74273 never load (they share one model
class; their outputs stayed undefined over eight clocks with the enable or
clear held right). The registers are built from 74175s with a 74157 in front
that feeds Q back when the register is not loaded.
