import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pocketbase/pocketbase.dart';

const String topicPrefix = 'home/foodbowl';

// Native (Android) builds reach the broker directly over Tailscale MagicDNS.
// The web build ignores this and connects same-origin via nginx (/mqtt).
const String mqttHost = 'mqtt.tailb99a87.ts.net';

// Web uses a same-origin path (proxied by nginx to PocketBase) so one build
// works on the LAN (http://cla.lan) and remotely over Tailscale.
// Native builds talk to PocketBase over Tailscale directly.
final String pbUrl =
    kIsWeb ? '${Uri.base.origin}/pb' : 'https://ubuntuserver.tailb99a87.ts.net';

final pb = PocketBase(pbUrl);
