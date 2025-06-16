import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnrollmentController {
  final BuildContext context;
  final void Function(void Function()) setStateCallback;
  final TickerProvider vsync;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> filteredEnrollments = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _semesters = [];
  bool isLoading = true;
  bool isSearching = false;

  late AnimationController animationController;
  late Animation<double> fabAnimation;
  final refreshKey = GlobalKey<RefreshIndicatorState>();
  final TextEditingController searchController = TextEditingController();

  EnrollmentController({
    required this.context,
    required this.setStateCallback,
    required this.vsync,
  });

  void init() {
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 800),
    );

    fabAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.elasticOut,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      animationController.forward();
    });

    searchController.addListener(filterEnrollments);
    fetchData();
  }

  void dispose() {
    animationController.dispose();
    searchController.dispose();
  }

  Future<void> fetchData() async {
    setStateCallback(() {
      isLoading = true;
    });

    try {
      await Future.wait([
        _fetchEnrollments(),
        _fetchStudents(),
        _fetchCourses(),
        _fetchSemesters(),
      ]);

      setStateCallback(() {
        isLoading = false;
      });
    } catch (e) {
      showErrorMessage('Error fetching data: ${e.toString()}');
      setStateCallback(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchEnrollments() async {
    try {
      final response = await _supabase
          .from('enrollment')
          .select('*, student(name), course(title), semester(semester_id)')
          .order('enrollment_id');

      setStateCallback(() {
        _enrollments = (response as List).cast<Map<String, dynamic>>();
        filteredEnrollments = List.from(_enrollments);
      });
    } catch (e) {
      showErrorMessage('Error fetching enrollments: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final response = await _supabase
          .from('student')
          .select('student_id, name')
          .order('student_id');

      setStateCallback(() {
        _students = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      showErrorMessage('Error fetching students: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select('course_id, title')
          .order('course_id');

      setStateCallback(() {
        _courses = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      showErrorMessage('Error fetching courses: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _fetchSemesters() async {
    try {
      final response = await _supabase
          .from('semester')
          .select('semester_id, term, year') // Added more semester fields
          .order('semester_id');

      setStateCallback(() {
        _semesters = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      showErrorMessage('Error fetching semesters: ${e.toString()}');
      rethrow;
    }
  }

  void filterEnrollments() {
    if (searchController.text.isEmpty) {
      setStateCallback(() {
        filteredEnrollments = List.from(_enrollments);
        isSearching = false;
      });
      return;
    }

    final query = searchController.text.toLowerCase();
    setStateCallback(() {
      filteredEnrollments = _enrollments.where((enrollment) {
        final studentName = _getStudentName(enrollment['student_id']).toLowerCase();
        final courseTitle = _getCourseTitle(enrollment['course_id']).toLowerCase();
        final semesterId = _getSemesterDisplay(enrollment['semester_id']).toLowerCase();
        final status = enrollment['enrollment_status'].toString().toLowerCase();
        return studentName.contains(query) ||
            courseTitle.contains(query) ||
            semesterId.contains(query) ||
            status.contains(query);
      }).toList();
      isSearching = true;
    });
  }

  String _getStudentName(String studentId) {
    final student = _students.firstWhere(
          (student) => student['student_id'] == studentId,
      orElse: () => {'name': 'Unknown'},
    );
    return student['name'];
  }

  String _getCourseTitle(String courseId) {
    final course = _courses.firstWhere(
          (course) => course['course_id'] == courseId,
      orElse: () => {'title': 'Unknown'},
    );
    return course['title'];
  }

  String _getSemesterDisplay(String semesterId) {
    final semester = _semesters.firstWhere(
          (semester) => semester['semester_id'] == semesterId,
      orElse: () => {'term': 'Unknown', 'year': ''},
    );
    return '${semester['term']} ${semester['year']}';
  }

  Future<void> _deleteEnrollment(int enrollmentId, int index) async {
    final deletedEnrollment = filteredEnrollments[index];

    setStateCallback(() {
      filteredEnrollments.removeAt(index);
    });

    try {
      await _supabase.from('enrollment').delete().match({'enrollment_id': enrollmentId});

      showSuccessMessage(
        'Enrollment deleted',
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            try {
              await _supabase.from('enrollment').insert(deletedEnrollment);
              await _fetchEnrollments();
              showSuccessMessage('Enrollment restored');
            } catch (e) {
              showErrorMessage('Failed to restore: $e');
            }
          },
        ),
      );

      _enrollments.removeWhere((enrollment) => enrollment['enrollment_id'] == enrollmentId);
    } catch (e) {
      setStateCallback(() {
        filteredEnrollments.insert(index, deletedEnrollment);
      });
      showErrorMessage('Failed to delete: $e');
    }
  }

  void showAddEditDialog(BuildContext context, {Map<String, dynamic>? enrollment}) {
    final bool isEditing = enrollment != null;
    String? selectedStudentId = isEditing ? enrollment!['student_id'] : null;
    String? selectedCourseId = isEditing ? enrollment!['course_id'] : null;
    String? selectedSemesterId = isEditing ? enrollment!['semester_id'] : null;
    String selectedStatus = isEditing ? enrollment!['enrollment_status'] : 'Active';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Enrollment",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note : Icons.add_box,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Enrollment' : 'Add Enrollment',
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Student Dropdown
                    StatefulBuilder(
                      builder: (context, setDropdownState) {
                        return DropdownButtonFormField<String>(
                          value: selectedStudentId,
                          onChanged: isEditing
                              ? null
                              : (String? newValue) {
                            setDropdownState(() {
                              selectedStudentId = newValue;
                            });
                          },
                          items: _students.map((student) {
                            return DropdownMenuItem<String>(
                              value: student['student_id'],
                              child: Text(student['name']),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            labelText: 'Student',
                            labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                            prefixIcon: const Icon(Icons.person, color: Colors.deepPurple),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple.shade200),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                            ),
                            filled: true,
                            fillColor: isEditing ? Colors.grey.shade100 : Colors.deepPurple.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Course Dropdown
                    StatefulBuilder(
                      builder: (context, setDropdownState) {
                        return DropdownButtonFormField<String>(
                          value: selectedCourseId,
                          onChanged: isEditing
                              ? null
                              : (String? newValue) {
                            setDropdownState(() {
                              selectedCourseId = newValue;
                            });
                          },
                          items: _courses.map((course) {
                            return DropdownMenuItem<String>(
                              value: course['course_id'],
                              child: Text(course['title']),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            labelText: 'Course',
                            labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                            prefixIcon: const Icon(Icons.book, color: Colors.deepPurple),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple.shade200),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                            ),
                            filled: true,
                            fillColor: isEditing ? Colors.grey.shade100 : Colors.deepPurple.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Semester Dropdown
                    StatefulBuilder(
                      builder: (context, setDropdownState) {
                        return DropdownButtonFormField<String>(
                          value: selectedSemesterId,
                          onChanged: isEditing
                              ? null
                              : (String? newValue) {
                            setDropdownState(() {
                              selectedSemesterId = newValue;
                            });
                          },
                          items: _semesters.map((semester) {
                            return DropdownMenuItem<String>(
                              value: semester['semester_id'],
                              child: Text('${semester['term']} ${semester['year']}'),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            labelText: 'Semester',
                            labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                            prefixIcon: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple.shade200),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                            ),
                            filled: true,
                            fillColor: isEditing ? Colors.grey.shade100 : Colors.deepPurple.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status Dropdown
                    StatefulBuilder(
                      builder: (context, setDropdownState) {
                        return DropdownButtonFormField<String>(
                          value: selectedStatus,
                          onChanged: (String? newValue) {
                            setDropdownState(() {
                              selectedStatus = newValue!;
                            });
                          },
                          items: ['Active', 'Inactive', 'Completed', 'Dropped'].map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            labelText: 'Enrollment Status',
                            labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                            prefixIcon: const Icon(Icons.assignment_turned_in, color: Colors.deepPurple),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.deepPurple.shade50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                  label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () async {
                    if (selectedStudentId == null || selectedCourseId == null || selectedSemesterId == null) {
                      showErrorMessage('Student, Course, and Semester are required');
                      return;
                    }

                    try {
                      if (isEditing) {
                        await _supabase.from('enrollment').update({
                          'enrollment_status': selectedStatus,
                        }).match({'enrollment_id': enrollment!['enrollment_id']});
                        showSuccessMessage('Enrollment updated successfully');
                      } else {
                        await _supabase.from('enrollment').insert({
                          'student_id': selectedStudentId,
                          'course_id': selectedCourseId,
                          'semester_id': selectedSemesterId,
                          'enrollment_status': selectedStatus,
                        });
                        showSuccessMessage('Enrollment added successfully');
                      }

                      Navigator.pop(context);
                      await _fetchEnrollments();
                    } catch (e) {
                      showErrorMessage('Operation failed: $e');
                    }
                  },
                  icon: Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showSuccessMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: action != null ? const Duration(seconds: 5) : const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        action: action,
      ),
    );
  }

  void showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.assignment_outlined,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          isSearching ? 'No enrollments match your search' : 'No enrollments found',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isSearching ? 'Try a different search term' : 'Add an enrollment to get started',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (!isSearching)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => showAddEditDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Enrollment'),
          ),
      ],
    );
  }

  void showEnrollmentDetails(BuildContext context, Map<String, dynamic> enrollment) {
    final studentName = _getStudentName(enrollment['student_id']);
    final courseTitle = _getCourseTitle(enrollment['course_id']);
    final semesterDisplay = _getSemesterDisplay(enrollment['semester_id']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            courseTitle,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.deepPurple,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        icon: Icons.person,
                        title: 'Student ID',
                        value: enrollment['student_id'],
                      ),
                      const Divider(),
                      _buildDetailItem(
                        icon: Icons.book,
                        title: 'Course ID',
                        value: enrollment['course_id'],
                      ),
                      const Divider(),
                      _buildDetailItem(
                        icon: Icons.calendar_today,
                        title: 'Semester',
                        value: semesterDisplay,
                      ),
                      const Divider(),
                      _buildDetailItem(
                        icon: Icons.assignment_turned_in,
                        title: 'Status',
                        value: enrollment['enrollment_status'],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            label: 'Edit',
                            icon: Icons.edit,
                            color: Colors.blue,
                            onTap: () {
                              Navigator.pop(context);
                              showAddEditDialog(context, enrollment: enrollment);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              final index = filteredEnrollments.indexWhere(
                                      (e) => e['enrollment_id'] == enrollment['enrollment_id']);
                              if (index != -1) {
                                _deleteEnrollment(enrollment['enrollment_id'], index);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEnrollmentCard(BuildContext context, Map<String, dynamic> enrollment, int index) {
    final studentName = _getStudentName(enrollment['student_id']);
    final courseTitle = _getCourseTitle(enrollment['course_id']);
    final semesterDisplay = _getSemesterDisplay(enrollment['semester_id']);

    return Hero(
      tag: 'enrollment_${enrollment['enrollment_id']}',
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => showEnrollmentDetails(context, enrollment),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.deepPurple.withOpacity(0.1),
          highlightColor: Colors.deepPurple.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person, color: Colors.deepPurple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  courseTitle,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: enrollment['enrollment_status'] == 'Active'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: enrollment['enrollment_status'] == 'Active'
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Text(
                        enrollment['enrollment_status'],
                        style: TextStyle(
                          color: enrollment['enrollment_status'] == 'Active'
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Row(
                    children: [
                      _buildInfoChip(semesterDisplay, Icons.calendar_today),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => showAddEditDialog(context, enrollment: enrollment),
                      tooltip: 'Edit',
                      splashRadius: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEnrollment(enrollment['enrollment_id'], index),
                      tooltip: 'Delete',
                      splashRadius: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.deepPurple,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.deepPurple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void toggleSearch() {
    setStateCallback(() {
      if (isSearching) {
        searchController.clear();
        filteredEnrollments = List.from(_enrollments);
      }
      isSearching = !isSearching;
    });
  }
}