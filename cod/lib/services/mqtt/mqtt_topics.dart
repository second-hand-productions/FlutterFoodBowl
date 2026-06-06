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
