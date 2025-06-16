import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AddEventPage extends StatefulWidget {
  final int? currentUserId;
  const AddEventPage({Key? key, this.currentUserId}) : super(key: key);

  @override
  _AddEventPageState createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> programs = [];
  List<Map<String, dynamic>> originalEvents = [];
  List<String> selectedProgramIds = [];
  bool _isLoading = false;
  bool _isSearching = false;
  int? _currentEditId;
  bool _isEditing = false;
  bool _isSaving = false;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  late AnimationController _animationController;
  late Animation<double> _fabAnimation;

  PlatformFile? _pickedFile;
  String? _uploadedFileUrl;
  String? _uploadedFileName;

  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  final List<String> _allowedExtensions = ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'];

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fabAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 500), () => _animationController.forward());

    _searchController.addListener(_performSearch);
    _initializeData();
  }

  void _performSearch() {
    final searchText = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = searchText.isNotEmpty;
      events = originalEvents.where((event) {
        return (event['title']?.toString().toLowerCase() ?? '').contains(searchText) ||
            (event['description']?.toString().toLowerCase() ?? '').contains(searchText);
      }).toList();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _eventDateController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchEvents(), _fetchPrograms()]);
    } catch (e) {
      _showErrorMessage('Error initializing data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEvents() async {
    final response = await supabase.from('event').select().order('event_date', ascending: false);
    setState(() {
      events = List<Map<String, dynamic>>.from(response);
      originalEvents = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _fetchPrograms() async {
    final response = await supabase.from('program').select('program_id, program_name');
    setState(() => programs = List<Map<String, dynamic>>.from(response));
  }

  Future<void> _addOrUpdateEvent() async {
    if (!_validateInputs()) return;

    setState(() => _isSaving = true);
    try {
      final eventData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'event_date': _eventDateController.text,
        'created_by': widget.currentUserId,
        'document_path': _uploadedFileUrl,
      };

      if (_isEditing && _currentEditId != null) {
        await supabase.from('event').update(eventData).eq('event_id', _currentEditId!);
        await _updateEventPrograms(_currentEditId!);
        _showSuccessMessage('Event updated successfully');
      } else {
        final response = await supabase.from('event').insert(eventData).select();
        if (response.isNotEmpty) {
          await _insertEventPrograms(response[0]['event_id']);
          _showSuccessMessage('Event added successfully');
        }
      }
      _resetForm();
      await _fetchEvents();
    } catch (e) {
      _showErrorMessage('Error saving event: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  bool _validateInputs() {
    if (_titleController.text.trim().isEmpty) {
      _showErrorMessage('Please enter an event title');
      return false;
    }
    if (_eventDateController.text.isEmpty) {
      _showErrorMessage('Please select an event date');
      return false;
    }
    return true;
  }

  Future<void> _updateEventPrograms(int eventId) async {
    await supabase.from('event_program').delete().eq('event_id', eventId);
    await _insertEventPrograms(eventId);
  }

  Future<void> _insertEventPrograms(int eventId) async {
    if (selectedProgramIds.isNotEmpty) {
      final insertData = selectedProgramIds.map((programId) => {'event_id': eventId, 'program_id': programId}).toList();
      await supabase.from('event_program').insert(insertData);
    }
  }

  Future<void> _pickDocument() async {
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
        _showErrorMessage('File too large (max 5MB) or invalid type');
      }
    } catch (e) {
      _showErrorMessage('Error picking file: $e');
    }
  }

  Future<void> _uploadFile() async {
    if (_pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final fileBytes = _pickedFile!.bytes ?? await File(_pickedFile!.path!).readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}-${_pickedFile!.name}';
      await supabase.storage.from('events').uploadBinary(fileName, fileBytes);
      final url = supabase.storage.from('events').getPublicUrl(fileName);
      setState(() => _uploadedFileUrl = url);
      _showSuccessMessage('File uploaded successfully');
    } catch (e) {
      _showErrorMessage('Error uploading file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editEvent(Map<String, dynamic> event) async {
    setState(() {
      _isEditing = true;
      _currentEditId = event['event_id'];
      _titleController.text = event['title'] ?? '';
      _descriptionController.text = event['description'] ?? '';
      _eventDateController.text = event['event_date'] ?? '';
      _uploadedFileUrl = event['document_path'];
      _uploadedFileName = event['document_path']?.split('/').last;
    });
    await _fetchAssociatedPrograms(event['event_id']);
    _showAddEditDialog(event: event);
  }

  Future<void> _fetchAssociatedPrograms(int eventId) async {
    final response = await supabase.from('event_program').select('program_id').eq('event_id', eventId);
    setState(() {
      selectedProgramIds = response.map((item) => item['program_id'].toString()).toList();
    });
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _currentEditId = null;
      _titleController.clear();
      _descriptionController.clear();
      _eventDateController.clear();
      _pickedFile = null;
      _uploadedFileUrl = null;
      _uploadedFileName = null;
      selectedProgramIds.clear();
    });
  }

  Future<void> _deleteEvent(int eventId) async {
    setState(() => _isLoading = true);
    try {
      await supabase.from('event_program').delete().eq('event_id', eventId);
      await supabase.from('event').delete().eq('event_id', eventId);
      _showSuccessMessage('Event deleted successfully');
      await _fetchEvents();
    } catch (e) {
      _showErrorMessage('Error deleting event: $e');
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

  void _showSuccessMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Text(message)]),
        backgroundColor: Colors.green.shade700,
        duration: action != null ? const Duration(seconds: 5) : const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        action: action,
      ),
    );
  }

  void _showErrorMessage(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? event}) {
    final bool isEditing = event != null;
    final titleController = TextEditingController(text: isEditing ? event!['title'] : _titleController.text);
    final descriptionController = TextEditingController(text: isEditing ? event!['description'] : _descriptionController.text);
    final eventDateController = TextEditingController(text: isEditing ? event!['event_date'] : _eventDateController.text);
    List<String> dialogSelectedPrograms = List.from(selectedProgramIds);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Event",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center the title
                children: [
                  Icon(isEditing ? Icons.edit_note : Icons.add_box, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Event' : 'Add New Event',
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.9, // Control dialog width
                      padding: const EdgeInsets.symmetric(horizontal: 8), // Add padding
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch form fields
                        children: [
                          const SizedBox(height: 8), // Add consistent spacing
                          TextField(
                            controller: titleController,
                            decoration: _inputDecoration('Event Title', Icons.title),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descriptionController,
                            decoration: _inputDecoration('Description', Icons.description),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: eventDateController,
                            decoration: _inputDecoration('Event Date', Icons.calendar_today),
                            readOnly: true,
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (pickedDate != null) {
                                setDialogState(() => eventDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate));
                              }
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
                                const Text('Associated Programs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                const SizedBox(height: 8),
                                // Center the program chips
                                SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: programs.map((program) {
                                      final programId = program['program_id'].toString();
                                      return FilterChip(
                                        label: Text(program['program_name']),
                                        selected: dialogSelectedPrograms.contains(programId),
                                        selectedColor: Colors.deepPurple.shade100,
                                        checkmarkColor: Colors.deepPurple,
                                        onSelected: (selected) {
                                          setDialogState(() {
                                            if (selected) {
                                              dialogSelectedPrograms.add(programId);
                                            } else {
                                              dialogSelectedPrograms.remove(programId);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_uploadedFileName != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.file_present, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('File: $_uploadedFileName', overflow: TextOverflow.ellipsis)),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => setDialogState(() {
                                      _pickedFile = null;
                                      _uploadedFileUrl = null;
                                      _uploadedFileName = null;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          // Center the upload button
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _pickDocument,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload File'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade100,
                                foregroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                // Center and space the action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel, color: Colors.grey),
                      label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () async {
                        if (titleController.text.isEmpty || eventDateController.text.isEmpty) {
                          _showErrorMessage('Title and date are required');
                          return;
                        }
                        Navigator.pop(context);
                        setState(() {
                          _titleController.text = titleController.text;
                          _descriptionController.text = descriptionController.text;
                          _eventDateController.text = eventDateController.text;
                          selectedProgramIds = dialogSelectedPrograms;
                          if (isEditing) {
                            _isEditing = true;
                            _currentEditId = event!['event_id'];
                          }
                        });
                        await _addOrUpdateEvent();
                      },
                      icon: Icon(isEditing ? Icons.save : Icons.add),
                      label: Text(isEditing ? 'Update' : 'Add'),
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

  InputDecoration _inputDecoration(String labelText, IconData prefixIcon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.deepPurple.shade300),
      prefixIcon: Icon(prefixIcon, color: Colors.deepPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.deepPurple.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
      filled: true,
      fillColor: Colors.deepPurple.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.event_note, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          _isSearching ? 'No events match your search' : 'No events found',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _isSearching ? 'Try a different search term' : 'Add an event to get started',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (!_isSearching)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () => Navigator.pop(context),
        // ),
        title: _isSearching
            ? Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                autofocus: true,
              ),
            ),
          ],
        )
            : const Text('Events'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) _searchController.clear();
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshKey.currentState?.show(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text('Loading events...', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      )
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple,
        onRefresh: _fetchEvents,
        child: events.isEmpty
            ? Center(child: _buildEmptyState())
            : Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) => _buildEventCard(events[index], index),
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Event'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, int index) {
    final DateTime eventDate = DateTime.parse(event['event_date']);
    final bool isUpcoming = eventDate.isAfter(DateTime.now());

    return Hero(
      tag: 'event_${event['event_id']}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showEventDetails(event),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.deepPurple.withOpacity(0.1),
          highlightColor: Colors.deepPurple.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isUpcoming ? Icons.event : Icons.event_available,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event['title'] ?? 'Untitled Event',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(eventDate),
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          splashRadius: 24,
                          tooltip: 'Edit',
                          onPressed: () => _editEvent(event),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          splashRadius: 24,
                          tooltip: 'Delete',
                          onPressed: () => _showDeleteConfirmation(event['event_id']),
                        ),
                      ],
                    ),
                  ],
                ),
                if (event['description'] != null && event['description'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 40),
                    child: Text(
                      event['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                if (event['document_path'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 40),
                    child: InkWell(
                      onTap: () => _downloadFile(event['document_path'], event['document_path'].split('/').last),
                      child: Row(
                        children: [
                          Icon(Icons.attachment, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event['document_path'].split('/').last,
                              style: TextStyle(color: Colors.blue.shade700, decoration: TextDecoration.underline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> event) async {
    final programsResponse = await supabase.from('event_program').select('program_id, program(program_name)').eq('event_id', event['event_id']);
    final List<Map<String, dynamic>> eventPrograms = List<Map<String, dynamic>>.from(programsResponse);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            event['title'] ?? 'Untitled Event',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(DateTime.parse(event['event_date'])),
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 1))],
                          ),
                          child: const Icon(Icons.close, color: Colors.deepPurple, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(icon: Icons.calendar_today, title: 'Date', value: DateFormat('MMMM dd, yyyy').format(DateTime.parse(event['event_date']))),
                      if (event['description'] != null && event['description'].isNotEmpty)
                        _buildDetailItem(icon: Icons.description, title: 'Description', value: event['description']),
                      if (eventPrograms.isNotEmpty)
                        _buildDetailItem(
                          icon: Icons.school,
                          title: 'Programs',
                          value: eventPrograms.map((p) => p['program']['program_name']).join(', '),
                        ),
                      if (event['document_path'] != null)
                        _buildDetailItem(
                          icon: Icons.attachment,
                          title: 'Attachment',
                          value: event['document_path'].split('/').last,
                          onTap: () => _downloadFile(event['document_path'], event['document_path'].split('/').last),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            label: 'Edit',
                            icon: Icons.edit,
                            color: Colors.blue,
                            onTap: () {
                              Navigator.pop(context);
                              _editEvent(event);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              _showDeleteConfirmation(event['event_id']);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Confirm Deletion')]),
        content: const Text('Are you sure you want to delete this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEvent(eventId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({required IconData icon, required String title, required String value, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.deepPurple),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 2),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.open_in_new, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}