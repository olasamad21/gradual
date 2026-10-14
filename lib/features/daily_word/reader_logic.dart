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

double accumulatePull(double currentPull, double overscroll) {
  final base = (currentPull.isNaN || currentPull < 0) ? 0.0 : currentPull;
  if (overscroll.isFinite && overscroll < 0) {
    final result = base + (-overscroll);
    return result < 0 ? 0.0 : result;
  }
  return base;
}

double? pullVelocityFromSamples(List<({double dy, int micros})> samples) {
  final window = samples.length > 5 ? samples.sublist(samples.length - 5) : samples;
  if (window.length < 2) return null;

  final first = window.first;
  final last = window.last;
  final dtMicros = last.micros - first.micros;
  if (dtMicros <= 0) return null;

  final dy = last.dy - first.dy;
  final dtSeconds = dtMicros / 1000000.0;
  return dy / dtSeconds;
}

double nextReadingSpeed(double currentSpeed) {
  if (currentSpeed == 0.75) {
    return 1.0;
  } else if (currentSpeed == 1.0) {
    return 1.25;
  } else {
    return 0.75;
  }
}
