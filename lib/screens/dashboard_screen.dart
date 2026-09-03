import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:student_app/services/database_service.dart';
import 'package:student_app/screens/todo_list_screen.dart';

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Map<String, dynamic>>> _syllabiFuture;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchData();
  }

  void _fetchData() {
    // Get the database service and fetch the syllabi
    _syllabiFuture = Provider.of<DatabaseService>(context, listen: false).fetchSyllabi();
  }

  Future<void> _refresh() async {
    setState(() {
      _fetchData();
    });
  }

  Future<void> _deleteSyllabus(String id) async {
    try {
      await Provider.of<DatabaseService>(context, listen: false).deleteSyllabus(id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syllabus deleted successfully.')),
      );
      _refresh(); // Reload the data after deletion
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  int _weekdayFromString(String dayStr) {
    final d = dayStr.toLowerCase();
    if (d.contains('mon')) return DateTime.monday;
    if (d.contains('tue')) return DateTime.tuesday;
    if (d.contains('wed')) return DateTime.wednesday;
    if (d.contains('thu')) return DateTime.thursday;
    if (d.contains('fri')) return DateTime.friday;
    if (d.contains('sat')) return DateTime.saturday;
    if (d.contains('sun')) return DateTime.sunday;
    return -1;
  }

  List<Map<String, dynamic>> _getRecurringClasses(List<Map<String, dynamic>> syllabiList) {
    List<Map<String, dynamic>> classes = [];
    for (var row in syllabiList) {
      final rawJson = row['raw_json'] as Map<String, dynamic>? ?? {};
      final courseInfo = rawJson['course_info'] as Map<String, dynamic>? ?? {};
      final courseCode = courseInfo['course_code'] ?? 'Unknown Course';
      final schedule = courseInfo['schedule'] as List<dynamic>? ?? [];

      for (var session in schedule) {
        final dayStr = session['day_of_week']?.toString() ?? '';
        final weekday = _weekdayFromString(dayStr);
        if (weekday != -1) {
          classes.add({
            'is_class': true,
            'course_code': courseCode,
            'name': 'Class',
            'type': 'Lecture/Studio',
            'weekday': weekday,
            'start_time': session['start_time'] ?? '',
            'end_time': session['end_time'] ?? '',
            'location': session['location'] ?? 'TBD',
          });
        }
      }
    }
    return classes;
  }

  /// Parses the raw database JSON rows into individual calendar events
  Map<DateTime, List<dynamic>> _getEventsForSyllabi(List<Map<String, dynamic>> syllabiList) {
    Map<DateTime, List<dynamic>> events = {};
    for (var row in syllabiList) {
      final rawJson = row['raw_json'] as Map<String, dynamic>? ?? {};
      final courseInfo = rawJson['course_info'] as Map<String, dynamic>? ?? {};
      final courseCode = courseInfo['course_code'] ?? 'Unknown Course';
      final assignments = rawJson['assignments_and_exams'] as List<dynamic>? ?? [];

      for (var task in assignments) {
        final dateStr = task['due_date']?.toString() ?? '';
        try {
          // TableCalendar relies on UTC dates for accurate equality checks
          final parsedDate = DateTime.parse(dateStr);
          final date = DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day);
          
          // Attach course code to the task so it looks clear in the daily agenda
          final taskWithCourse = Map<String, dynamic>.from(task);
          taskWithCourse['course_code'] = courseCode;

          events.putIfAbsent(date, () => []).add(taskWithCourse);
        } catch (e) {
          // Silently skip missing or unparseable dates
        }
      }
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Semester'),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'To-Do List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TodoListScreen()),
              ).then((_) => _refresh()); // Refresh when returning
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _syllabiFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error loading data: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No syllabi uploaded yet.\nGo to the Syllabus tab to add one!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            final syllabiList = snapshot.data!;
            final eventsMap = _getEventsForSyllabi(syllabiList);
            final recurringClasses = _getRecurringClasses(syllabiList);

            List<dynamic> getEventsForDay(DateTime day) {
              final date = DateTime.utc(day.year, day.month, day.day);
              final dayEvents = List<dynamic>.from(eventsMap[date] ?? []);
              for (var cls in recurringClasses) {
                if (cls['weekday'] == day.weekday) {
                  dayEvents.add(cls);
                }
              }
              return dayEvents;
            }

            final normalizedSelected = _selectedDay ?? _focusedDay;
            final selectedEvents = getEventsForDay(normalizedSelected);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your semester at a glance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('${syllabiList.length} course${syllabiList.length == 1 ? '' : 's'} tracked • ${selectedEvents.length} item${selectedEvents.length == 1 ? '' : 's'} for ${normalizedSelected.month}/${normalizedSelected.day}', style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 14)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoPill(label: 'Courses', value: '${syllabiList.length}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoPill(label: 'Today', value: '${selectedEvents.length}'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('My courses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                ),
                ...syllabiList.map((row) {
                final syllabusId = row['id']?.toString() ?? '';
                final fileName = row['file_name'] ?? 'Unknown File';
                
                // Supabase returns the JSONB column directly as a Dart Map!
                final rawJson = row['raw_json'] as Map<String, dynamic>? ?? {};
                final courseInfo = rawJson['course_info'] as Map<String, dynamic>? ?? {};
                final courseCode = courseInfo['course_code'] ?? 'Unknown Course';
                final courseName = courseInfo['course_name'] ?? '';
                final attendancePolicy = courseInfo['attendance_policy'] ?? 'No attendance policy extracted.';
                final schedule = courseInfo['schedule'] as List<dynamic>? ?? [];
                final assignments = rawJson['assignments_and_exams'] as List<dynamic>? ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(child: Icon(Icons.menu_book_rounded, color: Color(0xFF4F46E5), size: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(courseCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF0F172A), letterSpacing: -0.3)),
                              Text(courseName.isNotEmpty ? courseName : 'Extracted from $fileName', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.transparent,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (schedule.isNotEmpty) ...[
                                const Text('Class schedule', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5), letterSpacing: -0.2)),
                                const SizedBox(height: 8),
                                ...schedule.map((session) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '${session['day_of_week']}s: ${session['start_time']} - ${session['end_time']} (${session['location']})',
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                                  ),
                                )),
                                const SizedBox(height: 12),
                              ],
                              const Text('Attendance policy', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5), letterSpacing: -0.2)),
                              const SizedBox(height: 6),
                              Text(
                                attendancePolicy,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text('Key dates & assignments', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5), letterSpacing: -0.2)),
                        ),
                      ),
                      if (assignments.isEmpty)
                        const Padding(padding: EdgeInsets.all(16), child: Text('No assignments found.', style: TextStyle(color: Color(0xFF94A3B8)))),
                      ...assignments.map((task) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEEF2FF),
                              foregroundColor: Color(0xFF4F46E5),
                              child: Icon(Icons.event_note, size: 20),
                            ),
                            title: Text(task['name'] ?? 'Task', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            subtitle: Text('${task['type'] ?? 'Assignment'} • Due: ${task['due_date'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF64748B))),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                task['weight'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569), fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 1),
                      ButtonBar(
                        alignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Edit feature coming soon!')),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: () => syllabusId.isNotEmpty ? _deleteSyllabus(syllabusId) : null,
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                }),
                
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0, top: 8.0),
                  child: Text('Semester calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                ),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: getEventsForDay,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                      weekendStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    calendarStyle: const CalendarStyle(
                      markerDecoration: BoxDecoration(color: Color(0xFF818CF8), shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle),
                      todayTextStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      selectedDecoration: BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                      selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(child: Text('No assignments due on this day.', style: TextStyle(color: Color(0xFF94A3B8)))),
                  )
                else
                  ...selectedEvents.map((task) {
                    if (task['is_class'] == true) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), foregroundColor: Color(0xFF2563EB), child: Icon(Icons.school, size: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${task['course_code']} class', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                  Text('${task['start_time']} - ${task['end_time']} • ${task['location']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final isCompleted = task['completed'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCompleted ? Icons.check_circle : Icons.assignment_turned_in_outlined,
                            color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['name'] ?? 'Task',
                                  style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600, color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
                                ),
                                Text('${task['course_code']} • ${task['type']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(task['weight'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}