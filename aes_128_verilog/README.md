
# AES-128 Hardware Trojan Detection and Analysis on FPGA

A Verilog-based AES-128 encryption implementation with multiple hardware Trojan variants, designed for simulation, FPGA deployment, and hardware-level power analysis using the Digilent Basys3 FPGA board.

## Project Overview

This project implements the AES-128 encryption algorithm and integrates multiple hardware Trojan variants to study their impact on:

- Functional correctness
- FPGA resource utilization
- Timing performance
- Power consumption
- Hardware security

The project uses Icarus Verilog for simulation and AMD Xilinx Vivado for FPGA synthesis, implementation, and bitstream generation.

## Hardware Requirements

- Digilent Basys3 FPGA Development Board
- Artix-7 XC7A35T FPGA
- Micro-USB cable
- INA219 power monitoring sensor (for external power measurements)

## Software Requirements

| Software | Purpose |
|---|---|
| Icarus Verilog | Verilog simulation |
| GTKWave | Waveform visualization |
| AMD Xilinx Vivado | FPGA synthesis and implementation |
| Git | Version control |

**Supported operating systems:**
- Windows
- Linux
- macOS (simulation only; Vivado does not run natively)

## Project Structure

```text
AES-Trojan-FPGA/
│
├── aes_sbox.v
├── key_expansion.v
├── aes_transforms.v
├── aes_128.v
│
├── aes_128_trojan_leak.v
├── aes_128_trojan_counter.v
├── aes_128_trojan_tiny.v
├── aes_128_trojan_drain.v
├── aes_128_trojan_burst.v
├── aes_128_trojan_hamming.v
│
├── basys3_top_v2.v
│
├── tb_aes_128.v
├── tb_new_trojans.v
│
├── Basys3_Master.xdc
├── build.tcl
│
└── README.md
```

## 1. Install Dependencies

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install iverilog gtkwave
```

### macOS

```bash
brew install icarus-verilog gtkwave
```

### Windows

Install Icarus Verilog and GTKWave using their Windows distributions.

### Install Vivado

1. Visit the AMD Xilinx website.
2. Download the Vivado Unified Installer.
3. Create or sign in to your AMD account.
4. Select Vivado ML Standard Edition.
5. Select the Artix-7 device family.
6. Complete the installation.

Vivado installation may require approximately 40 GB or more of available storage.

## 2. Simulate AES-128 Using Icarus Verilog

Navigate to the project directory:

```bash
cd AES-Trojan-FPGA
```

Compile the AES modules and testbench:

```bash
iverilog -o sim.out \
aes_sbox.v \
key_expansion.v \
aes_transforms.v \
aes_128.v \
tb_aes_128.v
```

Run the simulation:

```bash
vvp sim.out
```

### Expected Output

For the standard AES-128 test vector:

**Plaintext:**
```text
00112233445566778899aabbccddeeff
```

**Key:**
```text
000102030405060708090a0b0c0d0e0f
```

**Expected Ciphertext:**
```text
69c4e0d86a7b0430d8cdb78070b4c55a
```

The generated ciphertext should match the expected AES-128 result.

## 3. View Simulation Waveforms

Add the following statements inside the testbench initial block:

```verilog
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_aes_128);
end
```

Recompile and execute:

```bash
iverilog -o sim.out \
aes_sbox.v \
key_expansion.v \
aes_transforms.v \
aes_128.v \
tb_aes_128.v

