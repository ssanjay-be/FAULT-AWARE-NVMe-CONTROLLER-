# Implementation and Reporting Notes

## Target and tool

The project setup script targets AMD/Xilinx Zynq-7000 part `xc7z020clg400-1`. The reported simulation environment was Vivado 2026.1 / XSim.

## Correct reporting practice

Before reporting synthesis or implementation metrics:

1. Confirm `top_controller` is selected as the synthesis top.
2. Confirm only synthesizable RTL is in the design source set; `tb_top.v` belongs in simulation sources.
3. Confirm the target part matches the intended FPGA.
4. Review the XDC constraints and identify all constrained and unconstrained ports.
5. Run synthesis and implementation on the exact repository revision being reported.
6. Save the Vivado version, part, constraints, utilization report, timing summary, DRC and methodology reports with the results.

## Timing

Positive WNS/WHS values indicate that the analyzed paths meet their respective setup/hold requirements. This conclusion applies only to paths covered by the active timing constraints. If external input/output delays are missing, do not claim complete interface timing closure.

## I/O DRC warnings

NSTD-1 indicates ports still use a default I/O standard. UCIO-1 indicates ports lack explicit package-pin location assignments. Resolve these only when the actual development board, package pinout, bank voltage and electrical interface are known. Never assign arbitrary pins or I/O standards merely to suppress warnings.

## Power

A vectorless power report is an estimate based on assumed activity. Label it as estimated, state the activity source and confidence level, and do not present it as measured board power.

## Revision discipline

Historical utilization, timing or power numbers from a previous RTL revision must be labelled as historical. Do not attach them to the current source revision unless the implementation flow has been rerun and the reports archived.
