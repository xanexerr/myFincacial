part of finance_app;

List<MapEntry<String, double>> categorySummary(List<FinanceEntry> entries) {
  final result = <String, double>{};
  for (final entry in entries) {
    result[entry.category] = (result[entry.category] ?? 0) + entry.amount;
  }
  return result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

String formatMoney(double value) => '${value.toStringAsFixed(0)} $currency';
String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

DateTime startOfWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

int weekOfYear(DateTime date) {
  final first = startOfWeek(DateTime(date.year, 1, 1));
  return (startOfWeek(date).difference(first).inDays ~/ 7) + 1;
}

List<int> availableYears(FinanceStore store) {
  final years =
      <int>{
          DateTime.now().year,
          ...store.entries.map((e) => e.date.year),
        }.toList()
        ..sort();
  return years;
}

int monthsBetweenInclusive(DateTime start, DateTime end) {
  if (end.isBefore(start)) return 0;
  return (end.year - start.year) * 12 + end.month - start.month + 1;
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _shortMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthLabel(DateTime month) {
  return '${_monthNames[month.month - 1]}, ${month.year}';
}

String dateLabel(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

String timeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String periodLabel(
  DashboardPeriod period,
  ({DateTime start, DateTime end}) range,
) {
  if (period == DashboardPeriod.month) return monthLabel(range.start);
  if (period == DashboardPeriod.year) return '${range.start.year}';
  final end = range.end.subtract(const Duration(days: 1));
  if (range.start.year != end.year) {
    return '${range.start.day} ${_shortMonthNames[range.start.month - 1]} ${range.start.year} - '
        '${end.day} ${_shortMonthNames[end.month - 1]} ${end.year}';
  }
  return '${range.start.day} ${_shortMonthNames[range.start.month - 1]} - '
      '${end.day} ${_shortMonthNames[end.month - 1]} ${end.year}';
}
