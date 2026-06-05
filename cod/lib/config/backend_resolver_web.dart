const bool isBrowserBuild = true;

Future<(String httpBaseUri, String webSocketBaseUri)> resolveBackend({
  required String lanHost,
  required String tailnetHost,
}) async {
  final base = Uri.base;
  final webSocketScheme = base.scheme == 'https' ? 'wss' : 'ws';
  return (
    '${base.scheme}://${base.authority}',
    '$webSocketScheme://${base.authority}',
  );
}
