import 'package:flutter/material.dart';

import 'package:cod/models/camera_models.dart';

class CameraFeedView extends StatefulWidget {
  const CameraFeedView({super.key, required this.feed});

  final CameraFeed feed;

  @override
  State<CameraFeedView> createState() => _CameraFeedViewState();
}

class _CameraFeedViewState extends State<CameraFeedView> {
  var _refreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final feedUri = _displayUri(feed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                feed.refreshesAsImage
                    ? _buildNetworkImage(
                      feedUri,
                      fallbackUri:
                          feed.snapshotUri == null ||
                                  feed.snapshotUri == feedUri
                              ? null
                              : _refreshedUri(feed.snapshotUri!),
                    )
                    : _FeedPlaceholder(
                      icon: Icons.open_in_new,
                      text: feed.displayUri.toString(),
                    ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                feed.displayUri.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh camera',
              onPressed: () {
                setState(() {
                  _refreshToken += 1;
                });
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ],
    );
  }

  Uri _displayUri(CameraFeed feed) {
    if (feed.kind == CameraFeedKind.mjpeg) {
      return feed.displayUri;
    }

    return _refreshedUri(feed.displayUri);
  }

  Uri _refreshedUri(Uri uri) {
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'refresh': _refreshToken.toString(),
      },
    );
  }

  Widget _buildNetworkImage(Uri uri, {Uri? fallbackUri}) {
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        if (fallbackUri != null) {
          return _buildNetworkImage(fallbackUri);
        }

        return _FeedPlaceholder(
          icon: Icons.videocam_off_outlined,
          text: 'Camera unavailable',
        );
      },
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
