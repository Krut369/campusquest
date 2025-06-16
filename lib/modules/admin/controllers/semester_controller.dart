import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SemesterController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _filteredSemesters = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> get semesters => _filteredSemesters;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;

  set isSearching(bool value) {
    _isSearching = value;
    if (!_isSearching) {
      searchController.clear();
    }
    notifyListeners();
  }

  SemesterController() {
    searchController.addListener(_filterSemesters);
    _fetchSemesters();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterSemesters() {
    if (searchController.text.isEmpty) {
      _filteredSemesters = List.from(_semesters);
      _isSearching = false;
    } else {
      final query = searchController.text.toLowerCase();
      _filteredSemesters = _semesters.where((semester) {
        final year = semester['year'].toString().toLowerCase();
        final term = semester['term'].toString().toLowerCase();
        return year.contains(query) || term.contains(query);
      }).toList();
      _isSearching = true;
    }
    notifyListeners();
  }

  Future<void> _fetchSemesters() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('semester')
          .select()
          .order('year')
          .order('term');
      _semesters = List<Map<String, dynamic>>.from(response);
      _filteredSemesters = List.from(_semesters);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw 'Error fetching semesters: $e';
    }
  }

  Future<void> deleteSemester(String semesterId) async {
    final index = _filteredSemesters.indexWhere((s) => s['semester_id'] == semesterId);
    if (index == -1) return;

    final deletedSemester = _filteredSemesters[index];
    _filteredSemesters.removeAt(index);
    notifyListeners();

    try {
      await _supabase.from('semester').delete().match({'semester_id': semesterId});
      _semesters.removeWhere((s) => s['semester_id'] == semesterId);
    } catch (e) {
      _filteredSemesters.insert(index, deletedSemester);
      notifyListeners();
      throw 'Failed to delete: $e';
    }
  }

  Future<void> addOrUpdateSemester({
    String? semesterId,
    required int year,
    required String term,
  }) async {
    try {
      if (semesterId != null) {
        await _supabase.from('semester').update({
          'year': year,
          'term': term,
        }).match({'semester_id': semesterId});
      } else {
        await _supabase.from('semester').insert({
          'year': year,
          'term': term,
        });
      }
      await _fetchSemesters();
    } catch (e) {
      throw 'Operation failed: $e';
    }
  }

  Future<void> refreshSemesters() => _fetchSemesters();
}