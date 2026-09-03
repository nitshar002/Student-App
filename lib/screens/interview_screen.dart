import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_app/services/ai_service.dart';

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmittingAnswer = false;
  bool _interviewStarted = false;
  Map<String, dynamic> _insights = {};
  String _currentQuestion = '';
  String _feedback = '';
  int _currentRound = 0;
  static const int _maxRounds = 3;
  List<Map<String, String>> _conversation = [];
  String _roleTitle = '';
  String _roleDescription = '';

  @override
  void dispose() {
    _roleController.dispose();
    _descriptionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _searchRole(BuildContext context) async {
    final role = _roleController.text.trim();
    final description = _descriptionController.text.trim();

    if (role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the job title or role you want to prep for.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _insights = {};
      _interviewStarted = false;
      _conversation.clear();
      _feedback = '';
      _currentQuestion = '';
      _currentRound = 0;
      _answerController.clear();
    });

    final service = context.read<GeminiService>();
    final response = await service.generateInterviewRoleInsights(
      roleTitle: role,
      roleDescription: description.isEmpty ? 'General role' : description,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _insights = GeminiService.parseRoleInsightResponse(response);
      _roleTitle = role;
      _roleDescription = description.isEmpty ? 'General role' : description;
    });

    await _startMockInterview();
  }

  Future<void> _startMockInterview() async {
    if (_roleTitle.isEmpty) return;

    setState(() {
      _isLoading = true;
      _feedback = '';
      _currentQuestion = '';
      _interviewStarted = false;
      _conversation.clear();
      _answerController.clear();
    });

    final service = context.read<GeminiService>();
    final turn = await service.generateMockInterviewTurn(
      roleTitle: _roleTitle,
      roleDescription: _roleDescription,
      roleSummary: (_insights['role_summary'] ?? '').toString(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _interviewStarted = true;
      _currentRound = 0;
      _currentQuestion = turn['next_question']?.toString() ?? '';
      _feedback = turn['feedback']?.toString() ?? '';
      _answerController.clear();
    });
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your response before continuing.')),
      );
      return;
    }

    setState(() {
      _isSubmittingAnswer = true;
    });

    final service = context.read<GeminiService>();
    final turn = await service.generateMockInterviewTurn(
      roleTitle: _roleTitle,
      roleDescription: _roleDescription,
      roleSummary: (_insights['role_summary'] ?? '').toString(),
      question: _currentQuestion,
      userAnswer: answer,
    );

    if (!mounted) return;

    final nextRound = _currentRound + 1;
    final nextQuestion = turn['next_question']?.toString() ?? '';

    setState(() {
      _conversation.add({
        'question': _currentQuestion,
        'answer': answer,
        'feedback': turn['feedback']?.toString() ?? '',
      });
      _feedback = turn['feedback']?.toString() ?? '';
      _currentRound = nextRound;
      _answerController.clear();
      _isSubmittingAnswer = false;

      if (nextRound >= _maxRounds || nextQuestion.isEmpty) {
        _currentQuestion = '';
        _interviewStarted = true;
      } else {
        _currentQuestion = nextQuestion;
      }
    });
  }

  Widget _buildSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.brightness_1, size: 8, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(color: Color(0xFF334155), height: 1.4))),
                ],
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleSummary = (_insights['role_summary'] ?? '').toString();
    final coreSkills = List<String>.from((_insights['core_skills'] ?? []).map((item) => item.toString()));
    final interviewTopics = List<String>.from((_insights['common_interview_topics'] ?? []).map((item) => item.toString()));
    final questions = List<String>.from((_insights['questions_to_prepare_for'] ?? []).map((item) => item.toString()));
    final tips = List<String>.from((_insights['tips'] ?? []).map((item) => item.toString()));

    return Scaffold(
      appBar: AppBar(title: const Text('AI Interview Prep')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find your interview role', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Search for the kind of job you want to prepare for and we will build your interview starter guide.', style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _roleController,
                    decoration: const InputDecoration(
                      labelText: 'Job title or role',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Software Engineer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Describe the role (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Tell us about the company, responsibilities, or stack you want to target.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _searchRole(context),
                      icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                      label: Text(_isLoading ? 'Searching...' : 'Search role'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_insights.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What you will get', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Once you search a role, we will summarize what the job is about, highlight the core skills to practice, and suggest interview questions to prepare for.'),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Interview prep brief', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(roleSummary, style: const TextStyle(color: Color(0xFF334155), height: 1.5)),
                        _buildSection('Core skills', coreSkills),
                        _buildSection('Common interview topics', interviewTopics),
                        _buildSection('Questions to prepare for', questions),
                        _buildSection('Tips', tips),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Mock interview practice', style: theme.textTheme.titleMedium),
                            ),
                            TextButton.icon(
                              onPressed: _isLoading ? null : _startMockInterview,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Restart'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Answer the prompt as if you were in the interview. We will give you feedback and move to the next question.', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Center(child: Padding(padding: EdgeInsets.only(top: 12), child: CircularProgressIndicator()))
                        else if (!_interviewStarted)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startMockInterview,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start mock interview'),
                            ),
                          )
                        else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Question ${_currentRound + 1} of $_maxRounds', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                                const SizedBox(height: 8),
                                Text(
                                  _currentQuestion.isEmpty ? 'You have completed the mock interview. Restart to practice again.' : _currentQuestion,
                                  style: const TextStyle(color: Color(0xFF0F172A), height: 1.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _answerController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Your response',
                              border: OutlineInputBorder(),
                              hintText: 'Reply as if you were answering this interview question out loud.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmittingAnswer ? null : _submitAnswer,
                              icon: _isSubmittingAnswer
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.send),
                              label: Text(_isSubmittingAnswer ? 'Submitting...' : 'Submit answer'),
                            ),
                          ),
                          if (_feedback.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Coach feedback', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4338CA))),
                                  const SizedBox(height: 6),
                                  Text(_feedback, style: const TextStyle(color: Color(0xFF312E81), height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                          if (_conversation.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Conversation so far', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8),
                            ..._conversation.map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Q: ${entry['question']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 6),
                                        Text('A: ${entry['answer']}', style: const TextStyle(color: Color(0xFF334155), height: 1.4)),
                                        const SizedBox(height: 6),
                                        Text('Feedback: ${entry['feedback']}', style: const TextStyle(color: Color(0xFF4F46E5), height: 1.4)),
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
