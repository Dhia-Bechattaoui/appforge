# Agent Guidelines: AppForge Framework

This repository contains the source code for AppForge, an all-in-one Flutter micro-framework built with **zero external dependencies**. Every agent working on this repository must strictly adhere to the rules, workflow, and engineering standards defined below.

---

## 1. Absolute Constraints (Non-Negotiable)

1. **0 External Packages (`0 dependencies`)**:
   - `pubspec.yaml` must **NEVER** include third-party dependencies (e.g., no `get`, no `provider`, no `dio`, no `intl`, no `flutter_screenutil`, no `shared_preferences`).
   - Use only:
     - Dart standard library: `dart:core`, `dart:async`, `dart:convert`, `dart:io`, `dart:ui`, `dart:math`.
     - Flutter SDK: `package:flutter/material.dart`, `package:flutter/foundation.dart`, `package:flutter/services.dart`.
2. **Context-Free Navigation & Overlays**:
   - Navigation, snackbars, dialogs, and loaders must work without requiring a `BuildContext` parameter across async callbacks.
3. **Memory Safety & Lifecycle Integrity**:
   - Never leak controllers. Controllers bound to a screen must auto-dispose when the route is removed from the navigation stack.
   - Guard against `"Looking up a deactivated widget's ancestor"` errors.
4. **Specification Alignment**:
   - Always refer to `SPECIFICATION.md` for architecture decisions, naming, and module structure.
5. **Platform Focus (Android & iOS)**:
   - Primary focus is strictly mobile (Android and iOS).
   - Prioritize mobile-specific behaviors: system back gesture/button handling, Safe Area/notch/dynamic island insets, touch responsiveness, and virtual keyboard adjustments. Web and desktop considerations are out of scope for now.

---

## 2. Arabic & BiDi (Bidirectional) Standards

When implementing or modifying localization and text formatting:
1. **Phone Numbers & Symbols**:
   - Phone numbers (e.g., `+974 5500 1234`) and symbol-prefixed strings must be isolated using Unicode direction marks (LRM `\u200E`, RLM `\u200F`, LRE `\u202A`, PDF `\u202C`). The `+` sign must never flip to the wrong end in RTL layouts.
2. **Mixed Script & Trailing Punctuation**:
   - Punctuation (`!`, `?`, `.`, `:`) must remain at the correct visual end of sentences when Arabic is mixed with English words or variables.
3. **Arabic Pluralization (6 Grammatical Forms)**:
   - Arabic translations must support all 6 forms:
     - `zero` (0)
     - `one` (1 - مفرد)
     - `two` (2 - مثنى)
     - `few` (3-10 - جمع قلة)
     - `many` (11-99 - تمييز منصوب)
     - `other` (100+)
4. **Runtime Switching**:
   - Language switching must happen immediately in memory with zero app restart.

---

## 3. Architecture & Code Style

- **Modular Architecture**:
  - Keep modules segregated under `lib/src/`:
    - `core/`: Global controller, root `MasterApp`, base `AppController`.
    - `state/`: Service locator (`locator.dart`), reactive variables (`rx.dart`), rebuilder (`watch.dart`).
    - `localization/`: Translations registry, BiDi sanitizers, plurals, `.tr` extensions.
    - `theme/`: Light/Dark/System theme switcher and dynamic palette tokens.
    - `navigation/`: Context-free router and overlays (snackbars, dialogs, loading).
    - `responsive/`: Screen scaler (`.w`, `.h`, `.sp`, `.r`, `.gapX`, `.gapY`).
    - `cleaner/`: Unused translation detector and cross-locale consistency auditor.
    - `utils/`: Form validators and context extensions.
- **Export Discipline**:
  - All public APIs must be exported cleanly through `lib/appforge.dart`. Internal implementation details stay in `lib/src/`.
- **Typing & Clean Code**:
  - Strong typing with generic constraints (`App.find<T>()`).
  - Clear docstrings with code examples on every public class and extension.
  - Unit tests for every module under `test/`.

---

## 4. Deprecation & Breaking Change Lifecycle (SemVer Standard)

To maintain absolute stability for consumers, every agent must follow the official Dart/Flutter SemVer lifecycle:

1. **Never Abruptly Delete or Mutate Public APIs**:
   - Never remove or break an existing public method/class in a minor or patch update.
2. **Deprecation Phase (MINOR version increment - `X.(Y+1).0`)**:
   - When introducing a new replacement API, the old API **must** be marked with Dart's `@Deprecated` annotation:
     ```dart
     @Deprecated('Use App.to() instead. Will be removed in v2.0.0.')
     void navigateTo(...) {
       App.to(...); // forward to the new implementation
     }
     ```
   - Deprecated methods must continue to work via backwards-compatible shims.
   - Document in `CHANGELOG.md` under `### Deprecated` with clear before/after examples.
3. **Removal Phase (MAJOR version increment only - `(X+1).0.0`)**:
   - **All previously marked `@Deprecated` APIs are removed ONLY when upgrading the MAJOR version** (e.g., `1.x.x` -> `2.0.0`, or `0.1.x` -> `0.2.0` during initial development).
   - Document in `CHANGELOG.md` under `### Breaking Changes` with a direct Migration Guide.

