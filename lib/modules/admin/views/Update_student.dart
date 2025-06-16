import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class BulkStudentUpdateScreen extends StatefulWidget {
  const BulkStudentUpdateScreen({super.key});

  @override
  State<BulkStudentUpdateScreen> createState() => _BulkStudentUpdateScreenState();
}

class _BulkStudentUpdateScreenState extends State<BulkStudentUpdateScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _departments = [];
  Set<int> _selectedStudents = {};
  bool _isLoading = true;
  bool _updatingStudents = false;

  // Filters
  String? _selectedDepartment;
  int? _selectedProgramId;
  int? _selectedSemesterId;
  String _searchQuery = '';

  // For bulk update
  int? _targetSemesterId;
  final TextEditingController _rollNumberPrefixController = TextEditingController();
  final TextEditingController _rollNumberStartController = TextEditingController(text: '1');
  bool _showRollNumberSettings = false;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _rollNumberPrefixController.dispose();
    _rollNumberStartController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final studentResponse = await _supabase
          .from('student')
          .select('*, program(program_name, dept_name), users(email, phone_number), semester(semester_id, semester_number, program(program_name))')
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

  void _applyFilters() {
    setState(() {
      _filteredStudents = _students.where((student) {
        final matchesSearch = _searchQuery.isEmpty ||
            student['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (student['roll_number'] != null &&
                student['roll_number'].toString().toLowerCase().contains(_searchQuery.toLowerCase()));

        final matchesDepartment = _selectedDepartment == null ||
            student['dept_name'] == _selectedDepartment;

        final matchesProgram = _selectedProgramId == null ||
            student['program_id'] == _selectedProgramId;

        final matchesSemester = _selectedSemesterId == null ||
            student['current_semester'] == _selectedSemesterId;

        return matchesSearch && matchesDepartment && matchesProgram && matchesSemester;
      }).toList();

      _selectedStudents.clear();
      _selectAll = false;
    });
  }

  Future<void> _performBulkSemesterUpdate() async {
    if (_selectedStudents.isEmpty) {
      _showErrorMessage('No students selected');
      return;
    }

    if (_targetSemesterId == null) {
      _showErrorMessage('Please select a target semester');
      return;
    }

    setState(() => _updatingStudents = true);

    try {
      final semesterResponse = await _supabase
          .from('semester')
          .select('semester_id, semester_number, program_id')
          .eq('semester_id', _targetSemesterId!)
          .single();

      List<int> successfulUpdates = [];
      List<int> failedUpdates = [];

      for (var studentId in _selectedStudents) {
        try {
          final student = _filteredStudents.firstWhere(
                  (s) => s['student_id'] == studentId);

          if (student['program_id'] != semesterResponse['program_id']) {
            failedUpdates.add(studentId);
            continue;
          }

          await _supabase.from('student').update({
            'current_semester': _targetSemesterId,
          }).match({'student_id': studentId});

          successfulUpdates.add(studentId);
        } catch (e) {
          failedUpdates.add(studentId);
        }
      }

      if (successfulUpdates.isNotEmpty) {
        _showSuccessMessage(
            'Updated ${successfulUpdates.length} student(s) to the new semester');
      }

      if (failedUpdates.isNotEmpty) {
        _showErrorMessage(
            'Failed to update ${failedUpdates.length} student(s). Ensure the students are in the same program as the target semester.');
      }

      await _fetchData();
      _applyFilters();
    } catch (e) {
      _showErrorMessage('Update failed: $e');
    } finally {
      setState(() => _updatingStudents = false);
    }
  }

  Future<void> _generateRollNumbers() async {
    if (_selectedStudents.isEmpty) {
      _showErrorMessage('No students selected');
      return;
    }

    final prefix = _rollNumberPrefixController.text.trim();
    int startNumber;

    try {
      startNumber = int.parse(_rollNumberStartController.text);
      if (startNumber < 1) {
        _showErrorMessage('Starting number must be at least 1');
        return;
      }
    } catch (e) {
      _showErrorMessage('Please enter a valid number for the starting index');
      return;
    }

    setState(() => _updatingStudents = true);

    try {
      List<int> successfulUpdates = [];
      List<int> failedUpdates = [];
      int currentNumber = startNumber;

      List<Map<String, dynamic>> selectedStudents = _filteredStudents
          .where((s) => _selectedStudents.contains(s['student_id']))
          .toList();

      selectedStudents.sort((a, b) => a['name'].compareTo(b['name']));

      for (var student in selectedStudents) {
        try {
          String rollNumber = prefix;
          if (currentNumber < 10) {
            rollNumber += '00$currentNumber';
          } else if (currentNumber < 100) {
            rollNumber += '0$currentNumber';
          } else {
            rollNumber += currentNumber.toString();
          }

          await _supabase.from('student').update({
            'roll_number': rollNumber,
          }).match({'student_id': student['student_id']});

          successfulUpdates.add(student['student_id']);
          currentNumber++;
        } catch (e) {
          failedUpdates.add(student['student_id']);
        }
      }

      if (successfulUpdates.isNotEmpty) {
        _showSuccessMessage(
            'Assigned roll numbers to ${successfulUpdates.length} student(s)');
      }

      if (failedUpdates.isNotEmpty) {
        _showErrorMessage(
            'Failed to assign roll numbers to ${failedUpdates.length} student(s)');
      }

      await _fetchData();
      _applyFilters();
    } catch (e) {
      _showErrorMessage('Roll number assignment failed: $e');
    } finally {
      setState(() => _updatingStudents = false);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedStudents.clear();
      } else {
        _selectedStudents = _filteredStudents
            .map((student) => student['student_id'] as int)
            .toSet();
      }
      _selectAll = !_selectAll;
    });
  }

  void _toggleStudentSelection(int studentId) {
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
      } else {
        _selectedStudents.add(studentId);
      }
      _selectAll = _selectedStudents.length == _filteredStudents.length;
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedDepartment = null;
      _selectedProgramId = null;
      _selectedSemesterId = null;
      _searchQuery = '';
      _filteredStudents = List.from(_students);
      _selectedStudents.clear();
      _selectAll = false;
    });
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
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

  Widget _buildFilterSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 600;
        final padding = isLargeScreen ? 24.0 : 16.0;
        final fontSize = isLargeScreen ? 16.0 : 14.0;

        return Card(
          margin: EdgeInsets.all(padding),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 800), // Limit card width on large screens
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.deepPurple, size: isLargeScreen ? 24 : 20),
                    SizedBox(width: padding / 2),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: Icon(Icons.refresh, size: isLargeScreen ? 20 : 18),
                      label: Text('Reset', style: TextStyle(fontSize: fontSize)),
                      style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                    ),
                  ],
                ),
                const Divider(),
                SizedBox(height: padding / 2),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or roll number',
                    prefixIcon: Icon(Icons.search, color: Colors.deepPurple, size: isLargeScreen ? 24 : 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.deepPurple.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: isLargeScreen ? 12 : 8),
                    fillColor: Colors.deepPurple.shade50,
                    filled: true,
                    hintStyle: TextStyle(fontSize: fontSize),
                  ),
                  style: TextStyle(fontSize: fontSize),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _applyFilters();
                  },
                ),
                SizedBox(height: padding),
                isLargeScreen
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDepartment,
                        decoration: _inputDecoration('Department', Icons.business, fontSize),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Departments', style: TextStyle(fontSize: fontSize)),
                          ),
                          ..._departments.map((dept) => DropdownMenuItem<String>(
                            value: dept['dept_name'],
                            child: Text(dept['dept_name'], style: TextStyle(fontSize: fontSize)),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedDepartment = value;
                            _selectedProgramId = null;
                            _selectedSemesterId = null;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    SizedBox(width: padding),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedProgramId,
                        decoration: _inputDecoration('Program', Icons.school, fontSize),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text('All Programs', style: TextStyle(fontSize: fontSize)),
                          ),
                          ..._programs
                              .where((program) =>
                          _selectedDepartment == null ||
                              program['dept_name'] == _selectedDepartment)
                              .map((program) => DropdownMenuItem<int>(
                            value: program['program_id'],
                            child: Text(program['program_name'], style: TextStyle(fontSize: fontSize)),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProgramId = value;
                            _selectedSemesterId = null;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: _inputDecoration('Department', Icons.business, fontSize),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Departments', style: TextStyle(fontSize: fontSize)),
                        ),
                        ..._departments.map((dept) => DropdownMenuItem<String>(
                          value: dept['dept_name'],
                          child: Text(dept['dept_name'], style: TextStyle(fontSize: fontSize)),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value;
                          _selectedProgramId = null;
                          _selectedSemesterId = null;
                        });
                        _applyFilters();
                      },
                    ),
                    SizedBox(height: padding),
                    DropdownButtonFormField<int>(
                      value: _selectedProgramId,
                      decoration: _inputDecoration('Program', Icons.school, fontSize),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: Text('All Programs', style: TextStyle(fontSize: fontSize)),
                        ),
                        ..._programs
                            .where((program) =>
                        _selectedDepartment == null ||
                            program['dept_name'] == _selectedDepartment)
                            .map((program) => DropdownMenuItem<int>(
                          value: program['program_id'],
                          child: Text(program['program_name'], style: TextStyle(fontSize: fontSize)),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedProgramId = value;
                          _selectedSemesterId = null;
                        });
                        _applyFilters();
                      },
                    ),
                  ],
                ),
                SizedBox(height: padding),
                DropdownButtonFormField<int>(
                  value: _selectedSemesterId,
                  decoration: _inputDecoration('Current Semester', Icons.calendar_today, fontSize),
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('All Semesters', style: TextStyle(fontSize: fontSize)),
                    ),
                    ..._semesters
                        .where((semester) =>
                    _selectedProgramId == null ||
                        semester['program_id'] == _selectedProgramId)
                        .map((semester) => DropdownMenuItem<int>(
                      value: semester['semester_id'],
                      child: Text(
                        'Semester ${semester['semester_number']} - ${semester['program']['program_name']}',
                        style: TextStyle(fontSize: fontSize),
                      ),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedSemesterId = value);
                    _applyFilters();
                  },
                ),
                SizedBox(height: padding),
                ElevatedButton.icon(
                  icon: Icon(Icons.filter_alt, size: isLargeScreen ? 20 : 18),
                  label: Text('Apply Filters', style: TextStyle(fontSize: fontSize)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 14 : 12, horizontal: padding),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size(double.infinity, isLargeScreen ? 48 : 44),
                  ),
                  onPressed: _applyFilters,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBulkUpdateSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 600;
        final padding = isLargeScreen ? 24.0 : 16.0;
        final fontSize = isLargeScreen ? 16.0 : 14.0;

        return Card(
          margin: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 800),
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.update, color: Colors.deepPurple, size: isLargeScreen ? 24 : 20),
                    SizedBox(width: padding / 2),
                    Text(
                      'Bulk Updates',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                SizedBox(height: padding / 2),
                ExpansionTile(
                  title: Row(
                    children: [
                      Icon(Icons.school, color: Colors.deepPurple, size: isLargeScreen ? 20 : 18),
                      SizedBox(width: padding / 2),
                      Text(
                        'Semester Update',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: fontSize),
                      ),
                    ],
                  ),
                  childrenPadding: EdgeInsets.all(padding),
                  children: [
                    DropdownButtonFormField<int>(
                      value: _targetSemesterId,
                      decoration: _inputDecoration('Target Semester', Icons.change_circle, fontSize),
                      items: _semesters.map((semester) => DropdownMenuItem<int>(
                        value: semester['semester_id'],
                        child: Text(
                          'Semester ${semester['semester_number']} - ${semester['program']['program_name']}',
                          style: TextStyle(fontSize: fontSize),
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => _targetSemesterId = value),
                    ),
                    SizedBox(height: padding),
                    ElevatedButton.icon(
                      icon: Icon(Icons.people, size: isLargeScreen ? 20 : 18),
                      label: Text(
                        'Update ${_selectedStudents.length} Students',
                        style: TextStyle(fontSize: fontSize),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 14 : 12, horizontal: padding),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size(double.infinity, isLargeScreen ? 48 : 44),
                      ),
                      onPressed: _selectedStudents.isEmpty ? null : _performBulkSemesterUpdate,
                    ),
                  ],
                ),
                ExpansionTile(
                  title: Row(
                    children: [
                      Icon(Icons.format_list_numbered, color: Colors.deepPurple, size: isLargeScreen ? 20 : 18),
                      SizedBox(width: padding / 2),
                      Text(
                        'Roll Number Assignment',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: fontSize),
                      ),
                    ],
                  ),
                  onExpansionChanged: (expanded) {
                    setState(() => _showRollNumberSettings = expanded);
                  },
                  childrenPadding: EdgeInsets.all(padding),
                  children: [
                    TextField(
                      controller: _rollNumberPrefixController,
                      decoration: _inputDecoration('Roll Number Prefix (e.g. CS)', Icons.label, fontSize),
                      style: TextStyle(fontSize: fontSize),
                    ),
                    SizedBox(height: padding),
                    TextField(
                      controller: _rollNumberStartController,
                      decoration: _inputDecoration('Starting Number', Icons.filter_1, fontSize),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: fontSize),
                    ),
                    SizedBox(height: padding),
                    Text(
                      'Preview: ${_rollNumberPrefixController.text}001, ${_rollNumberPrefixController.text}002, ...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                        fontSize: fontSize - 2,
                      ),
                    ),
                    SizedBox(height: padding),
                    ElevatedButton.icon(
                      icon: Icon(Icons.numbers, size: isLargeScreen ? 20 : 18),
                      label: Text(
                        'Assign Roll Numbers to ${_selectedStudents.length} Students',
                        style: TextStyle(fontSize: fontSize),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 14 : 12, horizontal: padding),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size(double.infinity, isLargeScreen ? 48 : 44),
                      ),
                      onPressed: _selectedStudents.isEmpty ? null : _generateRollNumbers,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 600;
        final padding = isLargeScreen ? 24.0 : 16.0;
        final fontSize = isLargeScreen ? 16.0 : 14.0;

        return Card(
          margin: EdgeInsets.all(padding),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Colors.deepPurple, size: isLargeScreen ? 24 : 20),
                          SizedBox(width: padding / 2),
                          Text(
                            'Students (${_filteredStudents.length})',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Checkbox(
                                value: _selectAll,
                                onChanged: (_) => _toggleSelectAll(),
                                activeColor: Colors.deepPurple,
                              ),
                              Text(
                                'Select All',
                                style: TextStyle(fontSize: fontSize),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_selectedStudents.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: padding / 2),
                          child: Text(
                            '${_selectedStudents.length} students selected',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _filteredStudents.isEmpty
                    ? Padding(
                  padding: EdgeInsets.all(padding * 1.5),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.person_search, size: isLargeScreen ? 56 : 48, color: Colors.grey),
                        SizedBox(height: padding),
                        Text(
                          'No students match your criteria',
                          style: TextStyle(
                            fontSize: fontSize,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _filteredStudents.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = _filteredStudents[index];
                    final isSelected = _selectedStudents.contains(student['student_id']);

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 4),
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleStudentSelection(student['student_id']),
                        activeColor: Colors.deepPurple,
                      ),
                      title: Text(
                        student['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roll Number: ${student['roll_number'] ?? 'Not Assigned'}',
                            style: TextStyle(fontSize: fontSize - 2),
                          ),
                          Text(
                            '${student['program']['program_name']} - Semester ${student['semester']['semester_number']}',
                            style: TextStyle(fontSize: fontSize - 2),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.info_outline, size: isLargeScreen ? 24 : 20),
                        onPressed: () => _showStudentDetails(student),
                      ),
                      onTap: () => _toggleStudentSelection(student['student_id']),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) {
        final isLargeScreen = MediaQuery.of(context).size.width > 600;
        final fontSize = isLargeScreen ? 16.0 : 14.0;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            student['name'],
            style: TextStyle(fontSize: isLargeScreen ? 20 : 18, color: Colors.deepPurple.shade700),
          ),
          content: Container(
            constraints: BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailItem('Student ID', '${student['student_id']}', fontSize),
                  _buildDetailItem('Roll Number', student['roll_number'] ?? 'Not Assigned', fontSize),
                  _buildDetailItem('Email', student['users']['email'] ?? 'N/A', fontSize),
                  _buildDetailItem('Program', student['program']['program_name'], fontSize),
                  _buildDetailItem('Department', student['dept_name'], fontSize),
                  _buildDetailItem('Semester', '${student['semester']['semester_number']}', fontSize),
                  _buildDetailItem('Phone', student['users']['phone_number'] ?? 'N/A', fontSize),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(fontSize: fontSize, color: Colors.deepPurple),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String labelText, IconData prefixIcon, double fontSize) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.deepPurple.shade300, fontSize: fontSize),
      prefixIcon: Icon(prefixIcon, color: Colors.deepPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.deepPurple.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.deepPurple, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: fontSize - 2),
      fillColor: Colors.deepPurple.shade50,
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Student Update'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
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
              'Loading data...',
              style: TextStyle(fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterSection(context),
                    _buildBulkUpdateSection(context),
                    _buildStudentList(context),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  ],
                ),
              );
            },
          ),
          if (_updatingStudents)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.deepPurple),
                        const SizedBox(height: 16),
                        Text(
                          'Processing...',
                          style: TextStyle(fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedStudents.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: null, // Disabled as it's just for display
        icon: Icon(Icons.check_circle, size: MediaQuery.of(context).size.width > 600 ? 24 : 20),
        label: Text(
          '${_selectedStudents.length} selected',
          style: TextStyle(fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}