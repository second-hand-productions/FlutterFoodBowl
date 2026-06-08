import 'package:flutter/material.dart';
import '../models/bowl.dart';
import '../widgets/camera_view.dart';

/// Full-screen camera feed for a bowl, opened by tapping its card.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key, required this.bowl, required this.camBase});

  final Bowl bowl;
  final String camBase;

  @override
  Widget build(BuildContext context) {
    final camera = bowl.camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(bowl.name)),
      body: Center(
        child: camera == null
            ? const Text(
                'No camera linked to this bowl',
                style: TextStyle(color: Colors.white70),
              )
            : InteractiveViewer(
                child: CameraView(snapshotUrl: camera.snapshotUrl(camBase)),
              ),
      ),
    );
  }
}