---

## 5. Execution Workflow

When building or adding features:
1. **Strict Step-by-Step Gate (Wait for User Permission)**:
   - Work on ONLY ONE module/step at a time.
   - When a module/step is finished (implemented, tested, documented, and verified), **STOP IMMEDIATELY**.
   - Present the completion summary to the user and **WAIT FOR THEIR EXPLICIT PERMISSION** before beginning the next step.
   - **NEVER** auto-advance to subsequent modules or roadmap items without explicit user approval.
2. **Verify against zero dependencies**: Ensure no accidental package imports occur.
3. **Check Deprecations**: Ensure no breaking changes are introduced without the `@Deprecated` transition cycle.
4. **Test edge cases**: Especially RTL/BiDi inversion, async context safety, and disposal hooks.
5. **Always Keep AI.md & llms.txt Updated**:
   - Whenever any new public API, parameter, extension, or behavior is added, modified, or deprecated, you **MUST** immediately update `AI.md` and `llms.txt`. Consumer AI agents rely on `AI.md` to understand exact, up-to-date syntax and best practices.
6. **Update SPECIFICATION.md & CHANGELOG.md**: Check off completed items in the roadmap and maintain version history.

---

## 6. Discernment & Architectural Restraint (Questions ≠ Feature Requests)

To keep AppForge elite, focused, and truly impressive, every agent must act as a discerning technical partner rather than a reactive code generator:

1. **User Questions & Comparisons Are Inquiries, Not Feature Requests**:
   - When the user asks a question, raises a hypothetical, or compares AppForge with other libraries (e.g. Riverpod, Bloc, GetX), they are asking for an evaluation and technical opinion.
   - **NEVER** rush to write code, modify classes, or add features simply because a concept was mentioned in conversation.
2. **Defend What is Already Better**:
   - Always evaluate first: *Is our current implementation already superior, cleaner, or more elegant?*
   - If what we already have is better, explain why with technical clarity. Resist the temptation to bloat the framework with every feature from other tools.
3. **Confirm Before Implementing**:
   - When new features or architectural changes are considered, propose and discuss them first. Confirm that the addition genuinely elevates the framework without adding unnecessary cognitive load or API surface bloat.
4. **Guarding the Framework's Identity**:
   - The goal is not to mimic every framework; the goal is to be the most lean, robust, context-free zero-dependency micro-framework in the Flutter ecosystem. Protect its simplicity.

---

## 7. Creative Engineering Over Blind Mimicry (Don't Copy — Innovate)

Every agent must design features with first-principles creativity, leveraging deep platform knowledge rather than copying existing packages:

1. **Never Blindly Mimic 3rd-Party Packages (Universal Standard)**:
   - Do not port the flawed patterns, bloated APIs, or compromises of **any external package or library whatsoever** (no matter what it is). AppForge exists because third-party packages introduce version locks, bloat, unmaintained bugs, dependency graph conflicts, and file-corruption vulnerabilities. We never copy—we engineer from first principles.
2. **Deep Native Platform & Flutter SDK Mastery**:
   - Understand how the Dart VM, Flutter Engine, and mobile operating systems (iOS and Android) work natively.
   - Leverage Dart standard library primitives (`dart:io`, `dart:async`, `dart:convert`, POSIX atomic file operations, memory-mapped buffers) to build superior solutions with strictly zero external dependencies.
3. **Ergonomic Simplicity Outside, Relentless Optimization Inside**:
   - **Front-facing API**: Must be effortless, elegant, and crystal-clear in developer code (e.g., `AppStorage.read<T>()`, `App.isOnline`, `persistLocale: true`).
   - **Behind-the-scenes Engine**: Must be rock-solid, crash-immune, hardware-accelerated, and free of memory leaks.

---

## 8. Professional Technical Naming & API Craftsmanship (No Casual/Marketing Jargon in Code)

Every agent must uphold senior software engineering standards for all public and internal code identifiers:

1. **User Descriptions Are Problem Statements, Not API Names**:
   - The user often explains a desired capability using colloquial, casual, or non-technical words (e.g. *"the shimmer should be smart"*, *"make it auto-guess"*, *"magic loader"*, *"super list"*).
   - **NEVER blindly convert the user's casual phrases into API symbols** (e.g., avoid `smartShimmer`, `magicBox`, `autoGuess`, `superWidget`).
2. **Code Must Use Standard Technical & Architectural Vocabulary**:
   - Use established computer science, Flutter SDK, native mobile (iOS/Android), graphics, and software design pattern terminology:
     - Use `skeletonize` / `AppSkeletonizer` (not `smartShimmer`).
     - Use `harmonize` / `derive` (not `autoColor`).
     - Use `evict` / `invalidate` (not `forget`).
     - Use `reconcile` / `synchronize` (not `syncUpNow`).
     - Use `intercept` / `pipeline` / `middleware` (not `gateKeeper`).
3. **Casual Words Belong in High-Level Descriptions Only**:
   - Non-technical, relatable phrasing is welcome in README feature summaries, tutorial paragraphs, or chat discussions to explain benefits to developers.
   - The code itself (class names, method names, extension signatures, parameter labels, and enum values) must strictly be technical, dignified, and production-grade.

