// Web inherits the origin that served the app, so a single build works on the
// LAN (http/ws) and over Tailscale (https/wss) with no probing needed.
Future<(String httpBase, String wsBase)> resolveBackend() async {
  final base = Uri.base;
  final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
  return ('${base.scheme}://${base.authority}', '$wsScheme://${base.authority}');
}
