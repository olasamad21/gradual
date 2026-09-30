import 'package:flutter/material.dart';

import '../../core/models/concept_model.dart';
import '../../shared/widgets/primary_button.dart';

class ConceptCard extends StatefulWidget {
  const ConceptCard({
    super.key,
    required this.concept,
    required this.isRead,
    required this.onMarkRead,
  });

  final Concept concept;
  final bool isRead;
  final VoidCallback onMarkRead;

  @override
  State<ConceptCard> createState() => _ConceptCardState();
}

class _ConceptCardState extends State<ConceptCard> {
  bool _isExpanded = false;

  void _toggleExpand() {
    if (widget.isRead) return; // Optional: maybe we allow expanding even if read? 
    // The prompt says "After Got it: button disabled, green checkmark, card collapses".
    // I will let them expand again if they tap it, or maybe not. 
    // Let's allow toggle, but force collapse on mark read.
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  void didUpdateWidget(covariant ConceptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRead && !oldWidget.isRead) {
      // Force collapse when marked as read
      _isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isRead ? Colors.green.shade200 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleExpand,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildContent(),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: widget.isRead ? 'Got it' : 'Got it',
                    onPressed: widget.isRead ? null : widget.onMarkRead,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.concept.term,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildChip(widget.concept.category.toUpperCase(), Colors.blue),
                  const SizedBox(width: 8),
                  _buildChip(widget.concept.level.toUpperCase(), Colors.orange),
                ],
              ),
            ],
          ),
        ),
        if (widget.isRead)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.green,
              size: 20,
            ),
          )
        else
          Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.grey.shade400,
          ),
      ],
    );
  }

  Widget _buildChip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color.shade700,
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
          const SizedBox(height: 16),
          _buildSection('Analogy', widget.concept.analogy!),
        ],
        const SizedBox(height: 16),
        _buildSection('Real World Example', widget.concept.realWorldExample),
        if (widget.concept.confusedWith != null && widget.concept.confusedWith!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection('Don\'t confuse with', widget.concept.confusedWith!),
        ],
        if (widget.concept.related.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Related Terms',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.concept.related.map((r) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  r, // Or convert from slug if desired, but slug is fine for now
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
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
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
