import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/concept_model.dart';
import '../../core/theme/app_theme.dart';
import '../saved/saved_controller.dart';
import 'read_aloud_controller.dart';
import '../../core/services/read_aloud_text.dart';
import 'auto_scroll_logic.dart';
import 'concept_section_style.dart';
import 'read_along_text.dart';
import 'reader_logic.dart';
import 'today_concepts_controller.dart';

Future<int?> openConceptReader({
  required BuildContext context,
  required List<Concept> concepts,
  required int initialIndex,
  required void Function(String conceptId) onMarkRead,
  bool showGotIt = true,
  bool isWeekendReview = false,
}) async {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  final result = await Navigator.of(context).push<int>(
    PageRouteBuilder<int>(
      opaque: true,
      transitionDuration: disableAnimations
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 350),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ConceptReader(
          concepts: concepts,
          initialIndex: initialIndex,
          onMarkRead: onMarkRead,
          showGotIt: showGotIt,
          isWeekendReview: isWeekendReview,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (disableAnimations) {
          return FadeTransition(opacity: animation, child: child);
        }
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    ),
  );
  return result ?? initialIndex;
}

class ConceptReader extends ConsumerStatefulWidget {
  const ConceptReader({
    super.key,
    required this.concepts,
    required this.initialIndex,
    required this.onMarkRead,
    this.showGotIt = true,
    this.isWeekendReview = false,
  });

  final List<Concept> concepts;
  final int initialIndex;
  final void Function(String conceptId) onMarkRead;
  final bool showGotIt;
  final bool isWeekendReview;

  @override
  ConsumerState<ConceptReader> createState() => _ConceptReaderState();
}

