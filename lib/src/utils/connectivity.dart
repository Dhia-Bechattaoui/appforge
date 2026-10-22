import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../core/lifecycle.dart';
import '../state/rx.dart';

/// Zero-dependency network connectivity and internet reachability monitor.
///
/// Unlike standard OS interface checkers which only verify if Wi-Fi or cellular
/// is toggled on, [AppConnectivity] checks actual end-to-end internet reachability
/// via low-overhead socket lookups using Dart standard library `dart:io`.
///
/// It provides a reactive [isOnline] observable (`Rx<bool>`) for declarative UI rebuilds,
/// a broadcast stream, in-flight deduplication, parallel host racing, and automatic
/// lifecycle pause/resume to eliminate background battery drain.
class AppConnectivity {
  AppConnectivity._();

  static final AppConnectivity _instance = AppConnectivity._();

  /// Singleton instance of [AppConnectivity].
  static AppConnectivity get instance => _instance;

  /// Default reliable IP endpoints used for quick socket connectivity pings (port 53 DNS).
  static const List<String> defaultLookupHosts = [
    '1.1.1.1',
    '8.8.8.8',
    'one.one.one.one',
  ];

  /// Reactive observable tracking whether the device currently has internet reachability.
  ///
  /// Can be observed directly in widgets using `Watch`:
  /// ```dart
  /// Watch((context) => App.isOnline.value
  ///     ? const SizedBox.shrink()
  ///     : const OfflineBanner());
  /// ```
  final Rx<bool> isOnline = true.obs;

  /// Returns `true` if the device is currently confirmed offline.
  bool get isOffline => !isOnline.value;

  /// Stream of connectivity status changes.
  Stream<bool> get onConnectivityChanged => isOnline.stream;

  Timer? _monitorTimer;
  bool _isMonitoringActive = false;
  Duration _activeInterval = const Duration(seconds: 5);
  List<String> _activeHosts = defaultLookupHosts;
  Duration _activeTimeout = const Duration(seconds: 3);
  RxSubscription? _lifecycleSubscription;
  Future<bool>? _inFlightCheck;

  /// Optional custom connectivity test resolver (primarily used for unit testing).
  Future<bool> Function()? customChecker;

  /// Performs a network reachability check and updates [isOnline].
  ///
  /// If a check is already in-flight, returns the existing in-flight [Future]
  /// to prevent redundant socket allocation and state-update race conditions.
  Future<bool> checkConnection({
    List<String>? hosts,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_inFlightCheck != null) {
      return _inFlightCheck!;
    }

    final future = () async {
      if (customChecker != null) {
        return await customChecker!();
      }
      return await _checkHostsParallel(hosts ?? _activeHosts, timeout);
    }();

    _inFlightCheck = future;
    try {
      final connected = await future;
      isOnline.value = connected;
      return connected;
    } finally {
      _inFlightCheck = null;
    }
  }

  /// Races all candidate hosts in parallel. Resolves immediately when the
  /// first host responds successfully, or returns false if all hosts fail
  /// within [timeout].
  Future<bool> _checkHostsParallel(
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

  static Future<bool> _pingSingleHost(String host, Duration timeout) async {
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

  /// Starts background periodic connectivity monitoring.
  ///
  /// [interval] specifies how often to ping for connectivity (defaults to 5 seconds).
  /// [hosts] specifies the target hostnames or IP addresses to test against.
  /// [timeout] specifies socket timeout per attempt (defaults to 3 seconds).
  ///
  /// Automatically pauses polling while the application is backgrounded (`paused`, `hidden`)
  /// to eliminate battery and cellular radio drain, and resumes immediately upon return.
  void startMonitoring({
    Duration interval = const Duration(seconds: 5),
    List<String>? hosts,
    Duration timeout = const Duration(seconds: 3),
  }) {
    stopMonitoring();
    _isMonitoringActive = true;
    _activeInterval = interval;
    _activeHosts = hosts ?? defaultLookupHosts;
    _activeTimeout = timeout;

    _scheduleTimer();

    // Trigger initial check immediately
    checkConnection(hosts: _activeHosts, timeout: _activeTimeout);

    // Pause periodic polling while backgrounded to conserve battery and radio
    _lifecycleSubscription = AppLifecycleManager.instance.addListener((state) {
      if (!_isMonitoringActive) return;
      if (state == AppLifecycleState.resumed) {
        _scheduleTimer();
        checkConnection(hosts: _activeHosts, timeout: _activeTimeout);
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        _cancelTimer();
      }
    });
  }

  void _scheduleTimer() {
    _cancelTimer();
    _monitorTimer = Timer.periodic(_activeInterval, (_) {
      checkConnection(hosts: _activeHosts, timeout: _activeTimeout);
    });
  }

  void _cancelTimer() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// Stops the background connectivity monitor and cancels its timer and lifecycle listener.
  void stopMonitoring() {
    _isMonitoringActive = false;
    _cancelTimer();
    _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
  }

  /// Resets connectivity state and stops monitoring (primarily used for test teardown).
  void reset() {
    stopMonitoring();
    customChecker = null;
    _activeHosts = defaultLookupHosts;
    isOnline.value = true;
  }
}
