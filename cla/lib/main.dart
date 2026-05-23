import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── MQTT configuration ──────────────────────────────────────────────────────
const String mqttHost = '192.168.0.49';
const int mqttPort = 9001; // WebSocket port
const String topicPrefix = 'home/foodbowl';
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

class Bowl {
  final String id;
  String name;
  LidState lidState;

  Bowl({required this.id, required this.name, this.lidState = LidState.unknown});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Bowl.fromJson(Map<String, dynamic> json) =>
      Bowl(id: json['id'] as String, name: json['name'] as String);
}

class FoodBowlHome extends StatefulWidget {
  const FoodBowlHome({super.key});

  @override
  State<FoodBowlHome> createState() => _FoodBowlHomeState();
}

class _FoodBowlHomeState extends State<FoodBowlHome> {
  late MqttBrowserClient _client;
  bool _connected = false;
  String _statusMessage = 'Connecting…';
  final List<Bowl> _bowls = [];

  @override
  void initState() {
    super.initState();
    _loadBowls();
    _connect();
  }

  Future<void> _loadBowls() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('bowls');
    if (data != null) {
      final list = jsonDecode(data) as List;
      if (mounted) {
        setState(() {
          _bowls.addAll(list.map((e) => Bowl.fromJson(e as Map<String, dynamic>)));
        });
      }
    }
  }

  Future<void> _saveBowls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bowls', jsonEncode(_bowls.map((b) => b.toJson()).toList()));
  }

  Future<void> _connect() async {
    _client = MqttBrowserClient('ws://$mqttHost', 'flutter_food_bowl');
    _client.port = mqttPort;
    _client.keepAlivePeriod = 30;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.logging(on: false);

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
      if (mounted) setState(() => _statusMessage = 'Failed: $e — retrying…');
      _client.disconnect();
      Future.delayed(const Duration(seconds: 5), _connect);
      return;
    }

    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      final code = _client.connectionStatus?.returnCode;
      if (mounted) setState(() => _statusMessage = 'Refused ($code) — retrying…');
      _client.disconnect();
      Future.delayed(const Duration(seconds: 5), _connect);
    }
  }

  void _onConnected() {
    _client.subscribe('$topicPrefix/+/status', MqttQos.atLeastOnce);
    _client.updates?.listen(_onMessage);
    if (mounted) {
      setState(() {
        _connected = true;
        _statusMessage = 'Connected';
      });
    }
  }

  void _onDisconnected() {
    if (mounted) {
      setState(() {
        _connected = false;
        _statusMessage = 'Disconnected — retrying in 5 s…';
        for (final bowl in _bowls) {
          bowl.lidState = LidState.unknown;
        }
      });
    }
    Future.delayed(const Duration(seconds: 5), _connect);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>> messages) {
    final rec = messages.first;
    final parts = rec.topic.split('/');
    if (parts.length < 4) return;
    final bowlId = parts[2];

    final message = rec.payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);

    final idx = _bowls.indexWhere((b) => b.id == bowlId);
    if (idx == -1) return;

    setState(() {
      if (payload == 'open') {
        _bowls[idx].lidState = LidState.open;
      } else if (payload == 'closed') {
        _bowls[idx].lidState = LidState.closed;
      }
    });
  }

  void _publish(String bowlId, String command) {
    if (!_connected) return;
    final builder = MqttClientPayloadBuilder()..addString(command);
    _client.publishMessage(
      '$topicPrefix/$bowlId/command',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void _addBowl(String id, String name) {
    if (_bowls.any((b) => b.id == id)) return;
    setState(() => _bowls.add(Bowl(id: id, name: name)));
    _saveBowls();
  }

  void _removeBowl(String id) {
    setState(() => _bowls.removeWhere((b) => b.id == id));
    _saveBowls();
  }

  void _showAddBowlDialog() {
    final nameController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bowl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Kitchen Bowl',
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'Bowl ID',
                hintText: 'e.g. a4cf123456ab',
              ),
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final id = idController.text.trim();
              if (name.isNotEmpty && id.isNotEmpty) {
                _addBowl(id, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
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
        title: const Text('Pet Food Bowls'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              _connected ? Icons.wifi : Icons.wifi_off,
              color: _connected ? Colors.white : Colors.white54,
            ),
          ),
        ],
      ),
      body: _bowls.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: scheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text('No bowls added yet',
                      style: TextStyle(color: scheme.outline, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _connected ? scheme.primary : scheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _connected ? scheme.primary : scheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bowls.length,
                    itemBuilder: (context, i) => _BowlCard(
                      bowl: _bowls[i],
                      enabled: _connected,
                      onOpen: () => _publish(_bowls[i].id, 'open'),
                      onClose: () => _publish(_bowls[i].id, 'close'),
                      onRemove: () => _removeBowl(_bowls[i].id),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBowlDialog,
        tooltip: 'Add bowl',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BowlCard extends StatelessWidget {
  const _BowlCard({
    required this.bowl,
    required this.enabled,
    required this.onOpen,
    required this.onClose,
    required this.onRemove,
  });

  final Bowl bowl;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (bowl.lidState) {
      LidState.open => (Icons.lock_open_rounded, Colors.green, 'Open'),
      LidState.closed => (Icons.lock_rounded, Colors.red, 'Closed'),
      LidState.unknown => (Icons.help_outline_rounded, Colors.grey, 'Unknown'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bowl.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(label,
                          style: TextStyle(color: color, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.grey,
                  onPressed: onRemove,
                  tooltip: 'Remove bowl',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled && bowl.lidState != LidState.open
                        ? onOpen
                        : null,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Open'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled && bowl.lidState != LidState.closed
                        ? onClose
                        : null,
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('Close'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
