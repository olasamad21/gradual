import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/daily_word/reader_logic.dart';

void main() {
  group('reader_logic pure tests', () {
    test('shouldDismissReader true for distance 150', () {
      expect(shouldDismissReader(dragDistance: 150, velocity: 0), isTrue);
    });

    test('shouldDismissReader true for velocity 800 with distance 20', () {
      expect(shouldDismissReader(dragDistance: 20, velocity: 800), isTrue);
    });

    test('shouldDismissReader false for distance 50 and velocity 200', () {
      expect(shouldDismissReader(dragDistance: 50, velocity: 200), isFalse);
    });

    test('shouldDismissReader false for NaN and negative', () {
      expect(shouldDismissReader(dragDistance: double.nan, velocity: 800), isFalse);
      expect(shouldDismissReader(dragDistance: 150, velocity: double.nan), isFalse);
      expect(shouldDismissReader(dragDistance: -20, velocity: 800), isFalse);
    });

    test('readerDragScale is 1.0 at 0', () {
      expect(readerDragScale(0, 800), 1.0);
    });

    test('readerDragScale is 0.92 at half the screen height', () {
      expect(readerDragScale(400, 800), closeTo(0.92, 0.0001));
    });

    test('readerDragScale is between 1.0 and 0.92 in the middle', () {
      final scale = readerDragScale(200, 800);
      expect(scale, greaterThan(0.92));
      expect(scale, lessThan(1.0));
      expect(scale, closeTo(0.96, 0.0001));
    });

    test('readerDragScale clamped beyond half screen height', () {
      expect(readerDragScale(600, 800), 0.92);
    });

    test('readerDragScale 1.0 for NaN and for screenHeight 0', () {
      expect(readerDragScale(double.nan, 800), 1.0);
      expect(readerDragScale(100, double.nan), 1.0);
      expect(readerDragScale(100, 0), 1.0);
      expect(readerDragScale(100, -100), 1.0);
    });

    test('accumulatePull adds for negative overscroll, ignores positive, zero, NaN and infinite, never goes negative', () {
      expect(accumulatePull(10.0, -15.0), 25.0);
      expect(accumulatePull(10.0, 5.0), 10.0);
      expect(accumulatePull(10.0, 0.0), 10.0);
      expect(accumulatePull(10.0, double.nan), 10.0);
      expect(accumulatePull(10.0, double.infinity), 10.0);
      expect(accumulatePull(10.0, double.negativeInfinity), 10.0);
      expect(accumulatePull(-10.0, 5.0), 0.0);
      expect(accumulatePull(-10.0, -5.0), 5.0);
      expect(accumulatePull(double.nan, -5.0), 5.0);
    });

    test('pullVelocityFromSamples returns null for 0 or 1 samples or a zero time span, and a positive pixels-per-second value for samples moving down', () {
      expect(pullVelocityFromSamples([]), isNull);
      expect(pullVelocityFromSamples([(dy: 10.0, micros: 1000)]), isNull);
      expect(pullVelocityFromSamples([(dy: 10.0, micros: 1000), (dy: 20.0, micros: 1000)]), isNull);
      expect(pullVelocityFromSamples([(dy: 10.0, micros: 2000), (dy: 20.0, micros: 1000)]), isNull);

      // 2 samples moving down
      final v1 = pullVelocityFromSamples([
        (dy: 0.0, micros: 0),
        (dy: 100.0, micros: 500000), // 0.5s -> 200 px/s
      ]);
      expect(v1, closeTo(200.0, 0.001));

      // Window of last 5 samples
      final v2 = pullVelocityFromSamples([
        (dy: 999.0, micros: -999999), // should be ignored (outside last 5)
        (dy: 10.0, micros: 100000),
        (dy: 20.0, micros: 200000),
        (dy: 30.0, micros: 300000),
        (dy: 40.0, micros: 400000),
        (dy: 110.0, micros: 600000), // dt = 500000 us = 0.5s, dy = 100.0 -> 200 px/s
      ]);
      expect(v2, closeTo(200.0, 0.001));
    });

    test('nextReadingSpeed cycles 0.75 -> 1.0 -> 1.25 -> 0.75', () {
      expect(nextReadingSpeed(0.75), 1.0);
      expect(nextReadingSpeed(1.0), 1.25);
      expect(nextReadingSpeed(1.25), 0.75);
    });
  });
}

