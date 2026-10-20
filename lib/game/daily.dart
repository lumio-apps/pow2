// Helpers for the daily challenge. Every day has a number like 20261020.
// The same number always gives the same tiles, so the day is the "seed".

int dayKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

DateTime _dateOf(int key) =>
    DateTime(key ~/ 10000, key ~/ 100 % 100, key % 100);

int previousDay(int key) {
  final date = _dateOf(key);
  return dayKey(DateTime(date.year, date.month, date.day - 1));
}

/// Days in a row that the daily challenge was played, counted back from today.
/// If today was not played yet, the streak still counts up to yesterday.
int dailyStreak(Set<int> played, int today) {
  var day = played.contains(today) ? today : previousDay(today);
  var count = 0;
  while (played.contains(day)) {
    count++;
    day = previousDay(day);
  }
  return count;
}
