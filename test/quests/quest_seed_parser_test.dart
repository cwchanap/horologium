import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/quest_seed_parser.dart';

void main() {
  group('parseLatestSeedFromQuestIds', () {
    test('returns the latest matching seed', () {
      final seed = parseLatestSeedFromQuestIds(const [
        'daily_20260220_0',
        'daily_20260227_1',
        'weekly_20260223_0',
      ], 'daily_');

      expect(seed, equals(20260227));
    });

    test('ignores non-matching and invalid quest IDs', () {
      final seed = parseLatestSeedFromQuestIds(const [
        'build_house',
        'daily_invalid_0',
        'daily__1',
        'daily_20260115_0',
      ], 'daily_');

      expect(seed, equals(20260115));
    });

    test('returns null when no matching IDs are present', () {
      final seed = parseLatestSeedFromQuestIds(const [
        'quest_intro',
        'weekly_20260223_0',
      ], 'daily_');

      expect(seed, isNull);
    });
  });
}
