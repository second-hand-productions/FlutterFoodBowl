import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

// ── MQTT configuration ──────────────────────────────────────────────────────
const String mqttHost = '192.168.0.49';
const int mqttPort = 9001; // WebSocket port
const String commandTopic = 'home/foodbowl/command';
const String statusTopic = 'home/foodbowl/status';
// ────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const FoodBowlApp());
}

class FoodBowlApp extends StatelessWidget {
  const FoodBowlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Bowl',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const FoodBowlHome(),
    );
  }
}

enum LidState { unknown, open, closed }

class FoodBowlHome extends StatefulWidget {
  const FoodBowlHome({super.key});

  @override
  State<FoodBowlHome> createState() => _FoodBowlHomeState();
}

class _FoodBowlHomeState extends State<FoodBowlHome> {
  late MqttBrowserClient _client;
  bool _connected = false;
  LidState _lidState = LidState.unknown;
  String _statusMessage = 'Connecting…';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    _client = MqttBrowserClient('ws://$mqttHost', 'flutter_food_bowl');
    _client.port = mqttPort;
    _client.keepAlivePeriod = 30;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.logging(on: true);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_food_bowl')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client.connectionMessage = connMessage;

    try {
      await _client.connect().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timed out'),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Failed: $e — retrying…');
      }
      _client.disconnect();
      Future.delayed(const Duration(seconds: 5), _connect);
      return;
    }

    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      final code = _client.connectionStatus?.returnCode;
      if (mounted) {
        setState(() => _statusMessage = 'Refused ($code) — retrying…');
      }
      _client.disconnect();
      Future.delayed(const Duration(seconds: 5), _connect);
    }
  }

  void _onConnected() {
    _client.subscribe(statusTopic, MqttQos.atLeastOnce);
    _client.updates?.listen(_onMessage);
    if (mounted) {
      setState(() {
        _connected = true;
        _statusMessage = 'Connected';
      });
    }
  }

  void _onDisconnected() {
    setState(() {
      _connected = false;
      _lidState = LidState.unknown;
      _statusMessage = 'Disconnected — retrying in 5 s…';
    });
    Future.delayed(const Duration(seconds: 5), _connect);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>> messages) {
    final message = messages.first.payload as MqttPublishMessage;
    final payload =
        MqttPublishPayload.bytesToStringAsString(message.payload.message);
    setState(() {
      if (payload == 'open') {
        _lidState = LidState.open;
        _statusMessage = 'Lid is open';
      } else if (payload == 'closed') {
        _lidState = LidState.closed;
        _statusMessage = 'Lid is closed';
      }
    });
  }

  void _publish(String command) {
    if (!_connected) return;
    final builder = MqttClientPayloadBuilder()..addString(command);
    _client.publishMessage(
      commandTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: const Text('Pet Food Bowl'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LidStatusIndicator(state: _lidState),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _connected ? scheme.primary : scheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BowlButton(
                  label: 'Open',
                  icon: Icons.lock_open_rounded,
                  color: Colors.green,
                  enabled: _connected && _lidState != LidState.open,
                  onPressed: () => _publish('open'),
                ),
                const SizedBox(width: 24),
                _BowlButton(
                  label: 'Close',
                  icon: Icons.lock_rounded,
                  color: Colors.red,
                  enabled: _connected && _lidState != LidState.closed,
                  onPressed: () => _publish('close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LidStatusIndicator extends StatelessWidget {
  const _LidStatusIndicator({required this.state});
  final LidState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (state) {
      LidState.open => (Icons.lock_open_rounded, Colors.green, 'Open'),
      LidState.closed => (Icons.lock_rounded, Colors.red, 'Closed'),
      LidState.unknown => (Icons.help_outline_rounded, Colors.grey, 'Unknown'),
    };

    return Column(
      children: [
        Icon(icon, size: 96, color: color),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BowlButton extends StatelessWidget {
  const _BowlButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
