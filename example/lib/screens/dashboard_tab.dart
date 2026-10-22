import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

import '../controllers/app_settings_controller.dart';
import 'route_disposal_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = App.find<AppSettingsController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF041C4E), const Color(0xFF0F3A7E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF041C4E))
                    .withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC99A3D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'dash_title'.tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'dash_subtitle'.tr,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Metrics Grid (Locale, Theme, Lifecycle, Controllers)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildMetricCard(
              icon: Icons.language,
              label: 'dash_card_locale'.tr,
              value: 'dash_active_locale'.tr,
              color: Colors.blue,
            ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: App.themeModeNotifier,
              builder: (context, mode, child) {
                return _buildMetricCard(
                  icon: App.isDark ? Icons.dark_mode : Icons.light_mode,
                  label: 'dash_card_theme'.tr,
                  value: App.isDark ? 'theme_dark'.tr : 'theme_light'.tr,
                  color: Colors.orange,
                );
              },
            ),
            ValueListenableBuilder<AppLifecycleState>(
              valueListenable: App.lifecycleNotifier,
              builder: (context, state, _) {
                return _buildMetricCard(
                  icon: Icons.devices,
                  label: 'dash_card_lifecycle'.tr,
                  value: state.name.toUpperCase(),
                  color: state == AppLifecycleState.resumed
                      ? Colors.green
                      : Colors.amber,
                );
              },
            ),
            _buildMetricCard(
              icon: Icons.memory,
              label: 'dash_card_controllers'.tr,
              value: '${settings.registeredControllerCount} Active',
              color: Colors.purple,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Live Network Reachability Card (Zero Dependencies)
        Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.wifi,
                      color: Color(0xFFC99A3D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'connectivity_title'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Watch(
                (context) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: App.isOnline.value
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: App.isOnline.value ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: App.isOnline.value ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          App.isOnline.value
                              ? 'connectivity_status_online'.tr
                              : 'connectivity_status_offline'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: App.isOnline.value
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'connectivity_desc'.tr,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        App.showLoading();
                        // Clear simulation so real socket ping is executed
                        AppConnectivity.instance.customChecker = null;
                        final connected = await App.checkConnectivity();
                        App.hideLoading();
                        App.snackbar(
                          connected
                              ? 'ping_success_title'.tr
                              : 'ping_error_title'.tr,
                          connected
                              ? 'ping_success_msg'.tr
                              : 'ping_error_msg'.tr,
                          type: connected
                              ? AppSnackbarType.success
                              : AppSnackbarType.error,
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text('btn_ping_now'.tr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Watch(
                    (context) => OutlinedButton(
                      onPressed: () {
                        if (AppConnectivity.instance.customChecker == null) {
                          // Simulate offline
                          AppConnectivity.instance.customChecker = () async =>
                              false;
                          App.checkConnectivity();
                        } else {
                          // Restore real network
                          AppConnectivity.instance.customChecker = null;
                          App.checkConnectivity();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            AppConnectivity.instance.customChecker != null
                            ? Colors.green
                            : Colors.red.shade700,
                        side: BorderSide(
                          color: AppConnectivity.instance.customChecker != null
                              ? Colors.green
                              : Colors.red.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        AppConnectivity.instance.customChecker != null
                            ? 'btn_restore_real'.tr
                            : 'btn_simulate_offline'.tr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Zero-Dependency AppStorage Engine Lab Card
        Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.save_rounded,
                      color: Color(0xFFC99A3D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'storage_card_title'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'storage_card_desc'.tr,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              // Live Storage Inspection Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primary.withValues(alpha: isDark ? 0.35 : 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language,
                          size: 14,
                          color: isDark ? Colors.white : primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'storage_persisted_locale'.trParams({
                            'locale':
                                App.storageRead<String>(
                                  'appforge_locale',
                                  defaultValue: App.locale.languageCode,
                                ) ??
                                App.locale.languageCode,
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC99A3D).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFC99A3D).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.palette_outlined,
                          size: 14,
                          color: Color(0xFFC99A3D),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'storage_persisted_theme'.trParams({
                            'theme':
                                App.storageRead<String>(
                                  'appforge_theme_mode',
                                  defaultValue: App.themeMode.name,
                                ) ??
                                App.themeMode.name,
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB07D2B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    settings.toggleLanguage();
                    final currentLang = App.locale.languageCode;
                    App.snackbar(
                      currentLang == 'ar' ? 'تم حفظ اللغة' : 'Language Saved',
                      currentLang == 'ar'
                          ? 'تم حفظ "العربية" تلقائياً في AppStorage وسيتم استعادتها عند إعادة تشغيل التطبيق.'
                          : 'Saved "English" to AppStorage. It will restore automatically upon app restart.',
                      type: AppSnackbarType.success,
                    );
                  },
                  icon: const Icon(Icons.translate, size: 16),
                  label: Text('storage_toggle_lang'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Zero-Dependency AppEnv Configuration Card
        Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFFC99A3D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'env_card_title'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'env_card_desc'.tr,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              // Live parsed env chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primary.withValues(alpha: isDark ? 0.35 : 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.apps,
                          size: 14,
                          color: isDark ? Colors.white : primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'env_app_name'.trParams({
                            'val': App.env(
                              'APP_NAME',
                              defaultValue: 'AppForge',
                            ),
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC99A3D).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFC99A3D).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed,
                          size: 14,
                          color: Color(0xFFC99A3D),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'env_timeout'.trParams({
                            'val':
                                '${App.envInt('API_TIMEOUT_SEC', defaultValue: 10)}',
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB07D2B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_queue,
                          size: 14,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'env_mode'.trParams({
                            'val': App.env('APP_ENV', defaultValue: 'dev'),
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'env_api_url'.trParams({
                            'val': App.env('API_BASE_URL', defaultValue: '-'),
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'env_secret_masked'.trParams({
                            'val': App.envMaskedMap['API_SECRET_KEY'] ?? '***',
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(
                        alpha: isDark ? 0.2 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '.env (${App.envMap.length} variables loaded)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    const sampleEnv = '''
# Server Configuration
HOST=127.0.0.1
PORT=8080
BASE_URL=https://\${HOST}:\${PORT}
API_ENDPOINT=\${BASE_URL}/api/v2
APP_SECRET="super-secret-token"
IS_STAGING=true
                    ''';
                    final parsed = AppEnv.parse(sampleEnv);
                    App.bottomSheet(
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.code,
                                  color: Color(0xFFC99A3D),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'env_dialog_title'.tr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'env_dialog_parsed_count'.trParams({
                                'count': '${parsed.length}',
                              }),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: parsed.entries.map((e) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${e.key}: ',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            e.value,
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              color: primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => App.back(),
                                child: Text('common_close'.tr),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.data_object, size: 16),
                  label: Text('env_btn_test_dialog'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Zero-Dependency Skeleton Shimmer Engine Card
        Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.animation_rounded,
                      color: Color(0xFFC99A3D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'shimmer_card_title'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'shimmer_card_desc'.tr,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              // Status Badge
              Watch(
                (context) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: settings.isShimmerLoading.value
                        ? const Color(0xFFC99A3D).withValues(alpha: 0.12)
                        : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: settings.isShimmerLoading.value
                          ? const Color(0xFFC99A3D).withValues(alpha: 0.3)
                          : Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        settings.isShimmerLoading.value
                            ? Icons.hourglass_top_rounded
                            : Icons.check_circle_outline,
                        size: 14,
                        color: settings.isShimmerLoading.value
                            ? const Color(0xFFC99A3D)
                            : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        settings.isShimmerLoading.value
                            ? 'shimmer_badge_active'.tr
                            : 'shimmer_badge_loaded'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: settings.isShimmerLoading.value
                              ? const Color(0xFFB07D2B)
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Live Interactive Adaptive Skeleton Preview Container
              Watch(
                (context) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.15),
                        ),
                        child: Icon(Icons.person, color: primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'shimmer_sample_name'.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'shimmer_sample_role'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.star_border, size: 20),
                      ),
                    ],
                  ).shimmer(enabled: settings.isShimmerLoading.value),
                ),
              ),
              const SizedBox(height: 12),
              // Micro Badges automatically skeletonized matching text and chips!
              Watch(
                (context) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '#AppForge'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '#Flutter'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC99A3D)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFC99A3D).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '#ZeroDependencies'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB07D2B),
                        ),
                      ),
                    ),
                  ],
                ).shimmer(enabled: settings.isShimmerLoading.value),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => settings.toggleShimmer(),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: Text('shimmer_btn_toggle'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Zero-Dependency In-Memory Cache Engine (AppCache) Card
        Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cached_rounded,
                      color: Color(0xFFC99A3D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'cache_card_title'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'cache_card_desc'.tr,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              // Live Cache Inspection Badges
              Watch((context) {
                // Read reactive trigger to rebuild on cache changes
                final _ = settings.cacheUpdateTrigger.value;
                final stats = App.cache.stats;
                final hitRatePercent = (stats.hitRate * 100).toStringAsFixed(1);

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(
                          alpha: isDark ? 0.2 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storage_rounded,
                            size: 14,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'cache_stats_badge'.trParams({
                              'size': '${stats.size}',
                              'capacity': '${stats.capacity}',
                            }),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC99A3D)
                            .withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFC99A3D).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.query_stats_rounded,
                            size: 14,
                            color: Color(0xFFC99A3D),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'cache_hit_rate'.trParams({'rate': hitRatePercent}),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB07D2B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(
                          alpha: isDark ? 0.2 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hits: ${stats.hits} | Misses: ${stats.misses}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 14),
              // Cache Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final hadKey = App.cache.has('demo_user_profile');
                        final value = await App.cache.getOrFetch<String>(
                          'demo_user_profile',
                          () async {
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                            return 'Dr. Sara Al-Thani';
                          },
                          ttl: const Duration(minutes: 5),
                        );
                        settings.notifyCacheChanged();

                        App.snackbar(
                          hadKey ? 'cache_hit_title'.tr : 'cache_miss_title'.tr,
                          hadKey
                              ? 'cache_hit_msg'.trParams({'key': value})
                              : 'cache_miss_msg'.tr,
                          type: hadKey
                              ? AppSnackbarType.success
                              : AppSnackbarType.info,
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        'cache_btn_fetch'.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final wasAlreadyCached = App.cache.has('coalesce_key');
                        var executionCount = 0;
                        final futures = List.generate(
                          3,
                          (_) => App.cache.getOrFetch<String>(
                            'coalesce_key',
                            () async {
                              executionCount++;
                              await Future.delayed(
                                const Duration(milliseconds: 400),
                              );
                              return 'Payload from single fetch';
                            },
                            ttl: const Duration(minutes: 5),
                          ),
                        );

                        await Future.wait(futures);
                        settings.notifyCacheChanged();

                        if (wasAlreadyCached) {
                          App.snackbar(
                            'cache_coalesce_title'.tr,
                            'cache_coalesce_all_hit'.tr,
                            type: AppSnackbarType.success,
                          );
                        } else {
                          App.snackbar(
                            'cache_coalesce_title'.tr,
                            'cache_coalesce_toast'.trParams({
                              'fetches': '$executionCount',
                              'hits': '${3 - executionCount}',
                            }),
                            type: AppSnackbarType.success,
                          );
                        }
                      },
                      icon: const Icon(Icons.alt_route_rounded, size: 16),
                      label: Text(
                        'cache_btn_coalesce'.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    App.cache.clear();
                    App.cache.resetStats();
                    settings.notifyCacheChanged();
                    App.snackbar(
                      'cache_cleared_title'.tr,
                      'cache_cleared_msg'.tr,
                      type: AppSnackbarType.info,
                    );
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text('cache_btn_clear'.tr),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Route Auto-Disposal Test Section
        Container(
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
              Row(
                children: [
                  const Icon(
                    Icons.auto_delete_outlined,
                    color: Color(0xFFC99A3D),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'dash_test_route_btn'.tr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'dash_route_hint'.tr,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Context-free push with directionality-aware slide transition
                    App.to(
                      const RouteDisposalScreen(),
                      transition: AppTransition.slide,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward).autoMirror(context),
                  label: Text('dash_test_route_btn'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Overlays & Context-Free Feedback Lab
        Container(
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
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFFC99A3D),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'overlays_lab_title'.tr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'overlays_lab_desc'.tr,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Row 1: Snackbars
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        App.snackbar(
                          'snackbar_success_title'.tr,
                          'snackbar_success_msg'.tr,
                          type: AppSnackbarType.success,
                        );
                      },
                      icon: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      label: Text(
                        'btn_snackbar_success'.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        side: BorderSide(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        App.snackbar(
                          'snackbar_error_title'.tr,
                          'snackbar_error_msg'.tr,
                          type: AppSnackbarType.error,
                        );
                      },
                      icon: const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                      label: Text(
                        'btn_snackbar_error'.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        side: BorderSide(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Dialog & BottomSheet
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        App.dialog(
                          AlertDialog(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: isDark ? Colors.white : primary,
                                ),
                                const SizedBox(width: 8),
                                Text('dialog_sample_title'.tr),
                              ],
                            ),
                            content: Text('dialog_sample_body'.tr),
                            actions: [
                              TextButton(
                                onPressed: () => App.back(),
                                child: Text('common_ok'.tr),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_in_picture, size: 18),
                      label: Text(
                        'btn_show_dialog'.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: onPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        App.bottomSheet(
                          Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.layers,
                                      color: Color(0xFFC99A3D),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'bottom_sheet_title'.tr,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'bottom_sheet_desc'.tr,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => App.back(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: onPrimary,
                                    ),
                                    child: Text('common_close'.tr),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.vertical_align_top, size: 18),
                      label: Text(
                        'btn_show_bottom_sheet'.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC99A3D),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 3: Global Loader
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    App.showLoading(message: 'loading_message'.tr);
                    Future.delayed(const Duration(seconds: 2), () {
                      App.hideLoading();
                    });
                  },
                  icon: const Icon(
                    Icons.hourglass_top,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                  label: Text(
                    'btn_show_loader'.tr,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                    ),
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

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
