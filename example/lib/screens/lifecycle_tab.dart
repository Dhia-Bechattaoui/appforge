import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

import '../controllers/lifecycle_lab_controller.dart';

class LifecycleTab extends StatelessWidget {
  const LifecycleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = App.find<LifecycleLabController>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Real-time Lifecycle State Header
        ValueListenableBuilder<AppLifecycleState>(
          valueListenable: App.lifecycleNotifier,
          builder: (context, state, _) {
            final isResumed = state == AppLifecycleState.resumed;
            final color = isResumed ? Colors.green : Colors.amber;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isResumed ? Icons.bolt : Icons.pause_circle_outline,
                    color: color,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OS Lifecycle: ${state.name.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isResumed
                              ? 'App is active in foreground receiving user touch events.'
                              : 'App is transitioning or backgrounded in memory.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Draft Auto-Save Form (Simulates surviving LMK / Jetsam process death)
        _buildCard(
          context: context,
          title: 'lifecycle_title'.tr,
          description: 'lifecycle_subtitle'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'draft_input_label'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (val) => controller.currentDraftInput.value = val,
                decoration: InputDecoration(hintText: 'draft_input_hint'.tr),
              ),
              const SizedBox(height: 12),
              Watch((context) {
                final saved = controller.lastSavedDraft.value;
                if (saved.isEmpty) return const SizedBox.shrink();

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.green.shade900.withValues(alpha: 0.25)
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.shade700
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.save_as, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${'last_saved'.tr} "$saved"',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.green.shade200
                                : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Event Log
        _buildCard(
          context: context,
          title: 'lifecycle_history'.tr,
          description:
              'Chronological feed of OS transitions received by AppController:',
          child: Watch((context) {
            final logs = controller.eventLog.value;
            if (logs.isEmpty) {
              return const Text('No lifecycle events recorded yet.');
            }

            return Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1D),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white12, height: 8),
                itemBuilder: (context, index) {
                  return Text(
                    logs[index],
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: Color(0xFF38BDF8),
                    ),
                  );
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF8FAFC)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
