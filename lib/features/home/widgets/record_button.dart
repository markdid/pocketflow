import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// A tape-recorder style button: brushed gray housing, sunken well, red dot. While [recording] it sits pressed in
/// and the dot becomes a stop square.
class RecordButton extends StatelessWidget {
  const RecordButton({super.key, required this.recording, this.onTap, this.size = 52});

  final bool recording;

  /// Null disables the button (dictation in progress).
  final VoidCallback? onTap;
  final double size;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final well = size * 0.7;
    final dot = recording ? size * 0.34 : size * 0.42;
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
                  colors: [Color(0xFFF7F8FA), Color(0xFFD9DCE1), Color(0xFFBFC4CB)],
                ),
                border: Border.all(color: const Color(0xFFA9AFB8), width: 0.5),
                boxShadow: recording
                    ? const [BoxShadow(color: Color(0x290F1115), blurRadius: 2, offset: Offset(0, 1))]
                    : const [
                        BoxShadow(color: Color(0x330F1115), blurRadius: 8, offset: Offset(0, 4)),
                        BoxShadow(color: Color(0x1F0F1115), blurRadius: 1, offset: Offset(0, 1)),
                      ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: well,
                height: well,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFADB3BC), Color(0xFFD3D7DD), Color(0xFFEDEFF2)],
                  ),
                ),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: _duration,
                  curve: Curves.easeOutCubic,
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(recording ? size * 0.07 : dot / 2),
                    gradient: const RadialGradient(
                      center: Alignment(-0.35, -0.45),
                      radius: 0.95,
                      colors: [Color(0xFFF47B6E), AppColors.danger, Color(0xFF8A1F18)],
                      stops: [0, 0.55, 1],
                    ),
                    boxShadow: [
                      const BoxShadow(color: Color(0x4D5A0F0A), blurRadius: 2, offset: Offset(0, 1)),
                      if (recording) BoxShadow(color: AppColors.danger.withValues(alpha: 0.45), blurRadius: 10),
                    ],
                  ),
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
