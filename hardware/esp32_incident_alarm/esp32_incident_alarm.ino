// BFP Rosario GIS - ESP32 incident alarm
//
// Watches the Firestore `incidents` collection and sounds an alarm whenever a
// citizen submits a new report. The sound tells how serious it is:
//
//   Critical -> long wailing siren (rises and falls without stopping)
//   High     -> "wang-wang" siren (two alternating tones)
//   Low      -> beep-beep, pause, beep-beep
//
// Press the STOP button to silence the alarm. A newer, more serious report
// that arrives while the alarm is sounding switches to the stronger sound.
//
// Wi-Fi setup from a phone (WiFiManager): when the saved network cannot be
// reached, the ESP32 opens its own hotspot "BFP-Alarm-Setup". Join it from a
// phone, pick the new network (e.g. the school hotspot), enter its password,
// and Save. The ESP32 remembers it across reboots. To change networks while
// it is still online, hold STOP for 5 seconds (or hold STOP while powering
// on): the red LED blinks while the hotspot is open. Hold STOP for 5 seconds
// again to close it (back to solid green). It also closes by
// itself after 3 minutes and the saved network is retried.
//
// Wiring (same as docs/SYSTEM_AND_HARDWARE.md):
//   GPIO26 -> buzzer +          GPIO14 -> red LED (220 ohm)
//   GPIO27 -> green LED (220 ohm)
//   GPIO33 -> STOP button side A, side B -> GND (internal pull-up)
//   GPIO25 -> relay IN (reserved for the real siren, off by default)
//
// LEDs:
//   green solid     = online, watching for reports
//   green solid     = ready: online, watching for reports
//   green blinking  = connecting to Wi-Fi / Firebase, or an error
//   red blinking, green off = Wi-Fi setup hotspot open (no alarm running)
//   red             = alarm (solid: Critical, fast blink: High, slow: Low)
//
// Serial Monitor (115200 baud) test commands:
//   1 = Low sound, 2 = High sound, 3 = Critical sound, 0 = stop
//
// Libraries: ArduinoJson 7, WiFiManager (tzapu). Board: "ESP32 Dev Module".

#include <WiFi.h>
#include <WiFiManager.h>
#include <NetworkClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <esp_system.h>

#include "secrets.h"

// Setup hotspot the phone joins to choose a Wi-Fi network. Override the
// password in secrets.h; it must be at least 8 characters.
#ifndef SETUP_AP_NAME
#define SETUP_AP_NAME "BFP-Alarm-Setup"
#endif
#ifndef SETUP_AP_PASSWORD
#define SETUP_AP_PASSWORD "bfpalarm2026"
#endif

// ---------- Pins ----------
const int BUZZER_PIN = 26;
const int RED_LED_PIN = 14;
const int GREEN_LED_PIN = 27;
const int BUTTON_PIN = 33;
const int RELAY_PIN = 25;

// Set to true once the real siren is wired to the relay.
const bool USE_RELAY_SIREN = true;

// Where the relay module's VCC is wired:
//   true  = ESP32 3V3: LOW = on, HIGH = off. Wi-Fi transmit power is lowered
//           so the 3.3 V rail stays strong enough to pull the relay in.
//   false = 5 V with a diode GPIO25 --|<-- IN (stripe toward GPIO25):
//           LOW = on, released pin (INPUT) = off. Without the diode the
//           ESP32 cannot turn a 5 V module off and the siren never stops.
const bool RELAY_VCC_ON_3V3 = true;

// ---------- Timing ----------
const unsigned long POLL_INTERVAL_MS = 3000;
const unsigned long TOKEN_LIFETIME_MS = 50UL * 60UL * 1000UL;  // tokens last 60 min
const unsigned long DEBOUNCE_MS = 50;
const unsigned long SETUP_HOLD_MS = 5000;  // hold STOP to open Wi-Fi setup
const unsigned long WIFI_CONNECT_TIMEOUT_S = 20;
const unsigned long SETUP_PORTAL_TIMEOUT_S = 180;

// ---------- Severity ----------
enum Severity { SEV_NONE = 0, SEV_LOW = 1, SEV_HIGH = 2, SEV_CRITICAL = 3 };

const char *severityName(int severity) {
  switch (severity) {
    case SEV_CRITICAL: return "CRITICAL";
    case SEV_HIGH: return "HIGH";
    case SEV_LOW: return "LOW";
    default: return "NONE";
  }
}

