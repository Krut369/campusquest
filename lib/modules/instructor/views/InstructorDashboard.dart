import 'package:campusquest/controllers/login_controller.dart';
import 'package:campusquest/modules/instructor/views/Submitted_Assignments.dart';
import 'package:campusquest/modules/instructor/views/attendancepage.dart';
import 'package:campusquest/modules/instructor/views/uploadmaterialpage.dart';
import 'package:campusquest/modules/login/views/login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../controllers/theme_controller.dart';

class InstructorDashboard extends StatefulWidget {
  const InstructorDashboard({super.key});

  @override
  State<InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<InstructorDashboard> {
  String instructorName = "Instructor";
  String designation = "";
  bool isLoading = true;
  final SupabaseClient _supabase = Supabase.instance.client;
  int _notesCount = 0;
  int _coursesCount = 0;
  int _studentsCount = 0;
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadInstructorData();
    _fetchCounts();
    _fetchAssignments();
  }

  Future<void> _loadInstructorData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final savedName = prefs.getString('instructorName');
    final savedDesignation = prefs.getString('instructorDesignation');

    if (savedName != null && savedDesignation != null) {
      setState(() {
        instructorName = savedName;
        designation = savedDesignation;
        isLoading = false;
      });
      return;
    }

    if (userId != null) {
      try {
        final instructorData = await _supabase
            .from('instructor')
            .select('name, designation')
            .eq('user_id', int.parse(userId))
            .single();

        final name = instructorData['name'] as String;
        final prof = instructorData['designation'] as String;
        await prefs.setString('instructorName', name);
        await prefs.setString('instructorDesignation', prof);
        setState(() {
          instructorName = name;
          designation = prof;
        });
      } catch (e) {
        print("Error fetching instructor data: $e");
      } finally {
        setState(() => isLoading = false);
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchAssignments() async {
    try {
      final loginController =
          Provider.of<LoginController>(context, listen: false);
      final instructorId = loginController.instructorId;
      if (instructorId == null) {
        throw Exception('Instructor ID is null');
      }
      final assignments = await _supabase
          .from('assignment')
          .select(
              'assignment_id, title, course_id, semester_id, due_date, description, file_path, max_marks, created_by, course!inner(course_name)')
          .eq('created_by', instructorId);
      setState(() {
        _assignments = assignments;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching assignments: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('instructorName');
    await prefs.remove('instructorDesignation');
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  Future<void> _fetchCounts() async {
    try {
      final loginController =
          Provider.of<LoginController>(context, listen: false);
      final instructorId = loginController.instructorId;
      if (instructorId == null) return;

      // Fetch notes count
      final notesResponse = await _supabase
          .from('notes')
          .select()
          .eq('uploaded_by', instructorId);
      final notesCount = notesResponse.length;

      // Fetch courses count
      final coursesResponse = await _supabase
          .from('teaches')
          .select()
          .eq('instructor_id', instructorId);
      final coursesCount = coursesResponse.length;

      // Fetch students count
      final studentsResponse = await _supabase
          .from('enrollment')
          .select('student_id')
          .any('course_id', coursesResponse.map((c) => c['course_id']).toList())
          .distinct();
      final studentsCount = studentsResponse.length;

      setState(() {
        _notesCount = notesCount;
        _coursesCount = coursesCount;
        _studentsCount = studentsCount;
      });
    } catch (e) {
      print('Error fetching counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 36,
                    child: Text(
                      instructorName.isNotEmpty
                          ? instructorName[0].toUpperCase()
                          : "I",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    instructorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    designation.isNotEmpty ? designation : 'Instructor',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.deepPurple),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Upload Materials'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UploadMaterialsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.green),
              title: const Text('Attendance'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AttendancePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.orange),
              title: const Text('Students'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to students page
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: _logout,
            ),
            ListTile(
              leading: IconButton(
                icon: const Icon(Icons.brightness_6),
                onPressed: () {
                  Provider.of<ThemeController>(context, listen: false)
                      .toggleTheme();
                },
              ),
              title: const Text('Toggle Theme'),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.deepPurple.shade50, Colors.white],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.deepPurple,
                                Colors.deepPurple.shade700
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                radius: 24,
                                child: Text(
                                  instructorName.isNotEmpty
                                      ? instructorName[0].toUpperCase()
                                      : "I",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back, $instructorName',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      designation.isNotEmpty
                                          ? designation
                                          : 'Instructor',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Overview',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildCounterCard('Materials', _notesCount,
                                      Colors.blue, Icons.book),
                                  _buildCounterCard('Classes', _coursesCount,
                                      Colors.green, Icons.calendar_today),
                                  _buildCounterCard('Students', _studentsCount,
                                      Colors.orange, Icons.people),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Upload Materials',
                              'Share files with your students',
                              Icons.upload_file,
                              Colors.blue,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const UploadMaterialsPage()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              'Attendance',
                              'Mark class attendance',
                              Icons.calendar_today,
                              Colors.green,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const AttendancePage()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              'Student Records',
                              'View marks and attendance',
                              Icons.people,
                              Colors.orange,
                              () {
                                // Navigate to student records page
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              'Assignments',
                              'Grade student submissions',
                              Icons.assignment,
                              Colors.purple,
                              () {
                                // No direct navigation; assignments are listed below
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Assignments',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 16),
                      _assignments.isEmpty
                          ? Center(
                              child: Text(
                                'No assignments found.',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _assignments.length,
                              itemBuilder: (context, index) {
                                final assignment = _assignments[index];
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Text(
                                      assignment['title'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo[700],
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Course: ${assignment['course']['course_name']}\nDue: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['due_date']))}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    trailing: Icon(Icons.arrow_forward,
                                        color: Colors.indigo[700]),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              InstructorAssignmentsPage(
                                            title: assignment['title'],
                                            subject: assignment['course']
                                                ['course_name'],
                                            assignmentId:
                                                assignment['assignment_id'],
                                            dueDate: DateTime.parse(
                                                assignment['due_date']),
                                            instructorFilePath:
                                                assignment['file_path'],
                                            description:
                                                assignment['description'] ??
                                                    'No description',
                                            courseId: assignment['course_id'],
                                            semesterId:
                                                assignment['semester_id'],
                                            maxMarks: assignment['max_marks'],
                                            createdBy: assignment['created_by'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCounterCard(
      String label, int count, Color color, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}

extension on PostgrestFilterBuilder<PostgrestList> {
  any(String s, List list) {}
}
