# Zero-Dependency Flutter Framework Rules

## Principles

1. **0 Dependencies**:
   - Never add any third-party external dependencies to `pubspec.yaml` (no `get`, `provider`, `dio`, `intl`, `flutter_screenutil`, `shared_preferences`, `material_ui`, `cupertino_ui`).
   - Use only the Dart standard library and core Flutter SDK.

2. **Context-Free Navigation & Overlays**:
   - State, navigation, snackbars, dialogs, bottom sheets, and loaders must work across async gaps without requiring a `BuildContext` parameter.

3. **True Arabic & BiDi Localization**:
   - Isolate bidirectional strings, symbols, and phone numbers using Unicode marks (`\u200E`, `\u200F`).
   - Full support for all 6 Arabic plural forms (zero, one, two, few, many, other) and instant in-memory runtime switching.

4. **Memory Cleanliness & Lifecycle Integrity**:
   - Prevent controller leaks; auto-dispose route-bound controllers on pop.
   - Guard against unmounted context access and deactivated widget tree lookups.

5. **Tier-1 Package Deprecation & Breaking Change Standard (SemVer Lifecycle)**:
   - **Never Abruptly Delete or Mutate Public APIs**:
     - When modifying, renaming, or refactoring an existing API, **never delete or break it directly**.
     - Implement the new superior API alongside the existing one.
     - Keep the old API functioning 100% via a backwards-compatible forwarding shim (redirect wrapper calling the new API) and annotate it with:
       ```dart
       @Deprecated('Use newApi() instead. Will be removed in v(MAJOR+1).0.0.')
       ```
   - **Two-Phase Lifecycle (Deprecation in Minor -> Removal in Major)**:
     - **Minor Releases (`X.(Y+1).0`)**:
       - Introduce the new API.
       - Mark the legacy API `@Deprecated` with a working shim.
       - Document in `CHANGELOG.md` under `### Deprecated` with clear Before/After migration examples.
       - Update `AI.md` and `llms.txt`.
     - **Major Releases (`(X+1).0.0`)**:
       - Delete old `@Deprecated` APIs that completed their cycle in the preceding major version.
       - Any newly deprecated APIs introduced in this major release are retained with `@Deprecated` until the *next* major release (`(X+2).0.0`).
       - Document all deletions in `CHANGELOG.md` under `### Breaking Changes` with a step-by-step Migration Guide.

6. **Upstream Flutter SDK Deprecation Standard (Platform Bridges)**:
   - When the Flutter SDK or Dart VM marks an internal library as deprecated (e.g. `package:flutter/material.dart` transitioning toward modular packages):
     1. **Decouple First**: Switch non-Material files (`navigator.dart`, `transitions.dart`, `shimmer.dart`, `directional_icon.dart`, `theme_manager.dart`) to style-neutral core primitives (`package:flutter/widgets.dart`, `foundation.dart`).
     2. **Protect Backward Compatibility & Zero Dependencies**: Never add unreleased or experimental external packages (`package:material_ui`) that break older stable Flutter versions (`>=3.19.0`) or violate the 0-dependency rule.
     3. **Surgical Line-Level Suppression Only**: Use targeted `// ignore: deprecated_member_use` exclusively on the bridge import lines. Never use blanket `deprecated_member_use: ignore` in `analysis_options.yaml`.

7. **Pro Documentation & Craftsmanship (100% DartDoc Standard)**:
   - Every public class, method, extension, property, and typedef must have comprehensive, professional DartDoc comments.
   - Must include realistic, working code snippets (`/// Example:\n/// ```dart\n/// ...\n/// ````).
   - Docstrings must be dignified, accurate, and completely free of casual jargon or duplication.

8. **Architectural Restraint (Questions ≠ Feature Requests)**:
   - When the user asks a question, raises a comparison, or brainstorms, do NOT immediately write code or add APIs.
   - Evaluate if the existing design is already superior, defend simplicity, and confirm with the user before adding features. Keep the framework lean, elite, and zero-bloat.

9. **Strict Step-by-Step Gate (Wait for User Permission)**:
   - Work on only ONE module/step at a time.
   - When that step is completed, tested, and documented, STOP immediately.
   - Do NOT start the next step until the user explicitly reviews and commands you to proceed.

10. **Professional Technical Naming (No Marketing/Casual Jargon in Code)**:
    - User inquiries and feature descriptions often use casual or colloquial terms (e.g., "smart shimmer", "magic loader", "auto guess"). Never blindly copy the user's conversational words as code symbols.
    - Code symbols (classes, methods, parameters, enums) must always use dignified, precise computer science, Flutter SDK, graphics, and architectural terminology (e.g., `skeletonize`, `AppSkeletonizer`, `harmonize`, `reconcile`, `evict`). Non-technical language belongs only in high-level README / documentation intros.
