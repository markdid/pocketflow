import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/features/vocabulary/state/vocabulary_notifier.dart';
import 'package:pocketflow/features/vocabulary/views/vocabulary_view.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';
import 'package:pocketflow/ui/widgets/structure/view_shell.dart';

class VocabularyPage extends ConsumerWidget {
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabulary = ref.watch(vocabularyProvider);
    final notifier = ref.read(vocabularyProvider.notifier);

    return Scaffold(
      body: vocabulary.when(
        loading: () => const ViewShell.loading(),
        error: (error, _) =>
            ViewShell.error(message: error.toString(), onRetry: () => ref.invalidate(vocabularyProvider)),
        data: (data) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: VocabularyView(
            terms: data.terms,
            rules: data.rules,
            onAdd: () => _showAddSheet(context, notifier),
            onRemoveTerm: notifier.removeTerm,
            onRemoveRule: notifier.removeRule,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, VocabularyNotifier notifier) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddSheet(onAddTerm: notifier.addTerm, onAddRule: notifier.addRule),
    );
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.onAddTerm, required this.onAddRule});

  final ValueChanged<String> onAddTerm;
  final void Function(String from, String to) onAddRule;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _term = TextEditingController();
  final _heard = TextEditingController();

  @override
  void dispose() {
    _term.dispose();
    _heard.dispose();
    super.dispose();
  }

  void _save() {
    final term = _term.text.trim();
    if (term.isEmpty) return;
    widget.onAddTerm(term);
    if (_heard.text.trim().isNotEmpty) widget.onAddRule(_heard.text.trim(), term);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a word', style: AppThemeData.display(22)),
          const SizedBox(height: 4),
          Text(
            'A name or term PocketFlow should always spell this way.',
            style: AppThemeData.geist(14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _term,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Word or name', hintText: 'Sinead'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heard,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'Usually misheard as (optional)',
              hintText: 'shin aid',
              helperText: 'Adds a replacement so this always gets fixed.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Add word')),
        ],
      ),
    );
  }
}
