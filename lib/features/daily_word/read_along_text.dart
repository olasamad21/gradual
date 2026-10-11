import 'package:flutter/material.dart';

/// Displays text with a word-by-word colour highlight that tracks
/// the current read-aloud position.
///
/// Already-spoken words turn green, the current word is bold green
/// with an underline, and upcoming words keep the original style.
class ReadAlongText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int? highlightStart;
  final int? highlightEnd;
  final bool sectionActive;
  final void Function(Rect globalRect)? onCurrentWordRect;

  const ReadAlongText({
    super.key,
    required this.text,
    required this.style,
    this.highlightStart,
    this.highlightEnd,
    this.sectionActive = false,
    this.onCurrentWordRect,
  });

  @override
  State<ReadAlongText> createState() => _ReadAlongTextState();
}

class _ReadAlongTextState extends State<ReadAlongText> {
  static const _spokenColor = Color(0xFF388E3C);

  bool get _hasValidRange =>
      widget.highlightStart != null &&
      widget.highlightEnd != null &&
      widget.highlightStart! >= 0 &&
      widget.highlightEnd! <= widget.text.length &&
      widget.highlightStart! < widget.highlightEnd!;

  @override
  void initState() {
    super.initState();
    if (_hasValidRange && widget.onCurrentWordRect != null) {
      _reportWordRect();
    }
  }

  @override
  void didUpdateWidget(ReadAlongText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.highlightStart != oldWidget.highlightStart ||
            widget.highlightEnd != oldWidget.highlightEnd) &&
        _hasValidRange &&
        widget.onCurrentWordRect != null) {
      _reportWordRect();
    }
  }

  void _reportWordRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) return;
        final width = renderBox.size.width;
        if (width <= 0) return;

        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        );
        textPainter.layout(maxWidth: width);

        final boxes = textPainter.getBoxesForSelection(
          TextSelection(
            baseOffset: widget.highlightStart!,
            extentOffset: widget.highlightEnd!,
          ),
        );

        if (boxes.isNotEmpty) {
          final box = boxes.first;
          final localRect = box.toRect();
          final globalTopLeft = renderBox.localToGlobal(localRect.topLeft);
          final globalRect = Rect.fromLTWH(
            globalTopLeft.dx,
            globalTopLeft.dy,
            localRect.width,
            localRect.height,
          );
          widget.onCurrentWordRect?.call(globalRect);
        }
      } catch (_) {
        // Never throw: catch errors and ignore.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget textWidget;

    if (widget.text.isEmpty || !_hasValidRange) {
      textWidget = Text(widget.text, style: widget.style);
    } else {
      final before = widget.text.substring(0, widget.highlightStart!);
      final current = widget.text.substring(widget.highlightStart!, widget.highlightEnd!);
      final after = widget.text.substring(widget.highlightEnd!);

      textWidget = Text.rich(
        TextSpan(
          children: [
            if (before.isNotEmpty)
              TextSpan(
                text: before,
                style: widget.style.copyWith(color: _spokenColor),
              ),
            TextSpan(
              text: current,
              style: widget.style.copyWith(
                color: _spokenColor,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: _spokenColor.withValues(alpha: 0.5),
                decorationThickness: 2,
              ),
            ),
            if (after.isNotEmpty)
              TextSpan(text: after, style: widget.style),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.sectionActive
            ? _spokenColor.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: textWidget,
    );
  }
}
