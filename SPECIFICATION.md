# AppForge Technical Specification

A zero-dependency micro-framework for Flutter providing state management, service location, context-free navigation, BiDi localization, dynamic theming, and responsive utilities.

---

## 1. Core Philosophy & Architectural Pillars

1. **Zero External Dependencies (`0 packages`)**:
   - Built strictly using pure Dart standard libraries (`dart:core`, `dart:async`, `dart:convert`, `dart:io`, `dart:ui`) and the core Flutter SDK (`flutter/material.dart`, `flutter/foundation.dart`).
   - Never breaks during Flutter major version upgrades.
   - Ultra-fast compilation times and near-zero binary footprint.
2. **Context-Free API**:
   - Navigation, dialogs, snackbars, and translations accessible without passing `BuildContext` across deep asynchronous calls.
3. **Safety & Zero Memory Leaks**:
   - Controller auto-disposal when screens pop.
   - Context safety guards preventing `"Looking up a deactivated widget's ancestor"` crashes.
4. **Flawless Arabic & BiDi Localization**:
   - Real bidirectional support, not just text alignment.
   - Preserves phone numbers with `+` prefixes, trailing punctuation, mixed Arabic/English text, and Arabic's 6 plural forms.
5. **Mobile-First Target (Android & iOS)**:
   - Optimized specifically for Android and iOS devices.
   - Built around mobile lifecycle, Safe Area insets (notches, dynamic islands, home bars), system back gestures, and virtual keyboard handling.

---

## 2. Master Feature Breakdown

### Module 1: True BiDi & Localization Engine
- **Dictionary Registry**:
  - Simple, in-memory Map structure: `Map<String, Map<String, String>>`.
  - Nested keys support: `'auth.login_button'.tr`.
- **Bidirectional (BiDi) Text Sanitization**:
  - Automatically isolates mixed-script texts using Unicode direction marks (`\u200E` LRM, `\u200F` RLM, `\u202A` LRE, `\u202C` PDF).
  - Phone Number formatting: `'+974 5500 1234'.asPhone` or `.forceLtr` to prevent inverted signs.
  - Punctuation fixer: Stops `!` or `.` from jumping to the opposite end in mixed Arabic/English sentences.
- **6-Level Arabic Pluralization**:
  - Supports English (`one`, `other`) and Arabic grammatical plural forms (`zero`, `one`, `two / مثنى`, `few / جمع قلة`, `many`, `other`).
- **Dynamic Language Switch & Instant Hot Reload**:
  - Change language on the fly (`App.setLocale('ar')`) with immediate reactive UI rebuild across all screens without app restart.
  - **Instant Hot-Reload Updates (0ms Live Updates)**: Unlike legacy frameworks that cache dictionaries into immutable singletons on boot (requiring a full app restart whenever strings are edited), AppForge dynamically evaluates dictionaries on every build pass. Code changes to `AppTranslations` reflect immediately during Flutter Hot Reload with zero restart and zero loss of navigation state.
  - **Ultra-Lightweight & Fast**: Pure Dart in-memory maps eliminate JSON asset I/O, reflection, and `build_runner`/`intl` compilation overhead.

---

### Module 2: Micro Service Locator & Dependency Injection
- **Registration**:
  - `App.put<T>(T instance)`: Registers a singleton instance in memory.
  - `App.lazyPut<T>(T Function() factory)`: Instantiates the service only upon first call.
- **Retrieval**:
  - `final auth = App.find<AuthService>();`
- **Lifecycle & Auto-Disposal**:
  - Bind controllers to routes: When a route is popped, any controller marked `autoDispose: true` is automatically disposed, preventing memory leaks.

---

### Module 3: Reactive State Engine
- **Primitives**:
  - `Rx<T>` wrapper (e.g., `0.obs`, `'text'.obs`, `false.obs`).
  - Automatic notification dispatching on `.value` change.
- **Reactive UI Rebuilder (`Watch` / `Obx`)**:
  - Minimal rebuild footprint: Only re-renders the exact child widget subscribed to the reactive variable, avoiding full screen rebuilds.
- **Controller Base Class**:
  - `AppController` with `onInit()`, `onReady()`, and `onClose()` lifecycle hooks.

---

### Module 4: Context-Free Navigation & Overlay System
- **Routing**:
  - `App.to(Screen())`: Push new route.
  - `App.off(Screen())`: Replace current route.
  - `App.offAll(Screen())`: Clear entire stack and navigate (e.g., logout or onboarding completion).
  - `App.back([result])`: Pop current screen with optional return data.
