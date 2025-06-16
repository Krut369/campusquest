import 'package:campusquest/modules/admin/views/ExportStudentDataPage.dart';
import 'package:campusquest/modules/admin/views/Program_Courses.dart';
import 'package:campusquest/modules/admin/views/TimeSlotScreen.dart';
import 'package:campusquest/modules/admin/views/assignteacher.dart';
import 'package:campusquest/modules/admin/views/classroom_screen.dart';
import 'package:campusquest/modules/admin/views/course_screen.dart';
import 'package:campusquest/modules/admin/views/department_screen.dart';
import 'package:campusquest/modules/admin/views/enrollment_screen.dart';
import 'package:campusquest/modules/admin/views/instructor_screen.dart';
import 'package:campusquest/modules/admin/views/programscreen.dart';
import 'package:campusquest/modules/admin/views/semester_screen.dart';
import 'package:campusquest/modules/login/views/login.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../../../controllers/login_controller.dart'; // Ensure this path is correct
import '../../../controllers/theme_controller.dart';
import '../views/EventsPage.dart';
import 'Update_student.dart';

// Assuming you have initialized Supabase in your main.dart file
final supabase = Supabase.instance.client;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _programsCount = 0;
  int _studentsCount = 0;
  int _instructorsCount = 0;
  int _classroomsCount = 0;
  int _coursesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    try {
      // Using the correct table names from the schema
      final programsResponse = await supabase.from('program').select('count');
      final studentsResponse = await supabase.from('student').select('count');
      final instructorsResponse = await supabase.from('instructor').select('count');
      final classroomsResponse = await supabase.from('classroom').select('count');
      final coursesResponse = await supabase.from('course').select('count');

      setState(() {
        // Using null-aware operators to handle potential null values
        _programsCount = programsResponse[0]['count'] ?? 0;
        _studentsCount = studentsResponse[0]['count'] ?? 0;
        _instructorsCount = instructorsResponse[0]['count'] ?? 0;
        _classroomsCount = classroomsResponse[0]['count'] ?? 0;
        _coursesCount = coursesResponse[0]['count'] ?? 0;
      });
    } catch (e) {
      print('Error fetching counts: $e'); // Print error to console

      // Default all counts to 0 in case of error
      setState(() {
        _programsCount = 0;
        _studentsCount = 0;
        _instructorsCount = 0;
        _classroomsCount = 0;
        _coursesCount = 0;
      });

      // Show error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching counts: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<LoginController>(context).role;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              const Text(
                'Welcome, Admin!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const SizedBox(height: 8),
              const Text(
                'Heres an overview of your system.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Counters Section
              _buildCountersSection(context),

              const SizedBox(height: 24),

              // Quick Actions Section
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const SizedBox(height: 12),

              _buildButtonsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  // Counters Section - Made responsive
  Widget _buildCountersSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTabletOrLarger = constraints.maxWidth > 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTabletOrLarger ? 4 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isTabletOrLarger ? 1.5 : 1.2,
          ),
          itemCount: 5,
          itemBuilder: (context, index) {
            final counters = [
              {'label': 'Programs', 'count': _programsCount, 'color': Colors.purple},
              {'label': 'Students', 'count': _studentsCount, 'color': Colors.teal},
              {'label': 'Instructors', 'count': _instructorsCount, 'color': Colors.blue},
              {'label': 'Classrooms', 'count': _classroomsCount, 'color': Colors.green}, // Updated label from 'Classes' to 'Classrooms'
              {'label': 'Courses', 'count': _coursesCount, 'color': Colors.orange},
            ];

            return _buildCounterCard(
              counters[index]['label'] as String,
              counters[index]['count'] as int,
              counters[index]['color'] as Color,
            );
          },
        );
      },
    );
  }

  // Counter Card
  Widget _buildCounterCard(String label, int count, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Buttons Section - Made fully responsive
  Widget _buildButtonsSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTabletOrLarger = constraints.maxWidth > 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTabletOrLarger ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isTabletOrLarger ? 1.3 : 1.0,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final buttonData = [
              {'label': 'Add Instructor', 'icon': Icons.person_add, 'color': Colors.blue, 'route': const AddInstructorPage()},
              {'label': 'Assign Instructors', 'icon': Icons.assignment_ind, 'color': Colors.green, 'route': const TeachesScreen()},
              {'label': 'Manage Programs', 'icon': Icons.school, 'color': Colors.purple, 'route': const ProgramScreen()},
              {'label': 'Update Student', 'icon': Icons.add_box, 'color': Colors.orange, 'route': BulkStudentUpdateScreen()}, // Changed from 'Add Section' to 'Add Classroom'
              {'label': 'Create Event', 'icon': Icons.event, 'color': Colors.red, 'route': AddEventPage()},
              {'label': 'Export Student Data', 'icon': Icons.download, 'color': Colors.brown, 'route': const StudentScreen()},
            ][index];

            return _buildActionButton(
              context,
              label: buttonData['label'] as String,
              icon: buttonData['icon'] as IconData,
              color: buttonData['color'] as Color,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => buttonData['route'] as Widget),
                );
              },
            );
          },
        );
      },
    );
  }

  // Action Button - Improved for responsiveness
  Widget _buildActionButton(
      BuildContext context, {
        required String label,
        required IconData icon,
        required Color color,
        required VoidCallback onPressed,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with Circular Background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 8),
              // Label with FittedBox for text overflow prevention
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Drawer for Web and Mobile
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'Admin Dashboard',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                SizedBox(height: 8),
                Text(
                  'Management System',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.roofing_outlined),
            title: const Text('Manage Classrooms'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClassroomScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.room_preferences_sharp),
            title: const Text('Manage Departments'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DepartmentScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Manage Programs'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProgramScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Add Semester'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SemesterScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Add Course'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CourseScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Add Time Slot'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TimeSlotScreen()),
              );
            },
          ),


          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Add Instructor'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddInstructorPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind),
            title: const Text('Assign Instructors'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeachesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Course Enrollement'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EnrollmentScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in),
            title: const Text('Program Course'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProgramCoursesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Create Event'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddEventPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Student Data'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              // Logout the user from Supabase
              supabase.auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
          ListTile(
              leading: IconButton(
                icon: Icon(Icons.brightness_6),
                onPressed: () {
                  Provider.of<ThemeController>(context, listen: false).toggleTheme();
                },
              )
          )
        ],
      ),
    );
  }
}