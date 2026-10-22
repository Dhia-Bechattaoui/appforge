# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-10-22

Initial production release of **AppForge**, an all-in-one Flutter micro-framework engineered from first principles with **strictly zero external dependencies** (`0 dependencies`).

### Added

#### 1. Reactive State Management & Dependency Injection
- **`Rx<T>` Reactive Primitives**: Observable wrapper (`0.obs`, `'hello'.obs`, `[].obs`) with identity-based equality, mid-build deferred mutation scheduling, and typed listener resolution (`listen`, `listenPrev`, `update`).
- **`Watch` Surgical Rebuilder**: Rebuilds only atomic leaf widgets reading `.value` without rebuilding parent widget trees. Automatically manages subscription lifecycles on route disposal and conditional branching.
- **`Watch.listen`**: Side-effect handler triggered on value changes without rebuilding the child widget tree.
- **`Watch.state` & `UiState<T>`**: Strongly-typed sealed state container (`idle`, `loading`, `success`, `failure`) with exhaustive matching and localized default views.
- **`AppLocator` Service Container**: Fast, memory-safe dependency locator (`App.put`, `App.lazyPut`, `App.putAsync`, `App.find`, `App.delete`).
- **`AppBind` Route Scope**: Declarative controller binding with instance stacking for nested routes and automatic controller disposal upon route unmount.

#### 2. Context-Free Navigation & Overlays
- **`AppNavigator`**: Complete context-free routing (`App.to`, `App.off`, `App.offAll`, `App.back`) backed by native `NavigatorState`.
- **`App.arguments`**: Tracks Flutter's route stack via `NavigatorObserver`, preserving page arguments across modal dialogs and system back gestures.
- **Context-Free Overlays (`AppOverlay`)**:
  - `App.snackbar()`: Floating snackbar with contextual icons and semantic styling.
  - `App.dialog()`: Modal alerts and confirmation dialogs.
  - `App.bottomSheet()`: Modal bottom sheets.
  - `App.showLoading()` / `App.hideLoading()`: Route-isolated loading dialogs that dismiss without popping overlying alerts.

#### 3. BiDi & Arabic Localization Engine
- **`.tr` / `.trParams` / `.trPlural` / `.trGender`**: Zero-boilerplate string translation with in-memory memoization (O(1) lookups).
- **Unicode UAX #9 Directional Isolation**: Automatically isolates phone numbers (`+974...`), hashtags (`#tag`), handles (`@user`), URLs, and mixed Latin tokens inside RTL layouts to prevent punctuation and symbol inversion.
- **6-Form Arabic CLDR Plurals**: Full grammatical support for `zero`, `one`, `two` (مثنى), `few` (جمع قلة), `many` (تمييز منصوب), and `other`, with strict CLDR decimal and negative number classification.
- **Arabic Grammar & Inflection**: 2nd-person pronoun inflection (`كَ` vs `كِ`), 11-category grammatical gender classifier (`arabicGender`), and gender morphology adaptation.
- **Arabic Orthography & Autocorrect**: Diacritic stripping (`stripTashkeel`), Kashida removal (`stripTatweel`), punctuation correction, Waw spacing normalization, and QWERTY-to-Arabic mistyping conversion.
- **`ArabicTextInputFormatter`**: Real-time Word/Gboard style text formatting for Arabic text fields.

#### 4. Dynamic Theming & Contrast Harmonizer
- **`MasterApp` Root Widget**: Reactive top-level container binding locale, theme mode, and responsive screen metrics.
- **`AppThemeManager`**: Instant runtime theme switching (`App.setThemeMode`, `App.toggleTheme`, `context.isDark`).
- **`AppThemeHarmonizer`**: Single-theme derivation that automatically generates contrast-safe dark themes from light themes (or vice-versa) with zero manual color tokens.
- **W3C WCAG AA Compliance**: Relative luminance and contrast ratio calculation (`contrastRatio`, `hasAccessibleContrast`, `ensureContrast`).

