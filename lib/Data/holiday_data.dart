class Holiday {
  final String name;
  final DateTime date;
  final String day;

  Holiday({required this.name, required this.date, required this.day});
}

class HolidayManager {
  static final List<Holiday> holidays = [
    Holiday(
        name: 'Christian New Year Day',
        date: DateTime(2025, 1, 1),
        day: 'Wednesday'),
    Holiday(
        name: 'Makar Sankranti', date: DateTime(2025, 1, 14), day: 'Tuesday'),
    Holiday(
        name: 'Mahashivratri', date: DateTime(2025, 2, 26), day: 'Wednesday'),
    Holiday(name: 'Holi / Dhuleti', date: DateTime(2025, 3, 14), day: 'Friday'),
    Holiday(
        name: 'Id-ul-Fitra / Ramjan-Eid',
        date: DateTime(2025, 3, 31),
        day: 'Monday'),
    Holiday(
        name: 'Mahavir Jayanti', date: DateTime(2025, 4, 10), day: 'Thursday'),
    Holiday(
        name: "Dr. Baba Saheb Ambedkar's Birthday",
        date: DateTime(2025, 4, 14),
        day: 'Monday'),
    Holiday(name: 'Good Friday', date: DateTime(2025, 4, 18), day: 'Friday'),
    Holiday(name: 'Buddha Purnima', date: DateTime(2025, 5, 12), day: 'Monday'),
    Holiday(
        name: 'Independence Day/Parsi New Year Day',
        date: DateTime(2025, 8, 15),
        day: 'Friday'),
    Holiday(
        name: 'Ganesh Chaturthi/Samvatsari',
        date: DateTime(2025, 8, 27),
        day: 'Wednesday'),
    Holiday(name: 'Id-e-Milad', date: DateTime(2025, 9, 5), day: 'Friday'),
    Holiday(
        name: "Mahatma Gandhi's Birthday/Dussehra",
        date: DateTime(2025, 10, 2),
        day: 'Thursday'),
    Holiday(
        name: 'Diwali (Dipawali)', date: DateTime(2025, 10, 20), day: 'Monday'),
    Holiday(
        name: 'Vikram Samvant New Year Day',
        date: DateTime(2025, 10, 22),
        day: 'Wednesday'),
    Holiday(name: 'Bhai Bij', date: DateTime(2025, 10, 23), day: 'Thursday'),
    Holiday(
        name: "Guru Nanak's Birthday",
        date: DateTime(2025, 11, 5),
        day: 'Wednesday'),
    Holiday(name: 'Christmas', date: DateTime(2025, 12, 25), day: 'Thursday'),
  ];

  static bool isHoliday(DateTime date) {
    // Check if it's a weekend (Saturday or Sunday)
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }

    // Check if it's a festival holiday
    return holidays.any((holiday) =>
        holiday.date.year == date.year &&
        holiday.date.month == date.month &&
        holiday.date.day == date.day);
  }

  static String? getHolidayName(DateTime date) {
    // If it's weekend, return the day name
    if (date.weekday == DateTime.saturday) return 'Saturday (Weekend)';
    if (date.weekday == DateTime.sunday) return 'Sunday (Weekend)';

    // Check for festival holiday
    final holiday = holidays.firstWhere(
      (holiday) =>
          holiday.date.year == date.year &&
          holiday.date.month == date.month &&
          holiday.date.day == date.day,
      orElse: () => Holiday(name: '', date: date, day: ''),
    );

    return holiday.name.isNotEmpty ? holiday.name : null;
  }
}
