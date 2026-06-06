import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import '../config.dart';
import '../mqtt_client_factory.dart';
import '../models/bowl.dart';

class MqttService {
  late MqttClient _client;
  bool connected = false;

  void Function(bool connected, String message)? onStatusChanged;
  void Function(String bowlId, LidState state)? onLidStateChanged;
  void Function(String bowlId)? onAnnounce;

  Future<void> connect() async {
    final clientId =
        'flutter_food_bowl_${DateTime.now().millisecondsSinceEpoch}';
    _client = createMqttClient(mqttWsUrl, clientId);
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
    _client.subscribe(discoveryTopicFilter, MqttQos.atLeastOnce);
    _client.subscribe(
      '$canonicalTopicPrefix/+/door/status',
      MqttQos.atLeastOnce,
    );
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
      (rec.payload as MqttPublishMessage).payload.message,
    );
    final topic = rec.topic;

    if (_handleLegacyMessage(topic, payload)) {
      return;
    }

    if (_handleCanonicalMessage(topic, payload)) {
      return;
    }
  }

  bool _handleLegacyMessage(String topic, String payload) {
    final parts = topic.split('/');
    if (parts.length != 4 || parts[0] != 'home' || parts[1] != 'foodbowl') {
      return false;
    }

    final bowlId = parts[2];
    final action = parts[3];

    if (action == 'announce') {
      final announcedId = payload.trim().isEmpty ? bowlId : payload.trim();
      onAnnounce?.call(announcedId);
      return true;
    }

    if (action == 'status') {
      onLidStateChanged?.call(bowlId, _lidStateFromPayload(payload));
      return true;
    }

    return false;
  }

  bool _handleCanonicalMessage(String topic, String payload) {
    final parts = topic.split('/');
    if (parts.length == 3 &&
        parts[0] == canonicalTopicPrefix &&
        parts[1] == 'discovery') {
      onAnnounce?.call(_bowlIdFromDiscovery(parts[2], payload));
      return true;
    }

    if (parts.length != 4 ||
        parts[0] != canonicalTopicPrefix ||
        parts[2] != 'door') {
      return false;
    }

    if (parts[3] == 'status') {
      onLidStateChanged?.call(parts[1], _lidStateFromPayload(payload));
      return true;
    }

    return false;
  }

  LidState _lidStateFromPayload(String payload) {
    return switch (payload.trim().toLowerCase()) {
      'open' => LidState.open,
      'closed' => LidState.closed,
      _ => LidState.unknown,
    };
  }

  String _bowlIdFromDiscovery(String topicBowlId, String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final payloadBowlId = decoded['bowl_id'];
        if (payloadBowlId is String && payloadBowlId.trim().isNotEmpty) {
          return payloadBowlId.trim();
        }
      }
    } on FormatException {
      // The topic id is enough for discovery; legacy firmware may send text.
    }

    return topicBowlId.trim();
  }

  void publish(String bowlId, String command) {
    if (!connected) return;
    final builder = MqttClientPayloadBuilder()..addString(command);
    for (final topic in commandTopicsFor(bowlId)) {
      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  void disconnect() => _client.disconnect();
}
