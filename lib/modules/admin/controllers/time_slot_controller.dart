import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TimeSlotController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _timeSlots = [];
  List<Map<String, dynamic>> _filteredTimeSlots = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> get timeSlots => _filteredTimeSlots;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;

  set isSearching(bool value) {
    _isSearching = value;
    if (!_isSearching) {
      searchController.clear();
    }
    notifyListeners();
  }

  TimeSlotController() {
    searchController.addListener(_filterTimeSlots);
    _fetchTimeSlots();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTimeSlots() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('time_slot')
          .select()
          .order('day')
          .order('start_time');

      _timeSlots = List<Map<String, dynamic>>.from(response);
      _filteredTimeSlots = List.from(_timeSlots);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw 'Error fetching time slots: $e';
    }
  }

  void _filterTimeSlots() {
    if (searchController.text.isEmpty) {
      _filteredTimeSlots = List.from(_timeSlots);
      _isSearching = false;
    } else {
      final query = searchController.text.toLowerCase();
      _filteredTimeSlots = _timeSlots.where((ts) {
        final id = ts['time_slot_id'];
        return ts['day'].toString().toLowerCase().contains(query) ||
            ts['start_time'].toString().contains(query) ||
            ts['end_time'].toString().contains(query) ||
            (id is int && id.toString().contains(query)) ||
            (id is String && id.contains(query));
      }).toList();
      _isSearching = true;
    }
    notifyListeners();
  }

  Future<void> deleteTimeSlot(int timeSlotId) async {
    final index = _filteredTimeSlots.indexWhere((ts) => ts['time_slot_id'] == timeSlotId);
    if (index == -1) return;

    final deletedSlot = _filteredTimeSlots[index];
    _filteredTimeSlots.removeAt(index);
    notifyListeners();

    try {
      await _supabase.from('time_slot').delete().match({'time_slot_id': timeSlotId});
      _timeSlots.removeWhere((ts) => ts['time_slot_id'] == timeSlotId);
    } catch (e) {
      _filteredTimeSlots.insert(index, deletedSlot);
      notifyListeners();
      throw 'Delete failed: $e';
    }
  }

  Future<void> addOrUpdateTimeSlot({
    int? timeSlotId,
    required String day,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    try {
      final startTimeFormatted = formatTimeForDB(startTime);
      final endTimeFormatted = formatTimeForDB(endTime);

      if (timeSlotId != null) {
        await _supabase.from('time_slot').update({
          'day': day,
          'start_time': startTimeFormatted,
          'end_time': endTimeFormatted,
        }).match({'time_slot_id': timeSlotId});
      } else {
        await _supabase.from('time_slot').insert({
          'day': day,
          'start_time': startTimeFormatted,
          'end_time': endTimeFormatted,
        });
      }
      await _fetchTimeSlots();
    } catch (e) {
      throw timeSlotId != null ? 'Update failed: $e' : 'Add failed: $e';
    }
  }

  String formatTimeFromDB(String dbTime) {
    try {
      final dateTime = DateFormat('HH:mm:ss').parse(dbTime);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return dbTime;
    }
  }

  String formatTimeForDB(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    return DateFormat('HH:mm').format(DateTime(now.year, now.month, now.day, time.hour, time.minute));
  }

  TimeOfDay? parseTime(String timeString) {
    try {
      final parsedTime = DateFormat('HH:mm').parse(timeString);
      return TimeOfDay.fromDateTime(parsedTime);
    } catch (e) {
      return null;
    }
  }

  int calculateDuration(String start, String end) {
    try {
      final startTime = DateFormat('HH:mm:ss').parse(start);
      final endTime = DateFormat('HH:mm:ss').parse(end);
      return endTime.difference(startTime).inMinutes;
    } catch (e) {
      return 0;
    }
  }

  Future<void> refreshTimeSlots() => _fetchTimeSlots();
}