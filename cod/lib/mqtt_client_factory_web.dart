import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createMqttClient(String brokerUri, String clientId) {
  final uri = Uri.parse(brokerUri);
  final port = uri.hasPort ? uri.port : 9001;

  return MqttBrowserClient.withPort(brokerUri, clientId, port);
}
