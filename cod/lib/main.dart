import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_factory.dart';

const String brokerUri = 'ws://192.168.0.49:9001';
const String commandTopic = 'foodbowl/door/set';
const String statusTopic = 'foodbowl/door/status';

void main() {
  runApp(const FoodBowlApp());
}

class FoodBowlApp extends StatelessWidget {
  const FoodBowlApp({super.key, this.autoConnect = true});

  final bool autoConnect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E7E67),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Food Bowl',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: FoodBowlHomePage(autoConnect: autoConnect),
    );
  }
}

enum BrokerState { disconnected, connecting, connected, error }

class FoodBowlHomePage extends StatefulWidget {
  const FoodBowlHomePage({super.key, this.autoConnect = true});

  final bool autoConnect;

  @override
  State<FoodBowlHomePage> createState() => _FoodBowlHomePageState();
}

class _FoodBowlHomePageState extends State<FoodBowlHomePage> {
  MqttClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;
  BrokerState _brokerState = BrokerState.disconnected;
  String _statusMessage = 'Starting connection';
  String _lastPayload = 'No status received yet';
  String _lastCommand = 'None';

  bool get _isConnected => _brokerState == BrokerState.connected;
  bool get _isBusy => _brokerState == BrokerState.connecting;

  @override
  void initState() {
    super.initState();
    if (widget.autoConnect) {
      unawaited(_connect());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _brokerState = BrokerState.connecting;
      _statusMessage = 'Connecting to $brokerUri';
    });

    await _subscription?.cancel();
    _client?.disconnect();

    final clientId = 'food_bowl_app_${DateTime.now().millisecondsSinceEpoch}';
    final client = createMqttClient(brokerUri, clientId);
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.onConnected = _handleConnected;
    client.onDisconnected = _handleDisconnected;
    client.onSubscribed = (topic) => _setStatus('Subscribed to $topic');
    client.pongCallback = () => _setStatus('Broker heartbeat received');
    client.logging(on: false);

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await client.connect();
    } on Exception catch (error) {
      client.disconnect();
      _setError('Connection failed: $error');
      return;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      final reason = client.connectionStatus?.returnCode?.name ?? 'unknown';
      client.disconnect();
      _setError('Connection failed: $reason');
      return;
    }

    _subscription = client.updates?.listen(_handleMessage);
    client.subscribe(statusTopic, MqttQos.atLeastOnce);

    setState(() {
      _client = client;
      _brokerState = BrokerState.connected;
      _statusMessage = 'Connected to $brokerUri';
    });
  }

  void _disconnect() {
    _client?.disconnect();
    setState(() {
      _brokerState = BrokerState.disconnected;
      _statusMessage = 'Disconnected';
    });
  }

  void _handleConnected() {
    _setStatus('Connected');
  }

  void _handleDisconnected() {
    if (!mounted) {
      return;
    }

    setState(() {
      if (_brokerState != BrokerState.error) {
        _brokerState = BrokerState.disconnected;
        _statusMessage = 'Disconnected from broker';
      }
    });
  }

  void _handleMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    final received = messages.first.payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(
      received.payload.message,
    );

    setState(() {
      _lastPayload = '${messages.first.topic}: $payload';
      _statusMessage = 'Status updated';
    });
  }

  void _publishDoorAction(String action) {
    final client = _client;
    if (client == null || !_isConnected) {
      _setError('Connect to the broker before sending $action.');
      return;
    }

    final payload = MqttClientPayloadBuilder()..addString(action);
    client.publishMessage(commandTopic, MqttQos.atLeastOnce, payload.payload!);

    setState(() {
      _lastCommand = action;
      _statusMessage = 'Sent "$action" to $commandTopic';
    });
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = message;
    });
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _brokerState = BrokerState.error;
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Bowl Door')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectionPanel(
              isBusy: _isBusy,
              isConnected: _isConnected,
              onConnect: _connect,
              onDisconnect: _disconnect,
            ),
            const SizedBox(height: 16),
            _DoorControls(
              isConnected: _isConnected,
              onOpen: () => _publishDoorAction('open'),
              onClose: () => _publishDoorAction('close'),
            ),
            const SizedBox(height: 16),
            _StatusPanel(
              brokerState: _brokerState,
              statusMessage: _statusMessage,
              lastPayload: _lastPayload,
              lastCommand: _lastCommand,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.isBusy,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final bool isBusy;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mosquitto Broker',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const _BrokerDetail(label: 'Endpoint', value: brokerUri),
            const SizedBox(height: 8),
            const _BrokerDetail(label: 'Command topic', value: commandTopic),
            const SizedBox(height: 8),
            const _BrokerDetail(label: 'Status topic', value: statusTopic),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  isBusy
                      ? null
                      : isConnected
                      ? onDisconnect
                      : onConnect,
              icon:
                  isBusy
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(isConnected ? Icons.link_off : Icons.link),
              label: Text(
                isBusy
                    ? 'Connecting'
                    : isConnected
                    ? 'Disconnect'
                    : 'Reconnect',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrokerDetail extends StatelessWidget {
  const _BrokerDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 112, child: Text(label, style: textTheme.labelLarge)),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
      ],
    );
  }
}

class _DoorControls extends StatelessWidget {
  const _DoorControls({
    required this.isConnected,
    required this.onOpen,
    required this.onClose,
  });

  final bool isConnected;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Door Control', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConnected ? onOpen : null,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: isConnected ? onClose : null,
                    icon: const Icon(Icons.lock),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.brokerState,
    required this.statusMessage,
    required this.lastPayload,
    required this.lastCommand,
  });

  final BrokerState brokerState;
  final String statusMessage;
  final String lastPayload;
  final String lastCommand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stateColor = switch (brokerState) {
      BrokerState.connected => colorScheme.primary,
      BrokerState.connecting => colorScheme.tertiary,
      BrokerState.error => colorScheme.error,
      BrokerState.disconnected => colorScheme.outline,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 14, color: stateColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text('Last command: $lastCommand'),
            const SizedBox(height: 8),
            Text('Last broker status: $lastPayload'),
          ],
        ),
      ),
    );
  }
}
