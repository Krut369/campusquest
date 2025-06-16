import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

class TimetablePageAdmin extends StatefulWidget {
  const TimetablePageAdmin({super.key});

  @override
  State<TimetablePageAdmin> createState() => _TimetablePageAdminState();
}

class _TimetablePageAdminState extends State<TimetablePageAdmin> {
  final _supabase = Supabase.instance.client;

  // Data fetched from Supabase
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _timeSlots = [];
  List<Map<String, dynamic>> _classrooms = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _timetable = [];

  // Loading states
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isAddingCourse = false;

  // Selected program and semester
  int? _selectedProgramId;
  int? _selectedSemesterId;

  // Random number generator for timetable
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _fetchPrograms();
  }

  Future<void> _fetchPrograms() async {
    setState(() => _isLoading = true);
    try {
      final programsResponse =
      await _supabase.from('program').select('program_id, program_name, batch_year');
      setState(() {
        _programs = List<Map<String, dynamic>>.from(programsResponse);
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching programs: $e'), backgroundColor: Colors.red.shade700),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSemesters(int programId) async {
    setState(() => _isLoading = true);
    try {
      final semestersResponse = await _supabase
          .from('semester')
          .select('semester_id, semester_number, elective_courses')
          .eq('program_id', programId);
      setState(() {
        _semesters = List<Map<String, dynamic>>.from(semestersResponse);
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching semesters: $e'), backgroundColor: Colors.red.shade700),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCourses(int semesterId) async {
    try {
      final coursesResponse = await _supabase
          .from('course')
          .select('course_id, course_name, category_id, l')
          .eq('semester_id', semesterId);
      setState(() {
        _courses = List<Map<String, dynamic>>.from(coursesResponse);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching courses: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _fetchTimeSlotsAndClassrooms() async {
    try {
      final timeSlotsResponse = await _supabase.from('time_slot').select();
      final classroomsResponse =
      await _supabase.from('classroom').select('classroom_id, building, room_number');
      setState(() {
        _timeSlots = List<Map<String, dynamic>>.from(timeSlotsResponse);
        _classrooms = List<Map<String, dynamic>>.from(classroomsResponse);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching time slots or classrooms: $e'),
            backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _fetchTimetable(int semesterId) async {
    setState(() => _isLoading = true);
    try {
      final timetableResponse = await _supabase
          .from('timetable')
          .select('timetable_id, course_id, time_slot_id, classroom_id')
          .eq('semester_id', semesterId);

      final courseIds = timetableResponse.map((t) => t['course_id']).toList();
      final coursesResponse = courseIds.isNotEmpty
          ? await _supabase.from('course').select('course_id, course_name').inFilter('course_id', courseIds)
          : [];

      final timeSlotIds = timetableResponse.map((t) => t['time_slot_id']).toList();
      final slotsResponse = timeSlotIds.isNotEmpty
          ? await _supabase
          .from('time_slot')
          .select('time_slot_id, day, start_time, end_time')
          .inFilter('time_slot_id', timeSlotIds)
          : [];

      final classroomIds = timetableResponse.map((t) => t['classroom_id']).toList();
      final classroomsResponse = classroomIds.isNotEmpty
          ? await _supabase
          .from('classroom')
          .select('classroom_id, building, room_number')
          .inFilter('classroom_id', classroomIds)
          : [];

      final timetableWithDetails = timetableResponse.map((entry) {
        final course = coursesResponse.firstWhere(
              (c) => c['course_id'] == entry['course_id'],
          orElse: () => {'course_name': 'Unknown Course'},
        );
        final slot = slotsResponse.firstWhere(
              (s) => s['time_slot_id'] == entry['time_slot_id'],
          orElse: () => {'day': 'Unknown', 'start_time': '', 'end_time': ''},
        );
        final classroom = classroomsResponse.firstWhere(
              (c) => c['classroom_id'] == entry['classroom_id'],
          orElse: () => {'building': 'Unknown', 'room_number': ''},
        );
        return {
          'timetable_id': entry['timetable_id'],
          'course_id': entry['course_id'],
          'course': course['course_name'],
          'day': slot['day'],
          'time': '${slot['start_time']} - ${slot['end_time']}',
          'time_slot_id': slot['time_slot_id'],
          'classroom': '${classroom['building']} - ${classroom['room_number']}',
          'classroom_id': classroom['classroom_id'],
          'semester_id': semesterId,
        };
      }).toList();

      setState(() {
        _timetable = timetableWithDetails;
        _selectedSemesterId = semesterId;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching timetable: $e'), backgroundColor: Colors.red.shade700),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkOneCoursePerDay(int semesterId, int timeSlotId, int courseId) async {
    try {
      // Get the day and time for the selected time slot
      final timeSlot = await _supabase
          .from('time_slot')
          .select('day, start_time, end_time')
          .eq('time_slot_id', timeSlotId)
          .single();

      final day = timeSlot['day'];
      final startTime = timeSlot['start_time'];
      final endTime = timeSlot['end_time'];

      // Get all timetable entries for this semester and course
      final existingTimetable = await _supabase
          .from('timetable')
          .select('time_slot_id')
          .eq('semester_id', semesterId)
          .eq('course_id', courseId);

      // If there are no existing entries for this course, no conflict
      if (existingTimetable.isEmpty) return false;

      // Get all time slots for the existing entries
      final timeSlotIds = existingTimetable.map((t) => t['time_slot_id']).toList();

      // Get all time slots on the same day
      final slotsOnSameDay = await _supabase
          .from('time_slot')
          .select('start_time, end_time')
          .eq('day', day)
          .inFilter('time_slot_id', timeSlotIds);

      // Check for time overlap with existing slots
      for (var slot in slotsOnSameDay) {
        final existingStart = slot['start_time'];
        final existingEnd = slot['end_time'];

        // Check if the new time slot overlaps with any existing slot
        if ((startTime >= existingStart && startTime < existingEnd) ||
            (endTime > existingStart && endTime <= existingEnd) ||
            (startTime <= existingStart && endTime >= existingEnd)) {
          return true; // Conflict found
        }
      }

      return false; // No conflict found
    } catch (e) {
      print('Error checking one course per day: $e');
      return false;
    }
  }

  Future<bool> _checkClassroomConflict(int timeSlotId, String classroomId) async {
    try {
      // Get the day and time for the selected time slot
      final timeSlot = await _supabase
          .from('time_slot')
          .select('day, start_time, end_time')
          .eq('time_slot_id', timeSlotId)
          .single();

      final day = timeSlot['day'];
      final startTime = timeSlot['start_time'];
      final endTime = timeSlot['end_time'];

      // Get all timetable entries for this classroom
      final classroomBookings = await _supabase
          .from('timetable')
          .select('time_slot_id')
          .eq('classroom_id', classroomId);

      if (classroomBookings.isEmpty) return false;

      // Get all time slots for the classroom bookings
      final timeSlotIds = classroomBookings.map((t) => t['time_slot_id']).toList();

      // Get all time slots on the same day
      final slotsOnSameDay = await _supabase
          .from('time_slot')
          .select('start_time, end_time')
          .eq('day', day)
          .inFilter('time_slot_id', timeSlotIds);

      // Check for time overlap with existing slots
      for (var slot in slotsOnSameDay) {
        final existingStart = slot['start_time'];
        final existingEnd = slot['end_time'];

        // Check if the new time slot overlaps with any existing slot
        if ((startTime >= existingStart && startTime < existingEnd) ||
            (endTime > existingStart && endTime <= existingEnd) ||
            (startTime <= existingStart && endTime >= existingEnd)) {
          return true; // Conflict found
        }
      }

      return false; // No conflict found
    } catch (e) {
      print('Error checking classroom conflict: $e');
      return false;
    }
  }

  Future<bool> _checkCourseConflict(int courseId, int timeSlotId, int semesterId) async {
    try {
      // Check if this course is already scheduled in this time slot
      final response = await _supabase
          .from('timetable')
          .select()
          .eq('course_id', courseId)
          .eq('time_slot_id', timeSlotId)
          .eq('semester_id', semesterId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('Error checking course conflict: $e');
      return false;
    }
  }

  Future<bool> _checkInstructorConflict(int instructorId, int timeSlotId, int semesterId) async {
    try {
      // Get all courses taught by this instructor in this semester
      final teaches = await _supabase
          .from('teaches')
          .select('course_id')
          .eq('instructor_id', instructorId)
          .eq('semester_id', semesterId);

      if (teaches.isEmpty) return false;

      // Get all course IDs taught by this instructor
      final courseIds = teaches.map((t) => t['course_id']).toList();

      // Check if any of these courses are scheduled in this time slot
      final response = await _supabase
          .from('timetable')
          .select()
          .eq('time_slot_id', timeSlotId)
          .eq('semester_id', semesterId)
          .inFilter('course_id', courseIds)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking instructor conflict: $e');
      return false;
    }
  }

  Future<void> _generateLectureTimetableAvoidingConflicts(
      int targetSemesterId,
      String targetClassroomId,
      List<int> selectedElectiveCourseIds,
      ) async {
    setState(() => _isGenerating = true);

    try {
      // Clear existing timetable for this semester
      await _supabase.from('timetable').delete().eq('semester_id', targetSemesterId);

      // Fetch all necessary data
      final [allCourses, teaches, timeSlots] = await Future.wait([
        _supabase.from('course').select().eq('semester_id', targetSemesterId),
        _supabase.from('teaches').select().eq('semester_id', targetSemesterId),
        _supabase.from('time_slot').select(),
      ]);

      // Filter courses based on type and lecture count
      final courses = allCourses.where((course) {
        final isCore = course['category_id'] == 1;
        final isElective = course['category_id'] == 2;
        final hasLectures = course['l'] > 0;
        return hasLectures && (isCore || (isElective && selectedElectiveCourseIds.contains(course['course_id'])));
      }).toList();

      // Group time slots by day
      final slotsByDay = <String, List<Map<String, dynamic>>>{};
      for (var slot in timeSlots) {
        final day = slot['day'] as String;
        slotsByDay[day] = slotsByDay[day] ?? [];
        slotsByDay[day]!.add(slot);
      }

      // Track assigned slots and unassigned courses
      final assignedCourseSlots = <int, int>{};
      final unassignedCourses = <String, int>{};

      // Sort courses by lecture count (descending) to prioritize courses with more lectures
      courses.sort((a, b) => (b['l'] as int).compareTo(a['l'] as int));

      for (final course in courses) {
        final courseId = course['course_id'];
        final lectureCount = course['l'] as int;

        if (lectureCount == 0) continue;

        final instructorEntry = teaches.firstWhere(
              (entry) => entry['course_id'] == courseId,
          orElse: () => {},
        );

        if (instructorEntry.isEmpty) {
          unassignedCourses[course['course_name']] = lectureCount;
          continue;
        }

        final instructorId = instructorEntry['instructor_id'];
        int slotsAssigned = 0;

        // Try to assign lectures on different days
        final days = slotsByDay.keys.toList()..shuffle(_random);

        for (final day in days) {
          if (slotsAssigned >= lectureCount) break;

          // Check if course already has a lecture on this day
          final dayConflict = await _checkOneCoursePerDay(targetSemesterId, slotsByDay[day]!.first['time_slot_id'], courseId);
          if (dayConflict) continue;

          // Try to assign consecutive slots if possible
          final daySlots = List<Map<String, dynamic>>.from(slotsByDay[day]!);
          daySlots.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));

          for (final slot in daySlots) {
            if (slotsAssigned >= lectureCount) break;

            final timeSlotId = slot['time_slot_id'];

            // Check all conflicts
            final classroomConflict = await _checkClassroomConflict(timeSlotId, targetClassroomId);
            if (classroomConflict) continue;

            final courseConflict = await _checkCourseConflict(courseId, timeSlotId, targetSemesterId);
            if (courseConflict) continue;

            final instructorConflict = await _checkInstructorConflict(instructorId, timeSlotId, targetSemesterId);
            if (instructorConflict) continue;

            try {
              await _supabase.from('timetable').insert({
                'course_id': courseId,
                'semester_id': targetSemesterId,
                'time_slot_id': timeSlotId,
                'classroom_id': targetClassroomId,
              });
              slotsAssigned++;
              assignedCourseSlots[courseId] = (assignedCourseSlots[courseId] ?? 0) + 1;
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to assign course ${course['course_name']}: $e'),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            }
          }
        }

        if (slotsAssigned < lectureCount) {
          unassignedCourses[course['course_name']] = lectureCount - slotsAssigned;
        }
      }

      // Show summary of unassigned courses
      if (unassignedCourses.isNotEmpty) {
        final message = unassignedCourses.entries
            .map((e) => '${e.key}: ${e.value} slot${e.value > 1 ? 's' : ''} unassigned')
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Some courses could not be assigned: $message'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Refresh the timetable view
      await _fetchTimetable(targetSemesterId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating timetable: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _showAddTimetableForm() {
    int? selectedProgramId = _selectedProgramId;
    int? selectedSemesterId;
    String? selectedClassroomId;
    List<int> selectedElectiveCourseIds = [];
    int maxElectiveCourses = 0;

    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: ThemeData(
            primarySwatch: Colors.deepPurple,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.blue.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              labelStyle: TextStyle(color: Colors.deepPurple.shade700),
            ),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.white,
                title: Text(
                  'Generate Timetable',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          value: selectedProgramId,
                          decoration: InputDecoration(
                            labelText: 'Program',
                            prefixIcon: Icon(Icons.school, color: Colors.deepPurple.shade700),
                          ),
                          hint: const Text('Select a program'),
                          items: _programs.map((program) {
                            return DropdownMenuItem<int>(
                              value: program['program_id'],
                              child: Text(
                                '${program['program_name']} (${program['batch_year']})',
                                style: TextStyle(color: Colors.deepPurple.shade900),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setDialogState(() {
                              selectedProgramId = value;
                              selectedSemesterId = null;
                              selectedElectiveCourseIds.clear();
                              _courses.clear();
                            });
                            if (value != null) {
                              await _fetchSemesters(value);
                              setDialogState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: selectedSemesterId,
                          decoration: InputDecoration(
                            labelText: 'Semester',
                            prefixIcon: Icon(Icons.calendar_today, color: Colors.deepPurple.shade700),
                          ),
                          hint: const Text('Select a semester'),
                          items: _semesters.map((semester) {
                            return DropdownMenuItem<int>(
                              value: semester['semester_id'],
                              child: Text(
                                'Semester ${semester['semester_number']}',
                                style: TextStyle(color: Colors.deepPurple.shade900),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setDialogState(() {
                              selectedSemesterId = value;
                              selectedElectiveCourseIds.clear();
                              _courses.clear();
                            });
                            if (value != null) {
                              await _fetchCourses(value);
                              final semester = _semesters.firstWhere((s) => s['semester_id'] == value);
                              maxElectiveCourses = semester['elective_courses'] ?? 0;
                              setDialogState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedClassroomId,
                          decoration: InputDecoration(
                            labelText: 'Classroom',
                            prefixIcon: Icon(Icons.room, color: Colors.deepPurple.shade700),
                          ),
                          hint: const Text('Select a classroom'),
                          items: _classrooms.map((classroom) {
                            return DropdownMenuItem<String>(
                              value: classroom['classroom_id'],
                              child: Text(
                                '${classroom['building']} - ${classroom['room_number']}',
                                style: TextStyle(color: Colors.deepPurple.shade900),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedClassroomId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_courses.isNotEmpty) ...[
                          Text(
                            'Courses',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          const Divider(height: 16, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Core Courses (Auto-selected)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _courses.where((course) => course['category_id'] == 1).map((course) {
                              return Chip(
                                label: Text(
                                  '${course['course_name']} (${course['l']} lectures)',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.green.shade600,
                                elevation: 2,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select Elective Courses (Max $maxElectiveCourses)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _courses.where((course) => course['category_id'] == 2).map((course) {
                              final isSelected = selectedElectiveCourseIds.contains(course['course_id']);
                              return FilterChip(
                                label: Text(
                                  '${course['course_name']} (${course['l']} lectures)',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.blue.shade900,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      if (selectedElectiveCourseIds.length < maxElectiveCourses) {
                                        selectedElectiveCourseIds.add(course['course_id']);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Maximum elective courses ($maxElectiveCourses) reached.'),
                                            backgroundColor: Colors.red.shade700,
                                          ),
                                        );
                                      }
                                    } else {
                                      selectedElectiveCourseIds.remove(course['course_id']);
                                    }
                                  });
                                },
                                selectedColor: Colors.blue.shade600,
                                checkmarkColor: Colors.white,
                                backgroundColor: Colors.blue.shade100,
                                elevation: isSelected ? 4 : 1,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isGenerating
                        ? null
                        : () async {
                      if (selectedProgramId == null ||
                          selectedSemesterId == null ||
                          selectedClassroomId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Please complete all selections.'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => _isGenerating = true);
                      try {
                        await _generateLectureTimetableAvoidingConflicts(
                          selectedSemesterId!,
                          selectedClassroomId!,
                          selectedElectiveCourseIds,
                        );
                        Navigator.pop(context);
                        await _fetchTimetable(selectedSemesterId!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Timetable generated successfully!'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error generating timetable: $e'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      } finally {
                        setDialogState(() => _isGenerating = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isGenerating
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : const Text('Generate'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showAddCourseForm(int semesterId) async {
    setState(() => _isAddingCourse = true);
    try {
      await Future.wait([
        _fetchCourses(semesterId),
        _fetchTimeSlotsAndClassrooms(),
      ]);

      if (_courses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No courses available for this semester.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      int? selectedCourseId;
      int? selectedTimeSlotId;
      String? selectedClassroomId;

      showDialog(
        context: context,
        builder: (context) {
          return Theme(
            data: ThemeData(
              primarySwatch: Colors.deepPurple,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.blue.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                labelStyle: TextStyle(color: Colors.deepPurple.shade700),
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isLargeScreen = constraints.maxWidth > 600;
                    final padding = isLargeScreen ? 24.0 : 16.0;
                    final fontSize = isLargeScreen ? 16.0 : 14.0;
                    final buttonHeight = isLargeScreen ? 48.0 : 40.0;

                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.white,
                      contentPadding: EdgeInsets.all(padding),
                      content: SizedBox(
                        width: isLargeScreen ? 600 : double.infinity,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Course to Timetable',
                                style: TextStyle(
                                  color: Colors.deepPurple.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isLargeScreen ? 20 : 18,
                                ),
                              ),
                              SizedBox(height: padding),
                              if (isLargeScreen)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          DropdownButtonFormField<int>(
                                            value: selectedCourseId,
                                            decoration: InputDecoration(
                                              labelText: 'Course',
                                              prefixIcon: Icon(Icons.book, color: Colors.deepPurple.shade700),
                                              labelStyle: TextStyle(fontSize: fontSize),
                                            ),
                                            hint: Text('Select a course', style: TextStyle(fontSize: fontSize)),
                                            items: _courses.map((course) {
                                              return DropdownMenuItem<int>(
                                                value: course['course_id'],
                                                child: Text(
                                                  '${course['course_name']} (${course['l']} lectures)',
                                                  style: TextStyle(
                                                    fontSize: fontSize,
                                                    color: Colors.deepPurple.shade900,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setDialogState(() {
                                                selectedCourseId = value;
                                              });
                                            },
                                          ),
                                          SizedBox(height: padding),
                                          DropdownButtonFormField<int>(
                                            value: selectedTimeSlotId,
                                            decoration: InputDecoration(
                                              labelText: 'Time Slot',
                                              prefixIcon: Icon(Icons.schedule, color: Colors.deepPurple.shade700),
                                              labelStyle: TextStyle(fontSize: fontSize),
                                            ),
                                            hint: Text('Select a time slot', style: TextStyle(fontSize: fontSize)),
                                            items: _timeSlots.map((slot) {
                                              return DropdownMenuItem<int>(
                                                value: slot['time_slot_id'],
                                                child: Text(
                                                  '${slot['day']} ${slot['start_time']} - ${slot['end_time']}',
                                                  style: TextStyle(
                                                    fontSize: fontSize,
                                                    color: Colors.deepPurple.shade900,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setDialogState(() {
                                                selectedTimeSlotId = value;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: padding),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: selectedClassroomId,
                                        decoration: InputDecoration(
                                          labelText: 'Classroom',
                                          prefixIcon: Icon(Icons.room, color: Colors.deepPurple.shade700),
                                          labelStyle: TextStyle(fontSize: fontSize),
                                        ),
                                        hint: Text('Select a classroom', style: TextStyle(fontSize: fontSize)),
                                        items: _classrooms.map((classroom) {
                                          return DropdownMenuItem<String>(
                                            value: classroom['classroom_id'],
                                            child: Text(
                                              '${classroom['building']} - ${classroom['room_number']}',
                                              style: TextStyle(
                                                fontSize: fontSize,
                                                color: Colors.deepPurple.shade900,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setDialogState(() {
                                            selectedClassroomId = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    DropdownButtonFormField<int>(
                                      value: selectedCourseId,
                                      decoration: InputDecoration(
                                        labelText: 'Course',
                                        prefixIcon: Icon(Icons.book, color: Colors.deepPurple.shade700),
                                        labelStyle: TextStyle(fontSize: fontSize),
                                      ),
                                      hint: Text('Select a course', style: TextStyle(fontSize: fontSize)),
                                      items: _courses.map((course) {
                                        return DropdownMenuItem<int>(
                                          value: course['course_id'],
                                          child: Text(
                                            '${course['course_name']} (${course['l']} lectures)',
                                            style: TextStyle(
                                              fontSize: fontSize,
                                              color: Colors.deepPurple.shade900,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          selectedCourseId = value;
                                        });
                                      },
                                    ),
                                    SizedBox(height: padding),
                                    DropdownButtonFormField<int>(
                                      value: selectedTimeSlotId,
                                      decoration: InputDecoration(
                                        labelText: 'Time Slot',
                                        prefixIcon: Icon(Icons.schedule, color: Colors.deepPurple.shade700),
                                        labelStyle: TextStyle(fontSize: fontSize),
                                      ),
                                      hint: Text('Select a time slot', style: TextStyle(fontSize: fontSize)),
                                      items: _timeSlots.map((slot) {
                                        return DropdownMenuItem<int>(
                                          value: slot['time_slot_id'],
                                          child: Text(
                                            '${slot['day']} ${slot['start_time']} - ${slot['end_time']}',
                                            style: TextStyle(
                                              fontSize: fontSize,
                                              color: Colors.deepPurple.shade900,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          selectedTimeSlotId = value;
                                        });
                                      },
                                    ),
                                    SizedBox(height: padding),
                                    DropdownButtonFormField<String>(
                                      value: selectedClassroomId,
                                      decoration: InputDecoration(
                                        labelText: 'Classroom',
                                        prefixIcon: Icon(Icons.room, color: Colors.deepPurple.shade700),
                                        labelStyle: TextStyle(fontSize: fontSize),
                                      ),
                                      hint: Text('Select a classroom', style: TextStyle(fontSize: fontSize)),
                                      items: _classrooms.map((classroom) {
                                        return DropdownMenuItem<String>(
                                          value: classroom['classroom_id'],
                                          child: Text(
                                            '${classroom['building']} - ${classroom['room_number']}',
                                            style: TextStyle(
                                              fontSize: fontSize,
                                              color: Colors.deepPurple.shade900,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          selectedClassroomId = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: fontSize,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isAddingCourse
                              ? null
                              : () async {
                            if (selectedCourseId == null ||
                                selectedTimeSlotId == null ||
                                selectedClassroomId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Please complete all selections.'),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              return;
                            }

                            setDialogState(() => _isAddingCourse = true);

                            try {
                              // Check for instructor assignment
                              final instructorEntry = await _supabase
                                  .from('teaches')
                                  .select('instructor_id')
                                  .eq('course_id', selectedCourseId!)
                                  .eq('semester_id', semesterId)
                                  .maybeSingle();

                              if (instructorEntry == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('No instructor assigned for this course.'),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                                setDialogState(() => _isAddingCourse = false);
                                return;
                              }

                              // Check all conflicts
                              final conflicts = await Future.wait([
                                _checkClassroomConflict(selectedTimeSlotId!, selectedClassroomId!),
                                _checkCourseConflict(selectedCourseId!, selectedTimeSlotId!, semesterId),
                                _checkInstructorConflict(instructorEntry['instructor_id'], selectedTimeSlotId!, semesterId),
                                _checkOneCoursePerDay(semesterId, selectedTimeSlotId!, selectedCourseId!),
                              ]);

                              if (conflicts[0]) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Classroom is already booked for this time slot.'),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                                setDialogState(() => _isAddingCourse = false);
                                return;
                              }

                              if (conflicts[1]) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Course is already scheduled in this time slot.'),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                                setDialogState(() => _isAddingCourse = false);
                                return;
                              }

                              if (conflicts[2]) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Instructor is already scheduled in this time slot.'),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                                setDialogState(() => _isAddingCourse = false);
                                return;
                              }

                              if (conflicts[3]) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('This course already has a lecture scheduled on this day.'),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                                setDialogState(() => _isAddingCourse = false);
                                return;
                              }

                              // Add the course to timetable
                              await _supabase.from('timetable').insert({
                                'course_id': selectedCourseId,
                                'semester_id': semesterId,
                                'time_slot_id': selectedTimeSlotId,
                                'classroom_id': selectedClassroomId,
                              });

                              Navigator.pop(context);
                              await _fetchTimetable(semesterId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Course added successfully!'),
                                  backgroundColor: Colors.green.shade700,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding course: $e'),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            } finally {
                              setDialogState(() => _isAddingCourse = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            minimumSize: Size(isLargeScreen ? 120 : 100, buttonHeight),
                          ),
                          child: _isAddingCourse
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                              : Text('Add', style: TextStyle(fontSize: fontSize)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading add course form: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      setState(() => _isAddingCourse = false);
    }
  }

  Future<void> _deleteTimetableEntry(int timetableId, int semesterId) async {
    try {
      await _supabase.from('timetable').delete().eq('timetable_id', timetableId);
      await _fetchTimetable(semesterId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Timetable entry deleted successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting entry: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _deleteEntireTimetable(int semesterId) async {
    try {
      await _supabase.from('timetable').delete().eq('semester_id', semesterId);
      setState(() {
        _timetable.clear();
        _selectedSemesterId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Timetable deleted successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting timetable: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _editTimetableEntry(int timetableId, int newTimeSlotId, String newClassroomId, int semesterId) async {
    try {
      await _supabase
          .from('timetable')
          .update({'time_slot_id': newTimeSlotId, 'classroom_id': newClassroomId})
          .eq('timetable_id', timetableId);
      await _fetchTimetable(semesterId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Timetable entry updated successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating timetable: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic> entry) {
    int? selectedTimeSlotId = entry['time_slot_id'];
    String? selectedClassroomId = entry['classroom_id'];
    final semesterId = entry['semester_id'];

    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: ThemeData(primarySwatch: Colors.deepPurple),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Edit Timetable Entry: ${entry['course']}',
              style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedTimeSlotId,
                  decoration: InputDecoration(
                    labelText: 'Time Slot',
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _timeSlots.map((slot) {
                    return DropdownMenuItem<int>(
                      value: slot['time_slot_id'],
                      child: Text(
                        '${slot['day']} ${slot['start_time']} - ${slot['end_time']}',
                        style: TextStyle(color: Colors.deepPurple.shade900),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => selectedTimeSlotId = value,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedClassroomId,
                  decoration: InputDecoration(
                    labelText: 'Classroom',
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _classrooms.map((classroom) {
                    return DropdownMenuItem<String>(
                      value: classroom['classroom_id'],
                      child: Text(
                        '${classroom['building']} - ${classroom['room_number']}',
                        style: TextStyle(color: Colors.deepPurple.shade900),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => selectedClassroomId = value,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedTimeSlotId == null || selectedClassroomId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please select both time slot and classroom.'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                    return;
                  }
                  _editTimetableEntry(
                      entry['timetable_id'], selectedTimeSlotId!, selectedClassroomId!, semesterId);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteEntryDialog(int timetableId, int semesterId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Timetable Entry',
            style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to delete this timetable entry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteTimetableEntry(timetableId, semesterId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteTimetableDialog(int semesterId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Entire Timetable',
            style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to delete the entire timetable for this semester?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteEntireTimetable(semesterId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportTimetableToPDF() async {
    if (_timetable.isEmpty || _semesters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No timetable data available to export.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Timetable for Semester ${_semesters.firstWhere((s) => s['semester_id'] == _timetable.first['semester_id'], orElse: () => {'semester_number': 'Unknown'})['semester_number']}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Course',
                            style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Day',
                            style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Time',
                            style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Classroom',
                            style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    for (var entry in _timetable)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(entry['course'], style: pw.TextStyle(font: font)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(entry['day'], style: pw.TextStyle(font: font)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(entry['time'], style: pw.TextStyle(font: font)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(entry['classroom'], style: pw.TextStyle(font: font)),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final filename = 'timetable_semester_${_timetable.first['semester_id']}.pdf';

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );
      } else {
        throw UnsupportedError('PDF sharing not supported on this platform.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF exported successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showProgramAndSemesterSelection() {
    int? selectedProgramId = _selectedProgramId;
    int? selectedSemesterId;

    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: ThemeData(primarySwatch: Colors.deepPurple),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  'Select Program and Semester',
                  style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedProgramId,
                      decoration: InputDecoration(
                        labelText: 'Program',
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      hint: const Text('Select a program'),
                      items: _programs.map((program) {
                        return DropdownMenuItem<int>(
                          value: program['program_id'],
                          child: Text(
                            '${program['program_name']} (${program['batch_year']})',
                            style: TextStyle(color: Colors.deepPurple.shade900),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        setDialogState(() {
                          selectedProgramId = value;
                          selectedSemesterId = null;
                          _semesters.clear();
                        });
                        if (value != null) {
                          await _fetchSemesters(value);
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedSemesterId,
                      decoration: InputDecoration(
                        labelText: 'Semester',
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      hint: const Text('Select a semester'),
                      items: _semesters.map((semester) {
                        return DropdownMenuItem<int>(
                          value: semester['semester_id'],
                          child: Text(
                            'Semester ${semester['semester_number']}',
                            style: TextStyle(color: Colors.deepPurple.shade900),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSemesterId = value;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedProgramId == null || selectedSemesterId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Please select both program and semester.'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _selectedProgramId = selectedProgramId;
                        _selectedSemesterId = selectedSemesterId;
                      });
                      Navigator.pop(context);
                      await _fetchTimetable(selectedSemesterId!);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('View Timetable'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Timetable Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedProgramId == null
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Programs',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _programs.length,
                itemBuilder: (context, index) {
                  final program = _programs[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        '${program['program_name']} (${program['batch_year']})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedProgramId = program['program_id'];
                                _semesters.clear();
                                _timetable.clear();
                              });
                              _fetchSemesters(program['program_id']).then((_) {
                                _showProgramAndSemesterSelection();
                              });
                            },
                            icon: const Icon(Icons.visibility, size: 20),
                            label: const Text('View'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              setState(() {
                                _selectedProgramId = program['program_id'];
                              });
                              await _fetchTimeSlotsAndClassrooms();
                              await _fetchSemesters(program['program_id']);
                              _showAddTimetableForm();
                            },
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )
          : _selectedSemesterId == null
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Semester',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 16),
            if (_semesters.isEmpty)
              const Center(
                child: Text(
                  'No semesters found for this program.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            else
              DropdownButtonFormField<int>(
                value: _selectedSemesterId,
                decoration: InputDecoration(
                  labelText: 'Semester',
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                hint: const Text('Select a semester'),
                items: _semesters.map((semester) {
                  return DropdownMenuItem<int>(
                    value: semester['semester_id'],
                    child: Text(
                      'Semester ${semester['semester_number']}',
                      style: TextStyle(color: Colors.deepPurple.shade900),
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value != null) {
                    setState(() {
                      _selectedSemesterId = value;
                    });
                    await _fetchTimetable(value);
                  }
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedProgramId = null;
                  _semesters.clear();
                  _timetable.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Back to Programs'),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timetable for Semester ${_semesters.firstWhere((s) => s['semester_id'] == _selectedSemesterId, orElse: () => {'semester_number': 'Unknown'})['semester_number']}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final buttonWidth = constraints.maxWidth > 600
                    ? 200.0
                    : (constraints.maxWidth - 32) / 2;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddCourseForm(_selectedSemesterId!),
                            icon: const Icon(Icons.add_circle, size: 20),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton.icon(
                            onPressed: () => _showDeleteTimetableDialog(_selectedSemesterId!),
                            icon: const Icon(Icons.delete_forever, size: 20),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton.icon(
                            onPressed: _exportTimetableToPDF,
                            icon: const Icon(Icons.picture_as_pdf, size: 20),
                            label: const Text('Export'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedProgramId = null;
                                _selectedSemesterId = null;
                                _timetable.clear();
                                _semesters.clear();
                                _courses.clear();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                            child: const Text('Back to Programs'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _timetable.isEmpty
                  ? const Center(
                child: Text(
                  'No timetable entries found for this semester.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: WidgetStateProperty.all(Colors.deepPurple.shade50),
                      dataRowColor: WidgetStateProperty.resolveWith(
                              (states) =>
                          states.contains(WidgetState.hovered)
                              ? Colors.blue.shade50
                              : Colors.white),
                      columns: const [
                        DataColumn(
                          label: Text('Course', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Classroom', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                      rows: _timetable.map((entry) {
                        return DataRow(
                          cells: [
                            DataCell(Text(entry['course'], style: const TextStyle(fontSize: 14))),
                            DataCell(Text(entry['day'], style: const TextStyle(fontSize: 14))),
                            DataCell(Text(entry['time'], style: const TextStyle(fontSize: 14))),
                            DataCell(
                                Text(entry['classroom'], style: const TextStyle(fontSize: 14))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(entry),
                                    tooltip: 'Edit Entry',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteEntryDialog(
                                        entry['timetable_id'], entry['semester_id']),
                                    tooltip: 'Delete Entry',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}