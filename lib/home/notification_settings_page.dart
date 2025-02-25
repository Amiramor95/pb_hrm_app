import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:platform/platform.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/http_service.dart';
import '../settings/theme_notifier.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  NotificationSettingsPageState createState() =>
      NotificationSettingsPageState();
}

class NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final ApiService _apiService = ApiService();
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  List<Device> _devices = [];
  bool _isLoading = false;
  bool _biometricEnabled = false;
  String? _deviceToken;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadDevices();
    _fetchDeviceToken();
  }

  /// Fetches the FCM token
  Future<void> _fetchDeviceToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        print("Retrieved APNs Token: $apnsToken"); // Print here
        if (apnsToken != null) {
          setState(() {
            _deviceToken = apnsToken;
          });
        } else {
          print("APNs token is null. Check APNs setup in Firebase.");
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        print("Retrieved FCM Token: $fcmToken"); // Print here
        if (fcmToken != null) {
          setState(() {
            _deviceToken = fcmToken;
          });
        }
      } else {
        print("Unsupported platform.");
      }
    } catch (e) {
      print("Error getting device token: $e");
    }
  }

  /// Loads the biometric setting from secure storage.
  Future<void> _loadBiometricSetting() async {
    String? isEnabled = await _storage.read(key: 'biometricEnabled');
    setState(() {
      _biometricEnabled = isEnabled == 'true';
    });
  }

  /// Fetches the list of devices from the API.
  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<Device> devices = await _apiService.fetchDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      _showSnackBar('Error loading devices: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Toggles the notification setting for a specific device.
  Future<void> _toggleNotification(Device device) async {
    setState(() {
      device.isUpdating = true;
    });
    try {
      bool updated = await _apiService.updateDeviceStatus(device, !device.status);
      if (updated) {
        setState(() {
          device.status = !device.status;
        });
        _showSnackBar('Notification setting updated successfully');
      } else {
        _showSnackBar('Failed to update notification setting');
      }
    } catch (e) {
      _showSnackBar('Error updating device: $e');
    } finally {
      setState(() {
        device.isUpdating = false;
      });
    }
  }

  /// Adds a new device by interacting with the API.
  Future<void> _addDevice(String deviceId, String deviceToken, String platform) async {
    setState(() {
      _isLoading = true;
    });
    try {
      bool added = await _apiService.addDevice(deviceId, deviceToken, platform);
      if (added) {
        // Show success validation modal
        _showValidationModal('Device added successfully', true);
        // Reload devices after successful addition
        _loadDevices();
      } else {
        // Show failure validation modal
        _showValidationModal('Failed to add device', false);
      }
    } catch (e) {
      // Handle error and show failure validation modal
      _showValidationModal('Error adding device: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Displays the API message in a dialog after adding the device
  void _showValidationModal(String message, bool isSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog manually
      builder: (context) {
        return AlertDialog(
          title: Text(isSuccess ? 'Success' : 'Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the validation modal
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((_) {
      // Auto-refresh devices after dialog is closed if success
      if (isSuccess) {
        _loadDevices(); // Refresh device list
      }
    });
  }

  /// Displays the dialog to add a new device.
  void _showAddDeviceDialog() {
    final formKey = GlobalKey<FormState>();
    String deviceId = '';
    String platform = const LocalPlatform().isAndroid ? 'android' : 'ios';  // Automatically choose platform

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Device'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Device ID'),
                    onChanged: (value) {
                      deviceId = value.trim();
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter Device ID';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Device Token'),
                    initialValue: _deviceToken, // Auto-fill the token
                    enabled: false, // Prevent editing
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Platform'),
                    initialValue: platform, // Automatically set platform
                    enabled: false, // Prevent editing
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  if (_biometricEnabled) {
                    await _addDevice(deviceId, _deviceToken ?? '', platform);
                  } else {
                    Navigator.of(context).pop();
                    _showBiometricPrompt();
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Prompts the user to enable biometric authentication in Settings.
  void _showBiometricPrompt() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Biometric Authentication Required'),
          content: const Text('Please enable biometric authentication in Settings to add a new device.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.pushNamed(context, '/settings'); // Navigate to Settings
              },
              child: const Text('Go to Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Handles biometric authentication (if needed in the future).
  Future<void> _enableBiometrics(bool enable) async {
    // Since biometric settings are managed in settings_page.dart,
    // this function can be left empty or used for future enhancements.
  }

  /// Displays a SnackBar with the provided message.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Builds the AppBar with custom styling.
  PreferredSizeWidget _buildAppBar() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    return AppBar(
      backgroundColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        'Notification Settings',
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
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 80,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDevices,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _devices.isEmpty
                    ? const Center(child: Text('No devices found.'))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return ListTile(
                      leading: Image.asset(
                        device.platform == 'android' ? 'assets/android_device.png' : 'assets/ios_device.png',
                        width: 30,
                        height: 40,
                      ),
                      title: Text(device.deviceId),
                      subtitle: Text('Last login: ${device.lastLoginFormatted}'),
                      trailing: device.isUpdating
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : Switch(
                        value: device.status,
                        onChanged: (value) {
                          _toggleNotification(device);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeviceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Represents a device with its notification settings.
class Device {
  final String deviceId;
  final String token;
  final String platform;
  bool status;
  final DateTime lastLogin;
  bool isUpdating;

  Device({
    required this.deviceId,
    required this.token,
    required this.platform,
    required this.status,
    required this.lastLogin,
    this.isUpdating = false,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    String platform = json['platform'] ?? 'android';
    if (platform.isEmpty) {
      platform = json['device_id'].toString().toLowerCase().contains('iphone') ? 'ios' : 'android';
    }
    return Device(
      deviceId: json['device_id'],
      token: json['token'],
      platform: platform,
      status: json['status'],
      lastLogin: DateTime.parse(json['last_login']),
    );
  }

  String get lastLoginFormatted {
    return "${lastLogin.year}-${_twoDigits(lastLogin.month)}-${_twoDigits(lastLogin.day)} "
        "${_twoDigits(lastLogin.hour)}:${_twoDigits(lastLogin.minute)}";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

/// Handles all API interactions related to notification settings.
class ApiService {
  Future<List<Device>> fetchDevices() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications/settings/device/all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['statusCode'] == 200 && data['results'] != null) {
        List<Device> devices = (data['results'] as List).map((e) => Device.fromJson(e)).toList();
        return devices;
      } else {
        throw Exception(data['message'] ?? 'Failed to load devices');
      }
    } else {
      throw Exception('Failed to load devices: ${response.reasonPhrase}');
    }
  }

  Future<bool> updateDeviceStatus(Device device, bool newStatus) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/notifications/settings/device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        "deviceId": device.deviceId,
        "deviceToken": device.token,
        "platform": device.platform,
        "status": newStatus,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['statusCode'] == 200;
    } else {
      return false;
    }
  }

  Future<bool> addDevice(String deviceId, String deviceToken, String platform) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/notifications/settings/device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        "deviceId": deviceId,
        "deviceToken": deviceToken,
        "platform": platform,
        "status": true,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['statusCode'] == 200;
    } else {
      return false;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