// The app stores priority as Low / Medium / High / Critical.
int severityFromPriority(const char *priority) {
  if (priority == nullptr) return SEV_HIGH;
  String p = String(priority);
  p.toLowerCase();
  if (p == "critical") return SEV_CRITICAL;
  if (p == "high") return SEV_HIGH;
  if (p == "low" || p == "medium") return SEV_LOW;
  return SEV_HIGH;  // unknown values err on the loud side
}

// ---------- State shared between the network task and loop() ----------
portMUX_TYPE stateMux = portMUX_INITIALIZER_UNLOCKED;
volatile int requestedSeverity = SEV_NONE;  // set by network task
volatile bool online = false;
volatile bool setupPortalRequested = false;  // set by holding STOP
volatile bool setupPortalOpen = false;       // hotspot is running
volatile bool setupPortalCloseRequested = false;  // STOP held while open

void requestAlarm(int severity) {
  portENTER_CRITICAL(&stateMux);
  if (severity > requestedSeverity) requestedSeverity = severity;
  portEXIT_CRITICAL(&stateMux);
}

int takeRequestedAlarm() {
  portENTER_CRITICAL(&stateMux);
  int severity = requestedSeverity;
  requestedSeverity = SEV_NONE;
  portEXIT_CRITICAL(&stateMux);
  return severity;
}

// =====================================================================
// Network task (core 0): Wi-Fi, Firebase sign-in, Firestore polling
// =====================================================================

String idToken;
unsigned long tokenObtainedAt = 0;
String lastSeenCreatedAt;  // Firestore timestamp of the newest report seen
bool baselineReady = false;
WiFiManager wifiManager;

const char *wifiStatusText(wl_status_t status) {
  switch (status) {
    case WL_NO_SSID_AVAIL: return "network not found (check the name; must be 2.4 GHz)";
    case WL_CONNECT_FAILED: return "connection refused (check the password)";
    case WL_CONNECTION_LOST: return "connection lost";
    case WL_DISCONNECTED: return "disconnected (weak signal or wrong password)";
    default: return "not connected";
  }
}

// Lists nearby networks so a wrong name or a 5 GHz-only network is obvious.
void printNearbyNetworks(const String &savedSsid) {
  int count = WiFi.scanNetworks();
  Serial.printf("[wifi] %d networks visible:\n", count);
  for (int i = 0; i < count; i++) {
    Serial.printf("[wifi]   \"%s\"  signal %d dBm  channel %d%s\n",
                  WiFi.SSID(i).c_str(), WiFi.RSSI(i), WiFi.channel(i),
                  WiFi.SSID(i) == savedSsid ? "  <- saved" : "");
  }
  WiFi.scanDelete();
}

void printSetupHint() {
  Serial.printf("[wifi] setup hotspot open: join \"%s\" (password %s) from a phone,\n",
                SETUP_AP_NAME, SETUP_AP_PASSWORD);
  Serial.println("[wifi] then open http://192.168.4.1 if the setup page does not pop up.");
}

// Joins the network saved by WiFiManager. If it cannot be reached, or STOP
// was held, opens the setup hotspot until a phone saves a new network or
// SETUP_PORTAL_TIMEOUT_S passes.
bool connectWifi() {
  bool portalRequested = setupPortalRequested;
  if (WiFi.status() == WL_CONNECTED && !portalRequested) return true;
  online = false;

  bool connected;
  if (portalRequested) {
    setupPortalRequested = false;
    setupPortalCloseRequested = false;
    Serial.println("[wifi] Wi-Fi setup requested");
    setupPortalOpen = true;
    connected = wifiManager.startConfigPortal(SETUP_AP_NAME, SETUP_AP_PASSWORD);
    // WiFiManager can leave the hotspot radio up; force it off so
    // "BFP-Alarm-Setup" disappears once the LED is back to green.
    WiFi.softAPdisconnect(true);
    WiFi.mode(WIFI_STA);
    setupPortalOpen = false;
    if (setupPortalCloseRequested) {
      setupPortalCloseRequested = false;
      Serial.println("[wifi] setup hotspot closed with STOP");
    }
    // Closing the hotspot without saving keeps the existing connection.
    if (!connected) connected = WiFi.status() == WL_CONNECTED;
  } else {
    // WiFiManager logs the saved network name itself (*wm: lines).
    Serial.println("[wifi] connecting to saved network");
    // If the saved network is unreachable, autoConnect opens the hotspot
    // itself (the AP callback sets setupPortalOpen).
    connected = wifiManager.autoConnect(SETUP_AP_NAME, SETUP_AP_PASSWORD);
    if (setupPortalOpen) {
      WiFi.softAPdisconnect(true);
      WiFi.mode(WIFI_STA);
      setupPortalOpen = false;
    }
  }

  if (!connected) {
    Serial.printf("[wifi] failed: %s\n", wifiStatusText(WiFi.status()));
    // Read only now: before WiFi starts, the saved config is not valid yet.
    printNearbyNetworks(wifiManager.getWiFiSSID(true));
    return false;
  }
  // Lower transmit power draws less current from the 3.3 V rail the relay
  // shares. Raise it (e.g. WIFI_POWER_15dBm) if the router is far away.
  if (RELAY_VCC_ON_3V3) WiFi.setTxPower(WIFI_POWER_8_5dBm);
  Serial.printf("[wifi] connected to %s, IP %s\n",
                WiFi.SSID().c_str(), WiFi.localIP().toString().c_str());
  return true;
}

