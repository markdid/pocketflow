import 'package:flutter/material.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/widgets/structure/view_shell.dart';

class VocabularyView extends StatelessWidget {
  const VocabularyView({
    super.key,
    required this.terms,
    required this.rules,
    required this.onRemoveTerm,
    required this.onRemoveRule,
  });

  final List<VocabularyTerm> terms;
  final List<ReplacementRule> rules;
  final ValueChanged<String> onRemoveTerm;
  final ValueChanged<String> onRemoveRule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedTerms = [...terms]..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.all(ViewShell.padding),
      children: [
        Text('Words and names', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Spellings PocketFlow should know: names, brands, jargon. Learned ones come from your corrections.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (sortedTerms.isEmpty)
          const _Empty('Add names you say often, like colleagues, products, or places.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in sortedTerms)
                InputChip(
                  avatar: term.source == TermSource.learned ? const Icon(Icons.auto_awesome, size: 16) : null,
                  label: Text(term.term),
                  tooltip: term.source == TermSource.learned ? 'Learned from a correction' : null,
                  onDeleted: () => onRemoveTerm(term.term),
                ),
            ],
          ),
        const SizedBox(height: 32),
        Text('Replacements', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Always rewrite something that gets misheard the same way.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          const _Empty('For example, "shin aid" → "Sinead".')
        else
          Card(
            child: Column(
              children: [
                for (final rule in rules)
                  ListTile(
                    leading: rule.source == TermSource.learned ? const Icon(Icons.auto_awesome) : null,
                    title: Text('${rule.from}  →  ${rule.to}'),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close),
                      onPressed: () => onRemoveRule(rule.from),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

@AppPreview(group: 'Vocabulary')
Widget vocabularyViewPreview() => VocabularyView(
  terms: [
    VocabularyTerm(term: 'Sinead', source: TermSource.learned, addedAt: DateTime(2026, 10, 1)),
    VocabularyTerm(term: 'PocketFlow', source: TermSource.manual, addedAt: DateTime(2026, 10, 1)),
    VocabularyTerm(term: 'Groq', source: TermSource.manual, addedAt: DateTime(2026, 10, 1)),
  ],
  rules: [ReplacementRule(from: 'shin aid', to: 'Sinead', source: TermSource.learned, addedAt: DateTime(2026, 10, 1))],
  onRemoveTerm: (_) {},
  onRemoveRule: (_) {},
);

@AppPreview(group: 'Vocabulary', name: 'Empty')
Widget vocabularyViewEmptyPreview() =>
    VocabularyView(terms: const [], rules: const [], onRemoveTerm: (_) {}, onRemoveRule: (_) {});
