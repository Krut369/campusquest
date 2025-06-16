import 'package:campusquest/controllers/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'SubMissionPage.dart'; // Updated SubmissionPage
import '../../../widgets/subject_card.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  _AssignmentsPageState createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _coursesData = [];
  String? _errorMessage;
  String _filter = 'All'; // Filter state: All, Due, Submitted

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final loginController = Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;

      if (studentId == null) {
        throw Exception('Student ID is null. Please log in.');
      }

      // Fetch enrollments
      final enrollments = await _supabase
          .from('enrollment')
          .select('course_id')
          .eq('student_id', studentId);

      if (enrollments.isEmpty) {
        setState(() {
          _coursesData = [];
          _isLoading = false;
        });
        return;
      }

      final courseIds = enrollments.map((e) => e['course_id'] as int).toSet().toList();

      // Fetch courses
      final courses = await _supabase
          .from('course')
          .select('course_id, course_name')
          .inFilter('course_id', courseIds);

      // Fetch assignments and submissions
      final assignmentsResponse = await _supabase
          .from('assignment')
          .select('assignment_id, course_id, title, due_date, description, file_path')
          .inFilter('course_id', courseIds);

      final submissionsResponse = await _supabase
          .from('submission')
          .select('assignment_id, submission_date')
          .eq('student_id', studentId);

      final submittedAssignmentIds =
      submissionsResponse.map((s) => s['assignment_id'] as int).toSet();

      // Process data
      List<Map<String, dynamic>> coursesWithAssignments = [];
      for (var course in courses) {
        final courseAssignments = assignmentsResponse
            .where((assignment) => assignment['course_id'] == course['course_id'])
            .map((assignment) {
          final dueDate = DateTime.parse(assignment['due_date']);
          final now = DateTime.now();
          final isSubmitted = submittedAssignmentIds.contains(assignment['assignment_id']);
          final isOverdue = dueDate.isBefore(now) && !isSubmitted;
          final isDueSoon = dueDate.difference(now).inDays <= 3 && !isSubmitted && !isOverdue;

          return {
            'id': assignment['assignment_id'],
            'title': assignment['title'] ?? 'Untitled',
            'description': assignment['description'] ?? '',
            'file_path': assignment['file_path'] ?? '',
            'due_date': dueDate,
            'formatted_due_date': DateFormat('MMM dd, yyyy').format(dueDate),
            'is_submitted': isSubmitted,
            'is_overdue': isOverdue,
            'is_due_soon': isDueSoon,
          };
        }).toList();

        // Apply filter
        var filteredAssignments = courseAssignments;
        if (_filter == 'Due') {
          filteredAssignments = courseAssignments
              .where((a) => !a['is_submitted'] && !a['is_overdue'])
              .toList();
        } else if (_filter == 'Submitted') {
          filteredAssignments = courseAssignments.where((a) => a['is_submitted']).toList();
        }

        if (filteredAssignments.isNotEmpty) {
          coursesWithAssignments.add({
            'code': 'CRS${course['course_id']}',
            'name': course['course_name'],
            'assignments': filteredAssignments,
          });
        }
      }

      setState(() {
        _coursesData = coursesWithAssignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load assignments: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Assignments', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
              _fetchAssignments();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'Due', child: Text('Due')),
              const PopupMenuItem(value: 'Submitted', child: Text('Submitted')),
            ],
            icon: const Icon(Icons.filter_list, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAssignments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _coursesData.isEmpty
          ? const Center(child: Text('No assignments found.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _coursesData.length,
        itemBuilder: (context, index) {
          final course = _coursesData[index];
          return _buildCourseSection(course);
        },
      ),
    );
  }

  Widget _buildCourseSection(Map<String, dynamic> course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          course['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(course['code']),
        children: (course['assignments'] as List).map((assignment) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: assignment['is_submitted']
                  ? Colors.green
                  : assignment['is_overdue']
                  ? Colors.red
                  : assignment['is_due_soon']
                  ? Colors.orange
                  : Colors.blue,
              child: Icon(
                assignment['is_submitted'] ? Icons.check : Icons.assignment,
                color: Colors.white,
              ),
            ),
            title: Text(assignment['title']),
            subtitle: Text('Due: ${assignment['formatted_due_date']}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubmissionPage(
                    title: assignment['title'],
                    subject: course['name'],
                    assignmentId: assignment['id'],
                    dueDate: assignment['due_date'],
                    description: assignment['description'],
                    filePath: assignment['file_path'],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}