// POSTs JSON over HTTPS. Returns the HTTP status (negative on network error).
int postJson(const String &url, const String &body, String &response, bool withAuth) {
  NetworkClientSecure client;
  client.useBuiltinCACertBundle();  // verifies Google's certificate
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) return -1;
  http.addHeader("Content-Type", "application/json");
  if (withAuth) http.addHeader("Authorization", "Bearer " + idToken);
  int status = http.POST(body);
  response = status > 0 ? http.getString() : String();
  http.end();
  return status;
}

bool signIn() {
  Serial.println("[auth] signing in device account");
  JsonDocument request;
  request["email"] = DEVICE_EMAIL;
  request["password"] = DEVICE_PASSWORD;
  request["returnSecureToken"] = true;
  String body;
  serializeJson(request, body);

  String response;
  int status = postJson(
    String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") + FIREBASE_API_KEY,
    body, response, false);
  if (status != 200) {
    Serial.printf("[auth] sign-in failed (HTTP %d): %s\n", status, response.c_str());
    return false;
  }

  JsonDocument result;
  if (deserializeJson(result, response)) return false;
  idToken = result["idToken"].as<String>();
  tokenObtainedAt = millis();
  Serial.println("[auth] signed in");
  return idToken.length() > 0;
}

bool ensureToken() {
  if (idToken.length() > 0 && millis() - tokenObtainedAt < TOKEN_LIFETIME_MS) {
    return true;
  }
  return signIn();
}

// Runs a Firestore structured query on `incidents`. When afterTimestamp is
// empty it returns the single newest report (used as the starting point so
// old reports do not ring at boot); otherwise every report created after it.
int queryIncidents(const String &afterTimestamp, JsonDocument &result) {
  JsonDocument request;
  JsonObject query = request["structuredQuery"].to<JsonObject>();
  query["from"][0]["collectionId"] = "incidents";

  JsonArray fields = query["select"]["fields"].to<JsonArray>();
  const char *wanted[] = {"priority", "type", "barangayName", "createdAt"};
  for (const char *name : wanted) fields.add<JsonObject>()["fieldPath"] = name;

  JsonObject order = query["orderBy"][0].to<JsonObject>();
  order["field"]["fieldPath"] = "createdAt";
  if (afterTimestamp.length() == 0) {
    order["direction"] = "DESCENDING";
    query["limit"] = 1;
  } else {
    order["direction"] = "ASCENDING";
    query["limit"] = 10;
    JsonObject filter = query["where"]["fieldFilter"].to<JsonObject>();
    filter["field"]["fieldPath"] = "createdAt";
    filter["op"] = "GREATER_THAN";
    filter["value"]["timestampValue"] = afterTimestamp;
  }

  String body;
  serializeJson(request, body);
  String response;
  int status = postJson(
    String("https://firestore.googleapis.com/v1/projects/") + FIREBASE_PROJECT_ID +
      "/databases/(default)/documents:runQuery",
    body, response, true);

  if (status == 200) {
    if (deserializeJson(result, response)) return -2;
  } else {
    Serial.printf("[firestore] query failed (HTTP %d): %s\n", status, response.c_str());
    if (status == 403) {
      Serial.println("[firestore] permission denied: the device account must have the BFP Personnel role.");
    }
  }
  return status;
}

