import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/quiz/quiz_providers.dart';
import 'app_shell.dart';

class AnimatedQuizIcon extends ConsumerStatefulWidget {
  const AnimatedQuizIcon({super.key});

  @override
  ConsumerState<AnimatedQuizIcon> createState() => _AnimatedQuizIconState();
}

class _AnimatedQuizIconState extends ConsumerState<AnimatedQuizIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _activeDurationMs = 1200;
  static const _restDurationMs = 2500;
  static const _totalDurationMs = _activeDurationMs + _restDurationMs;
  static const _activeFraction = _activeDurationMs / _totalDurationMs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We only animate if it's available (enabled but not completed)
    final quizState = ref.watch(quizButtonStateProvider(DateTime.now()));
    final isAvailable = quizState.isEnabled && !quizState.isCompleted;
    
    // Stop animation if we are actually on the quiz tab
    final isQuizTab = ref.watch(appShellTabProvider) == 1;
    
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (isAvailable && !isQuizTab && !disableAnimations) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.reset();
        _controller.stop();
      }
    }

    if (!isAvailable || isQuizTab) {
      return const Icon(Icons.quiz_outlined);
    }

    // Static fallback for reduced motion
    if (disableAnimations) {
      return Semantics(
        label: 'Quiz, available',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.quiz_rounded, color: Color(0xFF388E3C)),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B), // Gold
                  shape: BoxShape.circle,
                ),
              ),
            )
          ],
        ),
      );
    }
    
    return Semantics(
      label: 'Quiz, available',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          
          double progress = 0.0;
          if (t <= _activeFraction) {
            progress = t / _activeFraction; // 0.0 to 1.0 during the active burst
          }
          
          // Ring expands and fades
          final ringScale = 1.0 + (progress * 1.5);
          final ringOpacity = (1.0 - progress).clamp(0.0, 1.0);
          
          // Hop: sine wave up and down
          final hop = math.sin(progress * math.pi) * -4.0;
          // Wiggle: slight rotation
          final wiggle = math.sin(progress * math.pi * 3) * 0.15;
          // Dot scale pulse
          final dotScale = 1.0 + math.sin(progress * math.pi) * 0.4;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Pulsing ring behind
              if (progress > 0)
                Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF388E3C).withValues(alpha: ringOpacity * 0.4),
                    ),
                  ),
                ),
              // Filled Icon with hop and wiggle
              Transform.translate(
                offset: Offset(0, hop),
                child: Transform.rotate(
                  angle: wiggle,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.quiz_rounded, color: Color(0xFF388E3C)),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Transform.scale(
                          scale: dotScale,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
