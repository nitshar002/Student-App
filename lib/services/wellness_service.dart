import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/models/wellness_data.dart';

class WellnessService {
  WellnessService({SupabaseClient? client, Future<SharedPreferences> Function()? prefsProvider})
      : _client = client,
        _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  final SupabaseClient? _client;
  final Future<SharedPreferences> Function() _prefsProvider;

  Future<List<SleepEntry>> loadSleepEntries() async {
    if (_client != null && _client!.auth.currentUser?.id != null) {
      final response = await _client!.from('sleep_logs').select().order('date', ascending: false);
      final data = response as List<dynamic>? ?? [];
      return data.map((item) => SleepEntry.fromMap(item as Map<String, dynamic>)).toList();
    }

    return _loadLocalSleepEntries();
  }

  Future<List<WorkoutEntry>> loadWorkoutEntries() async {
    if (_client != null && _client!.auth.currentUser?.id != null) {
      final response = await _client!.from('workout_logs').select().order('date', ascending: false);
      final data = response as List<dynamic>? ?? [];
      return data.map((item) => WorkoutEntry.fromMap(item as Map<String, dynamic>)).toList();
    }

    return _loadLocalWorkoutEntries();
  }

  Future<void> saveSleepEntry(SleepEntry entry) async {
    final userId = _client?.auth.currentUser?.id;
    if (_client != null && userId != null) {
      await _client!.from('sleep_logs').upsert({
        'user_id': userId,
        'date': entry.date.toIso8601String(),
        'bedtime_hour': entry.bedtimeHour,
        'bedtime_minute': entry.bedtimeMinute,
        'wake_hour': entry.wakeHour,
        'wake_minute': entry.wakeMinute,
        'note': entry.note,
      }, onConflict: 'user_id,date');
      return;
    }

    await _saveLocalSleepEntry(entry);
  }

  Future<void> saveWorkoutEntry(WorkoutEntry entry) async {
    final userId = _client?.auth.currentUser?.id;
    if (_client != null && userId != null) {
      await _client!.from('workout_logs').insert({
        'user_id': userId,
        'date': entry.date.toIso8601String(),
        'duration_minutes': entry.durationMinutes,
        'activity_type': entry.activityType,
        'note': entry.note,
      });
      return;
    }

    await _saveLocalWorkoutEntry(entry);
  }

  Future<void> deleteSleepEntry(DateTime date) async {
    if (_client != null && _client!.auth.currentUser?.id != null) {
      final userId = _client!.auth.currentUser!.id;
      await _client!.from('sleep_logs').delete().eq('user_id', userId).eq('date', date.toIso8601String());
      return;
    }

    final prefs = await _prefsProvider();
    final entries = await _loadLocalSleepEntriesFromPrefs(prefs);
    final filtered = entries.where((entry) => !(_isSameDate(entry.date, date))).toList();
    await prefs.setString(_sleepLocalKey, jsonEncode(filtered.map((entry) => entry.toMap()).toList()));
  }

  Future<void> deleteWorkoutEntry(DateTime date) async {
    if (_client != null && _client!.auth.currentUser?.id != null) {
      final userId = _client!.auth.currentUser!.id;
      await _client!.from('workout_logs').delete().eq('user_id', userId).eq('date', date.toIso8601String());
      return;
    }

    final prefs = await _prefsProvider();
    final entries = await _loadLocalWorkoutEntriesFromPrefs(prefs);
    final filtered = entries.where((entry) => !(_isSameDate(entry.date, date))).toList();
    await prefs.setString(_workoutLocalKey, jsonEncode(filtered.map((entry) => entry.toMap()).toList()));
  }

  double averageSleepHours(List<SleepEntry> entries) {
    if (entries.isEmpty) return 0;
    final total = entries.fold<double>(0.0, (sum, entry) => sum + entry.duration.inMinutes / 60.0);
    return total / entries.length;
  }

  int weeklyWorkoutMinutes(List<WorkoutEntry> entries) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 6));
    return entries
        .where((entry) => entry.date.isAfter(sevenDaysAgo) || _isSameDay(entry.date, sevenDaysAgo))
        .fold(0, (sum, entry) => sum + entry.durationMinutes);
  }

  int sleepConsistencyScore(List<SleepEntry> entries) {
    if (entries.isEmpty) return 0;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 6));
    final recentDayCount = entries
        .where((entry) => entry.date.isAfter(sevenDaysAgo) || _isSameDay(entry.date, sevenDaysAgo))
        .map((entry) => DateTime(entry.date.year, entry.date.month, entry.date.day))
        .toSet()
        .length;
    return ((recentDayCount / 7.0) * 100).round();
  }

  int computeSleepScore(double averageHours) {
    if (averageHours <= 0) return 0;
    final deviation = (averageHours - 8.0).abs();
    final score = (100 - (deviation * 12.5)).clamp(0, 100);
    return score.round();
  }

  int computeWorkoutScore(int weeklyMinutes) {
    final normalized = (weeklyMinutes / 150.0) * 100.0;
    return normalized.clamp(0, 100).round();
  }

  int computeMentalHealthScore(List<SleepEntry> sleepEntries, List<WorkoutEntry> workoutEntries) {
    final sleepHours = averageSleepHours(sleepEntries);
    final sleepScore = computeSleepScore(sleepHours);
    final consistency = sleepConsistencyScore(sleepEntries);
    final workoutMinutes = weeklyWorkoutMinutes(workoutEntries);
    final workoutScore = computeWorkoutScore(workoutMinutes);

    final weighted = (sleepScore * 0.55) + (workoutScore * 0.30) + (consistency * 0.15);
    return weighted.clamp(1, 100).round();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveLocalSleepEntry(SleepEntry entry) async {
    final prefs = await _prefsProvider();
    final entries = await _loadLocalSleepEntriesFromPrefs(prefs);
    final updatedEntries = entries.where((existing) => !(_isSameDate(existing.date, entry.date))).toList();
    updatedEntries.add(entry);
    updatedEntries.sort((a, b) => b.date.compareTo(a.date));
    await prefs.setString(_sleepLocalKey, jsonEncode(updatedEntries.map((item) => item.toMap()).toList()));
  }

  Future<void> _saveLocalWorkoutEntry(WorkoutEntry entry) async {
    final prefs = await _prefsProvider();
    final entries = await _loadLocalWorkoutEntriesFromPrefs(prefs);
    final updatedEntries = entries.where((existing) => !(_isSameDate(existing.date, entry.date))).toList();
    updatedEntries.add(entry);
    updatedEntries.sort((a, b) => b.date.compareTo(a.date));
    await prefs.setString(_workoutLocalKey, jsonEncode(updatedEntries.map((item) => item.toMap()).toList()));
  }

  Future<List<SleepEntry>> _loadLocalSleepEntries() async {
    final prefs = await _prefsProvider();
    return _loadLocalSleepEntriesFromPrefs(prefs);
  }

  Future<List<SleepEntry>> _loadLocalSleepEntriesFromPrefs(SharedPreferences prefs) async {
    final raw = prefs.getString(_sleepLocalKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => SleepEntry.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<List<WorkoutEntry>> _loadLocalWorkoutEntries() async {
    final prefs = await _prefsProvider();
    return _loadLocalWorkoutEntriesFromPrefs(prefs);
  }

  Future<List<WorkoutEntry>> _loadLocalWorkoutEntriesFromPrefs(SharedPreferences prefs) async {
    final raw = prefs.getString(_workoutLocalKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => WorkoutEntry.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  static const String _sleepLocalKey = 'wellness_sleep_entries';
  static const String _workoutLocalKey = 'wellness_workout_entries';
}
