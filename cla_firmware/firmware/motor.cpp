#include "motor.h"
#include "config.h"
#include <Arduino.h>

// ── Internal state ────────────────────────────────────────────────────────────

enum class MotorTarget : uint8_t { NONE, OPEN, CLOSED };

static MotorTarget   s_target  = MotorTarget::NONE;
static unsigned long s_startMs = 0;

// ── Private helpers ───────────────────────────────────────────────────────────

static void motorStop() {
  digitalWrite(PIN_AIN1, LOW);
  digitalWrite(PIN_AIN2, LOW);  // coast; set both HIGH to hard-brake instead
}

static void motorDriveOpen() {
  digitalWrite(PIN_AIN1, HIGH);
  digitalWrite(PIN_AIN2, LOW);
}

static void motorDriveClose() {
  digitalWrite(PIN_AIN1, LOW);
  digitalWrite(PIN_AIN2, HIGH);
}

// ── Public API ────────────────────────────────────────────────────────────────

void motorInit() {
  pinMode(PIN_AIN1, OUTPUT);
  pinMode(PIN_AIN2, OUTPUT);
  motorStop();   // ensure motor is off at boot

  pinMode(PIN_HALL_OPEN,   INPUT_PULLUP);
  pinMode(PIN_HALL_CLOSED, INPUT_PULLUP);
}

void motorRequestOpen() {
  if (s_target != MotorTarget::NONE) return;  // already moving — ignore
  s_target  = MotorTarget::OPEN;
  s_startMs = millis();
  // If the sensor is already LOW we're already there; motorUpdate() will
  // detect that and return "open" on the very next loop tick without driving.
  if (digitalRead(PIN_HALL_OPEN) != LOW) motorDriveOpen();
}

void motorRequestClose() {
  if (s_target != MotorTarget::NONE) return;
  s_target  = MotorTarget::CLOSED;
  s_startMs = millis();
  if (digitalRead(PIN_HALL_CLOSED) != LOW) motorDriveClose();
}

const char* motorUpdate() {
  if (s_target == MotorTarget::NONE) return nullptr;

  // Check whether the target sensor has triggered.
  if (s_target == MotorTarget::OPEN) {
    if (digitalRead(PIN_HALL_OPEN) == LOW) {
      motorStop();
      s_target = MotorTarget::NONE;
      return "open";
    }
  } else {
    if (digitalRead(PIN_HALL_CLOSED) == LOW) {
      motorStop();
      s_target = MotorTarget::NONE;
      return "closed";
    }
  }

  // Timeout guard — stops the motor and reports failure.
  if (millis() - s_startMs >= MOTOR_TIMEOUT_MS) {
    motorStop();
    s_target = MotorTarget::NONE;
    return "failed";
  }

  return nullptr;  // still moving
}
