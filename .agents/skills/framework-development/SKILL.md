---
name: framework-development
description: Workflow and procedures for developing the zero-dependency Flutter micro-framework ("The Idea").
---

# Framework Development Workflow

Use this skill when developing, refactoring, or testing modules inside this zero-dependency Flutter framework.

## 1. Zero-Dependency Verification
Before committing or finalizing any code in this repository:
- Check `pubspec.yaml` to ensure **no external packages** are listed under `dependencies:`.
- Check all imports: Only `package:flutter/...`, `dart:...`, or internal `package:idea/...` / `src/...` imports are allowed.

## 2. Implementing a Module Workflow
Follow this 4-step sequence for every module:
1. **Define Core Logic**: Implement the core classes/extensions under `lib/src/<module>/`.
2. **Export Public Surface**: Re-export public APIs in `lib/appforge.dart`.
3. **Write Unit Tests**: Add corresponding test files in `test/<module>_test.dart` verifying synchronous and asynchronous behavior without mocking third-party libraries.
4. **Update Documentation & AI Manifests**: Mark completed in `SPECIFICATION.md`, update `CHANGELOG.md`, and document syntax and rules in `AI.md` & `llms.txt`.

## 3. BiDi & Arabic Verification Checklist
Whenever touching text, localization, or layout utilities:
- [ ] Test with mixed Arabic and English phrases (e.g. `"مرحبا Flutter!"`).
- [ ] Verify phone numbers with `+` prefix (e.g. `+974 5500 1234`) using `asPhone` or Unicode isolate marks.
- [ ] Verify 6-level Arabic plurals (`zero`, `one`, `two`, `few`, `many`, `other`).
- [ ] Confirm RTL layout direction is automatically configured when switching to Arabic.

## 4. State & Navigation Safety Checklist
- [ ] Verify controllers registered via `App.put()` can be retrieved via `App.find<T>()`.
- [ ] Verify route-bound controllers call `onClose()` upon pop.
- [ ] Verify overlays and navigation calls do not crash when invoked after an async gap.

## 5. Deprecation & Breaking Change Checklist
- [ ] Are any public APIs being changed or renamed?
- [ ] If yes, **do not delete or alter** the old method signature in minor/patch releases.
- [ ] Add `@Deprecated('Use newApi() instead. Will be removed in vX.0.0.')` with a backwards-compatible proxy call.
- [ ] Add deprecation note in `CHANGELOG.md` under `### Deprecated`.
- [ ] Check if this is a Major version upgrade (`MAJOR.0.0`). If and only if upgrading major version, remove all previously deprecated APIs and document them under `### Breaking Changes`.

## 6. Architectural Restraint & Discernment (Questions ≠ Commands)
- [ ] When the user asks a question, explores an idea, or compares with another framework (e.g. Riverpod, Bloc), treat it as an **evaluation request**, NOT an immediate instruction to code.
- [ ] Always check first: **Is our current solution already better, leaner, and sufficient?**
- [ ] Defend simplicity. Avoid feature bloat and external framework mimicry.
- [ ] Present technical analysis, confirm whether a change is truly desirable with the user, and only implement when agreed.

## 7. Strict Step-by-Step Gate (Wait for User Permission)
- [ ] Complete ONLY the currently approved module/step.
- [ ] Once a step is implemented, tested, and documented, STOP immediately.
- [ ] Present status and wait for explicit user permission before beginning the next step.
- [ ] NEVER auto-advance to subsequent modules on your own.

## 8. Professional Technical Naming Checklist (No Casual/Marketing Jargon in Code)
- [ ] Are any public classes, methods, parameters, or extensions using colloquial/marketing words (e.g. `smart`, `magic`, `autoGuess`, `super`)?
- [ ] If yes, refactor them immediately to standard technical, architectural, Flutter SDK, or computer science terminology (e.g. `skeletonize`, `AppSkeletonizer`, `harmonize`, `reconcile`, `evict`, `derive`).
- [ ] Ensure casual phrasing is reserved strictly for high-level introductory documentation or README bullet points, never for public or internal code symbols.


