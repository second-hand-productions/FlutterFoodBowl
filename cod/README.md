# Flutter Food Bowl App

Flutter MQTT controller for one or more ESP32 food bowl doors.

## Android build

Native builds use the nginx front door by default. The app probes the LAN host
first (`http://cod.lan` / `ws://cod.lan`) and falls back to Tailscale
(`https://ubuntuserver.tailb99a87.ts.net` / `wss://ubuntuserver.tailb99a87.ts.net`):

```powershell
flutter build apk
```

The default hosts can be overridden at build time:

```powershell
flutter build apk `
  --dart-define=FOOD_BOWL_LAN_HOST=cod.lan `
  --dart-define=FOOD_BOWL_TAILNET_HOST=ubuntuserver.tailb99a87.ts.net
```

Flutter web builds inherit the origin that served the page. Open the same build
at `http://cod.lan/cod/` on the local subnet or
`https://ubuntuserver.tailb99a87.ts.net/cod/` over Tailscale; the app will use
same-origin `/pb` for PocketBase and `/mqtt` for MQTT WebSockets. nginx owns
the shared root and serves both apps by path.

For one-off builds, you can still override direct endpoints:

```powershell
flutter build apk `
  --dart-define=FOOD_BOWL_BROKER_URI=wss://ubuntuserver.tailb99a87.ts.net/mqtt `
  --dart-define=FOOD_BOWL_POCKETBASE_URI=https://ubuntuserver.tailb99a87.ts.net/pb
```

## Bowls

The app loads configured bowls from PocketBase. When a new ESP32 bowl boots, it
publishes a retained discovery message on MQTT. The app listens for that
message and creates the missing PocketBase `bowls` record automatically.

Manual **Add bowl** still works as a fallback. Enter the generated `BOWL_ID`
printed by the ESP32 firmware serial monitor. It is derived from the ESP32 WiFi
MAC address, for example `bowl-aabbccddeeff`. Use 32 characters or fewer with
letters, numbers, `_`, or `-`.

Configured bowls are saved in PocketBase through nginx at `/pb` in the `bowls`
collection. The app expects these fields:

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
