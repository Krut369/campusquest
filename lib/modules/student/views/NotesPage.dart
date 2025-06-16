import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../controllers/login_controller.dart';
import '../../../widgets/chapter_details_page.dart';
import '../../../widgets/subject_card.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notesData = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get the current student ID from the login controller
      final loginController = Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;

      if (studentId == null) {
        throw Exception('Student ID is null.');
      }

      // Step 1: Get student's current courses based on enrollments
      final enrollments = await _supabase
          .from('enrollment')
          .select('course_id, semester_id')
          .eq('student_id', studentId)
          .eq('enrollment_status', 'Active');

      if (enrollments.isEmpty) {
        setState(() {
          _notesData = [];
          _isLoading = false;
        });
        return;
      }

      // Step 2: Get course details for all enrolled courses
      final courseIds = enrollments.map((e) => e['course_id']).toList();

      // Instead of using .in_ or .contains, manually filter each course ID
      List<Map<String, dynamic>> courses = [];
      for (var courseId in courseIds) {
        final result = await _supabase
            .from('course')
            .select('course_id, course_name')
            .eq('course_id', courseId);

        if (result.isNotEmpty) {
          courses.addAll(result);
        }
      }

      // Step 3: Fetch notes related to these courses
      List<Map<String, dynamic>> notesResult = await Future.wait(
        courses.map((course) async {
          // Get notes for this course
          final notes = await _supabase
              .from('notes')
              .select('*')
              .eq('course_id', course['course_id']);

          // Format course notes for display
          return {
            'code': 'CRS${course['course_id']}',
            'name': course['course_name'],
            'chapters': notes.map<Map<String, String>>((note) {
              return {
                'title': note['title'],
                'description': note['description'] ?? 'No description available',
                'file_path': note['file_path'] ?? '',
                'id': note['note_id'].toString(),
              };
            }).toList(),
          };
        }),
      ).then((list) => list.cast<Map<String, dynamic>>());

      // Filter out courses with no notes
      final notesWithContent = notesResult
          .where((courseNotes) => (courseNotes['chapters'] as List).isNotEmpty)
          .toList();

      setState(() {
        _notesData = notesWithContent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load notes: ${e.toString()}';
        _isLoading = false;
      });
      print('Error fetching notes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Match the dark background of the image
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notes / Materials',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchNotes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _notesData.isEmpty
          ? const Center(child: Text('No notes available for your courses.', style: TextStyle(color: Colors.black)))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 columns to match the image
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8, // Adjust to make folders more square
          ),
          itemCount: _notesData.length,
          itemBuilder: (context, index) {
            final note = _notesData[index];
            final chapterCount = (note['chapters'] as List).length;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotesViewPage(
                      courseId: note['code'],
                      courseName: note['name'],
                      chapters: note['chapters'],
                      notes: [],
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder,
                    size: 80,
                    color: Colors.deepPurple, // Blue folder icon to match the image
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note['name'],
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$chapterCount items',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 6.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}