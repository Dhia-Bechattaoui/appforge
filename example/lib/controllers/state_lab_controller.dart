import 'package:appforge/appforge.dart';

/// Controller managing reactive signals and discrete UiState transitions.
class StateLabController extends AppController {
  final count = 0.obs;
  final requestState = const UiState<String>.idle().obs;
  int _cycleIndex = 0;

  void increment() => count.value++;

  void decrement() {
    if (count.value > 0) count.value--;
  }

  void cycleState() {
    _cycleIndex = (_cycleIndex + 1) % 4;
    switch (_cycleIndex) {
      case 0:
        requestState.value = const UiState.idle();
      case 1:
        requestState.value = const UiState.loading();
      case 2:
        requestState.value = const UiState.success('Auth Token: #8929-SECURE');
      case 3:
        requestState.value = const UiState.failure(
          'Connection reset by peer (503)',
        );
    }
  }
}
