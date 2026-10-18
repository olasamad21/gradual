import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../../core/models/concept_model.dart';
import '../../core/services/read_aloud_text.dart';
import '../../core/theme/app_theme.dart';
import 'auto_scroll_logic.dart';
import 'concept_section_style.dart';
import 'read_along_text.dart';

class ConceptFlipCard extends StatefulWidget {
  const ConceptFlipCard({
    super.key,
    required this.concept,
    required this.index,
    required this.isRead,
    required this.isLastWord,
    required this.onMarkRead,
    this.isReadingAloud = false,
    this.onToggleReadAloud,
    this.onToggleReadAloudWithFace,
    this.readingSection,
    this.readingWordStart,
    this.readingWordEnd,
    this.readingSpeed = 1.0,
    this.onCycleSpeed,
    this.onExpand,
    this.isSaved = false,
    this.onToggleSaved,
  });

  final Concept concept;
  final int index;
  final bool isRead;
  final bool isLastWord;
  final VoidCallback onMarkRead;
  final bool isReadingAloud;
  final VoidCallback? onToggleReadAloud;
  final void Function({bool fromBackFace})? onToggleReadAloudWithFace;
  final ReadSectionKind? readingSection;
  final int? readingWordStart;
  final int? readingWordEnd;
  final double readingSpeed;
  final VoidCallback? onCycleSpeed;
  final VoidCallback? onExpand;
  final bool isSaved;
  final VoidCallback? onToggleSaved;

  @override
  State<ConceptFlipCard> createState() => _ConceptFlipCardState();
}

