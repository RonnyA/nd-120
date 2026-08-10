# PAL provenance — how a PAL in this tree is proved faithful

Every `PAL_<id>.v` in this directory is a hand transcription of a PALASM
listing. Transcription is the single largest source of real bugs found in this
project: `CGA_ALU_QREG` (one wrong mux input — every multiply returned a zero
low word) and `CGA_CPU_ALU_CONTR` (one wrong input — every rotate ran as a
plain shift) were both single-character errors that survived for months.

## Where the originals are

| What | Where |
|---|---|
| PALASM listings, OCR'd to text | `DesignDocuments/PAL-Code/SRC/<id>.txt` |
| Scanned listing images — **the true original** | `DesignDocuments/PAL-Code/IMG/<id>.png` |
| Equation-by-equation audit, 21-JUL-2026 | `DesignDocuments/PAL-Code/PAL-TRANSCRIPTION-FINDINGS.md` |
| The Verilog | `Verilog/PAL/PAL_<id>.v` |

All 24 transcribed PALs have a listing. There are no gaps in coverage.

**The `.txt` files are OCR output and have known garble.** During the July audit
a dropped `/` on 44601B's `/CGNTCACT` produced a false positive that was only
caught by going back to the PNG. When anything disagrees, the image wins.

## Rule

**A PAL is not modified on a hunch.** If the Verilog and the machine disagree,
the fault is assumed to be elsewhere until the listing proves the Verilog
wrong. Changing a PAL to make a symptom go away, without a listing to justify
it, is how a faithful recreation quietly stops being one.

## The two checks

### 1. Equation-level — the July 2026 audit

`PAL-TRANSCRIPTION-FINDINGS.md` records a manual, product-term-by-product-term
diff of every PAL against its listing, each candidate then confirmed with an
exhaustive or 40 000-cycle random equivalence testbench, and finally
re-checked against the PNG scan. That audit found and fixed real faults
(44306A EIPL, 44302B DSTB, 45001B SPEA/SPES, and others).

It is thorough, but it is a **one-time** pass. Nothing re-runs it.

### 2. Structural — `make test-pal-provenance`, every run

```
cd Verilog/PAL/sim
make test-pal-provenance
```

This holds every `PAL_*.v` to its listing on the one property that can be
checked mechanically and cheaply: **which outputs exist**. The Verilog may not
drive an output the listing does not define, and may not drop one it does.

That is the "invented signal" detector. It will not catch a wrong literal
inside an equation — that is what the audit and the golden testbenches are
for — but it does catch a whole signal appearing from nowhere, which is the
failure mode that a debugging session under pressure actually produces.

Three tables in `check_provenance.py` keep it honest:

- **`ALIASES`** — Verilog names that differ from the listing's pin name for a
  stated reason (e.g. `EBADR_b1`, because Verilator rejects the bare name
  `EBADR`). Each entry cites the source line.
- **`NOT_CONNECTED`** — pins the design deliberately leaves undriven, with the
  reason. Reported as warnings.
- **`ACKNOWLEDGED`** — signals that no listing backs and that are already
  understood. Reported loudly as warnings on every run. **This list may only
  shrink.** Anything not in it fails the build.

`ACKNOWLEDGED` is currently **empty**. Its one entry, 44404C `DLSHADOW`, was
resolved on 08-AUG-2026:

> `DLSHADOW` belongs to revision **44404D**, whose listing is not in
> `DesignDocuments/PAL-Code/SRC`, and `PAL_44404C.v:81-83` records the
> implementation as an explicit guess rather than a transcription. Tracing every
> instantiation showed the only board one is `CYC_36.v:468`, and
> **`CYC_36.v:485` leaves `.DLSHADOW()` unconnected**. `LSHADOW` feeds nothing
> else inside the PAL. The guess therefore drives nothing and cannot change
> machine behaviour — dead logic, not a latent bug. It moved to
> `NOT_CONNECTED`.
>
> This stops being true the moment anyone connects `.DLSHADOW()`. Doing so
> **requires the 44404D listing first** — do not wire it up on the strength of
> the current guess.

## Adding a listing or resolving a gap

1. Put the listing in `DesignDocuments/PAL-Code/SRC/<id>.txt`, and the scan in
   `IMG/<id>.png`.
2. Run `make test-pal-provenance`. Anything it flags is either a transcription
   error in the Verilog or OCR garble in the `.txt` — settle which by reading
   the PNG, never by guessing.
3. Remove the corresponding `ACKNOWLEDGED` entry.
4. If the PAL has no golden equivalence testbench, add one, so the equations
   and not just the pin names are held to the listing. `PAL/sim/` has the
   pattern (`PAL_44445B_D_tb`, `PAL_44446B_D_tb`).
