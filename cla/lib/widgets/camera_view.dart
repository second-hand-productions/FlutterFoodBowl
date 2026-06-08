import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a Frigate camera by polling its latest-frame snapshot. Frigate 0.17
/// exposes no plain MJPEG endpoint, but `latest.jpg` is stable and works on web
/// and native alike. [Image.network] with `gaplessPlayback` keeps the previous
/// frame on screen while the next one loads, so the refresh doesn't flicker.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    required this.snapshotUrl,
    this.refreshInterval = const Duration(seconds: 1),
    this.height = 480,
  });

  /// Snapshot URL without a query string, e.g. `…/frigate/api/zero1/latest.jpg`.
  final String snapshotUrl;
  final Duration refreshInterval;
  final int height;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `t` busts the browser cache so each poll fetches a fresh frame; `h` asks
    // Frigate to scale the JPEG to a sensible size.
    final url = '${widget.snapshotUrl}?h=${widget.height}&t=$_tick';
    return Image.network(
      url,
      gaplessPlayback: true,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Center(
            child: CircularProgressIndicator(),
          ),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Camera feed unavailable',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
