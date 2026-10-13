bool shouldDismissReader({
  required double dragDistance,
  required double velocity,
  double distanceThreshold = 120,
  double velocityThreshold = 700,
}) {
  if (dragDistance.isNaN || velocity.isNaN) return false;
  if (dragDistance < 0) return false;
  return dragDistance >= distanceThreshold || velocity >= velocityThreshold;
}

double readerDragScale(double dragDistance, double screenHeight) {
  if (dragDistance.isNaN || screenHeight.isNaN || screenHeight <= 0) {
    return 1.0;
  }
  if (dragDistance <= 0) {
    return 1.0;
  }
  final maxDrag = screenHeight * 0.5;
  if (maxDrag <= 0) return 1.0;

  final t = (dragDistance / maxDrag).clamp(0.0, 1.0);
  return 1.0 - t * (1.0 - 0.92);
}
