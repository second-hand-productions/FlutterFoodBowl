#pragma once
/*
 * config.h  —  all site-specific constants for the food bowl firmware.
 *
 * This file contains WiFi credentials — add it to .gitignore and keep a
 * config.h.example (no real credentials) committed instead.
 */

// ── WiFi ──────────────────────────────────────────────────────────────────────
#define WIFI_SSID     "TP-Link_14DC"
#define WIFI_PASSWORD "28760795"

// ── MQTT broker ───────────────────────────────────────────────────────────────
#define MQTT_HOST "192.168.0.49"
constexpr int MQTT_PORT = 1883;   // TCP (not the WebSocket 9001 port)

// ── Topic namespace ───────────────────────────────────────────────────────────
#define TOPIC_PREFIX "home/foodbowl"

// ── Pin assignments ───────────────────────────────────────────────────────────
//   DRV8833 motor driver
constexpr int PIN_AIN1 = 16;   // motor direction A
constexpr int PIN_AIN2 = 18;   // motor direction B
//   A3144 Hall effect sensors (output LOW when south-pole magnet present)
constexpr int PIN_HALL_OPEN   = 33;   // LOW = lid fully open
constexpr int PIN_HALL_CLOSED = 35;   // LOW = lid fully closed

// ── Motor tuning ──────────────────────────────────────────────────────────────
constexpr unsigned long MOTOR_TIMEOUT_MS = 5000;  // max travel time → "failed"
