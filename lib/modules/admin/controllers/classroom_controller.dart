import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClassroomController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _classrooms = [];
  List<Map<String, dynamic>> _filteredClassrooms = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> get classrooms => _filteredClassrooms;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  set isSearching(bool value) {
    _isSearching = value;
    if (!_isSearching) {
      searchController.clear();
    }
    notifyListeners();
  }

  ClassroomController() {
    searchController.addListener(_filterClassrooms);
    _fetchClassrooms();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterClassrooms() {
    if (searchController.text.isEmpty) {
      _filteredClassrooms = List.from(_classrooms);
      _isSearching = false;
    } else {
      final query = searchController.text.toLowerCase();
      _filteredClassrooms = _classrooms.where((classroom) {
        final building = classroom['building'].toString().toLowerCase();
        final roomNumber = classroom['room_number'].toString().toLowerCase();
        final capacity = classroom['capacity'].toString();
        return building.contains(query) ||
            roomNumber.contains(query) ||
            capacity.contains(query);
      }).toList();
      _isSearching = true;
    }
    notifyListeners();
  }

  Future<void> _fetchClassrooms() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('classroom')
          .select()
          .order('building')
          .order('room_number');

      _classrooms = List<Map<String, dynamic>>.from(response);
      _filteredClassrooms = List.from(_classrooms);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw 'Error fetching classrooms: $e';
    }
  }

  Future<void> deleteClassroom(String classroomId) async {
    final index = _filteredClassrooms.indexWhere((c) => c['classroom_id'] == classroomId);
    if (index == -1) return;

    final deletedClassroom = _filteredClassrooms[index];
    _filteredClassrooms.removeAt(index);
    notifyListeners();

    try {
      await _supabase.from('classroom').delete().match({'classroom_id': classroomId});
      _classrooms.removeWhere((c) => c['classroom_id'] == classroomId);
    } catch (e) {
      _filteredClassrooms.insert(index, deletedClassroom);
      notifyListeners();
      throw 'Failed to delete classroom: $e';
    }
  }

  Future<void> addOrUpdateClassroom({
    String? classroomId,
    required String building,
    required String roomNumber,
    required int capacity,
  }) async {
    try {
      if (classroomId != null) {
        await _supabase
            .from('classroom')
            .update({'capacity': capacity})
            .match({'classroom_id': classroomId});
      } else {
        await _supabase.from('classroom').insert({
          'building': building,
          'room_number': roomNumber,
          'capacity': capacity,
        });
      }
      await _fetchClassrooms();
    } catch (e) {
      throw classroomId != null
          ? 'Failed to update classroom: $e'
          : 'Failed to add classroom: $e';
    }
  }

  Future<void> refreshClassrooms() => _fetchClassrooms();
}