- **Feedback & Overlays**:
  - `App.snackbar(title, message, {type: Success/Error/Warning})`.
  - `App.dialog(Widget child, {barrierDismissible})`.
  - `App.bottomSheet(Widget child)`.
  - `App.showLoading()` / `App.hideLoading()`: Global backdrop spinner for async API calls.

---

### Module 5: Dynamic Theming Engine
- **Theme Modes**:
  - Support for `ThemeMode.light`, `ThemeMode.dark`, and `ThemeMode.system`.
  - Instant theme toggle: `App.toggleTheme()` or `App.setThemeMode(...)`.
- **Context Shortcuts**:
  - `context.isDark`
  - `context.theme`
  - `context.colorScheme`
  - `context.primaryColor`, `context.cardColor`, `context.scaffoldBackgroundColor`
- **Custom Token Extension**:
  - Ability to register custom brand palettes (e.g. Navy, Gold, Obsidian) directly into the theme system.

---

### Module 6: Screen Sizing & Responsive Utilities
- **Adaptive Sizing Scale**:
  - Built against a customizable design reference (default: 390x844 or custom).
  - Extensions: `16.w` (width scale), `24.h` (height scale), `14.sp` (font scale), `12.r` (radius scale).
- **Spacing Widgets**:
  - `16.gapY` -> `SizedBox(height: 16)`
  - `12.gapX` -> `SizedBox(width: 12)`
- **Device Form Factor**:
  - `context.isMobile`, `context.isTablet`, `context.isDesktop`.
  - `context.screenWidth`, `context.screenHeight`.

---

### Module 7: Form Validation & Common String Extensions
- **Built-in Regex Validators**:
  - `value.isValidEmail`
  - `value.isValidPhone`
  - `value.hasMinLength(int)`
  - `value.isNumeric`
- **Text Utilities**:
  - `value.capitalizeFirst`
  - `value.toArabicDigits` (Converts `123` to `١٢٣`)

---

### Module 8: Translation Cleaner & Resource Auditor
- **Dead Key Detection**:
  - Scans project codebase for translation keys used with `.tr`, `.trParams`, and `.trPlural`.
  - Flags unused keys defined in `AppTranslations` that bloat memory.
- **Cross-Locale Consistency**:
  - Detects missing keys between languages (e.g., key exists in English but missing in Arabic).
  - Highlights empty or untranslated string values.
- **CLI & Runtime Audit**:
  - Runtime method: `App.auditTranslations()` returning a structured `AppAuditReport`.
  - Command-line runner: `dart run appforge:clean` to analyze and optionally prune dead keys.

---

### Module 9: Root App Container (`MasterApp`)
- A single, clean wrapper replacing boilerplate `MaterialApp`:
  ```dart
  void main() {
    runApp(
      MasterApp(
        title: 'My App',
        initialRoute: const SplashScreen(),
        translations: AppTranslations(),
        fallbackLocale: const Locale('en'),
        initialLocale: const Locale('ar'),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        designSize: const Size(390, 844),
      ),
    );
  }
  ```

---

## 3. Package File Structure

```
appforge/
├── README.md                 <-- Public documentation
├── SPECIFICATION.md          <-- Technical architecture specification
├── AGENTS.md                 <-- Engineering standards and deprecation rules
├── CHANGELOG.md              <-- Release log
├── lib/
│   ├── appforge.dart         <-- Primary export barrel
│   ├── src/
│   │   ├── core/
│   │   │   ├── app.dart              <-- Global state & navigator registry
│   │   │   ├── master_app.dart       <-- Root widget
│   │   │   └── controller.dart       <-- Base AppController with lifecycle
│   │   ├── state/
│   │   │   ├── locator.dart          <-- Dependency Injection container
│   │   │   ├── rx.dart               <-- Reactive primitives (0.obs, Rx<T>)
│   │   │   └── watch.dart            <-- Micro reactive builder widget
│   │   ├── localization/
│   │   │   ├── translations.dart     <-- Dictionary container
│   │   │   ├── bidi_utils.dart       <-- Unicode LTR/RTL sanitization & phone helpers
│   │   │   ├── plurals.dart          <-- 6-form Arabic & multi-language plural engine
│   │   │   └── tr_extension.dart     <-- String extensions (.tr, .trParams)
│   │   ├── theme/
│   │   │   └── theme_manager.dart    <-- Light/Dark/System manager
│   │   ├── navigation/
│   │   │   ├── navigator.dart        <-- Context-free navigation methods
│   │   │   └── overlays.dart         <-- Snackbars, dialogs, bottom sheets, loading
│   │   ├── responsive/
│   │   │   ├── responsive_scaler.dart<-- Screen dimension scaler
│   │   │   └── responsive_ext.dart   <-- .w, .h, .sp, .r, .gapX, .gapY
│   │   ├── cleaner/
│   │   │   ├── audit_report.dart     <-- Missing & unused key report model
│   │   │   └── cleaner.dart          <-- Codebase scanner and translation pruner
│   │   └── utils/
│   │       ├── validators.dart       <-- Form field validation rules
│   │       └── context_ext.dart      <-- Clean context shortcuts
└── test/
    ├── localization_test.dart
    ├── state_test.dart
    ├── navigation_test.dart
    └── cleaner_test.dart
```

