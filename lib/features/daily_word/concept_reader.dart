import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/concept_model.dart';
import 'reader_logic.dart';
import 'today_concepts_controller.dart';

Future<void> openConceptReader(
  BuildContext context, {
  required Concept concept,
  required int index,
  required int total,
  required VoidCallback onMarkRead,
}) {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: disableAnimations
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 350),
      reverseTransitionDuration: disableAnimations
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ConceptReader(
          concept: concept,
          index: index,
          total: total,
          onMarkRead: onMarkRead,
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
}

class ConceptReader extends ConsumerStatefulWidget {
  const ConceptReader({
    super.key,
    required this.concept,
    required this.index,
    required this.total,
    required this.onMarkRead,
  });

  final Concept concept;
  final int index;
  final int total;
  final VoidCallback onMarkRead;

  @override
  ConsumerState<ConceptReader> createState() => _ConceptReaderState();
}

class _ConceptReaderState extends ConsumerState<ConceptReader>
    with SingleTickerProviderStateMixin {
  double _dragDistance = 0.0;
  late final AnimationController _snapController;
  late Animation<double> _snapAnimation;
  Timer? _popTimer;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _popTimer?.cancel();
    _snapController.dispose();
    super.dispose();
  }

  void _snapBack() {
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dragDistance = 0.0);
      return;
    }
    _snapAnimation = Tween<double>(begin: _dragDistance, end: 0.0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() => _dragDistance = _snapAnimation.value);
      });
    _snapController.forward(from: 0.0);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTopDragZone(bool isRead) {
    final pillColor = isRead ? const Color(0xFF16A34A) : const Color(0xFF374151);
    final pillBg = isRead ? const Color(0xFFF0FDF4) : const Color(0xFFF3F4F6);

    return GestureDetector(
      key: const Key('reader_top_drag_zone'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        final delta = details.primaryDelta ?? 0.0;
        final next = _dragDistance + delta;
        if (next >= 0) {
          setState(() => _dragDistance = next);
        } else if (_dragDistance != 0) {
          setState(() => _dragDistance = 0.0);
        }
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        if (shouldDismissReader(dragDistance: _dragDistance, velocity: velocity)) {
          Navigator.of(context).pop();
        } else {
          _snapBack();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WORDS OF THE DAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: pillColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: pillColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isRead
                              ? const Icon(Icons.check, color: Colors.white, size: 12)
                              : Text(
                                  '${widget.index + 1}',
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
                Semantics(
                  label: 'Close reader',
                  button: true,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('reader_close_button'),
                      tooltip: 'Close reader',
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF374151)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final concept = widget.concept;
    final showAnalogy = concept.analogy != null && concept.analogy!.isNotEmpty;
    final showExample = concept.realWorldExample.isNotEmpty;
    final showConfusedWith =
        concept.confusedWith != null && concept.confusedWith!.isNotEmpty;
    final showRelated = concept.related.isNotEmpty;

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              concept.term,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: const Color(0xFFF3F4F6),
            ),
            _buildSectionHeader('Definition'),
            Text(
              concept.definition,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF374151),
                height: 1.6,
              ),
            ),
            if (showAnalogy) ...[
              _buildSectionHeader('Analogy'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        concept.analogy!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF15803D),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showExample) ...[
              _buildSectionHeader('Real World Example'),
              Text(
                concept.realWorldExample,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
              ),
            ],
            if (showConfusedWith) ...[
              _buildSectionHeader("Don't confuse with"),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        concept.confusedWith!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB45309),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showRelated) ...[
              _buildSectionHeader('Related terms'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: concept.related.map((term) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      term,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isRead) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(
          top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
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
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isRead
                ? null
                : () {
                    widget.onMarkRead();
                    _popTimer?.cancel();
                    _popTimer = Timer(const Duration(milliseconds: 500), () {
                      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                        Navigator.of(context).pop();
                      }
                    });
                  },
            child: Text(
              isRead ? 'Got it \u2713' : 'Got it',
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
    final isRead =
        conceptsState?.readConceptIds.contains(widget.concept.id) ?? false;

    final scale = readerDragScale(_dragDistance, screenHeight);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Transform.translate(
          offset: Offset(0, _dragDistance),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                _buildTopDragZone(isRead),
                _buildBody(),
                _buildBottomBar(isRead),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
