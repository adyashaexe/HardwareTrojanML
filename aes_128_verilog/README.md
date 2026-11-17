
# AES-128 Hardware Trojan Detection and FPGA Analysis

A step-by-step Verilog project implementing AES-128 encryption and multiple hardware Trojan variants. This project demonstrates RTL simulation, waveform analysis, FPGA synthesis, implementation, bitstream generation, and power analysis using the Digilent Basys3 FPGA board.

---

# Table of Contents

1. Project Overview
2. Hardware and Software Requirements
3. Project Directory Structure
4. Installing Verilog Tools
5. Setting Up the Project
6. Understanding Verilog Files
7. Writing and Running Your First Verilog Program
8. Simulating AES-128
9. Viewing Waveforms Using GTKWave
10. Simulating Hardware Trojan Variants
11. Setting Up Vivado
12. Creating a Vivado Project
13. Adding Verilog Source Files
14. Configuring FPGA Constraints
15. Selecting Trojan Variants
16. Running Synthesis
17. Running Implementation
18. Generating the Bitstream
19. Programming the Basys3 FPGA
20. Power and Performance Analysis
21. Automating Builds Using Tcl
22. Troubleshooting

---

# 1. Project Overview

The objective of this project is to investigate the effects of hardware Trojans on an AES-128 cryptographic implementation.

The project evaluates:

- Functional correctness of AES encryption.
- Hardware Trojan activation and behaviour.
- FPGA resource utilization.
- Timing performance.
- Estimated power consumption.
- External power measurements using INA219.

The implementation uses Verilog HDL and targets the Artix-7 FPGA on the Digilent Basys3 development board.

# 2. Hardware and Software Requirements

## Hardware Requirements

- Digilent Basys3 FPGA Development Board.
- Artix-7 XC7A35T FPGA.
- Micro-USB cable.
- INA219 power monitoring sensor (for external measurements).

## Software Requirements

| Software | Purpose |
|---|---|
| Visual Studio Code | Writing and editing Verilog |
| Icarus Verilog | Compiling and simulating Verilog |
| GTKWave | Viewing simulation waveforms |
| AMD Xilinx Vivado | FPGA synthesis and implementation |
| Git | Version control |

**Operating System Compatibility**

- macOS: Verilog simulation using Icarus Verilog and GTKWave.
- Windows: Verilog simulation and Vivado.
- Linux: Verilog simulation and Vivado.

Vivado does not run natively on macOS. Use a supported Windows/Linux computer or college laboratory PC for FPGA implementation.

# 3. Project Directory Structure

Organize the project as follows:

```text
AES-Trojan-FPGA/
│
├── rtl/
│   ├── aes_sbox.v
│   ├── key_expansion.v
│   ├── aes_transforms.v
│   ├── aes_128.v
│   │
│   ├── aes_128_trojan_leak.v
│   ├── aes_128_trojan_counter.v
│   ├── aes_128_trojan_tiny.v
│   ├── aes_128_trojan_drain.v
│   ├── aes_128_trojan_burst.v
│   ├── aes_128_trojan_hamming.v
│   │
│   └── basys3_top_v2.v
│
├── testbench/
│   ├── tb_aes_128.v
│   └── tb_new_trojans.v
│
├── simulation/
│
├── reports/
│
├── constraints/
│   └── Basys3_Master.xdc
│
├── build.tcl
└── README.md
```

Place each existing source file in its corresponding folder. Update file paths in compilation commands accordingly.

# 4. Installing Verilog Tools

## Step 1: Install Visual Studio Code

1. Visit https://code.visualstudio.com/
2. Download Visual Studio Code.
3. Install the application.
4. Open VS Code.
5. Install a Verilog/SystemVerilog syntax-highlighting extension.

## Step 2: Install Homebrew (macOS)

Open Terminal and execute:

```bash
brew --version
```

If Homebrew is not installed, install it using:

https://brew.sh/

## Step 3: Install Icarus Verilog and GTKWave

Execute:

```bash
brew install icarus-verilog gtkwave
```

Verify the installation:

```bash
iverilog -V
gtkwave --version
```

For Ubuntu/Linux:

```bash
sudo apt update
sudo apt install iverilog gtkwave
```

For Windows, install the Icarus Verilog Windows distribution and GTKWave.

