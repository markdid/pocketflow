import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';

/// Shared padding + loading/error states so features don't need their own
/// loading and error views unless they are genuinely custom.
class ViewShell extends StatelessWidget {
  const ViewShell({super.key, required this.child});

  const ViewShell.loading({super.key}) : child = const Center(child: CircularProgressIndicator());

  ViewShell.error({super.key, required String message, VoidCallback? onRetry})
    : child = _ErrorState(message: message, onRetry: onRetry);

  final Widget child;

  /// Use as list padding instead of wrapping a scrollable in [ViewShell],
  /// otherwise the scrollbar is inset with the content.
  static const double padding = 16;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(padding), child: child);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

@AppPreview(group: 'Structure', name: 'Loading')
Widget viewShellLoadingPreview() => const ViewShell.loading();

@AppPreview(group: 'Structure', name: 'Error')
Widget viewShellErrorPreview() => ViewShell.error(message: 'Network unavailable', onRetry: () {});
