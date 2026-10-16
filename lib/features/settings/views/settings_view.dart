import 'package:flutter/material.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/widgets/structure/view_shell.dart';

const transcriptionModels = {
  'whisper-large-v3-turbo': 'Whisper large v3 turbo (fast)',
  'whisper-large-v3': 'Whisper large v3 (most accurate)',
};

const cleanupModels = {
  'openai/gpt-oss-20b': 'GPT-OSS 20B (fast)',
  'openai/gpt-oss-120b': 'GPT-OSS 120B (smarter)',
  'qwen/qwen3.8-27b': 'Qwen 3.8 27B',
};

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.settings,
    required this.apiKey,
    required this.onSettingsChanged,
    required this.onApiKeyChanged,
    this.device,
    this.onDeviceChanged,
  });

  final AppSettings settings;
  final String apiKey;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<String> onApiKeyChanged;
  final AndroidDeviceSettings? device;
  final ValueChanged<AndroidDeviceSettings>? onDeviceChanged;

  @override
  Widget build(BuildContext context) {
    final device = this.device;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: ViewShell.padding),
      children: [
        const _Section('Speech to text'),
        _CommitTextField(
          label: 'Groq API key',
          helper: 'Free at console.groq.com/keys. Stored in the system keychain on this device.',
          value: apiKey,
          obscure: true,
          onCommit: onApiKeyChanged,
        ),
        _Dropdown(
          label: 'Transcription model',
          value: settings.transcriptionModel,
          options: transcriptionModels,
          onChanged: (value) => onSettingsChanged(settings.copyWith(transcriptionModel: value)),
        ),
        _CommitTextField(
          label: 'Language',
          helper: 'Two-letter code such as en or de. Leave empty to detect automatically.',
          value: settings.language,
          onCommit: (value) => onSettingsChanged(settings.copyWith(language: value.trim().toLowerCase())),
        ),
        const _Section('Cleanup'),
        SwitchListTile(
          title: const Text('Clean up dictation'),
          subtitle: const Text('Removes filler words and false starts, applies self-corrections, fixes punctuation.'),
          value: settings.cleanupEnabled,
          onChanged: (value) => onSettingsChanged(settings.copyWith(cleanupEnabled: value)),
        ),
        _Dropdown(
          label: 'Cleanup model',
          value: settings.cleanupModel,
          options: cleanupModels,
          onChanged: (value) => onSettingsChanged(settings.copyWith(cleanupModel: value)),
        ),
        _CommitTextField(
          label: 'Your style preferences',
          helper: 'Optional, e.g. "British spelling. Never use em dashes."',
          value: settings.customInstructions,
          maxLines: 4,
          onCommit: (value) => onSettingsChanged(settings.copyWith(customInstructions: value)),
        ),
        SwitchListTile(
          title: const Text('Learn from my corrections'),
          subtitle: const Text(
            'When you fix a misheard name right after dictating, PocketFlow remembers the spelling next time.',
          ),
          value: settings.learnFromCorrections,
          onChanged: (value) => onSettingsChanged(settings.copyWith(learnFromCorrections: value)),
        ),
        if (device != null && onDeviceChanged != null) ...[
          const _Section('This phone'),
          SwitchListTile(
            title: const Text('Floating mic bubble'),
            subtitle: const Text('Shows a mic button next to the text field you’re typing in.'),
            value: device.bubble,
            onChanged: (value) => onDeviceChanged!(device.copyWith(bubble: value)),
          ),
          SwitchListTile(
            title: const Text('Use Bluetooth headset mic'),
            subtitle: const Text('Records through your headset like a phone call when one is connected.'),
            value: device.bluetoothMic,
            onChanged: (value) => onDeviceChanged!(device.copyWith(bluetoothMic: value)),
          ),
          _Dropdown(
            label: 'Walk mode: stop after silence',
            value: device.walkAutoStopSeconds.toString(),
            options: const {
              '0': 'Never (press the button again)',
              '4': '4 seconds',
              '8': '8 seconds',
              '15': '15 seconds',
            },
            onChanged: (value) => onDeviceChanged!(device.copyWith(walkAutoStopSeconds: int.parse(value))),
          ),
          _Dropdown(
            label: 'Hardware keyboard hotkey',
            value: device.hotkeyMode.name,
            options: {for (final mode in HotkeyMode.values) mode.name: mode.label},
            onChanged: (value) => onDeviceChanged!(device.copyWith(hotkeyMode: HotkeyMode.values.byName(value))),
          ),
          SwitchListTile(
            title: const Text('Remote desktop typing'),
            subtitle: const Text(
              'Types into RustDesk and similar apps key by key through the PocketFlow keyboard. '
              'Needs a one-time adb grant, see the README.',
            ),
            value: device.remoteDesktopTyping,
            onChanged: (value) => onDeviceChanged!(device.copyWith(remoteDesktopTyping: value)),
          ),
        ],
        const _Section('Advanced'),
        _CommitTextField(
          label: 'API base URL',
          helper: 'Any OpenAI-compatible API. Default: $groqBaseUrl',
          value: settings.apiBaseUrl,
          onCommit: (value) =>
              onSettingsChanged(settings.copyWith(apiBaseUrl: value.trim().isEmpty ? groqBaseUrl : value.trim())),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Keep a custom value (typed in an older version, or a model for another API) selectable.
    final all = {if (!options.containsKey(value)) value: value, ...options};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        isExpanded: true,
        items: [for (final entry in all.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value))],
        onChanged: (selected) {
          if (selected != null && selected != value) onChanged(selected);
        },
      ),
    );
  }
}

/// Saves when editing finishes rather than on every keystroke.
class _CommitTextField extends StatefulWidget {
  const _CommitTextField({
    required this.label,
    required this.value,
    required this.onCommit,
    this.helper,
    this.obscure = false,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onCommit;
  final String? helper;
  final bool obscure;
  final int maxLines;

  @override
  State<_CommitTextField> createState() => _CommitTextFieldState();
}

class _CommitTextFieldState extends State<_CommitTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  var _revealed = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_CommitTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text != widget.value) widget.onCommit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        obscureText: widget.obscure && !_revealed,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        minLines: 1,
        autocorrect: !widget.obscure,
        enableSuggestions: !widget.obscure,
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _revealed ? 'Hide' : 'Show',
                  icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _revealed = !_revealed),
                )
              : null,
        ),
      ),
    );
  }
}

@AppPreview(group: 'Settings')
Widget settingsViewPreview() => SettingsView(
  settings: const AppSettings(),
  apiKey: 'gsk_example',
  onSettingsChanged: (_) {},
  onApiKeyChanged: (_) {},
  device: const AndroidDeviceSettings(),
  onDeviceChanged: (_) {},
);
