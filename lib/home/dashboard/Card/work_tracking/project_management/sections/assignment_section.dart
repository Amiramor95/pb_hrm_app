// assignment_section.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_assignment.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/update_assignment.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/view_assignment.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AssignmentSection extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AssignmentSection({super.key, required this.projectId, required this.baseUrl});

  @override
  State<AssignmentSection> createState() => _AssignmentSectionState();
}

class _AssignmentSectionState extends State<AssignmentSection> {
  final WorkTrackingService _workTrackingService = WorkTrackingService();

  List<Map<String, dynamic>> _assignments = [];
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Finished'];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchAssignmentData();
  }

  Future<void> _fetchAssignmentData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/work-tracking/ass/assignments'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _assignments = List<Map<String, dynamic>>.from(data['results'] ?? []).where((assignment) {
            return assignment['proj_id'] == widget.projectId;
          }).toList();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load assignments')),
        );
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load assignment data: $e');
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  void _showAddAssignmentPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssignmentPage(
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        ),
      ),
    );

    if (result == true) {
      _fetchAssignmentData();
    }
  }

  void _showViewAssignmentPage(Map<String, dynamic> assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewAssignmentPage(
          assignmentId: assignment['as_id'],
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final createdAt = assignment['created_at'] != null ? DateTime.parse(assignment['created_at']) : DateTime.now();
    final updatedAt = assignment['updated_at'] != null ? DateTime.parse(assignment['updated_at']) : DateTime.now();
    final now = DateTime.now();
    // Assuming there are 'due_date' or similar fields; adjust accordingly
    // Since the API response doesn't provide 'from_date' and 'to_date', adjust the date-related logic
    // For demonstration, let's use 'created_at' as start date and assume 'due_date' is 'created_at' + some days
    // Adjust based on actual API response
    final dueDate = createdAt.add(const Duration(days: 7)); // Example: due in 7 days
    final daysRemaining = dueDate.difference(now).inDays;
    Color daysColor;

    String daysText;
    if (daysRemaining > 0) {
      daysColor = Colors.orange;
      daysText = '$daysRemaining day${daysRemaining > 1 ? 's' : ''} remaining';
    } else if (daysRemaining == 0) {
      daysColor = Colors.red;
      daysText = 'Today is the due date';
    } else {
      daysColor = Colors.red;
      daysText = 'Due ${-daysRemaining} day${-daysRemaining > 1 ? 's' : ''} ago';
    }

    return GestureDetector(
      onTap: () {
        _showViewAssignmentPage(assignment);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(4, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and Update Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: _getStatusColor(assignment['s_name'] ?? 'Unknown')),
                      const SizedBox(width: 8),
                      Text(
                        assignment['s_name'] ?? 'Unknown',
                        style: TextStyle(
                          color: _getStatusColor(assignment['s_name'] ?? 'Unknown'),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UpdateAssignmentPage(
                                assignmentId: assignment['as_id'],
                                projectId: widget.projectId,
                                baseUrl: widget.baseUrl,
                              ),
                            ),
                          ).then((value) {
                            if (value == true) {
                              _fetchAssignmentData();
                            }
                          });
                        },
                        child: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.alarm, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UpdateAssignmentPage(
                                assignmentId: assignment['as_id'],
                                projectId: widget.projectId,
                                baseUrl: widget.baseUrl,
                              ),
                            ),
                          ).then((value) {
                            if (value == true) {
                              _fetchAssignmentData();
                            }
                          });
                        },
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title Section
              Row(
                children: [
                  Image.asset('assets/title.png', width: 20, height: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Title: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      assignment['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Start and Due Date Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/calendar-icon.png', width: 20, height: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Date:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd').format(createdAt),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/box-time.png', width: 20, height: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Due Date:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd').format(dueDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Days Remaining Section
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: daysColor),
                  const SizedBox(width: 4),
                  Text(
                    daysText,
                    style: TextStyle(
                      fontSize: 14,
                      color: daysColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.bottomRight,
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Created by: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      TextSpan(
                        text: assignment['create_by'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontStyle: FontStyle.normal,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    List<Map<String, dynamic>> filteredAssignments = _assignments.where((assignment) {
      return _selectedStatus == 'All Status' || assignment['s_name'] == _selectedStatus;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Status Dropdown
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isDarkMode
                        ? const LinearGradient(
                      colors: [Color(0xFF424242), Color(0xFF303030)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(1, 1),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                      icon: Image.asset('assets/task.png', width: 24, height: 24),
                      iconSize: 28,
                      elevation: 16,
                      dropdownColor: isDarkMode ? const Color(0xFF424242) : Colors.white,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue!;
                        });
                      },
                      items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: _getStatusColor(value), size: 14),
                              const SizedBox(width: 10),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Add Button
              IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10.0),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
                onPressed: _showAddAssignmentPage,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? const Center(child: Text('Failed to load assignments'))
              : filteredAssignments.isEmpty
              ? const Center(child: Text('No assignment data to display'))
              : RefreshIndicator(
            onRefresh: _fetchAssignmentData,
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: filteredAssignments.length,
              itemBuilder: (context, index) {
                return _buildAssignmentCard(filteredAssignments[index]);
              },
            ),
          ),
        ),
      ],
    );
  }
}