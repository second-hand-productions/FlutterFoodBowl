import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createMqttClient(String host, String clientId) {
  return MqttBrowserClient.withPort('wss://$host', clientId, 9001);
}
