import 'dart:js_interop';

@JS('window.navigator.onLine')
external bool? get _navigatorOnLine;

/// Checks browser network availability using `window.navigator.onLine` on Web.
Future<bool> probeConnectivity(
  List<String> targetHosts,
  Duration timeout,
) async {
  return _navigatorOnLine ?? true;
}
