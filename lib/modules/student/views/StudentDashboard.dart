import 'package:campusquest/controllers/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _upcomingEvents = [];
  Map<String, dynamic>? _studentData;
  bool _isLoadingEvents = true;
  bool _isLoadingStudentData = true;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
    Future.microtask(() => _fetchData());
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchStudentData(), _fetchUpcomingEvents()]);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentData() async {
    setState(() => _isLoadingStudentData = true);
    try {
      final loginController = Provider.of<LoginController>(context, listen: false);
      final studentId = loginController.studentId;
      if (studentId == null) throw Exception('Student ID is null');
      final response = await _supabase
          .from('student')
          .select('student_id, name, roll_number, dept_name, program_id, current_semester, profile_picture_path')
          .eq('student_id', studentId)
          .single();
      setState(() {
        _studentData = response;
        _isLoadingStudentData = false;
      });
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Error fetching student data: $e');
        setState(() => _isLoadingStudentData = false);
      }
    }
  }

  Future<void> _fetchUpcomingEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      final loginController = Provider.of<LoginController>(context, listen: false);
      final programId = loginController.programId;
      if (programId == null) throw Exception('Program ID is null');
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('event')
          .select('event_id, title, description, event_date, document_path, event_program(program_id)')
          .eq('event_program.program_id', programId.toString())
          .gt('event_date', now)
          .order('event_date', ascending: true);
      if (mounted) {
        setState(() {
          _upcomingEvents = List<Map<String, dynamic>>.from(response);
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Error fetching events: $e');
        setState(() => _isLoadingEvents = false);
      }
    }
  }

  Future<void> _showEventDetails(Map<String, dynamic> event) async {
    try {
      showDialog(
        context: context,
        builder: (context) => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple))),
      );
      final programsResponse = await _supabase
          .from('event_program')
          .select('program_id, program(program_name)')
          .eq('event_id', event['event_id']);
      final List<Map<String, dynamic>> eventPrograms = List<Map<String, dynamic>>.from(programsResponse);
      if (!mounted) return;
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade50, Colors.grey.shade50],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event['title'] ?? 'Untitled Event',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.deepPurple),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.event, color: Colors.deepPurple.shade400),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(DateTime.parse(event['event_date'])),
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (event['description']?.isNotEmpty ?? false) ...[
                      const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Text(event['description'], style: TextStyle(color: Colors.grey.shade800, height: 1.5)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (eventPrograms.isNotEmpty) ...[
                      const Text('Associated Programs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: eventPrograms
                            .map((program) => Chip(
                          label: Text(program['program']['program_name']),
                          backgroundColor: Colors.deepPurple.shade100,
                          labelStyle: const TextStyle(color: Colors.deepPurple),
                        ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (event['document_path'] != null) ...[
                      const Text('Attachment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _downloadFile(event['document_path'], event['document_path'].split('/').last),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(Icons.file_present, color: Colors.deepPurple.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event['document_path'].split('/').last,
                                  style: TextStyle(color: Colors.deepPurple.shade700, decoration: TextDecoration.underline),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.download, color: Colors.deepPurple.shade700),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorMessage('Error loading event details: $e');
      }
    }
  }

  void _showFullScreenIdCard() {
    if (_studentData == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: Scaffold(
            backgroundColor: Colors.black.withOpacity(0.9),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Share functionality would go here"))),
                ),
              ],
            ),
            body: Center(
              child: Hero(
                tag: 'student-id-card',
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildFullScreenIdCard(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenIdCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.deepPurple.shade900.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Student ID Card',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 30),
              ),
            ],
          ),
          const Divider(color: Colors.white70, thickness: 1, height: 32),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
              image: _studentData!['profile_picture_path'] != null
                  ? DecorationImage(image: NetworkImage(_studentData!['profile_picture_path']), fit: BoxFit.cover)
                  : null,
            ),
            child: _studentData!['profile_picture_path'] == null
                ? const Icon(Icons.person, size: 80, color: Colors.white70)
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            _studentData!['name'] ?? 'N/A',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Roll No: ${_studentData!['roll_number'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          _buildFullScreenIdField('Student ID', _studentData!['student_id'].toString(), Icons.perm_identity),
          _buildFullScreenIdField('Department', _studentData!['dept_name'] ?? 'Not Assigned', Icons.business),
          _buildFullScreenIdField('Program ID', _studentData!['program_id'].toString(), Icons.school),
          _buildFullScreenIdField('Semester', _studentData!['current_semester'].toString(), Icons.calendar_today),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade600],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Valid for Current Semester',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenIdField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorMessage('Could not open $fileName');
      }
    } catch (e) {
      _showErrorMessage('Error opening file: $e');
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: 'DISMISS', textColor: Colors.white, onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, int index) {
    final DateTime eventDate = DateTime.parse(event['event_date']);
    final bool isUpcoming = eventDate.isAfter(DateTime.now());
    return Hero(
      tag: 'event-${event['event_id']}',
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Interval(0.1 * index, 0.6 + 0.1 * index, curve: Curves.easeOut)),
        ),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 3,
          shadowColor: Colors.deepPurple.shade200.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _showEventDetails(event),
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.deepPurple.shade200.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUpcoming ? Icons.event : Icons.event_available,
                      color: Colors.deepPurple.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'] ?? 'Untitled Event',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(eventDate),
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                        if (event['description']?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          Text(
                            event['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        ],
                        if (event['document_path'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.attachment, size: 16, color: Colors.deepPurple.shade700),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event['document_path'].split('/').last,
                                  style: TextStyle(color: Colors.deepPurple.shade700, decoration: TextDecoration.underline),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.deepPurple.shade700),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentIdCard() {
    if (_isLoadingStudentData) return _buildStudentIdCardShimmer();
    if (_studentData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            const Text('Failed to load student data', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _fetchStudentData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade700, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    return Hero(
      tag: 'student-id-card',
      child: FadeTransition(
        opacity: _animation,
        child: Card(
          elevation: 4,
          shadowColor: Colors.deepPurple.shade200.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: _showFullScreenIdCard,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade100, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple.shade300, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Student ID Card',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.school, color: Colors.deepPurple.shade700, size: 26),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.fullscreen, color: Colors.deepPurple.shade700, size: 26),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(color: Colors.deepPurple.shade700, thickness: 0.5, height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.deepPurple.shade700, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.deepPurple.shade200.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                          image: _studentData!['profile_picture_path'] != null
                              ? DecorationImage(image: NetworkImage(_studentData!['profile_picture_path']), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _studentData!['profile_picture_path'] == null
                            ? Icon(Icons.person, size: 50, color: Colors.deepPurple.shade700)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _studentData!['name'] ?? 'N/A',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.badge, size: 16, color: Colors.deepPurple.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Roll No: ${_studentData!['roll_number'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildIdField('Student ID', _studentData!['student_id'].toString(), Icons.perm_identity),
                  _buildIdField('Department', _studentData!['dept_name'] ?? 'Not Assigned', Icons.business),
                  _buildIdField('Program ID', _studentData!['program_id'].toString(), Icons.school),
                  _buildIdField('Semester', _studentData!['current_semester'].toString(), Icons.calendar_today),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentIdCardShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(width: double.infinity, height: 240, color: Colors.white),
      ),
    );
  }

  Widget _buildEventShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(height: 120, width: double.infinity),
        ),
      ),
    );
  }

  Widget _buildIdField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.deepPurple.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.deepPurple.shade700),
            const SizedBox(width: 8),
            Text(
              '$label: $value',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Student Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: _isLoadingStudentData && _isLoadingEvents
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple.shade700))
          : RefreshIndicator(
        key: _refreshKey,
        color: Colors.deepPurple.shade700,
        backgroundColor: Colors.white,
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStudentIdCard(),
            const SizedBox(height: 16),
            Text(
              'Upcoming Events',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
            ),
            const SizedBox(height: 8),
            _isLoadingEvents
                ? _buildEventShimmer()
                : _upcomingEvents.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 48, color: Colors.grey.shade600),
                  const SizedBox(height: 8),
                  Text('No upcoming events', style: TextStyle(color: Colors.grey.shade800, fontSize: 16)),
                ],
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingEvents.length,
              itemBuilder: (context, index) => _buildEventCard(_upcomingEvents[index], index),
            ),
          ],
        ),
      ),
    );
  }
}