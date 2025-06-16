import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DepartmentController {
  final BuildContext context;
  final void Function(void Function()) setStateCallback;
  final TickerProvider vsync;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> filteredDepartments = [];
  bool isLoading = true;
  bool isSearching = false;

  late AnimationController animationController;
  late Animation<double> fabAnimation;
  final refreshKey = GlobalKey<RefreshIndicatorState>();
  final TextEditingController searchController = TextEditingController();

  DepartmentController({
    required this.context,
    required this.setStateCallback,
    required this.vsync,
  });

  void init() {
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 800),
    );

    fabAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.elasticOut,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      animationController.forward();
    });

    searchController.addListener(filterDepartments);
    fetchData();
  }

  void dispose() {
    animationController.dispose();
    searchController.dispose();
  }

  Future<void> fetchData() async {
    setStateCallback(() {
      isLoading = true;
    });

    try {
      final response = await _supabase
          .from('department')
          .select()
          .order('dept_name');

      setStateCallback(() {
        _departments = (response as List).cast<Map<String, dynamic>>();
        filteredDepartments = List.from(_departments);
        isLoading = false;
      });
    } catch (e) {
      showErrorMessage('Error fetching departments: ${e.toString()}');
      setStateCallback(() {
        isLoading = false;
      });
    }
  }

  void filterDepartments() {
    if (searchController.text.isEmpty) {
      setStateCallback(() {
        filteredDepartments = List.from(_departments);
        isSearching = false;
      });
      return;
    }

    final query = searchController.text.toLowerCase();
    setStateCallback(() {
      filteredDepartments = _departments.where((dept) {
        final deptName = dept['dept_name'].toString().toLowerCase();
        final building = dept['building'].toString().toLowerCase();
        final budget = dept['budget'].toString();
        return deptName.contains(query) || building.contains(query) || budget.contains(query);
      }).toList();
      isSearching = true;
    });
  }

  Future<void> _deleteDepartment(String deptName, int index) async {
    final deletedDepartment = filteredDepartments[index];

    setStateCallback(() {
      filteredDepartments.removeAt(index);
    });

    try {
      await _supabase.from('department').delete().match({'dept_name': deptName});

      showSuccessMessage(
        'Department deleted',
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            try {
              await _supabase.from('department').insert(deletedDepartment);
              fetchData();
              showSuccessMessage('Department restored');
            } catch (e) {
              showErrorMessage('Failed to restore: $e');
            }
          },
        ),
      );

      _departments.removeWhere((dept) => dept['dept_name'] == deptName);
    } catch (e) {
      setStateCallback(() {
        filteredDepartments.insert(index, deletedDepartment);
      });
      showErrorMessage('Failed to delete: $e');
    }
  }

  void showAddEditDialog(BuildContext context, {Map<String, dynamic>? department}) {
    final bool isEditing = department != null;
    final deptNameController = TextEditingController(text: isEditing ? department!['dept_name'] : '');
    final buildingController = TextEditingController(text: isEditing ? department!['building'] : '');
    final budgetController = TextEditingController(text: isEditing ? department!['budget']?.toString() : '');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Add/Edit Department",
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
                children: [
                  Icon(
                    isEditing ? Icons.edit_note : Icons.add_box,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Department' : 'Add Department',
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: deptNameController,
                      labelText: 'Department Name',
                      prefixIcon: Icons.business,
                      enabled: !isEditing, // dept_name is PK, can't edit
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: buildingController,
                      labelText: 'Building',
                      prefixIcon: Icons.location_city,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: budgetController,
                      labelText: 'Budget',
                      prefixIcon: Icons.attach_money,
                      keyboardType: TextInputType.number,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () async {
                    final deptName = deptNameController.text.trim();
                    final building = buildingController.text.trim();
                    final budgetText = budgetController.text.trim();

                    if (deptName.isEmpty || building.isEmpty || budgetText.isEmpty) {
                      showErrorMessage('All fields are required');
                      return;
                    }

                    final budget = double.tryParse(budgetText);
                    if (budget == null || budget <= 0) {
                      showErrorMessage('Budget must be a positive number');
                      return;
                    }

                    try {
                      if (isEditing) {
                        await _supabase.from('department').update({
                          'building': building,
                          'budget': budget,
                        }).match({'dept_name': department!['dept_name']});
                        showSuccessMessage('Department updated successfully');
                      } else {
                        await _supabase.from('department').insert({
                          'dept_name': deptName,
                          'building': building,
                          'budget': budget,
                        });
                        showSuccessMessage('Department added successfully');
                      }

                      Navigator.pop(context);
                      fetchData();
                    } catch (e) {
                      showErrorMessage('Operation failed: $e');
                    }
                  },
                  icon: Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.deepPurple.shade300),
        prefixIcon: Icon(prefixIcon, color: Colors.deepPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepPurple.shade200),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepPurple, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.deepPurple.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }

  void showSuccessMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: action != null ? const Duration(seconds: 5) : const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        action: action,
      ),
    );
  }

  void showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.business_outlined,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          isSearching ? 'No departments match your search' : 'No departments found',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isSearching ? 'Try a different search term' : 'Add a department to get started',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (!isSearching)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => showAddEditDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Department'),
          ),
      ],
    );
  }

  void showDepartmentDetails(BuildContext context, Map<String, dynamic> department) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
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
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            department['dept_name'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.deepPurple,
                            size: 22,
                          ),
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
                      _buildDetailItem(
                        icon: Icons.location_city,
                        title: 'Building',
                        value: department['building'],
                      ),
                      const Divider(),
                      _buildDetailItem(
                        icon: Icons.attach_money,
                        title: 'Budget',
                        value: '\$${department['budget'].toStringAsFixed(2)}',
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
                              showAddEditDialog(context, department: department);
                            },
                          ),
                          _buildActionButton(
                            label: 'Delete',
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              final index = filteredDepartments.indexWhere(
                                      (dept) => dept['dept_name'] == department['dept_name']);
                              if (index != -1) {
                                _deleteDepartment(department['dept_name'], index);
                              }
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

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
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
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDepartmentCard(BuildContext context, Map<String, dynamic> department, int index) {
    return Hero(
      tag: 'department_${department['dept_name']}',
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 12),
        elevation: 3,
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => showDepartmentDetails(context, department),
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
                            child: const Icon(Icons.business, color: Colors.deepPurple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  department['dept_name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  department['building'],
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${department['budget'].toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => showAddEditDialog(context, department: department),
                      tooltip: 'Edit',
                      splashRadius: 24,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDepartment(department['dept_name'], index),
                      tooltip: 'Delete',
                      splashRadius: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void toggleSearch() {
    setStateCallback(() {
      if (isSearching) {
        searchController.clear();
        filteredDepartments = List.from(_departments);
      }
      isSearching = !isSearching;
    });
  }
}