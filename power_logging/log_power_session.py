"""
log_power_session_v3.py
-----------------------
Logs INA219 readings from the Arduino over serial into a CSV file.

What is new compared with the earlier versions
  - Rejects corrupted serial lines before they reach the CSV. A line is rejected if
      * the voltage is outside 0-26 V or the current is outside +/-3200 mA,
      * power_mW does not match voltage x current (the corrected sketches compute it that way),
      * the timestamp goes backwards or jumps forward by more than 0.1 s.
  - --duration SECONDS stops the recording automatically, so you never have to touch
    the PC (or press Ctrl+C) while the measurement is still running.
  - Works with both sketch formats (the column count is detected automatically):
        micros,current_mA,busVoltage_V,power_mW          (ina219_stream_corrected.ino)
        micros,current_mA,busVoltage_V,power_mW,btn      (ina219_stream_btn.ino)
  - Refuses to overwrite an existing CSV unless you pass --force.
  - Prints a summary with the number of rejected lines and the measured sample rate.

Usage:
    python log_power_session_v3.py --port COM3 --output clean_run1.csv --duration 40
    python log_power_session_v3.py --list

Baud rate must match SERIAL_BAUD in the sketch (default 500000).
pc_timestamp is only a rough wall-clock time. Use arduino_micros for timing analysis.
"""

import argparse
import csv
import os
import re
import sys
import time
from collections import Counter

import serial
import serial.tools.list_ports

DEFAULT_BAUD = 500000

# ---- validation limits ----
MAX_TS_JUMP_US = 100_000        # a gap longer than 0.1 s between lines is treated as corruption
MAX_FIRST_TS_US = 10_000_000    # first timestamp after an Arduino reset should be small
MAX_VOLTAGE_V = 26.0            # INA219 bus-voltage limit
MAX_CURRENT_MA = 3200.0         # +/-3.2 A with the default calibration
RESYNC_AFTER = 10               # after this many bad timestamps in a row, accept the next line


def list_ports():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found. Is the Arduino plugged in (data cable, not charge-only)?")
    for p in ports:
        print(f"  {p.device}: {p.description}")


def parse_line(line):
    """Return (parts, micros, current, voltage, power) or None if the line is not valid data."""
    parts = [p for p in re.split(r"[,\t; ]+", line.strip()) if p]
    if len(parts) not in (4, 5):
        return None
    try:
        micros = int(parts[0])
        current = float(parts[1])
        voltage = float(parts[2])
        power = float(parts[3])
    except ValueError:
        return None
    if len(parts) == 5 and parts[4] not in ("0", "1"):
        return None
    return parts, micros, current, voltage, power


class LineFilter:
    """Decides which serial lines are good enough to be written to the CSV."""

    def __init__(self, power_check=True):
        self.power_check = power_check
        self.last_micros = None
        self.ncols = None
        self.ts_streak = 0
        self.rejected = Counter()
        self.resyncs = 0

    def _value_problem(self, current, voltage, power):
        if not (0.0 <= voltage <= MAX_VOLTAGE_V):
            return "voltage out of range"
        if abs(current) > MAX_CURRENT_MA:
            return "current out of range"
        if self.power_check and abs(power - voltage * current) > 0.02 * abs(power) + 1.0:
            return "power does not match V x I"
        return None

    def _timestamp_problem(self, micros):
        if self.last_micros is None:
            return "first timestamp too large" if micros > MAX_FIRST_TS_US else None
        if micros <= self.last_micros:
            return "timestamp not increasing"
        if micros - self.last_micros > MAX_TS_JUMP_US:
            return "timestamp jump"
        return None

    def accept(self, line):
        """Return (parts, None) if the line is accepted, else (None, reason)."""
        parsed = parse_line(line)
        if parsed is None:
            self.rejected["not a data line"] += 1
            return None, "not a data line"
        parts, micros, current, voltage, power = parsed

        if self.ncols is not None and len(parts) != self.ncols:
            self.rejected["column count changed"] += 1
            return None, "column count changed"

        reason = self._value_problem(current, voltage, power)
        if reason:
            self.rejected[reason] += 1
            return None, reason

        reason = self._timestamp_problem(micros)
        if reason:
            self.ts_streak += 1
            if self.ts_streak < RESYNC_AFTER:
                self.rejected[reason] += 1
                return None, reason
            self.resyncs += 1      # many bad timestamps in a row: the Arduino probably restarted
        self.ts_streak = 0

        self.last_micros = micros
        if self.ncols is None:
            self.ncols = len(parts)
        return parts, None


