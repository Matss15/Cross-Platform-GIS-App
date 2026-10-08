// BFP Rosario GIS - ESP32 wiring test
//
// On power-up the green LED turns on (hardware is alive).
// Press the button: red LED on + relay closes (siren sounds).
// Press again: siren off, back to green.
// Safety: the siren turns itself off after SIREN_MAX_MS.
//
// Same pins as hardware/esp32_incident_alarm.

const int RED_LED_PIN = 14;
const int GREEN_LED_PIN = 27;
const int BUTTON_PIN = 33;  // to GND, internal pull-up
const int RELAY_PIN = 25;   // relay IN

// Where the relay module's VCC is wired:
//   true  = ESP32 3V3 -> LOW = on, HIGH = off (works without extra parts)
//   false = 5 V with a diode GPIO25 --|<-- IN (stripe toward GPIO25)
//           -> LOW = on, released pin = off
const bool RELAY_VCC_ON_3V3 = true;

void setRelay(bool on) {
  if (RELAY_VCC_ON_3V3) {
    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, on ? LOW : HIGH);  // LOW = on (verified by the user)
  } else if (on) {
    digitalWrite(RELAY_PIN, LOW);
    pinMode(RELAY_PIN, OUTPUT);
  } else {
    pinMode(RELAY_PIN, INPUT);
  }
}

const unsigned long DEBOUNCE_MS = 50;
const unsigned long SIREN_MAX_MS = 10000;

bool sirenOn = false;
unsigned long sirenStartedAt = 0;

bool lastReading = HIGH;
bool stableButton = HIGH;
unsigned long lastButtonChange = 0;

void setSiren(bool on) {
  sirenOn = on;
  setRelay(on);
  digitalWrite(RED_LED_PIN, on ? HIGH : LOW);
  digitalWrite(GREEN_LED_PIN, on ? LOW : HIGH);
  if (on) sirenStartedAt = millis();
  Serial.println(on ? "[test] button: RED + SIREN ON" : "[test] SIREN OFF, back to GREEN");
}

void setup() {
  Serial.begin(115200);
  setRelay(false);  // siren off at boot
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(GREEN_LED_PIN, HIGH);

  Serial.println();
  Serial.println("BFP Rosario GIS - ESP32 wiring test");
  Serial.println("Green = alive. Press button = red + siren. Press again = off.");
  Serial.println(digitalRead(BUTTON_PIN) == LOW
                     ? "[test] WARNING: button reads PRESSED at boot (check the button legs)"
                     : "[test] button reads released at boot (OK)");
}

void loop() {
  bool reading = digitalRead(BUTTON_PIN);
  if (reading != lastReading) {
    lastButtonChange = millis();
    lastReading = reading;
  }
  if (millis() - lastButtonChange > DEBOUNCE_MS && reading != stableButton) {
    stableButton = reading;
    Serial.println(stableButton == LOW ? "[test] button down" : "[test] button up");
    if (stableButton == LOW) setSiren(!sirenOn);
  }

  if (sirenOn && millis() - sirenStartedAt > SIREN_MAX_MS) {
    Serial.println("[test] 10 s safety timeout");
    setSiren(false);
  }
}