vvp sim.out
```

Open GTKWave:

```bash
gtkwave wave.vcd
```

Inspect important signals:

- Clock
- Reset
- Start
- Done
- Plaintext
- Ciphertext

## 4. Simulate Hardware Trojan Variants

Compile the Trojan testbench with all required source modules.

```bash
iverilog -o trojan_sim.out \
aes_sbox.v \
key_expansion.v \
aes_transforms.v \
aes_128.v \
aes_128_trojan_leak.v \
aes_128_trojan_counter.v \
aes_128_trojan_tiny.v \
aes_128_trojan_drain.v \
aes_128_trojan_burst.v \
aes_128_trojan_hamming.v \
tb_new_trojans.v
```

Run:

```bash
vvp trojan_sim.out
```

Check the testbench results for each Trojan variant.

## 5. Create the Vivado Project

1. Open AMD Xilinx Vivado.
2. Select **Create Project**.
3. Enter the project name.
4. Select RTL Project.
5. Choose Do not specify sources at this time.
6. Select the FPGA part:

```text
xc7a35tcpg236-1
```

7. Finish project creation.

### Add Design Sources

Add the following files:

```text
aes_sbox.v
key_expansion.v
aes_transforms.v
aes_128.v
aes_128_trojan_leak.v
aes_128_trojan_counter.v
aes_128_trojan_tiny.v
aes_128_trojan_drain.v
aes_128_trojan_burst.v
aes_128_trojan_hamming.v
basys3_top_v2.v
```

### Add Simulation Sources

```text
tb_aes_128.v
tb_new_trojans.v
```

### Add Constraints

Add the Digilent Basys3 master XDC constraints file.

Set the design top module:

```text
basys3_top_v2
```

## 6. Configure FPGA Constraints

Edit the Basys3 XDC file and uncomment only the required pin assignments.

Example clock constraint:

```tcl
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]

create_clock -add -name sys_clk_pin \
-period 10.00 \
-waveform {0 5} [get_ports clk]
```

Ensure that:

- Every required top-level input has a pin assignment.
- Every required top-level output has a pin assignment.
- Port names match the Verilog module exactly.
- The clock constraint matches the intended operating frequency.

The example clock constraint specifies 100 MHz.

## 7. Configure Trojan Variants

The project uses a configurable parameter:

```verilog
parameter VARIANT = 0;
```

Change the value to select a different implementation.

```verilog
parameter VARIANT = 4;
```

The supported parameter values are:

| VARIANT | Configuration |
|---|---|
| 0 | Clean AES implementation |
| 1–6 | Trojan configurations |

Refer to the variant mapping comments in `basys3_top_v2.v` for the exact Trojan-to-number mapping.

You can configure this parameter in Vivado under:

```text
Settings → General → Generics/Parameters
```

Add:

```text
Name: VARIANT
Value: 4
```

## 8. Run Synthesis

In Vivado:

1. Select Run Synthesis.
2. Wait for synthesis to complete.
3. Open Synthesized Design.
4. Open Report Utilization.

Record:

- LUT utilization
- Flip-flop utilization
- Slice utilization
- Total FPGA resource usage

Check the Messages tab for errors, latch warnings, and multiple-driver warnings.

## 9. Run Implementation

Select:

```text
Run Implementation
```

Vivado performs:

- Optimization
- Placement
- Routing

After implementation, generate the following reports:

### Timing Report

Check:

- Worst Negative Slack (WNS)
- Total Negative Slack (TNS)
- Clock timing performance

A non-negative WNS indicates that the reported timing constraints have been met.

### Utilization Report

Record:

- LUTs
- Flip-flops
- Slices

### Power Report

Record:

- Total estimated power
- Dynamic power
- Static power

Save reports separately for each variant.

Example:

```text
util_clean.txt
util_leak.txt
util_counter.txt
util_tiny.txt
util_drain.txt
util_burst.txt
util_hamming.txt
```

## 10. Generate FPGA Bitstream

In Vivado:

1. Select Generate Bitstream.
2. Wait for completion.
3. Open Hardware Manager.

If Vivado reports UCIO-1 or NSTD-1 errors, check the XDC pin assignments and I/O standards.

## 11. Program the Basys3 FPGA

1. Connect the Basys3 board to your computer using a micro-USB cable.
2. Turn on the board.
3. Ensure the JP1 jumper is configured for JTAG.
4. Open Vivado Hardware Manager.
5. Select Open Target.
6. Choose Auto Connect.
7. Select Program Device.
8. Choose the generated `.bit` file.
9. Click Program.

The FPGA should now execute the selected design.

To switch variants, change the VARIANT parameter and rebuild the bitstream.

## 12. Automate Builds Using Tcl

Create a file named `build.tcl`.

```tcl
set variant 4