# 5. Setting Up the Project

## Step 1: Create the project directory

Open Terminal:

```bash
mkdir AES-Trojan-FPGA
cd AES-Trojan-FPGA
```

Create the required folders:

```bash
mkdir rtl testbench simulation reports constraints
```

## Step 2: Open the project in VS Code

Execute:

```bash
code .
```

Alternatively, open VS Code and select:

File → Open Folder → AES-Trojan-FPGA

## Step 3: Add the Verilog source files

Copy the existing Verilog files into the appropriate folders.

Ensure that all required files are present before compiling.

# 6. Understanding Verilog Files

Before executing the project, understand the purpose of each Verilog module.

| File | Description |
|---|---|
| aes_sbox.v | Implements AES substitution operations |
| key_expansion.v | Generates round keys |
| aes_transforms.v | Implements AES transformations |
| aes_128.v | Main AES-128 encryption module |
| aes_128_trojan_leak.v | Trojan implementation |
| aes_128_trojan_counter.v | Trojan implementation |
| aes_128_trojan_tiny.v | Trojan implementation |
| aes_128_trojan_drain.v | Trojan implementation |
| aes_128_trojan_burst.v | Trojan implementation |
| aes_128_trojan_hamming.v | Trojan implementation |
| basys3_top_v2.v | FPGA top-level wrapper |
| tb_aes_128.v | AES testbench |
| tb_new_trojans.v | Trojan testbench |

## Understanding a Verilog Module

A Verilog module describes a hardware component.

Example:

```verilog
module and_gate(
    input a,
    input b,
    output y
);

assign y = a & b;

endmodule
```

Here:

- `module` defines the hardware component.
- `input` specifies incoming signals.
- `output` specifies outgoing signals.
- `assign` describes continuous logic.
- `endmodule` terminates the module.

## Understanding a Testbench

A testbench is used to provide input signals and verify the behaviour of a hardware module.

Example:

```verilog
module tb_and_gate;

reg a, b;
wire y;

and_gate uut (
    .a(a),
    .b(b),
    .y(y)
);

initial begin

    $monitor("a=%b b=%b y=%b", a, b, y);

    a = 0; b = 0;
    #10;

    a = 0; b = 1;
    #10;

    a = 1; b = 0;
    #10;

    a = 1; b = 1;
    #10;

    $finish;

end

endmodule
```

# 7. Writing and Running Your First Verilog Program

Before executing AES, test whether your Verilog environment works.

## Step 1: Create a Verilog file

Create:

```text
and_gate.v
```

Add:

```verilog
module and_gate(
    input a,
    input b,
    output y
);

assign y = a & b;

endmodule
```

## Step 2: Create the testbench

Create:

```text
tb_and_gate.v
```

Add:

```verilog
module tb_and_gate;

reg a, b;
wire y;

and_gate uut (
    .a(a),
    .b(b),
    .y(y)
);

initial begin

    $monitor("a=%b b=%b y=%b", a, b, y);

    a = 0; b = 0;
    #10;

    a = 0; b = 1;
    #10;

    a = 1; b = 0;
    #10;

    a = 1; b = 1;
    #10;

    $finish;

end

endmodule
```

## Step 3: Compile the program

Open Terminal in the directory containing both files.

Execute:

```bash
iverilog -o test and_gate.v tb_and_gate.v
```

## Step 4: Run the simulation

Execute:

```bash
vvp test
```

Expected output:

```text
a=0 b=0 y=0
a=0 b=1 y=0
a=1 b=0 y=0
a=1 b=1 y=1
```

This confirms that Icarus Verilog is working correctly.

# 8. Simulating AES-128

After successfully testing the basic Verilog program, proceed to AES-128 simulation.

## Step 1: Open the AES source files

Ensure that these files exist:

```text
rtl/aes_sbox.v
rtl/key_expansion.v
rtl/aes_transforms.v
rtl/aes_128.v
```

Also ensure that the testbench exists:

```text
testbench/tb_aes_128.v
```

## Step 2: Compile AES-128

Execute:

```bash
iverilog -o aes_sim \
rtl/aes_sbox.v \
rtl/key_expansion.v \
rtl/aes_transforms.v \
rtl/aes_128.v \
testbench/tb_aes_128.v
```

