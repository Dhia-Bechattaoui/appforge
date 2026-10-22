# Zero-Dependency Flutter Framework Rules

## Principles
1. **0 Dependencies**: Never add any external dependencies to `pubspec.yaml`.
2. **Context-Free**: State, navigation, overlays, and translations must be accessible without passing `BuildContext`.
3. **True Arabic Support**: Handle BiDi text isolation, phone numbers with `+` signs, and 6-case Arabic plurals natively.
4. **Memory Cleanliness**: Ensure auto-disposal of controllers and safe unmounted checks.
5. **SemVer & Deprecation**: Never abruptly delete or break public APIs. Mark with `@Deprecated('Use newApi() instead. Will be removed in vX.0.0')` in minor releases, maintain backwards-compatible shims, and remove deprecated APIs ONLY during major version upgrades.
6. **Architectural Restraint (Questions ≠ Feature Requests)**: When the user asks a question, raises a comparison, or brainstorms, do NOT immediately write code or add APIs. Evaluate if the existing design is already superior, defend simplicity, and confirm with the user before adding features. Keep the framework lean, elite, and zero-bloat.
7. **Strict Step-by-Step Gate (Wait for User Permission)**: Work on only ONE module/step at a time. When that step is completed, tested, and documented, STOP immediately. Do NOT start the next step until the user explicitly reviews and commands you to proceed.
8. **Professional Technical Naming (No Marketing/Casual Jargon in Code)**: User inquiries and feature descriptions often use casual or colloquial terms (e.g., "smart shimmer", "magic loader", "auto guess"). Never blindly copy the user's conversational words as code symbols. Code symbols (classes, methods, parameters, enums) must always use dignified, precise computer science, Flutter SDK, graphics, and architectural terminology (e.g., `skeletonize`, `AppSkeletonizer`, `harmonize`, `reconcile`, `evict`). Non-technical language belongs only in high-level README / documentation intros.

