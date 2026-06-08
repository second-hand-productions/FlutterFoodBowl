import 'package:pocketbase/pocketbase.dart';

/// A Frigate camera linked to a bowl. [frigateName] is the camera's key in
/// Frigate (e.g. `zero1`), which is what its media URLs are built from.
class Camera {
  const Camera({required this.pbId, required this.frigateName});

  final String pbId;
  final String frigateName;

  factory Camera.fromRecord(RecordModel record) => Camera(
        pbId: record.id,
        frigateName: record.getStringValue('frigate_name'),
      );

  /// Latest-frame snapshot URL, served by Frigate through the nginx `/frigate`
  /// proxy. [camBase] is the resolved front door + `/frigate`, e.g.
  /// `https://ubuntuserver.tailb99a87.ts.net/frigate`.
  String snapshotUrl(String camBase) => '$camBase/api/$frigateName/latest.jpg';
}
