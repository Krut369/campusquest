import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Assuming Supabase for data

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => EnrollmentScreenState();
}

class EnrollmentScreenState extends State<EnrollmentScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client; // Assuming Supabase integration
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> _filteredEnrollments = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _semesters = [];
  bool _isLoading = true;
  bool _isSearching = false;
  late AnimationController _animationController;
  late Animation<double> _fabAnimation;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 500), () => _animationController.forward());

    _searchController.addListener(_filterEnrollments);
    _fetchData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchEnrollments(),
      _fetchStudents(),
      _fetchCourses(),
      _fetchSemesters(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchEnrollments() async {
    try {
      final response = await _supabase.from('enrollment').select().order('enrollment_id');
      setState(() {
        _enrollments = List<Map<String, dynamic>>.from(response);
        _filteredEnrollments = List.from(_enrollments);
      });
    } catch (e) {
      _showErrorMessage('Error fetching enrollments: $e');
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final response = await _supabase.from('student').select('student_id, name').order('student_id');
      setState(() => _students = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _showErrorMessage('Error fetching students: $e');
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await _supabase.from('course').select('course_id, course_name').order('course_id');
      setState(() => _courses = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _showErrorMessage('Error fetching courses: $e');
    }
  }

  Future<void> _fetchSemesters() async {
    try {
      final response = await _supabase.from('semester').select('semester_id, semester_number').order('semester_id');
      setState(() => _semesters = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _showErrorMessage('Error fetching semesters: $e');
    }
  }

  void _filterEnrollments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredEnrollments = _enrollments.where((enrollment) {
        final studentName = _getStudentName(enrollment['student_id']).toLowerCase();
        final courseName = _getCourseName(enrollment['course_id']).toLowerCase();
        final semesterNum = _getSemesterNumber(enrollment['semester_id']).toString();
        return studentName.contains(query) || courseName.contains(query) || semesterNum.contains(query);
      }).toList();
    });
  }

  String _getStudentName(int studentId) {
    return _students.firstWhere(
          (student) => student['student_id'] == studentId,
      orElse: () => {'name': 'Unknown'},
    )['name'] as String;
  }

  String _getCourseName(int courseId) {
    return _courses.firstWhere(
          (course) => course['course_id'] == courseId,
      orElse: () => {'course_name': 'Unknown'},
    )['course_name'] as String;
  }

  int _getSemesterNumber(int semesterId) {
    return _semesters.firstWhere(
          (semester) => semester['semester_id'] == semesterId,
      orElse: () => {'semester_number': 0},
    )['semester_number'] as int;
  }

  // Get the student's most recent semester based on existing enrollments
  int? _getStudentSemester(int studentId) {
    final studentEnrollments = _enrollments.where((e) => e['student_id'] == studentId).toList();
    if (studentEnrollments.isEmpty) return null;
    // Sort by enrollment_id (assuming higher ID is more recent) and get the last semester
    studentEnrollments.sort((a, b) => (b['enrollment_id'] as int).compareTo(a['enrollment_id'] as int));
    return studentEnrollments.first['semester_id'] as int;
  }

  Future<void> _deleteEnrollment(int enrollmentId, int index) async {
    final deletedEnrollment = _filteredEnrollments[index];
    setState(() => _filteredEnrollments.removeAt(index));
    try {
      await _supabase.from('enrollment').delete().match({'enrollment_id': enrollmentId});
      _enrollments.removeWhere((e) => e['enrollment_id'] == enrollmentId);
      _showSuccessMessage(
        'Enrollment deleted successfully',
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () async {
            try {
              final newEnrollment = Map<String, dynamic>.from(deletedEnrollment)..remove('enrollment_id');
              await _supabase.from('enrollment').insert(newEnrollment);
              await _fetchEnrollments();
              _showSuccessMessage('Enrollment restored');
            } catch (e) {
              _showErrorMessage('Failed to restore: $e');
            }
          },
        ),
      );
    } catch (e) {
      setState(() => _filteredEnrollments.insert(index, deletedEnrollment));
      _showErrorMessage('Failed to delete: $e');
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? enrollment}) {
    final bool isEditing = enrollment != null;
    int? selectedStudentId = isEditing ? enrollment!['student_id'] as int? : null;
    int? selectedCourseId = isEditing ? enrollment!['course_id'] as int? : null;
    int? selectedSemesterId = isEditing ? enrollment!['semester_id'] as int? : null;

    // Determine if the student is from semester 1 based on existing enrollments (for Add) or current enrollment (for Edit)
    bool isSemesterOneStudent = isEditing
        ? enrollment!['semester_id'] == 1
        : (selectedStudentId != null ? _getStudentSemester(selectedStudentId) == 1 : false);

    // Filter courses for semester 1 if the student is from semester 1
    List<Map<String, dynamic>> filteredCourses = _courses;
    if (isSemesterOneStudent) {
      // Using enrollment data as a proxy to infer semester 1 courses
      final semesterOneCourses = _enrollments
          .where((e) => e['semester_id'] == 1)
          .map((e) => e['course_id'])
          .toSet()
          .map((id) => _courses.firstWhere((c) => c['course_id'] == id, orElse: () => {'course_id': id, 'course_name': 'Unknown'}))
          .toList();
      filteredCourses = semesterOneCourses;
      if (!isEditing) selectedSemesterId = 1; // Auto-select semester 1 only for Add
    }

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
                  Icon(isEditing ? Icons.edit_note : Icons.add_box, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Enrollment' : 'Enroll Student',
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          value: selectedStudentId,
                          decoration: _inputDecoration('Student', Icons.person),
                          items: _students
                              .map((student) => DropdownMenuItem<int>(
                            value: student['student_id'] as int,
                            child: Text(student['name'] as String),
                          ))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedStudentId = value;
                              // Re-evaluate semester and courses when student changes during Add
                              if (!isEditing) {
                                isSemesterOneStudent = _getStudentSemester(value!) == 1;
                                if (isSemesterOneStudent) {
                                  final semesterOneCourses = _enrollments
                                      .where((e) => e['semester_id'] == 1)
                                      .map((e) => e['course_id'])
                                      .toSet()
                                      .map((id) => _courses.firstWhere((c) => c['course_id'] == id,
                                      orElse: () => {'course_id': id, 'course_name': 'Unknown'}))
                                      .toList();
                                  filteredCourses = semesterOneCourses;
                                  selectedSemesterId = 1;
                                } else {
                                  filteredCourses = _courses;
                                  selectedSemesterId = null;
                                }
                                selectedCourseId = null; // Reset course selection
                              }
                            });
                          },
                          validator: (value) => value == null ? 'Student is required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: selectedCourseId,
                          decoration: _inputDecoration('Course', Icons.book),
                          items: filteredCourses
                              .map((course) => DropdownMenuItem<int>(
                            value: course['course_id'] as int,
                            child: Text(course['course_name'] as String),
                          ))
                              .toList(),
                          onChanged: (value) => setDialogState(() => selectedCourseId = value),
                          validator: (value) => value == null ? 'Course is required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: selectedSemesterId,
                          decoration: _inputDecoration('Semester', Icons.calendar_today).copyWith(
                            filled: true,
                            fillColor: isSemesterOneStudent ? Colors.grey.shade200 : null, // Visual cue for disabled state
                          ),
                          items: _semesters
                              .map((semester) => DropdownMenuItem<int>(
                            value: semester['semester_id'] as int,
                            child: Text('Semester ${semester['semester_number']}'),
                          ))
                              .toList(),
                          onChanged: isSemesterOneStudent ? null : (value) => setDialogState(() => selectedSemesterId = value),
                          validator: (value) => value == null ? 'Semester is required' : null,
                          // No 'enabled' parameter; using onChanged = null to disable
                        ),
                      ],
                    );
                  },
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
                      _showErrorMessage('All fields are required');
                      return;
                    }
                    Navigator.pop(context);
                    try {
                      if (isEditing) {
                        await _supabase.from('enrollment').update({
                          'student_id': selectedStudentId,
                          'course_id': selectedCourseId,
                          'semester_id': selectedSemesterId,
                        }).match({'enrollment_id': enrollment!['enrollment_id']});
                        _showSuccessMessage('Enrollment updated successfully');
                      } else {
                        await _supabase.from('enrollment').insert({
                          'student_id': selectedStudentId,
                          'course_id': selectedCourseId,
                          'semester_id': selectedSemesterId,
                        });
                        _showSuccessMessage('Enrollment added successfully');
                      }
                      _fetchEnrollments();
                    } catch (e) {
                      _showErrorMessage('Operation failed: $e');
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

  void _showEnrollmentDetails(Map<String, dynamic> enrollment) {
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
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
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
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getStudentName(enrollment['student_id']),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          Text(
                            _getCourseName(enrollment['course_id']),
                            style: TextStyle(fontSize: 16, color: Colors.deepPurple.shade700),
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
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 1))],
                          ),
                          child: const Icon(Icons.close, color: Colors.deepPurple, size: 22),
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
                      _buildDetailItem(icon: Icons.person, title: 'Student', value: _getStudentName(enrollment['student_id'])),
                      _buildDetailItem(icon: Icons.book, title: 'Course', value: _getCourseName(enrollment['course_id'])),
                      _buildDetailItem(icon: Icons.calendar_today, title: 'Semester', value: 'Semester ${_getSemesterNumber(enrollment['semester_id'])}'),
                      _buildDetailItem(icon: Icons.tag, title: 'Enrollment ID', value: enrollment['enrollment_id'].toString()),
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
                              _showAddEditDialog(enrollment: enrollment);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              final index = _filteredEnrollments.indexWhere((e) => e['enrollment_id'] == enrollment['enrollment_id']);
                              if (index != -1) _deleteEnrollment(enrollment['enrollment_id'], index);
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

  InputDecoration _inputDecoration(String labelText, IconData prefixIcon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.deepPurple.shade300),
      prefixIcon: Icon(prefixIcon, color: Colors.deepPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.deepPurple.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
      filled: true,
      fillColor: Colors.deepPurple.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  void _showSuccessMessage(String message, {SnackBarAction? action}) {
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

  void _showErrorMessage(String message) {
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

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.people_outline,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          _isSearching ? 'No enrollments match your search' : 'No enrollments found',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _isSearching ? 'Try a different search term' : 'Add an enrollment to get started',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (!_isSearching)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Enrollment'),
          ),
      ],
    );
  }

  Widget _buildEnrollmentCard(Map<String, dynamic> enrollment, int index) {
    return Hero(
      tag: 'enrollment_${enrollment['enrollment_id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showEnrollmentDetails(enrollment),
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
                            child: const Icon(Icons.people, color: Colors.deepPurple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStudentName(enrollment['student_id']),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _getCourseName(enrollment['course_id']),
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Semester ${_getSemesterNumber(enrollment['semester_id'])}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddEditDialog(enrollment: enrollment),
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

  Widget _buildDetailItem({required IconData icon, required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
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
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search enrollments...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (_) => _filterEnrollments(),
              ),
            ),
          ],
        )
            : const Text('Enroll Student'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshKey.currentState?.show(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'Loading enrollments...',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple,
        onRefresh: _fetchData,
        child: _filteredEnrollments.isEmpty
            ? Center(child: _buildEmptyState())
            : Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredEnrollments.length,
            itemBuilder: (context, index) => _buildEnrollmentCard(_filteredEnrollments[index], index),
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Enroll'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}