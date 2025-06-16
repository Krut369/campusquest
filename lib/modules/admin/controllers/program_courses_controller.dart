import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class ProgramCoursesController {
  final BuildContext context;
  final void Function(void Function()) setStateCallback;
  final TickerProvider vsync;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _programCourses = [];
  List<Map<String, dynamic>> filteredProgramCourses = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _courses = [];
  bool isLoading = true;
  bool isSearching = false;

  late AnimationController animationController;
  late Animation<double> fabAnimation;
  final refreshKey = GlobalKey<RefreshIndicatorState>();
  final TextEditingController searchController = TextEditingController();

  ProgramCoursesController(_programCoursesScreenState, {
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

    searchController.addListener(filterProgramCourses);
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
      final futures = await Future.wait([
        _fetchProgramCourses(),
        _fetchPrograms(),
        _fetchCourses(),
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

  Future<void> _fetchProgramCourses() async {
    try {
      final response = await _supabase
          .from('program_courses')
          .select('*')
          .order('program_id')
          .order('course_id');

      setStateCallback(() {
        _programCourses = (response as List).cast<Map<String, dynamic>>();
        filteredProgramCourses = List.from(_programCourses);
      });
    } catch (e) {
      showErrorMessage('Error fetching program courses: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _fetchPrograms() async {
    try {
      final response = await _supabase
          .from('program')
          .select()
          .order('program_name');

      setStateCallback(() {
        _programs = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      showErrorMessage('Error fetching programs: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await _supabase
          .from('course')
          .select()
          .order('title');

      setStateCallback(() {
        _courses = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      showErrorMessage('Error fetching courses: ${e.toString()}');
      rethrow;
    }
  }

  void filterProgramCourses() {
    if (searchController.text.isEmpty) {
      setStateCallback(() {
        filteredProgramCourses = List.from(_programCourses);
        isSearching = false;
      });
      return;
    }

    final query = searchController.text.toLowerCase();
    setStateCallback(() {
      filteredProgramCourses = _programCourses.where((programCourse) {
        final programName = _getProgramName(programCourse['program_id']);
        final courseTitle = _getCourseTitle(programCourse['course_id']);
        final isCompulsory = programCourse['is_compulsory'].toString();

        return programName.toLowerCase().contains(query) ||
            courseTitle.toLowerCase().contains(query) ||
            isCompulsory.contains(query);
      }).toList();
      isSearching = true;
    });
  }

  String _getProgramName(String programId) {
    final program = _programs.firstWhere(
          (program) => program['program_id'] == programId,
      orElse: () => {'program_name': 'Unknown'},
    );
    return program['program_name'];
  }

  String _getCourseTitle(String courseId) {
    final course = _courses.firstWhere(
          (course) => course['course_id'] == courseId,
      orElse: () => {'title': 'Unknown'},
    );
    return course['title'];
  }

  Future<void> _deleteProgramCourse(String programId, String courseId, int index) async {
    final deletedProgramCourse = filteredProgramCourses[index];

    setStateCallback(() {
      filteredProgramCourses.removeAt(index);
    });

    try {
      await _supabase
          .from('program_courses')
          .delete()
          .match({'program_id': programId, 'course_id': courseId});

      showSuccessMessage(
        'Program-Course association deleted',
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            try {
              await _supabase.from('program_courses').insert(deletedProgramCourse);
              _fetchProgramCourses();
              showSuccessMessage('Program-Course association restored');
            } catch (e) {
              showErrorMessage('Failed to restore: $e');
            }
          },
        ),
      );

      _programCourses.removeWhere(
              (pc) => pc['program_id'] == programId && pc['course_id'] == courseId);
    } catch (e) {
      setStateCallback(() {
        filteredProgramCourses.insert(index, deletedProgramCourse);
      });
      showErrorMessage('Failed to delete: $e');
    }
  }

  void showAddEditDialog(BuildContext context, {Map<String, dynamic>? programCourse}) {
    final bool isEditing = programCourse != null;

    String? selectedProgramId = isEditing ? programCourse!['program_id'] : null;
    String? selectedCourseId = isEditing ? programCourse!['course_id'] : null;
    bool isCompulsory = isEditing ? programCourse!['is_compulsory'] : true;
    final electiveGroupIdController = TextEditingController(
      text: isEditing && programCourse!['elective_group_id'] != null
          ? programCourse!['elective_group_id'].toString()
          : '',
    );
    final electiveLimitController = TextEditingController(
      text: isEditing && programCourse!['elective_limit'] != null
          ? programCourse!['elective_limit'].toString()
          : '',
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Program-Course",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

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
                    isEditing ? 'Edit Program-Course' : 'Add Program-Course',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatefulBuilder(
                      builder: (context, setDropdownState) {
                        return DropdownButtonFormField<String>(
                          value: selectedProgramId,
                          onChanged: isEditing
                              ? null
                              : (String? newValue) {
                            setDropdownState(() {
                              selectedProgramId = newValue;
                            });
                          },
                          items: _programs.map((program) {
                            return DropdownMenuItem<String>(
                              value: program['program_id'],
                              child: Text(program['program_name']),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            labelText: 'Program',
                            labelStyle: TextStyle(color: Colors.deepPurple.shade300),
                            prefixIcon: const Icon(Icons.school, color: Colors.deepPurple),
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
                    StatefulBuilder(
                      builder: (context, setSwitchState) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.deepPurple.shade200),
                            color: Colors.deepPurple.shade50,
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Is Compulsory',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              isCompulsory
                                  ? 'This course is mandatory for the program'
                                  : 'This course is elective for the program',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            value: isCompulsory,
                            onChanged: (bool value) {
                              setSwitchState(() {
                                isCompulsory = value;
                              });
                            },
                            secondary: const Icon(Icons.assignment_turned_in, color: Colors.deepPurple),
                            activeColor: Colors.deepPurple,
                            activeTrackColor: Colors.deepPurple.shade200,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: electiveGroupIdController,
                      labelText: 'Elective Group ID',
                      prefixIcon: Icons.group_work,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: electiveLimitController,
                      labelText: 'Elective Limit',
                      prefixIcon: Icons.format_list_numbered,
                      keyboardType: TextInputType.number,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () async {
                    if (!isEditing && (selectedProgramId == null || selectedCourseId == null)) {
                      showErrorMessage('Program and Course are required');
                      return;
                    }

                    final int? electiveGroupId = electiveGroupIdController.text.isNotEmpty
                        ? int.tryParse(electiveGroupIdController.text)
                        : null;
                    final int? electiveLimit = electiveLimitController.text.isNotEmpty
                        ? int.tryParse(electiveLimitController.text)
                        : null;

                    if (!isCompulsory && (electiveGroupId == null || electiveLimit == null)) {
                      showErrorMessage('Elective Group ID and Elective Limit are required for electives');
                      return;
                    }

                    try {
                      if (isEditing) {
                        await _supabase.from('program_courses').update({
                          'is_compulsory': isCompulsory,
                          'elective_group_id': electiveGroupId,
                          'elective_limit': electiveLimit,
                        }).match({
                          'program_id': programCourse!['program_id'],
                          'course_id': programCourse!['course_id']
                        });
                        showSuccessMessage('Program-Course updated successfully');
                      } else {
                        await _supabase.from('program_courses').insert({
                          'program_id': selectedProgramId,
                          'course_id': selectedCourseId,
                          'is_compulsory': isCompulsory,
                          'elective_group_id': electiveGroupId,
                          'elective_limit': electiveLimit,
                        });
                        showSuccessMessage('Program-Course added successfully');
                      }

                      Navigator.pop(context);
                      _fetchProgramCourses();
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
          Icons.school_outlined,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          isSearching ? 'No associations match your search' : 'No program-course associations found',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isSearching ? 'Try a different search term' : 'Add an association to get started',
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
            label: const Text('Add Program-Course Association'),
          ),
      ],
    );
  }

  void showProgramCourseDetails(BuildContext context, Map<String, dynamic> programCourse) {
    final programName = _getProgramName(programCourse['program_id']);
    final courseTitle = _getCourseTitle(programCourse['course_id']);

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
                            '$programName',
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
                        icon: Icons.assignment_turned_in,
                        title: 'Is Compulsory',
                        value: programCourse['is_compulsory'] ? 'Yes' : 'No',
                      ),
                      if (!programCourse['is_compulsory']) ...[
                        const Divider(),
                        _buildDetailItem(
                          icon: Icons.group_work,
                          title: 'Elective Group ID',
                          value: '${programCourse['elective_group_id'] ?? 'N/A'}',
                        ),
                        const Divider(),
                        _buildDetailItem(
                          icon: Icons.format_list_numbered,
                          title: 'Elective Limit',
                          value: '${programCourse['elective_limit'] ?? 'N/A'}',
                        ),
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
                              showAddEditDialog(context, programCourse: programCourse);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              final index = filteredProgramCourses.indexWhere(
                                      (pc) =>
                                  pc['program_id'] == programCourse['program_id'] &&
                                      pc['course_id'] == programCourse['course_id']);
                              if (index != -1) {
                                _deleteProgramCourse(
                                  programCourse['program_id'],
                                  programCourse['course_id'],
                                  index,
                                );
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProgramCourseCard(BuildContext context, Map<String, dynamic> programCourse, int index) {
    final programName = _getProgramName(programCourse['program_id']);
    final courseTitle = _getCourseTitle(programCourse['course_id']);

    return Hero(
      tag: 'program_course_${programCourse['program_id']}_${programCourse['course_id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => showProgramCourseDetails(context, programCourse),
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
                                  programName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  courseTitle,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
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
                        color: programCourse['is_compulsory']
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: programCourse['is_compulsory']
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Text(
                        programCourse['is_compulsory'] ? 'Compulsory' : 'Elective',
                        style: TextStyle(
                          color: programCourse['is_compulsory']
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
                if (!programCourse['is_compulsory'] &&
                    (programCourse['elective_group_id'] != null || programCourse['elective_limit'] != null))
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Row(
                      children: [
                        if (programCourse['elective_group_id'] != null)
                          _buildInfoChip(
                            'Group ${programCourse['elective_group_id']}',
                            Icons.group_work,
                          ),
                        const SizedBox(width: 8),
                        if (programCourse['elective_limit'] != null)
                          _buildInfoChip(
                            'Limit: ${programCourse['elective_limit']}',
                            Icons.format_list_numbered,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => showAddEditDialog(context, programCourse: programCourse),
                      tooltip: 'Edit',
                      splashRadius: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProgramCourse(
                        programCourse['program_id'],
                        programCourse['course_id'],
                        index,
                      ),
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
        filteredProgramCourses = List.from(_programCourses);
      }
      isSearching = !isSearching;
    });
  }
}