import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String brokerUri, String clientId) {
  final uri = Uri.parse(
    brokerUri.contains('://') ? brokerUri : 'mqtt://$brokerUri',
  );
  final scheme = uri.scheme.toLowerCase();
  final isWebSocket = scheme == 'ws' || scheme == 'wss';
  final isSecureTcp = scheme == 'mqtts' || scheme == 'ssl' || scheme == 'tls';
  final defaultPort =
      isWebSocket
          ? scheme == 'wss'
              ? 443
              : 80
          : isSecureTcp
          ? 8883
          : 1883;
  final port = uri.hasPort ? uri.port : defaultPort;

  if (uri.host.isEmpty) {
    throw ArgumentError.value(
      brokerUri,
      'brokerUri',
      'Include a broker host, for example mqtt://192.168.0.49:1883.',
    );
  }

  final client = MqttServerClient.withPort(
    isWebSocket ? uri.toString() : uri.host,
    clientId,
    port,
  );
  client.useWebSocket = isWebSocket;
  client.secure = isSecureTcp;
  if (isWebSocket) {
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  }

  return client;
}
