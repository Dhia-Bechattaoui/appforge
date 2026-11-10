# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-11-10

### Added
- **Built-In Manual State Rebuilds (`AppBuilder<T>` & `AppController.update`)**:
  - Added [`AppBuilder<T>`](lib/src/state/app_builder.dart) with `init`, `create`, `tag`, granular `id` filtering, `global: false` local controllers, `autoRemove`, `initState`/`dispose` hooks, and automatic post-frame deferral when `update()` is invoked mid-build (`SchedulerPhase.persistentCallbacks`).
  - Implemented [`AppController.update([List<Object>? ids, bool condition = true])`](lib/src/state/locator.dart) alongside `addListener`, `removeListener`, `addIdListener`, and `removeIdListener` with error-isolated snapshot dispatch and automatic listener cleanup in `onClose()`.
- **Safe Service Locator Helpers (`App.putIfAbsent` & `App.findOrNull`)**:
  - Added `App.putIfAbsent<T>(builder, ...)` to avoid instantiating redundant objects when a dependency is already registered.
  - Added `App.findOrNull<T>()` to safely resolve optional dependencies without throwing `StateError`.
- **Single-Shot Reactive Worker (`once`)**:
  - Added `once<T>(listener, callback)` in [`rx.dart`](lib/src/state/rx.dart) alongside `ever`, `everAll`, `debounce`, and `interval` to invoke a side-effect once on the first change and auto-cancel.

### Changed
- **Idempotent Dependency Registration (`App.put` / `AppLocator.put`)**:
  - `App.put<T>` now defaults to `replace: false` (preserving existing registered singletons and materializing pending `App.lazyPut` factories instead of overwriting populated controllers). Pass `replace: true` to force disposal and replacement.
  - Added `replace: false` protection to `App.lazyPut` and `App.putAsync` so `permanent: true` registrations are preserved unless explicitly replaced.

## [0.4.2] - 2026-11-09

### Fixed
- **Arabic Sub-Baseline Descender & Nuqat Masking (`AppShimmer`)**:
  - **Sub-Baseline Nuqat Coverage**: Fixed terminal Arabic characters with sub-baseline dots (such as Yāʼ *نقطتي الياء `ي`*, Jīm *`ج`*, and Kasrah diacritics *`ـِ`*) previously leaking out below the skeleton mask because Arabic calligraphic descenders extend 4–8px below standard typographic selection line boxes.
  - **Adaptive Vertical Inflation**: Replaced rigid `2.0px` uniform inflation with script-aware padding: when Arabic text is detected, `maskRect` applies an adaptive bottom margin (`lineRect.height * 0.35`, clamped to 6.0–10.0px) and `4.0px` top margin, completely blanking out all upper diacritics (*الشدة، الفتحة، الضمة*) and lower dots without altering line-bone positioning.

## [0.4.1] - 2026-11-06

### Fixed
- **Curved Surface & Circular Skeleton Masking (`AppShimmer`)**:
  - **Oval Surface Mask Matching**: Fixed circular elements (`BoxDecoration(shape: BoxShape.circle)`, `ShapeDecoration(shape: CircleBorder())`, `ClipOval`, and circular `PhysicalModel`) previously recording rectangular bounding box masks (`addRect`), which caused tinted square backgrounds (e.g. primary orange or light amber) to visually bleed out around circular avatars, camera badges, and circular notification icon containers. Surface masks for circular nodes are now recorded as exact matching ovals (`addOval`), strictly confining mask ink to the circular boundary.
  - **Rounded Icon Masking**: Enhanced icon masking to use proportional rounded rectangles (`addRRect`) matching the emitted icon bone geometry rather than sharp 90-degree rectangular bounds.
  - **Clipping AST Geometry (`RenderClipOval` & `RenderClipRRect`)**: Extended `_shapeOf` AST analysis to extract matching oval and rounded rectangle paths for clipped subtree roots.

## [0.4.0] - 2026-11-06