## Step 3: Execute the simulation

```bash
vvp aes_sim
```

## Step 4: Verify the encryption result

Use the standard AES-128 test vector.

**Plaintext:**

```text
00112233445566778899aabbccddeeff
```

**Encryption Key:**

```text
000102030405060708090a0b0c0d0e0f
```

**Expected Ciphertext:**

```text
69c4e0d86a7b0430d8cdb78070b4c55a
```

The ciphertext printed by the testbench must match the expected result.

Do not proceed to FPGA implementation until the clean AES implementation passes simulation.

# 9. Viewing Waveforms Using GTKWave

Waveforms help visualize how signals change during simulation.

## Step 1: Modify the testbench

Open:

```text
testbench/tb_aes_128.v
```

Inside the testbench, add the following statements inside its initial block:

```verilog
$dumpfile("simulation/aes_wave.vcd");
$dumpvars(0, tb_aes_128);
```

## Step 2: Recompile AES

```bash
iverilog -o aes_sim \
rtl/aes_sbox.v \
rtl/key_expansion.v \
rtl/aes_transforms.v \
rtl/aes_128.v \
testbench/tb_aes_128.v
```

## Step 3: Generate waveform data

```bash
vvp aes_sim
```

This generates:

```text
simulation/aes_wave.vcd
```

## Step 4: Open GTKWave

```bash
gtkwave simulation/aes_wave.vcd
```

## Step 5: Inspect the signals

In GTKWave:

1. Locate the testbench module in the left signal hierarchy.
2. Expand the module.
3. Select the signals.
4. Click Append.
5. Use Zoom Fit to display the complete simulation.

Important signals to inspect:

- Clock
- Reset
- Start
- Done
- Plaintext
- Ciphertext

# 10. Simulating Hardware Trojan Variants

After verifying clean AES, simulate the Trojan implementations.

## Step 1: Check the Trojan source files

Ensure all six Trojan modules are present in the `rtl` folder.

## Step 2: Compile the Trojan testbench

Execute:

```bash
iverilog -o trojan_sim \
rtl/aes_sbox.v \
rtl/key_expansion.v \
rtl/aes_transforms.v \
rtl/aes_128.v \
rtl/aes_128_trojan_leak.v \
rtl/aes_128_trojan_counter.v \
rtl/aes_128_trojan_tiny.v \
rtl/aes_128_trojan_drain.v \
rtl/aes_128_trojan_burst.v \
rtl/aes_128_trojan_hamming.v \
testbench/tb_new_trojans.v
```

## Step 3: Run the simulation

```bash
vvp trojan_sim
```

## Step 4: Verify the results

Check the simulation output for:

- Correct module instantiation.
- Trojan activation conditions.
- Expected behaviour of each variant.
- Differences between clean and Trojan-infected designs.

The exact expected output depends on the implementation and testbench.

# 11. Setting Up Vivado

Vivado is used to convert the Verilog design into an FPGA-compatible bitstream.

**Important:** Vivado does not run natively on macOS.

Use a supported Windows/Linux system or your college FPGA laboratory computer.

## Step 1: Download Vivado

Visit:

https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html

## Step 2: Install Vivado

1. Download the AMD Unified Installer.
2. Sign in using your AMD account.
3. Select Vivado ML Standard Edition.
4. Select the Artix-7 device family.
5. Complete the installation.

## Step 3: Select the FPGA device

The Basys3 uses:

```text
xc7a35tcpg236-1
```

Ensure that the Artix-7 device family is installed.

# 12. Creating a Vivado Project

## Step 1: Open Vivado

Launch Vivado and select:

```text
Create Project
```

## Step 2: Enter project details

Enter:

```text
Project Name: AES_Trojan_FPGA
```

Choose a project location without spaces in its path.

Enable:

```text
Create project subdirectory
```

Click Next.

## Step 3: Select project type

Choose:

```text
RTL Project
```

Select:

```text
Do not specify sources at this time
```

Click Next.

## Step 4: Select FPGA device

Choose Parts and search:

```text
xc7a35tcpg236-1
```

Select the device and click Finish.

# 13. Adding Verilog Source Files

## Step 1: Add design sources

In Vivado:

