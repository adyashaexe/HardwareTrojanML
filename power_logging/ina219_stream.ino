/*
  ina219_stream_corrected.ino
  ---------------------------
  Streams INA219 readings over Serial as CSV lines:
    micros,current_mA,busVoltage_V,power_mW

  I2C wiring (Arduino Uno):
    INA219 VCC -> Arduino 5V
    INA219 GND -> Arduino GND
    INA219 SDA -> A4
    INA219 SCL -> A5

  POWER wiring (this is what the bus-voltage reading depends on):
    Supply (+)  -> INA219 VIN+
    INA219 VIN- -> Load (+)   (the FPGA board's positive input)
    Supply (-), Load (-) and Arduino GND must ALL be connected together (common ground).
    Without the common ground the voltage reading shows noise (0 - 0.35 V with 50 Hz hum).

  Expected busVoltage_V: about the same as your supply voltage (e.g. ~5.0 V for a 5 V supply).

  Set the PC-side logger to the same baud rate as SERIAL_BAUD below.
*/

#include <Wire.h>
#include <Adafruit_INA219.h>

Adafruit_INA219 ina219;

// ---- Settings ----
constexpr unsigned long SAMPLE_INTERVAL_US = 2000;    // 2000 us = 500 samples/s
constexpr unsigned long SERIAL_BAUD        = 500000;  // must match the PC logger

// ---- INA219 registers ----
constexpr uint8_t INA_ADDR    = 0x40;
constexpr uint8_t REG_CONFIG  = 0x00;
constexpr uint8_t REG_BUS     = 0x02;
constexpr uint8_t REG_CURRENT = 0x04;

// 32 V bus range, +/-320 mV shunt range, 12-bit ADC (full resolution), continuous mode.
// One shunt+bus conversion takes ~1.06 ms, so 2 ms between samples is safe.
constexpr uint16_t INA_CONFIG = 0x399F;

// Matches setCalibration_32V_2A() with a 0.1 ohm shunt: 1 LSB of current = 0.1 mA.
// If you use a different shunt resistor or calibration, change this value.
constexpr float CURRENT_DIVIDER_MA = 10.0f;

unsigned long nextSampleUs = 0;

bool writeReg(uint8_t reg, uint16_t value) {
  Wire.beginTransmission(INA_ADDR);
  Wire.write(reg);
  Wire.write((uint8_t)(value >> 8));
  Wire.write((uint8_t)(value & 0xFF));
  return Wire.endTransmission() == 0;
}

bool readReg(uint8_t reg, uint16_t &value) {
  Wire.beginTransmission(INA_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;           // repeated start
  if (Wire.requestFrom(INA_ADDR, (uint8_t)2) != 2) return false;
  uint8_t hi = Wire.read();                                      // two separate reads on purpose
  uint8_t lo = Wire.read();
  value = ((uint16_t)hi << 8) | lo;
  return true;
}

void setup() {
  Serial.begin(SERIAL_BAUD);
  while (!Serial) { }

  if (!ina219.begin()) {   // sets default calibration (32V, 2A)
    Serial.println("ERROR: INA219 not found. Check wiring.");
    while (1) { delay(10); }
  }

  // IMPORTANT: set the I2C clock AFTER begin(), because begin() resets it to 100 kHz.
  Wire.setClock(400000);

  if (!writeReg(REG_CONFIG, INA_CONFIG)) {
    Serial.println("ERROR: could not configure INA219.");
    while (1) { delay(10); }
  }

  Serial.println("micros,current_mA,busVoltage_V,power_mW");
  nextSampleUs = micros() + SAMPLE_INTERVAL_US;
}

void loop() {
  unsigned long now = micros();

  if ((long)(now - nextSampleUs) >= 0) {
    // Fixed schedule: no drift. If we fall a full period behind, resync.
    nextSampleUs += SAMPLE_INTERVAL_US;
    if ((long)(now - nextSampleUs) >= 0) nextSampleUs = now + SAMPLE_INTERVAL_US;

    uint16_t rawBus, rawCur;
    if (!readReg(REG_BUS, rawBus) || !readReg(REG_CURRENT, rawCur)) {
      return;  // skip this sample if the I2C read failed
    }

    float busVoltage_V = (float)(rawBus >> 3) * 0.004f;               // 4 mV per step
    float current_mA   = (float)(int16_t)rawCur / CURRENT_DIVIDER_MA; // 0.1 mA per step
    float power_mW     = busVoltage_V * current_mA;                   // from the same sample

    Serial.print(now);
    Serial.print(',');
    Serial.print(current_mA, 1);      // 0.1 mA is the real resolution
    Serial.print(',');
    Serial.print(busVoltage_V, 3);
    Serial.print(',');
    Serial.println(power_mW, 1);
  }
}
