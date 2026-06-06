import 'dart:io';

// Two ways to reach nginx. The LAN name works on the home subnet without
// Tailscale (plain http/ws); the Tailscale MagicDNS name works from anywhere
// with Tailscale up (https/wss, TLS terminated by `tailscale serve`). nginx owns
// the root, serves the app at /cla/, and proxies shared /pb and /mqtt backends.
const String _lanHost = 'cla.lan';
const String _tailnetHost = 'ubuntuserver.tailb99a87.ts.net';

/// Returns `(httpBase, wsBase)` for the reachable nginx front door. Probes the
/// LAN first so the app works at home without Tailscale, then falls back to the
/// Tailscale name for remote use.
Future<(String httpBase, String wsBase)> resolveBackend() async {
  if (await _reachable('http://$_lanHost/cla/')) {
    return ('http://$_lanHost', 'ws://$_lanHost');
  }
  return ('https://$_tailnetHost', 'wss://$_tailnetHost');
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
