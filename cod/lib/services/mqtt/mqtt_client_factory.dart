import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_factory_io.dart'
    if (dart.library.js_interop) 'mqtt_client_factory_web.dart'
    as mqtt_factory;

typedef MqttClientFactory =
    MqttClient Function(String brokerUri, String clientId);

MqttClient createMqttClient(String brokerUri, String clientId) {
  return mqtt_factory.createMqttClient(brokerUri, clientId);
}
