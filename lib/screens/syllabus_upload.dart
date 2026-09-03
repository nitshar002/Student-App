import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:student_app/services/ai_service.dart';
import 'package:student_app/services/database_service.dart';

class SyllabusUploadScreen extends StatefulWidget {
  const SyllabusUploadScreen({super.key});

  @override
  State<SyllabusUploadScreen> createState() => _SyllabusUploadScreenState();
}

class _SyllabusUploadScreenState extends State<SyllabusUploadScreen> {
  bool _isLoading = false;
  String? _fileName;
  String? _fileSize;
  String? _parsedJsonResult; // Stores the response from Gemini

  Future<void> _pickSyllabus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Using FileType.any makes path resolving completely stable on Android emulators
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: kIsWeb, // Required for the Web to load the file into bytes automatically
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        final file = result.files.single;
        
        setState(() {
          _fileName = file.name;
          _fileSize = '${(file.size / 1024).toStringAsFixed(1)} KB';
        });
        
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: $_fileName')),
        );

        // --- CONNECT TO GEMINI ENGINE ---
        // Access your global provider
        final gemini = Provider.of<GeminiService>(context, listen: false);
        
        // --- EXTRACT REAL TEXT FROM PDF ---
        String extractedText = '';
        if (file.name.toLowerCase().endsWith('.pdf')) {
          // 1. Safely read the file bytes depending on the platform (Web vs Mobile/Desktop)
          final bytes = kIsWeb ? file.bytes : File(file.path!).readAsBytesSync();
          
          if (bytes != null) {
            // 2. Load it into a Syncfusion PDF Document
            final PdfDocument document = PdfDocument(inputBytes: bytes);
            // 3. Extract all the text from the pages
            extractedText = PdfTextExtractor(document).extractText();
            // 4. Clean up memory
            document.dispose();
          }
        } else {
          // Fallback: If you upload something that isn't a PDF (like a Word doc), we fall back to mock data for now.
          extractedText = "Syllabus for CS 241. Midterm Exam: October 15th (25%). Final Project due Dec 5th (35%). Quizzes weekly (40%).";
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warning: Only PDFs are fully supported right now.')));
          }
        }
        
        // Call your service layer feature
        final jsonResponse = await gemini.parseSyllabusText(file.name, extractedText);
        
        setState(() {
          _parsedJsonResult = jsonResponse;
        });

        // --- SAVE TO SUPABASE ---
        if (gemini.currentSyllabus != null) {
          try {
            if (!mounted) return;

            final db = Provider.of<DatabaseService>(context, listen: false);
            await db.saveSyllabus(gemini.currentSyllabus!);
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Successfully saved to Supabase! 🚀')),
            );
          } catch (dbError) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save to database: $dbError')),
            );
          }
        } else {
          // If the AI service failed, show the error message it returned.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_parsedJsonResult ?? 'An unknown AI error occurred.'), backgroundColor: Colors.redAccent),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Syllabus'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView( // Prevents layout overflows if text expands
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.cloud_upload_outlined,
                size: 100,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ),
              const SizedBox(height: 24),
              const Text(
                'Compile Your Semester',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload your course syllabi.\nOur system will extract assignments and deadlines automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // File Details Card if a file is loaded
              if (_fileName != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.description, color: Colors.redAccent, size: 36),
                    title: Text(
                      _fileName!, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(_fileSize ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _fileName = null;
                          _fileSize = null;
                          _parsedJsonResult = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Main Interactive Action Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickSyllabus,
                icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_open),
                label: Text(_isLoading ? 'Processing Document...' : 'Select Syllabus File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // AI Output Visualization Area
              if (_parsedJsonResult != null) ...[
                const SizedBox(height: 32),
                const Text(
                  'Extracted Structured Data:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    _parsedJsonResult!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}