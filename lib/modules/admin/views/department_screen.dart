import 'package:campusquest/modules/admin/controllers/department_controller.dart';
import 'package:flutter/material.dart';

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => DepartmentScreenState();
}

class DepartmentScreenState extends State<DepartmentScreen> with SingleTickerProviderStateMixin {
  late final DepartmentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DepartmentController(
      context: context,
      setStateCallback: setState,
      vsync: this,
    );
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: _controller.isSearching
            ? Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller.searchController,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search departments...',
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
                onChanged: (_) => _controller.filterDepartments(),
              ),
            ),
          ],
        )
            : const Text('Departments'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_controller.isSearching ? Icons.close : Icons.search),
            onPressed: () => _controller.toggleSearch(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.fetchData,
          ),
        ],
      ),
      body: _controller.isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'Loading data...',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        key: _controller.refreshKey,
        onRefresh: _controller.fetchData,
        color: Colors.deepPurple,
        child: _controller.filteredDepartments.isEmpty
            ? Center(child: _controller.buildEmptyState(context))
            : Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _controller.filteredDepartments.length,
            itemBuilder: (context, index) {
              return _controller.buildDepartmentCard(context, _controller.filteredDepartments[index], index);
            },
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _controller.fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _controller.showAddEditDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Department'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // Center the FAB
    );
  }
}