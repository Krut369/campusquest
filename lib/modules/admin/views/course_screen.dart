import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _courseCategories = [];
  bool _isLoading = true;
  bool _isSearching = false;
  late AnimationController _animationController;
  late Animation<double> _fabAnimation;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      _animationController.forward();
    });
    _searchController.addListener(_filterCourses);
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
      final courseResponse = await _supabase
          .from('course')
          .select('*, semester(semester_number, program(program_name)), coursecategories(category_name)')
          .order('course_name');
      final semesterResponse = await _supabase
          .from('semester')
          .select('semester_id, semester_number, program(program_name)')
          .order('semester_number');
      final categoryResponse = await _supabase.from('coursecategories').select();

      setState(() {
        _courses = List<Map<String, dynamic>>.from(courseResponse);
        _filteredCourses = List.from(_courses);
        _semesters = List<Map<String, dynamic>>.from(semesterResponse);
        _courseCategories = List<Map<String, dynamic>>.from(categoryResponse);
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      _showErrorMessage('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterCourses() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredCourses = List.from(_courses);
        _isSearching = false;
      });
    } else {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredCourses = _courses.where((course) {
          final courseName = course['course_name'].toString().toLowerCase();
          final semester = 'semester ${course['semester']['semester_number']} - ${course['semester']['program']['program_name']}'.toLowerCase();
          final category = course['coursecategories']['category_name'].toString().toLowerCase();
          return courseName.contains(query) || semester.contains(query) || category.contains(query);
        }).toList();
        _isSearching = true;
      });
    }
  }

  Future<void> _deleteCourse(int courseId) async {
    try {
      await _supabase.from('course').delete().match({'course_id': courseId});
      _showSuccessMessage('Course deleted successfully');
      _fetchData();
    } catch (e) {
      _showErrorMessage('Failed to delete course: $e');
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? course}) {
    final bool isEditing = course != null;
    final courseIdController = TextEditingController(text: isEditing ? course!['course_id'].toString() : '');
    final courseNameController = TextEditingController(text: isEditing ? course!['course_name'] : '');
    final lController = TextEditingController(text: isEditing ? course!['l'].toString() : '0');
    final tController = TextEditingController(text: isEditing ? course!['t'].toString() : '0');
    final pController = TextEditingController(text: isEditing ? course!['p'].toString() : '0');
    final cController = TextEditingController(text: isEditing ? course!['c'].toString() : '');
    int? selectedSemesterId = isEditing ? course!['semester_id'] : null;
    int? selectedCategoryId = isEditing ? course!['category_id'] : null;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Course",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Icon(isEditing ? Icons.edit_note : Icons.add_box, color: Colors.deepPurple),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Edit Course' : 'Add New Course',
                      style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEditing)
                        TextField(
                          controller: courseIdController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Course ID',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                        ),
                      if (isEditing) const SizedBox(height: 16),
                      _buildTextField(
                        controller: courseNameController,
                        labelText: 'Course Name',
                        prefixIcon: Icons.book,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: lController,
                        labelText: 'Lectures (L)',
                        prefixIcon: Icons.schedule,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: tController,
                        labelText: 'Tutorials (T)',
                        prefixIcon: Icons.edit_note,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: pController,
                        labelText: 'Practicals (P)',
                        prefixIcon: Icons.build,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: cController,
                        labelText: 'Credits (C)',
                        prefixIcon: Icons.credit_score,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedSemesterId,
                        decoration: InputDecoration(
                          labelText: 'Semester',
                          labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                          prefixIcon: const Icon(Icons.school, color: Colors.deepPurple),
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
                        items: _semesters.map((semester) {
                          return DropdownMenuItem<int>(
                            value: semester['semester_id'],
                            child: Text('Semester ${semester['semester_number']} - ${semester['program']['program_name']}'),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedSemesterId = value),
                        validator: (value) => value == null ? 'Please select a semester' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: 'Course Category',
                          labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                          prefixIcon: const Icon(Icons.category, color: Colors.deepPurple),
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
                        items: _courseCategories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category['category_id'],
                            child: Text(category['category_name']),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedCategoryId = value),
                        validator: (value) => value == null ? 'Please select a category' : null,
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
                      final l = int.tryParse(lController.text) ?? 0;
                      final t = int.tryParse(tController.text) ?? 0;
                      final p = int.tryParse(pController.text) ?? 0;
                      final c = int.tryParse(cController.text);

                      if (courseNameController.text.isEmpty || c == null || selectedSemesterId == null || selectedCategoryId == null) {
                        _showErrorMessage('All fields are required');
                        return;
                      }
                      if (l < 0 || t < 0 || p < 0) {
                        _showErrorMessage('L, T, P must be non-negative');
                        return;
                      }
                      if (c < 1) {
                        _showErrorMessage('Credits must be at least 1');
                        return;
                      }

                      Navigator.pop(context);

                      try {
                        if (isEditing) {
                          await _supabase.from('course').update({
                            'course_name': courseNameController.text,
                            'l': l,
                            't': t,
                            'p': p,
                            'c': c,
                            'semester_id': selectedSemesterId,
                            'category_id': selectedCategoryId,
                          }).match({'course_id': int.parse(courseIdController.text)});
                          _showSuccessMessage('Course updated successfully');
                        } else {
                          await _supabase.from('course').insert({
                            'course_name': courseNameController.text,
                            'l': l,
                            't': t,
                            'p': p,
                            'c': c,
                            'semester_id': selectedSemesterId,
                            'category_id': selectedCategoryId,
                          });
                          _showSuccessMessage('Course added successfully');
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
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
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
          borderSide: BorderSide(color: Colors.deepPurple, width: 2),
        ),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }

  void _showCourseDetails(Map<String, dynamic> course) {
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
                            course['course_name'],
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          Text(
                            'Semester ${course['semester']['semester_number']} - ${course['semester']['program']['program_name']}',
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
                      _buildDetailItem(icon: Icons.book, title: 'Course Name', value: course['course_name']),
                      const Divider(),
                      _buildDetailItem(
                        icon: Icons.school,
                        title: 'Semester',
                        value: 'Semester ${course['semester']['semester_number']} - ${course['semester']['program']['program_name']}',
                      ),
                      _buildDetailItem(icon: Icons.category, title: 'Category', value: course['coursecategories']['category_name']),
                      _buildDetailItem(icon: Icons.schedule, title: 'Lectures (L)', value: course['l'].toString()),
                      _buildDetailItem(icon: Icons.edit_note, title: 'Tutorials (T)', value: course['t'].toString()),
                      _buildDetailItem(icon: Icons.build, title: 'Practicals (P)', value: course['p'].toString()),
                      _buildDetailItem(icon: Icons.credit_score, title: 'Credits (C)', value: course['c'].toString()),
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
                              _showAddEditDialog(course: course);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () async {
                              Navigator.pop(context);
                              try {
                                await _deleteCourse(course['course_id']);
                              } catch (e) {
                                _showErrorMessage(e.toString());
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

  void _showSuccessMessage(String message) {
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.book_outlined,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          _isSearching ? 'No courses match your search' : 'No courses available',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _isSearching ? 'Try a different search term' : 'Add your first course',
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
            label: const Text('Add Course'),
          ),
      ],
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, int index) {
    return Hero(
      tag: 'course_${course['course_id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showCourseDetails(course),
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
                            child: const Icon(Icons.book, color: Colors.deepPurple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course['course_name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Semester ${course['semester']['semester_number']}',
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
                    const Icon(Icons.credit_score, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Credits: ${course['c']}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddEditDialog(course: course),
                      tooltip: 'Edit',
                      splashRadius: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        try {
                          await _deleteCourse(course['course_id']);
                        } catch (e) {
                          _showErrorMessage('Failed to delete: $e');
                        }
                      },
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
                  hintText: 'Search courses...',
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
                onChanged: (_) => _filterCourses(),
              ),
            ),
          ],
        )
            : const Text('Course Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
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
              'Loading courses...',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple,
        onRefresh: _fetchData,
        child: _filteredCourses.isEmpty
            ? Center(child: _buildEmptyState())
            : Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredCourses.length,
            itemBuilder: (context, index) {
              return _buildCourseCard(_filteredCourses[index], index);
            },
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Course'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}