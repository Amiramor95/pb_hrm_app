import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_people_page.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class AddProjectPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddProject;

  const AddProjectPage({required this.onAddProject, super.key});

  @override
  AddProjectPageState createState() => AddProjectPageState();
}

class AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _deadline1Controller = TextEditingController();
  final TextEditingController _deadline2Controller = TextEditingController();

  String _selectedStatus = 'Processing';
  String _selectedBranch = 'HQ Office';
  String _selectedDepartment = 'Digital Banking Dept';
  double _progress = 0.5;

  final List<String> _statusOptions = ['Processing', 'Pending', 'Finished'];
  final List<String> _branchOptions = [
    'HQ Office',
    'Samsen thai B',
    'HQ office premier room',
    'HQ office loan meeting room',
    'Back Can yon 2F(1)',
    'Back Can yon 2F(2)'
  ];
  final List<String> _departmentOptions = [
    'Digital Banking Dept',
    'IT department',
    'Teller',
    'HQ office loan meeting room',
    'Back Can yon 2F(1)',
    'Back Can yon 2F(2)'
  ];

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  void _addProject() {
    if (_formKey.currentState!.validate()) {
      final newProject = {
        'title': _projectNameController.text,
        'status': _selectedStatus,
        'deadline1': _deadline1Controller.text,
        'deadline2': _deadline2Controller.text,
        'progress': _progress,
        'author': 'Author Name', // This can be dynamic or fetched from user data
      };
      widget.onAddProject(newProject);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),
        title: Text(
          'Create New Project',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                TextFormField(
                  controller: _projectNameController,
                  decoration: InputDecoration(
                    labelText: 'Name of Project',
                    labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the project name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdownField('Status', _selectedStatus, _statusOptions, (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                }, isDarkMode),
                const SizedBox(height: 10),
                _buildDropdownField('Branch', _selectedBranch, _branchOptions, (value) {
                  setState(() {
                    _selectedBranch = value!;
                  });
                }, isDarkMode),
                const SizedBox(height: 10),
                _buildDropdownField('Department', _selectedDepartment, _departmentOptions, (value) {
                  setState(() {
                    _selectedDepartment = value!;
                  });
                }, isDarkMode),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField('Deadline 1', _deadline1Controller, isDarkMode),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDateField('Deadline 2', _deadline2Controller, isDarkMode),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Percent *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                _buildProgressBar(isDarkMode),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddPeoplePage()),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add People'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _addProject,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('+ Add'),
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

  Widget _buildDropdownField(String label, String value, List<String> options, ValueChanged<String?> onChanged, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            );
          }).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _selectDate(context, controller),
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                suffixIcon: Icon(Icons.calendar_today, color: isDarkMode ? Colors.white : Colors.black),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a date';
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: _progress,
            onChanged: (value) {
              setState(() {
                _progress = value;
              });
            },
            min: 0,
            max: 1,
            divisions: 100,
            label: '${(_progress * 100).toStringAsFixed(0)}%',
            activeColor: isDarkMode ? Colors.amber : Colors.blue,
            inactiveColor: isDarkMode ? Colors.grey : Colors.grey[300],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(_progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}
