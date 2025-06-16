import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class Course {
  final String courseId;
  final String courseName;
  Course({required this.courseId, required this.courseName});
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['course_id'].toString(),
      courseName: json['course_name'] ?? 'Unnamed Course',
    );
  }
}

class UploadMaterialsPage extends StatefulWidget {
  const UploadMaterialsPage({Key? key}) : super(key: key);

  @override
  _UploadMaterialsPageState createState() => _UploadMaterialsPageState();
}

class _UploadMaterialsPageState extends State<UploadMaterialsPage> with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _uploadDateController = TextEditingController();

  // State variables
  List<Course> courses = [];
  Map<String, List<Map<String, dynamic>>> courseNotes = {};
  List<String> selectedCourseIds = [];
  String? selectedCourseId; // Track the currently selected course
  bool _isLoading = false;
  bool _isEditing = false;
  int? _currentEditId;
  bool _isSaving = false;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  // Instructor information
  int? _instructorId;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fabAnimation;

  // File variables
  PlatformFile? _pickedFile;
  String? _uploadedFileUrl;
  String? _uploadedFileName;

  // Constants
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  final List<String> _allowedExtensions = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xlsx', 'txt'];

  // Supabase client
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _uploadDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeData();
    Future.delayed(const Duration(milliseconds: 500), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _uploadDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await _loadInstructorData();
      if (_instructorId != null) {
        await Future.wait([
          _fetchCourses(),
          _fetchNotes(),
        ]);
        if (courses.isNotEmpty) {
          setState(() => selectedCourseId = courses.first.courseId); // Default to first course
        }
      }
    } catch (e) {
      print(e);
      _showErrorMessage('Error initializing data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInstructorData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    final savedInstructorId = prefs.getInt('instructorId');
    if (savedInstructorId != null) {
      setState(() {
        _instructorId = savedInstructorId;
        _isLoading = false;
      });
      return;
    }

    if (userId != null) {
      try {
        final parsedUserId = int.tryParse(userId);
        if (parsedUserId == null) throw Exception('Invalid user ID format');

        final instructorData = await supabase
            .from('instructor')
            .select('instructor_id')
            .eq('user_id', parsedUserId)
            .maybeSingle();

        if (instructorData != null) {
          final id = instructorData['instructor_id'] as int;
          await prefs.setInt('instructorId', id);
          setState(() => _instructorId = id);
        } else {
          _showErrorMessage('No instructor profile found');
        }
      } catch (e) {
        _showErrorMessage('Error fetching instructor data: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      _showErrorMessage('No user ID found');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCourses() async {
    if (_instructorId == null) return;
    try {
      final response = await supabase
          .from('teaches')
          .select('course:course_id(course_id, course_name)')
          .eq('instructor_id', _instructorId!);

      setState(() {
        courses = response.map<Course>((json) => Course.fromJson(json['course'])).toList();
      });
    } catch (e) {
      _showErrorMessage('Error fetching courses: $e');
    }
  }

  Future<void> _fetchNotes() async {
    if (_instructorId == null) return;
    final response = await supabase
        .from('notes')
        .select()
        .eq('uploaded_by', _instructorId.toString())
        .order('upload_date', ascending: false);

    final notesList = List<Map<String, dynamic>>.from(response);
    setState(() {
      courseNotes = {};
      for (var note in notesList) {
        final courseId = note['course_id'].toString();
        if (!courseNotes.containsKey(courseId)) {
          courseNotes[courseId] = [];
        }
        courseNotes[courseId]!.add(note);
      }
    });
  }

  Future<void> _addOrUpdateNote() async {
    if (_instructorId == null) {
      _showErrorMessage('Instructor ID not found');
      return;
    }
    if (!_validateInputs()) return;
    setState(() => _isSaving = true);
    try {
      final noteData = {
        'course_id': selectedCourseIds.first, // Only the first selected course is used here
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'file_path': _uploadedFileUrl,
        'uploaded_by': _instructorId.toString(),
        'upload_date': _uploadDateController.text,
      };
      if (_isEditing && _currentEditId != null) {
        await supabase.from('notes').update(noteData).eq('note_id', _currentEditId!);
        _showSuccessMessage('Note updated successfully');
      } else {
        final response = await supabase.from('notes').insert(noteData).select();
        if (response.isNotEmpty) _showSuccessMessage('Note added successfully');
      }
      _resetForm();
      await _fetchNotes();
    } catch (e) {
      _showErrorMessage('Error saving note: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  bool _validateInputs() {
    if (_titleController.text.trim().isEmpty) {
      _showErrorMessage('Please enter a title');
      return false;
    }
    if (_uploadDateController.text.isEmpty) {
      _showErrorMessage('Please select an upload date');
      return false;
    }
    if (selectedCourseIds.isEmpty) {
      _showErrorMessage('Please select at least one course');
      return false;
    }
    return true;
  }

  Future<void> _pickFile() async {
    if (_instructorId == null) {
      _showErrorMessage('Instructor ID not found');
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (result != null && result.files.single.size <= _maxFileSizeBytes) {
        setState(() {
          _pickedFile = result.files.single;
          _uploadedFileName = _pickedFile!.name;
        });
        await _uploadFile();
      } else {
        _showErrorMessage('File too large (max 10MB) or invalid type');
      }
    } catch (e) {
      _showErrorMessage('Error picking file: $e');
    }
  }

  Future<void> _uploadFile() async {
    if (_instructorId == null || _pickedFile == null) return;
    setState(() => _isLoading = true);
    try {
      final fileBytes = _pickedFile!.bytes ?? await File(_pickedFile!.path!).readAsBytes();
      final fileName = '$_instructorId/${DateTime.now().millisecondsSinceEpoch}-${_pickedFile!.name}';
      await supabase.storage.from('notes').uploadBinary(fileName, fileBytes);
      final url = supabase.storage.from('notes').getPublicUrl(fileName);
      setState(() => _uploadedFileUrl = url);
      _showSuccessMessage('File uploaded successfully');
    } catch (e) {
      _showErrorMessage('Error uploading file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editNote(Map<String, dynamic> note) {
    setState(() {
      _isEditing = true;
      _currentEditId = note['note_id'];
      _titleController.text = note['title'] ?? '';
      _descriptionController.text = note['description'] ?? '';
      _uploadDateController.text = note['upload_date'] ?? '';
      _uploadedFileUrl = note['file_path'];
      _uploadedFileName = note['file_path']?.split('/').last;
      selectedCourseIds = [note['course_id'].toString()];
    });
    _showAddEditDialog(note: note);
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _currentEditId = null;
      _titleController.clear();
      _descriptionController.clear();
      _uploadDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _pickedFile = null;
      _uploadedFileUrl = null;
      _uploadedFileName = null;
      selectedCourseIds.clear();
    });
  }

  Future<void> _deleteNote(int noteId) async {
    if (_instructorId == null) return;
    setState(() => _isLoading = true);
    try {
      await supabase.from('notes').delete().eq('note_id', noteId);
      _showSuccessMessage('Note deleted successfully');
      await _fetchNotes();
    } catch (e) {
      _showErrorMessage('Error deleting note: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _downloadAndSaveFile(url, fileName);
      }
    } catch (e) {
      _showErrorMessage('Error handling file: $e');
    }
  }

  Future<void> _downloadAndSaveFile(String url, String fileName) async {
    try {
      setState(() => _isLoading = true);
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$fileName';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (await canLaunchUrl(Uri.file(filePath))) {
          await launchUrl(Uri.file(filePath), mode: LaunchMode.externalApplication);
        } else {
          _showErrorMessage('File downloaded to $filePath but cannot be opened', Colors.orange);
        }
      } else {
        _showErrorMessage('Failed to download file');
      }
    } catch (e) {
      _showErrorMessage('Error downloading file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Text(message)]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showErrorMessage(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? note}) {
    if (_instructorId == null) {
      _showErrorMessage('Instructor ID not found');
      return;
    }
    final bool isEditing = note != null;
    final titleController = TextEditingController(text: isEditing ? note!['title'] : _titleController.text);
    final descriptionController = TextEditingController(text: isEditing ? note!['description'] : _descriptionController.text);
    final uploadDateController = TextEditingController(text: isEditing ? note!['upload_date'] : _uploadDateController.text);
    List<String> dialogSelectedCourses = List.from(isEditing ? selectedCourseIds : selectedCourseIds);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_note : Icons.add_box, color: Colors.deepPurple),
              const SizedBox(width: 10),
              Text(
                isEditing ? 'Edit Note' : 'Add New Note',
                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(controller: titleController, labelText: 'Note Title', prefixIcon: Icons.title),
                const SizedBox(height: 16),
                _buildTextField(controller: descriptionController, labelText: 'Description', prefixIcon: Icons.description, maxLines: 3),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: uploadDateController,
                  labelText: 'Upload Date',
                  prefixIcon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) uploadDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Associated Courses', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const SizedBox(height: 8),
                      Column(
                        children: courses.map((course) {
                          final courseId = course.courseId;
                          return CheckboxListTile(
                            title: Text(course.courseName),
                            value: dialogSelectedCourses.contains(courseId),
                            activeColor: Colors.deepPurple,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  dialogSelectedCourses.add(courseId);
                                } else {
                                  dialogSelectedCourses.remove(courseId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_uploadedFileName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [Icon(Icons.file_present, color: Colors.deepPurple), const SizedBox(width: 8), Expanded(child: Text('File: $_uploadedFileName'))]),
                  ),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload File'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade100, foregroundColor: Colors.deepPurple),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel, color: Colors.grey),
              label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () async {
                if (titleController.text.isEmpty || uploadDateController.text.isEmpty || dialogSelectedCourses.isEmpty) {
                  _showErrorMessage('Title, date, and at least one course are required');
                  return;
                }
                Navigator.pop(context);
                setState(() {
                  _titleController.text = titleController.text;
                  _descriptionController.text = descriptionController.text;
                  _uploadDateController.text = uploadDateController.text;
                  selectedCourseIds = dialogSelectedCourses;
                  if (isEditing) {
                    _isEditing = true;
                    _currentEditId = note!['note_id'];
                  }
                });
                await _addOrUpdateNote();
              },
              icon: Icon(isEditing ? Icons.save : Icons.add),
              label: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, color: Colors.deepPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.deepPurple.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.deepPurple, width: 2)),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Materials'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: selectedCourseId,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            dropdownColor: Colors.deepPurple,
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            onChanged: (String? newValue) {
              if (newValue != null) setState(() => selectedCourseId = newValue);
            },
            items: courses.map<DropdownMenuItem<String>>((Course course) {
              return DropdownMenuItem<String>(
                value: course.courseId,
                child: Text(course.courseName, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white,),
            onPressed: () => _refreshKey.currentState?.show(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple,
        onRefresh: _fetchNotes,
        child: selectedCourseId == null || courses.isEmpty
            ? const Center(child: Text('No courses assigned to you', style: TextStyle(fontSize: 18, color: Colors.grey)))
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (courseNotes.containsKey(selectedCourseId))
              ...courseNotes[selectedCourseId]!.map((note) => _buildNoteCard(note)).toList()
            else
              const Center(child: Text('No materials uploaded for this course', style: TextStyle(fontSize: 18, color: Colors.grey))),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _instructorId != null ? _showAddEditDialog() : null,
          icon: const Icon(Icons.add),
          label: const Text('Add Material'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final DateTime uploadDate = DateTime.parse(note['upload_date']);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(note['title'] ?? 'Untitled Note', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note['description'] != null) Text(note['description']),
            Text('Uploaded: ${DateFormat('MMM dd, yyyy').format(uploadDate)}'),
            if (note['file_path'] != null)
              InkWell(
                onTap: () => _downloadFile(note['file_path'], note['file_path'].split('/').last),
                child: Text(
                  'File: ${note['file_path'].split('/').last}',
                  style: TextStyle(color: Colors.blue.shade700, decoration: TextDecoration.underline),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editNote(note)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _showDeleteConfirmation(note['note_id'])),
          ],
        ),
      ),
    );
  }

  void _showNoteDetails(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note['title'] ?? 'Untitled Note', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Description: ${note['description'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              Text('Upload Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.parse(note['upload_date']))}'),
              const SizedBox(height: 12),
              if (note['file_path'] != null)
                InkWell(
                  onTap: () => _downloadFile(note['file_path'], note['file_path'].split('/').last),
                  child: Text(
                    'File: ${note['file_path'].split('/').last}',
                    style: TextStyle(color: Colors.blue.shade700, decoration: TextDecoration.underline),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _editNote(note),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteConfirmation(note['note_id']),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(noteId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}