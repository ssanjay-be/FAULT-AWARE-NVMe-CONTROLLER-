# Verification Notes

## Environment

The reported directed simulation was run by the project author using Vivado 2026.1 / XSim.

## Directed scenarios

| Test | Stimulus | Intended check | Reported result |
|---|---|---|---|
| T1 | Valid command | Normal command execution and completion | PASS |
| T2 | Invalid CRC at ingress | Corrupted command is rejected | PASS |
| T2 observation | Observe for 10 cycles after rejection | No completion within that observation window | PASS |
| T3 | SEU-inspired bit flip in an active command | Integrity recheck detects corruption and replay restores the preserved command | PASS |
| T4 | A, B and C sequence with B corrupted | Recovery of B and expected completion sequence | PASS |

## Reported summary

- Four directed scenarios passed.
- Five successful command completions were observed.
- Zero failed testbench assertions were reported.
- The testbench printed `ALL TESTS PASSED`.

## Important interpretation limits

1. These are directed behavioral RTL tests, not formal verification.
2. The T2 negative-completion check covers the specified 10-cycle observation window only. It does not prove that the rejected command can never complete later.
3. The SEU-inspired fault is a simulated bit flip, not physical radiation testing.
4. The scenarios do not establish exhaustive coverage of all single-bit, multi-bit, burst, timing, or state-corruption faults.
5. The shadow command and recovery control state are not independently protected in this prototype.
6. The behavioral DMA/memory model does not establish PCIe/NVMe protocol compliance or real SSD behavior.

## Re-running

Use `vivado/create_project.tcl`, launch behavioral simulation, and inspect the transcript and waveform. Verify that `tb_top` is the simulation top and `top_controller` is the design/synthesis top.
