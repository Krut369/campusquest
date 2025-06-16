import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SemesterScreen extends StatefulWidget {
  const SemesterScreen({super.key});

  @override
  State<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends State<SemesterScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _filteredSemesters = [];
  List<Map<String, dynamic>> _programs = [];
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
    _searchController.addListener(_filterSemesters);
    _fetchSemestersAndPrograms();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSemestersAndPrograms() async {
    setState(() => _isLoading = true);
    try {
      final semesterResponse = await _supabase.from('semester').select('*, program(program_name)').order('semester_number');
      final programResponse = await _supabase.from('program').select();
      setState(() {
        _semesters = List<Map<String, dynamic>>.from(semesterResponse);
        _filteredSemesters = List.from(_semesters);
        _programs = List<Map<String, dynamic>>.from(programResponse);
        _isLoading = false;
      });
    } catch (e) {
      _showErrorMessage('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterSemesters() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredSemesters = List.from(_semesters);
        _isSearching = false;
      });
    } else {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredSemesters = _semesters.where((semester) {
          final programName = semester['program']['program_name'].toString().toLowerCase();
          final semesterNum = semester['semester_number'].toString();
          return programName.contains(query) || semesterNum.contains(query);
        }).toList();
        _isSearching = true;
      });
    }
  }

  Future<void> _addOrUpdateSemester({
    int? semesterId,
    required int programId,
    required int semesterNumber,
    required int maxCourses,
    required int coreCourses,
    required int electiveCourses,
    required bool isFinalSemester,
  }) async {
    try {
      final data = {
        'program_id': programId,
        'semester_number': semesterNumber,
        'max_courses': maxCourses,
        'core_courses': coreCourses,
        'elective_courses': electiveCourses,
        'is_final_semester': isFinalSemester,
      };
      if (semesterId != null) {
        await _supabase.from('semester').update(data).match({'semester_id': semesterId});
      } else {
        await _supabase.from('semester').insert(data);
      }
      await _fetchSemestersAndPrograms();
    } catch (e) {
      throw 'Operation failed: $e';
    }
  }

  Future<void> _deleteSemester(int semesterId) async {
    final index = _filteredSemesters.indexWhere((s) => s['semester_id'] == semesterId);
    if (index == -1) return;

    final deletedSemester = _filteredSemesters[index];
    setState(() => _filteredSemesters.removeAt(index));

    try {
      await _supabase.from('semester').delete().match({'semester_id': semesterId});
      setState(() => _semesters.removeWhere((s) => s['semester_id'] == semesterId));
    } catch (e) {
      setState(() => _filteredSemesters.insert(index, deletedSemester));
      throw 'Failed to delete: $e';
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? semester}) {
    final isEditing = semester != null;
    final semesterIdController = TextEditingController(text: isEditing ? semester!['semester_id'].toString() : '');
    final semesterNumberController = TextEditingController(text: isEditing ? semester!['semester_number'].toString() : '');
    final maxCoursesController = TextEditingController(text: isEditing ? semester!['max_courses'].toString() : '');
    final coreCoursesController = TextEditingController(text: isEditing ? semester!['core_courses'].toString() : '');
    final electiveCoursesController = TextEditingController(text: isEditing ? semester!['elective_courses'].toString() : '');
    int? selectedProgramId = isEditing ? semester!['program_id'] : null;
    bool isFinalSemester = isEditing ? semester!['is_final_semester'] : false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Semester",
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
                      isEditing ? 'Edit Semester' : 'Add New Semester',
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
                          controller: semesterIdController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Semester ID',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                        ),
                      if (isEditing) const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedProgramId,
                        decoration: InputDecoration(
                          labelText: 'Program',
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
                        items: _programs.map((program) {
                          return DropdownMenuItem<int>(
                            value: program['program_id'],
                            child: Text(program['program_name']),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedProgramId = value),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: semesterNumberController,
                        labelText: 'Semester Number',
                        prefixIcon: Icons.format_list_numbered,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: maxCoursesController,
                        labelText: 'Max Courses',
                        prefixIcon: Icons.book,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: coreCoursesController,
                        labelText: 'Core Courses',
                        prefixIcon: Icons.bookmark,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: electiveCoursesController,
                        labelText: 'Elective Courses',
                        prefixIcon: Icons.bookmark_border,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Is Final Semester'),
                        value: isFinalSemester,
                        onChanged: (value) => setDialogState(() => isFinalSemester = value ?? false),
                        activeColor: Colors.deepPurple,
                        controlAffinity: ListTileControlAffinity.leading,
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
                      final semesterNumber = int.tryParse(semesterNumberController.text);
                      final maxCourses = int.tryParse(maxCoursesController.text);
                      final coreCourses = int.tryParse(coreCoursesController.text);
                      final electiveCourses = int.tryParse(electiveCoursesController.text);

                      if (selectedProgramId == null ||
                          semesterNumber == null ||
                          maxCourses == null ||
                          coreCourses == null ||
                          electiveCourses == null) {
                        _showErrorMessage('All fields are required');
                        return;
                      }
                      if (semesterNumber <= 0) {
                        _showErrorMessage('Semester number must be greater than 0');
                        return;
                      }
                      if (maxCourses <= 0) {
                        _showErrorMessage('Max courses must be greater than 0');
                        return;
                      }
                      if (coreCourses < 0 || electiveCourses < 0) {
                        _showErrorMessage('Courses cannot be negative');
                        return;
                      }
                      if (coreCourses + electiveCourses > maxCourses) {
                        _showErrorMessage('Core + Elective courses cannot exceed Max Courses');
                        return;
                      }

                      Navigator.pop(context);
                      try {
                        await _addOrUpdateSemester(
                          semesterId: isEditing ? int.tryParse(semesterIdController.text) : null,
                          programId: selectedProgramId!,
                          semesterNumber: semesterNumber,
                          maxCourses: maxCourses,
                          coreCourses: coreCourses,
                          electiveCourses: electiveCourses,
                          isFinalSemester: isFinalSemester,
                        );
                        _showSuccessMessage(isEditing ? 'Semester updated successfully' : 'Semester added successfully');
                      } catch (e) {
                        final errorStr = e.toString();
                        if (errorStr.contains('unique_final_semester_index')) {
                          _showErrorMessage('Only one semester per program can be marked as final.');
                        } else {
                          _showErrorMessage('Operation failed: $e');
                        }
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
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepPurple, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.deepPurple.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
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
          Icons.school_outlined,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          _isSearching ? 'No semesters match your search' : 'No semesters available',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _isSearching ? 'Try a different search term' : 'Add your first semester',
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
            label: const Text('Add Semester'),
          ),
      ],
    );
  }

  Widget _buildSemesterCard(Map<String, dynamic> semester, int index) {
    return Hero(
      tag: 'semester_${semester['semester_id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showSemesterDetails(semester),
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
                            child: const Icon(Icons.school, color: Colors.deepPurple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Semester ${semester['semester_number']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${semester['program']['program_name']}',
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
                    const Icon(Icons.book, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Max Courses: ${semester['max_courses']}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddEditDialog(semester: semester),
                      tooltip: 'Edit',
                      splashRadius: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        try {
                          await _deleteSemester(semester['semester_id']);
                          _showSuccessMessage('Semester deleted successfully');
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

  void _showSemesterDetails(Map<String, dynamic> semester) {
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
                            'Semester ${semester['semester_number']}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          Text(
                            '${semester['program']['program_name']}',
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
                      _buildDetailItem(icon: Icons.school, title: 'Program', value: semester['program']['program_name']),
                      const Divider(),
                      _buildDetailItem(icon: Icons.format_list_numbered, title: 'Semester Number', value: semester['semester_number'].toString()),
                      _buildDetailItem(icon: Icons.book, title: 'Max Courses', value: semester['max_courses'].toString()),
                      _buildDetailItem(icon: Icons.bookmark, title: 'Core Courses', value: semester['core_courses'].toString()),
                      _buildDetailItem(icon: Icons.bookmark_border, title: 'Elective Courses', value: semester['elective_courses'].toString()),
                      _buildDetailItem(icon: Icons.flag, title: 'Is Final Semester', value: semester['is_final_semester'] ? 'Yes' : 'No'),
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
                              _showAddEditDialog(semester: semester);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () async {
                              Navigator.pop(context);
                              try {
                                await _deleteSemester(semester['semester_id']);
                                _showSuccessMessage('Semester deleted successfully');
                              } catch (e) {
                                _showErrorMessage('Failed to delete: $e');
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
                  hintText: 'Search semesters...',
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
                onChanged: (_) => _filterSemesters(),
              ),
            ),
          ],
        )
            : const Text('Semester Management'),
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
              'Loading semesters...',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple,
        onRefresh: _fetchSemestersAndPrograms,
        child: _filteredSemesters.isEmpty
            ? Center(child: _buildEmptyState())
            : Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredSemesters.length,
            itemBuilder: (context, index) {
              return _buildSemesterCard(_filteredSemesters[index], index);
            },
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Semester'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}