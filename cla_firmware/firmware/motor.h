#pragma once
/*
 * motor.h  —  non-blocking DRV8833 motor + Hall-sensor state machine.
 *
 * Usage:
 *   setup()  → motorInit()
 *   loop()   → const char* r = motorUpdate();
 *              if (r) publishStatus(r);   // "open" | "closed" | "failed"
 *
 *   On MQTT command: motorRequestOpen() or motorRequestClose().
 *   Both return immediately; motorUpdate() drives the motion over time.
 */

// Call once in setup() to configure pins.
void motorInit();

// Request a move. Ignored if a move is already in progress.
void motorRequestOpen();
void motorRequestClose();

// Tick the state machine — call every loop().
// Returns "open", "closed", or "failed" when a motion completes; nullptr otherwise.
const char* motorUpdate();
