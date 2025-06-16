import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardController extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  int _programsCount = 0;
  int _studentsCount = 0;
  int _instructorsCount = 0;
  int _classroomsCount = 0;
  int _coursesCount = 0;

  int get programsCount => _programsCount;
  int get studentsCount => _studentsCount;
  int get instructorsCount => _instructorsCount;
  int get classroomsCount => _classroomsCount;
  int get coursesCount => _coursesCount;

  Future<void> fetchCounts(BuildContext context) async {
    try {
      final programsResponse = await supabase.from('Programs').select('count');
      final studentsResponse = await supabase.from('student').select('count');
      final instructorsResponse = await supabase.from('instructor').select('count');
      final classroomsResponse = await supabase.from('classroom').select('count');
      final coursesResponse = await supabase.from('course').select('count');

      _programsCount = programsResponse[0]['count'] ?? 0;
      _studentsCount = studentsResponse[0]['count'] ?? 0;
      _instructorsCount = instructorsResponse[0]['count'] ?? 0;
      _classroomsCount = classroomsResponse[0]['count'] ?? 0;
      _coursesCount = coursesResponse[0]['count'] ?? 0;

      notifyListeners();
    } catch (e) {
      print('Error fetching counts: $e');

      _programsCount = 0;
      _studentsCount = 0;
      _instructorsCount = 0;
      _classroomsCount = 0;
      _coursesCount = 0;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching counts: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      notifyListeners();
    }
  }

  void logout(BuildContext context) {
    supabase.auth.signOut();
  }
}