---

## 4. Execution Plan (Step-by-Step)

- [x] **Step 1: Setup Dart Package Manifest** (`pubspec.yaml` with 0 external packages).
- [x] **Step 2: BiDi & Translation Engine** (Dictionary, Unicode BiDi isolate, 6-case Arabic pluralization, `.tr` extensions).
- [x] **Step 3: Service Locator & Reactive State** (`App.put()`, `App.lazyPut()`, `App.putAsync()`, `App.find()`, `Rx<T>`, `Watch` widget, `UiState<T>`, `AppBind`, auto-disposal).
- [x] **Step 4: Context-Free Navigation & Overlays** (`App.to()`, `App.back()`, `App.snackbar()`, `App.showLoading()`).
- [x] **Step 5: Dynamic Theme & Responsive Scaler** (`App.toggleTheme()`, `.w`, `.h`, `.sp`, `.gapX`, `.gapY`).
- [x] **Step 6: MasterApp Root Container** (Unifies routing, locale, theme, and responsiveness into 1 root widget).
- [x] **Step 7: Resource Cleaner & Auditor** (Static and runtime scanner to detect and prune unused/missing keys).
- [x] **Step 8: Unit Testing & Verification** (Comprehensive test suite verifying pure Dart execution).
- [x] **Step 9: Arabic Diacritics, Autocorrect, Pronoun Inflection & Orthography Engine** (`stripTashkeel`, `formatArabic`, `inflectArabicGender`).
- [x] **Step 10: Zero-Dependency Network Reachability Monitor** (`AppConnectivity`, `App.isOnline`, `checkConnectivity`).
- [x] **Step 11: Zero-Dependency Crash-Immune Storage Engine** (`AppStorage`, atomic swap, `persistLocale`, `persistTheme`).
- [x] **Step 12: Zero-Dependency Theme Harmonizer & Contrast Engine** (`AppThemeHarmonizer`, `harmonizeTheme: true`, WCAG AA).
- [x] **Step 13: Zero-Dependency Environment Configuration Loader** (`AppEnv`, `${VAR}` interpolation, secret masking).
- [x] **Step 14: Zero-Dependency Skeleton Shimmer Engine** (`AppShimmer`, `.shimmer()` automatic layout matching, GPU-accelerated presets, auto-RTL sweep).
- [x] **Step 15: Zero-Dependency In-Memory Memory Cache & Eviction Engine** (`AppCache`, LRU/LFU/FIFO, TTL expiration, single-flight request coalescing).

### Audit Remediation (v0.12.0) — see codebase audit
- [x] **R1: State Engine Integrity** (Watch subscription leak, identity-based `Rx` equality, typed listener resolution, listener error isolation, build-phase-safe rebuilds).
- [x] **R2: Storage Durability** (copy-on-read, write validation, async atomic write queue, flush on pause, iOS Application Support).
- [x] **R3: Navigation & Locator Lifecycle** (route-scoped `AppBind` instances, observer-driven `App.arguments`, route-bound loading overlay).
- [x] **R4: Responsive & Theme** (`.sp` single text scaling, metric-driven rebuilds, memoized derived themes, `themeMode` as initial value).
- [x] **R5: Hot-Path Performance** (`.tr` pipeline snapshot + memoization, cached skeleton geometry, literal token auto-bypass, precompiled regexes).
- [x] **R6: Connectivity, Env & Cache Hardening** (lifecycle-aware connectivity polling, parallel candidate host racing, in-flight check deduplication, POSIX single-quote & CRLF env parsing, monotonic Stopwatch TTL cache, generation-guarded clears).
- [x] **R7: Deprecated API Removal & Cleanup** (removal of deprecated `MasterApp.smartTheme` and `AppSmartTheme`, strongly typed `initialRoute` and `auditDictionary`, precompiled RegExps with Arabic-Indic digit validation, CLDR fractional/negative plural fixes, `AppLifecycleManager` re-instantiation).
- [x] **R8: Release 0.12.0** (version bump to 0.12.0, complete audit remediation, finalized changelog & migration guide).

