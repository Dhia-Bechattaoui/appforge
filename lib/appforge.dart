/// AppForge: A lightweight, zero-dependency Flutter micro-framework.
library;

// Core
export 'src/core/app.dart';
export 'src/core/lifecycle.dart';
export 'src/core/master_app.dart';
export 'src/config/env.dart';

// UI & Animations
export 'src/ui/shimmer.dart';

// Localization & BiDi
export 'src/localization/arabic_utils.dart';
export 'src/localization/bidi_utils.dart';
export 'src/localization/common_translations.dart';
export 'src/localization/directional_icon.dart';
export 'src/localization/gender.dart';
export 'src/localization/localizations_delegate.dart';
export 'src/localization/orthography.dart';
export 'src/localization/plurals.dart';
export 'src/localization/text_formatter.dart';
export 'src/localization/translations.dart';
export 'src/localization/tr_extension.dart';

// State Management & Service Locator
export 'src/state/locator.dart';
export 'src/state/rx.dart';
export 'src/state/ui_state.dart';
export 'src/state/watch.dart';

// Context-Free Navigation & Overlays
export 'src/navigation/navigator.dart';
export 'src/navigation/overlays.dart';
export 'src/navigation/transitions.dart';

// Dynamic Theming
export 'src/theme/theme_extensions.dart';
export 'src/theme/theme_harmonizer.dart';
export 'src/theme/theme_manager.dart';

// Responsive Scaling & Metrics
export 'src/responsive/responsive_ext.dart';
export 'src/responsive/responsive_scaler.dart';

// Persistent Storage Engine
export 'src/storage/storage.dart';

// In-Memory Cache Engine
export 'src/cache/cache.dart';

// Utilities & Shorthands
export 'src/utils/connectivity.dart';
export 'src/utils/context_ext.dart';
export 'src/utils/validators.dart';

// Resource Cleaner & Project Auditor
export 'src/cleaner/asset_auditor.dart';
export 'src/cleaner/audit_report.dart';
export 'src/cleaner/file_auditor.dart';
export 'src/cleaner/revert_manager.dart';
export 'src/cleaner/translation_auditor.dart';
