import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  bool _isSearching = false;

  late AnimationController _animationController;
  late Animation<double> _fabAnimation;

  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 500), () => _animationController.forward());

    _searchController.addListener(_filterStudents);
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
    try {
      final studentResponse = await _supabase
          .from('student')
          .select('*, program(program_name, dept_name), users(email, phone_number), semester(semester_number, program(program_name))')
          .order('name');

      final programResponse = await _supabase
          .from('program')
          .select('program_id, program_name, dept_name')
          .order('program_name');

      final semesterResponse = await _supabase
          .from('semester')
          .select('semester_id, semester_number, program_id, program(program_name)')
          .order('semester_number');

      final deptResponse = await _supabase.from('department').select('dept_name');

      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(studentResponse as List);
          _filteredStudents = List.from(_students);
          _programs = List<Map<String, dynamic>>.from(programResponse as List);
          _semesters = List<Map<String, dynamic>>.from(semesterResponse as List);
          _departments = List<Map<String, dynamic>>.from(deptResponse as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorMessage('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredStudents = _students.where((student) {
        final name = student['name'].toString().toLowerCase();
        final email = student['users']['email']?.toString().toLowerCase() ?? '';
        final program = student['program']['program_name']?.toString().toLowerCase() ?? '';
        final semester = student['semester']['semester_number'].toString().toLowerCase();
        return name.contains(query) || email.contains(query) || program.contains(query) || semester.contains(query);
      }).toList();
    });
  }

  Future<void> _deleteStudent(int studentId, int index) async {
    final deletedStudent = _filteredStudents[index];
    setState(() => _filteredStudents.removeAt(index));
    try {
      await _supabase.from('student').delete().match({'student_id': studentId});
      _students.removeWhere((s) => s['student_id'] == studentId);
      _showSuccessMessage(
        'Student deleted successfully',
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await _supabase.from('student').insert(deletedStudent);
              await _fetchData();
              _showSuccessMessage('Student restored');
            } catch (e) {
              _showErrorMessage('Failed to restore: $e');
            }
          },
        ),
      );
    } catch (e) {
      setState(() => _filteredStudents.insert(index, deletedStudent));
      _showErrorMessage('Failed to delete: $e');
    }
  }

  Future<void> _enrollStudent(int studentId, int semesterId) async {
    try {
      final coreCategoryResponse = await _supabase
          .from('coursecategories')
          .select('category_id')
          .eq('category_name', 'Core')
          .single();
      final coreCategoryId = coreCategoryResponse['category_id'];

      final coursesResponse = await _supabase
          .from('course')
          .select('course_id')
          .eq('semester_id', semesterId)
          .eq('category_id', coreCategoryId);

      final enrollments = (coursesResponse as List).map((course) => {
        'student_id': studentId,
        'course_id': course['course_id'],
        'semester_id': semesterId,
        'enrollment_status': 'Active',
      }).toList();

      if (enrollments.isNotEmpty) {
        await _supabase.from('enrollment').insert(enrollments);
        _showSuccessMessage('Student enrolled in core courses');
      }
    } catch (e) {
      _showErrorMessage('Failed to enroll student: $e');
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? student}) {
    final bool isEditing = student != null;
    final nameController = TextEditingController(text: isEditing ? student!['name'] : '');
    final emailController = TextEditingController(text: isEditing ? student!['users']['email'] : '');
    final phoneController = TextEditingController(text: isEditing ? student!['users']['phone_number'] : '');
    int? selectedProgramId = isEditing ? student!['program_id'] : null;
    int? selectedSemesterId = isEditing ? student!['semester_id'] : null;
    String? selectedDeptName = isEditing ? student!['dept_name'] : null;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Student",
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
                  Icon(isEditing ? Icons.edit_note : Icons.person_add, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Student' : 'Add New Student',
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setDialogState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEditing)
                        TextField(
                          controller: TextEditingController(text: student!['student_id'].toString()),
                          enabled: false,
                          decoration: _inputDecoration('Student ID', Icons.person),
                        ),
                      if (isEditing) const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: _inputDecoration('Name', Icons.person_outline),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: _inputDecoration('Email', Icons.email),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        decoration: _inputDecoration('Phone Number', Icons.phone),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedProgramId,
                        decoration: _inputDecoration('Program', Icons.school),
                        items: _programs
                            .map((program) => DropdownMenuItem<int>(
                          value: program['program_id'],
                          child: Text(program['program_name']),
                        ))
                            .toList(),
                        onChanged: (value) => setDialogState(() {
                          selectedProgramId = value;
                          selectedSemesterId = null;
                          selectedDeptName = _programs.firstWhere((p) => p['program_id'] == value)['dept_name'];
                        }),
                        validator: (value) => value == null ? 'Please select a program' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedSemesterId,
                        decoration: _inputDecoration('Current Semester', Icons.book),
                        items: selectedProgramId == null
                            ? []
                            : _semesters
                            .where((semester) => semester['program_id'] == selectedProgramId)
                            .map((semester) => DropdownMenuItem<int>(
                          value: semester['semester_id'],
                          child: Text('${semester['semester_number']}-${semester['program']['program_name']}'),
                        ))
                            .toList(),
                        onChanged: (value) => setDialogState(() => selectedSemesterId = value),
                        validator: (value) => value == null ? 'Please select a semester' : null,
                        hint: selectedProgramId == null ? const Text('Select a program first') : const Text('Select a semester'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: TextEditingController(text: selectedDeptName),
                        enabled: false,
                        decoration: _inputDecoration('Department', Icons.business),
                      ),
                    ],
                  ),
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
                    if (nameController.text.isEmpty ||
                        emailController.text.isEmpty ||
                        phoneController.text.isEmpty ||
                        selectedProgramId == null ||
                        selectedSemesterId == null) {
                      _showErrorMessage('All fields are required');
                      return;
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(emailController.text)) {
                      _showErrorMessage('Invalid email format');
                      return;
                    }
                    if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phoneController.text)) {
                      _showErrorMessage('Invalid phone number format');
                      return;
                    }

                    Navigator.pop(context);

                    try {
                      if (isEditing) {
                        await _supabase.from('users').update({
                          'email': emailController.text,
                          'phone_number': phoneController.text,
                        }).match({'id': student!['user_id']});

                        await _supabase.from('student').update({
                          'name': nameController.text,
                          'current_semester': selectedSemesterId,
                          'program_id': selectedProgramId,
                          'dept_name': selectedDeptName,
                        }).match({'student_id': student!['student_id']});
                        _showSuccessMessage('Student updated successfully');
                      } else {
                        final userResponse = await _supabase.from('users').insert({
                          'email': emailController.text,
                          'phone_number': phoneController.text,
                          'role': 'student',
                        }).select('id').single();

                        final userId = userResponse['id'];

                        final studentResponse = await _supabase.from('student').insert({
                          'user_id': userId,
                          'name': nameController.text,
                          'current_semester': selectedSemesterId,
                          'program_id': selectedProgramId,
                          'dept_name': selectedDeptName,
                        }).select('student_id').single();

                        await _enrollStudent(studentResponse['student_id'], selectedSemesterId!);
                        _showSuccessMessage('Student added and enrolled successfully');
                      }
                      _fetchData();
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

  void _showStudentDetails(Map<String, dynamic> student) {
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
                            student['name'],
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          Text(
                            student['users']['email'] ?? 'N/A',
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
                      _buildDetailItem(icon: Icons.person, title: 'Student ID', value: student['student_id'].toString()),
                      _buildDetailItem(icon: Icons.email, title: 'Email', value: student['users']['email'] ?? 'N/A'),
                      _buildDetailItem(icon: Icons.phone, title: 'Phone', value: student['users']['phone_number'] ?? 'N/A'),
                      _buildDetailItem(icon: Icons.school, title: 'Program', value: student['program']['program_name'] ?? 'N/A'),
                      _buildDetailItem(icon: Icons.business, title: 'Department', value: student['dept_name'] ?? 'N/A'),
                      _buildDetailItem(
                          icon: Icons.book,
                          title: 'Semester',
                          value: '${student['semester']['semester_number']}-${student['semester']['program']['program_name']}'),
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
                              _showAddEditDialog(student: student);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              final index = _filteredStudents.indexWhere((s) => s['student_id'] == student['student_id']);
                              if (index != -1) _deleteStudent(student['student_id'], index);
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.deepPurple.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  void _showSuccessMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Text(message)]),
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
        content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
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
        const Icon(Icons.person_outline, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          _isSearching ? 'No students match your search' : 'No students found',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _isSearching ? 'Try a different search term' : 'Add a student to get started',
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
            label: const Text('Add Student'),
          ),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    return Hero(
      tag: 'student_${student['student_id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showStudentDetails(student),
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
                                  student['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  student['users']['email'] ?? 'N/A',
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
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Text(
                        'Semester ${student['semester']['semester_number']}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 40),
                    Chip(
                      label: Text(student['program']['program_name'] ?? 'N/A', style: const TextStyle(fontSize: 12)),
                      avatar: Icon(Icons.school, size: 16, color: Colors.deepPurple),
                      backgroundColor: Colors.deepPurple.shade50,
                      labelStyle: TextStyle(color: Colors.deepPurple.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddEditDialog(student: student),
                      tooltip: 'Edit',
                      splashRadius: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteStudent(student['student_id'], index),
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
                  hintText: 'Search students...',
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
                onChanged: (_) => _filterStudents(),
              ),
            ),
          ],
        )
            : const Text('Student Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) _searchController.clear();
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
            Text('Loading students...', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      )
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple,
        onRefresh: _fetchData,
        child: _filteredStudents.isEmpty
            ? Center(child: _buildEmptyState())
            : Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredStudents.length,
            itemBuilder: (context, index) => _buildStudentCard(_filteredStudents[index], index),
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Student'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}