// office_booking_event_edit_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'history_office_edit_members_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class OfficeBookingEventEditPage extends StatefulWidget {
  final String id;
  final String type; // 'leave', 'meeting', 'car'

  const OfficeBookingEventEditPage({
    super.key,
    required this.id,
    required this.type,
  });

  @override
  _OfficeBookingEventEditPageState createState() =>
      _OfficeBookingEventEditPageState();
}

class _OfficeBookingEventEditPageState
    extends State<OfficeBookingEventEditPage> {
  // Loading and Error States
  bool _isLoading = false;
  String? _errorMessage;

  // Employee ID
  String? _employeeId;

  // Selected Members for Meeting
  List<Map<String, dynamic>> _selectedMembers = [];

  // Leave Types
  List<Map<String, dynamic>> _leaveTypes = [];
  String? _selectedLeaveTypeId;

  // Controllers for Leave
  final TextEditingController _leaveFromController = TextEditingController();
  final TextEditingController _leaveToController = TextEditingController();
  final TextEditingController _leaveReasonController = TextEditingController();
  final TextEditingController _leaveDaysController = TextEditingController();

  // Controllers for Meeting (if any editable fields exist)
  final TextEditingController _meetingTitleController = TextEditingController();
  final TextEditingController _meetingFromController = TextEditingController();
  final TextEditingController _meetingToController = TextEditingController();
  final TextEditingController _meetingRoomController = TextEditingController();
  final TextEditingController _meetingTelController = TextEditingController();
  final TextEditingController _meetingRemarkController =
  TextEditingController();

  // Controllers for Car
  final TextEditingController _carPurposeController = TextEditingController();
  final TextEditingController _carPlaceController = TextEditingController();
  final TextEditingController _carDateInController = TextEditingController();
  final TextEditingController _carDateOutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployeeId();
    _fetchLeaveTypes();
    _fetchEventDetails();
  }

  @override
  void dispose() {
    // Leave Controllers
    _leaveFromController.dispose();
    _leaveToController.dispose();
    _leaveReasonController.dispose();
    _leaveDaysController.dispose();

    // Meeting Controllers
    _meetingTitleController.dispose();
    _meetingFromController.dispose();
    _meetingToController.dispose();
    _meetingRoomController.dispose();
    _meetingTelController.dispose();
    _meetingRemarkController.dispose();

    // Car Controllers
    _carPurposeController.dispose();
    _carPlaceController.dispose();
    _carDateInController.dispose();
    _carDateOutController.dispose();
    super.dispose();
  }

  /// Fetches the current user's employee ID from shared preferences
  Future<void> _fetchEmployeeId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeId = prefs.getString('employee_id') ?? '';
    });
  }

  /// Fetches leave types from the API
  Future<void> _fetchLeaveTypes() async {
    try {
      String token = await _fetchToken();
      String url = 'https://demo-application-api.flexiflows.co/api/leave-types';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Fetching Leave Types from URL: $url');
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] is List) {
          setState(() {
            _leaveTypes =
            List<Map<String, dynamic>>.from(data['results']);
          });
        } else {
          throw Exception('Failed to fetch leave types');
        }
      } else {
        throw Exception('Failed to fetch leave types: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching leave types: $e';
      });
      if (kDebugMode) {
        print('Error fetching leave types: $e');
      }
    }
  }

  /// Fetches event details based on type and id
  Future<void> _fetchEventDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String token = await _fetchToken();
      String url = '';

      switch (widget.type.toLowerCase()) {
        case 'leave':
          url =
          'https://demo-application-api.flexiflows.co/api/leave_request/${widget.id}';
          break;
        case 'meeting':
          url =
          'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room/waiting/${widget.id}';
          break;
        case 'car':
          url =
          'https://demo-application-api.flexiflows.co/api/office-administration/car_permit/${widget.id}';
          break;
        default:
          throw Exception('Invalid event type');
      }

      if (kDebugMode) {
        print('Fetching event details from URL: $url');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawData = jsonDecode(response.body)['results'];

        // Handle if 'results' is a List or Map
        if (rawData is List && rawData.isNotEmpty) {
          final responseData = rawData[0];
          if (widget.type.toLowerCase() == 'leave') {
            _populateLeaveData(responseData);
          } else if (widget.type.toLowerCase() == 'meeting') {
            _populateMeetingData(responseData);
          } else if (widget.type.toLowerCase() == 'car') {
            _populateCarData(responseData);
          }
        } else if (rawData is Map<String, dynamic>) {
          final responseData = rawData;
          if (widget.type.toLowerCase() == 'leave') {
            _populateLeaveData(responseData);
          } else if (widget.type.toLowerCase() == 'meeting') {
            _populateMeetingData(responseData);
          } else if (widget.type.toLowerCase() == 'car') {
            _populateCarData(responseData);
          }
        } else {
          throw Exception('Unexpected data format received from API.');
        }
      } else {
        throw Exception(
            'Failed to load event details: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching event details: $e';
      });
      if (kDebugMode) {
        print('Error fetching event details: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches the authentication token from shared preferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';
    if (kDebugMode) {
      print('Fetched Token: $token');
    }
    return token;
  }

  /// Populates leave request data into controllers
  void _populateLeaveData(Map<String, dynamic> data) {
    setState(() {
      _selectedLeaveTypeId = data['take_leave_type_id']?.toString() ??
          (_leaveTypes.isNotEmpty
              ? _leaveTypes.first['leave_type_id'].toString()
              : null);
      _leaveFromController.text = data['take_leave_from'] ?? '';
      _leaveToController.text = data['take_leave_to'] ?? '';
      _leaveReasonController.text = data['take_leave_reason'] ?? '';
      _leaveDaysController.text = data['days']?.toString() ?? '';
    });
  }

  /// Populates meeting data into controllers
  void _populateMeetingData(Map<String, dynamic> data) {
    setState(() {
      _meetingTitleController.text = data['title'] ?? '';
      _meetingFromController.text = data['from_date_time'] != null
          ? DateFormat('yyyy-MM-dd')
          .format(DateTime.parse(data['from_date_time']))
          : '';
      _meetingToController.text = data['to_date_time'] != null
          ? DateFormat('yyyy-MM-dd')
          .format(DateTime.parse(data['to_date_time']))
          : '';
      _meetingRoomController.text = data['room_name'] ?? '';
      _meetingTelController.text = data['employee_tel'] ?? '';
      _meetingRemarkController.text = data['remark'] ?? '';

      _selectedMembers = List<Map<String, dynamic>>.from(
          data['members']?.map((member) => {
            'employee_id': member['employee_id'],
            'employee_name': member['employee_name'],
            'img_name': member['img_name'],
          }) ??
              []);
    });
  }

  /// Populates car booking data into controllers
  void _populateCarData(Map<String, dynamic> data) {
    setState(() {
      _carPurposeController.text = data['purpose'] ?? '';
      _carPlaceController.text = data['place'] ?? '';
      _carDateInController.text = data['date_in'] ?? '';
      _carDateOutController.text = data['date_out'] ?? '';
    });
  }

  /// Validates the input fields based on the event type
  bool _validateFields() {
    switch (widget.type.toLowerCase()) {
      case 'leave':
        if (_selectedLeaveTypeId == null) {
          _showErrorMessage('Please select a leave type.');
          return false;
        }
        if (_leaveFromController.text.isEmpty ||
            _leaveToController.text.isEmpty) {
          _showErrorMessage('Please select both From and To dates.');
          return false;
        }
        if (_leaveReasonController.text.isEmpty) {
          _showErrorMessage('Please provide a reason for leave.');
          return false;
        }
        break;
      case 'meeting':
        if (_meetingTitleController.text.isEmpty) {
          _showErrorMessage('Please enter a title for the meeting.');
          return false;
        }
        if (_meetingFromController.text.isEmpty ||
            _meetingToController.text.isEmpty) {
          _showErrorMessage('Please select both From and To dates.');
          return false;
        }
        if (_meetingTelController.text.isEmpty) {
          _showErrorMessage('Please enter the employee telephone number.');
          return false;
        }
        if (_selectedMembers.isEmpty) {
          _showErrorMessage('Please select at least one member.');
          return false;
        }
        break;
      case 'car':
        if (_carPurposeController.text.isEmpty ||
            _carPlaceController.text.isEmpty ||
            _carDateInController.text.isEmpty ||
            _carDateOutController.text.isEmpty) {
          _showErrorMessage(
              'Please fill all required fields for Car Booking.');
          return false;
        }
        break;
      default:
        _showErrorMessage('Invalid event type selected.');
        return false;
    }

    // Additional validations can be added here, e.g., date comparisons

    return true;
  }

  /// Shows error message using SnackBar
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Shows success message using SnackBar
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Opens the OfficeEditMembersPage and updates selected members
  Future<void> _editMembers() async {
    final updatedMembers = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficeEditMembersPage(
          initialSelectedMembers: _selectedMembers,
          meetingId: widget.id,
        ),
      ),
    );

    if (updatedMembers != null && updatedMembers is List<Map<String, dynamic>>) {
      setState(() {
        _selectedMembers = updatedMembers;
        if (kDebugMode) {
          print('Updated Members: $_selectedMembers');
        }
      });
    }
  }

  /// Builds the leave form
  Widget _buildLeaveForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leave Type Dropdown
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Leave Type*',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          value: _selectedLeaveTypeId,
          items: _leaveTypes
              .map((leaveType) => DropdownMenuItem<String>(
            value: leaveType['leave_type_id'].toString(),
            child: Text(leaveType['name'] ?? 'Unknown Type'),
          ))
              .toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedLeaveTypeId = newValue;
              if (kDebugMode) {
                print('Selected Leave Type ID: $_selectedLeaveTypeId');
              }
            });
          },
          validator: (value) =>
          value == null ? 'Please select a leave type' : null,
        ),
        const SizedBox(height: 16.0),
        // From Date
        GestureDetector(
          onTap: () =>
              _selectDate(context, _leaveFromController, 'From Date'),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _leaveFromController,
              decoration: InputDecoration(
                labelText: 'From Date*',
                suffixIcon: const Icon(Icons.calendar_today),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // To Date
        GestureDetector(
          onTap: () => _selectDate(context, _leaveToController, 'To Date'),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _leaveToController,
              decoration: InputDecoration(
                labelText: 'To Date*',
                suffixIcon: const Icon(Icons.calendar_today),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Reason
        TextFormField(
          controller: _leaveReasonController,
          decoration: InputDecoration(
            labelText: 'Reason*',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
        // Days (Read Only, calculated or editable as per requirement)
        TextFormField(
          controller: _leaveDaysController,
          decoration: InputDecoration(
            labelText: 'Days',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          readOnly:
          true, // Make editable if days can be manually adjusted
        ),
      ],
    );
  }

  /// Builds the meeting form
  Widget _buildMeetingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        TextFormField(
          controller: _meetingTitleController,
          decoration: InputDecoration(
            labelText: 'Title*',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
        ),
        const SizedBox(height: 16.0),
        // From Date
        GestureDetector(
          onTap: () =>
              _selectDate(context, _meetingFromController, 'From Date'),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _meetingFromController,
              decoration: InputDecoration(
                labelText: 'From Date*',
                suffixIcon: const Icon(Icons.calendar_today),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // To Date
        GestureDetector(
          onTap: () => _selectDate(context, _meetingToController, 'To Date'),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _meetingToController,
              decoration: InputDecoration(
                labelText: 'To Date*',
                suffixIcon: const Icon(Icons.calendar_today),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Employee Telephone
        TextFormField(
          controller: _meetingTelController,
          decoration: InputDecoration(
            labelText: 'Employee Telephone*',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16.0),
        // Remark
        TextFormField(
          controller: _meetingRemarkController,
          decoration: InputDecoration(
            labelText: 'Remark',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
        // Members
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Members*',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: _editMembers,
              child: const Text('Edit Members'),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        _selectedMembers.isNotEmpty
            ? Wrap(
          spacing: 8.0,
          children: _selectedMembers.map((member) {
            return Chip(
              avatar: CircleAvatar(
                backgroundImage: NetworkImage(
                    member['img_name'] ??
                        'https://www.w3schools.com/howto/img_avatar.png'),
              ),
              label: Text(member['employee_name'] ?? 'No Name'),
            );
          }).toList(),
        )
            : const Text(
          'No members selected.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  /// Builds the car form
  Widget _buildCarForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Purpose
        TextFormField(
          controller: _carPurposeController,
          decoration: InputDecoration(
            labelText: 'Purpose*',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
        // Place
        TextFormField(
          controller: _carPlaceController,
          decoration: InputDecoration(
            labelText: 'Place*',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
        ),
        const SizedBox(height: 16.0),
        // Date In
        GestureDetector(
          onTap: () =>
              _selectDate(context, _carDateInController, 'Date In'),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _carDateInController,
              decoration: InputDecoration(
                labelText: 'Date In*',
                suffixIcon: const Icon(Icons.calendar_today),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Date Out
        GestureDetector(
          onTap: () =>
              _selectDate(context, _carDateOutController, 'Date Out'),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _carDateOutController,
              decoration: InputDecoration(
                labelText: 'Date Out*',
                suffixIcon: const Icon(Icons.calendar_today),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the form fields based on event type
  Widget _buildFormFields() {
    switch (widget.type.toLowerCase()) {
      case 'leave':
        return _buildLeaveForm();
      case 'meeting':
        return _buildMeetingForm();
      case 'car':
        return _buildCarForm();
      default:
        return const Center(child: Text('Unknown event type.'));
    }
  }

  /// Builds the submit button
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitEdit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orangeAccent,
        padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 15.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      ),
      child: _isLoading
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.0,
        ),
      )
          : const Text(
        'Update',
        style: TextStyle(color: Colors.black, fontSize: 18.0),
      ),
    );
  }

  /// Submits the edited event
  Future<void> _submitEdit() async {
    if (!_validateFields()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String token = await _fetchToken();
      String url = '';
      Map<String, dynamic> body = {};

      switch (widget.type.toLowerCase()) {
        case 'leave':
          url =
          'https://demo-application-api.flexiflows.co/api/leave_request/${widget.id}';
          body = {
            "take_leave_type_id": _selectedLeaveTypeId,
            "take_leave_from": _leaveFromController.text,
            "take_leave_to": _leaveToController.text,
            "take_leave_reason": _leaveReasonController.text,
            "days": _leaveDaysController.text,
          };
          break;
        case 'meeting':
          url =
          'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room/${widget.id}';
          body = {
            "title": _meetingTitleController.text,
            "from_date_time": _meetingFromController.text,
            "to_date_time": _meetingToController.text,
            "room_id": _meetingRoomController.text, // Ensure room_id is correctly formatted
            "employee_tel": _meetingTelController.text,
            "remark": _meetingRemarkController.text,
            "members": _selectedMembers.isNotEmpty
                ? _selectedMembers
                .map((member) => {"employee_id": member['employee_id']})
                .toList()
                : [],
          };
          break;
        case 'car':
          url =
          'https://demo-application-api.flexiflows.co/api/office-administration/car_permit/${widget.id}';
          body = {
            "purpose": _carPurposeController.text.isNotEmpty
                ? _carPurposeController.text
                : null,
            "place": _carPlaceController.text.isNotEmpty
                ? _carPlaceController.text
                : null,
            "date_in": _carDateInController.text.isNotEmpty
                ? _carDateInController.text
                : null,
            "date_out": _carDateOutController.text.isNotEmpty
                ? _carDateOutController.text
                : null,
          };
          break;
        default:
          throw Exception('Invalid event type');
      }

      // Remove null values to prevent sending unchanged data
      body.removeWhere((key, value) => value == null);

      if (kDebugMode) {
        print('Submitting Edit with URL: $url');
        print('Edit Body: $body');
      }

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('Edit Response Status Code: ${response.statusCode}');
        print('Edit Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessMessage('Event updated successfully!');
        Navigator.pop(context, true); // Indicate success
      } else {
        String errorMsg = 'Failed to update event.';
        if (response.body.isNotEmpty) {
          try {
            final errorResponse = jsonDecode(response.body);
            errorMsg =
            'Failed to update event: ${errorResponse['message'] ?? 'Please try again.'}';
          } catch (_) {
            // If response is not JSON, keep the default error message
          }
        }
        _showErrorMessage(errorMsg);
      }
    } catch (e) {
      _showErrorMessage('Error: $e');
      if (kDebugMode) {
        print('Error submitting edit: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine form based on type
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Office Event',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 90,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black), // Back button color
      ),
      body: Stack(
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                    color: Colors.red, fontSize: 16.0),
              ),
            )
                : SingleChildScrollView(
              child: Form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormFields(),
                    const SizedBox(height: 30.0),
                    Center(child: _buildSubmitButton()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Selects a date and updates the controller
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller, String label) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        if (kDebugMode) {
          print('Selected Date for $label: ${controller.text}');
        }
      });
    }
  }
}
