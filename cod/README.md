# Flutter Food Bowl App

Flutter MQTT controller for one or more ESP32 food bowl doors.

## Android build

Native builds use the Mosquitto TCP listener by default:

```powershell
flutter build apk
```

The default endpoints can be overridden at build time:

```powershell
flutter build apk `
  --dart-define=FOOD_BOWL_NATIVE_BROKER_URI=mqtt://192.168.0.49:1883 `
  --dart-define=FOOD_BOWL_POCKETBASE_URI=http://pocketbase.lan
```

Flutter web builds use the WebSocket listener by default:
`ws://192.168.0.49:9001`. To override both platforms with one value, pass
`--dart-define=FOOD_BOWL_BROKER_URI=...`.

## Bowls

The app loads configured bowls from PocketBase. When a new ESP32 bowl boots, it
publishes a retained discovery message on MQTT. The app listens for that
message and creates the missing PocketBase `bowls` record automatically.

Manual **Add bowl** still works as a fallback. Enter the generated `BOWL_ID`
printed by the ESP32 firmware serial monitor. It is derived from the ESP32 WiFi
MAC address, for example `bowl-aabbccddeeff`. Use 32 characters or fewer with
letters, numbers, `_`, or `-`.

Configured bowls are saved in PocketBase at `http://pocketbase.lan` in the
`bowls` collection. The app expects these fields:

- `bowl_id`
- `name`

MQTT is only used for device control and live device state. Each bowl uses its
own discovery, command, and status topics:

- Discovery: `foodbowl/discovery/<BOWL_ID>`
- Command: `foodbowl/<BOWL_ID>/door/set`
- Status: `foodbowl/<BOWL_ID>/door/status`
- Result: `foodbowl/<BOWL_ID>/door/result`
- Availability: `foodbowl/<BOWL_ID>/door/availability`

Because each physical bowl has its own `BOWL_ID`, the app can open or close
multiple bowls independently.
