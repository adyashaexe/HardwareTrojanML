# Power Data Collection → CSV Pipeline

Three-step pipeline from FPGA power measurement to the CSV format your
ML notebook expects.

## Step 1: Flash the Arduino
Open `ina219_stream.ino` in the Arduino IDE. Install the "Adafruit INA219"
library (Library Manager). Wire INA219 to Arduino (SDA→A4, SCL→A5, VCC→5V,
GND→GND), upload the sketch.

## Step 2: Log a raw session per bitstream
For each variant (clean baseline, then each Trojan), program the Basys3
with that bitstream, then run:

```bash
pip install pyserial pandas numpy --break-system-packages
python log_power_session.py --port COM5 --output clean_session.csv
```

(Replace `COM5` with your actual port — check Arduino IDE's Tools > Port.
On Mac/Linux it looks like `/dev/tty.usbmodem14101` or `/dev/ttyACM0`.)

While it's running: press BTNU to reset, then press BTNC repeatedly
(50-100+ times) to trigger encryptions. Press Ctrl+C when done. Repeat for
every variant with a different `--output` filename:

```bash
python log_power_session.py --port COM5 --output trojan_leak_session.csv
python log_power_session.py --port COM5 --output trojan_counter_session.csv
python log_power_session.py --port COM5 --output trojan_tiny_session.csv
```

## Step 3: Segment each session into individual traces
```bash
python segment_traces.py --input clean_session.csv --label clean --output clean_traces.csv
python segment_traces.py --input trojan_leak_session.csv --label trojan --output trojan_leak_traces.csv
python segment_traces.py --input trojan_counter_session.csv --label trojan --output trojan_counter_traces.csv
python segment_traces.py --input trojan_tiny_session.csv --label trojan --output trojan_tiny_traces.csv
```

Check the printed "Detected N traces" count against how many times you
actually pressed BTNC. If it's way off, adjust `--threshold-multiplier`
(lower = more sensitive) or `--window-size` (should roughly match how long
one encryption's power spike lasts in samples).

**Tip:** if you want the fine-grained `trojan_variant` column needed for
leave-one-Trojan-out CV (see the training notebook, Section 7), use a more
specific `--label` per variant instead of just "trojan", e.g.
`--label trojan_leak`, then derive the binary clean/trojan column
afterward in pandas.

## Step 4: Combine into one CSV for training
```python
import pandas as pd
combined = pd.concat([
    pd.read_csv("clean_traces.csv"),
    pd.read_csv("trojan_leak_traces.csv"),
    pd.read_csv("trojan_counter_traces.csv"),
    pd.read_csv("trojan_tiny_traces.csv"),
], ignore_index=True)
combined.to_csv("all_traces.csv", index=False)
```

This `all_traces.csv` is what you point the training notebook at
(`target_column="label"`, `trace_column="power_trace"`).

## Tested
`segment_traces.py`'s spike-detection logic was tested against synthetic
data with 10 known spikes and correctly detected all 10 — the logic works,
but real INA219 data will need threshold/window tuning since real spikes
won't be as clean as the synthetic test.
