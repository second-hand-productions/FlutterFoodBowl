/*
  ESP32 firmware for the Flutter Food Bowl door.

  MQTT:
    Broker:    192.168.0.49:1883
    BOWL_ID is generated from the ESP32 WiFi MAC address.

    Publish:   foodbowl/discovery/<BOWL_ID> retained JSON discovery payload
    Subscribe: foodbowl/<BOWL_ID>/door/set       payload: open | close | status
    Publish:   foodbowl/<BOWL_ID>/door/status    payloads below, retained
    Publish:   foodbowl/<BOWL_ID>/door/result    JSON command result, not retained
    Publish:   foodbowl/<BOWL_ID>/door/availability  online | offline, retained

  Hardware:
    DRV8833 / L298N style motor driver:
      IN1 -> GPIO 16
      IN2 -> GPIO 18

    Two A3144 Hall effect sensors:
      OPEN sensor   -> GPIO 33
      CLOSED sensor -> GPIO 35

    A3144 output is normally HIGH and goes LOW when the magnet is present.
    Use 3.3 V for the sensors and share ground with the ESP32 and motor driver.
*/

#include <PubSubClient.h>
#include <WiFi.h>
#include <ctype.h>
#include <string.h>

// Change these for your network.
const char* WIFI_SSID = "TP-Link_14DC";
const char* WIFI_PASSWORD = "28760795";

// Mosquitto TCP listener. The Flutter web app uses ws://192.168.0.49:9001,
// but ESP32 PubSubClient connects to the normal MQTT TCP port.
const char* MQTT_HOST = "192.168.0.49";
const uint16_t MQTT_PORT = 1883;
const char* MQTT_USERNAME = "";
const char* MQTT_PASSWORD = "";

char bowlId[24];
char macAddress[18];
char topicDiscovery[80];
char topicCommand[80];
char topicStatus[80];
char topicResult[80];
char topicAvailability[88];

const uint8_t PIN_MOTOR_IN1 = 16;
const uint8_t PIN_MOTOR_IN2 = 18;
const uint8_t PIN_HALL_OPEN = 33;
const uint8_t PIN_HALL_CLOSED = 35;

const unsigned long MOTOR_TIMEOUT_MS = 6000;
const unsigned long SENSOR_STABLE_MS = 60;
const unsigned long RECONNECT_DELAY_MS = 5000;
const unsigned long WIFI_RECONNECT_DELAY_MS = 5000;

enum DoorPosition {
  POSITION_OPEN,
  POSITION_CLOSED,
  POSITION_BETWEEN,
  POSITION_CONFLICT,
};

enum MoveDirection {
  MOVE_NONE,
  MOVE_OPENING,
  MOVE_CLOSING,
};

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

char clientId[64];
MoveDirection activeMove = MOVE_NONE;
unsigned long moveStartedAt = 0;
unsigned long openLowSince = 0;
unsigned long closedLowSince = 0;

void publishDiscovery();

bool readActiveLowSensor(uint8_t pin, unsigned long& lowSince) {
  if (digitalRead(pin) == LOW) {
    if (lowSince == 0) {
      lowSince = millis();
    }
    return millis() - lowSince >= SENSOR_STABLE_MS;
  }

  lowSince = 0;
  return false;
}

bool openSensorActive() {
  return readActiveLowSensor(PIN_HALL_OPEN, openLowSince);
}

bool closedSensorActive() {
  return readActiveLowSensor(PIN_HALL_CLOSED, closedLowSince);
}

DoorPosition currentPosition() {
  const bool isOpen = openSensorActive();
  const bool isClosed = closedSensorActive();

  if (isOpen && isClosed) {
    return POSITION_CONFLICT;
  }
  if (isOpen) {
    return POSITION_OPEN;
  }
  if (isClosed) {
    return POSITION_CLOSED;
  }
  return POSITION_BETWEEN;
}

const char* positionName(DoorPosition position) {
  switch (position) {
    case POSITION_OPEN:
      return "open";
    case POSITION_CLOSED:
      return "closed";
    case POSITION_CONFLICT:
      return "sensor_conflict";
    case POSITION_BETWEEN:
    default:
      return "unknown";
  }
}

