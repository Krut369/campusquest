import 'package:flutter/material.dart';

class StudentAttendanceList extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final String formattedDate;
  final Function(int, String) onStatusChanged; // Callback to notify parent

  const StudentAttendanceList({
    super.key,
    required this.students,
    required this.formattedDate,
    required this.onStatusChanged,
  });

  @override
  State<StudentAttendanceList> createState() => _StudentAttendanceListState();
}

class _StudentAttendanceListState extends State<StudentAttendanceList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.students.length,
      itemBuilder: (context, index) {
        final student = widget.students[index];

        // Ensure attendance is initialized
        student['attendance'] ??= [];

        // Get the attendance status for the selected date
        final attendanceRecord = student['attendance']
            ?.firstWhere(
              (record) => record['date'] == widget.formattedDate,
          orElse: () => {'date': widget.formattedDate, 'status': 'Absent'},
        );

        // Ensure attendanceRecord has a 'status' key
        attendanceRecord['status'] ??= 'Absent';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Unknown Student',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ToggleButtons(
                  borderRadius: BorderRadius.circular(8),
                  isSelected: [
                    attendanceRecord['status'] == 'Present',
                    attendanceRecord['status'] == 'Absent',
                  ],
                  onPressed: (int newIndex) {
                    final newStatus = newIndex == 0 ? 'Present' : 'Absent';
                    setState(() {
                      attendanceRecord['status'] = newStatus;
                    });
                    // Notify the parent widget of the change
                    widget.onStatusChanged(index, newStatus);
                  },
                  fillColor: Colors.deepPurple,
                  selectedColor: Colors.white,
                  disabledColor: Colors.grey.shade300,
                  borderColor: Colors.grey.shade300,
                  borderWidth: 1,
                  renderBorder: true,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Present'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Absent'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}