/*
 * firmware.ino  —  ESP32 pet food bowl lid controller
 *
 * Hardware
 * ─────────────────────────────────────────────────────────────────────────────
 *  DRV8833 motor driver
 *    AIN1 → GPIO 16  |  AIN2 → GPIO 18
 *    (VM to motor supply, GND to common ground)
 *
 *  A3144 Hall effect sensors  (output LOW when south-pole magnet present)
 *    OPEN   → GPIO 33  (aligns with magnet when lid is fully open)
 *    CLOSED → GPIO 35  (aligns with magnet when lid is fully closed)
 *    (3.3 V supply, internal pull-up enabled — external 10 kΩ recommended)
 *
 * MQTT topics  (id = lower-case MAC, no separators, e.g. a4cf123456ab)
 *    Subscribe:  home/foodbowl/{id}/command   payloads: "open" | "close"
 *    Publish:    home/foodbowl/{id}/status    payloads: "open" | "closed" | "failed" | "unknown"
 *                home/foodbowl/{id}/announce  payload:  "{id}"  (retained, on connect)
 *
 * Required libraries (Arduino Library Manager)
 *    PubSubClient  by Nick O'Leary  ≥ 2.8
 * ─────────────────────────────────────────────────────────────────────────────
 */
#include <WiFi.h>
#include <PubSubClient.h>
#include <string.h>
#include "config.h"
#include "motor.h"

// ── Bowl identity ─────────────────────────────────────────────────────────────
static char g_bowlId[13];         // 12 hex chars + null  e.g. "a4cf123456ab"
static char g_canonicalBowlId[18]; // "bowl-" + 12 hex chars + null
static char g_cmdTopic[64];
static char g_statusTopic[64];
static char g_announceTopic[64];
static char g_canonicalCmdTopic[80];
static char g_canonicalStatusTopic[80];
static char g_canonicalDiscoveryTopic[80];

// ── MQTT client ───────────────────────────────────────────────────────────────
static WiFiClient   s_wifiClient;
static PubSubClient s_mqtt(s_wifiClient);

// ── MQTT publish helpers ──────────────────────────────────────────────────────

void publishStatus(const char* status) {
  s_mqtt.publish(g_statusTopic, status, /*retained=*/true);
  s_mqtt.publish(g_canonicalStatusTopic, status, /*retained=*/true);
  Serial.printf("[MQTT] %s → %s\n", g_statusTopic, status);
}

void publishAnnounce() {
  s_mqtt.publish(g_announceTopic, g_bowlId, /*retained=*/true);
  char payload[128];
  const String ipAddress = WiFi.localIP().toString();
  snprintf(
    payload,
    sizeof(payload),
    "{\"bowl_id\":\"%s\",\"ip_address\":\"%s\"}",
    g_canonicalBowlId,
    ipAddress.c_str()
  );
  s_mqtt.publish(g_canonicalDiscoveryTopic, payload, /*retained=*/true);
  Serial.printf("[MQTT] %s → %s\n", g_announceTopic, g_bowlId);
}

void publishCurrentState() {
  if      (digitalRead(PIN_HALL_OPEN)   == LOW) publishStatus("open");
  else if (digitalRead(PIN_HALL_CLOSED) == LOW) publishStatus("closed");
  else                                          publishStatus("unknown");
}

// ── MQTT callback — returns immediately, motor runs in loop() ─────────────────
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  char msg[length + 1];
  memcpy(msg, payload, length);
  msg[length] = '\0';
  Serial.printf("[MQTT] ← %s : %s\n", topic, msg);

  static char lastMsg[32] = "";
  static unsigned long lastMsgAt = 0;
  if (strcmp(msg, lastMsg) == 0 && millis() - lastMsgAt < 500) {
    Serial.println("[MQTT] duplicate command ignored");
    return;
  }
  strncpy(lastMsg, msg, sizeof(lastMsg) - 1);
  lastMsg[sizeof(lastMsg) - 1] = '\0';
  lastMsgAt = millis();

  if      (strcmp(msg, "open")   == 0) motorRequestOpen();
  else if (strcmp(msg, "close")  == 0) motorRequestClose();
  else if (strcmp(msg, "status") == 0) publishCurrentState();
}

