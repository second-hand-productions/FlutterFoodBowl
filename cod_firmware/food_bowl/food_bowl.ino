/*
  ESP32 firmware for the Flutter Food Bowl door.

  MQTT:
    Broker:    192.168.0.49:1883
    BOWL_ID is generated from the ESP32 WiFi MAC address.

    Publish:   foodbowl/discovery/<BOWL_ID> retained JSON discovery payload
    Subscribe: foodbowl/<BOWL_ID>/door/set       payload: open | close | status
    Publish:   foodbowl/<BOWL_ID>/door/status    retained status
    Publish:   foodbowl/<BOWL_ID>/door/result    JSON command result
    Publish:   foodbowl/<BOWL_ID>/door/availability  online | offline, retained
*/

#include <PubSubClient.h>
#include <WiFi.h>
#include <ctype.h>
#include <string.h>

#include "config.h"
#include "door_controller.h"
#include "food_bowl_protocol.h"

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
DoorController door;
FoodBowlIdentity identity;
FoodBowlTopics topics;

void publishDiscovery();

void publishStatus(const char* status) {
  mqtt.publish(topics.status, status, true);
  Serial.printf("[MQTT] publish %s = %s\n", topics.status, status);
}

void publishCurrentPosition() {
  publishStatus(positionName(door.currentPosition()));
}

void publishResult(const char* command, bool ok, const char* detail) {
  char payload[160];
  buildResultPayload(
    command,
    ok,
    positionName(door.currentPosition()),
    detail,
    payload,
    sizeof(payload)
  );

  mqtt.publish(topics.result, payload, false);
  Serial.printf("[MQTT] publish %s = %s\n", topics.result, payload);
}

void handleMotion() {
  const DoorMotionResult result = door.update();
  if (!result.completed) {
    return;
  }

  if (result.success) {
    publishCurrentPosition();
  } else {
    publishStatus("failed");
  }
  publishResult(result.command, result.success, result.detail);
}

void handleCommand(char* topic, byte* payload, unsigned int length) {
  char message[32];
  const unsigned int maxLength = sizeof(message) - 1;
  const unsigned int copyLength = length < maxLength ? length : maxLength;
  memcpy(message, payload, copyLength);
  message[copyLength] = '\0';

  for (unsigned int i = 0; i < copyLength; i++) {
    message[i] = static_cast<char>(
      tolower(static_cast<unsigned char>(message[i]))
    );
  }

  Serial.printf("[MQTT] received %s = %s\n", topic, message);

  if (strcmp(message, "status") == 0) {
    publishCurrentPosition();
    return;
  }

  if (door.isMoving()) {
    publishResult(message, false, "door_already_moving");
    return;
  }

  const DoorPosition position = door.currentPosition();
  if (position == DoorPosition::conflict) {
    publishStatus("sensor_conflict");
    publishResult(message, false, "both_hall_sensors_active");
    return;
  }

  if (strcmp(message, "open") == 0) {
    if (position == DoorPosition::open) {
      publishStatus("open");
      publishResult("open", true, "already_open");
    } else {
      door.startOpening();
      publishStatus("opening");
    }
    return;
  }

  if (strcmp(message, "close") == 0) {
    if (position == DoorPosition::closed) {
      publishStatus("closed");
      publishResult("close", true, "already_closed");
    } else {
      door.startClosing();
      publishStatus("closing");
    }
    return;
  }

  publishResult(message, false, "unknown_command");
}

void connectWiFiBlocking() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  Serial.printf("[WiFi] connecting to %s", kWiFiSsid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(kWiFiSsid, kWiFiPassword);

  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }

  Serial.printf(
    "\n[WiFi] connected, IP %s\n",
    WiFi.localIP().toString().c_str()
  );
}

void ensureWiFi() {
  static unsigned long lastAttemptAt = 0;

  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  if (millis() - lastAttemptAt < kWiFiReconnectDelayMs) {
    return;
  }

  lastAttemptAt = millis();
  Serial.printf("[WiFi] reconnecting to %s\n", kWiFiSsid);
  WiFi.disconnect();
  WiFi.mode(WIFI_STA);
  WiFi.begin(kWiFiSsid, kWiFiPassword);
}

bool connectMqttWithOptionalAuth() {
  if (strlen(kMqttUsername) == 0) {
    return mqtt.connect(
      identity.clientId,
      topics.availability,
      1,
      true,
      "offline"
    );
  }

  return mqtt.connect(
    identity.clientId,
    kMqttUsername,
    kMqttPassword,
    topics.availability,
    1,
    true,
    "offline"
  );
}

void ensureMqtt() {
  static unsigned long lastAttemptAt = 0;

  if (door.isMoving()) {
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  if (mqtt.connected()) {
    return;
  }

  if (millis() - lastAttemptAt < kMqttReconnectDelayMs) {
    return;
  }

  lastAttemptAt = millis();
  Serial.printf(
    "[MQTT] connecting to %s:%u as %s\n",
    kMqttHost,
    kMqttPort,
    identity.clientId
  );

  if (!connectMqttWithOptionalAuth()) {
    Serial.printf("[MQTT] connect failed, rc=%d\n", mqtt.state());
    return;
  }

  Serial.println("[MQTT] connected");
  mqtt.publish(topics.availability, "online", true);
  publishDiscovery();
  mqtt.subscribe(topics.command, 1);
  publishCurrentPosition();
}

void publishDiscovery() {
  const String ipAddress = WiFi.localIP().toString();
  char payload[192];
  buildDiscoveryPayload(identity, ipAddress.c_str(), payload, sizeof(payload));

  mqtt.publish(topics.discovery, payload, true);
  Serial.printf("[MQTT] publish %s = %s\n", topics.discovery, payload);
}

void setup() {
  Serial.begin(115200);
  delay(250);

  door.begin();

  WiFi.mode(WIFI_STA);
  buildIdentity(identity);
  buildTopics(identity.bowlId, topics);
  Serial.printf("[FoodBowl] generated BOWL_ID = %s\n", identity.bowlId);
  connectWiFiBlocking();

  mqtt.setServer(kMqttHost, kMqttPort);
  mqtt.setCallback(handleCommand);
  mqtt.setKeepAlive(30);
  mqtt.setSocketTimeout(3);

  ensureMqtt();
}

void loop() {
  handleMotion();
  ensureWiFi();
  ensureMqtt();
  mqtt.loop();
}
