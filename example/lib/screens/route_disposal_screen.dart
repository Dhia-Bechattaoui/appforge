import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

/// Dedicated controller whose lifecycle is bound exclusively to this route.
class RouteSubController extends AppController {
  final localCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    debugPrint('AppForge: RouteSubController onInit()');
  }

  @override
  void onClose() {
    debugPrint('AppForge: RouteSubController onClose() - Disposed cleanly!');
    super.onClose();
  }
}

/// Screen demonstrating automatic route-bound controller disposal.
class RouteDisposalScreen extends StatelessWidget {
  const RouteDisposalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBind<RouteSubController>(
      create: () => RouteSubController(),
      builder: (context, controller) {
        return Scaffold(
          appBar: AppBar(title: Text('disposal_screen_title'.tr)),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${'controller_status'.tr} ${App.isRegistered<RouteSubController>() ? "REGISTERED (Active)" : "NOT FOUND"}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'disposal_desc'.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Watch(
                  (context) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Local Count: ${controller.localCount.value}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => controller.localCount.value++,
                          icon: const Icon(Icons.add),
                          label: const Text('Increment Local Count'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: Text('btn_pop'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