void motorStop() {
  digitalWrite(PIN_MOTOR_IN1, LOW);
  digitalWrite(PIN_MOTOR_IN2, LOW);
}

void motorOpen() {
  digitalWrite(PIN_MOTOR_IN1, HIGH);
  digitalWrite(PIN_MOTOR_IN2, LOW);
}

void motorClose() {
  digitalWrite(PIN_MOTOR_IN1, LOW);
  digitalWrite(PIN_MOTOR_IN2, HIGH);
}

void publishStatus(const char* status) {
  mqtt.publish(topicStatus, status, true);
  Serial.printf("[MQTT] publish %s = %s\n", topicStatus, status);
}

void publishCurrentPosition() {
  publishStatus(positionName(currentPosition()));
}

void publishResult(const char* command, bool ok, const char* detail) {
  char payload[160];
  snprintf(
    payload,
    sizeof(payload),
    "{\"command\":\"%s\",\"success\":%s,\"status\":\"%s\",\"detail\":\"%s\"}",
    command,
    ok ? "true" : "false",
    positionName(currentPosition()),
    detail
  );

  mqtt.publish(topicResult, payload, false);
  Serial.printf("[MQTT] publish %s = %s\n", topicResult, payload);
}

void startMove(MoveDirection direction) {
  motorStop();
  activeMove = direction;
  moveStartedAt = millis();

  if (direction == MOVE_OPENING) {
    publishStatus("opening");
    motorOpen();
  } else if (direction == MOVE_CLOSING) {
    publishStatus("closing");
    motorClose();
  }
}

void finishMove(bool ok, const char* detail) {
  const MoveDirection completedMove = activeMove;
  const char* command = completedMove == MOVE_OPENING ? "open" : "close";

  motorStop();
  activeMove = MOVE_NONE;

  if (ok) {
    publishCurrentPosition();
  } else {
    publishStatus("failed");
  }
  publishResult(command, ok, detail);
}

void handleMotion() {
  if (activeMove == MOVE_NONE) {
    return;
  }

  const DoorPosition position = currentPosition();
  if (position == POSITION_CONFLICT) {
    finishMove(false, "both_hall_sensors_active");
    return;
  }

  if (activeMove == MOVE_OPENING && position == POSITION_OPEN) {
    finishMove(true, "open_sensor_reached");
    return;
  }

  if (activeMove == MOVE_CLOSING && position == POSITION_CLOSED) {
    finishMove(true, "closed_sensor_reached");
    return;
  }

  if (millis() - moveStartedAt >= MOTOR_TIMEOUT_MS) {
    finishMove(false, "movement_timeout");
  }
}

void handleCommand(char* topic, byte* payload, unsigned int length) {
  char message[32];
  const unsigned int copyLength = min(length, sizeof(message) - 1);
  memcpy(message, payload, copyLength);
  message[copyLength] = '\0';

  for (unsigned int i = 0; i < copyLength; i++) {
    message[i] = tolower(message[i]);
  }

  Serial.printf("[MQTT] received %s = %s\n", topic, message);

  if (strcmp(message, "status") == 0) {
    publishCurrentPosition();
    return;
  }

  if (activeMove != MOVE_NONE) {
    publishResult(message, false, "door_already_moving");
    return;
  }

  const DoorPosition position = currentPosition();
  if (position == POSITION_CONFLICT) {
    publishStatus("sensor_conflict");
    publishResult(message, false, "both_hall_sensors_active");
    return;
  }

  if (strcmp(message, "open") == 0) {
    if (position == POSITION_OPEN) {
      publishStatus("open");
      publishResult("open", true, "already_open");
    } else {
      startMove(MOVE_OPENING);
    }
    return;
  }

  if (strcmp(message, "close") == 0) {
    if (position == POSITION_CLOSED) {
      publishStatus("closed");
      publishResult("close", true, "already_closed");
    } else {
      startMove(MOVE_CLOSING);
    }
    return;
  }

  publishResult(message, false, "unknown_command");
}

