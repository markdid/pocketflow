# PocketFlow

Flutter app using Riverpod 3, go_router, and Flutter widget previews.

## Commands

Run `make help` for everything. Most used:

- `make run` / `make run-prod` — run against dev / prod (`--dart-define=ENV=...`)
- `make preview` — Flutter widget previewer for `@AppPreview` functions
- `make check` — format check, analyze, and non-golden tests (same as CI)
- `make test-local` — all tests locally; `make test update-goldens` — regenerate goldens in Docker (Linux)
- `make buildrunner` / `make watch` — code generation (dart_mappable)

## Architecture

Follow @docs/new-feature-guidelines.md for every new feature or refactor. In short:

- `lib/features/<feature>/` with `<feature>_page.dart` (coordinator), `state/`, `views/`, `widgets/`
- Pages watch providers; views and widgets take plain values + callbacks and never import Riverpod
- Riverpod 3 `Notifier`/`AsyncNotifier` with manual providers — no riverpod_generator
- Shared repositories (plain classes, no interfaces) in `lib/data/repositories/`
- `lib/features/home` is a working example of the whole pattern, including tests

## Conventions

- Package imports only (`package:pocketflow/...`), never relative imports in `lib/`
- Private `StatelessWidget` classes instead of `_buildX()` methods
- Tear-offs instead of unnecessary lambdas
- `dart_mappable` for domain models needing `copyWith` / equality
- Line length 120 (`dart format` reads it from analysis_options.yaml)
- Run `make check` before considering work done
