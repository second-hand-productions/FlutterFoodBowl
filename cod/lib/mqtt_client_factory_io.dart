import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String brokerUri, String clientId) {
  final uri = Uri.parse(brokerUri);
  final port = uri.hasPort ? uri.port : 1883;

  return MqttServerClient.withPort(uri.host, clientId, port);
}
