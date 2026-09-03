import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:student_app/models/course_task.dart';

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? college,
    String? major,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final userId = response.user?.id;
    if (userId != null) {
      try {
        await _client.from('profiles').upsert({
          'id': userId,
          'full_name': fullName,
          'email': email,
          'college': college ?? '',
          'major': major ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
      } on PostgrestException catch (e) {
        if (e.code == '42501') {
          throw Exception(
            'Profile creation is blocked by Supabase Row Level Security. '
            'Please apply the SQL policy in supabase/profiles_rls.sql to your Supabase project.',
          );
        }
        rethrow;
      }
    }

    return response;
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return response;
  }

  Future<void> updateProfile({String? fullName, String? college, String? major}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (college != null) updates['college'] = college;
    if (major != null) updates['major'] = major;

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  /// Example: Save extracted syllabus data to a 'syllabi' table in Supabase
  Future<void> saveSyllabus(SyllabusData syllabus) async {
    try {
      // The 'raw_json' column in Supabase is of type JSONB, so it expects a Map, not a string.
      final Map<String, dynamic> jsonData = jsonDecode(syllabus.rawJsonResult);

      await _client.from('syllabi').insert({
        'file_name': syllabus.fileName,
        'raw_json': jsonData, // Pass the parsed map
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // In a real app, you might want to log this or handle it specifically
      print('Error saving syllabus to Supabase: $e');
      rethrow; 
    }
  }

  /// Example: Fetch saved syllabi
  Future<List<Map<String, dynamic>>> fetchSyllabi() async {
    final response = await _client.from('syllabi').select().order('created_at', ascending: false);
    return response;
  }

  /// Update an existing syllabus (useful for saving completed tasks)
  Future<void> updateSyllabusData(String id, Map<String, dynamic> updatedJson) async {
    try {
      await _client.from('syllabi').update({'raw_json': updatedJson}).eq('id', id);
    } catch (e) {
      print('Error updating syllabus data: $e');
      rethrow;
    }
  }

  /// Delete a saved syllabus by its ID
  Future<void> deleteSyllabus(String id) async {
    try {
      await _client.from('syllabi').delete().eq('id', id);
    } catch (e) {
      print('Error deleting syllabus: $e');
      rethrow;
    }
  }
}