create_project aes_trojan ./proj \
-part xc7a35tcpg236-1 -force

add_files {
    aes_sbox.v
    key_expansion.v
    aes_transforms.v
    aes_128.v
    aes_128_trojan_leak.v
    aes_128_trojan_counter.v
    aes_128_trojan_tiny.v
    aes_128_trojan_drain.v
    aes_128_trojan_burst.v
    aes_128_trojan_hamming.v
    basys3_top_v2.v
}

add_files -fileset constrs_1 Basys3_Master.xdc

set_property top basys3_top_v2 [current_fileset]

set_property generic "VARIANT=$variant" [current_fileset]

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

open_run impl_1

report_utilization -file util_v$variant.txt

report_timing_summary \
-file timing_v$variant.txt

report_power -file power_v$variant.txt
```

Execute:

```bash
vivado -mode batch -source build.tcl
```

Change the variant value before rebuilding.

## 13. Performance Analysis

Compare the clean AES implementation against the Trojan-infected implementations.

Suggested evaluation parameters:

| Parameter | Evaluation |
|---|---|
| Functional Correctness | AES encryption output |
| Area Overhead | LUT and FF utilization |
| Timing Overhead | WNS and TNS |
| Power Overhead | Estimated FPGA power |
| Hardware Behaviour | Trojan activation and effects |

### Area Overhead

Calculate the percentage increase in FPGA resource utilization:

```text
Area Overhead (%) =
((Trojan Area - Clean Area) / Clean Area) * 100
```

### Power Overhead

```text
Power Overhead (%) =
((Trojan Power - Clean Power) / Clean Power) * 100
```

Use consistent measurement conditions when comparing variants.

## 14. Common Errors and Troubleshooting

| Error | Possible Solution |
|---|---|
| Module not found | Check whether all Verilog files are added |
| UCIO-1 | Assign missing FPGA pins |
| NSTD-1 | Specify the correct I/O standard |
| Negative WNS | Inspect timing constraints and critical paths |
| FPGA not detected | Check USB connection, board power and JTAG |
| Unknown X values | Check reset and testbench input initialization |
| Incorrect Trojan variant | Verify VARIANT and rebuild the bitstream |
| Simulation compilation failure | Check module names and dependencies |

## 15. Recommended Execution Workflow

Follow this order:

1. Simulate the clean AES-128 implementation.
2. Verify the expected ciphertext.
3. Simulate the Trojan variants.
4. Create the Vivado project.
5. Configure the Basys3 XDC file.
6. Build the clean implementation (VARIANT 0).
7. Program and test the FPGA.
8. Build each Trojan variant.
9. Collect utilization, timing, and power reports.
10. Compare the results.
11. Perform external power measurements using the INA219, if configured.

## Tools and Technologies

- Verilog HDL
- AES-128 Encryption
- Icarus Verilog
- GTKWave
- AMD Xilinx Vivado
- Artix-7 FPGA
- Digilent Basys3
- Tcl Automation
- INA219 Power Monitoring

## Project Objective

The primary objective is to investigate the effects of hardware Trojans on an AES-128 cryptographic implementation through RTL simulation, FPGA implementation, resource utilization analysis, timing analysis, and power measurements.

The project provides an experimental platform for understanding hardware security threats and evaluating their impact on FPGA-based cryptographic systems.

---

**Note:** Verify the exact Trojan variant mapping and top-level ports against the actual Verilog source files before running synthesis or generating the bitstream.