#### 5. Responsive Design Scaling
- **`AppResponsive`**: Baseline screen scaler with geometric proportional scaling (`.w`, `.h`, `.r`, `.gapX`, `.gapY`).
- **Single Text Scaling (`.sp`)**: Scales with design geometry by default without double-multiplying system accessibility `textScaleFactor`. Optional `maxScale` clamping.
- **Context-Bound Extensions**: `context.w()`, `context.h()`, `context.r()`, `context.sp()` subscribe calling widgets to `MediaQuery` metric and orientation changes.

#### 6. Atomic Crash-Immune Storage (`AppStorage`)
- **Memory-Fast Reads & Atomic Writes**: 0ms synchronous RAM reads backed by serialized asynchronous disk writes via atomic POSIX file replacement and `fsync`.
- **Copy-on-Read / Copy-on-Write**: Returned collections are deep-copied to prevent accidental RAM mutation or disk desynchronization.
- **Fail-Fast Type Validation**: Rejects non-JSON objects immediately at write time to guarantee disk integrity.
- **Lifecycle Background Auto-Flush**: Hooked to `AppLifecycleManager` to flush pending writes synchronously when backgrounded.
- **Apple Sandbox Compliance**: Stored in iOS `Library/Application Support` with automatic migration from legacy `Documents` files.
- **`MasterApp(persistLocale: true, persistTheme: true)`**: Zero-boilerplate automatic persistence.

#### 7. Network Connectivity Monitor (`AppConnectivity`)
- **Reactive Internet Reachability**: Real internet ping (`App.isOnline`, `App.checkConnectivity`) using parallel socket racing to candidate DNS hosts (`1.1.1.1` and `8.8.8.8`).
- **In-Flight Future Deduplication**: Concurrent checks share a single active socket probe.
- **Lifecycle-Aware Monitoring**: Automatically pauses polling in background states to prevent battery drain and resumes immediately on return.

#### 8. Environment Configuration (`AppEnv`)
- **POSIX & RFC Compliant `.env` Loader**: Full in-string variable interpolation (`${VAR}`), CRLF line ending normalization, and strict bash single-quote literal support.
- **Safe Secret Masking**: Masks sensitive keys (passwords, tokens, secrets) in logs and debugging summaries.

#### 9. High-Performance In-Memory Cache (`AppCache`)
- **Configurable Eviction Policies**: LRU (Least Recently Used), LFU (Least Frequently Used), and FIFO (First In First Out) eviction algorithms with isolated named buckets.
- **Monotonic Clock Expiration**: TTL expiration calculations use monotonic `Stopwatch` microseconds, immune to system clock tampering, timezone shifts, and NTP jumps.
- **Atomic Cache-Aside with Single-Flight Coalescing**: Concurrent requests for the same missing key join a single shared fetch execution, eliminating duplicate backend queries.
- **Generation-Guarded Clears**: Background network fetches started prior to `clear()` never resurrect stale data into an emptied bucket.

#### 10. GPU-Accelerated Skeleton Shimmer Engine (`AppShimmer`)
- **Layout-Adaptive Shimmer (`widget.shimmer()`)**: Wraps real UI trees and automatically derives skeleton geometry without manual bone layouts.
- **60–120Hz Animation Path Caching**: Extracts and caches render-tree paths once, animating sweeps via translated canvas operations without per-frame tree walks or glyph measurements.
- **BiDi Automatic Reading-Direction**: Sweeps right-to-left in RTL / Arabic layouts and left-to-right in LTR.
- **Pre-Built Presets**: `AppShimmer.box`, `AppShimmer.circle`, `AppShimmer.text`, `AppShimmer.listTile`, `AppShimmer.card`.

#### 11. Resource Cleaner & Auditor
- **Dead Translation & Gap Auditor (`AppTranslationAuditor`)**: Detects missing translations across locales, empty strings, and dead translation keys.
- **Asset & File Auditor**: Identifies unused assets in `assets/` and orphaned `.dart` files in `lib/`.
- **One-Command CLI**: `dart run appforge:clean`, `dart run appforge:clean --fix` (with automatic revert manifest backup), and `dart run appforge:clean --revert`.
