import 'package:flutter/material.dart';
import 'package:flutter_timetable/flutter_timetable.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimetablePage extends StatefulWidget {
  final DateTime date;
  final List<TimetableItem<String>> events;

  const TimetablePage({required this.date, required this.events, super.key});

  @override
  _TimetablePageState createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late DateTime selectedDate = widget.date;
  List<TimetableItem<String>> events = [];

  @override
  void initState() {
    super.initState();
    events = widget.events;
    _fetchLeaveRequests(selectedDate);
  }

  Future<void> _fetchLeaveRequests(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog('Authentication Error', 'Token is null. Please log in again.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body)['results'];
        final List<TimetableItem<String>> fetchedEvents = [];

        for (var item in results) {
          final DateTime startDate = item['take_leave_from'] != null
              ? DateTime.parse(item['take_leave_from'])
              : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8);
          final DateTime endDate = item['take_leave_to'] != null
              ? DateTime.parse(item['take_leave_to'])
              : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 17);
          final eventTitle = item['name'];
          final eventDescription = item['take_leave_reason'] ?? 'Approval Pending';

          // Create TimetableItems for each day of the event
          for (var day = startDate;
          day.isBefore(endDate.add(const Duration(days: 1)));
          day = day.add(const Duration(days: 1))) {
            fetchedEvents.add(
              TimetableItem<String>(
                DateTime(day.year, day.month, day.day, startDate.hour, startDate.minute),
                DateTime(day.year, day.month, day.day, endDate.hour, endDate.minute),
                data: '$eventTitle: $eventDescription',
              ),
            );
          }
        }

        setState(() {
          events = fetchedEvents;
        });
      } else {
        _showErrorDialog(
            'Failed to Load Leave Requests', 'Server returned status code: ${response.statusCode}. Message: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showErrorDialog('Error Fetching Leave Requests', 'An unexpected error occurred: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Detail Calendar Event',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 30),
                  onPressed: () {
                    setState(() {
                      selectedDate = DateTime(selectedDate.year, selectedDate.month - 1, selectedDate.day);
                      _fetchLeaveRequests(selectedDate);
                    });
                  },
                ),
                Text(
                  DateFormat.yMMMM().format(selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 30),
                  onPressed: () {
                    setState(() {
                      selectedDate = DateTime(selectedDate.year, selectedDate.month + 1, selectedDate.day);
                      _fetchLeaveRequests(selectedDate);
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final day = selectedDate.add(Duration(days: index - 3));
                final hasEvent = events.any((event) =>
                event.start.day == day.day &&
                    event.start.month == day.month &&
                    event.start.year == day.year);
                return _buildDateItem(
                  DateFormat.E().format(day),
                  day.day,
                  isSelected: day.day == selectedDate.day,
                  hasEvent: hasEvent,
                  onTap: () {
                    setState(() {
                      selectedDate = day;
                      _fetchLeaveRequests(selectedDate);
                    });
                  },
                );
              }),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _buildEventSlotsForDay(selectedDate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String day, int date,
      {bool isSelected = false, bool hasEvent = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.black : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD4A017)
                  : hasEvent
                  ? Colors.green.withOpacity(0.5)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [BoxShadow(color: Colors.black26, blurRadius: 10)]
                  : [],
            ),
            child: Text(
              "$date",
              style: TextStyle(
                fontSize: 16,
                color: isSelected || hasEvent ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlot(String time, {String? event}) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              time,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: event != null && event.isNotEmpty
                ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            )
                : Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventSlotsForDay(DateTime date) {
    final List<Widget> slots = [];
    final eventsForDay = events.where((event) =>
    event.start.day == date.day &&
        event.start.month == date.month &&
        event.start.year == date.year).toList();

    for (var i = 0; i < 24; i++) {
      final String timeLabel = "${i.toString().padLeft(2, '0')}:00";
      final matchingEvent = eventsForDay.firstWhere(
            (event) => event.start.hour == i,
        orElse: () => TimetableItem<String>(
          DateTime(date.year, date.month, date.day, i),
          DateTime(date.year, date.month, date.day, i + 1),
          data: "",
        ),
      );

      String eventTitle = matchingEvent.data ?? "";

      if (eventTitle.isNotEmpty) {
        slots.add(_buildTimeSlot(timeLabel, event: eventTitle));
      } else {
        slots.add(_buildTimeSlot(timeLabel));
      }
    }

    return slots;
  }
}
