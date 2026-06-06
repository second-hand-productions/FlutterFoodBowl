import 'package:pocketbase/pocketbase.dart';

import 'backend_resolver_io.dart'
    if (dart.library.js_interop) 'backend_resolver_web.dart'
    as resolver;

const String topicPrefix = 'home/foodbowl';
const String canonicalTopicPrefix = 'foodbowl';
const String discoveryTopicFilter = '$canonicalTopicPrefix/discovery/+';

final RegExp _macBowlIdPattern = RegExp(r'^[a-f0-9]{12}$');

String legacyCommandTopicFor(String bowlId) => '$topicPrefix/$bowlId/command';
String legacyStatusTopicFor(String bowlId) => '$topicPrefix/$bowlId/status';
String legacyAnnounceTopicFor(String bowlId) => '$topicPrefix/$bowlId/announce';

String doorCommandTopicFor(String bowlId) =>
    '$canonicalTopicPrefix/$bowlId/door/set';
String doorStatusTopicFor(String bowlId) =>
    '$canonicalTopicPrefix/$bowlId/door/status';

List<String> compatibleBowlIds(String bowlId) {
  final ids = <String>[];

  void add(String value) {
    if (value.isNotEmpty && !ids.contains(value)) {
      ids.add(value);
    }
  }

  final trimmed = bowlId.trim();
  final lower = trimmed.toLowerCase();
  add(trimmed);

  if (lower.startsWith('bowl-')) {
    add(lower);
    final suffix = lower.substring('bowl-'.length);
    if (_macBowlIdPattern.hasMatch(suffix)) {
      add(suffix);
    }
  } else if (_macBowlIdPattern.hasMatch(lower)) {
    add(lower);
    add('bowl-$lower');
  }

  return ids;
}

bool bowlIdsMatch(String configuredId, String receivedId) {
  final receivedIds = compatibleBowlIds(receivedId);
  return compatibleBowlIds(configuredId).any(receivedIds.contains);
}

Set<String> commandTopicsFor(String bowlId) {
  return {
    for (final id in compatibleBowlIds(bowlId)) legacyCommandTopicFor(id),
    for (final id in compatibleBowlIds(bowlId)) doorCommandTopicFor(id),
  };
}

// Set by [initBackend] before the app starts. Both services are reached through
// the same nginx front door: PocketBase under /pb, MQTT (WebSocket) under /mqtt.
late String pbUrl;
late String mqttWsUrl;
late PocketBase pb;

/// Resolves which nginx endpoint to use (LAN vs Tailscale) and wires up the
/// PocketBase client and MQTT WebSocket URL. Call once, before `runApp`.
Future<void> initBackend() async {
  final (httpBase, wsBase) = await resolver.resolveBackend();
  pbUrl = '$httpBase/pb';
  mqttWsUrl = '$wsBase/mqtt';
  pb = PocketBase(pbUrl);
}
