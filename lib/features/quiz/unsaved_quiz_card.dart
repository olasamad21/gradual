import 'package:flutter/material.dart';

class UnsavedQuizCard extends StatelessWidget {
  const UnsavedQuizCard({
    super.key,
    required this.isSaving,
    required this.onRetry,
  });

  final bool isSaving;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Unsaved quiz result',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: const EdgeInsets.only(top: 24, left: 20, right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'You have an unsaved quiz result',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ElevatedButton(
                  onPressed: isSaving ? null : onRetry,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFFECACA),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Retry save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