class _ConceptFlipCardState extends State<ConceptFlipCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late final ScrollController _frontScrollController;
  late final ScrollController _backScrollController;
  final GlobalKey _frontScrollViewKey = GlobalKey();
  final GlobalKey _backScrollViewKey = GlobalKey();
  bool _autoScrollPaused = false;
  Timer? _userScrollTimer;
  bool _isFront = true;
  bool _longPressed = false;

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
    _frontScrollController = ScrollController();
    _backScrollController = ScrollController();
  }

  @override
  void didUpdateWidget(ConceptFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReadingAloud && 
        widget.readingSection != null && 
        widget.readingSection!.onBackFace && 
        _isFront) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
      _isFront = false;
    }
  }

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _frontScrollController.dispose();
    _backScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onUserScroll() {
    _autoScrollPaused = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _autoScrollPaused = false;
      }
    });
  }

  void _onWordRect(Rect wordRect, {required bool isFrontFace}) {
    if (!widget.isReadingAloud) return;
    if (isFrontFace != _isFront) return;
    if (_autoScrollPaused) return;

    final controller = isFrontFace ? _frontScrollController : _backScrollController;
    final key = isFrontFace ? _frontScrollViewKey : _backScrollViewKey;

    if (!controller.hasClients) return;

    final scrollContext = key.currentContext;
    if (scrollContext == null) return;
    final renderBox = scrollContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final viewportTopLeft = renderBox.localToGlobal(Offset.zero);
    final viewportTop = viewportTopLeft.dy;
    final viewportBottom = viewportTop + renderBox.size.height;

    final target = computeAutoScrollTarget(
      currentOffset: controller.offset,
      maxExtent: controller.position.maxScrollExtent,
      viewportTop: viewportTop,
      viewportBottom: viewportBottom,
      wordTop: wordRect.top,
      wordBottom: wordRect.bottom,
    );

    if (target != null) {
      if (MediaQuery.disableAnimationsOf(scrollContext)) {
        controller.jumpTo(target);
      } else {
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  Widget _buildSpeakerAndSpeed({bool isBackFace = false}) {
    if (widget.onToggleReadAloud == null && widget.onToggleReadAloudWithFace == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isReadingAloud && widget.onCycleSpeed != null)
          Semantics(
            label: 'Reading speed',
            button: true,
            child: InkWell(
              onTap: widget.onCycleSpeed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.readingSpeed == 1.0 ? '1x' : (widget.readingSpeed == 0.75 ? '0.75x' : '1.25x'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Icon(
              widget.isReadingAloud ? Icons.stop_rounded : Icons.volume_up_rounded,
              color: Colors.grey.shade600,
            ),
            tooltip: widget.isReadingAloud ? 'Stop reading' : 'Read aloud',
            onPressed: () {
              if (widget.onToggleReadAloudWithFace != null) {
                widget.onToggleReadAloudWithFace!(fromBackFace: isBackFace);
              } else {
                widget.onToggleReadAloud?.call();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarkButton() {
    if (widget.onToggleSaved == null) return const SizedBox.shrink();
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: Icon(
          widget.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: widget.isSaved
              ? AppTheme.primaryColor
              : Colors.grey.shade600,
        ),
        tooltip: widget.isSaved ? 'Remove from saved' : 'Save word',
        onPressed: widget.onToggleSaved,
      ),
    );
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
                  Flexible(
                    child: WordIndexPill(index: widget.index, isRead: widget.isRead),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.index == 0) const SwipeHintAnimation(),
                      if (widget.onToggleSaved != null) _buildBookmarkButton(),
                      _buildSpeakerAndSpeed(isBackFace: false),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Word
              ReadAlongText(
                text: widget.concept.term,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
                sectionActive: widget.isReadingAloud && widget.readingSection == ReadSectionKind.term,
                onCurrentWordRect: (rect) => _onWordRect(rect, isFrontFace: true),
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
                child: ScrollFadeMask(
                  controller: _frontScrollController,
                  child: NotificationListener<ScrollStartNotification>(
                    onNotification: (notification) {
                      if (notification.dragDetails != null) {
                        _onUserScroll();
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      key: _frontScrollViewKey,
                      controller: _frontScrollController,
                      child: ReadAlongText(
                        text: widget.concept.definition,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF374151),
                          height: 1.6,
                        ),
                        sectionActive: widget.isReadingAloud && widget.readingSection == ReadSectionKind.definition,
                        highlightStart: widget.readingSection == ReadSectionKind.definition ? widget.readingWordStart : null,
                        highlightEnd: widget.readingSection == ReadSectionKind.definition ? widget.readingWordEnd : null,
                        onCurrentWordRect: (rect) => _onWordRect(rect, isFrontFace: true),
                      ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: WordIndexPill(index: widget.index, isRead: widget.isRead),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onToggleSaved != null) _buildBookmarkButton(),
                      _buildSpeakerAndSpeed(isBackFace: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ScrollFadeMask(
                  controller: _backScrollController,
                  child: NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    if (notification.dragDetails != null) {
                      _onUserScroll();
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    key: _backScrollViewKey,
                    controller: _backScrollController,
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
                                analogySectionIcon,
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ReadAlongText(
                                    text: widget.concept.analogy!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF166534),
                                      height: 1.5,
                                    ),
                                    sectionActive: widget.isReadingAloud && widget.readingSection == ReadSectionKind.analogy,
                                    highlightStart: widget.readingSection == ReadSectionKind.analogy ? widget.readingWordStart : null,
                                    highlightEnd: widget.readingSection == ReadSectionKind.analogy ? widget.readingWordEnd : null,
                                    onCurrentWordRect: (rect) => _onWordRect(rect, isFrontFace: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (showExample) ...[
                          _buildSectionHeader('Real World Example'),
                          ReadAlongText(
                            text: widget.concept.realWorldExample,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
                            sectionActive: widget.isReadingAloud && widget.readingSection == ReadSectionKind.example,
                            highlightStart: widget.readingSection == ReadSectionKind.example ? widget.readingWordStart : null,
                            highlightEnd: widget.readingSection == ReadSectionKind.example ? widget.readingWordEnd : null,
                            onCurrentWordRect: (rect) => _onWordRect(rect, isFrontFace: false),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (showConfusedWith) ...[
                          _buildSectionHeader("Don't confuse with"),
                          ReadAlongText(
                            text: widget.concept.confusedWith!,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
                            sectionActive: widget.isReadingAloud && widget.readingSection == ReadSectionKind.confusedWith,
                            highlightStart: widget.readingSection == ReadSectionKind.confusedWith ? widget.readingWordStart : null,
                            highlightEnd: widget.readingSection == ReadSectionKind.confusedWith ? widget.readingWordEnd : null,
                            onCurrentWordRect: (rect) => _onWordRect(rect, isFrontFace: false),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final gestures = <Type, GestureRecognizerFactory>{};

    if (widget.onExpand != null) {
      gestures[LongPressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(
          duration: const Duration(milliseconds: 450),
        ),
        (LongPressGestureRecognizer instance) {
          instance.onLongPress = () {
            _longPressed = true;
            HapticFeedback.mediumImpact();
            widget.onExpand?.call();
          };
        },
      );
    }

    gestures[TapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
      () => TapGestureRecognizer(),
      (TapGestureRecognizer instance) {
        instance.onTapDown = (_) {
          _longPressed = false;
        };
        instance.onTap = () {
          if (_longPressed) {
            _longPressed = false;
            return;
          }
          _toggleCard();
        };
      },
    );

    Widget cardContent = AnimatedBuilder(
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
    );

    Widget result = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: gestures,
      child: cardContent,
    );

    if (widget.onExpand != null) {
      result = Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Open full screen reader'):
              widget.onExpand!,
        },
        child: result,
      );
    }

    return result;
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


