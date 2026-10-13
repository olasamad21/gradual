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
  });
}
