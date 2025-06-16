import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgramController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _filteredPrograms = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> get programs => _filteredPrograms;
  List<Map<String, dynamic>> get departments => _departments;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;

  set isSearching(bool value) {
    _isSearching = value;
    if (!_isSearching) {
      searchController.clear();
    }
    notifyListeners();
  }

  ProgramController() {
    searchController.addListener(_filterPrograms);
    _fetchPrograms();
    _fetchDepartments();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterPrograms() {
    if (searchController.text.isEmpty) {
      _filteredPrograms = List.from(_programs);
      _isSearching = false;
    } else {
      final query = searchController.text.toLowerCase();
      _filteredPrograms = _programs.where((program) {
        final name = program['program_name'].toString().toLowerCase();
        final dept = program['dept_name'].toString().toLowerCase();
        return name.contains(query) || dept.contains(query);
      }).toList();
      _isSearching = true;
    }
    notifyListeners();
  }

  Future<void> _fetchPrograms() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('programs')  // Changed from 'program' to 'programs'
          .select()
          .order('program_name');
      _programs = List<Map<String, dynamic>>.from(response);
      _filteredPrograms = List.from(_programs);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw 'Error fetching programs: $e';
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await _supabase
          .from('department')
          .select()
          .order('dept_name');
      _departments = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      throw 'Error fetching departments: $e';
    }
  }

  Future<void> deleteProgram(int programId) async {
    final index = _filteredPrograms.indexWhere((p) => p['program_id'] == programId);
    if (index == -1) return;

    final deletedProgram = _filteredPrograms[index];
    _filteredPrograms.removeAt(index);
    notifyListeners();

    try {
      await _supabase
          .from('programs')  // Changed from 'program' to 'programs'
          .delete()
          .match({'program_id': programId});
      _programs.removeWhere((p) => p['program_id'] == programId);
    } catch (e) {
      _filteredPrograms.insert(index, deletedProgram);
      notifyListeners();
      throw 'Failed to delete: $e';
    }
  }

  Future<void> addOrUpdateProgram({
    int? programId,  // Changed type to int?
    required String programName,
    required int batchYear,
    required int totalSemesters,
    required String deptName,
  }) async {
    // Validate batch_year
    if (batchYear < DateTime.now().year || batchYear > 2100) {
      throw 'Batch year must be between the current year and 2100.';
    }

    // Validate total_semesters
    if (totalSemesters <= 0) {
      throw 'Total semesters must be a positive number.';
    }

    try {
      if (programId != null) {
        await _supabase
            .from('programs')  // Changed from 'program' to 'programs'
            .update({
          'program_name': programName,
          'batch_year': batchYear,
          'total_semesters': totalSemesters,
          'dept_name': deptName,
        })
            .match({'program_id': programId});
      } else {
        await _supabase.from('programs').insert({
          // 'program_id': const Uuid().v4(),  // This should be an integer, but UUIDs are typically strings
          'program_name': programName,
          'batch_year': batchYear,
          'total_semesters': totalSemesters,
          'dept_name': deptName,
        });
      }
      await _fetchPrograms();
    } catch (e) {
      throw 'Operation failed: $e';
    }
  }

  Future<void> refreshPrograms() => _fetchPrograms();
}