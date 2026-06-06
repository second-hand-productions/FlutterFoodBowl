import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_factory_io.dart'
    if (dart.library.js_interop) 'mqtt_client_factory_web.dart' as mqtt_factory;

/// Creates an MQTT client for [wsUrl], the full WebSocket URL including the
/// `/mqtt` path, e.g. `ws://cla.lan/mqtt` or
/// `wss://ubuntuserver.tailb99a87.ts.net/mqtt`. nginx proxies it to the broker.
MqttClient createMqttClient(String wsUrl, String clientId) {
  return mqtt_factory.createMqttClient(wsUrl, clientId);
}