void pollOnce() {
  JsonDocument result;
  int status = queryIncidents(baselineReady ? lastSeenCreatedAt : String(), result);
  if (status == 401 || status == 403) idToken = "";  // sign in again next time
  if (status != 200) {
    online = false;
    return;
  }
  online = true;

  if (!baselineReady) {
    // Empty collection: accept anything created from now on.
    lastSeenCreatedAt = "1970-01-01T00:00:00Z";
    for (JsonObject row : result.as<JsonArray>()) {
      const char *createdAt = row["document"]["fields"]["createdAt"]["timestampValue"];
      if (createdAt) lastSeenCreatedAt = createdAt;
    }
    baselineReady = true;
    Serial.printf("[firestore] watching for reports after %s\n", lastSeenCreatedAt.c_str());
    return;
  }

  int strongest = SEV_NONE;
  for (JsonObject row : result.as<JsonArray>()) {
    JsonObject fields = row["document"]["fields"];
    if (fields.isNull()) continue;  // rows without a document only carry readTime
    const char *createdAt = fields["createdAt"]["timestampValue"];
    const char *priority = fields["priority"]["stringValue"];
    const char *type = fields["type"]["stringValue"] | "Incident";
    const char *barangay = fields["barangayName"]["stringValue"] | "-";
    if (createdAt) lastSeenCreatedAt = createdAt;

    int severity = severityFromPriority(priority);
    if (severity > strongest) strongest = severity;
    Serial.printf("[incident] NEW %s | priority %s | %s | %s\n",
                  type, priority ? priority : "?", barangay, createdAt ? createdAt : "");
  }
  if (strongest > SEV_NONE) requestAlarm(strongest);
}

void networkTask(void *) {
  wifiManager.setConnectTimeout(WIFI_CONNECT_TIMEOUT_S);
  wifiManager.setConfigPortalTimeout(SETUP_PORTAL_TIMEOUT_S);
  wifiManager.setAPCallback([](WiFiManager *) {
    setupPortalOpen = true;
    printSetupHint();
  });
  for (;;) {
    if (connectWifi() && ensureToken()) {
      pollOnce();
    } else {
      online = false;
    }
    vTaskDelay(pdMS_TO_TICKS(POLL_INTERVAL_MS));
  }
}

// =====================================================================
// Alarm output (loop, core 1): buzzer patterns, LEDs, STOP button
// =====================================================================

int activeSeverity = SEV_NONE;
unsigned long alarmStartedAt = 0;
int currentTone = 0;

void setTone(int frequency) {
  if (frequency == currentTone) return;
  currentTone = frequency;
  if (frequency > 0) {
    tone(BUZZER_PIN, frequency);
  } else {
    noTone(BUZZER_PIN);
  }
}

void setRelay(bool on) {
  on = on && USE_RELAY_SIREN;
  if (RELAY_VCC_ON_3V3) {
    digitalWrite(RELAY_PIN, on ? LOW : HIGH);  // same as the working test sketch
    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, on ? LOW : HIGH);
  } else if (on) {
    digitalWrite(RELAY_PIN, LOW);
    pinMode(RELAY_PIN, OUTPUT);
  } else {
    pinMode(RELAY_PIN, INPUT);  // released = relay off
  }
}

void startAlarm(int severity) {
  if (severity <= activeSeverity) return;  // never downgrade a running alarm
  activeSeverity = severity;
  alarmStartedAt = millis();
  setRelay(true);
  Serial.printf("[alarm] %s alarm ON - press STOP to silence\n", severityName(severity));
}

void stopAlarm() {
  if (activeSeverity == SEV_NONE) return;
  activeSeverity = SEV_NONE;
  setTone(0);
  setRelay(false);
  digitalWrite(RED_LED_PIN, LOW);
  Serial.println("[alarm] stopped");
}

// Computes the buzzer frequency and red LED state for the running alarm.
void updateAlarmOutput() {
  if (activeSeverity == SEV_NONE) return;
  unsigned long t = millis() - alarmStartedAt;
  int frequency = 0;
  bool red = false;

  switch (activeSeverity) {
    case SEV_CRITICAL: {
      // Long wail: 600 Hz up to 1500 Hz and back over 4 s, no gaps.
      unsigned long phase = t % 4000;
      unsigned long ramp = phase < 2000 ? phase : 4000 - phase;
      frequency = 600 + (int)(ramp * 900 / 2000);
      red = true;
      break;
    }
    case SEV_HIGH: {
      // Wang-wang: 700 Hz / 1200 Hz, 350 ms each.
      frequency = (t / 350) % 2 == 0 ? 700 : 1200;
      red = (t / 200) % 2 == 0;
      break;
    }
    case SEV_LOW: {
      // beep (150) gap (150) beep (150) pause (1050) = 1.5 s cycle.
      unsigned long phase = t % 1500;
      bool beep = phase < 150 || (phase >= 300 && phase < 450);
      frequency = beep ? 2000 : 0;
      red = (t / 600) % 2 == 0;
      break;
    }
  }
  setTone(frequency);
  digitalWrite(RED_LED_PIN, red ? HIGH : LOW);
}

