import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// Web connects to the broker through nginx over WebSocket. [wsUrl] already
/// carries the scheme (ws/wss), host and /mqtt path inherited from the page
/// origin, so the same build works on the LAN and over Tailscale.
MqttClient createMqttClient(String wsUrl, String clientId) {
  final uri = Uri.parse(wsUrl);
  final port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);
  return MqttBrowserClient.withPort(wsUrl, clientId, port);
}
