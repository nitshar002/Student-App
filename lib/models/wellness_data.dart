class SleepEntry {
  final DateTime date;
  final int bedtimeHour;
  final int bedtimeMinute;
  final int wakeHour;
  final int wakeMinute;
  final String note;

  SleepEntry({
    required this.date,
    required this.bedtimeHour,
    required this.bedtimeMinute,
    required this.wakeHour,
    required this.wakeMinute,
    this.note = '',
  });

  Duration get duration {
    final bedtime = DateTime(date.year, date.month, date.day, bedtimeHour, bedtimeMinute);
    var wake = DateTime(date.year, date.month, date.day, wakeHour, wakeMinute);
    if (wake.isBefore(bedtime) || wake.isAtSameMomentAs(bedtime)) {
      wake = wake.add(const Duration(days: 1));
    }
    return wake.difference(bedtime);
  }

  String get formattedBedtime => '${_twoDigits(bedtimeHour)}:${_twoDigits(bedtimeMinute)}';
  String get formattedWake => '${_twoDigits(wakeHour)}:${_twoDigits(wakeMinute)}';

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'bedtimeHour': bedtimeHour,
        'bedtimeMinute': bedtimeMinute,
        'wakeHour': wakeHour,
        'wakeMinute': wakeMinute,
        'note': note,
      };

  factory SleepEntry.fromMap(Map<String, dynamic> map) {
    return SleepEntry(
      date: DateTime.parse(map['date'] as String),
      bedtimeHour: _readInt(map, ['bedtimeHour', 'bedtime_hour']),
      bedtimeMinute: _readInt(map, ['bedtimeMinute', 'bedtime_minute']),
      wakeHour: _readInt(map, ['wakeHour', 'wake_hour']),
      wakeMinute: _readInt(map, ['wakeMinute', 'wake_minute']),
      note: map['note']?.toString() ?? '',
    );
  }

  static int _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class WorkoutEntry {
  final DateTime date;
  final int durationMinutes;
  final String activityType;
  final String note;

  WorkoutEntry({
    required this.date,
    required this.durationMinutes,
    required this.activityType,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'activityType': activityType,
        'note': note,
      };

  factory WorkoutEntry.fromMap(Map<String, dynamic> map) {
    return WorkoutEntry(
      date: DateTime.parse(map['date'] as String),
      durationMinutes: SleepEntry._readInt(map, ['durationMinutes', 'duration_minutes']),
      activityType: map['activityType']?.toString() ?? map['activity_type']?.toString() ?? 'Workout',
      note: map['note']?.toString() ?? '',
    );
  }
}
