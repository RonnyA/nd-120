# Verilog/docs - index

Design docs, handoffs, plans, and root-cause writeups for the ND-120 Verilog
work. This index groups every file in this folder. Links are relative to this
directory (repo-root path is `Verilog/docs/<file>`).

> Honesty note: entries below the **Bus protocol** section are short hooks
> derived from each file's title/subject, not a re-verification of its
> contents. Open the file for the actual claims, and prefer the RTL + cited
> manuals over any summary.

## Bus protocol - IOX / IDENT / DMA (start here for the external bus)

- [`nd100-bus-deck.pptx`](nd100-bus-deck.pptx) - 16-slide deck covering ALL
  bus phases: IOX read/write, IDENT poll, DMA read/write, the recovery gap,
  and CPU-vs-DMA arbitration. Editable PowerPoint; verbatim ND-06.016.01
  manual text baked into each slide. Timing waveforms are native-drawn
  reconstructions - trust the RTL and the manual over the drawing.
- [`nd100-bus-dma.md`](nd100-bus-dma.md) - the authoritative ND-100 bus + DMA
  writeup. Section 10.8 = the MEASURED findings ("every second read lost",
  read-data-capture window). Read before touching
  `../ND-BUS-DEVICES/DMA/circuit/ND_DMA_MASTER.v`.
- [`nd100x-device-semantics.md`](nd100x-device-semantics.md) - device
  register/interrupt semantics from the nd100x reference.
- [`device-bus-todo.md`](device-bus-todo.md) - master task list for the
  external-bus device work.
- [`dma-test-plan.md`](dma-test-plan.md) - DMA test plan.

Device READMEs and validation plans that build on the above:
`../ND-BUS-DEVICES/README.md`, `../floppyTester/PLAN-P3-dma-master-validation.md`,
`../floppyTester/PLAN-floppy-validation.md`.

## Storage / floppy / SMD / tape / SD-FAT

- [`nd-storage-design.md`](nd-storage-design.md)
- [`nd-storage-interface-spec.md`](nd-storage-interface-spec.md)
- [`nd-storage-spec-validation.md`](nd-storage-spec-validation.md)
- [`PLAN-nd120-storage-phases.md`](PLAN-nd120-storage-phases.md)
- [`sd-bpun-device-plan.md`](sd-bpun-device-plan.md)
- [`sd-cmd18-block-gap-research.md`](sd-cmd18-block-gap-research.md)
- [`sd-speed-plan.md`](sd-speed-plan.md)
- [`usb-storage-options.md`](usb-storage-options.md)
- [`fat-reader-slimming-plan.md`](fat-reader-slimming-plan.md)
- [`floppy-3112-register-spec-ND-11.021.md`](floppy-3112-register-spec-ND-11.021.md)
- [`floppy-review-findings.md`](floppy-review-findings.md)
- [`floppy-smd-completion-plan.md`](floppy-smd-completion-plan.md)
- [`smd-review-findings.md`](smd-review-findings.md)
- [`BUG-tape400-sd-level12-storm.md`](BUG-tape400-sd-level12-storm.md)
- [`HANDOFF-floppy-core-session.md`](HANDOFF-floppy-core-session.md)
- [`HANDOFF-floppy-pio-c-and-csharp-fixes.md`](HANDOFF-floppy-pio-c-and-csharp-fixes.md)
- [`HANDOFF-floppy-smd-devices.md`](HANDOFF-floppy-smd-devices.md)
- [`HANDOFF-nd100x-floppy-dma-manual-fixes.md`](HANDOFF-nd100x-floppy-dma-manual-fixes.md)

## CPU / microcode / instruction bugs / interrupts

