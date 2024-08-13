import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class ProjectManagementPage extends StatefulWidget {
  final String projectId;

  const ProjectManagementPage({super.key, required this.projectId});

  @override
  _ProjectManagementPageState createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _messages = [];
  String _selectedStatus = 'All Status';
  final List<String> _statusOptions = ['All Status', 'Pending', 'Processing', 'Completed'];
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String _shortenedProjectId = '';

  final WorkTrackingService _workTrackingService = WorkTrackingService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _shortenedProjectId = widget.projectId.substring(0, 8) + '...';
    _initializeRecorder();
    _fetchProjectData();
    _loadChatMessages();
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
  }

  Future<void> _fetchProjectData() async {
    try {
      final tasks = await _workTrackingService.fetchMyProjects();
      setState(() {
        _tasks = tasks.map((task) {
          return {
            'title': task['p_name'],
            'status': task['s_name'],
            'start_date': task['created_project_at'].substring(0, 10),
            'due_date': task['dl'].substring(0, 10),
            'description': 'Project ID: ${task['project_id']}\nBranch: ${task['b_name']}',
            'images': [],
          };
        }).toList();
      });
    } catch (e) {
      print('Failed to load project data: $e');
    }
  }

  Future<void> _loadChatMessages() async {
    try {
      final messages = await _workTrackingService.fetchChatMessages(widget.projectId);
      setState(() {
        _messages = messages;
      });

      // Log the messages in the debug console
      _messages.forEach((message) {
        print('Chat Message: ${message['comments']} | From: ${message['createBy_name']} | At: ${message['created_at']}');
      });
    } catch (e) {
      print('Failed to load chat messages: $e');
    }
  }

