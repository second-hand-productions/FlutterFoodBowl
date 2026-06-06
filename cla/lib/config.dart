import 'platform/backend_resolver_io.dart'
    if (dart.library.js_interop) 'platform/backend_resolver_web.dart' as resolver;

/// MQTT topic namespace shared by every bowl: `home/foodbowl/<bowlId>/<action>`.
const String topicPrefix = 'home/foodbowl';

/// Resolved backend endpoints for the reachable nginx front door. Both services
/// are reached through the same nginx: PocketBase under `/pb`, MQTT (WebSocket)
/// under `/mqtt`.
class AppConfig {
  const AppConfig({required this.pbUrl, required this.mqttWsUrl});

  final String pbUrl;
  final String mqttWsUrl;
}

/// Resolves which nginx endpoint to use (LAN vs Tailscale) and builds the
/// per-service URLs. Call once at startup, before constructing the services.
Future<AppConfig> loadConfig() async {
  final (httpBase, wsBase) = await resolver.resolveBackend();
  return AppConfig(pbUrl: '$httpBase/pb', mqttWsUrl: '$wsBase/mqtt');
}
