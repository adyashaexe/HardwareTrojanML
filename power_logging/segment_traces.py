"""
segment_traces.py
-------------------
Takes a raw continuous power-log session CSV (from log_power_session.py)
and cuts it into individual per-encryption traces, saving the result in
the label,power_trace format the training notebook expects.

How it works:
  1. Reads the continuous power_mW column.
  2. Finds rising edges above a baseline threshold (each button press /
     encryption causes a spike above idle power).
  3. Cuts a fixed-length window starting at each detected spike.
  4. Saves one row per detected trace: label, power_trace (as a JSON list).

Usage:
    python segment_traces.py --input clean_session.csv --label clean --output clean_traces.csv
    python segment_traces.py --input trojan_leak_session.csv --label trojan --output trojan_leak_traces.csv

Then combine all the per-variant *_traces.csv files into one combined CSV
before feeding into the training notebook (see combine step at the bottom
of this file's usage notes).

Tune --threshold and --window if detection misses spikes or cuts them short --
run once, check the printed count of detected traces against how many times
you actually pressed BTNC, and adjust.
"""

import argparse
import json

import numpy as np
import pandas as pd


def segment_traces(
    df: pd.DataFrame,
    threshold_multiplier: float = 1.5,
    window_size: int = 100,
    min_gap: int = 50,
) -> list[list[float]]:
    """Detect rising-edge spikes in power_mW and cut fixed-length windows.

    threshold_multiplier: spike must exceed baseline_mean * this value
    window_size: number of samples to keep per trace, starting at the spike
    min_gap: minimum samples between two detected spikes (avoids double-counting one encryption)
    """
    power = df["power_mW"].to_numpy()
    baseline = np.median(power)  # median is robust to the spikes themselves
    threshold = baseline * threshold_multiplier

    traces = []
    i = 0
    last_spike = -min_gap
    while i < len(power) - window_size:
        if power[i] > threshold and (i - last_spike) >= min_gap:
            trace = power[i : i + window_size].tolist()
            traces.append(trace)
            last_spike = i
            i += window_size  # skip past this trace before looking for the next spike
        else:
            i += 1

    return traces


def main():
    parser = argparse.ArgumentParser(description="Segment a raw power session into individual traces.")
    parser.add_argument("--input", required=True, help="Raw session CSV from log_power_session.py")
    parser.add_argument("--label", required=True, help="Label for every trace in this file, e.g. clean or trojan")
    parser.add_argument("--output", required=True, help="Output CSV in label,power_trace format")
    parser.add_argument("--threshold-multiplier", type=float, default=1.5, help="Spike must exceed baseline * this value")
    parser.add_argument("--window-size", type=int, default=100, help="Samples per trace")
    parser.add_argument("--min-gap", type=int, default=50, help="Minimum samples between detected spikes")
    args = parser.parse_args()

    df = pd.read_csv(args.input)
    if "power_mW" not in df.columns:
        raise ValueError(f"Expected a 'power_mW' column in {args.input}, found: {list(df.columns)}")

    traces = segment_traces(
        df,
        threshold_multiplier=args.threshold_multiplier,
        window_size=args.window_size,
        min_gap=args.min_gap,
    )

    print(f"Detected {len(traces)} traces in {args.input}")
    if len(traces) == 0:
        print("No traces detected -- try lowering --threshold-multiplier, or check the raw CSV has real spikes.")
        return

    out_df = pd.DataFrame({
        "label": [args.label] * len(traces),
        "power_trace": [json.dumps(t) for t in traces],
    })
    out_df.to_csv(args.output, index=False)
    print(f"Saved to {args.output}")


if __name__ == "__main__":
    main()
