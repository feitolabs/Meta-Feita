class CivilDate implements Comparable<CivilDate> {
  final int year;
  final int month;
  final int day;

  const CivilDate(this.year, this.month, this.day);

  factory CivilDate.today() {
    final now = DateTime.now();
    return CivilDate(now.year, now.month, now.day);
  }

  static CivilDate? tryParse(String raw) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    if (m < 1 || m > 12) return null;
    final maxD = daysInMonth(y, m);
    if (d < 1 || d > maxD) return null;
    return CivilDate(y, m, d);
  }

  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return leap ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  CivilDate addMonths(int months) {
    final zeroBasedMonth = (year * 12 + (month - 1)) + months;
    final newYear = zeroBasedMonth ~/ 12;
    final newMonth = (zeroBasedMonth % 12) + 1;
    final clampedDay = day.clamp(1, daysInMonth(newYear, newMonth));
    return CivilDate(newYear, newMonth, clampedDay);
  }

  CivilDate addDays(int days) {
    final utc = DateTime.utc(year, month, day).add(Duration(days: days));
    return CivilDate(utc.year, utc.month, utc.day);
  }

  int daysBetween(CivilDate other) {
    final a = DateTime.utc(year, month, day);
    final b = DateTime.utc(other.year, other.month, other.day);
    return b.difference(a).inDays;
  }

  String toIso() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String formatPtBr() {
    final d = day.toString().padLeft(2, '0');
    final m = month.toString().padLeft(2, '0');
    return '$d/$m/$year';
  }

  String formatMonthYearPtBr() {
    const names = [
      '',
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return '${names[month]}/$year';
  }

  @override
  int compareTo(CivilDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

