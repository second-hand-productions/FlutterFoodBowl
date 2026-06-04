import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pocketbase/pocketbase.dart';

const String topicPrefix = 'home/foodbowl';

// Native (Android) builds reach the broker directly over Tailscale MagicDNS.
// The web build ignores this and connects same-origin via nginx (/mqtt).
const String mqttHost = 'mqtt.tailb99a87.ts.net';

// PocketBase is reached through nginx under the /pb prefix on both platforms.
// Web uses the same origin that served the app (works on the LAN and over
// Tailscale); native targets the Tailscale name directly. nginx strips /pb/.
final String pbUrl = kIsWeb
    ? '${Uri.base.origin}/pb'
    : 'https://ubuntuserver.tailb99a87.ts.net/pb';

final pb = PocketBase(pbUrl);