// Green shows readiness; red blinks while the setup hotspot is open. A
// running alarm owns the red LED (updateAlarmOutput) and turns green off.
void updateStatusLeds() {
  if (activeSeverity == SEV_NONE) {
    bool red = setupPortalOpen && (millis() / 300) % 2 == 0;
    digitalWrite(RED_LED_PIN, red ? HIGH : LOW);
  }

  bool green;
  if (activeSeverity != SEV_NONE || setupPortalOpen) {
    green = false;
  } else if (online) {
    green = true;
  } else {
    green = (millis() / 500) % 2 == 0;  // blinking: connecting / error
  }
  digitalWrite(GREEN_LED_PIN, green ? HIGH : LOW);
}

bool lastReading = HIGH;
bool stableButton = HIGH;
unsigned long lastButtonChange = 0;
unsigned long buttonPressedAt = 0;
bool setupHoldHandled = false;

void updateButton() {
  bool reading = digitalRead(BUTTON_PIN);
  if (reading != lastReading) {
    lastButtonChange = millis();
    lastReading = reading;
  }
  if (millis() - lastButtonChange >= DEBOUNCE_MS && reading != stableButton) {
    stableButton = reading;
    if (stableButton == LOW) {  // INPUT_PULLUP: LOW = pressed
      Serial.println("[button] STOP pressed");
      buttonPressedAt = millis();
      setupHoldHandled = false;
      stopAlarm();
    }
  }
  if (stableButton == LOW && !setupHoldHandled && millis() - buttonPressedAt >= SETUP_HOLD_MS) {
    setupHoldHandled = true;
    if (setupPortalOpen) {
      setupPortalCloseRequested = true;
      wifiManager.stopConfigPortal();  // only sets a flag the portal loop checks
      Serial.println("[button] STOP held: closing Wi-Fi setup");
    } else {
      setupPortalRequested = true;
      Serial.println("[button] STOP held: opening Wi-Fi setup");
    }
    tone(BUZZER_PIN, 2000, 300);  // short confirmation beep
  }
}

// A command is one digit on its own line (Serial Monitor line ending must be
// "New Line" or "Both NL & CR"). Without USB the RX pin picks up noise, so
// single stray bytes must never start the siren: any non-printable byte
// spoils the current line.
String serialLine;
bool serialLineSpoiled = false;

void handleSerialCommands() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (!serialLineSpoiled && serialLine.length() == 1) {
        char cmd = serialLine[0];
        Serial.printf("[serial] test command %c\n", cmd);
        if (cmd >= '1' && cmd <= '3') {
          stopAlarm();
          startAlarm(cmd - '0');
        } else if (cmd == '0') {
          stopAlarm();
        }
      }
      serialLine = "";
      serialLineSpoiled = false;
    } else if (c < 32 || c > 126 || serialLine.length() >= 8) {
      serialLineSpoiled = true;
    } else {
      serialLine += c;
    }
  }
}

const char *resetReasonText(esp_reset_reason_t reason) {
  switch (reason) {
    case ESP_RST_POWERON: return "power on";
    case ESP_RST_BROWNOUT: return "BROWNOUT (power dipped: check the 5 V supply and relay)";
    case ESP_RST_PANIC: return "crash";
    case ESP_RST_SW: return "software restart";
    case ESP_RST_EXT: return "reset button";
    case ESP_RST_INT_WDT:
    case ESP_RST_TASK_WDT:
    case ESP_RST_WDT: return "watchdog";
    default: return "other";
  }
}

void setup() {
  // Relay first, before anything else, so the siren stays quiet at power-up.
  setRelay(false);

  Serial.begin(115200);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(GREEN_LED_PIN, LOW);

  Serial.println();
  Serial.println("BFP Rosario GIS - ESP32 incident alarm");
  Serial.printf("[boot] reset reason: %s\n", resetReasonText(esp_reset_reason()));
  Serial.println("Test: send 1 (Low), 2 (High), 3 (Critical), 0 (stop)");

  // Holding STOP while powering on opens Wi-Fi setup right away.
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("[button] STOP held at boot: opening Wi-Fi setup");
    setupPortalRequested = true;
    lastReading = LOW;  // releasing it later is not a new press
    stableButton = LOW;
    setupHoldHandled = true;
  }

  // Network calls block for up to a few seconds, so they run on core 0 and
  // never freeze the siren pattern or the STOP button on core 1. The setup
  // hotspot's web server also runs here, so the stack is a bit larger.
  xTaskCreatePinnedToCore(networkTask, "network", 20480, nullptr, 1, nullptr, 0);
}

void loop() {
  int requested = takeRequestedAlarm();
  if (requested != SEV_NONE) startAlarm(requested);

  updateButton();
  handleSerialCommands();
  updateAlarmOutput();
  updateStatusLeds();
  delay(10);
}
