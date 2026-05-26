const bool isBrowserBuild = bool.fromEnvironment('dart.library.js_interop');

const String webBrokerUri = String.fromEnvironment(
  'FOOD_BOWL_WEB_BROKER_URI',
  defaultValue: 'ws://192.168.0.49:9001',
);
const String nativeBrokerUri = String.fromEnvironment(
  'FOOD_BOWL_NATIVE_BROKER_URI',
  defaultValue: 'mqtt://192.168.0.49:1883',
);
const String brokerUri = String.fromEnvironment(
  'FOOD_BOWL_BROKER_URI',
  defaultValue: isBrowserBuild ? webBrokerUri : nativeBrokerUri,
);
const String pocketBaseUri = String.fromEnvironment(
  'FOOD_BOWL_POCKETBASE_URI',
  defaultValue: 'http://pocketbase.lan',
);
const String bowlsCollection = 'bowls';
const String discoveryTopicFilter = 'foodbowl/discovery/+';

String commandTopicFor(String bowlId) => 'foodbowl/$bowlId/door/set';
String statusTopicFor(String bowlId) => 'foodbowl/$bowlId/door/status';
String resultTopicFor(String bowlId) => 'foodbowl/$bowlId/door/result';
String availabilityTopicFor(String bowlId) =>
    'foodbowl/$bowlId/door/availability';

bool isDiscoveryTopic(String topic) {
  final parts = topic.split('/');
  return parts.length == 3 && parts[0] == 'foodbowl' && parts[1] == 'discovery';
}

bool isValidBowlId(String id) {
  return id.length <= 32 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
}
