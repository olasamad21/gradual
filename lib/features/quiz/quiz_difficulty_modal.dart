import 'package:flutter/material.dart';

import '../../core/enums/difficulty_level.dart';

class QuizDifficultyModal extends StatelessWidget {
  const QuizDifficultyModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your challenge level',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _DifficultyTile(
              title: 'Junior',
              subtitle: 'Check your understanding of the definition.',
              onTap: () => Navigator.of(context).pop(DifficultyLevel.junior),
            ),
            _DifficultyTile(
              title: 'Senior',
              subtitle: 'Focus on syntax and application.',
              onTap: () => Navigator.of(context).pop(DifficultyLevel.senior),
            ),
            _DifficultyTile(
              title: 'Tech Lead',
              subtitle: 'Think in terms of system design and trade-offs.',
              onTap: () => Navigator.of(context).pop(DifficultyLevel.techLead),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

