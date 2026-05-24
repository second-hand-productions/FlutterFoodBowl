#ifndef DOOR_CONTROLLER_H
#define DOOR_CONTROLLER_H

#include <Arduino.h>

enum class DoorPosition : uint8_t {
  open,
  closed,
  between,
  conflict,
};

enum class MoveDirection : uint8_t {
  none,
  opening,
  closing,
};

struct DoorMotionResult {
  bool completed;
  bool success;
  const char* command;
  const char* detail;
};

class DoorController {
 public:
  void begin();
  void startOpening();
  void startClosing();
  DoorMotionResult update();

  bool isMoving() const;
  DoorPosition currentPosition();

 private:
  bool readActiveLowSensor(uint8_t pin, unsigned long& lowSince);
  bool openSensorActive();
  bool closedSensorActive();
  const char* activeCommand() const;
  DoorMotionResult noMotion() const;
  DoorMotionResult finishMove(bool success, const char* detail);

  void stopMotor();
  void motorOpen();
  void motorClose();

  MoveDirection activeMove_ = MoveDirection::none;
  unsigned long moveStartedAt_ = 0;
  unsigned long openLowSince_ = 0;
  unsigned long closedLowSince_ = 0;
};

const char* positionName(DoorPosition position);

#endif
