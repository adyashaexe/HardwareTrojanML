"""
log_power_session.py
---------------------
Connects to the Arduino over serial and logs every INA219 reading to a CSV
file, continuously, until you press Ctrl+C. This is a RAW session log --
one row per sample, not yet split into individual per-encryption traces.

Usage:
    python log_power_session.py --port COM5 --output clean_session.csv
    (on Mac/Linux, port looks like /dev/tty.usbmodem14101 or /dev/ttyACM0)

While this script runs:
  1. Press BTNU on the Basys3 to reset.
  2. Press BTNC repeatedly to trigger encryptions -- each press produces a
     visible spike in the power log.
  3. Press Ctrl+C here when done collecting for this variant.

Run this once per bitstream (clean baseline, then each Trojan variant),
using a different --output filename each time, e.g.:
    python log_power_session.py --port COM5 --output clean_session.csv
    python log_power_session.py --port COM5 --output trojan_leak_session.csv
    python log_power_session.py --port COM5 --output trojan_counter_session.csv
    python log_power_session.py --port COM5 --output trojan_tiny_session.csv
"""

import argparse
import csv
import sys
import time

import serial


def main():
    parser = argparse.ArgumentParser(description="Log INA219 power readings to CSV.")
    parser.add_argument("--port", required=True, help="Serial port, e.g. COM5 or /dev/ttyACM0")
    parser.add_argument("--baud", type=int, default=115200, help="Must match the Arduino sketch's Serial.begin() value")
    parser.add_argument("--output", required=True, help="Output CSV filename, e.g. clean_session.csv")
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.port, args.baud, timeout=2)
    except serial.SerialException as error:
        print(f"Could not open serial port {args.port}: {error}")
        print("Tip: check the port name in Arduino IDE under Tools > Port, and close the Arduino Serial Monitor if it's open (only one program can use the port at a time).")
        sys.exit(1)

    time.sleep(2)  # give the Arduino time to reset after opening the serial connection

    print(f"Logging to {args.output}. Press Ctrl+C to stop.")
    row_count = 0

    with open(args.output, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["pc_timestamp", "arduino_micros", "current_mA", "busVoltage_V", "power_mW"])

        try:
            while True:
                line = ser.readline().decode("utf-8", errors="ignore").strip()
                if not line or line.startswith("micros") or line.startswith("ERROR"):
                    continue  # skip header echo or error lines
                parts = line.split(",")
                if len(parts) != 4:
                    continue  # skip malformed/partial lines
                pc_timestamp = time.time()
                writer.writerow([pc_timestamp] + parts)
                row_count += 1
                if row_count % 500 == 0:
                    print(f"  {row_count} samples logged...")
        except KeyboardInterrupt:
            print(f"\nStopped. {row_count} total samples saved to {args.output}")
        finally:
            ser.close()


if __name__ == "__main__":
    main()
