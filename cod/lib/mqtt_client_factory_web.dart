import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createMqttClient(String brokerUri, String clientId) {
  final uri = Uri.parse(
    brokerUri.contains('://') ? brokerUri : 'ws://$brokerUri',
  );
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'ws' && scheme != 'wss') {
    throw ArgumentError.value(
      brokerUri,
      'brokerUri',
      'Browser builds must use a ws:// or wss:// MQTT broker URI.',
    );
  }

  final port =
      uri.hasPort
          ? uri.port
          : scheme == 'wss'
          ? 443
          : 9001;

  final client = MqttBrowserClient.withPort(uri.toString(), clientId, port);
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

  return client;
}
