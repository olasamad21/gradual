import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/models/daily_content_model.dart'; // <-- Updated import

class WordCard extends StatefulWidget {
  final DailyContent content; // <-- Updated type

  const WordCard({super.key, required this.content});

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Use a curved animation for a realistic flip physics feel
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          // Determine if we've passed the 90-degree mark
          final isFrontFacing = angle <= math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Adds 3D perspective depth
              ..rotateY(angle),
            child: isFrontFacing
                ? _buildFront()
            // THE MIRROR FIX: Counter-rotate the back widget by PI (180 deg)
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

  Widget _buildFront() {
    return _buildCardBase(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.content.word, // Make sure 'word' matches your DailyContent field
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            widget.content.definition, // Make sure 'definition' matches your DailyContent field
            style: const TextStyle(fontSize: 18, color: Color(0xFF4B5563), height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          const Text(
            "Tap to see analogy & code",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return _buildCardBase(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Analogy', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            // If your analogy field is named differently in DailyContent, change it here
            widget.content.analogy ?? "No analogy provided.",
            style: const TextStyle(fontSize: 18, color: Color(0xFF1F2937)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text('Code Example', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark code block
              borderRadius: BorderRadius.circular(8),
            ),
            width: double.infinity,
            child: Text(
              // If your code field is named differently, change it here
              widget.content.codeSnippet ?? "// No code snippet",
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFD4D4D4), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to keep the physical card styling consistent
  Widget _buildCardBase({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}