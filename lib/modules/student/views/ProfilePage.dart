import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campusquest/controllers/login_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:campusquest/modules/login/views/login.dart'; // Import LoginPage

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isEditing = false;
  File? _profileImage;
  XFile? _pickedXFile;
  String? _profileImageUrl;
  Map<String, dynamic> _studentData = {};
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<Map<String, dynamic>> _availableElectives = [];
  int? _currentSemesterId;
  int _maxCourses = 0;
  int _coreCourses = 0;
  int _electiveCourses = 0;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchStudentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentProfile() async {
    setState(() => _isLoading = true);

    try {
      final loginController = Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;

      if (studentId == null) {
        throw Exception('Student ID is null.');
      }

      // Fetch student data
      final studentResponse = await _supabase
          .from('student')
          .select('*, department:dept_name(*), program:program_id(*), users:user_id(*)')
          .eq('student_id', studentId)
          .single();

      // Fetch current semester details
      final semesterResponse = await _supabase
          .from('semester')
          .select()
          .eq('program_id', studentResponse['program_id'])
          .eq('semester_number', studentResponse['current_semester'])
          .single();

      // Fetch enrolled courses with category details
      final enrollmentResponse = await _supabase
          .from('enrollment')
          .select('*, course:course_id(course_name, l, t, p, c, category:coursecategories(category_name))')
          .eq('student_id', studentId)
          .eq('semester_id', semesterResponse['semester_id']);

      // Fetch available elective courses
      final electiveResponse = await _supabase
          .from('course')
          .select('*, category:coursecategories(category_name)')
          .eq('semester_id', semesterResponse['semester_id'])
          .eq('category.category_name', 'Elective');

      setState(() {
        _studentData = studentResponse;
        _profileImageUrl = _studentData['profile_picture_path'];
        _currentSemesterId = semesterResponse['semester_id'];
        _maxCourses = semesterResponse['max_courses'];
        _coreCourses = semesterResponse['core_courses'];
        _electiveCourses = semesterResponse['elective_courses'];
        _enrolledCourses = List<Map<String, dynamic>>.from(enrollmentResponse);
        _availableElectives = List<Map<String, dynamic>>.from(electiveResponse)
            .where((course) => !_enrolledCourses.any((enrolled) => enrolled['course_id'] == course['course_id']))
            .toList();

        // Initialize form controllers
        _nameController.text = _studentData['name'] ?? '';
        _addressController.text = _studentData['address'] ?? '';
        _cityController.text = _studentData['city'] ?? '';
        _stateController.text = _studentData['state'] ?? '';
        _countryController.text = _studentData['country'] ?? '';
        _postalCodeController.text = _studentData['postal_code'] ?? '';
        _selectedGender = _studentData['gender'];

        if (_studentData['date_of_birth'] != null) {
          _selectedDate = DateTime.parse(_studentData['date_of_birth']);
          _dobController.text = DateFormat('MMM dd, yyyy').format(_selectedDate!);
        }

        _isLoading = false;
      });
    } catch (e) {
      print(e);
      _showErrorMessage('Error fetching profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = kIsWeb ? null : File(pickedFile.path);
          _pickedXFile = pickedFile;
        });
      }
    } catch (e) {
      _showErrorMessage('Error picking image: $e');
    }
  }

  Future<String?> _uploadProfileImage(dynamic studentId) async {
    try {
      final String studentIdStr = studentId.toString();
      final filename = '${DateTime.now().millisecondsSinceEpoch}_profile_image';
      final filePath = 'profiles/$studentIdStr/$filename';

      if (kIsWeb && _pickedXFile != null) {
        final bytes = await _pickedXFile!.readAsBytes();
        await _supabase.storage.from('profilepictures').uploadBinary(filePath, bytes);
      } else if (_profileImage != null) {
        await _supabase.storage.from('profilepictures').upload(filePath, _profileImage!);
      } else {
        return _profileImageUrl;
      }

      return _supabase.storage.from('profilepictures').getPublicUrl(filePath);
    } catch (e) {
      _showErrorMessage('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.deepPurple,
            colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MMM dd, yyyy').format(_selectedDate!);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final loginController = Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;

      if (studentId == null) {
        throw Exception('Student ID is null.');
      }

      String? profilePicturePath = _studentData['profile_picture_path'];
      if (_profileImage != null || _pickedXFile != null) {
        profilePicturePath = await _uploadProfileImage(studentId);
      }

      await _supabase.from('student').update({
        'name': _nameController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'country': _countryController.text,
        'postal_code': _postalCodeController.text,
        'gender': _selectedGender,
        'date_of_birth': _selectedDate?.toIso8601String(),
        'profile_picture_path': profilePicturePath,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('student_id', studentId);

      _showSuccessMessage('Profile updated successfully');
      setState(() {
        _isEditing = false;
        _profileImage = null;
        _pickedXFile = null;
      });
      await _fetchStudentProfile();
    } catch (e) {
      _showErrorMessage('Error updating profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enrollInElective(int courseId) async {
    final loginController = Provider.of<LoginController>(context, listen: false);
    final studentId = loginController.studentId;

    if (_enrolledCourses.length >= _maxCourses) {
      _showErrorMessage('Maximum course limit reached ($_maxCourses courses).');
      return;
    }

    final currentElectives = _enrolledCourses.where((course) => course['course']['category']['category_name'] == 'Elective').length;
    if (currentElectives >= _electiveCourses) {
      _showErrorMessage('Maximum elective course limit reached ($_electiveCourses electives).');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.from('enrollment').insert({
        'student_id': studentId,
        'course_id': courseId,
        'semester_id': _currentSemesterId,
        'enrollment_status': 'Active',
      });

      _showSuccessMessage('Successfully enrolled in elective course.');
      await _fetchStudentProfile(); // Refresh enrolled courses
    } catch (e) {
      _showErrorMessage('Error enrolling in course: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      final loginController = Provider.of<LoginController>(context, listen: false);
      print('Current session before logout: ${Supabase.instance.client.auth.currentSession}');
      await loginController.logout();
      if (!mounted) return;
      _showSuccessMessage('Logged out successfully');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e, stackTrace) {
      print('Logout error: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      _showErrorMessage('Failed to log out: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text(message),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildReadOnlyProfile() {
    final dateOfBirth = _studentData['date_of_birth'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(_studentData['date_of_birth']))
        : 'Not Available';

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.deepPurple.shade100,
          backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
          child: _profileImageUrl == null ? const Icon(Icons.person, size: 60, color: Colors.deepPurple) : null,
        ),
        const SizedBox(height: 16),
        Text(_studentData['name'] ?? 'Student', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        Text(_studentData['roll_number'] ?? 'Roll Number Not Available', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
        const SizedBox(height: 24),

        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Basic Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Divider(),
                _infoRow('Date of Birth', dateOfBirth),
                _infoRow('Gender', _studentData['gender'] ?? 'Not Specified'),
                _infoRow('Email', _studentData['users']?['email'] ?? 'Not Available'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Academic Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Divider(),
                _infoRow('Department', _studentData['department']?['dept_name'] ?? 'Not Assigned'),
                _infoRow('Program', _studentData['program']?['program_name'] ?? 'Not Available'),
                _infoRow('Current Semester', _studentData['current_semester']?.toString() ?? 'Not Available'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Divider(),
                _infoRow('Address', _studentData['address'] ?? 'Not Available'),
                _infoRow('City', _studentData['city'] ?? 'Not Available'),
                _infoRow('State', _studentData['state'] ?? 'Not Available'),
                _infoRow('Country', _studentData['country'] ?? 'Not Available'),
                _infoRow('Postal Code', _studentData['postal_code'] ?? 'Not Available'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Enrolled Courses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _showElectiveSelectionDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Elective'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                if (_enrolledCourses.isEmpty)
                  const Text('No courses enrolled yet.', style: TextStyle(color: Colors.grey))
                else
                  ..._enrolledCourses.map((course) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          course['course']['category']['category_name'] == 'Core' ? Icons.book : Icons.bookmark,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course['course']['course_name'],
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'L:${course['course']['l']} T:${course['course']['t']} P:${course['course']['p']} C:${course['course']['c']}',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(course['enrollment_status']),
                          backgroundColor: course['enrollment_status'] == 'Active'
                              ? Colors.green.shade100
                              : course['enrollment_status'] == 'Completed'
                              ? Colors.blue.shade100
                              : Colors.red.shade100,
                        ),
                      ],
                    ),
                  )),
                const SizedBox(height: 8),
                Text(
                  'Course Limits: Total ${_enrolledCourses.length}/$_maxCourses | Electives ${_enrolledCourses.where((c) => c['course']['category']['category_name'] == 'Elective').length}/$_electiveCourses',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showElectiveSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Elective Course', style: TextStyle(color: Colors.deepPurple)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: _availableElectives.isEmpty
            ? const Text('No elective courses available for this semester.', style: TextStyle(color: Colors.grey))
            : SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: _availableElectives.map((course) => Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  title: Text(
                    course['course_name'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'L:${course['l']} T:${course['t']} P:${course['p']} C:${course['c']}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                    onPressed: _isLoading
                        ? null
                        : () {
                      _enrollInElective(course['course_id']);
                      Navigator.pop(context);
                    },
                  ),
                ),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableProfile() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.deepPurple.shade100,
                backgroundImage: _profileImage != null
                    ? kIsWeb
                    ? null
                    : FileImage(_profileImage!) as ImageProvider
                    : _pickedXFile != null && kIsWeb
                    ? NetworkImage(_pickedXFile!.path)
                    : _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: (_profileImage == null && _pickedXFile == null && _profileImageUrl == null)
                    ? const Icon(Icons.person, size: 60, color: Colors.deepPurple)
                    : null,
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepPurple,
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  onPressed: _pickImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const Divider(),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person, color: Colors.deepPurple)),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.people, color: Colors.deepPurple)),
                    items: ['Male', 'Female', 'Other', 'Prefer not to say']
                        .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedGender = value),
                    validator: (value) => value == null || value.isEmpty ? 'Please select your gender' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month, color: Colors.deepPurple),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    onTap: () => _selectDate(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const Divider(),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.home, color: Colors.deepPurple)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city, color: Colors.deepPurple)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(labelText: 'State/Province', prefixIcon: Icon(Icons.map, color: Colors.deepPurple)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.flag, color: Colors.deepPurple)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(labelText: 'Postal Code', prefixIcon: Icon(Icons.markunread_mailbox, color: Colors.deepPurple)),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _nameController.text = _studentData['name'] ?? '';
                    _addressController.text = _studentData['address'] ?? '';
                    _cityController.text = _studentData['city'] ?? '';
                    _stateController.text = _studentData['state'] ?? '';
                    _countryController.text = _studentData['country'] ?? '';
                    _postalCodeController.text = _studentData['postal_code'] ?? '';
                    _selectedGender = _studentData['gender'];
                    if (_studentData['date_of_birth'] != null) {
                      _selectedDate = DateTime.parse(_studentData['date_of_birth']);
                      _dobController.text = DateFormat('MMM dd, yyyy').format(_selectedDate!);
                    } else {
                      _selectedDate = null;
                      _dobController.text = '';
                    }
                    _profileImage = null;
                    _pickedXFile = null;
                  });
                },
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateProfile,
                icon: _isLoading
                    ? Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(2.0),
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  disabledBackgroundColor: Colors.deepPurple.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.deepPurple)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _isEditing ? _buildEditableProfile() : _buildReadOnlyProfile(),
        ),
      ),
    );
  }
}