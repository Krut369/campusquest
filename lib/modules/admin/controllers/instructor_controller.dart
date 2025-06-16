import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstructorController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _filteredInstructors = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> get instructors => _filteredInstructors;
  List<Map<String, dynamic>> get departments => _departments;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;

  set isSearching(bool value) {
    _isSearching = value;
    if (!_isSearching) {
      searchController.clear();
      _filteredInstructors = List.from(_instructors);
    }
    notifyListeners();
  }

  InstructorController() {
    searchController.addListener(_filterInstructors);
    _fetchInstructors();
    _fetchDepartments();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterInstructors() {
    if (searchController.text.isEmpty) {
      _filteredInstructors = List.from(_instructors);
      _isSearching = false;
    } else {
      final query = searchController.text.toLowerCase();
      _filteredInstructors = _instructors.where((instructor) {
        final name = instructor['name'].toString().toLowerCase();
        final department = (instructor['dept_name'] ?? '').toString().toLowerCase();
        final designation = instructor['designation'].toString().toLowerCase();
        final email = instructor['users']['email'].toString().toLowerCase();
        return name.contains(query) ||
            department.contains(query) ||
            designation.contains(query) ||
            email.contains(query);
      }).toList();
      _isSearching = true;
    }
    notifyListeners();
  }

  Future<void> _fetchInstructors() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('instructor')
          .select('*, users(*)') // Join with users table
          .order('instructor_id');
      _instructors = (response as List).cast<Map<String, dynamic>>();
      _filteredInstructors = List.from(_instructors);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw 'Error fetching instructors: $e';
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await _supabase.from('department').select('dept_name');
      _departments = (response as List).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      throw 'Error fetching departments: $e';
    }
  }

  Future<void> addOrUpdateInstructor({
    String? instructorId,
    String? userId,
    required String name,
    required String deptName,
    required String designation,
    required String qualification,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      if (instructorId != null && userId != null) {
        // Update existing user
        await _supabase.from('users').update({
          'email': email,
          'phone_number': phoneNumber,
        }).match({'id': userId});

        // Update instructor
        await _supabase.from('instructor').update({
          'dept_name': deptName,
          'designation': designation,
          'qualification': qualification,
          'name': name,
        }).match({'instructor_id': instructorId});
      } else {
        // Insert new user
        final userResponse = await _supabase.from('users').insert({
          'email': email,
          'phone_number': phoneNumber,
          'role': 'instructor', // Default role
        }).select();
        final newUserId = userResponse[0]['id'];

        // Insert new instructor
        await _supabase.from('instructor').insert({
          'user_id': newUserId,
          'dept_name': deptName,
          'designation': designation,
          'qualification': qualification,
          'name': name,
        });
      }
      await _fetchInstructors();
    } catch (e) {
      throw 'Operation failed: $e';
    }
  }

  Future<void> deleteInstructor(String instructorId) async {
    final index = _filteredInstructors.indexWhere((i) => i['instructor_id'] == instructorId);
    if (index == -1) return;

    final deletedInstructor = _filteredInstructors[index];
    _filteredInstructors.removeAt(index);
    notifyListeners();

    try {
      // Fetch the associated user ID
      final user = await _supabase
          .from('instructor')
          .select('user_id')
          .match({'instructor_id': instructorId})
          .single();

      // Delete the associated user
      await _supabase.from('users').delete().match({'id': user['user_id']});

      // Delete the instructor
      await _supabase.from('instructor').delete().match({'instructor_id': instructorId});

      _instructors.removeWhere((instructor) => instructor['instructor_id'] == instructorId);
    } catch (e) {
      _filteredInstructors.insert(index, deletedInstructor);
      notifyListeners();
      throw 'Failed to delete instructor: $e';
    }
  }

  Future<void> refreshInstructors() => _fetchInstructors();
}