import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

import '../controllers/app_settings_controller.dart';
import 'dashboard_tab.dart';
import 'localization_tab.dart';
import 'state_tab.dart';
import 'responsive_tab.dart';
import 'lifecycle_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    App.localeNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    App.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = App.find<AppSettingsController>();

    final tabs = const [
      DashboardTab(),
      LocalizationTab(),
      StateTab(),
      ResponsiveTab(),
      LifecycleTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'AF',
                style: TextStyle(
                  color: Color(0xFFC99A3D),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'app_name'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Theme Toggle
          ValueListenableBuilder<ThemeMode>(
            valueListenable: App.themeModeNotifier,
            builder: (context, mode, child) => IconButton(
              onPressed: settings.toggleTheme,
              icon: Icon(
                App.isDark ? Icons.light_mode : Icons.dark_mode,
                color: const Color(0xFFC99A3D),
              ),
              tooltip: 'theme_toggle'.tr,
            ),
          ),

          // Language Switcher Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: InkWell(
              onTap: settings.toggleLanguage,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFC99A3D),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    'switch_lang'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Global Reactive Offline Banner
          Watch((context) {
            if (App.isOnline.value) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red.shade800,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'offline_banner_msg'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () async {
                        // Clear simulation so retry checks real connectivity
                        AppConnectivity.instance.customChecker = null;
                        final isOnline = await App.checkConnectivity();
                        App.snackbar(
                          isOnline
                              ? 'ping_success_title'.tr
                              : 'ping_error_title'.tr,
                          isOnline
                              ? 'ping_success_msg'.tr
                              : 'ping_error_msg'.tr,
                          type: isOnline
                              ? AppSnackbarType.success
                              : AppSnackbarType.error,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'retry'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: tabs),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: 'tab_dashboard'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.translate_outlined),
            activeIcon: const Icon(Icons.translate),
            label: 'tab_localization'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bolt_outlined),
            activeIcon: const Icon(Icons.bolt),
            label: 'tab_state'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.aspect_ratio_outlined),
            activeIcon: const Icon(Icons.aspect_ratio),
            label: 'tab_responsive'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.devices_outlined),
            activeIcon: const Icon(Icons.devices),
            label: 'tab_lifecycle'.tr,
          ),
        ],
      ),
    );
  }
}
