import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:pocketbase/pocketbase.dart';

import 'mqtt_client_factory.dart';

const String brokerUri = 'ws://192.168.0.49:9001';
const String pocketBaseUri = 'http://pocketbase.lan';
const String bowlsCollection = 'bowls';
const String discoveryTopicFilter = 'foodbowl/discovery/+';

String commandTopicFor(String bowlId) => 'foodbowl/$bowlId/door/set';
String statusTopicFor(String bowlId) => 'foodbowl/$bowlId/door/status';
String resultTopicFor(String bowlId) => 'foodbowl/$bowlId/door/result';
String availabilityTopicFor(String bowlId) =>
    'foodbowl/$bowlId/door/availability';

void main() {
  runApp(const FoodBowlApp());
}

class FoodBowlApp extends StatelessWidget {
  const FoodBowlApp({
    super.key,
    this.autoConnect = true,
    this.usePocketBase = true,
  });

  final bool autoConnect;
  final bool usePocketBase;

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
      home: FoodBowlHomePage(
        autoConnect: autoConnect,
        usePocketBase: usePocketBase,
      ),
    );
  }
}

enum BrokerState { disconnected, connecting, connected, error }

class FoodBowlConfig {
  const FoodBowlConfig({this.recordId, required this.id, required this.name});

  factory FoodBowlConfig.fromRecord(RecordModel record) {
    final bowlId = record.data['bowl_id'];
    final name = record.data['name'];
    final id = bowlId is String ? bowlId.trim() : '';

    return FoodBowlConfig(
      recordId: record.id,
      id: id,
      name: name is String && name.trim().isNotEmpty ? name.trim() : id,
    );
  }

  final String? recordId;
  final String id;
  final String name;

