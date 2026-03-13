/// Extracts the latest (maximum) seed from quest IDs matching [prefix].
///
/// Quest IDs are expected to follow the rotating quest format
/// `<prefix><seed>_<index>` such as `daily_20260227_0`. Invalid or
/// non-matching IDs are ignored.
int? parseLatestSeedFromQuestIds(Iterable<String> questIds, String prefix) {
  int? latestSeed;
  for (final id in questIds) {
    if (!id.startsWith(prefix)) continue;

    final parts = id.split('_');
    if (parts.length < 2) continue;

    final seed = int.tryParse(parts[1]);
    if (seed == null) continue;

    if (latestSeed == null || seed > latestSeed) {
      latestSeed = seed;
    }
  }

  return latestSeed;
}