- [`MPY-dynamic-overflow-rootcause.md`](MPY-dynamic-overflow-rootcause.md)
- [`SHIFT-serial-input-rootcause.md`](SHIFT-serial-input-rootcause.md)
- [`RUN-level14-livelock-analysis.md`](RUN-level14-livelock-analysis.md)
- [`am2914-command-model.md`](am2914-command-model.md)
- [`HANDOFF-mor-level12-wiring.md`](HANDOFF-mor-level12-wiring.md)
- [`HANDOFF-instruction-verify-and-mpy.md`](HANDOFF-instruction-verify-and-mpy.md)
- [`HANDOFF-interrupt-trap-testbenches.md`](HANDOFF-interrupt-trap-testbenches.md)
- [`HANDOFF-ff-execution-divergence.md`](HANDOFF-ff-execution-divergence.md)
- [`HANDOFF-rqbit-v2-latch-to-ff.md`](HANDOFF-rqbit-v2-latch-to-ff.md)
- [`HANDOFF-mmu-cache-stale-read-banner.md`](HANDOFF-mmu-cache-stale-read-banner.md)
- [`HANDOFF-paging-test3-pof-dispatch-rootcause.md`](HANDOFF-paging-test3-pof-dispatch-rootcause.md)
- [`HANDOFF-tpe-memory-test-corruption.md`](HANDOFF-tpe-memory-test-corruption.md)
- [`INSTRUCTION-verifier-TPE-run.md`](INSTRUCTION-verifier-TPE-run.md)
- [`bfill-sts-static-analysis.md`](bfill-sts-static-analysis.md)
- [`boot-golden-spec.md`](boot-golden-spec.md)
- [`serial-binload-300.md`](serial-binload-300.md)
- [`48bit-float-not-configured.md`](48bit-float-not-configured.md)
- [`PAL-AUDIT-2026-07-30.md`](PAL-AUDIT-2026-07-30.md)

## FPGA / clocking / boards / memory

- [`fpga-bringup-issues.md`](fpga-bringup-issues.md)
- [`fpga-debug-methodology.md`](fpga-debug-methodology.md)
- [`fpga-resource-limits.md`](fpga-resource-limits.md)
- [`fpga-utilization-breakdown.md`](fpga-utilization-breakdown.md)
- [`fpga-utilization-reduction-plan.md`](fpga-utilization-reduction-plan.md)
- [`clock-enable-refactor.md`](clock-enable-refactor.md)
- [`plan-fix-unconstrained-clocks.md`](plan-fix-unconstrained-clocks.md)
- [`latch-inventory.md`](latch-inventory.md)
- [`hw-timing-vs-verilog.md`](hw-timing-vs-verilog.md)
- [`sim-io-capture-and-clocking-lessons.md`](sim-io-capture-and-clocking-lessons.md)
- [`skip-wcs-load.md`](skip-wcs-load.md)
- [`build-defines.md`](build-defines.md)
- [`backwiring-prom-installation-number.md`](backwiring-prom-installation-number.md)
- [`PLAN-nd120-core-extraction.md`](PLAN-nd120-core-extraction.md)

### Tang Nano 20K / Basys3 boards

- [`tang-nano-20k-port.md`](tang-nano-20k-port.md)
- [`tang-bsram-sdram-plan.md`](tang-bsram-sdram-plan.md)
- [`tang20k-build-flows.md`](tang20k-build-flows.md)
- [`tang-masked-grant-audit.md`](tang-masked-grant-audit.md)
- [`HANDOFF-tang-does-not-work-for-verilog-llm.md`](HANDOFF-tang-does-not-work-for-verilog-llm.md)
- [`HANDOFF-basys3-memory-write.md`](HANDOFF-basys3-memory-write.md)
- [`basys3-memory-speed-validation.md`](basys3-memory-speed-validation.md)
- [`HANDOFF-opcom-output-speed.md`](HANDOFF-opcom-output-speed.md)

### DRAM / parity / pack16

- [`nd120-dram-memory.md`](nd120-dram-memory.md)
- [`nd120-parity-analysis.md`](nd120-parity-analysis.md)
- [`nd120-parity-refactor-order.md`](nd120-parity-refactor-order.md)
- [`nd120-pack16-defines-note.md`](nd120-pack16-defines-note.md)
- [`worklog-2026-07-12-pack16-dual-toolchain.md`](worklog-2026-07-12-pack16-dual-toolchain.md)
