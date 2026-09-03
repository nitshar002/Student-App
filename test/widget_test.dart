import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/models/wellness_data.dart';
import 'package:student_app/services/wellness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wellness scoring', () {
    test('average sleep hours and mental health score update when a sleep entry is added', () {
      final service = WellnessService();

      final emptySleep = <SleepEntry>[];
      final emptyWorkouts = <WorkoutEntry>[];

      expect(service.averageSleepHours(emptySleep), 0.0);
      expect(service.computeMentalHealthScore(emptySleep, emptyWorkouts), 1);

      final entry = SleepEntry(
        date: DateTime(2026, 7, 15),
        bedtimeHour: 22,
        bedtimeMinute: 0,
        wakeHour: 6,
        wakeMinute: 0,
        note: 'Rested well',
      );

      final sleepWithEntry = [entry];
      final workoutWithEntry = <WorkoutEntry>[
        WorkoutEntry(
          date: DateTime(2026, 7, 15),
          durationMinutes: 150,
          activityType: 'Walking',
          note: 'Easy walk',
        ),
      ];

      expect(service.averageSleepHours(sleepWithEntry), 8.0);
      expect(service.computeMentalHealthScore(sleepWithEntry, workoutWithEntry), 87);
    });

    test('sleep entries persist locally when no Supabase user is authenticated', () async {
      SharedPreferences.setMockInitialValues({});
      final service = WellnessService();
      final entry = SleepEntry(
        date: DateTime(2026, 7, 15),
        bedtimeHour: 22,
        bedtimeMinute: 30,
        wakeHour: 6,
        wakeMinute: 30,
        note: 'Rested well',
      );

      await service.saveSleepEntry(entry);
      final savedEntries = await service.loadSleepEntries();

      expect(savedEntries, hasLength(1));
      expect(savedEntries.first.date, entry.date);
      expect(savedEntries.first.note, entry.note);
    });
  });
}