  FoodBowlConfig copyWith({String? recordId, String? id, String? name}) {
    return FoodBowlConfig(
      recordId: recordId ?? this.recordId,
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

class BowlRuntimeState {
  const BowlRuntimeState({
    this.status = 'No status received yet',
    this.availability = 'unknown',
    this.lastCommand = 'None',
    this.lastResult = 'No result received yet',
  });

  final String status;
  final String availability;
  final String lastCommand;
  final String lastResult;

  BowlRuntimeState copyWith({
    String? status,
    String? availability,
    String? lastCommand,
    String? lastResult,
  }) {
    return BowlRuntimeState(
      status: status ?? this.status,
      availability: availability ?? this.availability,
      lastCommand: lastCommand ?? this.lastCommand,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class BowlDiscovery {
  const BowlDiscovery({required this.bowlId, this.macAddress, this.ipAddress});

  final String bowlId;
  final String? macAddress;
  final String? ipAddress;
}

class FoodBowlHomePage extends StatefulWidget {
  const FoodBowlHomePage({
    super.key,
    this.autoConnect = true,
    this.usePocketBase = true,
  });

  final bool autoConnect;
  final bool usePocketBase;

  @override
  State<FoodBowlHomePage> createState() => _FoodBowlHomePageState();
}

class _FoodBowlHomePageState extends State<FoodBowlHomePage> {
  final List<FoodBowlConfig> _foodBowls = [];
  final Map<String, BowlRuntimeState> _bowlStates = {};
  final Set<String> _pendingDiscoveryBowlIds = {};
  late final PocketBase _pb = PocketBase(pocketBaseUri);

  MqttClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;
  BrokerState _brokerState = BrokerState.disconnected;
  bool _isLoadingBowls = false;
  String _statusMessage = 'Loading bowls';

  bool get _isConnected => _brokerState == BrokerState.connected;
  bool get _isBusy => _brokerState == BrokerState.connecting;

  @override
  void initState() {
    super.initState();
    if (widget.usePocketBase) {
      unawaited(_loadBowls());
    } else {
      _statusMessage = 'Add a bowl to begin';
    }
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
    client.subscribe(discoveryTopicFilter, MqttQos.atLeastOnce);
    for (final bowl in _foodBowls) {
      _subscribeToBowl(client, bowl);
    }

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

    final topic = messages.first.topic;
    if (_isDiscoveryTopic(topic)) {
      unawaited(_handleDiscovery(topic, payload));
      return;
    }

    final parts = topic.split('/');
    if (parts.length != 4 || parts.first != 'foodbowl' || parts[2] != 'door') {
      setState(() {
        _statusMessage = 'Received $topic: $payload';
      });
      return;
    }

    final bowlId = parts[1];
    final bowl = _bowlForId(bowlId);
    if (bowl == null) {
      setState(() {
        _statusMessage = 'Ignored unconfigured bowl $bowlId';
      });
      return;
    }

    final stream = parts[3];
    final currentState = _bowlStates[bowlId] ?? const BowlRuntimeState();

    setState(() {
      _bowlStates[bowlId] = switch (stream) {
        'status' => currentState.copyWith(status: payload),
        'result' => currentState.copyWith(lastResult: payload),
        'availability' => currentState.copyWith(availability: payload),
        _ => currentState,
      };
      _statusMessage = 'Updated ${bowl.name} $stream';
    });
  }

  void _publishDoorAction(String bowlId, String action) {
    final client = _client;
    if (client == null || !_isConnected) {
      _setError('Connect to the broker before sending $action.');
      return;
    }

    final bowl = _bowlForId(bowlId);
    if (bowl == null) {
      _setError('Add the bowl before sending $action.');
      return;
    }

    final payload = MqttClientPayloadBuilder()..addString(action);
    final topic = commandTopicFor(bowlId);
    client.publishMessage(topic, MqttQos.atLeastOnce, payload.payload!);

    setState(() {
      final currentState = _bowlStates[bowlId] ?? const BowlRuntimeState();
      _bowlStates[bowlId] = currentState.copyWith(lastCommand: action);
      _statusMessage = 'Sent "$action" to ${bowl.name}';
    });
  }

  void _subscribeToBowl(MqttClient client, FoodBowlConfig bowl) {
    client.subscribe(statusTopicFor(bowl.id), MqttQos.atLeastOnce);
    client.subscribe(resultTopicFor(bowl.id), MqttQos.atLeastOnce);
    client.subscribe(availabilityTopicFor(bowl.id), MqttQos.atLeastOnce);
  }

  void _unsubscribeFromBowl(MqttClient client, FoodBowlConfig bowl) {
    client.unsubscribe(statusTopicFor(bowl.id));
    client.unsubscribe(resultTopicFor(bowl.id));
    client.unsubscribe(availabilityTopicFor(bowl.id));
  }

  bool _isDiscoveryTopic(String topic) {
    final parts = topic.split('/');
    return parts.length == 3 &&
        parts[0] == 'foodbowl' &&
        parts[1] == 'discovery';
  }

  BowlDiscovery? _parseDiscovery(String topic, String payload) {
    final topicParts = topic.split('/');
    final topicBowlId = topicParts.length == 3 ? topicParts[2].trim() : '';

    String? payloadBowlId;
    String? macAddress;
    String? ipAddress;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final rawBowlId = decoded['bowl_id'];
        final rawMacAddress = decoded['mac_address'];
        final rawIpAddress = decoded['ip_address'];
        if (rawBowlId is String) {
          payloadBowlId = rawBowlId.trim();
        }
        if (rawMacAddress is String && rawMacAddress.trim().isNotEmpty) {
          macAddress = rawMacAddress.trim();
        }
        if (rawIpAddress is String && rawIpAddress.trim().isNotEmpty) {
          ipAddress = rawIpAddress.trim();
        }
      }
    } on FormatException {
      // The topic id is enough for discovery; older firmware may send plain text.
    }

    final bowlId =
        payloadBowlId != null && payloadBowlId == topicBowlId
            ? payloadBowlId
            : topicBowlId;
    if (!_isValidBowlId(bowlId)) {
      return null;
    }

    return BowlDiscovery(
      bowlId: bowlId,
      macAddress: macAddress,
      ipAddress: ipAddress,
    );
  }

  Future<void> _handleDiscovery(String topic, String payload) async {
    final discovery = _parseDiscovery(topic, payload);
    if (discovery == null) {
      _setStatus('Ignored invalid bowl discovery');
      return;
    }

    if (_bowlForId(discovery.bowlId) != null ||
        !_pendingDiscoveryBowlIds.add(discovery.bowlId)) {
      _setStatus('Discovered known bowl ${discovery.bowlId}');
      return;
    }

    try {
      while (mounted && _isLoadingBowls) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted || _bowlForId(discovery.bowlId) != null) {
        return;
      }

      final bowl = FoodBowlConfig(
        id: discovery.bowlId,
        name: _defaultDiscoveredBowlName(discovery),
      );
      FoodBowlConfig savedBowl = bowl;

      if (widget.usePocketBase) {
        setState(() {
          _statusMessage = 'Registering ${discovery.bowlId} in PocketBase';
        });

        try {
          final existingRecord = await _findBowlRecord(bowl.id);
          if (existingRecord != null) {
            savedBowl = FoodBowlConfig.fromRecord(existingRecord);
          } else {
            final body = <String, dynamic>{
              'bowl_id': bowl.id,
              'name': bowl.name,
            };
            final record = await _pb
                .collection(bowlsCollection)
                .create(body: body, files: []);
            savedBowl = bowl.copyWith(recordId: record.id);
          }
        } on ClientException catch (error) {
          _setError('PocketBase discovery create failed: ${error.response}');
          return;
        }
      }

      final client = _client;
      setState(() {
        _foodBowls.add(savedBowl);
        _bowlStates[savedBowl.id] = const BowlRuntimeState();
        _statusMessage = 'Registered ${savedBowl.name}';
      });

      if (client != null && _isConnected) {
        _subscribeToBowl(client, savedBowl);
        _publishDoorAction(savedBowl.id, 'status');
      }
    } on Exception catch (error) {
      _setError('Bowl discovery failed: $error');
    } finally {
      _pendingDiscoveryBowlIds.remove(discovery.bowlId);
    }
  }

  String _defaultDiscoveredBowlName(BowlDiscovery discovery) {
    final suffix =
        discovery.bowlId.length <= 6
            ? discovery.bowlId
            : discovery.bowlId.substring(discovery.bowlId.length - 6);
    return 'Food Bowl $suffix';
  }

  Future<RecordModel?> _findBowlRecord(String bowlId) async {
    final result = await _pb
        .collection(bowlsCollection)
        .getList(page: 1, perPage: 1, filter: 'bowl_id = "$bowlId"');
    return result.items.isEmpty ? null : result.items.first;
  }

  Future<void> _loadBowls() async {
    setState(() {
      _isLoadingBowls = true;
      _statusMessage = 'Loading bowls from PocketBase';
    });

    try {
      final records = await _pb
          .collection(bowlsCollection)
          .getFullList(sort: 'name');
      final bowls =
          records
              .map(FoodBowlConfig.fromRecord)
              .where((bowl) => _isValidBowlId(bowl.id))
              .toList();

      _replaceBowls(bowls);
      _setStatus(
        bowls.isEmpty
            ? 'No bowls configured in PocketBase'
            : 'Loaded ${bowls.length} bowls from PocketBase',
      );
    } on ClientException catch (error) {
      _setError('PocketBase load failed: ${error.response}');
    } on Exception catch (error) {
      _setError('PocketBase load failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBowls = false;
        });
      }
    }
  }

  void _replaceBowls(List<FoodBowlConfig> bowls) {
    final client = _client;
    final previousBowls = List<FoodBowlConfig>.of(_foodBowls);
    final nextIds = bowls.map((bowl) => bowl.id).toSet();

    if (client != null && _isConnected) {
      for (final previousBowl in previousBowls) {
        if (!nextIds.contains(previousBowl.id)) {
          _unsubscribeFromBowl(client, previousBowl);
        }
      }
      for (final bowl in bowls) {
        if (_bowlForId(bowl.id) == null) {
          _subscribeToBowl(client, bowl);
        }
      }
    }

    setState(() {
      _foodBowls
        ..clear()
        ..addAll(bowls);

      _bowlStates.removeWhere((bowlId, _) => !nextIds.contains(bowlId));
      for (final bowl in bowls) {
        _bowlStates.putIfAbsent(bowl.id, () => const BowlRuntimeState());
      }
    });
  }

  Future<void> _addBowl() async {
    final bowl = await showDialog<FoodBowlConfig>(
      context: context,
      builder: (context) {
        return _AddBowlDialog(
          existingIds: _foodBowls.map((bowl) => bowl.id).toSet(),
        );
      },
    );

    if (bowl == null) {
      return;
    }

    FoodBowlConfig savedBowl = bowl;
    if (widget.usePocketBase) {
      setState(() {
        _statusMessage = 'Saving ${bowl.name} to PocketBase';
      });

      try {
        final body = <String, dynamic>{'bowl_id': bowl.id, 'name': bowl.name};
        final record = await _pb
            .collection(bowlsCollection)
            .create(body: body, files: []);
        savedBowl = bowl.copyWith(recordId: record.id);
      } on ClientException catch (error) {
        _setError('PocketBase create failed: ${error.response}');
        return;
      } on Exception catch (error) {
        _setError('PocketBase create failed: $error');
        return;
      }
    }

    final client = _client;
    setState(() {
      _foodBowls.add(savedBowl);
      _bowlStates[savedBowl.id] = const BowlRuntimeState();
      _statusMessage = 'Added ${savedBowl.name}';
    });

    if (client != null && _isConnected) {
      _subscribeToBowl(client, savedBowl);
      _publishDoorAction(savedBowl.id, 'status');
    }
  }

  Future<void> _removeBowl(FoodBowlConfig bowl) async {
    if (widget.usePocketBase && bowl.recordId != null) {
      setState(() {
        _statusMessage = 'Removing ${bowl.name} from PocketBase';
      });

      try {
        await _pb.collection(bowlsCollection).delete(bowl.recordId!);
      } on ClientException catch (error) {
        _setError('PocketBase delete failed: ${error.response}');
        return;
      } on Exception catch (error) {
        _setError('PocketBase delete failed: $error');
        return;
      }
    }

    final client = _client;
    if (client != null && _isConnected) {
      _unsubscribeFromBowl(client, bowl);
    }

    setState(() {
      _foodBowls.removeWhere((configuredBowl) => configuredBowl.id == bowl.id);
      _bowlStates.remove(bowl.id);
      _statusMessage = 'Removed ${bowl.name}';
    });
  }

  Future<void> _renameBowl(FoodBowlConfig bowl) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameBowlDialog(bowl: bowl),
    );

