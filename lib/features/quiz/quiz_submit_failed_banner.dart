import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class QuizSubmitFailedBanner extends StatelessWidget {
  const QuizSubmitFailedBanner({
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
      label: 'Quiz score not saved',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: context.colors.dangerSoft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Couldn't save your score. Check your connection and retry.",
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
                      : const Text('Retry'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
