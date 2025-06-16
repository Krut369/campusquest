import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NotesViewPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final List<Map<String, dynamic>> chapters;
  final List<Map<String, dynamic>> notes;

  const NotesViewPage({
    Key? key,
    required this.courseId,
    required this.courseName,
    required this.chapters,
    required this.notes,
  }) : super(key: key);

  @override
  _NotesViewPageState createState() => _NotesViewPageState();
}

class _NotesViewPageState extends State<NotesViewPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;

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

  void _showErrorMessage(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final DateTime uploadDate = DateTime.parse(note['upload_date'] ?? DateTime.now().toString());
    final String fileName = note['file_path'] != null
        ? note['file_path'].toString().split('/').last
        : 'No file available';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showNoteDetails(note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        _getFileIcon(fileName),
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note['title'] ?? 'Unknown Note',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (note['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            note['description'],
                            style: TextStyle(color: Colors.grey.shade700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Uploaded: ${DateFormat('MMM dd, yyyy').format(uploadDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (note['file_path'] != null)
                    TextButton.icon(
                      onPressed: () => _downloadFile(
                        note['file_path'],
                        fileName,
                      ),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) return Icons.description;
    if (fileName.endsWith('.ppt') || fileName.endsWith('.pptx')) return Icons.slideshow;
    if (fileName.endsWith('.xls') || fileName.endsWith('.xlsx')) return Icons.table_chart;
    if (fileName.endsWith('.txt')) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  void _showNoteDetails(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                note['title'] ?? 'Unknown Note',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 12),
              if (note['description'] != null)
                Text(
                  'Description:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              if (note['description'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(
                    note['description'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.deepPurple.shade300, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Uploaded: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(note['upload_date'] ?? DateTime.now().toString()))}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, color: Colors.deepPurple.shade300, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'By: ${note['uploaded_by'] ?? 'Unknown'}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (note['file_path'] != null) ...[
                const Text(
                  'Download File:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _downloadFile(
                    note['file_path'],
                    note['file_path'].toString().split('/').last,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.deepPurple.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_present, color: Colors.deepPurple.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note['file_path'].toString().split('/').last,
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.download, color: Colors.deepPurple.shade700),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseId,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              widget.courseName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.chapters.length,
        itemBuilder: (context, index) {
          return _buildNoteCard(widget.chapters[index]);
        },
      ),
    );
  }
}