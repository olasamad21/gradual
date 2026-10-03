import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/concept_model.dart';
class ConceptFlipCard extends StatefulWidget {
  const ConceptFlipCard({
    super.key,
    required this.concept,
    required this.index,
    required this.isRead,
    required this.isLastWord,
    required this.onMarkRead,
  });

  final Concept concept;
  final int index;
  final bool isRead;
  final bool isLastWord;
  final VoidCallback onMarkRead;

  @override
  State<ConceptFlipCard> createState() => _ConceptFlipCardState();
}

class _ConceptFlipCardState extends State<ConceptFlipCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  Widget _buildCardBase({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFront() {
    return _buildCardBase(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word chip header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388E3C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'WORDS OF THE DAY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF388E3C),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFF388E3C),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.index == 0) const SwipeHintAnimation(),
                ],
              ),
              const SizedBox(height: 14),

              // Word
              Text(
                widget.concept.term,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              Container(
                height: 1,
                color: const Color(0xFFF3F4F6),
              ),
              const SizedBox(height: 16),

              // Definition Header
              const Text(
                'DEFINITION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    widget.concept.definition,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF374151),
                      height: 1.6,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Flip hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flip_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text(
                    'Tap to see more',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.isRead)
            Positioned(
              top: -8,
              right: -8,
              child: Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 28),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildBack() {
    final showAnalogy = widget.concept.analogy != null && widget.concept.analogy!.isNotEmpty;
    final showExample = widget.concept.realWorldExample.isNotEmpty;
    final showConfusedWith = widget.concept.confusedWith != null && widget.concept.confusedWith!.isNotEmpty;
    final showRelated = widget.concept.related.isNotEmpty;

    return _buildCardBase(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showAnalogy) ...[
                        _buildSectionHeader('Analogy'),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.concept.analogy!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF166534),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (showExample) ...[
                        _buildSectionHeader('Real World Example'),
                        Text(
                          widget.concept.realWorldExample,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (showConfusedWith) ...[
                        _buildSectionHeader("Don't confuse with"),
                        Text(
                          widget.concept.confusedWith!,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (showRelated) ...[
                        _buildSectionHeader('Related Terms'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.concept.related.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 16),
                      if (widget.isRead && widget.isLastWord)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.celebration_rounded, color: Colors.orange.shade400, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'All done for today',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Center(
                        child: FilledButton(
                          onPressed: widget.isRead
                              ? null
                              : () {
                                  setState(() {});
                                  widget.onMarkRead();
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            backgroundColor: Colors.black87,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                          ),
                          child: Text(
                            widget.isRead ? 'Got it \u2713' : 'Got it',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Flip back hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flip_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    'Tap to flip back',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.isRead)
            Positioned(
              top: -8,
              right: -8,
              child: Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 28),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final isFrontFacing = _animation.value <= 0.5;

          if (disableAnimations) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: isFrontFacing
                  ? KeyedSubtree(key: const ValueKey(1), child: _buildFront())
                  : KeyedSubtree(key: const ValueKey(2), child: _buildBack()),
            );
          }

          final angle = _animation.value * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFrontFacing
                ? _buildFront()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }
}




class SwipeHintAnimation extends StatefulWidget {
  const SwipeHintAnimation({super.key});

  @override
  State<SwipeHintAnimation> createState() => _SwipeHintAnimationState();
}

class _SwipeHintAnimationState extends State<SwipeHintAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final offsetX = 10.0 - (t * 20.0);
        double opacity = 1.0;
        if (t < 0.2) opacity = t / 0.2;
        if (t > 0.8) opacity = (1.0 - t) / 0.2;

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: Opacity(
            opacity: opacity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_double_arrow_left_rounded, color: const Color(0xFF388E3C).withValues(alpha: 0.8), size: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}


