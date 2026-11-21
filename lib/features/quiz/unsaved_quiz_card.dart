import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
          color: context.colors.dangerSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.dangerBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'You have an unsaved quiz result',
                style: TextStyle(
                  color: context.colors.onDangerSoft,
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
                    backgroundColor: context.colors.danger,
                    foregroundColor: context.colors.onBrand,
                    disabledBackgroundColor: context.colors.dangerBorder,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onBrand,
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
