import 'package:flutter/material.dart';
import '../../Data/instructor_data.dart';

class CourseDropdown extends StatelessWidget {
  final String? selectedCourse;
  final Function(String?) onChanged;

  const CourseDropdown({
    super.key,
    required this.selectedCourse,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Select Course:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: selectedCourse,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Choose a course'),
              ),
              isExpanded: true,
              underline: const SizedBox(),
              items: instructorCourses.map((course) {
                return DropdownMenuItem<String>(
                  value: course['course'],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(course['course']),
                  ),
                );
              }).toList(),
              onChanged: (value) => onChanged(value),
            ),
          ),
        ),
      ],
    );
  }
}