/// Friendly names for Android packages and macOS bundle ids shown on history cards.
String appDisplayName(String appId) {
  final known = _names[appId];
  if (known != null) return known;
  final lower = appId.toLowerCase();
  for (final entry in _contains.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  final last = appId.split('.').where((part) => part.isNotEmpty).lastOrNull ?? appId;
  return last.isEmpty ? appId : last[0].toUpperCase() + last.substring(1);
}

const _names = {
  'com.google.android.gm': 'Gmail',
  'com.google.android.apps.messaging': 'Messages',
  'com.google.android.keep': 'Keep',
  'com.google.android.apps.docs': 'Drive',
  'com.google.android.apps.docs.editors.docs': 'Docs',
  'com.microsoft.office.outlook': 'Outlook',
  'org.telegram.messenger': 'Telegram',
  'org.thoughtcrime.securesms': 'Signal',
  'com.facebook.orca': 'Messenger',
  'com.apple.mail': 'Mail',
  'com.apple.Notes': 'Notes',
  'com.apple.Terminal': 'Terminal',
  'com.apple.Safari': 'Safari',
  'com.google.Chrome': 'Chrome',
  'com.googlecode.iterm2': 'iTerm',
  'com.microsoft.VSCode': 'VS Code',
  'com.tinyspeck.slackmacgap': 'Slack',
  'md.obsidian': 'Obsidian',
  'notion.id': 'Notion',
  'carriez.flutter_hbb': 'RustDesk',
};

const _contains = {
  'whatsapp': 'WhatsApp',
  'slack': 'Slack',
  'discord': 'Discord',
  'rustdesk': 'RustDesk',
  'chrome': 'Chrome',
  'firefox': 'Firefox',
  'termux': 'Termux',
  'linkedin': 'LinkedIn',
  'instagram': 'Instagram',
  'twitter': 'X',
};
