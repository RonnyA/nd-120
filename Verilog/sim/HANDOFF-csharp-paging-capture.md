# Handoff request → C# ND-120 microcode-CPU team: capture TPE paging setup + STA→177777

**Full path:** `Verilog/sim/HANDOFF-csharp-paging-capture.md`
**From:** ND-120 Verilog/Verilator probe work (nd-120 repo, `sim/nd120_probe.*`).
**Why:** the Verilog RTL fails TPE `INSTRUCTION` on every memory-WRITE op that touches
logical address **177777 (0xFFFF, the top logical page)** — STA/STT/STX/MIN/STF/SBYT
read back 0. Physical (paging-OFF) round-trips 177777 fine; the fault appears only
under PAGING. We need the *known-good* paging bring-up from the C# oracle to (a) learn
the exact PTE/PCR/PON sequence the diagnostic uses, (b) replay it deterministically in
an RTL testbench, and (c) diff C# vs RTL routing of the top-page store. See
`docs`/memory `nd120-mmu-shadow-ram` for the full narrowing.

## The one decisive question first
Does the **C# ND-120/CX** running the real TPE `INSTRUCTION` (INSTCTION C03)
**memory-reference** test PASS — i.e. NO `*** ERROR *** STA/STT/STX/MIN/STF/SBYT`?
- If **PASS** → C# routes the top-page paged store correctly and the RTL is wrong;
  the capture below is the reference we replay/diff.
- If C# also errors on 177777 → it's a shared spec question, not an RTL-only bug.

## What to capture (window: start of the memory-reference sub-test → the STA→177777 write+verify)

A trace, **octal**, of:

1. **Paging control setup**
   - Every `TRR PCR` (per-level): the PCR value written + which level (PT/APT/ring/MMS2 bit2).
   - The `PON` enable point: the instruction that sets PONI (MST/TRR STS or PCR), and
     STS + current level at that moment.
   - MMS type in effect (MMS-2, 16PT vs 4PT).

2. **Page-table / shadow-map population** — the ground truth we're missing:
   - Every write that populates a page-table entry, as **(virtual page number → physical
     page number)**, especially **VPN 63 (logical page 177 = addresses 0177400-0177777)**.
   - HOW each PTE is written (the addressing: shadow-memory address range used, or the
     privileged op), and the exact **word format** of a PTE entry (bit layout: PPN bits,
     ring/permission bits, WPM/RPM/etc.).

3. **The store under test** — for `STA A→177777` (and ideally one control store to a
   NON-top page):
   - Effective **logical** address (177777) and the **physical** address it maps to
     (mapped page × 2000 + offset).
   - The value written, and **where C# writes it** (main physical page vs the shadow/
     page-table region).
   - The **verify read**: what logical address TPE reads back, what physical it maps to,
     and the value returned. (Our RTL reads back 0 — we need to see C#'s value + path.)

4. **Programmer-visible registers** at the STA fetch: A D T X B L P STS + the active
   PCR, so the replay tb can reproduce the exact MMU state.

## Format
Whatever the C# side emits easily — a per-instruction dump `addr : opcode : operands`
+ register state + a memory-write log `(logical → physical → value)` is ideal. Octal.
A machine-readable CSV/JSON of just the PTE writes + the STA/verify pair is enough on
its own to build the RTL replay testbench.

## How it plugs in on our side
- The captured PTE/PCR/PON sequence becomes the **deterministic setup vectors** for a
  new iverilog tb (`CPU-BOARD-3202/circuit/sim/…`, `test-…`, run under WSL) that replays
  it into the MMU (CPU_MMU_24 / CPU_MMU_PT_29) and asserts where the top-page store
  routes — the "model the tb from REAL CPU signals" plan, but with a *correct* reference
  instead of our hand-rolled paging setup (which never came up).
- We also drive the same setup through the RTL via `sim/nd120_probe.py` and compare the
  `MMU.s_wmap_n / s_epmap_n / s_ept_n / s_la_20_10 / PON` activity for the 177777 store
  against the C# routing.

## Guardrails
RTL is report-only on our side; this request is for a *reference capture* only — no
changes needed to the C# model beyond emitting the trace.
