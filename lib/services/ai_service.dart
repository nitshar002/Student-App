import 'dart:convert'; 
import 'dart:math'; // Added for exponential backoff math
import 'package:flutter/material.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:student_app/models/course_task.dart'; 

class GeminiService extends ChangeNotifier { 
  final String _apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  SyllabusData? _currentSyllabus;
  SyllabusData? get currentSyllabus => _currentSyllabus;

  GeminiService();
  
  Future<String> parseSyllabusText(String fileName, String rawText) async {
    _currentSyllabus = null; 
    notifyListeners();

    // 1. Offload date generation to Dart later. Keep the AI focused purely on extraction.
    final prompt = '''
    Analyze the following syllabus text. Extract all major assignments, exams, quizzes, and project due dates. 
    Also, extract the grading weightage breakdown (percentages), the attendance policy, and the regular class schedule (meeting days, times, and location). 
    
    Crucial: Format all dates strictly as YYYY-MM-DD. If the year is missing, assume the current year. If an exact day is missing, default to the 1st of the month.
    Crucial: If an assignment is recurring (e.g., "Weekly homework due every Tuesday"), do NOT generate all weeks. Instead, write the pattern clearly in the "due_date" field (e.g., "Every Tuesday").
    
    Return the output as a clean JSON structure matching this hierarchy:
    {
      "course_info": { 
        "course_code": "...",
        "course_name": "...",
        "attendance_policy": "...",
        "schedule": [
          {
            "day_of_week": "Monday",
            "start_time": "10:00 AM",
            "end_time": "11:30 AM",
            "location": "Room 101"
          }
        ]
      },
      "assignments_and_exams": [ 
        { "name": "...", "type": "...", "due_date": "...", "weight": "..." } 
      ]
    }
    
    Syllabus text:
    $rawText
    ''';
 
    if (_apiKey.isEmpty) {
      return 'Error: API key is missing. Please provide GEMINI_API_KEY as an environment variable.';
    }

    // 2. Use Gemini 1.5 Flash for better performance and fresh free tier limits
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    // 3. Add a built-in Exponential Backoff retry mechanism to catch 429/503 traffic spikes
    int maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await model.generateContent([Content.text(prompt)]);
        String jsonResult = response.text ?? '{}';
        
        // Note: With responseMimeType: 'application/json', Gemini guarantees 
        // raw JSON without the markdown ```json blocks. You rarely need to strip it now!
        jsonResult = jsonResult.replaceAll('```json', '').replaceAll('```', '').trim();

        _currentSyllabus = SyllabusData(fileName: fileName, rawJsonResult: jsonResult);
        notifyListeners(); 

        return jsonResult;
      } catch (e) {
        String errorMsg = e.toString();
        // If we hit rate limits or temporary server overload, wait and retry
        if ((errorMsg.contains('429') || errorMsg.contains('503')) && attempt < maxRetries - 1) {
          final waitTime = Duration(seconds: pow(2, attempt + 1).toInt() + Random().nextInt(2));
          debugPrint("Traffic limit hit. Retrying in ${waitTime.inSeconds}s (Attempt ${attempt + 1}/$maxRetries)...");
          await Future.delayed(waitTime);
          continue; 
        }
        
        return 'Error connecting to Gemini API: $e';
      }
    }
    return 'Error: Rate limit exceeded. Please try again in a moment.';
  }

  Future<String> generateInterviewRoleInsights({required String roleTitle, required String roleDescription}) async {
    final prompt = '''
You are helping a student prepare for interviews.

Create a short, practical interview prep brief for the role below.
Return valid JSON with these keys:
{
  "role_summary": "...",
  "core_skills": ["..."],
  "common_interview_topics": ["..."],
  "questions_to_prepare_for": ["..."],
  "tips": ["..."]
}

Role title: $roleTitle
Role description: $roleDescription
''';

    if (_apiKey.isEmpty) {
      return 'Error: API key is missing. Please provide GEMINI_API_KEY as an environment variable.';
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '{}';
    } catch (e) {
      return 'Error connecting to Gemini API: $e';
    }
  }

  Future<Map<String, dynamic>> generateMockInterviewTurn({
    required String roleTitle,
    required String roleDescription,
    String? roleSummary,
    String? question,
    String? userAnswer,
  }) async {
    final prompt = '''
You are running a mock interview for a student.

Role title: $roleTitle
Role description: $roleDescription
Role summary: ${roleSummary ?? 'N/A'}

If this is the first turn, create a realistic first interview question.
If the student already answered a question, provide supportive feedback and the next question.
Return valid JSON with exactly these keys:
{
  "feedback": "...",
  "next_question": "...",
  "score": 7
}

${question == null ? 'This is the first turn.' : 'Current question: $question\nStudent answer: $userAnswer'}
''';

    if (_apiKey.isEmpty) {
      return _fallbackMockInterviewTurn(roleTitle: roleTitle, question: question, userAnswer: userAnswer);
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final rawResponse = response.text ?? '{}';
      final decoded = jsonDecode(rawResponse);
      if (decoded is Map<String, dynamic>) {
        return {
          'feedback': decoded['feedback']?.toString() ?? '',
          'next_question': decoded['next_question']?.toString() ?? '',
          'score': int.tryParse(decoded['score']?.toString() ?? '') ?? 0,
        };
      }
    } catch (_) {}

    return _fallbackMockInterviewTurn(roleTitle: roleTitle, question: question, userAnswer: userAnswer);
  }

  Map<String, dynamic> _fallbackMockInterviewTurn({
    required String roleTitle,
    String? question,
    String? userAnswer,
  }) {
    if (question == null || userAnswer == null || userAnswer.trim().isEmpty) {
      final starterQuestion = roleTitle.toLowerCase().contains('engineer')
          ? 'Tell me about yourself and why this role interests you.'
          : 'Tell me about your background and what interested you in this role.';

      return {
        'feedback': 'Let’s start with a concise introduction. Highlight your experience and why this opportunity fits your goals.',
        'next_question': starterQuestion,
        'score': 0,
      };
    }

    final nextQuestion = roleTitle.toLowerCase().contains('engineer')
        ? 'Describe a project you are proud of and explain how you contributed to the result.'
        : 'Tell me about a time you solved a problem under pressure and what you learned.';

    return {
      'feedback': 'That was a strong start. You can make it even better by adding one specific example and tying it back to the role.',
      'next_question': nextQuestion,
      'score': 7,
    };
  }

  static Map<String, dynamic> parseRoleInsightResponse(String response) {
    try {
      final decoded = jsonDecode(response);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return {
      'role_summary': response,
      'core_skills': <String>[],
      'common_interview_topics': <String>[],
      'questions_to_prepare_for': <String>[],
      'tips': <String>[],
    };
  }

  void clearSyllabus() {
    _currentSyllabus = null;
    notifyListeners();
  }
}