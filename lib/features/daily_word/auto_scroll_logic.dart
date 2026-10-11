/// Pure logic for computing auto-scroll targets during read-aloud.
///
/// Returns `null` if no scroll is needed or if any inputs are invalid.
double? computeAutoScrollTarget({
  required double currentOffset,
  required double maxExtent,
  required double viewportTop,
  required double viewportBottom,
  required double wordTop,
  required double wordBottom,
}) {
  if (currentOffset.isNaN ||
      currentOffset.isInfinite ||
      maxExtent.isNaN ||
      maxExtent.isInfinite ||
      viewportTop.isNaN ||
      viewportTop.isInfinite ||
      viewportBottom.isNaN ||
      viewportBottom.isInfinite ||
      wordTop.isNaN ||
      wordTop.isInfinite ||
      wordBottom.isNaN ||
      wordBottom.isInfinite) {
    return null;
  }

  if (viewportBottom <= viewportTop) {
    return null;
  }

  double lineHeight = wordBottom - wordTop;
  if (lineHeight <= 0) {
    lineHeight = 20.0;
  }

  final bottomMargin = lineHeight * 3.0;
  final topMargin = lineHeight;

  if (wordBottom > viewportBottom - bottomMargin || wordTop < viewportTop + topMargin) {
    final desired = currentOffset + (wordTop - (viewportTop + (viewportBottom - viewportTop) * 0.30));
    final effectiveMax = maxExtent < 0 ? 0.0 : maxExtent;
    final clamped = desired.clamp(0.0, effectiveMax);
    if ((clamped - currentOffset).abs() < 4.0) {
      return null;
    }
    return clamped;
  }

  return null;
}
