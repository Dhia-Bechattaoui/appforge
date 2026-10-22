import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

import '../controllers/app_settings_controller.dart';

/// Interactive showcase demonstrating MasterApp root container features:
/// Responsive scaling (.w, .h, .sp, .r, .gapX, .gapY), dynamic theming,
/// breakpoints, and form validators.
class ResponsiveTab extends StatefulWidget {
  const ResponsiveTab({super.key});

  @override
  State<ResponsiveTab> createState() => _ResponsiveTabState();
}

class _ResponsiveTabState extends State<ResponsiveTab> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _numericController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _numericController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = App.find<AppSettingsController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Hero Header
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
                      Icons.aspect_ratio,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'responsive_title'.tr,
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
                'responsive_subtitle'.tr,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF10B981),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'masterapp_badge'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Real-Time Screen Metrics Card
        _buildCard(
          context: context,
          title: 'section_dimensions'.tr,
          icon: Icons.straighten,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'dim_width'.tr,
                      value: '${context.screenWidth.toStringAsFixed(1)} dp',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'dim_height'.tr,
                      value: '${context.screenHeight.toStringAsFixed(1)} dp',
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'dim_scale_w'.tr,
                      value:
                          '${AppResponsive.scaleWidth(1.0).toStringAsFixed(3)}x',
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'dim_scale_h'.tr,
                      value:
                          '${AppResponsive.scaleHeight(1.0).toStringAsFixed(3)}x',
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'dim_orientation'.tr,
                      value: context.isPortrait ? 'Portrait' : 'Landscape',
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'dim_status_bar'.tr,
                      value: '${context.statusBarHeight.toStringAsFixed(1)} dp',
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Adaptive Breakpoints Card
        _buildCard(
          context: context,
          title: 'section_breakpoints'.tr,
          icon: Icons.devices,
          child: Row(
            children: [
              Expanded(
                child: _buildBreakpointBadge(
                  label: 'bp_mobile'.tr,
                  isActive: context.isMobile,
                  icon: Icons.phone_iphone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakpointBadge(
                  label: 'bp_tablet'.tr,
                  isActive: context.isTablet,
                  icon: Icons.tablet_mac,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakpointBadge(
                  label: 'bp_desktop'.tr,
                  isActive: context.isDesktop,
                  icon: Icons.laptop_mac,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Visual Proportional Sizing (.w, .h, .sp, .r, .gapY, .gapX)
        _buildCard(
          context: context,
          title: 'section_scaling_demo'.tr,
          icon: Icons.photo_size_select_small,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 250.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC99A3D), Color(0xFFE2B755)],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC99A3D).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'scaling_demo_box'.tr,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        4.gapY,
                        Text(
                          'scaling_demo_text'.tr,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: (isDark ? Colors.white : primary).withValues(
                              alpha: 0.8,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              12.gapY,
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  '// Syntax:\n'
                  'Container(width: 250.w, height: 80.h, borderRadius: 16.r)\n'
                  'Text(\'Title\', style: TextStyle(fontSize: 13.sp))\n'
                  '4.gapY  // SizedBox(height: 4)',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 5. Dynamic Theme Controller & Color Scheme
        _buildCard(
          context: context,
          title: 'section_theme'.tr,
          icon: Icons.palette_outlined,
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: App.themeModeNotifier,
            builder: (context, activeMode, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildThemeChoice(
                          label: 'theme_system'.tr,
                          mode: ThemeMode.system,
                          selectedMode: activeMode,
                          icon: Icons.brightness_auto,
                          onTap: () => settings.setThemeMode(ThemeMode.system),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeChoice(
                          label: 'theme_light'.tr,
                          mode: ThemeMode.light,
                          selectedMode: activeMode,
                          icon: Icons.light_mode,
                          onTap: () => settings.setThemeMode(ThemeMode.light),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeChoice(
                          label: 'theme_dark'.tr,
                          mode: ThemeMode.dark,
                          selectedMode: activeMode,
                          icon: Icons.dark_mode,
                          onTap: () => settings.setThemeMode(ThemeMode.dark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'theme_active_mode'.trParams({
                                'mode': 'theme_${activeMode.name}'.tr,
                              }),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? Colors.indigo.withValues(alpha: 0.2)
                                : Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'theme_is_dark'.trParams({
                              'val': '${context.isDark}',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: context.isDark
                                  ? Colors.indigoAccent
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // 6. Form Validators & Context Extensions
        _buildCard(
          context: context,
          title: 'section_validators'.tr,
          icon: Icons.verified_user_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email validator
              Text(
                'val_email_label'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'val_email_hint'.tr,
                  suffixIcon: _emailController.text.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.all(10),
                          child: _buildValidationChip(
                            isValid: _emailController.text.isValidEmail,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Phone validator
              Text(
                'val_phone_label'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'val_phone_hint'.tr,
                  suffixIcon: _phoneController.text.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.all(10),
                          child: _buildValidationChip(
                            isValid: _phoneController.text.isValidPhone,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Dismiss keyboard helper button (context.unfocus)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.unfocus(),
                  icon: const Icon(Icons.keyboard_hide, size: 18),
                  label: Text('btn_unfocus'.tr),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : primary.withValues(alpha: 0.4),
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

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
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
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC99A3D), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakpointBadge({
    required String label,
    required bool isActive,
    required IconData icon,
  }) {
    final activeColor = isActive
        ? const Color(0xFF10B981)
        : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: activeColor, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? const Color(0xFF065F46) : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF10B981) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'IDLE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeChoice({
    required String label,
    required ThemeMode mode,
    required ThemeMode selectedMode,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == selectedMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : Colors.grey.shade600),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFE2E8F0)
                          : Colors.grey.shade800),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationChip({required bool isValid}) {
    final color = isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final icon = isValid ? Icons.check_circle : Icons.cancel;
    final text = isValid ? 'val_valid'.tr : 'val_invalid'.tr;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