1. Open Flow Navigator.
2. Select Add Sources.
3. Choose Add or Create Design Sources.
4. Click Add Files.
5. Select all AES and Trojan source files.
6. Add `basys3_top_v2.v`.
7. Click Finish.

## Step 2: Add simulation sources

Select Add Sources again.

Choose:

```text
Add or Create Simulation Sources
```

Add:

```text
tb_aes_128.v
tb_new_trojans.v
```

## Step 3: Add constraints

Select Add Sources.

Choose:

```text
Add or Create Constraints
```

Add:

```text
Basys3_Master.xdc
```

## Step 4: Set the top module

In the Sources panel:

1. Locate `basys3_top_v2`.
2. Right-click the module.
3. Select Set as Top.

The module should appear in bold.

# 14. Configuring FPGA Constraints

The XDC file maps Verilog input/output ports to physical FPGA pins.

## Step 1: Open the XDC file

Open:

```text
Basys3_Master.xdc
```

## Step 2: Configure the clock

The Basys3 onboard clock uses pin W5.

Example:

```tcl
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]

create_clock -add -name sys_clk_pin \
-period 10.00 \
-waveform {0 5} [get_ports clk]
```

## Step 3: Configure remaining pins

Uncomment and configure the required:

- Push buttons.
- Switches.
- LEDs.
- Additional output pins.

The names in the XDC file must match the actual top-level Verilog ports.

For example, if your Verilog module declares:

```verilog
input clk;
```

The corresponding XDC constraint must reference:

```tcl
[get_ports clk]
```

Check the actual port names in `basys3_top_v2.v` before editing the constraints.

# 15. Selecting Trojan Variants

The FPGA top-level module uses a configurable parameter named `VARIANT`.

Example:

```verilog
parameter VARIANT = 0;
```

The project supports seven configurations.

| Variant | Configuration |
|---|---|
| 0 | Clean AES |
| 1–6 | Trojan variants |

Refer to the mapping comments in `basys3_top_v2.v` for the exact assignment of each Trojan.

## Changing the variant in Verilog

Example:

```verilog
parameter VARIANT = 4;
```

## Changing the variant in Vivado

Navigate to:

```text
Settings → General → Generics/Parameters
```

Add:

```text
Name: VARIANT
Value: 4
```

Apply the changes.

# 16. Running Synthesis

Synthesis converts Verilog RTL into a gate-level representation.

## Steps

1. Open Vivado.
2. Verify that `basys3_top_v2` is the design top.
3. Verify that the XDC file is included.
4. Select Run Synthesis.
5. Click OK.
6. Wait for synthesis to finish.
7. Open Synthesized Design.

## Check utilization

Navigate to:

```text
Reports → Report Utilization
```

Record:

- LUTs.
- Flip-flops.
- Slices.
- Other relevant FPGA resources.

Inspect the Messages tab for errors and warnings.

# 17. Running Implementation

Implementation performs optimization, placement and routing.

## Steps

1. Select Run Implementation.
2. Click OK.
3. Wait for completion.
4. Open Implemented Design.

## Generate reports

### Timing Summary

Navigate to:

```text
Reports → Timing → Report Timing Summary
```

Check:

- WNS (Worst Negative Slack).
- TNS (Total Negative Slack).
- Timing constraints.

A non-negative WNS indicates that the analyzed timing requirements are met.

### Utilization Report

Record LUT and flip-flop utilization.

### Power Report

Navigate to:

```text
Reports → Report Power
```

Record:

- Total estimated power.
- Dynamic power.
- Static power.

Save each report in the `reports` folder.

# 18. Generating the Bitstream

After successful implementation:

1. Select Generate Bitstream.
2. Click OK.
3. Wait for generation to finish.
4. Check the Messages tab.
5. Resolve any remaining errors.

The generated bitstream will normally be located at:

```text
AES_Trojan_FPGA.runs/impl_1/basys3_top_v2.bit
```

# 19. Programming the Basys3 FPGA

## Step 1: Connect the board

1. Connect the Basys3 to your computer using a micro-USB cable.
2. Turn on the board.
3. Check that the JP1 jumper is configured for JTAG.

## Step 2: Open Hardware Manager

In Vivado:

```text
Open Hardware Manager
```

Select:

```text
Open Target → Auto Connect
```

## Step 3: Program the device