class _ConceptReaderState extends ConsumerState<ConceptReader>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, ScrollController> _scrollControllers = {};
  final Map<int, GlobalKey> _scrollViewKeys = {};
  bool _autoScrollPaused = false;
  Timer? _userScrollTimer;
  Timer? _gotItTimer;

  final ValueNotifier<double> _pullNotifier = ValueNotifier<double>(0.0);
  double get _pull => _pullNotifier.value;
  final List<({double dy, int micros})> _pullSamples = [];
  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;
  late final AnimationController _dismissController;
  Animation<double>? _dismissAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userScrollTimer?.cancel();
    _gotItTimer?.cancel();
    _snapController.dispose();
    _dismissController.dispose();
    _pageController.dispose();
    _pullNotifier.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(readAloudControllerProvider.notifier).stop();
    }
  }

  ScrollController _getScrollController(int index) {
    return _scrollControllers.putIfAbsent(index, () => ScrollController());
  }

  GlobalKey _getScrollViewKey(int index) {
    return _scrollViewKeys.putIfAbsent(index, () => GlobalKey());
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

  void _onWordRect(int pageIndex, Rect wordRect) {
    if (pageIndex != _currentIndex) return;
    final readAloudState = ref.read(readAloudControllerProvider);
    if (readAloudState.conceptId != widget.concepts[pageIndex].id) return;
    if (_autoScrollPaused) return;

    final controller = _getScrollController(pageIndex);
    final key = _getScrollViewKey(pageIndex);
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

  void _handlePullEnd(double velocity) {
    if (_isDismissing) return;
    if (shouldDismissReader(dragDistance: _pull, velocity: velocity)) {
      _dismiss();
    } else {
      _snapBack();
    }
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    ref.read(readAloudControllerProvider.notifier).stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      Navigator.of(context).pop(_currentIndex);
      return;
    }
    final screenHeight = MediaQuery.sizeOf(context).height;
    _dismissAnimation = Tween<double>(begin: _pullNotifier.value, end: screenHeight).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeIn),
    )..addListener(() {
        _pullNotifier.value = _dismissAnimation!.value;
      });
    _dismissController.forward(from: 0.0).then((_) {
      if (mounted) {
        Navigator.of(context).pop(_currentIndex);
      }
    });
  }

  void _snapBack() {
    _pullSamples.clear();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pullNotifier.value = 0.0;
      return;
    }
    _snapAnimation = Tween<double>(begin: _pullNotifier.value, end: 0.0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    )..addListener(() {
        _pullNotifier.value = _snapAnimation!.value;
      });
    _snapController.forward(from: 0.0);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.colors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSpeedChip(double currentSpeed) {
    return Semantics(
      label: 'Reading speed',
      button: true,
      child: InkWell(
        onTap: () {
          final nextSpeed = nextReadingSpeed(currentSpeed);
          ref.read(readAloudControllerProvider.notifier).setSpeed(nextSpeed);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentSpeed == 1.0
                  ? '1x'
                  : (currentSpeed == 0.75 ? '0.75x' : '1.25x'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.colors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkButton(Concept currentConcept) {
    final savedIds = ref.watch(savedIdsProvider);
    final isSaved = savedIds.contains(currentConcept.id);
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: Icon(
          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: isSaved ? context.colors.brand : context.colors.textTertiary,
        ),
        tooltip: isSaved ? 'Remove from saved' : 'Save word',
        onPressed: () {
          Haptics.light();
          ref.read(savedControllerProvider.notifier).toggle(currentConcept.id);
        },
      ),
    );
  }

  Widget _buildSpeakerButton(bool isReadingCurrent, Concept currentConcept) {
    return Semantics(
      label: isReadingCurrent ? 'Stop reading' : 'Read aloud',
      button: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: isReadingCurrent ? 'Stop reading' : 'Read aloud',
          icon: Icon(
            isReadingCurrent ? Icons.stop_rounded : Icons.volume_up_rounded,
            color: context.colors.textTertiary,
          ),
          onPressed: () async {
            final success = await ref
                .read(readAloudControllerProvider.notifier)
                .toggle(currentConcept);
            if (!mounted) return;
            if (!success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Read aloud isn't available on this device."),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildTopDragZone(bool isReadCurrent) {
    final readAloudState = ref.watch(readAloudControllerProvider);
    final currentConcept = widget.concepts[_currentIndex];
    final isReadingCurrent = readAloudState.conceptId == currentConcept.id;

    return Semantics(
      container: true,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Close reader'): () {
          ref.read(readAloudControllerProvider.notifier).stop();
          Navigator.of(context).pop(_currentIndex);
        },
      },
      child: GestureDetector(
        key: const Key('reader_top_drag_zone'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (details) {
          _pullSamples.clear();
          _pullSamples.add((
            dy: details.globalPosition.dy,
            micros: DateTime.now().microsecondsSinceEpoch,
          ));
        },
        onVerticalDragUpdate: (details) {
          final delta = details.primaryDelta ?? 0.0;
          final next = _pullNotifier.value + delta;
          _pullNotifier.value = next >= 0 ? next : 0.0;
          _pullSamples.add((
            dy: details.globalPosition.dy,
            micros: DateTime.now().microsecondsSinceEpoch,
          ));
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ??
              pullVelocityFromSamples(_pullSamples) ??
              0.0;
          _handlePullEnd(velocity);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: WordIndexPill(
                      index: _currentIndex,
                      isRead: isReadCurrent,
                      total: widget.concepts.length,
                      label: widget.isWeekendReview ? 'WEEKEND REVIEW' : 'WORDS OF THE DAY',
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBookmarkButton(currentConcept),
                      if (isReadingCurrent) ...[
                        _buildSpeedChip(readAloudState.speed),
                        const SizedBox(width: 4),
                      ],
                      _buildSpeakerButton(isReadingCurrent, currentConcept),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    final concept = widget.concepts[index];
    final showAnalogy = concept.analogy != null && concept.analogy!.isNotEmpty;
    final showExample = concept.realWorldExample.isNotEmpty;
    final showConfusedWith =
        concept.confusedWith != null && concept.confusedWith!.isNotEmpty;
    final showRelated = concept.related.isNotEmpty;

    final readAloudState = ref.watch(readAloudControllerProvider);
    final isReadingThisConcept = readAloudState.conceptId == concept.id;
    final readingSection = readAloudState.section;
    final readingWordStart = readAloudState.wordStart;
    final readingWordEnd = readAloudState.wordEnd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) {
            _pullSamples.clear();
            _pullSamples.add((
              dy: details.globalPosition.dy,
              micros: DateTime.now().microsecondsSinceEpoch,
            ));
          },
          onVerticalDragUpdate: (details) {
            final delta = details.primaryDelta ?? 0.0;
            final controller = _getScrollController(index);
            if (delta < 0 && controller.hasClients) {
              controller.jumpTo((controller.offset - delta).clamp(0.0, controller.position.maxScrollExtent));
            } else if (controller.hasClients && controller.offset > 0) {
              controller.jumpTo((controller.offset - delta).clamp(0.0, controller.position.maxScrollExtent));
            } else {
              final next = _pullNotifier.value + delta;
              _pullNotifier.value = next >= 0 ? next : 0.0;
              _pullSamples.add((
                dy: details.globalPosition.dy,
                micros: DateTime.now().microsecondsSinceEpoch,
              ));
            }
          },
          onVerticalDragEnd: (details) {
            if (_pullNotifier.value > 0) {
              final velocity = details.primaryVelocity ??
                  pullVelocityFromSamples(_pullSamples) ??
                  0.0;
              _handlePullEnd(velocity);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept.term,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: context.colors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: context.colors.surfaceSunken,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ScrollFadeMask(
            controller: _getScrollController(index),
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(overscroll: false),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
                    return false;
                  }
                  if (notification is ScrollStartNotification && notification.dragDetails != null) {
                    _onUserScroll();
                  }
                  if (notification is OverscrollNotification &&
                      notification.dragDetails != null &&
                      notification.metrics.pixels <= 0) {
                    _pullNotifier.value = accumulatePull(_pullNotifier.value, notification.overscroll);
                    final dy = notification.dragDetails?.globalPosition.dy ?? 0.0;
                    _pullSamples.add((
                      dy: dy,
                      micros: DateTime.now().microsecondsSinceEpoch,
                    ));
                    if (_pullSamples.length > 10) _pullSamples.removeAt(0);
                  } else if (notification is ScrollUpdateNotification &&
                      notification.dragDetails != null &&
                      notification.metrics.pixels > 0) {
                    if (_pullNotifier.value > 0 || _pullSamples.isNotEmpty) {
                      _pullNotifier.value = 0.0;
                      _pullSamples.clear();
                    }
                  } else if (notification is ScrollEndNotification) {
                    if (_pullNotifier.value > 0) {
                      final velocity = notification.dragDetails?.velocity.pixelsPerSecond.dy ??
                          pullVelocityFromSamples(_pullSamples) ??
                          0.0;
                      _handlePullEnd(velocity);
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  key: _getScrollViewKey(index),
                  controller: _getScrollController(index),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, widget.showGotIt ? 96 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Definition'),
                      ReadAlongText(
                        text: concept.definition,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.colors.textBody,
                          height: 1.6,
                        ),
                        sectionActive: isReadingThisConcept && readingSection == ReadSectionKind.definition,
                        highlightStart: isReadingThisConcept && readingSection == ReadSectionKind.definition ? readingWordStart : null,
                        highlightEnd: isReadingThisConcept && readingSection == ReadSectionKind.definition ? readingWordEnd : null,
                        onCurrentWordRect: (rect) => _onWordRect(index, rect),
                      ),
                      if (showAnalogy) ...[
                        _buildSectionHeader('Analogy'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.colors.successSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.colors.successBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AnalogySectionIcon(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ReadAlongText(
                                  text: concept.analogy!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.colors.onSuccessSoft,
                                    height: 1.5,
                                  ),
                                  sectionActive: isReadingThisConcept && readingSection == ReadSectionKind.analogy,
                                  highlightStart: isReadingThisConcept && readingSection == ReadSectionKind.analogy ? readingWordStart : null,
                                  highlightEnd: isReadingThisConcept && readingSection == ReadSectionKind.analogy ? readingWordEnd : null,
                                  onCurrentWordRect: (rect) => _onWordRect(index, rect),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (showExample) ...[
                        _buildSectionHeader('Real World Example'),
                        ReadAlongText(
                          text: concept.realWorldExample,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textBody,
                            height: 1.5,
                          ),
                          sectionActive: isReadingThisConcept && readingSection == ReadSectionKind.example,
                          highlightStart: isReadingThisConcept && readingSection == ReadSectionKind.example ? readingWordStart : null,
                          highlightEnd: isReadingThisConcept && readingSection == ReadSectionKind.example ? readingWordEnd : null,
                          onCurrentWordRect: (rect) => _onWordRect(index, rect),
                        ),
                      ],
                      if (showConfusedWith) ...[
                        _buildSectionHeader("Don't confuse with"),
                        ReadAlongText(
                          text: concept.confusedWith!,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textBody,
                            height: 1.5,
                          ),
                          sectionActive: isReadingThisConcept && readingSection == ReadSectionKind.confusedWith,
                          highlightStart: isReadingThisConcept && readingSection == ReadSectionKind.confusedWith ? readingWordStart : null,
                          highlightEnd: isReadingThisConcept && readingSection == ReadSectionKind.confusedWith ? readingWordEnd : null,
                          onCurrentWordRect: (rect) => _onWordRect(index, rect),
                        ),
                      ],
                      if (showRelated) ...[
                        _buildSectionHeader('Related terms'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: concept.related.map((term) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceSunken,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                term,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isReadCurrent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(
          top: BorderSide(color: context.colors.surfaceSunken, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: context.colors.inverseSurface,
              foregroundColor: context.colors.onInverseSurface,
              disabledBackgroundColor: context.colors.borderStrong,
              disabledForegroundColor: context.colors.textTertiary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isReadCurrent
                ? null
                : () {
                    final currentConcept = widget.concepts[_currentIndex];
                    Haptics.medium();
                    widget.onMarkRead(currentConcept.id);
                    _gotItTimer?.cancel();
                    _gotItTimer = Timer(const Duration(milliseconds: 500), () {
                      if (!mounted) return;
                      if (_currentIndex < widget.concepts.length - 1) {
                        if (MediaQuery.disableAnimationsOf(context)) {
                          _pageController.jumpToPage(_currentIndex + 1);
                        } else {
                          _pageController.animateToPage(
                            _currentIndex + 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      } else {
                        Navigator.of(context).pop(_currentIndex);
                      }
                    });
                  },
            child: Text(
              isReadCurrent ? 'Got it \u2713' : 'Got it',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final conceptsState =
        ref.watch(todayConceptsControllerProvider).asData?.value;
    final currentConcept = widget.concepts[_currentIndex];
    final isReadCurrent =
        conceptsState?.readConceptIds.contains(currentConcept.id) ?? false;

    return PopScope<int>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(readAloudControllerProvider.notifier).stop();
        Navigator.of(context).pop(_currentIndex);
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _pullNotifier,
            builder: (context, child) {
              final pull = _pullNotifier.value;
              final scale = readerDragScale(pull, screenHeight);
              return Transform.translate(
                offset: Offset(0, pull),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                _buildTopDragZone(isReadCurrent),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.concepts.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      ref.read(readAloudControllerProvider.notifier).stop();
                    },
                    itemBuilder: (context, index) => _buildPage(index),
                  ),
                ),
                if (widget.showGotIt) _buildBottomBar(isReadCurrent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
