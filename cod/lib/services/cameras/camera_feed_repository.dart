import 'package:pocketbase/pocketbase.dart';

import 'package:cod/config/food_bowl_settings.dart';
import 'package:cod/models/bowl_models.dart';
import 'package:cod/models/camera_models.dart';

abstract class CameraFeedRepository {
  Future<CameraFeed?> findFeedForBowl(FoodBowlConfig bowl);
}

class PocketBaseCameraFeedRepository implements CameraFeedRepository {
  PocketBaseCameraFeedRepository({PocketBase? pocketBase})
    : _pb = pocketBase ?? PocketBase(pocketBaseUri);

  final PocketBase _pb;

  @override
  Future<CameraFeed?> findFeedForBowl(FoodBowlConfig bowl) async {
    final relationFields = {
      cameraBowlRelationField,
      if (cameraBowlRelationField != 'bowl') 'bowl',
      if (cameraBowlRelationField != 'relation') 'relation',
    };
    final idFields = {'bowl_id', 'bowlId'};

    ClientException? lastClientException;
    var reachedCollection = false;

    if (bowl.recordId != null) {
      for (final fieldName in relationFields) {
        for (final operator in const ['=', '?=']) {
          try {
            final feed = await _findFeed(
              filter: '$fieldName $operator "${_filterValue(bowl.recordId!)}"',
            );
            reachedCollection = true;
            if (feed != null) {
              return feed;
            }
          } on ClientException catch (error) {
            lastClientException = error;
          }
        }
      }
    }

    for (final fieldName in idFields) {
      try {
        final feed = await _findFeed(
          filter: '$fieldName = "${_filterValue(bowl.id)}"',
        );
        reachedCollection = true;
        if (feed != null) {
          return feed;
        }
      } on ClientException catch (error) {
        lastClientException = error;
      }
    }

    if (!reachedCollection && lastClientException != null) {
      throw lastClientException;
    }

    return null;
  }

  Future<CameraFeed?> _findFeed({required String filter}) async {
    final result = await _pb
        .collection(cameraCollection)
        .getList(page: 1, perPage: 1, filter: filter, sort: 'name');
    if (result.items.isEmpty) {
      return null;
    }

    return _feedFromRecord(result.items.first);
  }

  CameraFeed? _feedFromRecord(RecordModel record) {
    if (!_boolField(record.data, const ['enabled', 'is_enabled'], true)) {
      return null;
    }

    final name =
        _stringField(record.data, const [
          'name',
          'display_name',
          'displayName',
          'camera_name',
          'cameraName',
          'frigate_camera',
          'frigateName',
          'stream_name',
          'streamName',
        ]) ??
        'Camera';
    final streamName = _stringField(record.data, const [
      'frigate_camera',
      'frigateName',
      'frigate_name',
      'frigateName',
      'stream_name',
      'streamName',
      'camera_name',
      'cameraName',
      'name',
    ]);
    final feedUri =
        _uriField(record.data, const [
          'mjpeg_url',
          'mjpegUrl',
          'feed_url',
          'feedUrl',
          'stream_url',
          'streamUrl',
          'live_url',
          'liveUrl',
          'displayUri',
          'url',
        ]) ??
        _frigateMjpegUri(streamName);
    final snapshotUri =
        _uriField(record.data, const [
          'snapshot_url',
          'snapshotUri',
          'snapshotUrl',
          'latest_url',
          'latestUrl',
          'still_url',
          'stillUrl',
          'poster_url',
          'posterUrl',
        ]) ??
        _frigateSnapshotUri(streamName);

    if (feedUri == null && snapshotUri == null) {
      return null;
    }

    return CameraFeed(
      recordId: record.id,
      name: name,
      displayUri: feedUri ?? snapshotUri!,
      kind: _feedKind(feedUri ?? snapshotUri!),
      snapshotUri: snapshotUri,
    );
  }

  CameraFeedKind _feedKind(Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp')) {
      return CameraFeedKind.image;
    }
    if (lowerPath.endsWith('.m3u8') ||
        lowerPath.endsWith('.mpd') ||
        uri.scheme == 'rtsp' ||
        uri.scheme == 'webrtc') {
      return CameraFeedKind.external;
    }
    return CameraFeedKind.mjpeg;
  }

  Uri? _uriField(Map<String, dynamic> data, List<String> fields) {
    final value = _stringField(data, fields);
    if (value == null) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }
    if (uri.hasScheme) {
      return uri;
    }

    return Uri.parse(frigateUri).resolve(value);
  }

  Uri? _frigateMjpegUri(String? streamName) {
    if (streamName == null || streamName.isEmpty) {
      return null;
    }

    return Uri.parse(
      '${_withoutTrailingSlash(frigateUri)}/api/${Uri.encodeComponent(streamName)}',
    );
  }

  Uri? _frigateSnapshotUri(String? streamName) {
    if (streamName == null || streamName.isEmpty) {
      return null;
    }

    return Uri.parse(
      '${_withoutTrailingSlash(frigateUri)}/api/${Uri.encodeComponent(streamName)}/latest.jpg',
    );
  }

  String? _stringField(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      final value = data[field];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool _boolField(
    Map<String, dynamic> data,
    List<String> fields,
    bool fallback,
  ) {
    for (final field in fields) {
      final value = data[field];
      if (value is bool) {
        return value;
      }
    }
    return fallback;
  }

  String _filterValue(String value) {
    return value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  }

  String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
