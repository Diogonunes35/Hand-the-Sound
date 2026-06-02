#include <Wire.h>  // Wire library - used for I2C communication

int ADXL345 = 0x53;  // The ADXL345 sensor I2C address

float X_out, Y_out, Z_out;  // Outputs
float roll, pitch, rollF, pitchF = 0;

//flex Sensor
const int FLEX_PIN = A0;
int straightValue = 0;
int bentValue = 0;

//Botoes
const int BT1_PIN = 4;
const int BT2_PIN = 3;

const unsigned long debounceDelay = 50;

int btn1State;  // variable for reading the pushbutton status
int btn2State;
int lastReading1 = HIGH;
int lastReading2 = HIGH;

bool btn1Pressed = false;
bool btn2Pressed = false;

unsigned long lastDebounceTime1 = 0;  // the last time the button input changed
const unsigned long debounceDelay1 = 50;

unsigned long lastDebounceTime2 = 0;
const unsigned long debounceDelay2 = 50;

int value = 0;

void setup() {
  Serial.begin(9600);  // Initiate serial communication for printing the results on the Serial monitor

  Wire.begin();  // Initiate the Wire library
  // Set ADXL345 in measuring mode
  Wire.beginTransmission(ADXL345);  // Start communicating with the device
  Wire.write(0x2D);                 // Access/ talk to POWER_CTL Register - 0x2D
  // Enable measurement
  Wire.write(8);  // Bit D3 High for measuring enable (8dec -> 0000 1000 binary)
  Wire.endTransmission();
  delay(10);

  //Off-set Calibration
  //X-axis
  Wire.beginTransmission(ADXL345);
  Wire.write(0x1E);
  Wire.write(1);
  Wire.endTransmission();
  delay(10);
  //Y-axis
  Wire.beginTransmission(ADXL345);
  Wire.write(0x1F);
  Wire.write(-2);
  Wire.endTransmission();
  delay(10);
  //Z-axis
  Wire.beginTransmission(ADXL345);
  Wire.write(0x20);
  Wire.write(-9);
  Wire.endTransmission();
  delay(10);

  //Flex Sensor

  delay(5000);

  Serial.println("=================================");
  Serial.println(" FLEX SENSOR CALIBRATION ");
  Serial.println("=================================");
  Serial.println();

  delay(1000);

  Serial.println("Keep finger straight for...");
  countdown(4);

  straightValue = averageRead();

  Serial.print("Straight value = ");
  Serial.println(straightValue);
  Serial.println();

  Serial.println("Bend finger to 90 degrees for...");
  delay(5000);
  countdown(4);

  bentValue = averageRead();

  Serial.print("Bent value = ");
  Serial.println(bentValue);

  Serial.println();

  Serial.println("Calibration complete!");
  Serial.println();


  //botoes
  pinMode(BT1_PIN, INPUT_PULLUP);
  pinMode(BT2_PIN, INPUT_PULLUP);
}

void loop() {
  int reading1 = digitalRead(BT1_PIN);
  if (reading1 == LOW && lastReading1 == HIGH || reading1 == HIGH && lastReading1 == LOW) {
    btn1Pressed = !btn1Pressed;
    delay(50);
  }
  lastReading1 = reading1;

  int reading2 = digitalRead(BT2_PIN);
  if (reading2 == LOW && lastReading2 == HIGH || reading2 == HIGH && lastReading2 == LOW) {
    btn2Pressed = !btn2Pressed;
    delay(50);
  }
  lastReading2 = reading2;

  // === Read acceleromter data === //
  Wire.beginTransmission(ADXL345);
  Wire.write(0x32);  // Start with register 0x32 (ACCEL_XOUT_H)
  Wire.endTransmission(false);
  Wire.requestFrom(ADXL345, 6, true);        // Read 6 registers total, each axis value is stored in 2 registers
  X_out = (Wire.read() | Wire.read() << 8);  // X-axis value
  X_out = X_out / 256;                       //For a range of +-2g, we need to divide the raw values by 256, according to the datasheet
  Y_out = (Wire.read() | Wire.read() << 8);  // Y-axis value
  Y_out = Y_out / 256;
  Z_out = (Wire.read() | Wire.read() << 8);  // Z-axis value
  Z_out = Z_out / 256;

  // Calculate Roll and Pitch (rotation around X-axis, rotation around Y-axis)
  roll = atan(Y_out / sqrt(pow(X_out, 2) + pow(Z_out, 2))) * 180 / PI;
  pitch = atan(X_out / sqrt(pow(Y_out, 2) + pow(Z_out, 2))) * 180 / PI;

  // Low-pass filter
  rollF = 0.94 * rollF + 0.06 * roll;
  pitchF = 0.94 * pitchF + 0.06 * pitch;

  // Read analog value from flex sensor
  int flexValue = analogRead(FLEX_PIN);
  flexValue = constrain(map(flexValue, bentValue, straightValue, -100, 100), -100, 100);  //best values 175, 200
  // Print value to Serial Monitor
  //Serial.print("Flex Value: ");
  // Small delay for readability
  //delay(100);

  Serial.print(rollF);
  Serial.print("/");
  Serial.print(pitchF);
  Serial.print("/");
  Serial.print(btn1Pressed);
  Serial.print("/");
  Serial.print(btn2Pressed);
  Serial.print("/");
  Serial.println(flexValue);
}

// =====================================================
// FUNCTIONS
// =====================================================

// Average multiple readings for stability
int averageRead() {

  int total = 0;

  for (int i = 0; i < 15; i++) {

    total += analogRead(FLEX_PIN);
    delay(10);
  }

  return total = total / 15;
}

void countdown(int seconds) {

  for (int i = seconds; i > 0; i--) {

    Serial.print(i);
    Serial.println("...");
    delay(1000);
  }
}
