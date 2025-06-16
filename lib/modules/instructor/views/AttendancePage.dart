import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../Data/holiday_data.dart';

class Course {
  final String courseId;
  final String courseName;
  final int semesterId; // Added to store semester_id
  Course(
      {required this.courseId,
      required this.courseName,
      required this.semesterId});
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['course_id'].toString(),
      courseName: json['course_name'] ?? 'Unnamed Course',
      semesterId: json['semester_id'] as int? ?? 1, // Fallback to 1 if null
    );
  }
}

class Student {
  final int studentId;
  final String name;
  String status;
  Student(
      {required this.studentId, required this.name, this.status = 'Present'});
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      studentId: json['student_id'] as int,
      name: json['name'] ?? 'Unknown Student',
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _attendanceDateController =
      TextEditingController();
  List<Course> courses = [];
  String? selectedCourseId;
  int? selectedSemesterId; // Dynamic semester_id
  List<Student> students = [];
  bool _isLoading = false;
  int? _instructorId;
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  late AnimationController _animationController;
  late Animation<double> _fabAnimation;
  final Map<String, List<Student>> _statusCategories = {
    'Present': [],
    'Absent': [],
  };
  final supabase = Supabase.instance.client;
  String? _holidayName;
  OverlayEntry? _tooltipOverlay;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutBack);
    final today = DateTime.now();
    _attendanceDateController.text = DateFormat('yyyy-MM-dd').format(today);
    _checkIfHoliday(today);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeData();
    Future.delayed(const Duration(milliseconds: 500),
        () => _animationController.forward());
  }

  @override
  void dispose() {
    _attendanceDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await _loadInstructorData();
      if (_instructorId != null) {
        await _fetchCourses();
        if (courses.isNotEmpty) {
          setState(() {
            selectedCourseId = courses.first.courseId;
            selectedSemesterId =
                courses.first.semesterId; // Set initial semester_id
          });
          await _fetchStudentsAndAttendance();
        }
      }
    } catch (e) {
      print('Initialize data error: $e');
      _showErrorMessage('Error initializing data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInstructorData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final savedInstructorId = prefs.getInt('instructorId');
    if (savedInstructorId != null) {
      setState(() {
        _instructorId = savedInstructorId;
        _isLoading = false;
      });
      return;
    }
    if (userId != null) {
      try {
        final parsedUserId = int.tryParse(userId);
        if (parsedUserId == null) throw Exception('Invalid user ID format');
        final instructorData = await supabase
            .from('instructor')
            .select('instructor_id')
            .eq('user_id', parsedUserId)
            .maybeSingle();
        print('Instructor query response: $instructorData');
        if (instructorData != null) {
          final id = instructorData['instructor_id'] as int;
          await prefs.setInt('instructorId', id);
          setState(() => _instructorId = id);
        } else {
          _showErrorMessage(
              'No instructor profile found for user ID: $parsedUserId');
        }
      } catch (e) {
        print('Load instructor error: $e');
        _showErrorMessage('Error fetching instructor data: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      _showErrorMessage('No user ID found in SharedPreferences');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCourses() async {
    if (_instructorId == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('teaches')
          .select(
              'course:course_id(course_id, course_name, semester_id), semester_id')
          .eq('instructor_id', _instructorId!);
      print('Teaches query response: $response');
      setState(() {
        courses = response
            .map<Course>((json) => Course.fromJson({
                  'course_id': json['course']['course_id'],
                  'course_name': json['course']['course_name'],
                  'semester_id':
                      json['course']['semester_id'] ?? json['semester_id'],
                }))
            .toList();
      });
      if (courses.isEmpty) {
        _showErrorMessage('No courses assigned to this instructor');
      }
    } catch (e) {
      print('Fetch courses error: $e');
      _showErrorMessage('Error fetching assigned courses: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentsAndAttendance() async {
    if (_instructorId == null ||
        selectedCourseId == null ||
        selectedSemesterId == null) {
      print(
          'Missing required data: instructorId=$_instructorId, courseId=$selectedCourseId, semesterId=$selectedSemesterId');
      return;
    }
    setState(() => _isLoading = true);
    try {
      _statusCategories.forEach((key, value) => value.clear());
      // Debug: Check enrollment table directly
      final rawEnrollment = await supabase
          .from('enrollment')
          .select('*')
          .eq('course_id', int.parse(selectedCourseId!))
          .eq('semester_id', selectedSemesterId!);
      print('Raw enrollment data: $rawEnrollment');

      // Fetch enrolled students
      final enrollmentResponse = await supabase
          .from('enrollment')
          .select(
              'student:student_id!inner(student_id, name), enrollment_status')
          .eq('course_id', int.parse(selectedCourseId!))
          .eq('semester_id', selectedSemesterId!);
      // Removed .eq('enrollment_status', 'Active') to debug

      print('Enrollment query response: $enrollmentResponse');

      if (enrollmentResponse.isEmpty) {
        print(
            'No students found for course_id: $selectedCourseId, semester_id: $selectedSemesterId');
        setState(() => students = []);
        _showErrorMessage(
            'No students found for this course and semester. Check enrollment data.');
        return;
      }

      // Process students
      final studentsList = List<Student>.from(
        enrollmentResponse.map((json) {
          final studentData = json['student'] as Map<String, dynamic>;
          final student = Student.fromJson(studentData);
          student.status = json['enrollment_status'] == 'Active'
              ? 'Present'
              : 'Absent'; // Default based on status
          return student;
        }),
      );
      print(
          'Fetched students: ${studentsList.map((s) => "${s.name} (ID: ${s.studentId})").join(', ')}');

      // Fetch existing attendance
      final attendanceResponse = await supabase
          .from('attendance')
          .select('student_id, status')
          .eq('course_id', int.parse(selectedCourseId!))
          .eq('semester_id', selectedSemesterId!)
          .eq('attendance_date', _attendanceDateController.text);

      print('Attendance query response: $attendanceResponse');

      final attendanceMap = {
        for (var item in attendanceResponse)
          item['student_id'] as int: item['status'] as String
      };
      studentsList.forEach((student) {
        student.status = attendanceMap[student.studentId] ?? student.status;
        _statusCategories[student.status]!.add(student);
      });

      setState(() => students = studentsList);
    } catch (e) {
      print('Fetch students and attendance error: $e');
      _showErrorMessage('Error fetching students or attendance: $e');
      setState(() => students = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_instructorId == null ||
        selectedCourseId == null ||
        selectedSemesterId == null ||
        students.isEmpty) {
      _showErrorMessage('No course, semester, or students selected');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final attendanceData = students
          .map((student) => {
                'student_id': student.studentId,
                'course_id': int.parse(selectedCourseId!),
                'semester_id': selectedSemesterId!,
                'attendance_date': _attendanceDateController.text,
                'status': student.status,
              })
          .toList();
      print('Saving attendance data: $attendanceData');
      await supabase.from('attendance').upsert(
            attendanceData,
            onConflict: 'student_id, course_id, semester_id, attendance_date',
          );
      _showSuccessMessage('Attendance saved successfully');
    } catch (e) {
      print('Save attendance error: $e');
      _showErrorMessage('Error saving attendance: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        ]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  void _updateStudentStatus(Student student, String newStatus) {
    setState(() {
      _statusCategories[student.status]!.remove(student);
      student.status = newStatus;
      _statusCategories[newStatus]!.add(student);
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap ??
          () async {
            if (labelText == 'Attendance Date') {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
                selectableDayPredicate: (DateTime date) {
                  return !HolidayManager.isHoliday(date);
                },
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.indigo.shade700,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: Tooltip(
                      message:
                          HolidayManager.getHolidayName(DateTime.now()) ?? '',
                      child: MouseRegion(
                        onHover: (event) {
                          final RenderBox box =
                              context.findRenderObject() as RenderBox;
                          final position = box.globalToLocal(event.position);
                          final DateTime? hoveredDate =
                              _getDateFromPosition(position, box.size);

                          if (hoveredDate != null) {
                            final holidayName =
                                HolidayManager.getHolidayName(hoveredDate);
                            if (holidayName != null) {
                              _showTooltip(
                                  context, holidayName, event.position);
                            }
                          }
                        },
                        onExit: (_) {
                          _hideTooltip();
                        },
                        child: CalendarDatePicker(
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          onDateChanged: (DateTime date) {
                            Navigator.of(context).pop(date);
                          },
                          selectableDayPredicate: (DateTime date) {
                            return !HolidayManager.isHoliday(date);
                          },
                        ),
                      ),
                    ),
                  );
                },
              );

              if (pickedDate != null) {
                setState(() {
                  _attendanceDateController.text =
                      DateFormat('yyyy-MM-dd').format(pickedDate);
                  _checkIfHoliday(pickedDate);
                });
                _fetchStudentsAndAttendance();
              }
            }
          },
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, color: Colors.indigo.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.indigo.shade100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.indigo.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        labelStyle: TextStyle(color: Colors.indigo.shade700),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  void _showTooltip(BuildContext context, String message, Offset position) {
    _hideTooltip();

    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy - 40, // Show tooltip above the cursor
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Colors.black87,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_tooltipOverlay!);
  }

  void _hideTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  DateTime? _getDateFromPosition(Offset localPosition, Size size) {
    // This is a simplified calculation and might need adjustment
    final cellWidth = size.width / 7;
    final cellHeight = size.height / 6;

    final column = (localPosition.dx / cellWidth).floor();
    final row = (localPosition.dy / cellHeight).floor();

    if (column < 0 || column > 6 || row < 0 || row > 5) return null;

    // Calculate the date based on the grid position
    final firstDayOfMonth =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    final startOffset = firstDayOfMonth.weekday - 1;

    final dayOfMonth = row * 7 + column - startOffset + 1;
    if (dayOfMonth < 1) return null;

    return DateTime(DateTime.now().year, DateTime.now().month, dayOfMonth);
  }

  Widget _buildStudentItem(Student student) {
    return Card(
      elevation: 4,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                student.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.indigo.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${student.studentId}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey.shade100,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(20),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Present',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(20),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Absent',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  DragTarget<String>(
                    builder: (context, candidateData, rejectedData) {
                      return AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: student.status == 'Present'
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Draggable<String>(
                          data: student.status,
                          feedback: Container(
                            width: 60,
                            height: 40,
                            decoration: BoxDecoration(
                              color: student.status == 'Present'
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                student.status == 'Present'
                                    ? Icons.check
                                    : Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          childWhenDragging: Container(
                            width: 60,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Container(
                            width: 60,
                            height: 40,
                            decoration: BoxDecoration(
                              color: student.status == 'Present'
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                student.status == 'Present'
                                    ? Icons.check
                                    : Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onWillAccept: (data) => true,
                    onAccept: (data) {
                      if (data == 'Present') {
                        _updateStudentStatus(student, 'Absent');
                      } else {
                        _updateStudentStatus(student, 'Present');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkIfHoliday(DateTime date) {
    setState(() {
      _holidayName = HolidayManager.getHolidayName(date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate =
        DateFormat('yyyy-MM-dd').parse(_attendanceDateController.text);
    final isHoliday = HolidayManager.isHoliday(selectedDate);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Attendance',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: selectedCourseId,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              dropdownColor: Colors.deepPurple,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              underline: Container(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedCourseId = newValue;
                    // Find the corresponding semester_id
                    selectedSemesterId = courses
                        .firstWhere((course) => course.courseId == newValue)
                        .semesterId;
                  });
                  print(
                      'Selected course: $newValue, semester: $selectedSemesterId');
                  _fetchStudentsAndAttendance();
                }
              },
              items: courses.map<DropdownMenuItem<String>>((Course course) {
                return DropdownMenuItem<String>(
                  value: course.courseId,
                  child: Text('${course.courseName} (Sem ${course.semesterId})',
                      style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _refreshKey.currentState?.show(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.indigo.shade700))
          : RefreshIndicator(
              key: _refreshKey,
              color: Colors.indigo.shade700,
              backgroundColor: Colors.white,
              onRefresh: _fetchStudentsAndAttendance,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _attendanceDateController,
                                labelText: 'Attendance Date',
                                prefixIcon: Icons.calendar_today,
                                readOnly: true,
                                onTap: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                    selectableDayPredicate: (DateTime date) {
                                      // Disable weekends and holidays
                                      return !HolidayManager.isHoliday(date);
                                    },
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: Colors.indigo.shade700,
                                            onPrimary: Colors.white,
                                            surface: Colors.white,
                                            onSurface: Colors.black,
                                          ),
                                          dialogBackgroundColor: Colors.white,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      _attendanceDateController.text =
                                          DateFormat('yyyy-MM-dd')
                                              .format(pickedDate);
                                      _checkIfHoliday(pickedDate);
                                    });
                                    _fetchStudentsAndAttendance();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildSummaryBadge(),
                          ],
                        ),
                        if (_holidayName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event,
                                      size: 16, color: Colors.orange.shade800),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Holiday: $_holidayName',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isHoliday)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.orange.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Attendance Cannot Be Taken\nOn Holidays',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _holidayName ?? 'Holiday',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: selectedCourseId == null || courses.isEmpty
                          ? _buildNoCourses()
                          : students.isEmpty
                              ? _buildNoStudents()
                              : _buildAttendanceList(),
                    ),
                ],
              ),
            ),
      floatingActionButton: !isHoliday && students.isNotEmpty
          ? ScaleTransition(
              scale: _fabAnimation,
              child: GestureDetector(
                onTap: _saveAttendance,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.shade300.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(Icons.save, color: Colors.white, size: 28),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNoCourses() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No assigned courses',
            style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStudents() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No students enrolled for this course/semester',
            style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Slide to mark attendance',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return _buildStudentItem(student);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge() {
    final presentCount = _statusCategories['Present']?.length ?? 0;
    final totalCount = students.length;
    final attendanceRate = totalCount > 0
        ? (presentCount / totalCount * 100).toStringAsFixed(0)
        : '0';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$attendanceRate%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700,
            ),
          ),
          Text(
            'Present',
            style: TextStyle(
              fontSize: 12,
              color: Colors.indigo.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
