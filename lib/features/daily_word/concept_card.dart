import 'package:flutter/material.dart';

import '../../core/models/concept_model.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/primary_button.dart';

class ConceptCard extends StatefulWidget {
  const ConceptCard({
    super.key,
    required this.concept,
    required this.isRead,
    required this.onMarkRead,
    this.index = 0,
  });

  final Concept concept;
  final bool isRead;
  final VoidCallback onMarkRead;
  final int index;

  @override
  State<ConceptCard> createState() => _ConceptCardState();
}

class _ConceptCardState extends State<ConceptCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _appearController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOut),
    );

    // Stagger based on index
    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) {
        _appearController.forward();
      }
    });
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  void didUpdateWidget(covariant ConceptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Removed auto-collapse so users can keep reading
  }

  Color _getCategoryColor(String category) {
    const map = <String, Color>{
      'operating-systems': Colors.blue,
      'concurrency': Colors.orange,
      'synchronization': Colors.purple,
      'pitfalls': Colors.pink,
      'patterns': Colors.teal,
      'async': Colors.indigo,
    };
    return map[category] ?? Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(widget.concept.category);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: AppTheme.borderRadius20,
            boxShadow: AppTheme.softShadows,
            border: Border.all(
              color: widget.isRead ? AppTheme.primaryColor.withValues(alpha: 0.3) : const Color(0xFFF3F4F6),
              width: widget.isRead ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Accent stripe
              Positioned(
                left: 0, top: 0, bottom: 0, width: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: widget.isRead ? AppTheme.primaryColor : categoryColor,
                ),
              ),
              InkWell(
                onTap: _toggleExpand,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(categoryColor),
                        if (_isExpanded) ...[
                          const SizedBox(height: 20),
                          const Divider(color: Color(0xFFF3F4F6), height: 1),
                          const SizedBox(height: 20),
                          _buildContent(),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: widget.isRead ? 'Got it ✓' : 'Got it',
                            onPressed: widget.isRead ? null : widget.onMarkRead,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color categoryColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.concept.term,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildChip(widget.concept.category.toUpperCase(), categoryColor),
                  const SizedBox(width: 8),
                  _buildChip(widget.concept.level.toUpperCase(), const Color(0xFF6B7280)),
                ],
              ),
            ],
          ),
        ),
        if (widget.isRead)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, val, child) {
              return Transform.scale(
                scale: val,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
              );
            },
          )
        else
          Icon(
            _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: AppTheme.textSecondary,
            size: 28,
          ),
      ],
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Definition', widget.concept.definition),
        if (widget.concept.analogy != null && widget.concept.analogy!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSection('Analogy', widget.concept.analogy!),
        ],
        const SizedBox(height: 20),
        _buildSection('Real World Example', widget.concept.realWorldExample),
        if (widget.concept.confusedWith != null && widget.concept.confusedWith!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSection('Don\'t confuse with', widget.concept.confusedWith!),
        ],
        if (widget.concept.related.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'RELATED TERMS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.concept.related.map((r) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r.replaceAll('-', ' '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
