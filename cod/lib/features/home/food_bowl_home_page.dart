import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cod/config/food_bowl_settings.dart';
import 'package:cod/features/bowl_detail/bowl_detail_page.dart';
import 'package:cod/features/home/widgets/bowl_dialogs.dart';
import 'package:cod/features/home/widgets/home_panels.dart';
import 'package:cod/models/bowl_models.dart';
import 'package:cod/services/bowls/bowl_repository.dart';
import 'package:cod/services/cameras/camera_feed_repository.dart';
import 'package:cod/services/mqtt/mqtt_client_factory.dart';
import 'package:cod/services/mqtt/mqtt_topics.dart';

class FoodBowlHomePage extends StatefulWidget {
  const FoodBowlHomePage({
    super.key,
    this.autoConnect = true,
    this.usePocketBase = true,
    this.bowlRepository,
    this.cameraFeedRepository,
    this.mqttClientFactory,
  });

  final bool autoConnect;
  final bool usePocketBase;
  final BowlRepository? bowlRepository;
  final CameraFeedRepository? cameraFeedRepository;
  final MqttClientFactory? mqttClientFactory;

  @override
  State<FoodBowlHomePage> createState() => _FoodBowlHomePageState();
}

class _FoodBowlHomePageState extends State<FoodBowlHomePage> {
  final List<FoodBowlConfig> _foodBowls = [];
  final Map<String, BowlRuntimeState> _bowlStates = {};
  final Set<String> _pendingDiscoveryBowlIds = {};
  late final BowlRepository _bowlRepository =
      widget.bowlRepository ?? PocketBaseBowlRepository();
  late final CameraFeedRepository? _cameraFeedRepository =
      widget.cameraFeedRepository ??
      (widget.usePocketBase ? PocketBaseCameraFeedRepository() : null);
  late final MqttClientFactory _mqttClientFactory =
      widget.mqttClientFactory ?? createMqttClient;

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
    final client = _mqttClientFactory(brokerUri, clientId);
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
      await client.connect().timeout(const Duration(seconds: 10));
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
    if (isDiscoveryTopic(topic)) {
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
    if (!isValidBowlId(bowlId)) {
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
          final existingBowl = await _bowlRepository.findBowl(bowl.id);
          savedBowl = existingBowl ?? await _bowlRepository.createBowl(bowl);
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

  Future<void> _loadBowls() async {
    setState(() {
      _isLoadingBowls = true;
      _statusMessage = 'Loading bowls from PocketBase';
    });

    try {
      final bowls =
          (await _bowlRepository.loadBowls())
              .where((bowl) => isValidBowlId(bowl.id))
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
        return AddBowlDialog(
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
        savedBowl = await _bowlRepository.createBowl(bowl);
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
        await _bowlRepository.deleteBowl(bowl);
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
      builder: (context) => RenameBowlDialog(bowl: bowl),
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
        final renamedBowl = await _bowlRepository.renameBowl(bowl, newName);
        if (renamedBowl == null) {
          _setError('PocketBase record not found for ${bowl.id}.');
          return;
        }

        updatedBowl = renamedBowl;
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

  Future<void> _openBowlDetail(FoodBowlConfig bowl) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return BowlDetailPage(
            bowl: bowl,
            state: _bowlStates[bowl.id] ?? const BowlRuntimeState(),
            isConnected: _isConnected,
            cameraFeedRepository: _cameraFeedRepository,
            onOpen: () => _publishDoorAction(bowl.id, 'open'),
            onClose: () => _publishDoorAction(bowl.id, 'close'),
            onStatus: () => _publishDoorAction(bowl.id, 'status'),
          );
        },
      ),
    );
  }

  FoodBowlConfig? _bowlForId(String bowlId) {
    for (final bowl in _foodBowls) {
      if (bowl.id == bowlId) {
        return bowl;
      }
    }
    return null;
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
            ConnectionPanel(
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
              EmptyBowlsPanel(onAddBowl: _addBowl)
            else
              for (final bowl in _foodBowls) ...[
                DoorControls(
                  bowl: bowl,
                  state: _bowlStates[bowl.id] ?? const BowlRuntimeState(),
                  isConnected: _isConnected,
                  onOpen: () => _publishDoorAction(bowl.id, 'open'),
                  onClose: () => _publishDoorAction(bowl.id, 'close'),
                  onStatus: () => _publishDoorAction(bowl.id, 'status'),
                  onViewCamera: () => unawaited(_openBowlDetail(bowl)),
                  onRename: () => unawaited(_renameBowl(bowl)),
                  onRemove: () => unawaited(_removeBowl(bowl)),
                ),
                const SizedBox(height: 16),
              ],
            StatusPanel(
              brokerState: _brokerState,
              statusMessage: _statusMessage,
            ),
          ],
        ),
      ),
    );
  }
}
