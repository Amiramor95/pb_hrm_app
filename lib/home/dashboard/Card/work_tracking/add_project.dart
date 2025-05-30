import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_people_page.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';

// Custom TextEditingController that can store a display format
class DateTextEditingController extends TextEditingController {
  String? displayFormat;
}

class AddProjectPage extends StatefulWidget {
  const AddProjectPage({super.key});

  @override
  AddProjectPageState createState() => AddProjectPageState();
}

class AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final DateTextEditingController _deadline1Controller =
  DateTextEditingController();
  final DateTextEditingController _deadline2Controller =
  DateTextEditingController();

  final Map<String, String> statusMap = {
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  String _selectedStatus = 'Processing';
  String _selectedBranch = 'HQ Office';
  String _selectedDepartment = 'Digital Banking Dept';
  double _progress = 0.5;
  bool _isLoading = false;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void dispose() {
    _projectNameController.dispose();
    _deadline1Controller.dispose();
    _deadline2Controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
      BuildContext context, DateTextEditingController controller) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null) {
        setState(() {
          // Store original format for API but display in dd-MM-yyyy
          final String apiFormat =
          "${picked.toLocal()}".split(' ')[0]; // yyyy-MM-dd for API
          final String displayFormat =
              "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}"; // dd-MM-yyyy for display

          // Store the API format and set display format
          controller.text = apiFormat;
          controller.displayFormat = displayFormat;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to select date. Please try again.');
    }
  }

  Future<void> _createProjectAndProceed() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final newProject = {
        'project_name': _projectNameController.text.trim(),
        'department_id': '1',
        'branch_id': '1',
        'status_id': statusMap[_selectedStatus]!,
        'precent_of_project': (_progress * 100).toStringAsFixed(0),
        'deadline': _deadline1Controller.text.trim(),
        'extended': _deadline2Controller.text.trim(),
      };
      try {
        final projectId = await WorkTrackingService().addProject(newProject);
        if (projectId != null) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => AddPeoplePage(projectId: projectId)),
            );
          }
        } else {
          _showErrorDialog(
              'Project created but failed to retrieve project ID.');
        }
      } catch (e) {
        _showErrorDialog('Failed to create project. Error: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

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
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Create New Project',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.45,
                  padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createProjectAndProceed,
                    icon: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Icon(Icons.arrow_forward, color: Colors.black),
                    label: const Text(
                      'Next',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFDBB342),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Form(
                    key: _formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Name of Project',
                            style: TextStyle(
                                fontSize: 14,
                                color:
                                isDarkMode ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _projectNameController,
                            isDarkMode: isDarkMode,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the project name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Status',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Branch',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: _buildDropdownField(
                                  value: _selectedStatus,
                                  options: [
                                    'Processing',
                                    'Pending',
                                    'Finished'
                                  ],
                                  isDarkMode: isDarkMode,
                                  onChanged: (value) =>
                                      setState(() => _selectedStatus = value!),
                                  assetIconPath: 'assets/task.png',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: _buildDropdownField(
                                  value: _selectedBranch,
                                  options: [
                                    'HQ Office',
                                    'Samsen Thai B',
                                    'HQ Office Premier Room'
                                  ],
                                  isDarkMode: isDarkMode,
                                  onChanged: (value) =>
                                      setState(() => _selectedBranch = value!),
                                  assetIconPath: 'assets/task.png',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Department',
                            style: TextStyle(
                                fontSize: 14,
                                color:
                                isDarkMode ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 8),
                          _buildDropdownField(
                            value: _selectedDepartment,
                            options: [
                              'Digital Banking Dept',
                              'IT Department',
                              'Teller'
                            ],
                            isDarkMode: isDarkMode,
                            onChanged: (value) =>
                                setState(() => _selectedDepartment = value!),
                            assetIconPath: 'assets/task.png',
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Dead-line',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Dead-line 2',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  controller: _deadline1Controller,
                                  isDarkMode: isDarkMode,
                                  onTap: () => _selectDate(
                                      context, _deadline1Controller),
                                  hintText: 'dd/mm/yyyy',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDateField(
                                  controller: _deadline2Controller,
                                  isDarkMode: isDarkMode,
                                  onTap: () => _selectDate(
                                      context, _deadline2Controller),
                                  hintText: 'dd/mm/yyyy',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Percent *',
                            style: TextStyle(
                                fontSize: 14,
                                color:
                                isDarkMode ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 8),
                          _buildSlider(isDarkMode),
                          const SizedBox(height: 40),
                        ]),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required bool isDarkMode,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> options,
    required bool isDarkMode,
    required ValueChanged<String?> onChanged,
    required String assetIconPath,
  }) {
    // Add numbering to the options
    final numberedOptions = options.asMap().entries.map((entry) {
      final index = entry.key + 1; // Start numbering from 1
      final text = entry.value;
      return '$index. $text'; // Combine number and text
    }).toList();

    return DropdownButtonFormField<String>(
      value: numberedOptions.firstWhere((element) =>
          element.contains(value)), // Ensure selected value maps correctly
      onChanged: (newValue) {
        final selectedText = newValue!.substring(
            newValue.indexOf(' ') + 1); // Extract text without number
        onChanged(selectedText);
      },
      icon: Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Image.asset(assetIconPath,
            width: 16,
            height: 16,
            color: isDarkMode ? Colors.white : Colors.black),
      ),
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 8), // Reduced padding
        filled: true,
        fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
      menuMaxHeight: 300,
      items: numberedOptions.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            option,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 13, // Slightly smaller font size
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateField({
    required DateTextEditingController controller,
    required bool isDarkMode,
    required VoidCallback onTap,
    required String hintText,
  }) {
    String displayText = controller.displayFormat ?? controller.text;
    if (controller.text.isEmpty) {
      displayText = hintText;
    }

    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: displayText),
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey, fontSize: 14),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 6.0),
              child:
              Icon(Icons.calendar_month, size: 24, color: Colors.black54),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 12), // Lower height
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(bool isDarkMode) {
    // Define colors based on theme
    const primaryColor = Color(0xFFDBB342); // Gold color
    final trackColor = isDarkMode ? Colors.grey[850]! : Colors.grey[200]!;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 14,
                    pressedElevation: 8.0,
                  ),
                  overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 20),
                  activeTrackColor: primaryColor,
                  inactiveTrackColor: trackColor,
                  thumbColor: primaryColor,
                  overlayColor: Color.fromRGBO(primaryColor.r.toInt(),
                      primaryColor.g.toInt(), primaryColor.b.toInt(), 0.3),
                  valueIndicatorColor: primaryColor,
                  valueIndicatorTextStyle: TextStyle(
                    color: isDarkMode ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                ),
                child: Slider(
                  value: _progress,
                  onChanged: (value) {
                    setState(() => _progress = value);
                  },
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: '${(_progress * 100).toStringAsFixed(0)}%',
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:
                      MediaQuery.of(context).size.width * 0.9 * _progress,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
