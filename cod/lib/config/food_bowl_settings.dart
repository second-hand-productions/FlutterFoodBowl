import 'backend_resolver_io.dart'
    if (dart.library.js_interop) 'backend_resolver_web.dart'
    as resolver;

const String lanBackendHost = String.fromEnvironment(
  'FOOD_BOWL_LAN_HOST',
  defaultValue: 'cod.lan',
);
const String tailnetBackendHost = String.fromEnvironment(
  'FOOD_BOWL_TAILNET_HOST',
  defaultValue: 'ubuntuserver.tailb99a87.ts.net',
);
const String _configuredBrokerUri = String.fromEnvironment(
  'FOOD_BOWL_BROKER_URI',
);
const String _configuredPocketBaseUri = String.fromEnvironment(
  'FOOD_BOWL_POCKETBASE_URI',
);
const String _configuredHttpBaseUri = String.fromEnvironment(
  'FOOD_BOWL_HTTP_BASE_URI',
);
const String _configuredWebSocketBaseUri = String.fromEnvironment(
  'FOOD_BOWL_WEBSOCKET_BASE_URI',
);
const String _legacyWebBrokerUri = String.fromEnvironment(
  'FOOD_BOWL_WEB_BROKER_URI',
);
const String _legacyNativeBrokerUri = String.fromEnvironment(
  'FOOD_BOWL_NATIVE_BROKER_URI',
);

String brokerUri = _defaultBrokerUri;
String pocketBaseUri = _configuredPocketBaseUri.ifNotEmpty(
  'http://$lanBackendHost/pb',
);
const String bowlsCollection = 'bowls';
const String discoveryTopicFilter = 'foodbowl/discovery/+';
const String legacyTopicPrefix = 'home/foodbowl';
const String legacyAnnounceTopicFilter = '$legacyTopicPrefix/+/announce';

final RegExp _macBowlIdPattern = RegExp(r'^[a-f0-9]{12}$');

Future<void> initFoodBowlSettings() async {
  final brokerOverride = _configuredBrokerUri.ifNotEmpty(
    _legacyBrokerUriForPlatform,
  );
  final hasBrokerOverride = brokerOverride.isNotEmpty;
  final hasPocketBaseOverride = _configuredPocketBaseUri.isNotEmpty;

  if (hasBrokerOverride) {
    brokerUri = brokerOverride;
  }
  if (hasPocketBaseOverride) {
    pocketBaseUri = _configuredPocketBaseUri;
  }
  if (hasBrokerOverride && hasPocketBaseOverride) {
    return;
  }

  final needsResolvedBackend =
      _configuredHttpBaseUri.isEmpty || _configuredWebSocketBaseUri.isEmpty;
  final (resolvedHttpBaseUri, resolvedWebSocketBaseUri) =
      needsResolvedBackend
          ? await resolver.resolveBackend(
            lanHost: lanBackendHost,
            tailnetHost: tailnetBackendHost,
          )
          : ('', '');
  final httpBaseUri = _configuredHttpBaseUri.ifNotEmpty(resolvedHttpBaseUri);
  final webSocketBaseUri = _configuredWebSocketBaseUri.ifNotEmpty(
    resolvedWebSocketBaseUri,
  );

  if (!hasPocketBaseOverride) {
    pocketBaseUri = '${_withoutTrailingSlash(httpBaseUri)}/pb';
  }
  if (!hasBrokerOverride) {
    brokerUri = '${_withoutTrailingSlash(webSocketBaseUri)}/mqtt';
  }
}

String commandTopicFor(String bowlId) => 'foodbowl/$bowlId/door/set';
String statusTopicFor(String bowlId) => 'foodbowl/$bowlId/door/status';
String resultTopicFor(String bowlId) => 'foodbowl/$bowlId/door/result';
String availabilityTopicFor(String bowlId) =>
    'foodbowl/$bowlId/door/availability';
String legacyCommandTopicFor(String bowlId) =>
    '$legacyTopicPrefix/$bowlId/command';
String legacyStatusTopicFor(String bowlId) =>
    '$legacyTopicPrefix/$bowlId/status';

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
    for (final id in compatibleBowlIds(bowlId)) commandTopicFor(id),
    for (final id in compatibleBowlIds(bowlId)) legacyCommandTopicFor(id),
  };
}

bool isDiscoveryTopic(String topic) {
  final parts = topic.split('/');
  return parts.length == 3 && parts[0] == 'foodbowl' && parts[1] == 'discovery';
}

bool isLegacyAnnounceTopic(String topic) {
  final parts = topic.split('/');
  return parts.length == 4 &&
      parts[0] == 'home' &&
      parts[1] == 'foodbowl' &&
      parts[3] == 'announce';
}

bool isLegacyStatusTopic(String topic) {
  final parts = topic.split('/');
  return parts.length == 4 &&
      parts[0] == 'home' &&
      parts[1] == 'foodbowl' &&
      parts[3] == 'status';
}

bool isValidBowlId(String id) {
  return id.length <= 32 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
}

String _withoutTrailingSlash(String value) {
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

String get _defaultBrokerUri =>
    _legacyBrokerUriForPlatform.ifNotEmpty('ws://$lanBackendHost/mqtt');

String get _legacyBrokerUriForPlatform =>
    resolver.isBrowserBuild ? _legacyWebBrokerUri : _legacyNativeBrokerUri;

extension on String {
  String ifNotEmpty(String fallback) => isEmpty ? fallback : this;
}