def main():
    parser = argparse.ArgumentParser(description="Log INA219 power readings to CSV.")
    parser.add_argument("--port", help="Serial port, e.g. COM3 or /dev/ttyACM0")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD,
                        help=f"Must match Serial.begin() in the sketch (default {DEFAULT_BAUD})")
    parser.add_argument("--output", help="Output CSV filename")
    parser.add_argument("--duration", type=float, default=0,
                        help="Stop automatically after this many seconds (default: run until Ctrl+C)")
    parser.add_argument("--force", action="store_true", help="Allow overwriting an existing output file")
    parser.add_argument("--no-power-check", action="store_true",
                        help="Do not reject lines where power_mW differs from voltage x current")
    parser.add_argument("--list", action="store_true", help="List available serial ports and exit")
    args = parser.parse_args()

    if args.list:
        list_ports()
        return
    if not args.port or not args.output:
        parser.error("--port and --output are required (or use --list)")

    if os.path.exists(args.output) and not args.force:
        print(f"'{args.output}' already exists and would be overwritten.")
        print("Choose a different --output name, or add --force if you really want to replace it.")
        sys.exit(1)

    try:
        ser = serial.Serial(args.port, args.baud, timeout=1)
    except serial.SerialException as error:
        print(f"Could not open serial port {args.port}: {error}")
        print("Available ports:")
        list_ports()
        print("Also close the Arduino Serial Monitor/Plotter if open.")
        sys.exit(1)

    try:
        ser.set_buffer_size(rx_size=1 << 20)   # 1 MB receive buffer (Windows); ignored elsewhere
    except (AttributeError, serial.SerialException):
        pass

    time.sleep(2)             # Arduino resets when the port opens
    ser.reset_input_buffer()  # drop anything left over from the reset

    when = f"for {args.duration:g} s" if args.duration else "until Ctrl+C"
    print(f"Logging to {args.output} at {args.baud} baud {when}.")
    print("First raw lines received will be shown below:\n")

    flt = LineFilter(power_check=not args.no_power_check)
    row_count = 0
    raw_seen = 0
    first_micros = None
    shown_rejects = 0
    start = time.time()
    warned_silence = False
    header_written = False

    with open(args.output, "w", newline="") as f:
        writer = csv.writer(f)
        try:
            while True:
                if args.duration and time.time() - start >= args.duration:
                    print("\nDuration reached, stopping.")
                    break

                raw = ser.readline()
                if not raw:
                    if raw_seen == 0 and not warned_silence and time.time() - start > 5:
                        warned_silence = True
                        print("WARNING: nothing received for 5+ seconds. Check that:")
                        print("         - the sketch is uploaded (no compile errors),")
                        print(f"         - SERIAL_BAUD in the sketch equals --baud (now {args.baud}),")
                        print("         - the COM port is correct and the Serial Monitor is closed.")
                    continue

                line = raw.decode("utf-8", errors="replace").strip()
                if not line:
                    continue

                raw_seen += 1
                if raw_seen <= 10:
                    print(f"  raw: {line!r}")

                parts, reason = flt.accept(line)
                if parts is None:
                    if raw_seen > 10 and shown_rejects < 5:
                        shown_rejects += 1
                        print(f"  rejected ({reason}): {line!r}")
                    continue

                if not header_written:
                    columns = ["pc_timestamp", "arduino_micros", "current_mA", "busVoltage_V", "power_mW"]
                    if len(parts) == 5:
                        columns.append("btn")
                    writer.writerow(columns)
                    header_written = True
                    first_micros = int(parts[0])

                writer.writerow([time.time()] + parts)
                row_count += 1
                if row_count % 500 == 0:
                    f.flush()
                    print(f"  {row_count} samples logged...")
        except KeyboardInterrupt:
            pass
        finally:
            ser.close()

    total_rejected = sum(flt.rejected.values())
    print(f"\nStopped. {row_count} samples saved to {args.output}")
    print(f"Lines received: {raw_seen}, rejected: {total_rejected}")
    for reason, count in flt.rejected.most_common():
        print(f"    {reason}: {count}")
    if flt.resyncs:
        print(f"    timestamp resyncs (possible Arduino restart): {flt.resyncs}")

    if row_count > 1 and first_micros is not None and flt.last_micros is not None:
        seconds = (flt.last_micros - first_micros) / 1e6
        if seconds > 0:
            print(f"Recorded {seconds:.1f} s at {row_count / seconds:.1f} samples/s "
                  f"(average spacing {1e6 * seconds / row_count:.0f} us)")

    if row_count == 0:
        try:
            os.remove(args.output)     # do not leave an empty file that blocks the next run
        except OSError:
            pass
        if raw_seen == 0:
            print("Diagnosis: the Arduino sent NOTHING. Wrong port, wrong baud, sketch not uploaded/running,")
            print("or another program (Serial Monitor) is using the port.")
        else:
            print("Diagnosis: data arrived but every line was rejected.")
            print("Compare the 'raw:' lines above with:  micros,current_mA,busVoltage_V,power_mW[,btn]")
            print("If power_mW is read from the INA219 itself (original library sketch), add --no-power-check.")


if __name__ == "__main__":
    main()
