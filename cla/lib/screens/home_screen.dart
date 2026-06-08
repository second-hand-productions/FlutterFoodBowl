import 'package:flutter/material.dart';
import '../models/bowl.dart';
import '../services/mqtt_service.dart';
import '../services/bowl_service.dart';
import '../widgets/bowl_card.dart';
import 'camera_screen.dart';

class FoodBowlHome extends StatefulWidget {
  const FoodBowlHome({
    super.key,
    required this.bowlService,
    required this.mqttService,
    required this.camBase,
  });

  final BowlService bowlService;
  final MqttService mqttService;
  final String camBase;

  @override
  State<FoodBowlHome> createState() => _FoodBowlHomeState();
}

class _FoodBowlHomeState extends State<FoodBowlHome> {
  late final MqttService _mqtt = widget.mqttService;
  late final BowlService _bowlService = widget.bowlService;

  bool _connected = false;
  String _statusMessage = 'Connecting…';
  final List<Bowl> _bowls = [];

  @override
  void initState() {
    super.initState();
    _mqtt.onStatusChanged = (connected, message) {
      if (!mounted) return;
      setState(() {
        _connected = connected;
        _statusMessage = message;
        if (!connected) {
          for (final bowl in _bowls) {
            bowl.lidState = LidState.unknown;
          }
        }
      });
    };
    _mqtt.onLidStateChanged = (bowlId, state) {
      if (!mounted) return;
      setState(() {
        final idx = _bowls.indexWhere((b) => b.id == bowlId);
        if (idx != -1) _bowls[idx].lidState = state;
      });
    };
    _mqtt.onAnnounce = _handleAnnounce;
    _loadBowls();
    _mqtt.connect();
  }

  Future<void> _loadBowls() async {
    try {
      final bowls = await _bowlService.loadBowls();
      if (mounted) setState(() => _bowls.addAll(bowls));
      _bowlService.subscribe(
        onCreate: (bowl) {
          if (mounted && !_bowls.any((b) => b.pbId == bowl.pbId)) {
            setState(() => _bowls.add(bowl));
          }
        },
        onDelete: (pbId) {
          if (mounted) setState(() => _bowls.removeWhere((b) => b.pbId == pbId));
        },
        onUpdate: (pbId, name) {
          if (mounted) {
            setState(() {
              final idx = _bowls.indexWhere((b) => b.pbId == pbId);
              if (idx != -1) _bowls[idx].name = name;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'PocketBase error: $e');
    }
  }

  Future<void> _addBowl(String id, String name) async {
    if (_bowls.any((b) => b.id == id)) return;
    try {
      final bowl = await _bowlService.addBowl(id, name);
      if (mounted) setState(() => _bowls.add(bowl));
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Failed to add bowl: $e');
    }
  }

  Future<void> _removeBowl(String pbId) async {
    try {
      await _bowlService.removeBowl(pbId);
      if (mounted) setState(() => _bowls.removeWhere((b) => b.pbId == pbId));
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Failed to remove bowl: $e');
    }
  }

  Future<void> _renameBowl(String pbId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Bowl'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;
    try {
      await _bowlService.renameBowl(pbId, newName);
      if (mounted) {
        setState(() {
          final idx = _bowls.indexWhere((b) => b.pbId == pbId);
          if (idx != -1) _bowls[idx].name = newName;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Failed to rename bowl: $e');
    }
  }

  void _handleAnnounce(String bowlId) {
    if (_bowls.any((b) => b.id == bowlId)) return;
    final defaultName = 'Bowl ${bowlId.substring(bowlId.length - 4)}';
    _addBowl(bowlId, defaultName);
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
    _bowlService.unsubscribe();
    _mqtt.disconnect();
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
                    itemBuilder: (context, i) => BowlCard(
                      bowl: _bowls[i],
                      enabled: _connected,
                      onOpen: () => _mqtt.publish(_bowls[i].id, 'open'),
                      onClose: () => _mqtt.publish(_bowls[i].id, 'close'),
                      onRemove: () => _removeBowl(_bowls[i].pbId),
                      onRename: () =>
                          _renameBowl(_bowls[i].pbId, _bowls[i].name),
                      onTap: _bowls[i].camera == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CameraScreen(
                                    bowl: _bowls[i],
                                    camBase: widget.camBase,
                                  ),
                                ),
                              ),
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