Widget _buildChatInput(bool isDarkMode) {
  final Color backgroundColor = isDarkMode ? Colors.black : Colors.white;
  final Color textColor = isDarkMode ? Colors.white : Colors.black;

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Type a message',
              filled: true,
              fillColor: backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.yellow, width: 2),
              ),
              hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
            ),
            style: TextStyle(color: textColor),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.green,
          child: IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                _sendMessage(_messageController.text);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.red),
          onPressed: _isRecording ? _stopRecording : _startRecording,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.attach_file, color: Colors.blue),
          onPressed: _pickFile,
        ),
      ],
    ),
  );
}

  Widget _buildChatMessage(String message, String time, String senderName, bool isSentByMe, bool isDarkMode, String? filePath, String? fileType) {
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color backgroundColor = isSentByMe ? Colors.green.shade100 : Colors.blue.shade100;

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (fileType != null)
              if (fileType == 'aac')
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    // Play the audio file
                  },
                )
              else
                GestureDetector(
                  onTap: () {
                    // Open the file
                  },
                  child: Text(
                    message,
                    style: TextStyle(color: textColor, fontSize: 16, decoration: TextDecoration.underline),
                  ),
                ),
            if (fileType == null)
              Text(
                message,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAndConversationTab(bool isDarkMode) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildChatMessage(
                      message['comments'],
                      DateFormat('hh:mm a').format(DateTime.parse(message['created_at'])),
                      message['createBy_name'],
                      message['created_by'] == "PSV-00-000002", // Assuming "PSV-00-000002" is the ID of the current user
                      isDarkMode,
                      null, // Add handling for filePath and fileType if available
                      null);
                },
              ),
            ),
            _buildChatInput(isDarkMode),
          ],
        ),
      ],
    );
  }

  Future<void> _sendMessage(String message, {String? filePath, String? fileType}) async {
    try {
      await _workTrackingService.sendChatMessage(widget.projectId, message, filePath: filePath, fileType: fileType);
      _addMessage(message, filePath: filePath, fileType: fileType);
    } catch (e) {
      print('Failed to send message: $e');
    }
  }

  void _addMessage(String message, {String? filePath, String? fileType}) {
    setState(() {
      _messages.add({
        'time': DateFormat('hh:mm a').format(DateTime.now()),
        'message': message,
        'filePath': filePath,
        'fileType': fileType
      });
    });
    _messageController.clear();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.first;
      _sendMessage(file.name, filePath: file.path, fileType: file.extension);
    }
  }

  Future<void> _startRecording() async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/temp.aac';
    await _recorder.startRecorder(toFile: filePath);
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    final filePath = await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    _sendMessage('Voice Message', filePath: filePath, fileType: 'aac');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    List<Map<String, dynamic>> filteredTasks = _tasks.where((task) => _selectedStatus == 'All Status' || task['status'] == _selectedStatus).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(
              child: Text(
                'Work Tracking',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Project ID'),
                      content: Text(widget.projectId),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text(
                _shortenedProjectId,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'Processing or Detail'),
            Tab(text: 'Chat and Conversation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProcessingOrDetailTab(filteredTasks),
          _buildChatAndConversationTab(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildProcessingOrDetailTab(List<Map<String, dynamic>> filteredTasks) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    icon: const Icon(Icons.arrow_downward),
                    iconSize: 24,
                    elevation: 16,
                    style: TextStyle(color: textColor),
                    underline: Container(
                      height: 2,
                      color: Colors.transparent,
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
                            Icon(Icons.circle, color: _getStatusColor(value), size: 12),
                            const SizedBox(width: 8),
                            Text(value, style: TextStyle(color: textColor)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.green),
                onPressed: () => _showTaskModal(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              return _buildTaskCard(filteredTasks[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, int index) {
    final progressColors = {
      'Pending': Colors.orange,
      'Processing': Colors.blue,
      'Completed': Colors.green,
    };

    final startDate = DateTime.parse(task['start_date']);
    final dueDate = DateTime.parse(task['due_date']);
    final days = dueDate.difference(startDate).inDays;

    return GestureDetector(
      onTap: () {
        _showTaskViewModal(task, index);
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: progressColors[task['status']]!),
        ),
        elevation: 5,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    task['status'],
                    style: TextStyle(color: progressColors[task['status']], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Title: ${task['title']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Start Date: ${task['start_date']}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                'Due Date: ${task['due_date']}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                'Days: $days',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                'Description: ${task['description']}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  void _showTaskModal({Map<String, dynamic>? task, int? index, bool isEdit = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _TaskModal(
          task: task,
          onSave: (newTask) {
            if (task != null && index != null) {
              _editTask(index, newTask);
            } else {
              _addTask(newTask);
            }
          },
          isEdit: isEdit,
          projectId: widget.projectId, // Pass projectId here
        );
      },
    );
  }

  void _editTask(int index, Map<String, dynamic> updatedTask) {
    setState(() {
      _tasks[index] = updatedTask;
    });
  }

  Future<void> _addTask(Map<String, dynamic> task) async {
    try {
      await _workTrackingService.addProject(task);
      setState(() {
        _tasks.add(task);
      });
    } catch (e) {
      print('Failed to add task: $e');
    }
  }

  void _showTaskViewModal(Map<String, dynamic> task, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('View Task'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title: ${task['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('Status: ${task['status']}', style: TextStyle(color: _getStatusColor(task['status']))),
                const SizedBox(height: 10),
                Text('Start Date: ${task['start_date']}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text('Due Date: ${task['due_date']}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text('Description: ${task['description']}', style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 10),
                const Text('Images:'),
                const SizedBox(height: 10),
                Column(
                  children: task['images'] != null
                      ? task['images'].map<Widget>((image) {
                          return GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Image.memory(base64Decode(image)),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Image.memory(base64Decode(image), width: 100, height: 100, fit: BoxFit.cover),
                            ),
                          );
                        }).toList()
                      : [],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showTaskModal(task: task, index: index, isEdit: true);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.amber,
              ),
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }
}

class _TaskModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Function(Map<String, dynamic>) onSave;
  final bool isEdit;
  final String projectId;

  const _TaskModal({this.task, required this.onSave, this.isEdit = false, required this.projectId});

  @override
  __TaskModalState createState() => __TaskModalState();
}

class __TaskModalState extends State<_TaskModal> {
  late TextEditingController _titleController;
  late TextEditingController _startDateController;
  late TextEditingController _dueDateController;
  late TextEditingController _descriptionController;
  String _selectedStatus = 'Pending';
  final ImagePicker _picker = ImagePicker();
  List<String> _images = [];
  List<Map<String, dynamic>> _selectedPeople = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?['title'] ?? '');
    _startDateController = TextEditingController(text: widget.task?['start_date'] ?? '');
    _dueDateController = TextEditingController(text: widget.task?['due_date'] ?? '');
    _descriptionController = TextEditingController(text: widget.task?['description'] ?? '');
    _selectedStatus = widget.task?['status'] ?? 'Pending';
    if (widget.task != null && widget.task!['images'] != null) {
      _images = List<String>.from(widget.task!['images']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startDateController.dispose();
    _dueDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only upload up to 2 images')));
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      setState(() {
        _images.add(base64Image);
      });
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final task = {
        'title': _titleController.text,
        'start_date': _startDateController.text,
        'due_date': _dueDateController.text,
        'description': _descriptionController.text,
        'status': _selectedStatus,
        'images': _images,
        'members': _selectedPeople,  // Add the selected members to the task data
      };

      widget.onSave(task);

      Navigator.pop(context);
    }
  }

  void _openAddPeoplePage() async {
    final selectedPeople = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPeoplePageWorkTracking(
          projectId: widget.projectId,
          onSelectedPeople: (people) {
            setState(() {
              _selectedPeople = people;
            });
          },
        ),
      ),
    );

    if (selectedPeople != null) {
      setState(() {
        _selectedPeople = selectedPeople;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressColors = {
      'Pending': Colors.orange,
      'Processing': Colors.blue,
      'Completed': Colors.green,
    };

    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(widget.task != null ? 'Edit Task' : 'Add Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                icon: const Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: const TextStyle(color: Colors.black),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedStatus = newValue!;
                  });
                },
                items: ['Pending', 'Processing', 'Completed']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: progressColors[value], size: 12),
                        const SizedBox(width: 8),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _selectStartDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _startDateController,
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a start date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _selectDueDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dueDateController,
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an end date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Upload Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: _images.map((image) {
                  return Stack(
                    children: [
                      Image.memory(base64Decode(image), width: 100, height: 100, fit: BoxFit.cover),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _images.remove(image);
                            });
                          },
                          child: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _openAddPeoplePage,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Members'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: _selectedPeople.map((person) {
                  return Chip(
                    label: Text(person['name']),
                    onDeleted: () {
                      setState(() {
                        _selectedPeople.remove(person);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.amber,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class AddPeoplePageWorkTracking extends StatefulWidget {
  final String projectId;
  final Function(List<Map<String, dynamic>>) onSelectedPeople;

  const AddPeoplePageWorkTracking({super.key, required this.projectId, required this.onSelectedPeople});

  @override
  _AddPeoplePageWorkTrackingState createState() => _AddPeoplePageWorkTrackingState();
}

class _AddPeoplePageWorkTrackingState extends State<AddPeoplePageWorkTracking> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _selectedPeople = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final members = await WorkTrackingService().fetchMembersByProjectId(widget.projectId);
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching members: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      _members[index]['isSelected'] = !_members[index]['isSelected'];
      if (_members[index]['isSelected']) {
        _selectedPeople.add(_members[index]);
      } else {
        _selectedPeople.removeWhere((person) => person['id'] == _members[index]['id']);
      }
    });
  }

  void _confirmSelection() {
    widget.onSelectedPeople(_selectedPeople);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _members.where((member) {
      return member['name'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add People'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(filteredMembers[index]['image']),
                          ),
                          title: Text(filteredMembers[index]['name']),
                          subtitle: Text('${filteredMembers[index]['surname']} - ${filteredMembers[index]['email']}'),
                          trailing: Checkbox(
                            value: filteredMembers[index]['isSelected'],
                            onChanged: (bool? value) {
                              _toggleSelection(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
    );
  }
}