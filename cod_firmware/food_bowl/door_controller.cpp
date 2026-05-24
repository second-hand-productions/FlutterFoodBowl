#include "door_controller.h"

#include "config.h"

void DoorController::begin() {
  pinMode(kPinMotorIn1, OUTPUT);
  pinMode(kPinMotorIn2, OUTPUT);
  stopMotor();

  pinMode(kPinHallOpen, INPUT_PULLUP);
  pinMode(kPinHallClosed, INPUT_PULLUP);
}

void DoorController::startOpening() {
  stopMotor();
  activeMove_ = MoveDirection::opening;
  moveStartedAt_ = millis();
  motorOpen();
}

void DoorController::startClosing() {
  stopMotor();
  activeMove_ = MoveDirection::closing;
  moveStartedAt_ = millis();
  motorClose();
}

DoorMotionResult DoorController::update() {
  if (!isMoving()) {
    return noMotion();
  }

  const DoorPosition position = currentPosition();
  if (position == DoorPosition::conflict) {
    return finishMove(false, "both_hall_sensors_active");
  }

  if (activeMove_ == MoveDirection::opening && position == DoorPosition::open) {
    return finishMove(true, "open_sensor_reached");
  }

  if (activeMove_ == MoveDirection::closing && position == DoorPosition::closed) {
    return finishMove(true, "closed_sensor_reached");
  }

  if (millis() - moveStartedAt_ >= kMotorTimeoutMs) {
    return finishMove(false, "movement_timeout");
  }

  return noMotion();
}

bool DoorController::isMoving() const {
  return activeMove_ != MoveDirection::none;
}

DoorPosition DoorController::currentPosition() {
  const bool isOpen = openSensorActive();
  const bool isClosed = closedSensorActive();

  if (isOpen && isClosed) {
    return DoorPosition::conflict;
  }
  if (isOpen) {
    return DoorPosition::open;
  }
  if (isClosed) {
    return DoorPosition::closed;
  }
  return DoorPosition::between;
}

bool DoorController::readActiveLowSensor(uint8_t pin, unsigned long& lowSince) {
  const unsigned long now = millis();
  if (digitalRead(pin) == LOW) {
    if (lowSince == 0) {
      lowSince = now;
    }
    return now - lowSince >= kSensorStableMs;
  }

  lowSince = 0;
  return false;
}

bool DoorController::openSensorActive() {
  return readActiveLowSensor(kPinHallOpen, openLowSince_);
}

bool DoorController::closedSensorActive() {
  return readActiveLowSensor(kPinHallClosed, closedLowSince_);
}

const char* DoorController::activeCommand() const {
  switch (activeMove_) {
    case MoveDirection::opening:
      return "open";
    case MoveDirection::closing:
      return "close";
    case MoveDirection::none:
    default:
      return "";
  }
}

DoorMotionResult DoorController::noMotion() const {
  return {false, false, "", ""};
}

DoorMotionResult DoorController::finishMove(bool success, const char* detail) {
  const char* command = activeCommand();
  stopMotor();
  activeMove_ = MoveDirection::none;
  return {true, success, command, detail};
}

void DoorController::stopMotor() {
  digitalWrite(kPinMotorIn1, LOW);
  digitalWrite(kPinMotorIn2, LOW);
}

void DoorController::motorOpen() {
  digitalWrite(kPinMotorIn1, HIGH);
  digitalWrite(kPinMotorIn2, LOW);
}

void DoorController::motorClose() {
  digitalWrite(kPinMotorIn1, LOW);
  digitalWrite(kPinMotorIn2, HIGH);
}

const char* positionName(DoorPosition position) {
  switch (position) {
    case DoorPosition::open:
      return "open";
    case DoorPosition::closed:
      return "closed";
    case DoorPosition::conflict:
      return "sensor_conflict";
    case DoorPosition::between:
    default:
      return "unknown";
  }
}
