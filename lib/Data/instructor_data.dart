// List of uploaded course materials
final List<Map<String, String>> courseMaterials = [
  {'title': 'Lecture 1 - Introduction', 'file': 'lecture1.pdf'},
  {'title': 'Lecture 2 - Advanced Topics', 'file': 'lecture2.pdf'},
];

// Instructor's assigned class schedule
final List<Map<String, String>> classSchedule = [
  {'course': 'CSE792', 'time': '08:00 AM - 09:30 AM', 'day': 'Monday'},
  {'course': 'CSE791', 'time': '10:00 AM - 11:30 AM', 'day': 'Wednesday'},
];

// Student marks data
final List<Map<String, dynamic>> studentMarks = [
  {'name': 'John Doe', 'course': 'CSE792', 'marks': 85},
  {'name': 'Jane Smith', 'course': 'CSE791', 'marks': 92},
];

// Student attendance data
final List<Map<String, dynamic>> studentAttendance = [
  {'name': 'John Doe', 'course': 'CSE792', 'status': 'Present'},
  {'name': 'Jane Smith', 'course': 'CSE791', 'status': 'Absent'},
];

final List<Map<String, dynamic>> instructorCourses = [
  {
    'course': 'CSE792',
    'students': [
      {
        'name': 'John Doe',
        'marks': 85,
        'attendance': [], // Initialize as an empty list
      },
      {
        'name': 'Jane Smith',
        'marks': 92,
        'attendance': [], // Initialize as an empty list
      },
    ],
  },
  {
    'course': 'CSE791',
    'students': [
      {
        'name': 'Alice Johnson',
        'marks': 78,
        'attendance': [], // Initialize as an empty list
      },
      {
        'name': 'Bob Brown',
        'marks': 88,
        'attendance': [], // Initialize as an empty list
      },
    ],
  },
];