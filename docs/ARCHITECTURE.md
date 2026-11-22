# Architecture Notes

## Design intent

The prototype investigates command-level integrity checking and recovery in an FPGA storage-controller datapath. It is NVMe-oriented, but it does not implement the complete NVMe or PCIe protocol stack.

## Functional path

1. A 32-bit command is presented to the controller.
2. The CRC-8 logic checks command integrity at ingress.
3. Valid commands are handled by the command queue manager.
4. A clean command copy is retained by the shadow-command mechanism.
5. Active-command integrity is rechecked during processing.
6. When the implemented fault/recovery conditions are met, the controller coordinates selective replay.
7. The behavioral DMA engine models command execution and completion.

## RTL source map

- `top_controller.v`: module integration and top-level signals.
- `cmd_queue_manager.v`: queue and replay-related control.
- `fault_unit.v`: CRC and fault-related logic.
- `dma_engine.v`: behavioral execution model.

For exact widths, reset behavior, handshake semantics, state transitions and replay conditions, the Verilog source is authoritative. This document intentionally avoids duplicating implementation details that may drift from the RTL.
