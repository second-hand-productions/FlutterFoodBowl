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
const String _configuredFrigateUri = String.fromEnvironment(
  'FOOD_BOWL_FRIGATE_URI',
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
String frigateUri = _configuredFrigateUri.ifNotEmpty(
  'http://$lanBackendHost/frigate',
);
const String bowlsCollection = 'bowls';
const String cameraCollection = String.fromEnvironment(
  'FOOD_BOWL_CAMERA_COLLECTION',
  defaultValue: 'camera',
);
const String cameraBowlRelationField = String.fromEnvironment(
  'FOOD_BOWL_CAMERA_BOWL_FIELD',
  defaultValue: 'bowl',
);

Future<void> initFoodBowlSettings() async {
  final brokerOverride = _configuredBrokerUri.ifNotEmpty(
    _legacyBrokerUriForPlatform,
  );
  final hasBrokerOverride = brokerOverride.isNotEmpty;
  final hasPocketBaseOverride = _configuredPocketBaseUri.isNotEmpty;
  final hasFrigateOverride = _configuredFrigateUri.isNotEmpty;

  if (hasBrokerOverride) {
    brokerUri = brokerOverride;
  }
  if (hasPocketBaseOverride) {
    pocketBaseUri = _configuredPocketBaseUri;
  }
  if (hasFrigateOverride) {
    frigateUri = _configuredFrigateUri;
  }
  if (hasBrokerOverride && hasPocketBaseOverride && hasFrigateOverride) {
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
  if (!hasFrigateOverride) {
    frigateUri = '${_withoutTrailingSlash(httpBaseUri)}/frigate';
  }
  if (!hasBrokerOverride) {
    brokerUri = '${_withoutTrailingSlash(webSocketBaseUri)}/mqtt';
  }
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
