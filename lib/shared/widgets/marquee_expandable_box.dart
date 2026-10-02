import 'package:flutter/material.dart';

class MarqueeExpandableBox extends StatefulWidget {
  const MarqueeExpandableBox({
    super.key,
    required this.text,
  });

  final String text;

  @override
  State<MarqueeExpandableBox> createState() => _MarqueeExpandableBoxState();
}

class _MarqueeExpandableBoxState extends State<MarqueeExpandableBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isExpanded = false;
  late int _copies;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    // A monospace character at size 13 is roughly 7.8 pixels wide.
    // We approximate the width to calculate a smooth, constant speed regardless of text length.
    final int charCount = widget.text.length + 6; // text + "  â€¢â€¢  "
    final double approxWidth = charCount * 7.8;
    
    // We need enough copies so it safely overflows typical phone screens (e.g., 800px)
    _copies = (800 / approxWidth).ceil() + 2; 
    
    // Calculate duration for a smooth reading speed (around 30 pixels per second)
    final int durationMs = (approxWidth / 70.0 * 1000).toInt().clamp(1000, 120000);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MarqueeExpandableBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.dispose();
      _setupAnimation();
      if (!_isExpanded) _controller.repeat();
    }
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    const style = TextStyle(
      fontFamily: 'monospace',
      color: Color(0xFFE2E8F0),
      fontSize: 13,
      height: 1.6,
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.text, style: style),
        Text(
          '  ••  ',
          style: style.copyWith(color: Colors.orange.shade400, fontWeight: FontWeight.bold),
        ),
      ],
    );

    Widget marquee = disableAnimations
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: content)
        : ClipRect(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FractionalTranslation(
                    translation: Offset(-_controller.value * (1.0 / _copies), 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_copies, (index) => content),
                ),
              ),
            ),
          );

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _isExpanded
                  ? Text(widget.text, style: style)
                  : SizedBox(
                      height: 13 * 1.6, // Maintain exact height of one line
                      child: marquee,
                    ),
              
              // Small visual hint
              if (!_isExpanded) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to expand',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