1. Select Program Device.
2. Select the FPGA device `xc7a35t_0`.
3. Select the generated `.bit` file.
4. Click Program.

After successful programming, the FPGA executes the selected design.

To test another variant, change the VARIANT parameter and rebuild the design.

# 20. Power and Performance Analysis

Compare the clean AES implementation with each Trojan implementation.

Record the following parameters:

| Parameter | Measurement |
|---|---|
| Functional correctness | Encryption output |
| Area utilization | LUTs and flip-flops |
| Timing performance | WNS and TNS |
| Estimated power | Vivado power report |
| External power | INA219 measurements, if configured |

## Area Overhead

```text
Area Overhead (%) =
((Trojan Area - Clean Area) / Clean Area) * 100
```

## Power Overhead

```text
Power Overhead (%) =
((Trojan Power - Clean Power) / Clean Power) * 100
```

Use the same measurement conditions for all variants.

# 21. Automating Builds Using Tcl

Create:

```text
build.tcl
```

Example:

```tcl
set variant 4

create_project aes_trojan ./proj \
-part xc7a35tcpg236-1 -force

add_files {
    rtl/aes_sbox.v
    rtl/key_expansion.v
    rtl/aes_transforms.v
    rtl/aes_128.v
    rtl/aes_128_trojan_leak.v
    rtl/aes_128_trojan_counter.v
    rtl/aes_128_trojan_tiny.v
    rtl/aes_128_trojan_drain.v
    rtl/aes_128_trojan_burst.v
    rtl/aes_128_trojan_hamming.v
    rtl/basys3_top_v2.v
}

add_files -fileset constrs_1 constraints/Basys3_Master.xdc

set_property top basys3_top_v2 [current_fileset]

set_property generic "VARIANT=$variant" [current_fileset]

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

open_run impl_1

report_utilization -file reports/util_v$variant.txt

report_timing_summary \
-file reports/timing_v$variant.txt

report_power -file reports/power_v$variant.txt
```

Execute the script from the project root using:

```bash
vivado -mode batch -source build.tcl
```

Change the variant number before each build.

# 22. Troubleshooting

| Problem | Solution |
|---|---|
| Module not found | Check whether all source files are included |
| Compilation error | Check module names, syntax and dependencies |
| Unknown X values | Check reset and testbench inputs |
| Incorrect ciphertext | Verify AES logic and testbench inputs |
| UCIO-1 | Add missing pin assignments |
| NSTD-1 | Configure the required I/O standards |
| Negative WNS | Inspect clock constraints and critical paths |
| Board not detected | Check USB, power, JTAG and cable drivers |
| Wrong variant | Verify VARIANT and rebuild the bitstream |
| Missing waveform | Check `$dumpfile` and `$dumpvars` |

---

# Recommended Execution Order

Follow this sequence to complete the project:

- [ ] Install VS Code, Icarus Verilog and GTKWave.
- [ ] Create the project directory.
- [ ] Understand the AES Verilog modules.
- [ ] Write and simulate a basic Verilog program.
- [ ] Compile the clean AES-128 design.
- [ ] Verify the expected ciphertext.
- [ ] Generate and inspect GTKWave waveforms.
- [ ] Simulate all Trojan variants.
- [ ] Set up Vivado on Windows/Linux.
- [ ] Create the Vivado project.
- [ ] Add design, simulation and constraint files.
- [ ] Configure the Basys3 pin assignments.
- [ ] Build the clean AES implementation.
- [ ] Program the Basys3 FPGA.
- [ ] Build each Trojan variant.
- [ ] Collect utilization, timing and power reports.
- [ ] Perform external power measurements, if configured.
- [ ] Compare clean and Trojan implementations.

---

# Project Objective

This project provides an experimental platform for studying hardware security threats in AES-128 cryptographic implementations.

By combining Verilog simulation, FPGA implementation, resource utilization analysis, timing analysis and power measurements, the project investigates how hardware Trojans can affect the behaviour and physical characteristics of cryptographic hardware.

**Technologies:** Verilog HDL | AES-128 | Icarus Verilog | GTKWave | AMD Xilinx Vivado | Artix-7 FPGA | Basys3 | Tcl | INA219

**Important:** Always verify the actual module names, port definitions, Trojan variant mapping and testbench dependencies in the source code before compiling or generating the FPGA bitstream.
