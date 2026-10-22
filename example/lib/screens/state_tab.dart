import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

import '../controllers/state_lab_controller.dart';

class StateTab extends StatelessWidget {
  const StateTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = App.find<StateLabController>();
    final isArabic = App.isRtl;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Reactive Signal Counter
        _buildCard(
          context: context,
          title: 'state_title'.tr,
          description: 'state_subtitle'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.15 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primary.withValues(alpha: isDark ? 0.35 : 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'reactive_counter'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Watch(
                          (context) => Text(
                            isArabic
                                ? controller.count.value
                                      .toString()
                                      .toArabicDigits
                                : '${controller.count.value}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: controller.decrement,
                              icon: const Icon(Icons.remove, size: 16),
                              label: Text('btn_decrement'.tr),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? theme.cardColor
                                    : Colors.grey.shade200,
                                foregroundColor: isDark
                                    ? const Color(0xFFE2E8F0)
                                    : Colors.black87,
                                elevation: 0,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: controller.increment,
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('btn_increment'.tr),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: onPrimary,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Discrete UiState Machine
        _buildCard(
          context: context,
          title: 'uistate_title'.tr,
          description: 'uistate_desc'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Watch.state<String>(
                  state: controller.requestState,
                  onIdle: (context) => _buildStateBadge(
                    icon: Icons.pause_circle_outline,
                    color: Colors.grey,
                    text: 'status_idle'.tr,
                  ),
                  onLoading: (context) => _buildStateBadge(
                    icon: Icons.refresh,
                    color: Colors.blue,
                    text: 'status_loading'.tr,
                    isLoading: true,
                  ),
                  onSuccess: (context, data) => _buildStateBadge(
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    text: '${'status_success'.tr} ($data)',
                  ),
                  onFailure: (context, msg, _) => _buildStateBadge(
                    icon: Icons.error_outline,
                    color: Colors.red,
                    text: '${'status_failure'.tr} ($msg)',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.cycleState,
                  icon: const Icon(Icons.sync),
                  label: Text('btn_cycle_state'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStateBadge({
    required IconData icon,
    required Color color,
    required String text,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
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
