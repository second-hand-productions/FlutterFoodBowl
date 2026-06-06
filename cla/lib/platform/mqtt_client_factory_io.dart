import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Native connects to the broker through nginx over WebSocket — the same
/// `/mqtt` endpoint the web build uses — so one build works on the LAN
/// (ws://cla.lan/mqtt) and remotely over Tailscale (wss://…/mqtt).
///
/// Note: TLS for `wss://` is handled at the WebSocket layer via the URL scheme.
/// Do NOT set `secure = true` — the client disables WebSocket mode when it is.
MqttClient createMqttClient(String wsUrl, String clientId) {
  final uri = Uri.parse(wsUrl);
  final port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);
  return MqttServerClient.withPort(wsUrl, clientId, port)..useWebSocket = true;
}
