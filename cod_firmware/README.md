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

Each physical bowl gets an automatic `BOWL_ID` derived from the ESP32 WiFi MAC
address, for example `bowl-aabbccddeeff`. Flash the same firmware to every
ESP32. When a bowl connects to MQTT, it publishes a retained discovery message.
The Flutter app sees that message and creates the PocketBase `bowls` record
automatically.

## MQTT

The sketch matches the Flutter app's per-bowl topics:

- Discovery topic: `foodbowl/discovery/<BOWL_ID>`
- Command topic: `foodbowl/<BOWL_ID>/door/set`
- Status topic: `foodbowl/<BOWL_ID>/door/status`

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