// ── WiFi & MQTT connection ────────────────────────────────────────────────────

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
  while (!s_mqtt.connected()) {
    Serial.printf("[MQTT] Connecting as %s…", g_bowlId);
    if (s_mqtt.connect(g_bowlId)) {
      Serial.println(" connected.");
      s_mqtt.subscribe(g_cmdTopic);
      s_mqtt.subscribe(g_canonicalCmdTopic);
      Serial.printf("[MQTT] Subscribed to %s\n", g_cmdTopic);
      Serial.printf("[MQTT] Subscribed to %s\n", g_canonicalCmdTopic);
      publishAnnounce();      // let Flutter apps discover this bowl
      publishCurrentState();  // report lid position on (re)connect
    } else {
      Serial.printf(" failed (rc=%d) — retrying in 5 s\n", s_mqtt.state());
      delay(5000);
    }
  }
}

// ── Arduino entry points ──────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(200);

  motorInit();

  // Build bowl ID from MAC (must init WiFi mode first)
  WiFi.mode(WIFI_STA);
  uint8_t mac[6];
  WiFi.macAddress(mac);
  snprintf(g_bowlId,        sizeof(g_bowlId),        "%02x%02x%02x%02x%02x%02x",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  snprintf(g_canonicalBowlId, sizeof(g_canonicalBowlId), "bowl-%s", g_bowlId);
  snprintf(g_cmdTopic,      sizeof(g_cmdTopic),      "%s/%s/command",  TOPIC_PREFIX, g_bowlId);
  snprintf(g_statusTopic,   sizeof(g_statusTopic),   "%s/%s/status",   TOPIC_PREFIX, g_bowlId);
  snprintf(g_announceTopic, sizeof(g_announceTopic), "%s/%s/announce", TOPIC_PREFIX, g_bowlId);
  snprintf(
    g_canonicalCmdTopic,
    sizeof(g_canonicalCmdTopic),
    "foodbowl/%s/door/set",
    g_canonicalBowlId
  );
  snprintf(
    g_canonicalStatusTopic,
    sizeof(g_canonicalStatusTopic),
    "foodbowl/%s/door/status",
    g_canonicalBowlId
  );
  snprintf(
    g_canonicalDiscoveryTopic,
    sizeof(g_canonicalDiscoveryTopic),
    "foodbowl/discovery/%s",
    g_canonicalBowlId
  );

  Serial.printf("\n[Bowl] ID:              %s\n", g_bowlId);
  Serial.printf("[Bowl] Canonical ID:    %s\n", g_canonicalBowlId);
  Serial.printf("[Bowl] Command topic:   %s\n", g_cmdTopic);
  Serial.printf("[Bowl] Status topic:    %s\n", g_statusTopic);
  Serial.printf("[Bowl] Announce topic:  %s\n", g_announceTopic);
  Serial.printf("[Bowl] Canonical cmd:   %s\n", g_canonicalCmdTopic);
  Serial.printf("[Bowl] Canonical status:%s\n", g_canonicalStatusTopic);

  connectWiFi();
  s_mqtt.setServer(MQTT_HOST, MQTT_PORT);
  s_mqtt.setCallback(mqttCallback);
  s_mqtt.setKeepAlive(30);  // seconds — MQTT_KEEPALIVE is reserved by PubSubClient.h
  connectMQTT();
}

void loop() {
  connectWiFi();
  if (!s_mqtt.connected()) connectMQTT();
  s_mqtt.loop();

  // Non-blocking motor tick — publishes result when motion completes
  const char* result = motorUpdate();
  if (result) publishStatus(result);
}
