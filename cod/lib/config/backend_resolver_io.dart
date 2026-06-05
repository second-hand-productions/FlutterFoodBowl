import 'dart:io';

const bool isBrowserBuild = false;

Future<(String httpBaseUri, String webSocketBaseUri)> resolveBackend({
  required String lanHost,
  required String tailnetHost,
}) async {
  if (await _reachable('http://$lanHost/')) {
    return ('http://$lanHost', 'ws://$lanHost');
  }

  return ('https://$tailnetHost', 'wss://$tailnetHost');
}

Future<bool> _reachable(String url) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
    return response.statusCode >= 200 && response.statusCode < 500;
  } catch (_) {
    return false;
  } finally {
    client?.close(force: true);
  }
}
