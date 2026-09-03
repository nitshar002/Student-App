import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_app/models/wellness_data.dart';
import 'package:student_app/services/wellness_service.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _bedtime;
  TimeOfDay? _wakeTime;
  String _sleepNote = '';

  DateTime _selectedWorkoutDate = DateTime.now();
  final TextEditingController _workoutDurationController = TextEditingController();
  String _activityType = 'Walking';
  String _workoutNote = '';

  List<SleepEntry> _sleepEntries = [];
  List<WorkoutEntry> _workoutEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _workoutDurationController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final service = Provider.of<WellnessService>(context, listen: false);
    final sleepEntries = await service.loadSleepEntries();
    final workoutEntries = await service.loadWorkoutEntries();
    if (!mounted) return;
    setState(() {
      _sleepEntries = sleepEntries;
      _workoutEntries = workoutEntries;
      _isLoading = false;
    });
  }

  Future<void> _saveSleepEntry() async {
    if (_bedtime == null || _wakeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both bedtime and wake-up time.')),
      );
      return;
    }

    final entry = SleepEntry(
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      bedtimeHour: _bedtime!.hour,
      bedtimeMinute: _bedtime!.minute,
      wakeHour: _wakeTime!.hour,
      wakeMinute: _wakeTime!.minute,
      note: _sleepNote.trim(),
    );

    final service = Provider.of<WellnessService>(context, listen: false);
    try {
      await service.saveSleepEntry(entry);
      setState(() {
        final updatedEntries = _sleepEntries.where((existing) => !(_isSameDate(existing.date, entry.date))).toList();
        updatedEntries.add(entry);
        updatedEntries.sort((a, b) => b.date.compareTo(a.date));
        _sleepEntries = updatedEntries;
      });
      await _loadEntries();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep log saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save sleep log: $error')),
      );
    }
  }

  Future<void> _saveWorkoutEntry() async {
    final minutes = int.tryParse(_workoutDurationController.text);
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid workout duration in minutes.')),
      );
      return;
    }

    final entry = WorkoutEntry(
      date: DateTime(_selectedWorkoutDate.year, _selectedWorkoutDate.month, _selectedWorkoutDate.day),
      durationMinutes: minutes,
      activityType: _activityType,
      note: _workoutNote.trim(),
    );

    final service = Provider.of<WellnessService>(context, listen: false);
    await service.saveWorkoutEntry(entry);
    await _loadEntries();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout log saved successfully.')),
    );
  }

  Future<void> _deleteWorkoutEntry(DateTime date) async {
    final service = Provider.of<WellnessService>(context, listen: false);
    await service.deleteWorkoutEntry(date);
    await _loadEntries();
  }

  Duration? get _sleepDuration {
    if (_bedtime == null || _wakeTime == null) return null;
    final bedtime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _bedtime!.hour, _bedtime!.minute);
    var wake = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _wakeTime!.hour, _wakeTime!.minute);
    if (wake.isBefore(bedtime) || wake.isAtSameMomentAs(bedtime)) {
      wake = wake.add(const Duration(days: 1));
    }
    return wake.difference(bedtime);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime(bool isBedtime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedtime
          ? (_bedtime ?? const TimeOfDay(hour: 22, minute: 0))
          : (_wakeTime ?? const TimeOfDay(hour: 7, minute: 0)),
    );
    if (picked == null) return;

    setState(() {
      if (isBedtime) {
        _bedtime = picked;
      } else {
        _wakeTime = picked;
      }
    });
  }

  Future<void> _pickDate({required bool workout}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: workout ? _selectedWorkoutDate : _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() {
      if (workout) {
        _selectedWorkoutDate = picked;
      } else {
        _selectedDate = picked;
      }
    });
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatPastWeekLabel(DateTime date) {
    final today = DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final difference = normalizedToday.difference(normalizedDate).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${date.month}/${date.day}';
  }

  double get _averageSleepHours {
    if (_sleepEntries.isEmpty) return 0.0;
    final totalHours = _sleepEntries.fold<double>(0, (sum, entry) => sum + entry.duration.inMinutes / 60.0);
    return totalHours / _sleepEntries.length;
  }

  int get _weeklyWorkoutMinutes {
    final service = Provider.of<WellnessService>(context, listen: false);
    return service.weeklyWorkoutMinutes(_workoutEntries);
  }

  int get _mentalHealthScore {
    final service = Provider.of<WellnessService>(context, listen: false);
    return service.computeMentalHealthScore(_sleepEntries, _workoutEntries);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mental health score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$_mentalHealthScore / 100',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Avg sleep: ${_averageSleepHours.toStringAsFixed(1)}h', style: theme.textTheme.bodyLarge),
                                  Text('Workout: $_weeklyWorkoutMinutes min', style: theme.textTheme.bodyLarge),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Score formula: 55% sleep quality, 30% workouts, 15% sleep consistency.', style: TextStyle(color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          const Text('Sleep quality is based on how close your average sleep is to 8 hours; workouts are weighted by the last 7 days.', style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Sleep tracker', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Log a night of sleep', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Pick any day from the past week if you missed a log.', style: TextStyle(color: Color(0xFF64748B))),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(7, (index) {
                              final day = DateTime.now().subtract(Duration(days: index));
                              final isSelected = _selectedDate.year == day.year && _selectedDate.month == day.month && _selectedDate.day == day.day;
                              return ChoiceChip(
                                label: Text(_formatPastWeekLabel(day)),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedDate = day;
                                  });
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _pickDate(workout: false),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}'),
                              ],
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bedtime'),
                            subtitle: Text(_bedtime != null ? _formatTimeOfDay(_bedtime!) : 'Tap to select bedtime'),
                            trailing: const Icon(Icons.bedtime),
                            onTap: () => _pickTime(true),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Wake-up time'),
                            subtitle: Text(_wakeTime != null ? _formatTimeOfDay(_wakeTime!) : 'Tap to select wake-up time'),
                            trailing: const Icon(Icons.wb_sunny),
                            onTap: () => _pickTime(false),
                          ),
                          const SizedBox(height: 12),
                          Text('Duration: ${_sleepDuration != null ? '${_sleepDuration!.inHours}h ${_sleepDuration!.inMinutes.remainder(60)}m' : 'Not set yet'}',
                              style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                          const SizedBox(height: 12),
                          TextField(
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => _sleepNote = value,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveSleepEntry,
                              child: const Text('Save Sleep Log'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Workout tracker', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Log a workout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => _pickDate(workout: true),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('${_selectedWorkoutDate.month}/${_selectedWorkoutDate.day}/${_selectedWorkoutDate.year}'),
                              ],
                            ),
                          ),
                          const Divider(),
                          DropdownButtonFormField<String>(
                            value: _activityType,
                            decoration: const InputDecoration(labelText: 'Activity type'),
                            items: const [
                              DropdownMenuItem(value: 'Walking', child: Text('Walking')),
                              DropdownMenuItem(value: 'Running', child: Text('Running')),
                              DropdownMenuItem(value: 'Yoga', child: Text('Yoga')),
                              DropdownMenuItem(value: 'Gym', child: Text('Gym')),
                              DropdownMenuItem(value: 'Cycling', child: Text('Cycling')),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _activityType = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _workoutDurationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration (minutes)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => _workoutNote = value,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveWorkoutEntry,
                              child: const Text('Save Workout Log'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sleep logs', style: TextStyle(color: Color(0xFF64748B))),
                                  Text('${_sleepEntries.length}', style: theme.textTheme.titleMedium),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Weekly workout', style: TextStyle(color: Color(0xFF64748B))),
                                  Text('$_weeklyWorkoutMinutes min', style: theme.textTheme.titleMedium),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Recent sleep logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_sleepEntries.isEmpty)
                    const Center(
                      child: Text('No sleep logs yet. Start by logging today’s night.', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  else
                    ..._sleepEntries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('${entry.date.month}/${entry.date.day}/${entry.date.year} • ${entry.duration.inHours}h ${entry.duration.inMinutes.remainder(60)}m'),
                          subtitle: Text('Bed: ${entry.formattedBedtime} · Wake: ${entry.formattedWake}${entry.note.isNotEmpty ? ' · ${entry.note}' : ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final service = Provider.of<WellnessService>(context, listen: false);
                              await service.deleteSleepEntry(entry.date);
                              await _loadEntries();
                            },
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  const Text('Recent workout logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_workoutEntries.isEmpty)
                    const Center(
                      child: Text('No workouts logged yet. Add your first session above.', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  else
                    ..._workoutEntries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('${entry.date.month}/${entry.date.day}/${entry.date.year} • ${entry.durationMinutes} min'),
                          subtitle: Text('${entry.activityType}${entry.note.isNotEmpty ? ' · ${entry.note}' : ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await _deleteWorkoutEntry(entry.date);
                            },
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
