// lib/home/dashboard/Card/work_tracking/add_people_page.dart

// ignore_for_file: unused_import

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking_page.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddPeoplePage extends StatefulWidget {
  final String projectId;

  const AddPeoplePage({super.key, required this.projectId});

  @override
  AddPeoplePageState createState() => AddPeoplePageState();
}

class AddPeoplePageState extends State<AddPeoplePage> {
  List<Map<String, dynamic>> _employees = [];
  final List<Map<String, dynamic>> _selectedPeople = [];
  String _searchQuery = '';
  bool _isLoading = false;
  final workTrackingService = WorkTrackingService();

  // New variables for groups
  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'AddPeoplePage initialized with project ID: ${widget.projectId}');
    _fetchEmployees();
    _fetchGroups(); // Fetch groups on initialization
  }

  // Existing method to fetch employees
  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
    });
    debugPrint('Fetching employees from WorkTrackingService...');
    try {
      final employees = await WorkTrackingService().getAllEmployees();
      debugPrint(
          'Employees fetched successfully. Total employees: ${employees.length}');
      // Ensure that each employee has 'isAdmin' and 'isSelected' properly set
      setState(() {
        _employees = employees.map((employee) {
          return {
            ...employee,
            'isAdmin': employee['isAdmin'] ?? false,
            'isSelected': false,
          };
        }).toList();
      });
      debugPrint('Employees processed and ready for display.');
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      _showDialog('Error', 'Failed to fetch employees. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Employee fetching process completed.');
    }
  }

  // New method to fetch groups from the API
  Future<void> _fetchGroups() async {
    setState(() {
      _isLoading = true;
    });
    debugPrint('Fetching groups from API...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        debugPrint('No token found in SharedPreferences.');
        _showDialog(
            'Error', 'Authentication token not found. Please log in again.');
        return;
      }
      debugPrint('Retrieved Bearer Token for groups: $token');

      final response = await http.get(
        Uri.parse(
            '${workTrackingService.baseUrl}/api/work-tracking/group/usergroups'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Groups API Response Status Code: ${response.statusCode}');
      debugPrint('Groups API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] != null) {
          setState(() {
            _groups = List<Map<String, dynamic>>.from(data['results']);
          });
          debugPrint(
              'Groups fetched successfully. Total groups: ${_groups.length}');
        } else {
          debugPrint(
              'Failed to fetch groups. Response message: ${data['message']}');
          _showDialog('Error', 'Failed to fetch groups. Please try again.');
        }
      } else {
        debugPrint(
            'Failed to fetch groups. Status Code: ${response.statusCode}');
        _showDialog('Error', 'Failed to fetch groups. Please try again.');
      }
    } catch (e) {
      debugPrint('Exception occurred while fetching groups: $e');
      _showDialog('Error',
          'An error occurred while fetching groups. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Group fetching process completed.');
    }
  }

  Future<void> _addMembersToProject() async {
    setState(() {
      _isLoading = true;
    });
    debugPrint(
        'Selected Members: ${_selectedPeople.map((e) => e['name']).toList()}');

    try {
      // Retrieve the token from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        debugPrint('No token found in SharedPreferences.');
        _showDialog(
            'Error', 'Authentication token not found. Please log in again.');
        return;
      }
      debugPrint('Retrieved Bearer Token: $token');

      // Prepare the request body
      List<Map<String, dynamic>> employeesMember =
          _selectedPeople.map((person) {
        String memberStatus = person['isAdmin'] ? '1' : '0';
        debugPrint(
            'Employee ID: ${person['employee_id']}, Member Status: $memberStatus');
        return {
          'employee_id': person['employee_id'],
          'member_status': memberStatus,
        };
      }).toList();

      Map<String, dynamic> requestBody = {
        'project_id': widget.projectId,
        'employees_member': employeesMember,
      };

      debugPrint('Request Body: ${jsonEncode(requestBody)}');

      // Make the POST request
      final response = await http.post(
        Uri.parse(
            '${workTrackingService.baseUrl}/api/work-tracking/project-member/insert'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('API Response Status Code: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Members added to project successfully.');

        // Optionally, you can parse the response body if needed
        // final responseData = jsonDecode(response.body);

        // Show success dialog
        _showDialog('Success',
            'All selected members have been successfully added to the project.',
            isSuccess: true);
      } else {
        debugPrint(
            'Failed to add members. Status Code: ${response.statusCode}');
        _showDialog('Error', 'Failed to add members. Please try again.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exception occurred while adding members: $e');
      }
      _showDialog(
          'Error', 'An error occurred while adding members. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Add members to project process completed.');
    }
  }

  void _showDialog(String title, String message, {bool isSuccess = false}) {
    debugPrint('$title Dialog: $message');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('Dialog "$title" dismissed.');
              Navigator.of(context).pop(); // Dismiss dialog

              if (isSuccess) {
                // Navigasi langsung ke WorkTrackingPage dan pastikan refresh
                debugPrint('Navigating to WorkTrackingPage with refresh flag');
                Navigator.of(context).pop();

                // Segarkan halaman WorkTrackingPage
                Navigator.pushReplacementNamed(context, '/workTrackingPage',
                    arguments: {'refresh': true});
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(Map<String, dynamic> employee) {
    if (_isLoading) {
      debugPrint('Cannot toggle selection while loading.');
      return; // Disable toggling if API call is in progress
    }
    setState(() {
      employee['isSelected'] = !(employee['isSelected'] ?? false);
      if (employee['isSelected']) {
        // Prevent adding duplicates
        if (!_selectedPeople.any((e) => e['id'] == employee['id'])) {
          _selectedPeople.add(employee);
          debugPrint('Selected member: ${employee['name']}');
        }
      } else {
        _selectedPeople.removeWhere((e) => e['id'] == employee['id']);
        debugPrint('Deselected member: ${employee['name']}');
      }
    });
  }

  void _toggleAdmin(Map<String, dynamic> employee) {
    if (_isLoading) {
      debugPrint('Cannot toggle admin status while loading.');
      return; // Prevent toggling if API call is in progress
    }
    setState(() {
      employee['isAdmin'] = !(employee['isAdmin'] ?? false);
      debugPrint(
          '${employee['isAdmin'] ? 'Granted' : 'Revoked'} admin rights for: ${employee['name']}');
    });
  }

  void _filterEmployees(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
    debugPrint('Filtering employees with query: "$query"');
  }

  List<Map<String, dynamic>> _getFilteredEmployees() {
    if (_searchQuery.isEmpty) {
      debugPrint('No search query. Displaying all employees.');
      return _employees;
    }
    final filtered = _employees
        .where((employee) =>
            (employee['name']?.toLowerCase().contains(_searchQuery) ?? false) ||
            (employee['email']?.toLowerCase().contains(_searchQuery) ?? false))
        .toList();
    debugPrint('Filtered employees count: ${filtered.length}');
    return filtered;
  }

  // New method to handle group selection
  void _onGroupSelected(String? groupId) {
    if (groupId == null) return;
    setState(() {
      _selectedGroupId = groupId;
    });
    debugPrint('Group selected: $groupId');

    // Find the selected group
    final selectedGroup = _groups
        .firstWhere((group) => group['groupId'] == groupId, orElse: () => {});

    if (selectedGroup.isNotEmpty && selectedGroup['employees'] != null) {
      final List<dynamic> employeesInGroup = selectedGroup['employees'];
      debugPrint('Employees in selected group: ${employeesInGroup.length}');

      setState(() {
        for (var emp in employeesInGroup) {
          // Find the employee in _employees list
          final index = _employees
              .indexWhere((e) => e['employee_id'] == emp['employee_id']);
          if (index != -1) {
            final employee = _employees[index];
            if (!(employee['isSelected'] ?? false)) {
              employee['isSelected'] = true;
              _selectedPeople.add(employee);
              debugPrint(
                  'Automatically selected member from group: ${employee['name']}');
            }
          } else {
            // If the employee is not in the main employees list, you might want to handle it accordingly
            debugPrint(
                'Employee ${emp['employee_name']} not found in the main employees list.');
          }
        }
      });
    } else {
      debugPrint('No employees found in the selected group.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final filteredEmployees = _getFilteredEmployees();

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                  isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Add Member',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () {
            debugPrint('Back button pressed.');
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.check,
                color: isDarkMode ? Colors.white : Colors.black),
            onPressed: _isLoading
                ? () {
                    debugPrint(
                        'Add Members button pressed but currently loading. Action is disabled.');
                  }
                : _addMembersToProject,
            tooltip: 'Add Selected Members',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  // Selected Members Preview
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedPeople.length + 1,
                      itemBuilder: (context, index) {
                        if (index < _selectedPeople.length) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _selectedPeople[index]
                                                  ['img_name'] !=
                                              null &&
                                          _selectedPeople[index]['img_name']
                                              .isNotEmpty
                                      ? NetworkImage(
                                          _selectedPeople[index]['img_name'])
                                      : null,
                                  child: _selectedPeople[index]['img_name'] ==
                                              null ||
                                          _selectedPeople[index]['img_name']
                                              .isEmpty
                                      ? const Icon(Icons.person,
                                          size: 30, color: Colors.white)
                                      : null,
                                ),
                                if (_selectedPeople[index]['isAdmin'] == true)
                                  const Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        } else {
                          return Transform.translate(
                            offset: const Offset(0, 0),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  '+${_selectedPeople.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: _filterEmployees,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search',
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  // Group Dropdown
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            hintText: 'Select Group',
                            hintStyle: const TextStyle(
                              fontSize: 15,
                              height: 2.5,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          value: _selectedGroupId,
                          items: _groups.map((group) {
                            return DropdownMenuItem<String>(
                              value: group['groupId'],
                              child:
                                  Text(group['group_name'] ?? 'Unnamed Group'),
                            );
                          }).toList(),
                          onChanged: _onGroupSelected,
                          isExpanded: true,
                          icon: Transform.translate(
                            offset: const Offset(0, -1),
                            child: Image.asset(
                              'assets/task.png',
                              height: 24,
                              width: 24,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredEmployees.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No employees found.'
                                  : 'No employees match your search.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredEmployees.length,
                            itemBuilder: (context, index) {
                              final employee = filteredEmployees[index];
                              final isSelected =
                                  employee['isSelected'] ?? false;
                              final isAdmin = employee['isAdmin'] ?? false;

                              return ListTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        _toggleSelection(employee);
                                      },
                                    ),
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: employee['img_name'] !=
                                                  null &&
                                              employee['img_name'].isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              employee['img_name'])
                                          : null,
                                      child: employee['img_name'] == null ||
                                              employee['img_name'].isEmpty
                                          ? const Icon(Icons.person,
                                              size: 24, color: Colors.white)
                                          : null,
                                    ),
                                  ],
                                ),
                                title: Text(
                                  employee['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(employee['email'] ?? 'No Email'),
                                trailing: IconButton(
                                  icon: Icon(
                                    isAdmin ? Icons.star : Icons.star_border,
                                    color: isAdmin ? Colors.amber : Colors.grey,
                                  ),
                                  onPressed: () => _toggleAdmin(employee),
                                  tooltip:
                                      isAdmin ? 'Revoke Admin' : 'Grant Admin',
                                ),
                                onTap: () => _toggleSelection(employee),
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
    );
  }
}