    if (newName == null || newName == bowl.name) {
      return;
    }

    FoodBowlConfig updatedBowl = bowl.copyWith(name: newName);
    if (widget.usePocketBase) {
      setState(() {
        _statusMessage = 'Renaming ${bowl.name}';
      });

      try {
        final recordId = bowl.recordId ?? (await _findBowlRecord(bowl.id))?.id;
        if (recordId == null) {
          _setError('PocketBase record not found for ${bowl.id}.');
          return;
        }

        final record = await _pb
            .collection(bowlsCollection)
            .update(recordId, body: {'name': newName});
        updatedBowl = FoodBowlConfig.fromRecord(record);
      } on ClientException catch (error) {
        _setError('PocketBase rename failed: ${error.response}');
        return;
      } on Exception catch (error) {
        _setError('PocketBase rename failed: $error');
        return;
      }
    }

    setState(() {
      final index = _foodBowls.indexWhere(
        (configuredBowl) => configuredBowl.id == bowl.id,
      );
      if (index != -1) {
        _foodBowls[index] = updatedBowl;
      }
      _statusMessage = 'Renamed ${updatedBowl.name}';
    });
  }

  FoodBowlConfig? _bowlForId(String bowlId) {
    for (final bowl in _foodBowls) {
      if (bowl.id == bowlId) {
        return bowl;
      }
    }
    return null;
  }

  bool _isValidBowlId(String id) {
    return id.length <= 32 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
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
      appBar: AppBar(
        title: const Text('Food Bowl Door'),
        actions: [
          IconButton(
            tooltip: 'Add bowl',
            onPressed: _addBowl,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBowl,
        icon: const Icon(Icons.add),
        label: const Text('Add bowl'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectionPanel(
              bowlCount: _foodBowls.length,
              isLoadingBowls: _isLoadingBowls,
              isBusy: _isBusy,
              isConnected: _isConnected,
              onRefreshBowls: widget.usePocketBase ? _loadBowls : null,
              onConnect: _connect,
              onDisconnect: _disconnect,
            ),
            const SizedBox(height: 16),
            if (_foodBowls.isEmpty)
              _EmptyBowlsPanel(onAddBowl: _addBowl)
            else
              for (final bowl in _foodBowls) ...[
                _DoorControls(
                  bowl: bowl,
                  state: _bowlStates[bowl.id] ?? const BowlRuntimeState(),
                  isConnected: _isConnected,
                  onOpen: () => _publishDoorAction(bowl.id, 'open'),
                  onClose: () => _publishDoorAction(bowl.id, 'close'),
                  onStatus: () => _publishDoorAction(bowl.id, 'status'),
                  onRename: () => unawaited(_renameBowl(bowl)),
                  onRemove: () => unawaited(_removeBowl(bowl)),
                ),
                const SizedBox(height: 16),
              ],
            _StatusPanel(
              brokerState: _brokerState,
              statusMessage: _statusMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBowlDialog extends StatefulWidget {
  const _AddBowlDialog({required this.existingIds});

  final Set<String> existingIds;

  @override
  State<_AddBowlDialog> createState() => _AddBowlDialogState();
}

class _AddBowlDialogState extends State<_AddBowlDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final id = _idController.text.trim();
    final nameText = _nameController.text.trim();
    Navigator.of(
      context,
    ).pop(FoodBowlConfig(id: id, name: nameText.isEmpty ? id : nameText));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add bowl'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Bowl ID',
                hintText: 'bowl-aabbccddeeff',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final id = value?.trim() ?? '';
                if (id.isEmpty) {
                  return 'Enter the firmware BOWL_ID';
                }
                if (id.length > 32) {
                  return 'Use 32 characters or fewer';
                }
                if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
                  return 'Use only letters, numbers, _, or -';
                }
                if (widget.existingIds.contains(id)) {
                  return 'That bowl is already added';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'Kitchen bowl',
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _RenameBowlDialog extends StatefulWidget {
  const _RenameBowlDialog({required this.bowl});

  final FoodBowlConfig bowl;

  @override
  State<_RenameBowlDialog> createState() => _RenameBowlDialogState();
}

class _RenameBowlDialogState extends State<_RenameBowlDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bowl.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename bowl'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Enter a display name';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.bowlCount,
    required this.isLoadingBowls,
    required this.isBusy,
    required this.isConnected,
    required this.onRefreshBowls,
    required this.onConnect,
    required this.onDisconnect,
  });

  final int bowlCount;
  final bool isLoadingBowls;
  final bool isBusy;
  final bool isConnected;
  final VoidCallback? onRefreshBowls;
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
            const _BrokerDetail(label: 'PocketBase', value: pocketBaseUri),
            const SizedBox(height: 8),
            const _BrokerDetail(
              label: 'Topic pattern',
              value: 'foodbowl/<bowl-id>/door/#',
            ),
            const SizedBox(height: 8),
            const _BrokerDetail(
              label: 'Discovery',
              value: discoveryTopicFilter,
            ),
            const SizedBox(height: 8),
            _BrokerDetail(label: 'Configured', value: '$bowlCount bowls'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  onRefreshBowls == null || isLoadingBowls
                      ? null
                      : onRefreshBowls,
              icon:
                  isLoadingBowls
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.sync),
              label: Text(isLoadingBowls ? 'Loading bowls' : 'Refresh bowls'),
            ),
            const SizedBox(height: 8),
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

class _EmptyBowlsPanel extends StatelessWidget {
  const _EmptyBowlsPanel({required this.onAddBowl});

  final VoidCallback onAddBowl;

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
              'No bowls added',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('Power on a bowl to register it automatically.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddBowl,
              icon: const Icon(Icons.add),
              label: const Text('Add bowl'),
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
    required this.bowl,
    required this.state,
    required this.isConnected,
    required this.onOpen,
    required this.onClose,
    required this.onStatus,
    required this.onRename,
    required this.onRemove,
  });

  final FoodBowlConfig bowl;
  final BowlRuntimeState state;
  final bool isConnected;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onStatus;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bowl.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _AvailabilityChip(availability: state.availability),
                IconButton(
                  tooltip: 'Rename bowl',
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Remove bowl',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _BrokerDetail(label: 'Bowl ID', value: bowl.id),
            const SizedBox(height: 8),
            _BrokerDetail(label: 'Command', value: commandTopicFor(bowl.id)),
            const SizedBox(height: 8),
            _BrokerDetail(label: 'Status', value: state.status),
            const SizedBox(height: 8),
            _BrokerDetail(label: 'Last command', value: state.lastCommand),
            const SizedBox(height: 8),
            _BrokerDetail(label: 'Last result', value: state.lastResult),
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
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Refresh status',
                  onPressed: isConnected ? onStatus : null,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.availability});

  final String availability;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOnline = availability == 'online';

    return Chip(
      avatar: Icon(
        Icons.circle,
        size: 12,
        color: isOnline ? colorScheme.primary : colorScheme.outline,
      ),
      label: Text(availability),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.brokerState, required this.statusMessage});

  final BrokerState brokerState;
  final String statusMessage;

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
        child: Row(
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
      ),
    );
  }
}
