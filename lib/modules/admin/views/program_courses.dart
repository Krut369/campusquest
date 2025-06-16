import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class ProgramCoursesScreen extends StatefulWidget {
  const ProgramCoursesScreen({super.key});

  @override
  State<ProgramCoursesScreen> createState() => _ProgramCoursesScreenState();
}

class _ProgramCoursesScreenState extends State<ProgramCoursesScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _programCourses = [];
  List<Map<String, dynamic>> _filteredProgramCourses = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _courses = [];
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

    _searchController.addListener(_filterProgramCourses);
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
      await Future.wait([
        _fetchProgramCourses(),
        _fetchPrograms(),
        _fetchCourses(),
      ]);
    } catch (e) {
      _showErrorMessage('Error fetching data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProgramCourses() async {
    try {
      final response = await _supabase.from('program_courses').select('*').order('program_id').order('course_id');
      setState(() {
        _programCourses = (response as List).cast<Map<String, dynamic>>();
        _filteredProgramCourses = List.from(_programCourses);
      });
    } catch (e) {
      _showErrorMessage('Error fetching program courses: $e');
      rethrow;
    }
  }

  Future<void> _fetchPrograms() async {
    try {
      final response = await _supabase.from('program').select().order('program_name');
      setState(() => _programs = (response as List).cast<Map<String, dynamic>>());
    } catch (e) {
      _showErrorMessage('Error fetching programs: $e');
      rethrow;
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await _supabase.from('course').select().order('title');
      setState(() => _courses = (response as List).cast<Map<String, dynamic>>());
    } catch (e) {
      _showErrorMessage('Error fetching courses: $e');
      rethrow;
    }
  }

  void _filterProgramCourses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredProgramCourses = _programCourses.where((programCourse) {
        final programName = _getProgramName(programCourse['program_id']).toLowerCase();
        final courseTitle = _getCourseTitle(programCourse['course_id']).toLowerCase();
        final isCompulsory = programCourse['is_compulsory'].toString().toLowerCase();
        return programName.contains(query) || courseTitle.contains(query) || isCompulsory.contains(query);
      }).toList();
    });
  }

  String _getProgramName(String programId) {
    return _programs.firstWhere(
          (program) => program['program_id'] == programId,
      orElse: () => {'program_name': 'Unknown'},
    )['program_name'] as String;
  }

  String _getCourseTitle(String courseId) {
    return _courses.firstWhere(
          (course) => course['course_id'] == courseId,
      orElse: () => {'title': 'Unknown'},
    )['title'] as String;
  }

  Future<void> _deleteProgramCourse(String programId, String courseId, int index) async {
    final deletedProgramCourse = _filteredProgramCourses[index];
    setState(() => _filteredProgramCourses.removeAt(index));
    try {
      await _supabase.from('program_courses').delete().match({'program_id': programId, 'course_id': courseId});
      _programCourses.removeWhere((pc) => pc['program_id'] == programId && pc['course_id'] == courseId);
      _showSuccessMessage(
        'Association deleted successfully',
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await _supabase.from('program_courses').insert(deletedProgramCourse);
              await _fetchProgramCourses();
              _showSuccessMessage('Association restored');
            } catch (e) {
              _showErrorMessage('Failed to restore: $e');
            }
          },
        ),
      );
    } catch (e) {
      setState(() => _filteredProgramCourses.insert(index, deletedProgramCourse));
      _showErrorMessage('Failed to delete: $e');
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? programCourse}) {
    final bool isEditing = programCourse != null;
    String? selectedProgramId = isEditing ? programCourse!['program_id'] : null;
    String? selectedCourseId = isEditing ? programCourse!['course_id'] : null;
    bool isCompulsory = isEditing ? programCourse!['is_compulsory'] : true;
    final electiveGroupIdController = TextEditingController(
      text: isEditing && programCourse!['elective_group_id'] != null ? programCourse!['elective_group_id'].toString() : '',
    );
    final electiveLimitController = TextEditingController(
      text: isEditing && programCourse!['elective_limit'] != null ? programCourse!['elective_limit'].toString() : '',
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Program-Course",
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
                    isEditing ? 'Edit Association' : 'Add New Association',
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
                        DropdownButtonFormField<String>(
                          value: selectedProgramId,
                          decoration: _inputDecoration('Program', Icons.school),
                          items: _programs
                              .map((program) => DropdownMenuItem<String>(
                            value: program['program_id'],
                            child: Text(program['program_name']),
                          ))
                              .toList(),
                          onChanged: isEditing ? null : (value) => setDialogState(() => selectedProgramId = value),
                          validator: (value) => value == null ? 'Program is required' : null,
                          disabledHint: Text(_getProgramName(selectedProgramId ?? '')),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCourseId,
                          decoration: _inputDecoration('Course', Icons.book),
                          items: _courses
                              .map((course) => DropdownMenuItem<String>(
                            value: course['course_id'],
                            child: Text(course['title']),
                          ))
                              .toList(),
                          onChanged: isEditing ? null : (value) => setDialogState(() => selectedCourseId = value),
                          validator: (value) => value == null ? 'Course is required' : null,
                          disabledHint: Text(_getCourseTitle(selectedCourseId ?? '')),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.deepPurple.shade200),
                            color: Colors.deepPurple.shade50,
                          ),
                          child: SwitchListTile(
                            title: const Text('Is Compulsory', style: TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              isCompulsory ? 'Mandatory course' : 'Elective course',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            value: isCompulsory,
                            onChanged: (value) => setDialogState(() => isCompulsory = value),
                            secondary: const Icon(Icons.assignment_turned_in, color: Colors.deepPurple),
                            activeColor: Colors.deepPurple,
                            activeTrackColor: Colors.deepPurple.shade200,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: electiveGroupIdController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Elective Group ID', Icons.group_work),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: electiveLimitController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Elective Limit', Icons.format_list_numbered),
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
                    if (!isEditing && (selectedProgramId == null || selectedCourseId == null)) {
                      _showErrorMessage('Program and Course are required');
                      return;
                    }
                    final int? electiveGroupId = electiveGroupIdController.text.isNotEmpty ? int.tryParse(electiveGroupIdController.text) : null;
                    final int? electiveLimit = electiveLimitController.text.isNotEmpty ? int.tryParse(electiveLimitController.text) : null;
                    if (!isCompulsory && (electiveGroupId == null || electiveLimit == null)) {
                      _showErrorMessage('Elective Group ID and Limit are required for electives');
                      return;
                    }
                    Navigator.pop(context);
                    try {
                      if (isEditing) {
                        await _supabase.from('program_courses').update({
                          'is_compulsory': isCompulsory,
                          'elective_group_id': electiveGroupId,
                          'elective_limit': electiveLimit,
                        }).match({'program_id': programCourse!['program_id'], 'course_id': programCourse!['course_id']});
                        _showSuccessMessage('Association updated successfully');
                      } else {
                        await _supabase.from('program_courses').insert({
                          'program_id': selectedProgramId,
                          'course_id': selectedCourseId,
                          'is_compulsory': isCompulsory,
                          'elective_group_id': electiveGroupId,
                          'elective_limit': electiveLimit,
                        });
                        _showSuccessMessage('Association added successfully');
                      }
                      _fetchProgramCourses();
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

  void _showProgramCourseDetails(Map<String, dynamic> programCourse) {
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
                            _getProgramName(programCourse['program_id']),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          Text(
                            _getCourseTitle(programCourse['course_id']),
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
                      _buildDetailItem(icon: Icons.assignment_turned_in, title: 'Is Compulsory', value: programCourse['is_compulsory'] ? 'Yes' : 'No'),
                      if (!programCourse['is_compulsory']) ...[
                        _buildDetailItem(icon: Icons.group_work, title: 'Elective Group ID', value: programCourse['elective_group_id']?.toString() ?? 'N/A'),
                        _buildDetailItem(icon: Icons.format_list_numbered, title: 'Elective Limit', value: programCourse['elective_limit']?.toString() ?? 'N/A'),
                      ],
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
                              _showAddEditDialog(programCourse: programCourse);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              final index = _filteredProgramCourses.indexWhere(
                                    (pc) => pc['program_id'] == programCourse['program_id'] && pc['course_id'] == programCourse['course_id'],
                              );
                              if (index != -1) _deleteProgramCourse(programCourse['program_id'], programCourse['course_id'], index);
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
        const Icon(Icons.school_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          _isSearching ? 'No associations match your search' : 'No program-course associations found',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _isSearching ? 'Try a different search term' : 'Add an association to get started',
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
            label: const Text('Add Association'),
          ),
      ],
    );
  }

  Widget _buildProgramCourseCard(Map<String, dynamic> programCourse, int index) {
    return Hero(
      tag: 'program_course_${programCourse['program_id']}_${programCourse['course_id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showProgramCourseDetails(programCourse),
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
                                  _getProgramName(programCourse['program_id']),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _getCourseTitle(programCourse['course_id']),
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
                        color: programCourse['is_compulsory'] ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: programCourse['is_compulsory'] ? Colors.green.shade300 : Colors.orange.shade300),
                      ),
                      child: Text(
                        programCourse['is_compulsory'] ? 'Compulsory' : 'Elective',
                        style: TextStyle(
                          color: programCourse['is_compulsory'] ? Colors.green.shade800 : Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!programCourse['is_compulsory'] && (programCourse['elective_group_id'] != null || programCourse['elective_limit'] != null))
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      if (programCourse['elective_group_id'] != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text('Group ${programCourse['elective_group_id']}', style: TextStyle(fontSize: 12)),
                            avatar: Icon(Icons.group_work, size: 16, color: Colors.deepPurple),
                            backgroundColor: Colors.deepPurple.shade50,
                            labelStyle: TextStyle(color: Colors.deepPurple.shade700),
                          ),
                        ),
                      if (programCourse['elective_limit'] != null)
                        Chip(
                          label: Text('Limit: ${programCourse['elective_limit']}', style: TextStyle(fontSize: 12)),
                          avatar: Icon(Icons.format_list_numbered, size: 16, color: Colors.deepPurple),
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
                      onPressed: () => _showAddEditDialog(programCourse: programCourse),
                      tooltip: 'Edit',
                      splashRadius: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProgramCourse(programCourse['program_id'], programCourse['course_id'], index),
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
                  hintText: 'Search programs or courses...',
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
                onChanged: (_) => _filterProgramCourses(),
              ),
            ),
          ],
        )
            : const Text('Program Courses'),
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
            Text('Loading associations...', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      )
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple,
        onRefresh: _fetchData,
        child: _filteredProgramCourses.isEmpty
            ? Center(child: _buildEmptyState())
            : Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredProgramCourses.length,
            itemBuilder: (context, index) => _buildProgramCourseCard(_filteredProgramCourses[index], index),
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Association'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}