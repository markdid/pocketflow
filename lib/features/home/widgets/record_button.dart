import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';

/// A recorder-style button: dark gray housing with a red dot. While [recording] it sits pressed in and the dot
/// becomes a stop square.
class RecordButton extends StatelessWidget {
  const RecordButton({super.key, required this.recording, this.onTap, this.size = 52});

  final bool recording;

  /// Null disables the button (dictation in progress).
  final VoidCallback? onTap;
  final double size;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final dot = recording ? size * 0.3 : size * 0.36;
    return Semantics(
      button: true,
      label: recording ? 'Stop voice memo' : 'Record voice memo',
      excludeSemantics: true,
      child: Tooltip(
        message: recording ? 'Stop' : 'Voice memo',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: _duration,
            opacity: onTap == null ? 0.45 : 1,
            child: AnimatedContainer(
              duration: _duration,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF55595F), Color(0xFF3E4146)],
                ),
                boxShadow: recording
                    ? const [BoxShadow(color: Color(0x290F1115), blurRadius: 2, offset: Offset(0, 1))]
                    : const [BoxShadow(color: Color(0x330F1115), blurRadius: 6, offset: Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: _duration,
                curve: Curves.easeOutCubic,
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5483C),
                  borderRadius: BorderRadius.circular(recording ? size * 0.06 : dot / 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@AppPreview(group: 'Home', name: 'Record button')
Widget recordButtonPreview() => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    RecordButton(recording: false, onTap: () {}),
    const SizedBox(width: 24),
    RecordButton(recording: true, onTap: () {}),
    const SizedBox(width: 24),
    const RecordButton(recording: false),
  ],
);
