enum CameraFeedKind { image, mjpeg, external }

class CameraFeed {
  const CameraFeed({
    required this.recordId,
    required this.name,
    required this.displayUri,
    required this.kind,
    this.snapshotUri,
  });

  final String recordId;
  final String name;
  final Uri displayUri;
  final CameraFeedKind kind;
  final Uri? snapshotUri;

  bool get refreshesAsImage =>
      kind == CameraFeedKind.image || kind == CameraFeedKind.mjpeg;
}
