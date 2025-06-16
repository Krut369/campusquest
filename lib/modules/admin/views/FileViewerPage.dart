import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path/path.dart' as path;

final supabase = Supabase.instance.client;

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _filePath;
  String? _fileName;
  String? _fileType;
  bool _isLoading = false;
  bool _isAddingEvent = false;
  bool _isEditingEvent = false;
  String? _selectedProgramId;
  String? _currentEventId;
  String? _existingFilePath;
  List<Map<String, dynamic>> _programs = [];
  final Dio _dio = Dio();
  var fileUrl;

  @override
  void initState() {
    super.initState();
    _fetchPrograms();
  }

  /// Fetch programs for dropdown
  Future<void> _fetchPrograms() async {
    try {
      final List<Map<String, dynamic>> response =
      await supabase.from('program').select('program_id, program_name');
      setState(() {
        _programs = response;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load programs: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Select a Date for Event
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /// Pick a File from Device
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'pdf', 'doc', 'docx', 'png', 'xlsx'],
    );
    if (result != null) {
      final file = result.files.first;
      setState(() {
        _filePath = file.path;
        _fileName = file.name;
        _fileType = file.extension;
      });
    }
  }

  /// Upload File to Supabase Storage
  Future<String?> _uploadFile() async {
    if (_filePath == null) return _existingFilePath;

    final file = File(_filePath!);
    final storagePath = "events/${DateTime.now().millisecondsSinceEpoch}_$_fileName";

    try {
      final response = await supabase.storage.from('uploads').upload(storagePath, file);
      return response.data?.path;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File upload failed: $e"), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  /// Get download URL for a file
  Future<String?> _getFileUrl(String filePath) async {
    try {
      // This already returns a fully formed URL with auth tokens
      return supabase.storage.from('uploads').getPublicUrl(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get file URL: $e"), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  /// Download file from Supabase Storage
  Future<void> _downloadFile(String filePath, String fileName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant storage permission to download the file.')),
          );
          return;
        }
      }

      // Get the file URL
      final fileUrl = await _getFileUrl(filePath);
      if (fileUrl == null) {
        throw Exception("Failed to get file URL");
      }

      // Get the download directory
      Directory? directory;
      if (Platform.isAndroid) {
        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        } catch (e) {
          directory = await getExternalStorageDirectory();
          if (directory == null) {
            throw Exception("Could not access external storage directory");
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        throw Exception("Platform not supported for file download");
      }

      if (directory == null) {
        throw Exception("Could not access download directory");
      }

      // Create the file path
      final savePath = '${directory.path}/$fileName';

      // Set headers to ensure the request is properly formed
      final options = Options(
        headers: {
          "Accept": "*/*",
          "Connection": "keep-alive",
        },
        followRedirects: true,
        validateStatus: (status) {
          return status != null && status < 500;
        },
      );

      // Download the file using Dio with proper options
      await _dio.download(
        fileUrl,
        savePath,
        options: options,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('Download progress: $progress%');
          }
        },
      );

      // Verify the file size after download
      final file = File(savePath);
      if (!await file.exists()) {
        throw Exception("File was not saved correctly");
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception("File is empty");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File downloaded to: $savePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
            textColor: Colors.white,
          ),
        ),
      );
    } catch (e) {
      print("Download error details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Reset form fields
  void _resetForm() {
    _titleController.clear();
    _dateController.clear();
    _descriptionController.clear();
    setState(() {
      _filePath = null;
      _fileName = null;
      _fileType = null;
      _selectedProgramId = null;
      _currentEventId = null;
      _existingFilePath = null;
    });
  }

  /// Toggle add event form
  void _toggleAddEvent() {
    setState(() {
      _isAddingEvent = !_isAddingEvent;
      _isEditingEvent = false;
      if (!_isAddingEvent) {
        _resetForm();
      }
    });
  }

  /// Load event data for editing
  void _editEvent(Map<String, dynamic> event) {
    _resetForm();

    setState(() {
      _isEditingEvent = true;
      _isAddingEvent = true;
      _currentEventId = event['event_id'];
      _titleController.text = event['title'];
      _dateController.text = event['date'];
      _descriptionController.text = event['description'];
      _selectedProgramId = event['program_id'];
      _fileName = event['file_name'];
      _fileType = event['file_type'];
      _existingFilePath = event['file_path'];
    });
  }

  /// Save edited event or add new event
  Future<void> _saveEvent() async {
    if (_titleController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? uploadedFilePath;

      // If we're editing and have a new file, remove old file first
      if (_isEditingEvent && _filePath != null && _existingFilePath != null) {
        try {
          await supabase.storage.from('uploads').remove([_existingFilePath!]);
        } catch (e) {
          // Continue even if old file deletion fails
          debugPrint('Failed to delete old file: $e');
        }
      }

      // Upload new file if available
      if (_filePath != null) {
        uploadedFilePath = await _uploadFile();
      } else {
        uploadedFilePath = _existingFilePath;
      }

      final eventData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'file_path': uploadedFilePath,
        'file_name': _fileName,
        'file_type': _fileType,
        'date': _dateController.text,
        'program_id': _selectedProgramId,
      };

      if (_isEditingEvent) {
        // Update existing event
        await supabase.from('event')
            .update(eventData)
            .eq('event_id', _currentEventId!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Insert new event
        eventData['event_id'] = DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8);
        await supabase.from('event').insert(eventData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Reset Fields and close form
      _resetForm();
      setState(() {
        _isAddingEvent = false;
        _isEditingEvent = false;
      });
    } catch (e) {
      final action = _isEditingEvent ? 'update' : 'add';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $action event: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Delete Event from Supabase
  Future<void> _deleteEvent(String eventId, String title) async {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First get the event to check if it has a file to delete
      final List<Map<String, dynamic>> eventData =
      await supabase.from('event').select('file_path').eq('event_id', eventId);

      if (eventData.isNotEmpty && eventData[0]['file_path'] != null) {
        // Delete the file from storage
        await supabase.storage.from('uploads').remove([eventData[0]['file_path']]);
      }

      // Delete the event record
      await supabase.from('event').delete().eq('event_id', eventId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event deleted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete event: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetch Events from Supabase
  Future<List<Map<String, dynamic>>> _fetchEvents() async {
    final List<Map<String, dynamic>> events = await supabase
        .from('event')
        .select('*, program:program_id(program_id, program_name)')
        .order('date', ascending: false);
    return events;
  }

  /// Get file type icon
  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Format date for display
  String _formatDate(String isoDate) {
    try {
      final DateTime date = DateTime.parse(isoDate);
      return DateFormat.yMMMMd().format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isAddingEvent
          ? _buildAddEventForm()
          : _buildEventsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleAddEvent,
        backgroundColor: Colors.indigo,
        child: Icon(_isAddingEvent ? Icons.close : Icons.add),
      ),
    );
  }

  Widget _buildAddEventForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditingEvent ? 'Edit Event' : 'Add New Event',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Event Title*',
              prefixIcon: Icon(Icons.event),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _dateController,
            readOnly: true,
            onTap: () => _selectDate(context),
            decoration: const InputDecoration(
              labelText: 'Event Date*',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedProgramId,
            decoration: const InputDecoration(
              labelText: 'Program (Optional)',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            hint: const Text('Select program'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('None'),
              ),
              ..._programs.map((program) {
                return DropdownMenuItem<String>(
                  value: program['program_id'],
                  child: Text(program['program_name']),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                _selectedProgramId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description*',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _fileName != null
                        ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attached File:',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _fileName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                        : const Text('Attach File (Optional)'),
                  ),
                  if (_fileName != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _filePath = null;
                          _fileName = null;
                          _fileType = null;
                          _existingFilePath = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saveEvent,
            icon: Icon(_isEditingEvent ? Icons.update : Icons.check),
            label: Text(_isEditingEvent ? 'Update Event' : 'Save Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No events found', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                const Text(
                  'Tap + to add your first event',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final events = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Dismissible(
                key: Key(event['event_id']),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Event'),
                      content: Text('Are you sure you want to delete "${event['title']}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ?? false;
                },
                onDismissed: (direction) {
                  _deleteEvent(event['event_id'], event['title']);
                },
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade100,
                        child: Icon(
                          event['file_path'] != null ? _getFileIcon(event['file_type']) : Icons.event,
                          color: Colors.indigo,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        event['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(event['date']),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.indigo),
                            tooltip: 'Edit Event',
                            onPressed: () => _editEvent(event),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Event',
                            onPressed: () => _deleteEvent(event['event_id'], event['title']),
                          ),
                          if (event['file_path'] != null && event['file_name'] != null)
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Colors.blue),
                              tooltip: 'View File',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FileViewerPage(
                                      filePath: event['file_path'],
                                      fileName: event['file_name'],
                                      fileType: event['file_type'],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event['program'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Chip(
                              label: Text(event['program']['program_name']),
                              backgroundColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(color: Colors.indigo.shade700),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        const Text(
                          'Description:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(event['description']),
                        if (event['file_path'] != null && event['file_name'] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getFileIcon(event['file_type']),
                                  color: Colors.indigo,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Attachment:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        event['file_name'],
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () {
                                    // Handle file download
                                    if (event['file_path'] != null && event['file_name'] != null) {
                                      _downloadFile(event['file_path'], event['file_name']);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No file attached to download'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                  color: Colors.indigo,
                                  tooltip: 'Download file',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

extension on String {
  get data => null;
}

class FileViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String fileType;

  const FileViewerPage({
    Key? key,
    required this.filePath,
    required this.fileName,
    required this.fileType,
  }) : super(key: key);

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  bool _isLoading = true;
  String? _localFilePath;
  String? _errorMessage;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    try {
      // Get the file URL from Supabase
      final String fileUrl = await _getFileUrl(widget.filePath);
      if (fileUrl == null) {
        throw Exception("Failed to get file URL");
      }

      // Get temporary directory to store the file
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/${widget.fileName}';

      // Check if file already exists in temp directory
      final file = File(localPath);
      if (await file.exists()) {
        setState(() {
          _localFilePath = localPath;
          _isLoading = false;
        });
        return;
      }

      // File doesn't exist, download it
      final options = Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        validateStatus: (status) {
          return status != null && status < 500;
        },
      );

      final response = await _dio.get(
        fileUrl,
        options: options,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('Download progress: $progress%');
          }
        },
      );

      // Write the bytes directly to the file
      await file.writeAsBytes(response.data);

      setState(() {
        _localFilePath = localPath;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading file: $e';
        _isLoading = false;
      });
      print("File preparation error: $e");
    }
  }

  Future<String> _getFileUrl(String filePath) async {
    try {
      return supabase.storage.from('uploads').getPublicUrl(filePath);
    } catch (e) {
      throw Exception("Failed to get file URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadFile,
            tooltip: 'Download file',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Implement share functionality here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality not implemented yet')),
              );
            },
            tooltip: 'Share file',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _prepareFile,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _buildFileViewer(),
    );
  }

  Widget _buildFileViewer() {
    if (_localFilePath == null) {
      return const Center(child: Text('File not found'));
    }

    final fileExtension = path.extension(widget.fileName).toLowerCase();

    // Debugging: Print the file extension to see what it evaluates to
    debugPrint('File Extension: $fileExtension');

    // PDF Viewer
    if (fileExtension == '.pdf') {
      return PDFView(
        filePath: _localFilePath!,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: false,
        pageSnap: true,
        defaultPage: 0,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        onError: (error) {
          print('PDF Error: $error');
          
        },
        onPageError: (page, error) {
          print('PDF Page Error: $error');
          
        },
      );
    }

    // Image Viewer
    else if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(fileExtension)) {
      return PhotoView(
        imageProvider: FileImage(File(_localFilePath!)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
      );
    }

    // Unsupported file type
    else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFileIcon(fileExtension),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'File type $fileExtension cannot be previewed',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _downloadFile,
              child: const Text('Download instead'),
            ),
          ],
        ),
      );
    }
  }

  IconData _getFileIcon(String? fileExtension) {
    if (fileExtension == null) return Icons.insert_drive_file;

    switch (fileExtension.toLowerCase()) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
        return Icons.image;
      case '.xlsx':
      case '.xls':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _downloadFile() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading file...')),
      );

      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant storage permission to download the file.')),
          );
          return;
        }
      }

      // Get the download directory
      Directory? directory;
      if (Platform.isAndroid) {
        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        } catch (e) {
          directory = await getExternalStorageDirectory();
          if (directory == null) {
            throw Exception("Could not access external storage directory");
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory(); // Use getApplicationDocumentsDirectory for iOS
      } else {
        throw Exception("Platform not supported for file download");
      }

      if (directory == null) {
        throw Exception("Could not access download directory");
      }

      // Create the file path
      final savePath = '${directory.path}/${widget.fileName}';

      // Just copy the already downloaded temporary file to the download directory
      if (_localFilePath != null) {
        final File sourceFile = File(_localFilePath!);
        final File destinationFile = File(savePath);
        await sourceFile.copy(savePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded to: $savePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        throw Exception("File not available locally");
      }
    } catch (e) {
      print("Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}