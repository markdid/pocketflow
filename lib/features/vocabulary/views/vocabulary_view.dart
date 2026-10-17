import 'package:flutter/material.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';
import 'package:pocketflow/ui/widgets/surface.dart';

class VocabularyView extends StatelessWidget {
  const VocabularyView({
    super.key,
    required this.terms,
    required this.rules,
    required this.onAdd,
    required this.onRemoveTerm,
    required this.onRemoveRule,
  });

  final List<VocabularyTerm> terms;
  final List<ReplacementRule> rules;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemoveTerm;
  final ValueChanged<String> onRemoveRule;

  @override
  Widget build(BuildContext context) {
    final sorted = [...terms]..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
    final learned = terms.where((t) => t.source == TermSource.learned).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 140),
      children: [
        Row(
          children: [
            Expanded(child: Text('Vocabulary', style: AppThemeData.serif(40))),
            _AddButton(onTap: onAdd),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          learned > 0
              ? 'Names and words PocketFlow spells your way. $learned learned from your corrections.'
              : 'Names and words PocketFlow spells your way. Fix a misheard name after dictating and it learns.',
          style: AppThemeData.geist(14, color: AppColors.textMuted, height: 1.45),
        ),
        const SizedBox(height: 28),
        _SectionTitle(title: 'Words', count: terms.length),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const _Empty('Add the names you say often: people, products, places, jargon.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final term in sorted) _TermChip(term: term, onRemove: () => onRemoveTerm(term.term))],
          ),
        const SizedBox(height: 36),
        _SectionTitle(title: 'Auto-fixes', count: rules.length),
        const SizedBox(height: 4),
        Text('Mishearings that get rewritten every time.', style: AppThemeData.geist(13, color: AppColors.textFaint)),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          const _Empty('Like “shin aid” → Sinead. Added when you add a word with how it’s usually misheard.')
        else
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, rule) in rules.indexed) ...[
                  if (index > 0) const Divider(indent: 18, endIndent: 18),
                  _RuleRow(rule: rule, onRemove: () => onRemoveRule(rule.from)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: 'Add a word',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.text,
        foregroundColor: AppColors.ink,
        minimumSize: const Size.square(48),
      ),
      icon: const Icon(Icons.add_rounded),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: AppThemeData.serif(28)),
        const SizedBox(width: 10),
        if (count > 0) Text('$count', style: AppThemeData.mono(13, color: AppColors.textFaint)),
      ],
    );
  }
}

class _TermChip extends StatelessWidget {
  const _TermChip({required this.term, required this.onRemove});

  final VocabularyTerm term;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final learned = term.source == TermSource.learned;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (learned) ...[
              const Icon(Icons.auto_awesome, size: 13, color: AppColors.textFaint, semanticLabel: 'Learned'),
              const SizedBox(width: 6),
            ],
            Text(term.term, style: AppThemeData.geist(14.5, weight: 520)),
            const SizedBox(width: 2),
            InkResponse(
              onTap: onRemove,
              radius: 16,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.textFaint,
                  semanticLabel: 'Remove ${term.term}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.onRemove});

  final ReplacementRule rule;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              rule.from,
              overflow: TextOverflow.ellipsis,
              style: AppThemeData.geist(
                15,
                color: AppColors.textFaint,
              ).copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.textFaint),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMuted),
          ),
          Flexible(child: Text(rule.to, style: AppThemeData.serif(24))),
          const Spacer(),
          if (rule.source == TermSource.learned)
            const Icon(Icons.auto_awesome, size: 13, color: AppColors.textFaint, semanticLabel: 'Learned'),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textFaint),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppThemeData.geist(14, color: AppColors.textFaint, height: 1.45));
  }
}

@AppPreview(group: 'Vocabulary', size: Size(390, 844))
Widget vocabularyViewPreview() => VocabularyView(
  terms: [
    VocabularyTerm(term: 'Sinead', source: TermSource.learned, addedAt: DateTime(2026, 10, 1)),
    VocabularyTerm(term: 'kubectl', source: TermSource.learned, addedAt: DateTime(2026, 10, 1)),
    VocabularyTerm(term: 'PocketFlow', source: TermSource.manual, addedAt: DateTime(2026, 10, 1)),
    VocabularyTerm(term: 'Groq', source: TermSource.manual, addedAt: DateTime(2026, 10, 1)),
    VocabularyTerm(term: 'RustDesk', source: TermSource.manual, addedAt: DateTime(2026, 10, 1)),
    VocabularyTerm(term: 'Caitlin', source: TermSource.learned, addedAt: DateTime(2026, 10, 1)),
  ],
  rules: [
    ReplacementRule(from: 'shin aid', to: 'Sinead', source: TermSource.learned, addedAt: DateTime(2026, 10, 1)),
    ReplacementRule(from: 'cube CTL', to: 'kubectl', source: TermSource.learned, addedAt: DateTime(2026, 10, 1)),
  ],
  onAdd: () {},
  onRemoveTerm: (_) {},
  onRemoveRule: (_) {},
);

@AppPreview(group: 'Vocabulary', name: 'Empty', size: Size(390, 844))
Widget vocabularyViewEmptyPreview() =>
    VocabularyView(terms: const [], rules: const [], onAdd: () {}, onRemoveTerm: (_) {}, onRemoveRule: (_) {});
