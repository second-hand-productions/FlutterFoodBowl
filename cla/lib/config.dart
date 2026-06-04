import 'package:pocketbase/pocketbase.dart';

import 'backend_resolver_io.dart'
    if (dart.library.js_interop) 'backend_resolver_web.dart' as resolver;

const String topicPrefix = 'home/foodbowl';

// Set by [initBackend] before the app starts. Both services are reached through
// the same nginx front door: PocketBase under /pb, MQTT (WebSocket) under /mqtt.
late String pbUrl;
late String mqttWsUrl;
late PocketBase pb;

/// Resolves which nginx endpoint to use (LAN vs Tailscale) and wires up the
/// PocketBase client and MQTT WebSocket URL. Call once, before `runApp`.
Future<void> initBackend() async {
  final (httpBase, wsBase) = await resolver.resolveBackend();
  pbUrl = '$httpBase/pb';
  mqttWsUrl = '$wsBase/mqtt';
  pb = PocketBase(pbUrl);
}
