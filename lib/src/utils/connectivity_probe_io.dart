import 'dart:async';
import 'dart:io';

/// Races candidate [targetHosts] via low-overhead DNS/TCP lookups on `dart:io`.
Future<bool> probeConnectivity(
  List<String> targetHosts,
  Duration timeout,
) async {
  if (targetHosts.isEmpty) return false;

  final completer = Completer<bool>();
  int pending = targetHosts.length;

  for (final host in targetHosts) {
    _pingSingleHost(host, timeout).then((success) {
      if (success && !completer.isCompleted) {
        completer.complete(true);
      } else {
        pending--;
        if (pending <= 0 && !completer.isCompleted) {
          completer.complete(false);
        }
      }
    }).catchError((_) {
      pending--;
      if (pending <= 0 && !completer.isCompleted) {
        completer.complete(false);
      }
    });
  }

  return completer.future.timeout(timeout, onTimeout: () => false);
}

Future<bool> _pingSingleHost(String host, Duration timeout) async {
  try {
    final lookupResults = await InternetAddress.lookup(host)
        .timeout(timeout, onTimeout: () => []);
    if (lookupResults.isEmpty || lookupResults.first.rawAddress.isEmpty) {
      return false;
    }
    final socket = await Socket.connect(
      lookupResults.first,
      53,
      timeout: timeout,
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
