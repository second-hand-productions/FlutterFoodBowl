/*
 * food_bowl.ino
 * ESP32 firmware for the pet food bowl lid controller.
 *
 * Hardware
 * ─────────────────────────────────────────────────────────────────────────────
 *  DRV8833 motor driver
 *    AIN1  → GPIO 25
 *    AIN2  → GPIO 26
 *    (connect VM to motor supply, GND to common ground)
 *
 *  A3144 Hall effect sensors  (output LOW when south-pole magnet present)
 *    HALL_OPEN   → GPIO 32  (sensor aligns with magnet when lid is fully open)
 *    HALL_CLOSED → GPIO 33  (sensor aligns with magnet when lid is fully closed)
 *    (3.3 V supply, internal pull-up enabled — external 10 kΩ pull-up recommended)
 *
 * MQTT topics  (bowl ID = lower-case MAC with no separators, e.g. a4cf123456ab)
 *    Subscribe:  home/foodbowl/{id}/command   payloads: "open" | "close"
 *    Publish:    home/foodbowl/{id}/status    payloads: "open" | "closed" | "failed" | "unknown"
 *
 * Required libraries (install via Arduino Library Manager)
 *    PubSubClient  by Nick O'Leary  ≥ 2.8
 * ─────────────────────────────────────────────────────────────────────────────
 */
#include <WiFi.h>
#include <PubSubClient.h>
// ── WiFi credentials ──────────────────────────────────────────────────────────
const char* WIFI_SSID     = "YOUR_SSID";
const char* WIFI_PASSWORD = "YOUR_PASSWORD";
// ── MQTT broker ───────────────────────────────────────────────────────────────
const char* MQTT_HOST = "192.168.0.49";
const int   MQTT_PORT = 1883;           // TCP port (not the WebSocket 9001 port)
// ── Topic namespace ───────────────────────────────────────────────────────────
const char* TOPIC_PREFIX = "home/foodbowl";
// ── Pin assignments ───────────────────────────────────────────────────────────
const int PIN_AIN1        = 16;   // DRV8833 AIN1  (motor direction A)
const int PIN_AIN2        = 18;   // DRV8833 AIN2  (motor direction B)
const int PIN_HALL_OPEN   = 33;   // A3144 output — LOW = open position reached
const int PIN_HALL_CLOSED = 35;   // A3144 output — LOW = closed position reached
// ── Tuning ────────────────────────────────────────────────────────────────────
const unsigned long MOTOR_TIMEOUT_MS = 5000;  // max travel time before "failed"
// ── Global state ──────────────────────────────────────────────────────────────
char g_bowlId[13];        // 12 hex chars + null  e.g. "a4cf123456ab"
char g_cmdTopic[64];
char g_statusTopic[64];
WiFiClient   wifiClient;
PubSubClient mqtt(wifiClient);
// ─────────────────────────────────────────────────────────────────────────────
// Motor helpers
// ─────────────────────────────────────────────────────────────────────────────
void motorStop() {
  digitalWrite(PIN_AIN1, LOW);
  digitalWrite(PIN_AIN2, LOW);   // coast — change both HIGH to brake instead
}
// Drive motor in the "open" direction at full speed.
// If open/close are reversed, swap the AIN1/AIN2 assignments here.
void motorDriveOpen() {
  digitalWrite(PIN_AIN1, HIGH);
  digitalWrite(PIN_AIN2, LOW);
}
void motorDriveClose() {
  digitalWrite(PIN_AIN1, LOW);
  digitalWrite(PIN_AIN2, HIGH);
}
// Returns true if the target hall sensor goes LOW within MOTOR_TIMEOUT_MS.
bool driveUntilSensor(void (*driveFunc)(), int sensorPin) {
  if (digitalRead(sensorPin) == LOW) {
    return true;   // already at target position
  }
  driveFunc();
  unsigned long start = millis();
  while (millis() - start < MOTOR_TIMEOUT_MS) {
    if (digitalRead(sensorPin) == LOW) {
      motorStop();
      return true;
    }
    delay(10);
  }
  motorStop();
  return false;
}
// ─────────────────────────────────────────────────────────────────────────────
// MQTT helpers
// ─────────────────────────────────────────────────────────────────────────────
void publishStatus(const char* status) {
  mqtt.publish(g_statusTopic, status, /*retained=*/true);
  Serial.printf("[MQTT] %s → %s\n", g_statusTopic, status);
}
void publishCurrentState() {
  if      (digitalRead(PIN_HALL_OPEN)   == LOW) publishStatus("open");
  else if (digitalRead(PIN_HALL_CLOSED) == LOW) publishStatus("closed");
  else                                          publishStatus("unknown");
}
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  char msg[length + 1];
  memcpy(msg, payload, length);
  msg[length] = '\0';
  Serial.printf("[MQTT] %s → %s\n", topic, msg);
  if (strcmp(msg, "open") == 0) {
    bool ok = driveUntilSensor(motorDriveOpen, PIN_HALL_OPEN);
    publishStatus(ok ? "open" : "failed");
  } else if (strcmp(msg, "close") == 0) {
    bool ok = driveUntilSensor(motorDriveClose, PIN_HALL_CLOSED);
    publishStatus(ok ? "closed" : "failed");
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// WiFi & MQTT connection
// ─────────────────────────────────────────────────────────────────────────────
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\n[WiFi] Connected — IP: %s\n", WiFi.localIP().toString().c_str());
}
void connectMQTT() {
  while (!mqtt.connected()) {
    Serial.printf("[MQTT] Connecting as %s…", g_bowlId);
    if (mqtt.connect(g_bowlId)) {
      Serial.println(" connected.");
      mqtt.subscribe(g_cmdTopic);
      Serial.printf("[MQTT] Subscribed to %s\n", g_cmdTopic);
      publishCurrentState();   // announce lid position on (re)connect
    } else {
      Serial.printf(" failed (rc=%d) — retrying in 5 s\n", mqtt.state());
      delay(5000);
    }
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Arduino entry points
// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(200);
  // Motor pins — ensure motor is stopped at boot
  pinMode(PIN_AIN1, OUTPUT);
  pinMode(PIN_AIN2, OUTPUT);
  motorStop();
  // Hall sensor pins — internal pull-up; add external 10 kΩ for reliability
  pinMode(PIN_HALL_OPEN,   INPUT_PULLUP);
  pinMode(PIN_HALL_CLOSED, INPUT_PULLUP);
  // Build bowl ID from MAC address (no separators)
  uint8_t mac[6];
  WiFi.macAddress(mac);
  snprintf(g_bowlId, sizeof(g_bowlId), "%02x%02x%02x%02x%02x%02x",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  snprintf(g_cmdTopic,    sizeof(g_cmdTopic),    "%s/%s/command", TOPIC_PREFIX, g_bowlId);
  snprintf(g_statusTopic, sizeof(g_statusTopic), "%s/%s/status",  TOPIC_PREFIX, g_bowlId);
  Serial.printf("\n[Bowl] ID:             %s\n", g_bowlId);
  Serial.printf("[Bowl] Command topic:  %s\n", g_cmdTopic);
  Serial.printf("[Bowl] Status topic:   %s\n", g_statusTopic);
  connectWiFi();
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setKeepAlive(30);
  connectMQTT();
}
void loop() {
  connectWiFi();
  if (!mqtt.connected()) {
    connectMQTT();
  }
  mqtt.loop();
}