import 'package:flutter/material.dart';

/// Displays text with a word-by-word colour highlight that tracks
/// the current read-aloud position.
///
/// Already-spoken words turn green, the current word is bold green
/// with an underline, and upcoming words keep the original style.
class ReadAlongText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? highlightStart;
  final int? highlightEnd;
  final bool sectionActive;

  const ReadAlongText({
    super.key,
    required this.text,
    required this.style,
    this.highlightStart,
    this.highlightEnd,
    this.sectionActive = false,
  });

  static const _spokenColor = Color(0xFF388E3C);

  bool get _hasValidRange =>
      highlightStart != null &&
      highlightEnd != null &&
      highlightStart! >= 0 &&
      highlightEnd! <= text.length &&
      highlightStart! < highlightEnd!;

  @override
  Widget build(BuildContext context) {
    final Widget textWidget;

    if (text.isEmpty || !_hasValidRange) {
      textWidget = Text(text, style: style);
    } else {
      final before = text.substring(0, highlightStart!);
      final current = text.substring(highlightStart!, highlightEnd!);
      final after = text.substring(highlightEnd!);

      textWidget = Text.rich(
        TextSpan(
          children: [
            if (before.isNotEmpty)
              TextSpan(
                text: before,
                style: style.copyWith(color: _spokenColor),
              ),
            TextSpan(
              text: current,
              style: style.copyWith(
                color: _spokenColor,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: _spokenColor.withValues(alpha: 0.5),
                decorationThickness: 2,
              ),
            ),
            if (after.isNotEmpty)
              TextSpan(text: after, style: style),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: sectionActive
            ? _spokenColor.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: textWidget,
    );
  }
}
