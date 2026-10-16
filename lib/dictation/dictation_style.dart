import 'package:dart_mappable/dart_mappable.dart';

part 'dictation_style.mapper.dart';

/// How cleanup formats text for the app it's going into.
@MappableEnum()
enum DictationStyle {
  standard('Default', 'Clean, natural sentences.'),
  chat('Chat', 'Casual and short, no greetings or sign-offs added.'),
  email('Email', 'Salutation, body, and closing on their own lines.'),
  notes('Notes', 'Paragraphs and lists when there are several points.'),
  code('Code', 'Technical terms, symbols, and commands kept exact.'),
  memo('Memo', 'Long, hands-free recordings tidied into readable paragraphs.');

  const DictationStyle(this.label, this.description);

  final String label;
  final String description;

  /// Built-in guesses from an Android package name or macOS bundle id. Users can override per app.
  static DictationStyle forApp(String? appId, {Map<String, DictationStyle> overrides = const {}}) {
    if (appId == null || appId.isEmpty) return standard;
    final override = overrides[appId];
    if (override != null) return override;

    final id = appId.toLowerCase();
    for (final (style, needles) in _builtIn) {
      if (needles.any(id.contains)) return style;
    }
    return standard;
  }

  static const _builtIn = [
    (email, ['android.gm', 'mail', 'outlook', 'proton', 'superhuman', 'spark', 'thunderbird', 'fastmail']),
    (
      chat,
      [
        'whatsapp',
        'telegram',
        'signal',
        'messag',
        'mms',
        'slack',
        'discord',
        'teams',
        'instagram',
        'facebook.orca',
        'beeper',
      ],
    ),
    (
      code,
      ['termux', 'terminal', 'iterm', 'vscode', 'visualstudio', 'jetbrains', 'xcode', 'cursor', 'warp', 'ghostty'],
    ),
    (notes, ['keep', 'notes', 'obsidian', 'notion', 'evernote', 'onenote', 'bear', 'docs', 'craft']),
  ];
}
