# Flutter Food Bowl Firmware

Arduino sketch: `food_bowl/food_bowl.ino`

## Libraries

Install these in Arduino IDE:

- ESP32 board support package
- PubSubClient by Nick O'Leary

## Configure

Edit these values in `food_bowl/config.h` before flashing:

- `kWiFiSsid`
- `kWiFiPassword`
- `kMqttHost`
- `kMqttPort`
- `kMqttUsername` and `kMqttPassword`, if your broker requires auth

Each physical bowl gets an automatic `BOWL_ID` derived from the ESP32 WiFi MAC
address, for example `bowl-aabbccddeeff`. Flash the same firmware to every
ESP32. When a bowl connects to MQTT, it publishes a retained discovery message.
The Flutter app sees that message and creates the PocketBase `bowls` record
automatically.

## MQTT

The ESP32 firmware uses normal MQTT TCP, for example
`192.168.0.49:1883`. The Flutter Android app uses that same TCP listener.
Flutter web builds must use a Mosquitto WebSocket listener, for example
`ws://192.168.0.49:9001`.

The sketch matches the Flutter app's per-bowl topics:

- Discovery topic: `foodbowl/discovery/<BOWL_ID>`
- Command topic: `foodbowl/<BOWL_ID>/door/set`
- Status topic: `foodbowl/<BOWL_ID>/door/status`

For compatibility with the older CLA app/firmware, the same board also accepts
`home/foodbowl/<MAC_ID>/command` and publishes
`home/foodbowl/<MAC_ID>/status` plus `home/foodbowl/<MAC_ID>/announce`, where
`MAC_ID` is the raw 12-character MAC suffix from `BOWL_ID`
(`bowl-aabbccddeeff` -> `aabbccddeeff`).

The discovery payload includes `bowl_id`, `mac_address`, and `ip_address`.

Send `open` or `close` to the command topic. The firmware publishes:

- `open`, `closed`, `opening`, `closing`, `failed`, `unknown`, or `sensor_conflict` to `foodbowl/<BOWL_ID>/door/status`
- JSON command results to `foodbowl/<BOWL_ID>/door/result`
- `online` / `offline` availability to `foodbowl/<BOWL_ID>/door/availability`

Because each ESP32 subscribes only to its own command topic, opening one bowl
does not move the others.

## Wiring

Motor driver:

- IN1 -> ESP32 GPIO 16
- IN2 -> ESP32 GPIO 18

A3144 Hall effect sensors:

- Open-position sensor output -> ESP32 GPIO 33
- Closed-position sensor output -> ESP32 GPIO 35
- Sensor VCC -> 3.3 V
- Sensor GND -> common ground

The A3144 output is active-low. The sketch enables ESP32 internal pull-ups, but external 10k pull-up resistors are recommended for reliability.
