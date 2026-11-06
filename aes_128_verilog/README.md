# AES-128 Verilog Core

Verified against the official FIPS-197 Appendix B known-answer test:
- Key:        000102030405060708090a0b0c0d0e0f
- Plaintext:  00112233445566778899aabbccddeeff
- Ciphertext: 69c4e0d86a7b0430d8cdb78070b4c55a  ✅ matches

## Files
- `aes_sbox.v`        — AES forward S-box lookup table
- `key_expansion.v`   — generates 11 round keys from the 128-bit cipher key
- `aes_transforms.v`  — SubBytes, ShiftRows, MixColumns, AddRoundKey modules
- `aes_128.v`         — top-level core, iterative FSM (1 round/clock, 11 cycles total)
- `tb_aes_128.v`      — testbench that runs the FIPS-197 test vector
- `aes_128_trojan_leak.v`, `_counter.v`, `_tiny.v` — original 3 Trojan variants
- `aes_128_trojan_drain.v`, `_burst.v`, `_hamming.v` — 3 new, power-visible Trojan variants (see below)
- `tb_new_trojans.v`  — testbench verifying the 3 new variants against the clean core
- `basys3_top.v`      — original wrapper (hard-wired to `aes_128_trojan_leak`)
- `basys3_top_v2.v`   — new wrapper; pick any of the 7 builds with one `VARIANT` parameter, with a continuous-run mode for logging

## Architecture
Iterative (round-per-clock), not fully unrolled. This keeps FPGA area low,
which matters both for fitting on the Basys3 and for your later area/power
overhead comparisons between clean and Trojan-infected variants.

## How to simulate (already verified with Icarus Verilog)
```
iverilog -o sim.out aes_sbox.v key_expansion.v aes_transforms.v aes_128.v tb_aes_128.v
vvp sim.out
```

## How to use in Vivado
1. Add all 5 `.v` files (skip tb for synthesis) as design sources.
2. Set `aes_128` as top module.
3. Instantiate with `clk`, `rst`, `start`, 128-bit `plaintext`, 128-bit `key`.
4. Pulse `start` for one clock; `done` goes high 11 cycles later with `ciphertext` valid.
5. For the Basys3, you'll need to wrap this with I/O logic (switches/UART/etc.)
   to load plaintext/key and read out ciphertext, since 256 bits of direct
   switch input isn't practical on real hardware.

## Next steps for your project
- This is your **clean baseline**. Keep an untouched copy.
- For Trojan insertion, copy this into a new folder per variant and modify
  there — never touch this baseline once your clean power traces are collected.
- A likely first Trojan target: modify `key_expansion.v` or `aes_128.v` to leak
  key bits via a rare trigger condition (classic TrustHub-style AES Trojan).

## Trojan Variants (verified against clean baseline)

All 3 verified: produce IDENTICAL ciphertext to the clean baseline
(matches FIPS-197 test vector) when untriggered.

| Variant | File | Trigger type | Trigger condition | Payload | Extra HW |
|---|---|---|---|---|---|
| 1 | `aes_128_trojan_leak.v` | Data (combinational) | plaintext == fixed 128-bit pattern (0xDEADBEEF...) | Leaks 1 key byte on spare output pin | 128-bit comparator + 8-bit reg |
| 2 | `aes_128_trojan_counter.v` | Time (sequential) | fires on every 128th encryption | Flips LSB of ciphertext | 8-bit counter + comparator |
| 3 | `aes_128_trojan_tiny.v` | Data (combinational, minimal) | plaintext[7:0] == 0x5A | Flips 1 bit of ciphertext | 8-bit comparator + XOR (smallest footprint — hardest to detect) |

These 3 give you leave-one-Trojan-out validation with different trigger
*mechanisms* (data-rare vs time-delayed vs minimal-data), not just
different payloads — a stronger dataset for showing your models
generalize rather than memorize one Trojan's signature.

### Why accuracy may be low, and 3 new variants that address it

Variants 1-3 change only a handful of logic cells. Each one flips at most
one bit of the ciphertext or copies one byte to a spare pin — the actual
*extra switching activity* they add is tiny next to the AES core's own
activity. An INA219 samples in ~2.6 ms steps (one sample spans thousands of
encryptions, see the report's Chapter 4), so a Trojan that small is very
likely sitting below the sensor's noise floor. That is a strong candidate
explanation for why Random Forest/SVM/CNN accuracy on Variants 1-3 was
disappointing — the models may be trying to learn a signal that mostly
isn't there in the power trace.

Variants 4-6 are sized to be clearly visible to a slow, cheap sensor,
while still leaving the ciphertext and `done` untouched (verified in
`tb_new_trojans.v`):

| Variant | File | Trigger type | Trigger condition | Payload | Extra HW | Power signature |
|---|---|---|---|---|---|---|
| 4 | `aes_128_trojan_drain.v` | Time (sequential, latched) | fires after the 16th encryption, then stays active | 512-bit ring of flip-flops toggles every clock | 512 flip-flops | Large, **steady** step up in average current once triggered |
| 5 | `aes_128_trojan_burst.v` | Data (combinational, latched at start) | plaintext[31:0] == 0xDEADBEEF | 8×32-bit free-running counters increment while an encryption runs | 256 flip-flops | Current rises and falls **with each encryption**, not a constant offset — a different shape from Variant 4 |
| 6 | `aes_128_trojan_hamming.v` | Time (sequential, latched) | fires after the 32nd encryption, then stays active | toggles a bank once per '1' bit in `key[7:0]` (its Hamming weight, 0–8) | 64 flip-flops | Step size **depends on the key**, closer to the dependence that real power-analysis attacks exploit |

All 3 were checked against the clean core with `tb_new_trojans.v`:
ciphertext matches on every run, each trigger fires only at its own
condition, and each payload is confirmed to actually toggle once active.

```
iverilog -g2005 -o sim.out aes_sbox.v key_expansion.v aes_transforms.v aes_128.v \
    aes_128_trojan_drain.v aes_128_trojan_burst.v aes_128_trojan_hamming.v tb_new_trojans.v
vvp sim.out
```

### Suggested next dataset (7 classes)

1. Re-capture `clean`, `trojan_leak`, `trojan_counter`, `trojan_tiny` if you
   suspect your first captures had too few samples or too much idle time.
2. Capture `trojan_drain`, `trojan_burst`, `trojan_hamming` the same way.
3. Retrain the same Random Forest / SVM / 1D-CNN pipeline on all 7 classes
   (or first on just clean vs. drain/burst/hamming) to check that accuracy
   rises sharply on these larger Trojans — that result, on its own, is good
   evidence that your *pipeline* is sound and the earlier low score came
   from Trojan size versus sensor resolution, not from the ML code.
4. Keep Variants 1-3 in the report as the "hard" classes and Variants 4-6
   as the "easy" classes — the accuracy gap between the two groups is
   itself a finding worth reporting.

### Using `basys3_top_v2.v`

In Vivado, set `basys3_top_v2` as the top module and set its `VARIANT`
parameter (Sources pane → right-click the module → Edit/Set 'Top' or
Tools → Settings → General → Verilog Options) to 0–6 per the table in that
file's header comment, then reprogram the Basys3 for each value. Flip
SW[14] high before logging so encryptions run back to back with no idle
gaps between button presses — this matters most for Variant 5, whose burst
is only visible while encryptions are actually running.

To collect traces: swap the top module in Vivado between `aes_128`
(clean) and each `aes_128_trojan_*` variant — or, more conveniently, use
`basys3_top_v2.v` and change its `VARIANT` parameter — reprogram the
Basys3, and log power for each.
