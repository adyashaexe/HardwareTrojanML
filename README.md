# Hardware Trojan Detection using Machine Learning and Power Side-Channel Analysis on FPGA

**Group No:** ECSc_14
**Members:** Adyasha Mohanty, Ayush Anand, Ayushman Mahapatra, Bidisha Jana
**Supervisors:** Professor Swati Swayamsiddha & Professor Kananbala Ray
**School of Electronics Engineering, KIIT Deemed to be University**

---

## 1. What This Project Is

Chips today are designed in one place and fabricated in another, often
untrusted, factory. A bad actor at that factory can secretly insert a
**Hardware Trojan (HT)** — extra malicious circuitry that stays dormant
during normal use and activates only under a rare, attacker-chosen
trigger. Once triggered, it can leak secrets, corrupt data, or disable
the chip.

Normal functional testing can't catch this, because the Trojan behaves
exactly like a clean chip until triggered. This project instead watches
the chip's **power consumption pattern** — even a dormant Trojan draws a
tiny bit of extra power just by existing on the chip — and trains
**machine learning models** to tell a clean circuit apart from a
Trojan-infected one, using only that power signature.

**Target platform:** AES-128 encryption circuit on a Xilinx Artix-7
(Basys3) FPGA.
**Models:** Random Forest, SVM, and a lightweight 1D-CNN.
**End goal:** A working detection framework validated on real hardware,
aimed at an IEEE publication and a patentable detection methodology.

---

## 2. Project Flowchart

![Project Flowchart](project_flowchart.png)

---

## 3. Files You Already Have

All in the `aes_128_verilog` folder:

| File | Purpose |
|---|---|
| `aes_sbox.v` | AES S-box lookup table |
| `key_expansion.v` | Generates 11 round keys from the 128-bit key |
| `aes_transforms.v` | SubBytes, ShiftRows, MixColumns, AddRoundKey |
| `aes_128.v` | **Clean baseline** AES-128 core (verified against FIPS-197) |
| `aes_128_trojan_leak.v` | Trojan variant 1 — rare-pattern trigger, key leak |
| `aes_128_trojan_counter.v` | Trojan variant 2 — time-delayed trigger, output corruption |
| `aes_128_trojan_tiny.v` | Trojan variant 3 — minimal footprint, hardest to detect |
| `tb_aes_128.v` | Testbench (simulation only, checks against FIPS-197 vector) |
| `basys3_top.v` | **Hardware wrapper** — needed because 256 bits of input won't fit on Basys3 switches |
| `basys3_constraints.xdc` | Pin mapping for the Basys3 board |

---

## 4. Step-by-Step: Vivado Workflow

Do this once for the clean baseline, then repeat for each Trojan variant.

