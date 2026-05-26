#ifndef FOOD_BOWL_CONFIG_H
#define FOOD_BOWL_CONFIG_H

#include <Arduino.h>

// Change these for your network.
static constexpr const char* kWiFiSsid = "TP-Link_14DC";
static constexpr const char* kWiFiPassword = "28760795";

// Mosquitto TCP listener. ESP32 firmware and Flutter Android/native builds use
// this port. Flutter web builds use the broker's WebSocket listener, typically
// ws://192.168.0.49:9001, because browsers cannot open raw MQTT TCP sockets.
static constexpr const char* kMqttHost = "192.168.0.49";
static constexpr uint16_t kMqttPort = 1883;
static constexpr const char* kMqttUsername = "";
static constexpr const char* kMqttPassword = "";

static constexpr uint8_t kPinMotorIn1 = 16;
static constexpr uint8_t kPinMotorIn2 = 18;
static constexpr uint8_t kPinHallOpen = 33;
static constexpr uint8_t kPinHallClosed = 35;

static constexpr unsigned long kMotorTimeoutMs = 6000;
static constexpr unsigned long kSensorStableMs = 60;
static constexpr unsigned long kMqttReconnectDelayMs = 5000;
static constexpr unsigned long kWiFiReconnectDelayMs = 5000;

#endif
