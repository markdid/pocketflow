import 'package:flutter/material.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';
import 'package:pocketflow/ui/widgets/surface.dart';

const transcriptionModels = {'whisper-large-v3-turbo': 'Turbo · fast', 'whisper-large-v3': 'Large v3 · accurate'};

const cleanupModels = {
  'openai/gpt-oss-20b': 'GPT-OSS 20B',
  'openai/gpt-oss-120b': 'GPT-OSS 120B',
  'qwen/qwen3.8-27b': 'Qwen 3.8 27B',
};

const _walkStopOptions = {'0': 'Never', '4': '4 seconds', '8': '8 seconds', '15': '15 seconds'};

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
    final onDeviceChanged = this.onDeviceChanged;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 140),
      children: [
        Text('Settings', style: AppThemeData.serif(40)),
        const _Section('Voice to text'),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Column(
            children: [
              _CommitTextField(
                label: 'Groq API key',
                helper: 'Free at console.groq.com/keys. Stored in the system keychain on this device.',
                value: apiKey,
                obscure: true,
                onCommit: onApiKeyChanged,
              ),
              _PickerRow(
                title: 'Transcription model',
                value: settings.transcriptionModel,
                options: transcriptionModels,
                onChanged: (value) => onSettingsChanged(settings.copyWith(transcriptionModel: value)),
              ),
              _PickerRow(
                title: 'Language',
                value: settings.language,
                options: const {
                  '': 'Detect automatically',
                  'en': 'English',
                  'es': 'Spanish',
                  'fr': 'French',
                  'de': 'German',
                  'pt': 'Portuguese',
                  'it': 'Italian',
                  'nl': 'Dutch',
                  'ja': 'Japanese',
                  'zh': 'Chinese',
                  'hi': 'Hindi',
                },
                onChanged: (value) => onSettingsChanged(settings.copyWith(language: value)),
              ),
            ],
          ),
        ),
        const _Section('Cleanup'),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              _SwitchRow(
                title: 'Polish what I say',
                subtitle:
                    'Drops ums and false starts, keeps only your final word on self-corrections, fixes punctuation.',
                value: settings.cleanupEnabled,
                onChanged: (value) => onSettingsChanged(settings.copyWith(cleanupEnabled: value)),
              ),
              _PickerRow(
                title: 'Cleanup model',
                value: settings.cleanupModel,
                options: cleanupModels,
                onChanged: (value) => onSettingsChanged(settings.copyWith(cleanupModel: value)),
              ),
              _SwitchRow(
                title: 'Learn from my corrections',
                subtitle: 'Fix a misheard name right after dictating and it’s spelled right next time.',
                value: settings.learnFromCorrections,
                onChanged: (value) => onSettingsChanged(settings.copyWith(learnFromCorrections: value)),
              ),
              const SizedBox(height: 8),
              _CommitTextField(
                label: 'Your style',
                helper: 'Optional. For example: British spelling. Never use em dashes.',
                value: settings.customInstructions,
                maxLines: 4,
                onCommit: (value) => onSettingsChanged(settings.copyWith(customInstructions: value)),
              ),
            ],
          ),
        ),
        if (device != null && onDeviceChanged != null) ...[
          const _Section('This phone'),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                _SwitchRow(
                  title: 'Floating mic bubble',
                  subtitle: 'Appears beside the text field you’re typing in.',
                  value: device.bubble,
                  onChanged: (value) => onDeviceChanged(device.copyWith(bubble: value)),
                ),
                _SwitchRow(
                  title: 'Use my headset’s mic',
                  subtitle: 'Records through a connected Bluetooth headset, like a phone call.',
                  value: device.bluetoothMic,
                  onChanged: (value) => onDeviceChanged(device.copyWith(bluetoothMic: value)),
                ),
                _PickerRow(
                  title: 'Walk mode stops after silence',
                  value: device.walkAutoStopSeconds.toString(),
                  options: _walkStopOptions,
                  onChanged: (value) => onDeviceChanged(device.copyWith(walkAutoStopSeconds: int.parse(value))),
                ),
              ],
            ),
          ),
          const _Section('Keyboards & remote desktops'),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                _PickerRow(
                  title: 'Hardware keyboard hotkey',
                  value: device.hotkeyMode.name,
                  options: {for (final mode in HotkeyMode.values) mode.name: mode.label},
                  onChanged: (value) => onDeviceChanged(device.copyWith(hotkeyMode: HotkeyMode.values.byName(value))),
                ),
                _SwitchRow(
                  title: 'Type into remote desktops',
                  subtitle: 'Key-by-key typing for RustDesk and similar apps. Needs a one-time adb grant (see README).',
                  value: device.remoteDesktopTyping,
                  onChanged: (value) => onDeviceChanged(device.copyWith(remoteDesktopTyping: value)),
                ),
              ],
            ),
          ),
        ],
        const _Section('Advanced'),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: _CommitTextField(
            label: 'API base URL',
            helper: 'Any OpenAI-compatible API. Default: $groqBaseUrl',
            value: settings.apiBaseUrl,
            onCommit: (value) =>
                onSettingsChanged(settings.copyWith(apiBaseUrl: value.trim().isEmpty ? groqBaseUrl : value.trim())),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Text(
            'PocketFlow is open source. Your audio goes only to the API above.',
            textAlign: TextAlign.center,
            style: AppThemeData.geist(12, color: AppColors.textFaint),
          ),
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
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Text(title, style: AppThemeData.serif(26)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppThemeData.geist(15.5, weight: 560)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppThemeData.geist(13, color: AppColors.textMuted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row showing the current choice; tapping opens a sheet with the options.
class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.title, required this.value, required this.options, required this.onChanged});

  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Keep a custom value (typed in an older version, or a model for another API) visible.
    final all = {if (!options.containsKey(value)) value: value, ...options};
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => _PickerSheet(title: title, value: value, options: all),
        );
        if (picked != null && picked != value) onChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(title, style: AppThemeData.geist(15.5, weight: 560))),
            const SizedBox(width: 12),
            Flexible(
              flex: 2,
              child: Text(
                all[value] ?? value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppThemeData.geist(14, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.title, required this.value, required this.options});

  final String title;
  final String value;
  final Map<String, String> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(title, style: AppThemeData.serif(28)),
          ),
          for (final entry in options.entries)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              selected: entry.key == value,
              selectedTileColor: AppColors.surfaceHigh,
              title: Text(entry.value, style: AppThemeData.geist(15.5, weight: entry.key == value ? 600 : 450)),
              trailing: entry.key == value ? const Icon(Icons.check_rounded, color: AppColors.text) : null,
              onTap: () => Navigator.pop(context, entry.key),
            ),
        ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        obscureText: widget.obscure && !_revealed,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        minLines: 1,
        autocorrect: !widget.obscure,
        enableSuggestions: !widget.obscure,
        style: widget.obscure ? AppThemeData.mono(14, color: AppColors.text) : AppThemeData.geist(15),
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          helperMaxLines: 3,
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _revealed ? 'Hide' : 'Show',
                  icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _revealed = !_revealed),
                )
              : null,
        ),
      ),
    );
  }
}

@AppPreview(group: 'Settings', size: Size(390, 1800))
Widget settingsViewPreview() => SettingsView(
  settings: const AppSettings(),
  apiKey: 'gsk_example',
  onSettingsChanged: (_) {},
  onApiKeyChanged: (_) {},
  device: const AndroidDeviceSettings(),
  onDeviceChanged: (_) {},
);
