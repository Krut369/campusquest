import 'package:campusquest/modules/admin/views/instructor_screen.dart';
import 'package:campusquest/modules/student/views/StudentDashboard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/login_controller.dart';
import '../modules/admin/views/AdminDashboard.dart';
import '../modules/admin/views/EventsPage.dart';
import '../modules/admin/views/TimetablePage.dart';
import '../modules/instructor/views/AttendancePage.dart';
import '../modules/instructor/views/ClassSchedule.dart';
import '../modules/instructor/views/InstructorDashboard.dart';
import '../modules/instructor/views/createassignmentpage.dart';
import '../modules/student/views/AssignmentsPage.dart';
import '../modules/student/views/NotesPage.dart';
import '../modules/student/views/ProfilePage.dart';
import '../modules/student/views/TimetablePage.dart';

class BottomBar extends StatefulWidget {
  const BottomBar({Key? key}) : super(key: key);

  @override
  _BottomBarState createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final loginController = Provider.of<LoginController>(context);
    final userRole = loginController.role ?? 'student';

    final roleBasedPages = _getRoleBasedPages(userRole);
    final roleBasedNavItems = _getRoleBasedNavItems(userRole);

    final theme = Theme.of(context); // Access the current theme

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: roleBasedPages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: theme.bottomAppBarColor,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.unselectedWidgetColor,
        currentIndex: _currentIndex,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: roleBasedNavItems,
      ),
    );
  }

  List<Widget> _getRoleBasedPages(String role) {
    switch (role) {
      case 'admin':
        return [
          const AdminDashboard(),
          const AddInstructorPage(),
          const AddEventPage(),
          const TimetablePageAdmin()
        ];
      case 'instructor':
        return [
          const InstructorDashboard(),
          const ClassSchedule(),
          const UploadAssignmentsPage(),
          const AttendancePage()
        ];
      case 'student':
      default:
        return [
          StudentDashboard(),
          TimetablePage(),
          AssignmentsPage(),
          const NotesPage(),
          ProfilePage()
        ];
    }
  }

  List<BottomNavigationBarItem> _getRoleBasedNavItems(String role) {
    switch (role) {
      case 'admin':
        return [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Instructor'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.timelapse), label: 'Time Table'),
        ];
      case 'instructor':
        return [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Assignments'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Attendance'),
        ];
      case 'student':
      default:
        return [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Timetable'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Assignments'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
    }
  }
}

extension on ThemeData {
  get bottomAppBarColor => null;
}