### Added
- **Typography-Adaptive Skeleton Shimmer Engine (`AppShimmer`)**:
  - **Cap-Height Line Bone Deflation**: Skeleton line bones are centered vertically within typographic line boxes at glyph cap-height (`62%` line factor). Preserves natural inter-line whitespace so closely stacked multi-line `Text` widgets maintain visual separation without fusing into solid blocks.
  - **Surface-Aware Text Masking (Zero Ghosting)**: Introduced host container surface color detection (`_surfaceColorOf`) supporting `BoxDecoration`, `Card`, `LinearGradient`, and `PhysicalModel`.
  - **Recursive Opaque Alpha-Blending (`_resolveSurfaceColor`)**: Blends semi-transparent surfaces (`color.a < 1.0`, such as 12% tinted banner containers or 10% badges) over parent backdrops into 100% opaque mask paths. Completely obliterates underlying styled text glyphs and icon ink with the exact native surface hue before sweeping the gradient shader.
  - **BiDi Multi-Span Line Coalescing**: Adjacent Arabic and numeral selection segments sharing the same horizontal baseline coalesce into unified, cohesive line rectangles.
  - **Overflow Ellipsis Blanketing**: Added `didExceedMaxLines` detection to extend masks across the overflow region, blanking out trailing `...` ellipsis ink.
  - **Subpixel Antialiasing & Diacritics Inset**: Added `2.0px` mask inflation to cover Arabic diacritics, dots (nuqats), and subpixel antialiasing fringes.

## [0.3.0] - 2026-11-05

### Added
- **Pure-Dart CLI Decoupling (`appforge:clean`)**:
  - Decoupled `AppTranslations` base contract into dedicated `lib/src/localization/app_translations.dart` with zero `dart:ui` / Flutter SDK dependencies, enabling `dart run appforge:clean` to run standalone in pure Dart environments and CI/CD pipelines without `dart:ui` availability errors.
  - Added `AppTranslationsLocalesExtension` preserving backwards-compatible `.supportedLocales` resolution for Flutter applications with zero breaking changes.
  - Relocated literal token heuristics (`isLiteralToken`) to `AppTranslations` to allow static CLI evaluation of URLs, phone numbers, and handles without Flutter engine dependencies.
- **Font & Asset Manifest Preservation (`AppAssetAuditor`)**:
  - Integrated `pubspec.yaml` manifest scanning into `AppAssetAuditor` to guarantee declared fonts and configuration assets are preserved and never incorrectly flagged as unreferenced assets during audits.
- **Enhanced Translation Discovery & AST Pruning (`AppTranslationAuditor`)**:
  - Added strict heuristics for JSON translation files to filter out configuration files (e.g. `firebase.json`, `package.json`, `tsconfig.json`).
  - Improved multi-line map entry pruning in Dart translation files with robust comma, semicolon, and brace boundary tracking.
- **Trash & Backup Isolation**:
  - Added global exclusion of `.appforge_trash` across `AppTranslationAuditor`, `AppAssetAuditor`, and `AppFileAuditor` to prevent previous backup revisions from interfering with active project scans.

## [0.2.0] - 2026-11-05

### Added
- **Reactive Collections & Typed Observers (`RxList`, `RxMap`, `RxSet`, `Rxn`)**: First-class zero-dependency reactive collection types implementing standard `List`, `Map`, and `Set` with automatic dependency registration in `Watch` and fine-grained mutation notification (`assignAll`, `assign`, `add`, `remove`, `clear`).
- **Reactive Workers (`Worker`, `ever`, `everAll`, `debounce`, `interval`)**: Lifecycle-managed workers to execute side-effects on reactive value updates with native cancellation, debouncing, and throttling support.
- **Stream Binding (`bindStream`)**: Added `bindStream(Stream<T>)` directly on `Rx<T>` and reactive collections for non-blocking asynchronous data stream synchronization.
- **Service & View Architectural Bases (`AppService`, `AppView<T>`, `AppBindings`, `BindingsBuilder`)**:
  - `AppService`: Dedicated base class for long-lived application singletons and background services.
  - `AppView<T>`: Ergonomic base `StatelessWidget` providing typed `controller` access via `AppLocator`.
  - `AppBindings` & `BindingsBuilder`: Modular dependency injection declaration contracts for route bindings.
- **Collection & Iterable Functional Extensions**:
  - `AppListExtension<E>`: Added `assignAll`, `assign`, and `firstWhereOrNull` on standard Dart `List<E>`.
  - `AppIterableExtension<E>`: Added `firstWhereOrNull` on standard Dart `Iterable<E>`.
