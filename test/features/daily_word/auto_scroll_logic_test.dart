import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/daily_word/auto_scroll_logic.dart';

void main() {
  group('computeAutoScrollTarget', () {
    test('word well inside the view returns null', () {
      final target = computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 200,
        wordBottom: 220,
      );
      expect(target, isNull);
    });

    test('word inside the bottom margin returns a target greater than currentOffset', () {
      final target = computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 440,
        wordBottom: 460,
      );
      expect(target, isNotNull);
      expect(target!, greaterThan(50));
      expect(target, 270.0);
    });

    test('word above the top margin returns a target smaller than currentOffset', () {
      final target = computeAutoScrollTarget(
        currentOffset: 200,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 110,
        wordBottom: 130,
      );
      expect(target, isNotNull);
      expect(target!, lessThan(200));
      expect(target, 90.0);
    });

    test('the target is clamped to maxExtent and to 0', () {
      final targetMax = computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: 150,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 440,
        wordBottom: 460,
      );
      expect(targetMax, 150.0);

      final targetMin = computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 50,
        wordBottom: 70,
      );
      expect(targetMin, 0.0);
    });

    test('a change smaller than 4 returns null', () {
      final target = computeAutoScrollTarget(
        currentOffset: 498,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 440,
        wordBottom: 460,
      );
      expect(target, isNull);
    });

    test('NaN input returns null', () {
      expect(computeAutoScrollTarget(
        currentOffset: double.nan,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 200,
        wordBottom: 220,
      ), isNull);

      expect(computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: double.infinity,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 200,
        wordBottom: 220,
      ), isNull);

      expect(computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: double.nan,
        wordBottom: 220,
      ), isNull);
    });

    test('viewportBottom <= viewportTop returns null', () {
      expect(computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: 500,
        viewportTop: 500,
        viewportBottom: 500,
        wordTop: 200,
        wordBottom: 220,
      ), isNull);

      expect(computeAutoScrollTarget(
        currentOffset: 50,
        maxExtent: 500,
        viewportTop: 500,
        viewportBottom: 400,
        wordTop: 200,
        wordBottom: 220,
      ), isNull);
    });

    test('a zero-height word uses the default line height', () {
      final target = computeAutoScrollTarget(
        currentOffset: 0,
        maxExtent: 500,
        viewportTop: 100,
        viewportBottom: 500,
        wordTop: 450,
        wordBottom: 450,
      );
      expect(target, isNotNull);
      expect(target, 230.0);
    });
  });
}
