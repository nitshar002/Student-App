import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_app/services/database_service.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late Future<List<Map<String, dynamic>>> _syllabiFuture;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    _syllabiFuture = Provider.of<DatabaseService>(context, listen: false).fetchSyllabi();
  }

  Future<void> _toggleTaskStatus(
    String syllabusId,
    Map<String, dynamic> fullJson,
    Map<String, dynamic> task,
    bool? newValue,
  ) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    // Update UI optimistically
    setState(() {
      task['completed'] = newValue ?? false;
    });

    try {
      // Save the updated JSON back to Supabase
      await databaseService.updateSyllabusData(syllabusId, fullJson);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
      // Revert if it failed
      setState(() {
        task['completed'] = !(newValue ?? false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master To-Do List'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _syllabiFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tasks found. Upload a syllabus!'));
          }

          // Extract all tasks across all syllabi
          List<_TaskReference> allTasks = [];
          for (var row in snapshot.data!) {
            final syllabusId = row['id']?.toString() ?? '';
            final rawJson = row['raw_json'] as Map<String, dynamic>? ?? {};
            final courseInfo = rawJson['course_info'] as Map<String, dynamic>? ?? {};
            final courseCode = courseInfo['course_code'] ?? 'Unknown Course';
            final assignments = rawJson['assignments_and_exams'] as List<dynamic>? ?? [];

            for (var task in assignments) {
              if (task is Map<String, dynamic>) {
                allTasks.add(_TaskReference(
                  syllabusId: syllabusId,
                  courseCode: courseCode,
                  fullJson: rawJson,
                  taskData: task,
                ));
              }
            } 
          }

          // Sort all tasks sequentially by due date
          allTasks.sort((a, b) {
            final dateA = DateTime.tryParse(a.taskData['due_date']?.toString() ?? '') ?? DateTime(2100);
            final dateB = DateTime.tryParse(b.taskData['due_date']?.toString() ?? '') ?? DateTime(2100);
            return dateA.compareTo(dateB);
          });

          if (allTasks.isEmpty) {
            return const Center(child: Text('No tasks found in your syllabi.', style: TextStyle(color: Color(0xFF94A3B8))));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allTasks.length,
            itemBuilder: (context, index) {
              final ref = allTasks[index];
              final isCompleted = ref.taskData['completed'] == true;
              final dueDate = ref.taskData['due_date'] ?? 'No date';
              final name = ref.taskData['name'] ?? 'Unnamed Task';
              final type = ref.taskData['type'] ?? 'Task';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  value: isCompleted,
                  onChanged: (bool? value) => _toggleTaskStatus(ref.syllabusId, ref.fullJson, ref.taskData, value),
                  title: Text(
                    '$name ($type)',
                    style: TextStyle(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('${ref.courseCode} • Due: $dueDate', style: const TextStyle(color: Color(0xFF64748B))),
                  activeColor: const Color(0xFF4F46E5), // Modern Indigo
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                  checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A helper class to keep track of where a task came from so we can update it in the database
class _TaskReference {
  final String syllabusId;
  final String courseCode;
  final Map<String, dynamic> fullJson;
  final Map<String, dynamic> taskData;

  _TaskReference({required this.syllabusId, required this.courseCode, required this.fullJson, required this.taskData});
}