- **Reactive Type Aliases**: Added `RxBool`, `RxInt`, `RxDouble`, `RxString`, `RxnString`, `RxnBool`, `RxnInt`, and `RxnDouble`.
- **Named Route Navigation (`App.toNamed`, `App.offNamed`, `App.offAllNamed`, `AppPage`)**:
  - Context-free named navigation methods on `AppNavigator` and `App` facade.
  - Declarative route registration via `AppPage<T>`.
  - Route duplicate prevention via `preventDuplicates` parameter on `toNamed`.
  - `fullscreenDialog` support across all route transition styles.
  - Dynamic arguments resolution (`dynamic get arguments`).
- **Cryptographic UUID v4 Generator (`App.uuid()`)**: Zero-dependency RFC 4122 v4 UUID generator using `math.Random.secure()`.
- **Enhanced Overlay Customization (`App.snackbar`)**:
  - Trailing action widget support via `mainButton`.
  - Custom floating inset via `margin`.
  - Custom corner styling via `borderRadius`.
  - Directional alignment via `snackPosition` (`top`, `bottom`).
- **Runtime Localization Enhancements**:
  - Added `App.translations` static setter for dynamic translation dictionary initialization.
  - Added asynchronous `App.updateLocale(ui.Locale)` returning `Future<void>`.

## [0.1.0] - 2026-11-05

### Added
- **Screen Fraction Responsive Extensions (`.sw`, `.sh`)**: Added `.sw` (screen width fraction, e.g. `0.8.sw`) and `.sh` (screen height fraction, e.g. `0.5.sh`) directly on `num` via `AppResponsiveNumExtension` for ergonomic percentage-based responsive layouts.
- **Modular Sub-Library Exports**: Added granular library entry points to allow selective imports and prevent namespace collisions (e.g. `.tr`, `.obs`, `Rx<T>`) when integrated into projects using third-party state managers like GetX, Bloc, or Riverpod:
  - `package:appforge/responsive.dart`: Responsive scaling (`.w`, `.h`, `.sp`, `.r`, `.sw`, `.sh`, `.gapX`, `.gapY`) and `AppResponsive`.
  - `package:appforge/storage.dart`: `AppStorage` atomic crash-immune storage engine.
  - `package:appforge/ui.dart`: Shimmer effects and context-free overlays.
  - `package:appforge/navigation.dart`: Context-free routing and transitions.
  - `package:appforge/theme.dart`: Dynamic theming, WCAG AA harmonizer, and contrast utilities.
  - `package:appforge/localization.dart`: BiDi isolation, Arabic grammar, plurals, and `.tr` extensions.
  - `package:appforge/state.dart`: `Rx<T>`, `Watch`, `UiState`, and `AppLocator`.
  - `package:appforge/config.dart`: POSIX `.env` parser and environment manager.
  - `package:appforge/utils.dart`: Network connectivity, context extensions, and validators.

## [0.0.2] - 2026-10-23

### Added
- **Surface-Aware Skeleton Compositor (`AppShimmer`)**: Structural host surfaces (`Card`, `Material`, decorated / bordered `Container`s, elevation, shadows) remain fully visible and styled during shimmer loading, while text lines, icons, and leaf content are concealed by matching skeleton bones.
- **Loading Gesture Absorption**: Automatically absorbs pointer click events on shimmering child elements to prevent accidental button taps or input activation while loading.

### Improved
- **Theme-Derived Shimmer Tones**: Ambient base and highlight colors are automatically blended against `colorScheme.surface` and `onSurface` across Material 2 and Material 3 for optimal contrast and zero content bleed.
- **Glyph Concealment**: Uses `DefaultTextStyle.merge` and `IconTheme.merge` with transparent ink during shimmer to preserve exact typography bounds and line breaks without sub-pixel font bleed.

### Fixed
- **Phone Number BiDi Isolation (`AppBidi.isolateMixed`)**: Phone numbers embedded within Arabic text (e.g. `رقم الهاتف: +974 5500 1234`) were being split into separate LRI-isolated segments (`⁦+974⁩ 5500 1234`), leaving trailing digit groups as neutral-direction characters that the Unicode BiDi algorithm reordered in RTL contexts, visually producing `974+` instead of `+974`. The entire `+NNN NNNN NNNN` sequence is now consumed as a single LRI-isolated block (`⁦+974 5500 1234⁩`).
- **Hot Reload Translation Refresh (`MasterApp`)**: Editing translation strings no longer requires a full app restart. `_MasterAppState.reassemble()` now re-snapshots the `AppTranslations.keys` getter and clears the static lookup cache on every hot reload, so modified dictionary values are reflected instantly.

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
