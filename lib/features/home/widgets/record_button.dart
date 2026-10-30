import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// A recorder-style button: a surface circle like the app's cards, with a red dot. While [recording] it sits pressed in and the dot
/// becomes a stop square.
class RecordButton extends StatelessWidget {
  const RecordButton({super.key, required this.recording, this.onTap, this.size = 46});

  final bool recording;

  /// Null disables the button (dictation in progress).
  final VoidCallback? onTap;
  final double size;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final dot = recording ? size * 0.28 : size * 0.32;
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
                color: recording ? AppColors.surfaceHigh : AppColors.surface,
                boxShadow: AppColors.cardShadow,
              ),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: _duration,
                curve: Curves.easeOutCubic,
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: AppColors.danger,
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
