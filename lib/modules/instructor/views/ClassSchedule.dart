import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassSchedule extends StatefulWidget {
  const ClassSchedule({super.key});

  @override
  State<ClassSchedule> createState() => _ClassScheduleState();
}

class _ClassScheduleState extends State<ClassSchedule> {
  final _supabase = Supabase.instance.client;
  String? selectedDay;
  List<Map<String, dynamic>> _schedule = [];
  bool _isLoading = true;
  String? _error;
  String? instructorName;
  String? designation;
  int? _instructorId;

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    // Set default to today's day
    final today = DateTime.now();
    selectedDay = _getDayName(today);
    // Load instructor data and schedule
    _loadInstructorData();
  }

  Future<void> _loadInstructorData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final savedName = prefs.getString('instructorName');
    final savedDesignation = prefs.getString('instructorDesignation');
    final savedInstructorId = prefs.getInt('instructorId');

    if (savedName != null && savedDesignation != null && savedInstructorId != null) {
      setState(() {
        instructorName = savedName;
        designation = savedDesignation;
        _instructorId = savedInstructorId;
        _isLoading = false;
      });
      await _fetchInstructorSchedule();
      return;
    }

    if (userId != null) {
      try {
        final instructorData = await _supabase
            .from('instructor')
            .select('instructor_id, name, designation')
            .eq('user_id', int.parse(userId))
            .single();

        if (instructorData != null) {
          final name = instructorData['name'] as String;
          final prof = instructorData['designation'] as String;
          final id = instructorData['instructor_id'] as int;
          await prefs.setString('instructorName', name);
          await prefs.setString('instructorDesignation', prof);
          await prefs.setInt('instructorId', id);
          setState(() {
            instructorName = name;
            designation = prof;
            _instructorId = id;
            _isLoading = false;
          });
          await _fetchInstructorSchedule();
        }
      } catch (e) {
        setState(() {
          _error = 'Error fetching instructor data: $e';
          _isLoading = false;
        });
        print('Error fetching instructor data: $e');
      }
    } else {
      setState(() {
        _error = 'User ID not found';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchInstructorSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_instructorId == null) {
        setState(() {
          _error = 'Instructor ID not found.';
          _isLoading = false;
        });
        return;
      }

      // Fetch courses the instructor teaches
      final teachesResponse = await _supabase
          .from('teaches')
          .select('course_id, semester_id')
          .eq('instructor_id', _instructorId!);

      if (teachesResponse.isEmpty) {
        setState(() {
          _schedule = [];
          _isLoading = false;
        });
        return;
      }

      final courseIds = teachesResponse.map((t) => t['course_id']).toList();
      final semesterIds = teachesResponse.map((t) => t['semester_id']).toList();

      // Fetch timetable entries
      final timetableResponse = await _supabase
          .from('timetable')
          .select('timetable_id, course_id, semester_id, time_slot_id, classroom_id')
          .inFilter('course_id', courseIds)
          .inFilter('semester_id', semesterIds);

      if (timetableResponse.isEmpty) {
        setState(() {
          _schedule = [];
          _isLoading = false;
        });
        return;
      }

      final timeSlotIds = timetableResponse.map((t) => t['time_slot_id']).toList();
      final classroomIds = timetableResponse.map((t) => t['classroom_id']).toList();

      // Fetch related data
      final coursesResponse = courseIds.isNotEmpty
          ? await _supabase.from('course').select('course_id, course_name').inFilter('course_id', courseIds)
          : [];

      final timeSlotsResponse = timeSlotIds.isNotEmpty
          ? await _supabase
          .from('time_slot')
          .select('time_slot_id, day, start_time, end_time')
          .inFilter('time_slot_id', timeSlotIds)
          : [];

      final classroomsResponse = classroomIds.isNotEmpty
          ? await _supabase
          .from('classroom')
          .select('classroom_id, building, room_number')
          .inFilter('classroom_id', classroomIds)
          : [];

      // Build schedule
      final schedule = timetableResponse.map((entry) {
        final course = coursesResponse.firstWhere(
              (c) => c['course_id'] == entry['course_id'],
          orElse: () => {'course_name': 'Unknown Course'},
        );
        final timeSlot = timeSlotsResponse.firstWhere(
              (ts) => ts['time_slot_id'] == entry['time_slot_id'],
          orElse: () => {
            'day': 'Unknown',
            'start_time': '00:00',
            'end_time': '00:00',
          },
        );
        final classroom = classroomsResponse.firstWhere(
              (cr) => cr['classroom_id'] == entry['classroom_id'],
          orElse: () => {'building': 'Unknown', 'room_number': ''},
        );

        return {
          'course': course['course_name'],
          'day': timeSlot['day'],
          'time': '${timeSlot['start_time']} - ${timeSlot['end_time']}',
          'classroom': '${classroom['building']} ${classroom['room_number']}',
          'start_time': timeSlot['start_time'], // For sorting
        };
      }).toList();

      // Sort by start_time
      schedule.sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));

      setState(() {
        _schedule = schedule;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error fetching schedule: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching schedule: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter schedule for the selected day
    final daySchedule = _schedule.where((s) => s['day'] == selectedDay).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Class Schedule',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Text(
          _error!,
          style: TextStyle(
            fontSize: 18,
            color: Colors.red.shade700,
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructor Info
            if (instructorName != null && designation != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.deepPurple.shade50,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      radius: 25,
                      child: Text(
                        instructorName!.isNotEmpty ? instructorName![0] : '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            instructorName!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            designation!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Section Title
            Text(
              'Your Schedule',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),

            // Day Dropdown
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Day',
                filled: true,
                fillColor: Colors.blue.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              value: selectedDay,
              items: days.map((day) {
                return DropdownMenuItem<String>(
                  value: day,
                  child: Text(day),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedDay = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Empty State Handling
            if (daySchedule.isEmpty)
              Center(
                child: Text(
                  'No classes scheduled on $selectedDay.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
            // List of Classes
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: daySchedule.length,
                itemBuilder: (context, index) {
                  final schedule = daySchedule[index];

                  // Check if the current day matches today's day
                  final today = DateTime.now();
                  final isToday = selectedDay == _getDayName(today);

                  return Column(
                    children: [
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isToday ? Colors.green.shade50 : Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule['course'] ?? 'Unknown Course',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? Colors.green.shade800 : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    schedule['day'] ?? 'Unknown Day',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    schedule['time'] ?? 'Unknown Time',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.room, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    schedule['classroom'] ?? 'Unknown Classroom',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index != daySchedule.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.shade300,
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to get the current day name
  String _getDayName(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday'; // Fallback
    }
  }
}