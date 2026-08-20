/*
  Reads the INA3221 power monitor and streams readings
  over Serial as CSV lines:

  micros,
  busVoltage1_V,current1_mA,power1_mW,
  busVoltage2_V,current2_mA,power2_mW,
  busVoltage3_V,current3_mA,power3_mW

  Wiring (Arduino Uno):
    INA3221 VCC -> Arduino 5V
    INA3221 GND -> Arduino GND
    INA3221 SDA -> Arduino A4
    INA3221 SCL -> Arduino A5

  Library needed:
    Adafruit INA3221
    Arduino IDE -> Library Manager
    Search: "Adafruit INA3221"
*/

#include <Wire.h>
#include <Adafruit_INA3221.h>

Adafruit_INA3221 ina3221;

void setup() {
  Serial.begin(115200);
  while (!Serial) {
    delay(10);
  }

  if (!ina3221.begin()) {
    Serial.println("ERROR: INA3221 not found. Check wiring.");
    while (1) {
      delay(10);
    }
  }

  // Configure the three channels.
  ina3221.setAveragingMode(INA3221_AVERAGING_1);

  Serial.println(
    "micros,"
    "busVoltage1_V,current1_mA,power1_mW,"
    "busVoltage2_V,current2_mA,power2_mW,"
    "busVoltage3_V,current3_mA,power3_mW"
  );
}

void loop() {

  // Channel 1
  float busVoltage1_V = ina3221.getBusVoltage(1);
  float current1_mA   = ina3221.getCurrentAmps(1) * 1000.0;
  float power1_mW     = busVoltage1_V * current1_mA;

  // Channel 2
  float busVoltage2_V = ina3221.getBusVoltage(2);
  float current2_mA   = ina3221.getCurrentAmps(2) * 1000.0;
  float power2_mW     = busVoltage2_V * current2_mA;

  // Channel 3
  float busVoltage3_V = ina3221.getBusVoltage(3);
  float current3_mA   = ina3221.getCurrentAmps(3) * 1000.0;
  float power3_mW     = busVoltage3_V * current3_mA;

  // Timestamp
  Serial.print(micros());
  Serial.print(",");

  // Channel 1
  Serial.print(busVoltage1_V, 4);
  Serial.print(",");
  Serial.print(current1_mA, 4);
  Serial.print(",");
  Serial.print(power1_mW, 4);
  Serial.print(",");

  // Channel 2
  Serial.print(busVoltage2_V, 4);
  Serial.print(",");
  Serial.print(current2_mA, 4);
  Serial.print(",");
  Serial.print(power2_mW, 4);
  Serial.print(",");

  // Channel 3
  Serial.print(busVoltage3_V, 4);
  Serial.print(",");
  Serial.print(current3_mA, 4);
  Serial.print(",");
  Serial.println(power3_mW, 4);

  // No delay() here.
  // The INA3221's internal conversion time determines
  // the effective sampling rate.
}