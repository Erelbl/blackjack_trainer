import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack_trainer/engine/utils/bet_utils.dart';

void main() {
  group('generateSnapPoints', () {
    test('coins=0 returns empty list', () {
      expect(generateSnapPoints(0), isEmpty);
    });

    test('coins=3 returns single entry [3] (below base minimum)', () {
      final pts = generateSnapPoints(3);
      expect(pts, [3]);
    });

    test('coins=80 returns ascending list with base values and cap', () {
      final pts = generateSnapPoints(80);
      // Must be ascending
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i], greaterThan(pts[i - 1]));
      }
      // Base values affordable with 80
      expect(pts, containsAll([5, 10, 25, 50]));
      // 100 > 80 so excluded
      expect(pts, isNot(contains(100)));
      // Cap included
      expect(pts.last, 80);
    });

    test('coins=400 returns sane ascending list including all base points', () {
      final pts = generateSnapPoints(400);
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i], greaterThan(pts[i - 1]));
      }
      expect(pts, containsAll([5, 10, 25, 50, 100]));
      expect(pts.last, 400);
      expect(pts.length, lessThanOrEqualTo(20));
    });

    test('coins=1500 returns <=20 points, ascending, includes base + cap', () {
      final pts = generateSnapPoints(1500);
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i], greaterThan(pts[i - 1]));
      }
      // All base points must be preserved even after sampling
      expect(pts, containsAll([5, 10, 25, 50, 100]));
      expect(pts.last, 1500);
      expect(pts.length, lessThanOrEqualTo(20));
    });

    test('respects maxBet cap', () {
      final pts = generateSnapPoints(2000, maxBet: 100);
      expect(pts.last, 100);
      // Nothing above maxBet
      for (final p in pts) {
        expect(p, lessThanOrEqualTo(100));
      }
    });

    test('all values are positive', () {
      for (final coins in [5, 80, 400, 1500, 5000]) {
        final pts = generateSnapPoints(coins);
        for (final p in pts) {
          expect(p, greaterThan(0));
        }
      }
    });

    test('first element is always 5 when coins >= 5', () {
      expect(generateSnapPoints(5).first, 5);
      expect(generateSnapPoints(100).first, 5);
      expect(generateSnapPoints(1000).first, 5);
    });
  });

  group('clampBetToCoins', () {
    test('returns bet unchanged when bet <= coins', () {
      expect(clampBetToCoins(50, 100), 50);
      expect(clampBetToCoins(100, 100), 100);
      expect(clampBetToCoins(5, 500), 5);
    });

    test('clamps to highest affordable snap point when bet > coins', () {
      // coins=60: snap points = [5,10,25,50,60], highest = 60
      expect(clampBetToCoins(100, 60), 60);
    });

    test('clamps to 50 when coins=50 and bet=100', () {
      // snap points for 50: [5,10,25,50]
      expect(clampBetToCoins(100, 50), 50);
    });

    test('returns 5 when coins=0', () {
      expect(clampBetToCoins(100, 0), 5);
    });

    test('handles coins just below bet', () {
      // coins=99: base=[5,10,25,50], then 99 added → last=99
      expect(clampBetToCoins(100, 99), 99);
    });

    test('auto-snap-down scenario: player loses and coins drop below bet', () {
      // Simulate: had 100 coins, bet 100, lost → now 0 coins
      // clampBetToCoins(100, 0) should return 5 (fallback minimum)
      expect(clampBetToCoins(100, 0), 5);

      // Had 200 coins, bet 100, lost → 100 coins remaining
      expect(clampBetToCoins(100, 100), 100); // still affordable, no clamp

      // Had 150 coins, bet 100, lost → 50 coins remaining
      expect(clampBetToCoins(100, 50), 50);
    });
  });
}
