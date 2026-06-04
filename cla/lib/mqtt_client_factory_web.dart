import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// Web connects to the MQTT broker through the same nginx origin that served
/// the app (path `/mqtt`). This keeps a single build working on the LAN over
/// plain `ws://` and remotely over Tailscale with `wss://`, matching whatever
/// scheme/host/port the page was loaded with. The [host] argument is ignored.
MqttClient createMqttClient(String host, String clientId) {
  final base = Uri.base;
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';
  return MqttBrowserClient.withPort(
    '$scheme://${base.host}/mqtt',
    clientId,
    base.port,
  );
}
