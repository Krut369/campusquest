// admin_data.dart

// Mock data for programs
// admin_data.dart

final List<Map<String, dynamic>> programs = [
  {'id': 1, 'name': 'Computer Science'},
  {'id': 2, 'name': 'Business Administration'},
  {'id': 3, 'name': 'Electrical Engineering'},
];
// Mock data for students
final List<Map<String, dynamic>> students = [
  {'id': 1, 'name': 'John Doe', 'program': 'Computer Science'},
  {'id': 2, 'name': 'Jane Smith', 'program': 'Business Administration'},
  {'id': 3, 'name': 'Alice Johnson', 'program': 'Electrical Engineering'},
];

// Mock data for instructors
final List<Map<String, dynamic>> instructors = [
  {'id': 1, 'name': 'Dr. Emily White', 'subject': 'Mathematics'},
  {'id': 2, 'name': 'Prof. Michael Brown', 'subject': 'Physics'},
];

// Mock data for classes
final List<Map<String, dynamic>> classes = [
  {'id': 1, 'name': 'CS101', 'program': 'Computer Science', 'instructor': 'Dr. Emily White'},
  {'id': 2, 'name': 'BA202', 'program': 'Business Administration', 'instructor': 'Prof. Michael Brown'},
];

// Mock data for courses
final List<Map<String, dynamic>> courses = [
  {'id': 1, 'name': 'Introduction to Programming', 'program': 'Computer Science'},
  {'id': 2, 'name': 'Marketing Fundamentals', 'program': 'Business Administration'},
];

// List of available instructors


// List of events
final List<Map<String, String>> events = [
  {
    'title': 'Cultural Fest',
    'date': '2023-11-10',
    'description': 'Annual cultural event for students and faculty.'
  },
  {
    'title': 'Guest Lecture on AI',
    'date': '2023-11-15',
    'description': 'Expert talk on Artificial Intelligence.'
  },
];