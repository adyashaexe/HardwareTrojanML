/*
  ina219_stream.ino
  ------------------
  Reads the INA219 power sensor as fast as possible and streams readings
  over Serial as CSV lines: micros,current_mA,busVoltage_V,power_mW

  Wiring (Arduino Uno):
    INA219 VCC -> Arduino 5V
    INA219 GND -> Arduino GND
    INA219 SDA -> Arduino A4
    INA219 SCL -> Arduino A5

  Library needed: Adafruit_INA219 (Arduino IDE -> Library Manager -> search "Adafruit INA219")
*/

#include <Wire.h>
#include <Adafruit_INA219.h>

Adafruit_INA219 ina219;

void setup() {
  Serial.begin(115200);   // fast baud rate to keep up with sampling
  while (!Serial) { }

  if (!ina219.begin()) {
    Serial.println("ERROR: INA219 not found. Check wiring.");
    while (1) { delay(10); }
  }

  // Optional: set a calibration mode for higher resolution at lower current.
  // Default (32V, 2A) works fine for an FPGA board's power draw.
  // ina219.setCalibration_16V_400mA();  // uncomment for finer resolution if current draw is small

  Serial.println("micros,current_mA,busVoltage_V,power_mW");
}

void loop() {
  float current_mA   = ina219.getCurrent_mA();
  float busVoltage_V = ina219.getBusVoltage_V();
  float power_mW     = ina219.getPower_mW();

  Serial.print(micros());
  Serial.print(",");
  Serial.print(current_mA, 4);
  Serial.print(",");
  Serial.print(busVoltage_V, 4);
  Serial.print(",");
  Serial.println(power_mW, 4);

  // No delay() here on purpose -- we want to sample as fast as the INA219's
  // internal conversion time allows (roughly 1-2 kHz depending on settings).
  // If your CSV shows duplicate consecutive readings, add a tiny delay(1).
}
