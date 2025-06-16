import 'package:campusquest/widgets/bottomnavigationbar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginController extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _email = '';
  String _phone = '';
  String _role = 'student'; // Default role
  String _errorMessage = '';

  bool _isLoggedIn = false;
  String? userId; // userId is expected to be a String
  int? _instructorId; // Instructor ID
  int? _studentId; // Add studentId
  String? _studentName; // Add student name
  String? _deptName; // Add department name
  int? _programId; // Add program ID
  int? _currentSemester; // Add current semester

  // Getters
  String get email => _email;
  String get phone => _phone;
  String get role => _role;
  String get errorMessage => _errorMessage;
  bool get isLoggedIn => _isLoggedIn;
  int? get instructorId => _instructorId;
  int? get studentId => _studentId; // Getter for studentId
  String? get studentName => _studentName; // Getter for student name
  String? get deptName => _deptName; // Getter for department name
  int? get programId => _programId; // Getter for program ID
  int? get currentSemester => _currentSemester; // Getter for current semester

  LoginController() {
    _loadLoginState();
  }

  // Load Login State from SharedPreferences
  Future<void> _loadLoginState() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      userId = prefs.getString('userId');
      _email = prefs.getString('userEmail') ?? '';
      _role = prefs.getString('userRole') ?? 'student';
      _instructorId = prefs.getInt('instructorId');
      _studentId = prefs.getInt('studentId'); // Load studentId
      _studentName = prefs.getString('studentName'); // Load student name
      _deptName = prefs.getString('deptName'); // Load department name
      _programId = prefs.getInt('programId'); // Load program ID
      _currentSemester =
          prefs.getInt('currentSemester'); // Load current semester
      notifyListeners();
    } catch (e) {
      print("Error loading login state: $e");
    }
  }

  void setEmail(String email) {
    _email = email.trim();
    notifyListeners();
  }

  void setPhone(String phone) {
    _phone = phone.trim();
    notifyListeners();
  }

  void setRole(String role) {
    _role = role;
    notifyListeners();
  }

  // Setter for studentName
  void setStudentName(String name) {
    _studentName = name;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Login Using Supabase
  Future<bool> login(BuildContext context) async {
    if (_email.isEmpty || _phone.isEmpty) {
      _errorMessage = 'Please enter both email and phone number.';
      notifyListeners();
      return false;
    }

    try {
      final response = await _supabase
          .from('users')
          .select('id, email, role')
          .eq('email', _email)
          .eq('phone_number', _phone)
          .single();

      if (response != null) {
        print("✅ Login Successful: ${response['email']}");

        _isLoggedIn = true;
        userId = response['id'].toString(); // Convert id to String
        _role = response['role'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', userId!);
        await prefs.setString('userEmail', _email);
        await prefs.setString('userRole', _role);

        // Fetch student details if the role is 'student'
        if (_role == 'student') {
          try {
            final studentData = await _supabase
                .from('student')
                .select(
                    'student_id, name, dept_name, program_id, current_semester')
                .eq('user_id', int.parse(userId!))
                .single();

            if (studentData != null) {
              _studentId = studentData['student_id'] as int;
              _studentName = studentData['name'] as String;
              _deptName = studentData['dept_name'] as String?;
              _programId = studentData['program_id'] as int;
              _currentSemester = studentData['current_semester'] as int;

              // Store student-specific data in SharedPreferences
              await prefs.setInt('studentId', _studentId!);
              await prefs.setString('studentName', _studentName!);
              if (_deptName != null)
                await prefs.setString('deptName', _deptName!);
              await prefs.setInt('programId', _programId!);
              await prefs.setInt('currentSemester', _currentSemester!);

              print(
                  "✅ Student data loaded: $_studentName, $_deptName, $_programId, $_currentSemester");
            }
          } catch (e) {
            print("Error fetching student data: $e");
            // Continue with login even if student data fetch fails
          }
        }
        // Fetch instructor details if the role is 'instructor'
        else if (_role == 'instructor') {
          try {
            final instructorData = await _supabase
                .from('instructor')
                .select('instructor_id, name, designation')
                .eq('user_id', int.parse(userId!))
                .single();

            if (instructorData != null) {
              _instructorId = instructorData['instructor_id'] as int;
              final instructorName = instructorData['name'] as String;
              final designation = instructorData['designation'] as String;

              // Store instructor-specific data
              await prefs.setInt('instructorId', _instructorId!);
              await prefs.setString('instructorName', instructorName);
              await prefs.setString('instructorDesignation', designation);

              print(
                  "✅ Instructor data loaded: $instructorName, $designation, $_instructorId");
            }
          } catch (e) {
            print("Error fetching instructor data: $e");
            // Continue with login even if instructor data fetch fails
          }
        }

        notifyListeners();

        // Navigate to HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BottomBar()),
        );
        return true;
      }
    } on PostgrestException catch (e) {
      // Handle invalid credentials
      _errorMessage = 'Invalid email or phone number.';
    } catch (e) {
      // Safely handle unexpected errors
      _errorMessage = "Unexpected error: ${_getErrorMessage(e)}";
      print(e);
    }

    notifyListeners();
    return false;
  }

  // Helper function to safely extract error messages
  String _getErrorMessage(dynamic error) {
    if (error is String) {
      return error; // If the error is already a string, return it directly
    } else if (error is Exception || error is Error) {
      return error.toString(); // Convert Exception or Error to string
    } else {
      return "An unknown error occurred."; // Fallback for other types
    }
  }

  // Logout Function
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      _isLoggedIn = false;
      userId = null;
      _email = '';
      _role = 'student';
      _instructorId = null;
      _studentId = null;
      _studentName = null;
      _deptName = null;
      _programId = null;
      _currentSemester = null;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Logout failed: $e');
    }
  }

  Future<void> restoreSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // Optionally, fetch user details from your DB if needed
      _isLoggedIn = true;
      userId = session.user?.id;
      // You may want to fetch and set the role, etc. here as well
      // For example, fetch user from 'users' table by userId and set _role
      notifyListeners();
    }
  }
}
