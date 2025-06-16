import 'package:campusquest/controllers/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SubmissionPage extends StatefulWidget {
  final String title;
  final String subject;
  final int assignmentId;
  final DateTime dueDate;
  final String description;
  final String filePath;

  const SubmissionPage({
    super.key,
    required this.title,
    required this.subject,
    required this.assignmentId,
    required this.dueDate,
    required this.description,
    required this.filePath,
  });

  @override
  State<SubmissionPage> createState() => _SubmissionPageState();
}

class _SubmissionPageState extends State<SubmissionPage> {
  final _supabase = Supabase.instance.client;
  bool _isSubmitted = false;
  String? _selectedFileName;
  String? _filePath;
  String? _feedback;
  num? _marksObtained;
  DateTime? _submissionDate;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchSubmissionStatus();
  }

  Future<void> _fetchSubmissionStatus() async {
    try {
      final loginController = Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;

      if (studentId == null) throw Exception('Student ID is null');

      final submissionResponse = await _supabase
          .from('submission')
          .select('submission_date, file_path, marks_obtained, feedback')
          .eq('assignment_id', widget.assignmentId)
          .eq('student_id', studentId)
          .maybeSingle();

      setState(() {
        if (submissionResponse != null) {
          _isSubmitted = true;
          _submissionDate = DateTime.tryParse(submissionResponse['submission_date'] ?? '');
          _filePath = submissionResponse['file_path'];
          _marksObtained = submissionResponse['marks_obtained'];
          _feedback = submissionResponse['feedback'];
          _selectedFileName = _filePath?.split('/').last;
        }
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      setState(() => _isUploading = true);
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        final loginController = Provider.of<LoginController>(context, listen: false);
        final studentId = loginController.studentId;

        if (studentId == null) throw Exception('Student ID is null');

        final fileName = '${studentId}_${widget.assignmentId}_${file.name}';
        final fileBytes = file.bytes;

        if (fileBytes == null) throw Exception('File bytes are null');

        await _supabase.storage
            .from('submissions')
            .uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(upsert: true));

        setState(() {
          _selectedFileName = file.name;
          _filePath = fileName;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File uploaded.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmAndSubmit() async {
    if (_filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please attach a file.')));
      return;
    }

    if (_isSubmitted && !widget.dueDate.isBefore(DateTime.now())) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Resubmission'),
          content: const Text('You have already submitted. Resubmitting will overwrite the previous submission. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      );

      if (confirm != true) return;
    }

    await _handleSubmit();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);

    try {
      final loginController = Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;

      if (studentId == null) throw Exception('Student ID is null');

      final submissionData = {
        'assignment_id': widget.assignmentId,
        'student_id': studentId,
        'submission_date': DateTime.now().toIso8601String(),
        'file_path': _filePath,
      };

      await _supabase.from('submission').upsert(submissionData);

      setState(() {
        _isSubmitted = true;
        _submissionDate = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadFile(String filePath, String bucket) async {
    try {
      // Ensure filePath is a raw path, not a URL
      if (filePath.startsWith('http')) {
        // Extract the path after the bucket name
        final bucketIndex = filePath.indexOf(bucket);
        if (bucketIndex != -1) {
          filePath = filePath.substring(bucketIndex + bucket.length + 1);
        }
      }

      final url = _supabase.storage.from(bucket).getPublicUrl(filePath);
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Assignment Details', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 12),
            _buildDescriptionAndAttachment(),
            const SizedBox(height: 20),
            _buildSubmissionPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final isPastDue = widget.dueDate.isBefore(DateTime.now());
    final dueDate = widget.dueDate;
    final isTomorrow = dueDate.difference(DateTime.now()).inDays == 1;

    final formattedDue = isTomorrow
        ? 'Due Tomorrow, ${DateFormat('hh:mm a').format(dueDate)}'
        : 'Due ${DateFormat('MMM dd, yyyy, hh:mm a').format(dueDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.subject, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('100 points', style: TextStyle(fontSize: 14)),
            Text(
              formattedDue,
              style: TextStyle(
                fontSize: 14,
                color: isPastDue ? Colors.red : Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionAndAttachment() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            if (widget.filePath.isNotEmpty)
              InkWell(
                onTap: () => _downloadFile(widget.filePath, 'assignments'), // Use 'assignments' bucket
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      widget.filePath.split('/').last,
                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionPanel() {
    final isPastDue = widget.dueDate.isBefore(DateTime.now());

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Work', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_isSubmitted ? Icons.check_circle : Icons.upload_file,
                    color: _isSubmitted ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: _isSubmitted && _filePath != null
                      ? InkWell(
                    onTap: () => _downloadFile(_filePath!, 'submissions'), // Use 'submissions' bucket
                    child: Text(
                      _selectedFileName ?? 'No file selected',
                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  )
                      : Text(
                    _selectedFileName ?? 'No file selected',
                    style: TextStyle(color: _isSubmitted ? Colors.green : Colors.grey),
                  ),
                ),
                if (!isPastDue)
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: Colors.deepPurple,
                    onPressed: _isUploading ? null : _pickAndUploadFile,
                  ),
              ],
            ),
            if (_submissionDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Submitted: ${DateFormat('MMM dd, yyyy').format(_submissionDate!)}'),
              ),
            const SizedBox(height: 12),
            if (!isPastDue)
              ElevatedButton(
                onPressed: _isUploading ? null : _confirmAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isSubmitted ? 'Update Submission' : 'Submit'),
              ),
            if (_marksObtained != null || _feedback != null) ...[
              const SizedBox(height: 16),
              const Text('Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_marksObtained != null ? 'Marks: $_marksObtained/10' : 'Marks: Pending'),
              const SizedBox(height: 4),
              Text(_feedback ?? 'Feedback: Pending'),
            ],
          ],
        ),
      ),
    );
  }
}