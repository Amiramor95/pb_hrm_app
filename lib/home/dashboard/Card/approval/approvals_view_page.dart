import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_request.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ApprovalsViewPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ApprovalsViewPage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildRequestorSection(),
              const SizedBox(height: 16),
              _buildBlueSection(),
              const SizedBox(height: 16),
              _buildDetailsSection(),
              const SizedBox(height: 16),
              _buildWorkflowSection(),
              const SizedBox(height: 16),
              _buildDescriptionSection(),
              const Spacer(),
              _buildActionButtons(context), // Only the staff actions
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Approvals'),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildRequestorSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(item['img_name'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
          radius: 30,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['requestor_name'] ?? 'No Name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Submitted on ${item['created_at']?.split("T")[0] ?? 'N/A'}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${item['is_approve'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 14, color: Colors.orange),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlueSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        item['types'] ?? 'No Data', // Displaying the "types" value from API
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          item['name'] ?? 'No Title', // Displaying the "name" value from API
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.calendar_today, 'Date', '${item['take_leave_from']} - ${item['take_leave_to']}'),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.access_time, 'Time', '09:00 AM - 12:00 PM'), // You can update these time details based on your requirement
        const SizedBox(height: 8),
        Text(
          'Type of leave: ${item['take_leave_reason'] ?? 'No Reason'}',
          style: const TextStyle(fontSize: 16, color: Colors.orange),
        ),
      ],
    );
  }

  Widget _buildWorkflowSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildUserAvatar(item['img_name']),
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar('https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'), // Replace with actual image URL for manager
        const Icon(Icons.arrow_forward, color: Colors.green),
        _buildUserAvatar('https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'), // Replace with actual image URL for manager
      ],
    );
  }

  Widget _buildUserAvatar(String? imageUrl) {
    return CircleAvatar(
      backgroundImage: NetworkImage(imageUrl ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg'),
      radius: 20,
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text('$title: $content'),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Description:'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item['take_leave_reason'] ?? 'No Description',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton('Delete', Colors.grey, Colors.white, onPressed: () => _deleteRequest(context)),
        _buildButton('Edit', Colors.amber, Colors.black, onPressed: () => _editRequest(context)),
      ],
    );
  }

  Widget _buildButton(String label, Color color, Color textColor, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor, backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }

  Future<void> _deleteRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      return;
    }

    final response = await http.put(
      Uri.parse('https://demo-application-api.flexiflows.co/api/leave_cancel/${item['take_leave_request_id']}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled successfully')),
      );
      Navigator.pop(context, true); // Returning to the previous page with success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request: ${response.reasonPhrase}')),
      );
    }
  }

  void _editRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRequestPage(item: item),
      ),
    );
  }
}
