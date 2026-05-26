import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String host, String clientId) {
  return MqttServerClient.withPort(host, clientId, 1883);
}
