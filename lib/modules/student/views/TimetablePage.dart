import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Added for date formatting
import '../../../controllers/login_controller.dart';
import '../../../widgets/attendance_pie_chart.dart';
import '../../login/views/login.dart';

class TimetablePage extends StatefulWidget {
  @override
  _TimetablePageState createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  // Selected attendance view state (default to current month)
  String? selectedAttendanceView;

  // Selected day state (default to current day)
  String? selectedDay;

  // Animation controller for dropdown
  late AnimationController _dropdownController;
  late Animation<double> _dropdownAnimation;

  // Data fetched from Supabase
  List<Map<String, dynamic>> _timetableData = [];
  List<Map<String, dynamic>> _attendanceData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Set default selectedDay to current day
    selectedDay = DateFormat('EEEE').format(DateTime.now()); // e.g., "Monday"
    // Set default selectedAttendanceView to current month
    selectedAttendanceView =
        DateFormat('MMMM').format(DateTime.now()); // e.g., "April"

    // Initialize dropdown animation controller
    _dropdownController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _dropdownAnimation =
        CurvedAnimation(parent: _dropdownController, curve: Curves.easeInOut);

    // Fetch data on initialization
    _fetchData();
  }

  @override
  void dispose() {
    _dropdownController.dispose();
    super.dispose();
  }

  // Fetch timetable and attendance data from Supabase
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final loginController =
          Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;

      if (studentId == null) {
        throw Exception('Student ID is null. Please log in again.');
      }

      // Step 1: Fetch student's current_semester and program_id
      final studentResponse = await _supabase
          .from('student')
          .select('current_semester, program_id')
          .eq('student_id', studentId)
          .single();

      final currentSemester = studentResponse['current_semester'] as int?;
      final programId = studentResponse['program_id'] as int?;

      if (currentSemester == null || programId == null) {
        throw Exception('Student semester or program not found.');
      }

      // Step 2: Fetch semester_id from semester table
      final semesterResponse = await _supabase
          .from('semester')
          .select('semester_id')
          .eq('semester_number', currentSemester)
          .eq('program_id', programId)
          .single();

      final semesterId = semesterResponse['semester_id'] as int?;

      if (semesterId == null) {
        throw Exception('Semester not found for current semester and program.');
      }

      // Step 3: Fetch timetable data
      final timetableResponse = await _supabase.from('timetable').select('''
      *, 
      course:course_id(course_name), 
      time_slot:time_slot_id(day, start_time, end_time), 
      classroom:classroom_id(classroom_id)
    ''').eq('semester_id', semesterId);

      // Step 4: Fetch attendance data
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('*, course:course_id(course_name)')
          .eq('student_id', studentId);

      setState(() {
        _timetableData = List<Map<String, dynamic>>.from(timetableResponse);
        _attendanceData = List<Map<String, dynamic>>.from(attendanceResponse);
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // Filtered timetable data based on the selected day
  List<Map<String, dynamic>> get filteredTimetableData {
    if (selectedDay == null) return [];
    return _timetableData.where((item) {
      return item['time_slot']['day'] == selectedDay;
    }).toList();
  }

  // Filtered attendance data based on the selected view
  List<Map<String, dynamic>> get filteredAttendanceData {
    if (selectedAttendanceView == null || selectedAttendanceView == 'Overall') {
      return _attendanceData;
    }
    return _attendanceData.where((item) {
      final attendanceDate = DateTime.parse(item['attendance_date']);
      return months[attendanceDate.month - 1] == selectedAttendanceView;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/logocq.png',
              height: 30,
              width: 30,
            ),
            const SizedBox(width: 8),
            const Text(
              'Time Table',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
          ),
          IconButton(
            onPressed: () {
              // Implement profile or settings functionality
            },
            icon: const Icon(Icons.account_circle, color: Colors.white),
            tooltip: 'Profile',
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple))
          : SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth > 600 ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Today's Class Section
                  Text(
                    "Today's Class",
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDaySelection(),
                  const SizedBox(height: 12),
                  if (selectedDay != null)
                    filteredTimetableData.isNotEmpty
                        ? Column(
                            children: filteredTimetableData.map((classItem) {
                              return _buildClassCard(
                                classItem['course']['course_name'],
                                '${classItem['time_slot']['start_time']} - ${classItem['time_slot']['end_time']}',
                                classItem['classroom']['classroom_id'],
                                Colors.blue.shade50,
                              );
                            }).toList(),
                          )
                        : const Center(
                            child: Text(
                              'No classes scheduled for today.',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                  const SizedBox(height: 24),

                  // Attendance Section
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildAttendanceViewSelection(),
                  const SizedBox(height: 12),
                  if (selectedAttendanceView != null)
                    _buildAttendanceSection(screenWidth)
                  else
                    const Center(
                      child: Text(
                        'Please select an attendance view.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // Day Selection Dropdown
  Widget _buildDaySelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Select Day:',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.deepPurple,
          ),
        ),
        _buildCustomDropdown(
          value: selectedDay,
          hint: 'Choose a day',
          items: days,
          onChanged: (String? newValue) {
            setState(() {
              selectedDay = newValue;
            });
          },
        ),
      ],
    );
  }

  // Attendance View Selection Dropdown
  Widget _buildAttendanceViewSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Select View:',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.deepPurple,
          ),
        ),
        _buildCustomDropdown(
          value: selectedAttendanceView,
          hint: 'Choose a view',
          items: ['Overall', ...months],
          onChanged: (String? newValue) {
            setState(() {
              selectedAttendanceView = newValue;
            });
          },
        ),
      ],
    );
  }

  // Custom Dropdown Widget with Animation and Hover Effects
  Widget _buildCustomDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _dropdownController.forward();
        },
        child: AnimatedBuilder(
          animation: _dropdownAnimation,
          builder: (context, child) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 600 ? 16 : 12,
                vertical: MediaQuery.of(context).size.width > 600 ? 10 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.grey.withOpacity(0.1 * _dropdownAnimation.value),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  hint: Text(
                    hint,
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 16 : 14,
                      color: Colors.grey,
                    ),
                  ),
                  items: items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width > 600 ? 16 : 14,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    onChanged(newValue);
                    _dropdownController.reverse();
                  },
                  icon:
                      Icon(Icons.keyboard_arrow_down, color: Colors.deepPurple),
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                    color: Colors.black,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Header for Attendance Section
  Widget _buildHeader() {
    return Text(
      'Attendance',
      style: TextStyle(
        fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 18,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      ),
    );
  }

  // Attendance Section with Pie Chart
  Widget _buildAttendanceSection(double screenWidth) {
    double overallAttendancePercentage =
        _calculateOverallAttendancePercentage();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWideScreen = constraints.maxWidth > 600;

        return Container(
          padding: EdgeInsets.all(isWideScreen ? 24 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
              ),
            ],
          ),
          child: isWideScreen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subjects',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.deepPurple,
                              fontSize: screenWidth > 600 ? 16 : 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          filteredAttendanceData.isEmpty
                              ? const Text(
                                  'No attendance data available.',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                )
                              : Column(
                                  children: _buildAttendanceBySubject()
                                      .map((item) => _buildAttendanceItem(
                                            item['subject'],
                                            item['attended'],
                                            item['total'],
                                            screenWidth,
                                          ))
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: AttendancePieChart(
                        attendancePercentage: overallAttendancePercentage,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subjects',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.deepPurple,
                        fontSize: screenWidth > 600 ? 16 : 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    filteredAttendanceData.isEmpty
                        ? const Text(
                            'No attendance data available.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          )
                        : Column(
                            children: _buildAttendanceBySubject()
                                .map((item) => _buildAttendanceItem(
                                      item['subject'],
                                      item['attended'],
                                      item['total'],
                                      screenWidth,
                                    ))
                                .toList(),
                          ),
                    const SizedBox(height: 16),
                    AttendancePieChart(
                      attendancePercentage: overallAttendancePercentage,
                    ),
                  ],
                ),
        );
      },
    );
  }

  // Aggregate attendance by subject for the selected view
  List<Map<String, dynamic>> _buildAttendanceBySubject() {
    Map<String, Map<String, int>> subjectAttendance = {};

    for (var item in filteredAttendanceData) {
      final subject = item['course']['course_name'] ?? 'Unknown Subject';
      subjectAttendance.putIfAbsent(subject, () => {'attended': 0, 'total': 0});

      subjectAttendance[subject]!['total'] =
          subjectAttendance[subject]!['total']! + 1;
      if (item['status'] == 'Present') {
        subjectAttendance[subject]!['attended'] =
            subjectAttendance[subject]!['attended']! + 1;
      }
    }

    return subjectAttendance.entries.map((entry) {
      return {
        'subject': entry.key,
        'attended': entry.value['attended']!,
        'total': entry.value['total']!,
      };
    }).toList();
  }

  // Individual Attendance Item
  Widget _buildAttendanceItem(
      String subject, int attended, int total, double screenWidth) {
    double percentage = _calculatePercentage(attended, total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              subject,
              style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // Class Card with Hover Effect and Animation
  Widget _buildClassCard(
      String courseName, String time, String classroom, Color color) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            EdgeInsets.all(MediaQuery.of(context).size.width > 600 ? 24 : 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.deepPurple,
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 16 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 14 : 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    classroom,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: MediaQuery.of(context).size.width > 600 ? 18 : 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to calculate percentage
  double _calculatePercentage(int attended, int total) {
    if (total == 0) return 0; // Avoid division by zero
    return (attended / total) * 100;
  }

  // Helper function to calculate overall attendance percentage
  double _calculateOverallAttendancePercentage() {
    int totalAttended = 0;
    int totalClasses = 0;

    for (var item in filteredAttendanceData) {
      totalClasses += 1;
      if (item['status'] == 'Present') {
        totalAttended += 1;
      }
    }

    return _calculatePercentage(totalAttended, totalClasses);
  }
}

// Defined lists
const List<String> days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];
const List<String> months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];
