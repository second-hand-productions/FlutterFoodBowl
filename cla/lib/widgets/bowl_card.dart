import 'package:flutter/material.dart';
import '../models/bowl.dart';

class BowlCard extends StatelessWidget {
  const BowlCard({
    super.key,
    required this.bowl,
    required this.enabled,
    required this.onOpen,
    required this.onClose,
    required this.onRemove,
    required this.onRename,
    this.onTap,
  });

  final Bowl bowl;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  /// Tapping the card body (not the buttons) opens the camera feed. Null when
  /// the bowl has no linked camera, which also disables the ripple.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (bowl.lidState) {
      LidState.open => (Icons.lock_open_rounded, Colors.green, 'Open'),
      LidState.closed => (Icons.lock_rounded, Colors.red, 'Closed'),
      LidState.unknown => (Icons.help_outline_rounded, Colors.grey, 'Unknown'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
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
                  if (bowl.camera != null)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.videocam, size: 20, color: Colors.grey),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    color: Colors.grey,
                    onPressed: onRename,
                    tooltip: 'Rename bowl',
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
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.green),
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
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                    ),
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
