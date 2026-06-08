import 'package:flutter/material.dart';

import 'package:cod/config/food_bowl_settings.dart';
import 'package:cod/models/bowl_models.dart';
import 'package:cod/services/mqtt/mqtt_topics.dart';

class ConnectionPanel extends StatelessWidget {
  const ConnectionPanel({
    super.key,
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
            _BrokerDetail(label: 'Endpoint', value: brokerUri),
            const SizedBox(height: 8),
            _BrokerDetail(label: 'PocketBase', value: pocketBaseUri),
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

class EmptyBowlsPanel extends StatelessWidget {
  const EmptyBowlsPanel({super.key, required this.onAddBowl});

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

class DoorControls extends StatelessWidget {
  const DoorControls({
    super.key,
    required this.bowl,
    required this.state,
    required this.isConnected,
    required this.onOpen,
    required this.onClose,
    required this.onStatus,
    required this.onViewCamera,
    required this.onRename,
    required this.onRemove,
  });

  final FoodBowlConfig bowl;
  final BowlRuntimeState state;
  final bool isConnected;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onStatus;
  final VoidCallback onViewCamera;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onViewCamera,
        borderRadius: BorderRadius.circular(8),
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
                    tooltip: 'View camera',
                    onPressed: onViewCamera,
                    icon: const Icon(Icons.videocam_outlined),
                  ),
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
      ),
    );
  }
}

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.brokerState,
    required this.statusMessage,
  });

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
