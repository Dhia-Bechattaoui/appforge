import 'package:appforge/appforge.dart';

/// Controller observing operating system lifecycle and demonstrating draft auto-saving.
class LifecycleLabController extends AppController {
  final currentDraftInput = ''.obs;
  final lastSavedDraft = ''.obs;
  final eventLog = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _logEvent('Controller onInit executed');
  }

  @override
  void onReady() {
    super.onReady();
    _logEvent('UI Ready & Frame Rendered');
  }

  @override
  void onPaused() {
    // OS backgrounded the application (Home button pressed or app switched)
    if (currentDraftInput.value.isNotEmpty) {
      lastSavedDraft.value = currentDraftInput.value;
      _logEvent(
        'onPaused: Auto-saved draft "${currentDraftInput.value}" to survive LMK/Jetsam',
      );
    } else {
      _logEvent('onPaused: App moved to background');
    }
  }

  @override
  void onResumed() {
    _logEvent('onResumed: App restored to foreground');
  }

  @override
  void onInactive() {
    _logEvent('onInactive: Notification tray or system overlay');
  }

  void _logEvent(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    eventLog.update((list) => list.insert(0, '[$timeStr] $message'));
  }
}