void connectWiFiBlocking() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  Serial.printf("[WiFi] connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }

  Serial.printf("\n[WiFi] connected, IP %s\n", WiFi.localIP().toString().c_str());
}

void ensureWiFi() {
  static unsigned long lastAttemptAt = 0;

  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  if (millis() - lastAttemptAt < WIFI_RECONNECT_DELAY_MS) {
    return;
  }

  lastAttemptAt = millis();
  Serial.printf("[WiFi] reconnecting to %s\n", WIFI_SSID);
  WiFi.disconnect();
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

bool connectMqttWithOptionalAuth() {
  if (strlen(MQTT_USERNAME) == 0) {
    return mqtt.connect(clientId, topicAvailability, 1, true, "offline");
  }

  return mqtt.connect(
    clientId,
    MQTT_USERNAME,
    MQTT_PASSWORD,
    topicAvailability,
    1,
    true,
    "offline"
  );
}

void ensureMqtt() {
  static unsigned long lastAttemptAt = 0;

  if (activeMove != MOVE_NONE) {
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  if (mqtt.connected()) {
    return;
  }

  if (millis() - lastAttemptAt < RECONNECT_DELAY_MS) {
    return;
  }

  lastAttemptAt = millis();
  Serial.printf("[MQTT] connecting to %s:%u as %s\n", MQTT_HOST, MQTT_PORT, clientId);

  if (!connectMqttWithOptionalAuth()) {
    Serial.printf("[MQTT] connect failed, rc=%d\n", mqtt.state());
    return;
  }

  Serial.println("[MQTT] connected");
  mqtt.publish(topicAvailability, "online", true);
  publishDiscovery();
  mqtt.subscribe(topicCommand, 1);
  publishCurrentPosition();
}

void buildTopics() {
  snprintf(topicDiscovery, sizeof(topicDiscovery), "foodbowl/discovery/%s", bowlId);
  snprintf(topicCommand, sizeof(topicCommand), "foodbowl/%s/door/set", bowlId);
  snprintf(topicStatus, sizeof(topicStatus), "foodbowl/%s/door/status", bowlId);
  snprintf(topicResult, sizeof(topicResult), "foodbowl/%s/door/result", bowlId);
  snprintf(
    topicAvailability,
    sizeof(topicAvailability),
    "foodbowl/%s/door/availability",
    bowlId
  );
}

void publishDiscovery() {
  const String ipAddress = WiFi.localIP().toString();
  char payload[192];
  snprintf(
    payload,
    sizeof(payload),
    "{\"bowl_id\":\"%s\",\"mac_address\":\"%s\",\"ip_address\":\"%s\"}",
    bowlId,
    macAddress,
    ipAddress.c_str()
  );

  mqtt.publish(topicDiscovery, payload, true);
  Serial.printf("[MQTT] publish %s = %s\n", topicDiscovery, payload);
}

void buildIdentity() {
  uint8_t mac[6];
  WiFi.macAddress(mac);

  snprintf(
    macAddress,
    sizeof(macAddress),
    "%02x:%02x:%02x:%02x:%02x:%02x",
    mac[0],
    mac[1],
    mac[2],
    mac[3],
    mac[4],
    mac[5]
  );

  snprintf(
    bowlId,
    sizeof(bowlId),
    "bowl-%02x%02x%02x%02x%02x%02x",
    mac[0],
    mac[1],
    mac[2],
    mac[3],
    mac[4],
    mac[5]
  );

  snprintf(
    clientId,
    sizeof(clientId),
    "foodbowl-%s",
    bowlId
  );
}

void setup() {
  Serial.begin(115200);
  delay(250);

  pinMode(PIN_MOTOR_IN1, OUTPUT);
  pinMode(PIN_MOTOR_IN2, OUTPUT);
  motorStop();

  pinMode(PIN_HALL_OPEN, INPUT_PULLUP);
  pinMode(PIN_HALL_CLOSED, INPUT_PULLUP);

  WiFi.mode(WIFI_STA);
  buildIdentity();
  buildTopics();
  Serial.printf("[FoodBowl] generated BOWL_ID = %s\n", bowlId);
  connectWiFiBlocking();

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
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
