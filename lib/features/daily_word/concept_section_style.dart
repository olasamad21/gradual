import 'package:flutter/material.dart';
import '../../core/theme/word_colors.dart';

const IconData analogySectionIconData = Icons.lightbulb_outline_rounded;
const double analogySectionIconSize = 18.0;
const Color analogySectionIconColor = Color(0xFF16A34A);

const Icon analogySectionIcon = Icon(
  analogySectionIconData,
  size: analogySectionIconSize,
  color: analogySectionIconColor,
);

class WordIndexPill extends StatelessWidget {
  const WordIndexPill({
    super.key,
    required this.index,
    required this.isRead,
    this.total = 3,
    this.label = 'WORDS OF THE DAY',
  });

  final int index;
  final bool isRead;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final color = isRead ? doneGreen : wordColor(index);
    final bgColor = color.withValues(alpha: 0.10);

    return Semantics(
      label: 'Word ${index + 1} of $total, ${isRead ? 'read' : 'not read yet'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: isRead
                      ? const Icon(Icons.check, key: ValueKey('check'), color: Colors.white, size: 12)
                      : Text(
                          '${index + 1}',
                          key: const ValueKey('number'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScrollFadeMask extends StatefulWidget {
  const ScrollFadeMask({
    super.key,
    required this.child,
    this.controller,
    this.topFade = 24.0,
    this.bottomFade = 24.0,
  });

  final Widget child;
  final ScrollController? controller;
  final double topFade;
  final double bottomFade;

  @override
  State<ScrollFadeMask> createState() => _ScrollFadeMaskState();
}

class _ScrollFadeMaskState extends State<ScrollFadeMask> {
  double _topFactor = 0.0;
  double _bottomFactor = 1.0;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ScrollFadeMask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onScroll);
      widget.controller?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final c = widget.controller;
    if (c != null && c.hasClients && c.position.hasContentDimensions) {
      _update(c.offset, c.position.maxScrollExtent);
    }
  }

  void _update(double offset, double maxExtent) {
    final newTop = (offset / widget.topFade).clamp(0.0, 1.0);
    final remaining = maxExtent - offset;
    final newBottom = maxExtent <= 0 ? 0.0 : (remaining / widget.bottomFade).clamp(0.0, 1.0);

    if ((newTop - _topFactor).abs() > 0.001 || (newBottom - _bottomFactor).abs() > 0.001) {
      if (mounted) {
        setState(() {
          _topFactor = newTop;
          _bottomFactor = newBottom;
        });
      }
    }
  }

  void _handleMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    _update(metrics.pixels, metrics.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) {
          _handleMetrics(notification.metrics);
        }
        return false;
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            _handleMetrics(notification.metrics);
          }
          return false;
        },
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            final height = bounds.height;
            if (height <= 0) {
              return const LinearGradient(
                colors: [Colors.black, Colors.black],
              ).createShader(bounds);
            }
            final topExtent = widget.topFade * _topFactor;
            final bottomExtent = widget.bottomFade * _bottomFactor;

            final topStop = (topExtent / height).clamp(0.0, 0.4);
            final bottomStop = (1.0 - (bottomExtent / height)).clamp(0.6, 1.0);

            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _topFactor > 0 ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                _bottomFactor > 0 ? Colors.transparent : Colors.black,
              ],
              stops: [
                0.0,
                topStop,
                bottomStop,
                1.0,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: widget.child,
        ),
      ),
    );
  }
}


