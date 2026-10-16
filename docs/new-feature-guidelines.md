---
description: New feature/refactor guidelines and best practices
globs: ["lib/features/**/*.dart"]
alwaysApply: false
---

# Flutter Feature Architecture

**⚠️ The examples below may or may not apply to your feature. The goal is clean, readable code that can be tested in isolation.**

- Views and widgets can be previewed in isolation with `@AppPreview` (`make preview`)
- Code is clear and readable
- Keep things as simple as possible, never overengineer. Do not create more files than necessary.
- Gain context from the codebase before creating new files
- View and widget files must not depend on Riverpod

When creating or refactoring a feature, review requirements and existing code first, then work step by step: core pieces in place before adding complexity.

## Folder Structure

```
lib/
├── features/
│   └── feature_name/
│       ├── state/
│       │   └── feature_notifier.dart     // Provider + Notifier/AsyncNotifier
│       ├── views/
│       │   ├── feature_view.dart         // Main content view (+ previews)
│       │   └── feature_empty_view.dart   // Only when a state needs a distinct layout
│       ├── widgets/
│       │   ├── complex_widget/           // Folder for widgets with private parts
│       │   │   └── complex_widget.dart
│       │   └── simple_widget.dart
│       └── feature_page.dart             // Coordinator: watches state, picks a view
├── data/
│   ├── models/                           // Generated (supadart) — never edit by hand
│   └── repositories/                     // Shared across features
├── ui/
│   ├── theme/
│   ├── preview/                          // @AppPreview helper
│   └── widgets/                          // Shared widgets (ViewShell, ...)
├── router/
└── config/
```

## Key Principles

1. **Page as coordinator**: the page only watches state and delegates to views. Use the shared `ViewShell.loading()` / `ViewShell.error()` unless a feature genuinely needs a custom loading or error layout.
2. **Views only when needed**: don't create empty/loading/error views preemptively.
3. **Private widgets**: prefer private `StatelessWidget` classes (`_Header`) over `Widget _buildHeader()` methods.
4. **State management**: Riverpod 3 `Notifier` / `AsyncNotifier` with manually declared providers (`NotifierProvider`, `AsyncNotifierProvider`). No `riverpod_generator` / annotations.
5. **Data**: repositories are plain classes in `lib/data/repositories/` and are shared — features don't create their own. With Supabase, repositories use the supadart generated classes in `lib/data/models/` (`Profile.c_id`, `Profile.fromJson`, `Profile.update(...)`), never raw column strings.
6. **Specific props**: pass specific values AND specific callbacks to widgets (`title`, `onRetry`), not whole models or notifiers. Stateless widgets ideally import only material and the theme. Don't add parameters for things that never change.
7. **Single responsibility**: each file/widget has one clear purpose.
8. **Style**: package imports only, tear-offs over lambdas, `dart_mappable` for domain models needing `copyWith`/equality.

## Pattern 1: `AsyncValue.when()` — data-dependent UIs

Dashboards, lists, detail screens:

```dart
class FeaturePage extends ConsumerWidget {
  const FeaturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feature = ref.watch(featureProvider);
    final notifier = ref.read(featureProvider.notifier);

    return Scaffold(
      body: feature.when(
        loading: () => const ViewShell.loading(),
        error: (error, _) => ViewShell.error(
          message: error.toString(),
          onRetry: () => ref.invalidate(featureProvider),
        ),
        data: (data) => FeatureView(
          firstName: data.firstName,
          isActive: data.isActive,
          onSomething: notifier.performAction,
        ),
      ),
    );
  }
}
```

## Pattern 2: simple conditional — forms & synchronous state

```dart
class BasketPage extends ConsumerWidget {
  const BasketPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basket = ref.watch(basketProvider);
    final notifier = ref.read(basketProvider.notifier);

    return Scaffold(
      body: basket.isEmpty
          ? BasketEmptyView(onStartShopping: () => context.go('/shop'))
          : BasketDataView(
              items: basket.items,
              subTotal: basket.subTotal,
              onFruitAdded: notifier.addFruit,
              onFruitRemoved: notifier.removeFruit,
            ),
    );
  }
}

final basketProvider = NotifierProvider<BasketNotifier, Basket>(BasketNotifier.new);

class BasketNotifier extends Notifier<Basket> {
  @override
  Basket build() => const Basket.empty();

  void addFruit(Fruit fruit) => state = state.copyWithIncreasedQuantity(fruit);
  void removeFruit(Fruit fruit) => state = state.copyWithDecreasedQuantity(fruit);
}
```

## AsyncNotifier with mutations

```dart
final featureProvider = AsyncNotifierProvider<FeatureNotifier, FeatureModel>(FeatureNotifier.new);

class FeatureNotifier extends AsyncNotifier<FeatureModel> {
  @override
  Future<FeatureModel> build() => ref.watch(featureRepositoryProvider).getFeatureData();

  Future<void> updateSomething(String value) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => ref.read(featureRepositoryProvider).updateFeature(value));
    if (!ref.mounted) return;
    state = result;
  }
}
```

## Previews

Views and widgets get `@AppPreview` functions at the bottom of the same file. `AppPreview` renders light + dark variants inside the app theme. Preview functions must be public, top-level, and take no arguments. Keep preview data inline and simple.

```dart
@AppPreview(group: 'Feature')
Widget featureViewPreview() => FeatureView(firstName: 'Ada', isActive: true, onSomething: () {});

@AppPreview(group: 'Feature', name: 'Inactive')
Widget featureViewInactivePreview() => FeatureView(firstName: 'Ada', isActive: false, onSomething: () {});
```

Pages depend on providers, so cover their loading/error/data states with golden tests (below) instead of previews.

## Testing

- Use **mocktail** and mock repositories directly — no interfaces needed.
- **Notifiers**: `ProviderContainer.test(overrides: [...], retry: (_, _) => null)` with a mocked repository.
- **Views/widgets**: plain widget tests — pump the view with values and callbacks, no providers needed.
- **Pages**: golden tests tagged `golden`, overriding the notifier with a fake that returns data / never completes / throws. See `test/features/home/home_page_golden_test.dart` and `test/helpers/golden_test_helper.dart`.
- Goldens are generated on Linux (Docker via `make test update-goldens`, or the CI `update_goldens` dispatch) so they match CI.

```dart
class MockFeatureRepository extends Mock implements FeatureRepository {}

final container = ProviderContainer.test(
  overrides: [featureRepositoryProvider.overrideWithValue(MockFeatureRepository())],
  retry: (_, _) => null,
);

// Page golden override
featureProvider.overrideWith(() => FakeFeatureNotifier(...))
```
