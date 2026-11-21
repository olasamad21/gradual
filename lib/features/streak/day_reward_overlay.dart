import 'dart:async';
import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';

import '../../core/services/streak_engine.dart';
import '../../shared/widgets/streak_box.dart';
import 'reward_burst.dart';

class DayRewardOverlay extends StatefulWidget {
  const DayRewardOverlay({
    super.key,
    required this.reward,
    required this.streakCount,
    this.onClose,
  });

  final DayReward reward;
  final int streakCount;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required DayReward reward,
    required int streakCount,
  }) {
    Haptics.success();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss reward',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DayRewardOverlay(
          reward: reward,
          streakCount: streakCount,
        );
      },
    );
  }

  @override
  State<DayRewardOverlay> createState() => _DayRewardOverlayState();
}

class _DayRewardOverlayState extends State<DayRewardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.elasticOut,
      ),
    );
    _animController.forward();

    _autoCloseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (widget.onClose != null) {
      widget.onClose!();
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isPerfect = widget.reward == DayReward.perfect;
    final cell = isPerfect ? HeatmapCell.perfect : HeatmapCell.partial;
    final title = isPerfect ? 'Perfect day!' : 'Day counted';
    final caption = isPerfect
        ? 'All 3 concepts done'
        : '${widget.streakCount} day streak';

    Widget box = StreakBox(
      cell: cell,
      size: 64.0,
    );

    if (isPerfect) {
      box = RewardBurst(
        animate: !disableAnimations,
        child: box,
      );
    }

    Widget animatedBox = disableAnimations
        ? box
        : ScaleTransition(
            scale: _scaleAnimation,
            child: box,
          );

    return Semantics(
      label: '$title. $caption',
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  animatedBox,
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
