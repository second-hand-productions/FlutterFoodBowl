import 'package:mqtt_client/mqtt_client.dart';
import '../config.dart' as config;
import '../platform/mqtt_client_factory.dart';
import '../models/bowl.dart';

/// Builds an [MqttClient] for [wsUrl] and [clientId]. Injectable so tests can
/// supply a fake transport instead of a real WebSocket client.
typedef MqttClientFactory = MqttClient Function(String wsUrl, String clientId);

class MqttService {
  MqttService({
    required this.wsUrl,
    this.topicPrefix = config.topicPrefix,
    MqttClientFactory clientFactory = createMqttClient,
  }) : _clientFactory = clientFactory;

  /// Full WebSocket URL including the `/mqtt` path, e.g. `ws://cla.lan/mqtt`.
  final String wsUrl;
  final String topicPrefix;
  final MqttClientFactory _clientFactory;

  late MqttClient _client;
  bool connected = false;

  void Function(bool connected, String message)? onStatusChanged;
  void Function(String bowlId, LidState state)? onLidStateChanged;
  void Function(String bowlId)? onAnnounce;

  Future<void> connect() async {
    final clientId =
        'flutter_food_bowl_${DateTime.now().millisecondsSinceEpoch}';
    _client = _clientFactory(wsUrl, clientId);
    _client.keepAlivePeriod = 30;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.logging(on: false);

    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await _client.connect().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timed out'),
      );
    } catch (e) {
      onStatusChanged?.call(false, 'Failed: $e — retrying…');
      _client.disconnect();
      Future.delayed(const Duration(seconds: 5), connect);
      return;
    }

    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      final code = _client.connectionStatus?.returnCode;
      onStatusChanged?.call(false, 'Refused ($code) — retrying…');
      _client.disconnect();
      Future.delayed(const Duration(seconds: 5), connect);
    }
  }

  void _onConnected() {
    _client.subscribe('$topicPrefix/+/status', MqttQos.atLeastOnce);
    _client.subscribe('$topicPrefix/+/announce', MqttQos.atLeastOnce);
    _client.updates?.listen(_onMessage);
    connected = true;
    onStatusChanged?.call(true, 'Connected');
  }

  void _onDisconnected() {
    connected = false;
    onStatusChanged?.call(false, 'Disconnected — retrying in 5 s…');
    Future.delayed(const Duration(seconds: 5), connect);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>> messages) {
    final rec = messages.first;
    final payload = MqttPublishPayload.bytesToStringAsString(
        (rec.payload as MqttPublishMessage).payload.message);
    handleMessage(rec.topic, payload);
  }

  /// Routes a decoded broker message — [topic] plus its string [payload] — to
  /// the matching callback. Split out from [_onMessage] so the routing logic
  /// can be unit-tested without a live MQTT connection.
  void handleMessage(String topic, String payload) {
    final parts = topic.split('/');
    if (parts.length < 4) return;
    final bowlId = parts[2];
    final action = parts[3];

    if (action == 'announce') {
      onAnnounce?.call(bowlId);
      return;
    }

    if (action == 'status') {
      final state = switch (payload) {
        'open' => LidState.open,
        'closed' => LidState.closed,
        _ => LidState.unknown,
      };
      onLidStateChanged?.call(bowlId, state);
    }
  }

  void publish(String bowlId, String command) {
    if (!connected) return;
    final builder = MqttClientPayloadBuilder()..addString(command);
    _client.publishMessage(
      '$topicPrefix/$bowlId/command',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void disconnect() => _client.disconnect();
}