### Step A — Create the Vivado project
1. Open Vivado → **File → New Project**.
2. Name it (e.g. `aes_baseline`), choose a project location.
3. Project type: **RTL Project** (don't check "do not specify sources now").
4. Board selection: search **Basys3**, select **Digilent Basys3**. If it's
   not listed, install the board file first (Xilinx board store / Digilent
   vivado-boards repo), or manually select part **xc7a35tcpg236-1**.
5. Finish.

### Step B — Add design sources
1. In the Sources panel: **Add Sources → Add or create design sources**.
2. Add these 5 files (do NOT add the testbench here):
   - `aes_sbox.v`
   - `key_expansion.v`
   - `aes_transforms.v`
   - `aes_128.v` (or the Trojan variant you're testing)
   - `basys3_top.v`
3. If you're testing a Trojan variant instead of the clean baseline,
   open `basys3_top.v` and change the instantiation line from
   `aes_128 dut (...)` to e.g. `aes_128_trojan_leak dut (...)` —
   everything else stays identical.

### Step C — Add the constraints file
1. **Add Sources → Add or create constraints**.
2. Add `basys3_constraints.xdc`.
3. Set `basys3_top` as the **top module** (right-click it in Sources →
   Set as Top).

### Step D — Simulate first (before touching real hardware)
1. Add `tb_aes_128.v` as a **simulation source** (Add Sources →
   Add or create simulation sources), along with the same 5 core files
   (not `basys3_top.v` — the testbench talks to `aes_128` directly).
2. Flow Navigator → **Run Simulation → Run Behavioral Simulation**.
3. Check the Tcl console output — it should print the ciphertext and say
   `PASS: matches FIPS-197 test vector`.
4. **Do not proceed to hardware until this passes.** This step already
   ran successfully outside Vivado (Icarus Verilog) for all 4 core
   variants — Vivado simulation should agree.

### Step E — Synthesis
1. Flow Navigator → **Run Synthesis**.
2. Wait for it to complete → click **Open Synthesized Design** if you
   want to sanity-check the schematic, otherwise just proceed.
3. Fix any critical warnings about unconnected ports before continuing
   (there shouldn't be any with the provided wrapper).

### Step F — Implementation
1. Flow Navigator → **Run Implementation**.
2. This places and routes the design onto the actual FPGA fabric.
3. Check the **Timing Summary** report — you want 0 timing violations
   (WNS should be positive). This design is simple enough that it should
   pass easily at 100 MHz.

### Step G — Generate bitstream
1. Flow Navigator → **Generate Bitstream**.
2. This produces the `.bit` file used to program the physical board.

### Step H — Program the Basys3
1. Connect the Basys3 via USB, power it on.
2. Flow Navigator → **Open Hardware Manager → Open Target → Auto Connect**.
3. **Program Device** → select the generated `.bit` file → Program.
4. On the board:
   - Press **BTNU** once to reset.
   - Press **BTNC** once to start encryption. **LED15** should light up
     when done.
   - Use switches **SW[3:0]** to select which of the 16 ciphertext bytes
     to view on **LED[7:0]** (step through values 0–15).
   - Compare against the known-correct result:
     `69 c4 e0 d8 6a 7b 04 30 d8 cd b7 80 70 b4 c5 5a`
     (byte at SW=0 should read `69`, SW=1 → `c4`, and so on).

### Step I — Repeat for each Trojan variant
For each of `aes_128_trojan_leak.v`, `aes_128_trojan_counter.v`,
`aes_128_trojan_tiny.v`:
1. Either start a new Vivado project, or swap the source file and the
   instantiation line in `basys3_top.v` within the same project.
2. Re-run Steps D through H.
3. **Keep a record of which bitstream corresponds to which variant** —
   you'll be reprogramming the board repeatedly during data collection,
   and mixing them up wastes a data-collection cycle.

---

## 5. Step-by-Step: Power Data Collection

1. Wire the **INA219** power sensor in-line between the power supply and
   the Basys3's power input.
2. Connect INA219 → I2C → Arduino/Raspberry Pi (bridge device).
3. Bridge device → USB → laptop, logging power readings to CSV.
4. For **each** bitstream (clean baseline + each Trojan variant):
   a. Program the board with that bitstream (Step H above).
   b. Trigger many encryption runs (press BTNC repeatedly, or better,
      wire a script/microcontroller to pulse BTNC automatically for
      consistent timing).
   c. Log a power trace for each run — aim for 50–100+ traces per variant.
   d. Save all traces as labeled CSV files, e.g. `clean_run_001.csv`,
      `trojan_leak_run_001.csv`, etc.
5. Keep conditions consistent across all variants (same power source,
   similar ambient temperature, same logging setup) so your model learns
   the Trojan's signature and not session noise.

---

## 6. Step-by-Step: ML Pipeline

1. **Preprocess:** align traces to a common start point, remove obvious
   outliers, optionally reduce dimensionality (PCA).
2. **Train Random Forest and SVM** locally in Python (scikit-learn) —
   fast, CPU-only.
3. **Train the 1D-CNN** on Google Colab (free GPU tier) using the same
   preprocessed data.
4. **Evaluate with leave-one-Trojan-out cross-validation** — train on
   some variants, test on one held-out unseen variant, to prove
   generalization rather than memorization.
5. **Report accuracy, false positive rate, and false negative rate** for
   each model. False negative rate (missed Trojans) is the metric that
   matters most in this field.

---

## 7. Components & Software Needed

| Item | Notes |
|---|---|
| Basys3 (Xilinx Artix-7) FPGA board | ₹8,000–10,000 |
| INA219 current/power sensor module | ₹300–800 |
| USB programming cable | usually included with board |
| Host laptop/PC (min 8GB RAM) | for Vivado + ML training |
| Xilinx Vivado WebPACK | free, for Verilog design/simulation |
| Python 3.x (scikit-learn, TensorFlow/PyTorch, pandas, numpy, matplotlib) | free |
| TrustHub benchmark suite | free, public dataset |

**Total estimated cost:** ₹8,500 – 11,300

---

## 8. Work Distribution

- **Member 1:** ML model development, training, and evaluation.
- **Member 2:** Power trace data acquisition setup and dataset preparation.
- **Member 3:** FPGA circuit design, AES-128 baseline implementation, and Trojan insertion.
- **Member 4:** Result analysis, benchmarking against existing literature, and documentation for publication/patent.

---

## 9. Key Things to Get Right

- **One FPGA is enough.** You reprogram it sequentially per variant —
  no need for multiple boards. Budget real calendar time for this,
  since it's the actual bottleneck, not the ML.
- **Minimum 3 Trojan variants**, ideally 4–6, for leave-one-out
  validation to mean anything.
- **Realistic accuracy target: 85–95%.** If you see 99–100% immediately,
  be suspicious of data leakage between train/test splits before
  celebrating.
- Report **false negative rate** alongside accuracy — it's the metric
  that matters most for this problem.

---

## 10. Where to Read More

1. **UC San Diego/Irvine thesis** (closest match to this exact setup —
   golden AES on FPGA, power traces, logistic regression, 95% accuracy):
   https://escholarship.org/uc/item/7hk8x6rb
2. **"Hardware Trojan Detection Using Machine Learning: A Tutorial,"
   ACM TECS 2023** (Trojan taxonomy, trigger/payload types, detection
   method survey):
   https://scispace.com/pdf/hardware-trojan-detection-using-machine-learning-a-tutorial-1ef00xkq.pdf
3. **"An AI-Enabled Side Channel Power Analysis Based Hardware Trojan
   Detection," arXiv 2024** (compares RF, Gradient Boosting, Neural
   Network, Naive Bayes on Trojans of varying subtlety):
   https://arxiv.org/pdf/2411.12721
4. **Scientific Reports, contrastive learning HT detection framework**
   (good literature-review background on the field's history):
   https://www.nature.com/articles/s41598-024-81473-0

---

## 11. Deliverables Checklist

- [ ] Clean AES-128 baseline (Verilog, verified against FIPS-197)
- [ ] 3+ Trojan variants (Verilog, verified functionally correct when untriggered)
- [ ] Bitstreams generated and tested on real Basys3 hardware for each variant
- [ ] Power trace dataset (labeled, clean + all variants)
- [ ] Preprocessing pipeline (alignment, noise removal, PCA)
- [ ] Trained RF, SVM, CNN models
- [ ] Leave-one-Trojan-out evaluation results (accuracy, FPR, FNR)
- [ ] Comparison table/chart across models
- [ ] Final report / IEEE paper draft
- [ ] Patent filing draft
