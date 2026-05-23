# Flutter Food Bowl Firmware

Arduino sketch: `food_bowl/food_bowl.ino`

## Libraries

Install these in Arduino IDE:

- ESP32 board support package
- PubSubClient by Nick O'Leary

## Configure

Edit these values at the top of `food_bowl.ino` before flashing:

- `WIFI_SSID`
- `WIFI_PASSWORD`
- `MQTT_HOST`
- `MQTT_USERNAME` and `MQTT_PASSWORD`, if your broker requires auth

## MQTT

The sketch matches the Flutter app topics:

- Command topic: `foodbowl/door/set`
- Status topic: `foodbowl/door/status`

Send `open` or `close` to the command topic. The firmware publishes:

- `open`, `closed`, `opening`, `closing`, `failed`, `unknown`, or `sensor_conflict` to `foodbowl/door/status`
- JSON command results to `foodbowl/door/result`
- `online` / `offline` availability to `foodbowl/door/availability`

## Wiring

Motor driver:

- IN1 -> ESP32 GPIO 25
- IN2 -> ESP32 GPIO 26

A3144 Hall effect sensors:

- Open-position sensor output -> ESP32 GPIO 32
- Closed-position sensor output -> ESP32 GPIO 33
- Sensor VCC -> 3.3 V
- Sensor GND -> common ground

The A3144 output is active-low. The sketch enables ESP32 internal pull-ups, but external 10k pull-up resistors are recommended for reliability.
