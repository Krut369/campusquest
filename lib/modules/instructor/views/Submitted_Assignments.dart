import 'package:campusquest/controllers/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class InstructorAssignmentsPage extends StatefulWidget {
  final String title;
  final String subject;
  final int assignmentId;
  final DateTime dueDate;
  final String? instructorFilePath;
  final String description;
  final int courseId;
  final int semesterId;
  final int maxMarks;
  final int createdBy;

  const InstructorAssignmentsPage({
    super.key,
    required this.title,
    required this.subject,
    required this.assignmentId,
    required this.dueDate,
    this.instructorFilePath,
    required this.description,
    required this.courseId,
    required this.semesterId,
    required this.maxMarks,
    required this.createdBy,
  });

  @override
  State<InstructorAssignmentsPage> createState() =>
      _InstructorAssignmentsPageState();
}

class _InstructorAssignmentsPageState extends State<InstructorAssignmentsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Log widget parameters for debugging
    print(
        'Initializing with course_id: ${widget.courseId}, semester_id: ${widget.semesterId}, assignment_id: ${widget.assignmentId}');
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final loginController =
          Provider.of<LoginController>(context, listen: false);
      final instructorId = loginController.instructorId;

      // Verify instructor authorization
      if (instructorId == null || instructorId != widget.createdBy) {
        throw Exception('Unauthorized access to assignment grading.');
      }

      // Log query parameters
      print(
          'Fetching enrollments for course_id: ${widget.courseId}, semester_id: ${widget.semesterId}');
      // Fetch enrolled students with inner join to ensure valid students
      final enrolledStudents = await _supabase
          .from('enrollment')
          .select('student_id, student!inner(name, roll_number)')
          .eq('course_id', widget.courseId)
          .eq('semester_id', widget.semesterId);
      print('Enrolled students: $enrolledStudents');

      // Log if no students are enrolled
      if (enrolledStudents.isEmpty) {
        print(
            'No students enrolled for course_id: ${widget.courseId}, semester_id: ${widget.semesterId}');
      }

      // Fetch submissions for the assignment
      print('Fetching submissions for assignment_id: ${widget.assignmentId}');
      final submissions = await _supabase
          .from('submission')
          .select(
              'submission_id, student_id, submission_date, file_path, marks_obtained, feedback')
          .eq('assignment_id', widget.assignmentId);
      print('Submissions: $submissions');

      // Create a map of submissions by student ID
      final submissionMap = {
        for (var sub in submissions) sub['student_id']: sub
      };

      // Combine enrolled students with their submissions
      final combinedData = enrolledStudents.map((student) {
        final studentId = student['student_id'];
        final submission = submissionMap[studentId];
        return {
          'student_id': studentId,
          'name': student['student']['name'] ?? 'Unknown',
          'roll_number': student['student']['roll_number'] ?? 'N/A',
          'submission_id': submission?['submission_id'],
          'submission_date': submission?['submission_date'],
          'file_path': submission?['file_path'],
          'marks_obtained': submission?['marks_obtained'],
          'feedback': submission?['feedback'],
        };
      }).toList();

      setState(() {
        _submissions = combinedData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching submissions: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No file available for download.'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }
    try {
      final uri = Uri.parse(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $filePath';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  Future<void> _submitGrade(int studentId, String? filePath, int? submissionId,
      BuildContext scaffoldContext) async {
    final marksController = TextEditingController();
    final feedbackController = TextEditingController();
    num? marks;
    String? feedback;

    final isPastDue = widget.dueDate.isBefore(DateTime.now());
    final statusText = filePath != null
        ? (isPastDue ? 'Submitted (Late)' : 'Submitted')
        : 'Not Submitted';
    final statusColor = filePath != null
        ? (isPastDue ? Colors.orange[600] : Colors.green[600])
        : Colors.red[600];

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Grade Submission'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: $statusText',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: marksController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Marks (0-${widget.maxMarks})',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: marksController.text.isNotEmpty &&
                          (num.tryParse(marksController.text) == null ||
                              num.parse(marksController.text) < 0 ||
                              num.parse(marksController.text) > widget.maxMarks)
                      ? 'Enter a number between 0 and ${widget.maxMarks}'
                      : null,
                ),
                onChanged: (value) {
                  (dialogContext as Element).markNeedsBuild();
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                decoration: InputDecoration(
                  labelText: 'Feedback',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              marks = num.tryParse(marksController.text);
              feedback = feedbackController.text.isEmpty
                  ? null
                  : feedbackController.text;

              if (marks != null && marks! >= 0 && marks! <= widget.maxMarks) {
                try {
                  final updateData = {
                    'marks_obtained': marks,
                    'feedback': feedback,
                  };

                  if (submissionId != null) {
                    await _supabase
                        .from('submission')
                        .update(updateData)
                        .eq('submission_id', submissionId);
                  } else {
                    await _supabase.from('submission').insert({
                      'assignment_id': widget.assignmentId,
                      'student_id': studentId,
                      'submission_date': null,
                      'file_path': null,
                      ...updateData,
                    });
                  }

                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: const Text('Grade submitted successfully!'),
                      backgroundColor: Colors.green[600],
                    ),
                  );

                  Navigator.pop(dialogContext);
                  _fetchSubmissions();
                } catch (e) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: Text('Error submitting grade: $e'),
                      backgroundColor: Colors.red[600],
                    ),
                  );
                }
              } else {
                (dialogContext as Element).markNeedsBuild();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPastDue = widget.dueDate.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Grade Assignments - ${widget.title}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.indigo[700]))
          : _submissions.isEmpty
              ? Center(
                  child: Text(
                    'No students enrolled for this course and semester.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _submissions.length,
                  itemBuilder: (context, index) {
                    final s = _submissions[index];
                    final name = s['name'];
                    final roll = s['roll_number'];
                    final filePath = s['file_path'];
                    final date = s['submission_date'] != null
                        ? DateTime.parse(s['submission_date'])
                        : null;
                    final marks = s['marks_obtained'];
                    final feedback = s['feedback'];
                    final studentId = s['student_id'];
                    final submissionId = s['submission_id'];

                    final isLate = isPastDue &&
                        date != null &&
                        date.isAfter(widget.dueDate);
                    final statusText = filePath != null
                        ? (isLate ? 'Submitted (Late)' : 'Submitted')
                        : 'Not Submitted';
                    final statusColor = filePath != null
                        ? (isLate ? Colors.orange[600] : Colors.green[600])
                        : Colors.red[600];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo[700],
                                        ),
                                      ),
                                      Text(
                                        'Roll: $roll',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor!.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (date != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Submitted: ${DateFormat('MMM dd, yyyy').format(date)}',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[600]),
                                ),
                              ),
                            if (filePath != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.upload_file,
                                    color: Colors.indigo[700]),
                                title: Text(
                                  'Submission File',
                                  style: TextStyle(color: Colors.indigo[700]),
                                ),
                                trailing: Icon(Icons.download,
                                    color: Colors.indigo[700]),
                                onTap: () => _downloadFile(filePath),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  marks != null
                                      ? Icons.check_circle
                                      : Icons.pending,
                                  size: 20,
                                  color: marks != null
                                      ? Colors.green[600]
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  marks != null
                                      ? 'Marks: $marks/${widget.maxMarks}'
                                      : 'Not Graded',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: marks != null
                                        ? Colors.green[600]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            if (feedback != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Feedback: $feedback',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _submitGrade(
                                    studentId, filePath, submissionId, context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(marks != null
                                    ? 'Update Grade'
                                    : 'Assign Grade'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
