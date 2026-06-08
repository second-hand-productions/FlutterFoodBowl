import 'package:flutter/material.dart';

import 'package:cod/features/bowl_detail/widgets/camera_feed_view.dart';
import 'package:cod/models/bowl_models.dart';
import 'package:cod/models/camera_models.dart';
import 'package:cod/services/cameras/camera_feed_repository.dart';

class BowlDetailPage extends StatelessWidget {
  const BowlDetailPage({
    super.key,
    required this.bowl,
    required this.state,
    required this.isConnected,
    required this.cameraFeedRepository,
    required this.onOpen,
    required this.onClose,
    required this.onStatus,
  });

  final FoodBowlConfig bowl;
  final BowlRuntimeState state;
  final bool isConnected;
  final CameraFeedRepository? cameraFeedRepository;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(bowl.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CameraPanel(
              bowl: bowl,
              cameraFeedRepository: cameraFeedRepository,
            ),
            const SizedBox(height: 16),
            _BowlStatePanel(bowl: bowl, state: state),
            const SizedBox(height: 16),
            _DoorActionsPanel(
              isConnected: isConnected,
              onOpen: onOpen,
              onClose: onClose,
              onStatus: onStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPanel extends StatefulWidget {
  const _CameraPanel({required this.bowl, required this.cameraFeedRepository});

  final FoodBowlConfig bowl;
  final CameraFeedRepository? cameraFeedRepository;

  @override
  State<_CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<_CameraPanel> {
  Future<CameraFeed?>? _feedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = _loadFeed();
  }

  Future<CameraFeed?> _loadFeed() async {
    return widget.cameraFeedRepository?.findFeedForBowl(widget.bowl);
  }

  void _refreshFeed() {
    setState(() {
      _feedFuture = _loadFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<CameraFeed?>(
          future: _feedFuture,
          builder: (context, snapshot) {
            final titleRow = Row(
              children: [
                Expanded(
                  child: Text(
                    'Camera',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Reload camera',
                  onPressed: _refreshFeed,
                  icon: const Icon(Icons.sync),
                ),
              ],
            );

            if (snapshot.connectionState != ConnectionState.done) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleRow,
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleRow,
                  const SizedBox(height: 16),
                  _MessagePanel(
                    icon: Icons.error_outline,
                    message: 'Camera lookup failed',
                    detail: snapshot.error.toString(),
                  ),
                ],
              );
            }

            final feed = snapshot.data;
            if (feed == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleRow,
                  const SizedBox(height: 16),
                  const _MessagePanel(
                    icon: Icons.videocam_off_outlined,
                    message: 'No camera configured',
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleRow,
                const SizedBox(height: 8),
                Text(feed.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                CameraFeedView(feed: feed),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BowlStatePanel extends StatelessWidget {
  const _BowlStatePanel({required this.bowl, required this.state});

  final FoodBowlConfig bowl;
  final BowlRuntimeState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Door', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _DetailRow(label: 'Bowl ID', value: bowl.id),
            const SizedBox(height: 8),
            _DetailRow(label: 'Status', value: state.status),
            const SizedBox(height: 8),
            _DetailRow(label: 'Availability', value: state.availability),
            const SizedBox(height: 8),
            _DetailRow(label: 'Last command', value: state.lastCommand),
            const SizedBox(height: 8),
            _DetailRow(label: 'Last result', value: state.lastResult),
          ],
        ),
      ),
    );
  }
}

class _DoorActionsPanel extends StatelessWidget {
  const _DoorActionsPanel({
    required this.isConnected,
    required this.onOpen,
    required this.onClose,
    required this.onStatus,
  });

  final bool isConnected;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.message, this.detail});

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: colorScheme.outline),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
