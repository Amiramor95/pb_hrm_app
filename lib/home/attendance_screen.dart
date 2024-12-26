// attendance_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../settings/theme_notifier.dart';
import 'monthly_attendance_record.dart';
import '../hive_helper/model/attendance_record.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pb_hrsystem/main.dart';

/// Mixin to handle Authentication Logic including biometric and fallback authentication.
mixin AuthenticationMixin<T extends StatefulWidget> on State<T> {
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();


  /// Attempts biometric authentication. If it fails or is unavailable, prompts for PIN/password.
  Future<bool> authenticateUser(BuildContext context) async {
    bool canCheckBiometrics = await auth.canCheckBiometrics;
    bool isDeviceSupported = await auth.isDeviceSupported();
    String? biometricEnabledStored = await _storage.read(key: 'biometricEnabled');

    bool biometricEnabled = (biometricEnabledStored == 'true') && canCheckBiometrics && isDeviceSupported;

    if (biometricEnabled) {
      try {
        bool didAuthenticate = await auth.authenticate(
          localizedReason: AppLocalizations.of(context)!.authenticateToLogin,
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          return true;
        } else {
          // Fallback to PIN/password if biometric fails
          return await _fallbackAuthentication(context);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Biometric authentication error: $e');
        }
        // Fallback to PIN/password in case of error
        return await _fallbackAuthentication(context);
      }
    } else {
      // If biometrics not enabled or available, use PIN/password
      return await _fallbackAuthentication(context);
    }
  }

  /// Fallback authentication method using PIN or password.
  Future<bool> _fallbackAuthentication(BuildContext context) async {
    String? storedPin = await _storage.read(key: 'userPin');

    if (storedPin == null) {
      // If no PIN is set, prompt user to set one
      await _promptSetPin(context);
      return false;
    }

    String enteredPin = await _promptEnterPin(context);

    if (enteredPin == storedPin) {
      return true;
    } else {
      _showCustomDialog(
        context,
        AppLocalizations.of(context)!.authenticationFailed,
        AppLocalizations.of(context)!.incorrectPin,
        isSuccess: false,
      );
      return false;
    }
  }

  /// Prompts the user to set a PIN.
  Future<void> _promptSetPin(BuildContext context) async {
    TextEditingController pinController = TextEditingController();
    TextEditingController confirmPinController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.setPin),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.enterPin,
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: confirmPinController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.confirmPin,
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                String pin = pinController.text;
                String confirmPin = confirmPinController.text;

                if (pin.isEmpty || confirmPin.isEmpty) {
                  _showCustomDialog(
                    context,
                    AppLocalizations.of(context)!.error,
                    AppLocalizations.of(context)!.pinCannotBeEmpty,
                    isSuccess: false,
                  );
                  return;
                }

                if (pin != confirmPin) {
                  _showCustomDialog(
                    context,
                    AppLocalizations.of(context)!.error,
                    AppLocalizations.of(context)!.pinsDoNotMatch,
                    isSuccess: false,
                  );
                  return;
                }

                await _storage.write(key: 'userPin', value: pin);
                Navigator.of(context).pop();
                _showCustomDialog(
                  context,
                  AppLocalizations.of(context)!.success,
                  AppLocalizations.of(context)!.pinSetSuccessfully,
                  isSuccess: true,
                );
              },
              child: Text(AppLocalizations.of(context)!.set),
            ),
          ],
        );
      },
    );
  }

  /// Prompts the user to enter their PIN.
  Future<String> _promptEnterPin(BuildContext context) async {
    TextEditingController pinController = TextEditingController();
    String enteredPin = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.enterPin),
          content: TextField(
            controller: pinController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.pin,
            ),
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                enteredPin = pinController.text;
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.submit),
            ),
          ],
        );
      },
    );

    return enteredPin;
  }

  /// Displays a custom dialog with given title and message.
  void _showCustomDialog(BuildContext context, String title, String message, {bool isSuccess = true}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              border: Border.all(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Attendance icon and text row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/attendance.png',
                              width: 40,
                              color: isDarkMode ? const Color(0xFFDBB342) : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.attendance,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Icon and Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                              color: isSuccess
                                  ? (isDarkMode ? Colors.greenAccent : Colors.green)
                                  : (isDarkMode ? Colors.redAccent : Colors.red),
                              size: constraints.maxWidth < 400 ? 40 : 50,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 18 : 20,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Message
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.close,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Mixin to handle Geolocation Logic including location monitoring and section determination.
mixin GeolocationMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<Position>? _positionStreamSubscription;
  String _currentSection = 'Home';
  static const double _officeRange = 500;
  static LatLng officeLocation = const LatLng(2.891589, 101.524822);

  /// Starts monitoring the user's location.
  void startLocationMonitoring() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Notify if the user moves 10 meters or more
      ),
    ).listen((Position position) {
      _determineSectionFromPosition(position);
    });
  }

  /// Determines the current section based on the user's position.
  void _determineSectionFromPosition(Position position) {
    double distanceToOffice = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLocation.latitude,
      officeLocation.longitude,
    );

    if (kDebugMode) {
      print('Current position: (${position.latitude}, ${position.longitude})');
      print('Distance to office: $distanceToOffice meters');
    }

    setState(() {
      if (distanceToOffice <= _officeRange) {
        _currentSection = 'Office';
      } else {
        _currentSection = 'Home';
      }
    });
  }

  /// Retrieves the current section.
  String get currentSection => _currentSection;

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}

/// Widget to display live time, optimized to rebuild only necessary parts.
class LiveTimeDisplay extends StatefulWidget {
  const LiveTimeDisplay({super.key});

  @override
  _LiveTimeDisplayState createState() => _LiveTimeDisplayState();
}

class _LiveTimeDisplayState extends State<LiveTimeDisplay> {
  late Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _timeStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DateTime>(
      stream: _timeStream,
      builder: (context, snapshot) {
        DateTime currentTime = snapshot.data ?? DateTime.now();
        String formattedTime = DateFormat('HH:mm:ss').format(currentTime);
        String formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(currentTime);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.hasData ? formattedTime : '--:--:--',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget to display individual attendance records.
class AttendanceRowWidget extends StatelessWidget {
  final Map<String, String> record;

  const AttendanceRowWidget({super.key, required this.record});

  /// Returns color based on status.
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase() ?? 'unknown') {
      case 'office':
        return Colors.green;
      case 'offsite':
        return Colors.red;
      case 'home':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final DateTime date = DateFormat('yyyy-MM-dd').parse(record['date']!);
    final String day = DateFormat('EEEE').format(date); // Day part
    final String datePart = DateFormat('dd-MM-yyyy').format(date); // Date part

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: isDarkMode ? Colors.grey[800] : Colors.white, // Adjust background color based on theme
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            // Centered Date Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: day, // Weekday
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF003366),
                        ),
                      ),
                      const TextSpan(text: ', '), // Comma separator
                      TextSpan(
                        text: datePart, // Date part
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode ? Colors.white70 : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status Icon for Check-Out
                _buildAttendanceStatusIcon(record['checkOut']!),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 8),
            // Attendance Items Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttendanceItem(
                  AppLocalizations.of(context)!.checkIn,
                  record['checkIn'] ?? '--:--:--',
                  _getStatusColor(record['checkInStatus']),
                ),
                _buildAttendanceItem(
                  AppLocalizations.of(context)!.checkOut,
                  record['checkOut'] ?? '--:--:--',
                  _getStatusColor(record['checkOutStatus']),
                ),
                _buildAttendanceItem(AppLocalizations.of(context)!.workingHours, record['workingHours']!, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the status icon based on check-out time.
  Widget _buildAttendanceStatusIcon(String checkOutTime) {
    return Icon(
      checkOutTime != '--:--:--' ? Icons.check_circle : Icons.hourglass_empty,
      color: checkOutTime != '--:--:--' ? Colors.green : Colors.orange,
      size: 20,
    );
  }

  /// Builds individual attendance item.
  Widget _buildAttendanceItem(String title, String time, Color color) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.black87, fontSize: 12),
        ),
      ],
    );
  }
}

/// Widget to display summary items in the header.
class SummaryItemWidget extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final Color color;

  const SummaryItemWidget({
    super.key,
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Icon with dynamic color based on dark mode
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        // Time Text with dynamic color based on dark mode
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black, // Adjust time color
          ),
        ),
        // Title Text with dynamic color based on dark mode
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : Colors.black87, // Adjust title color
          ),
        ),
      ],
    );
  }
}

/// Widget to display the header content including live time and check-in/check-out button.
class HeaderContentWidget extends StatelessWidget {
  final bool isCheckInActive;
  final bool isOffsite;
  final VoidCallback onTap;
  final String checkInTime;
  final String checkOutTime;
  final Duration workingHours;
  final String totalCheckInDelay;
  final String totalCheckOutDelay;
  final String totalWorkDuration;

  const HeaderContentWidget({
    super.key,
    required this.isCheckInActive,
    required this.isOffsite,
    required this.onTap,
    required this.checkInTime,
    required this.checkOutTime,
    required this.workingHours,
    required this.totalCheckInDelay,
    required this.totalCheckOutDelay,
    required this.totalWorkDuration,
  });

  /// Builds individual summary item.
  Widget _buildSummaryItem(BuildContext context, String title, String time, IconData icon, Color color) {
    return SummaryItemWidget(
      title: title,
      time: time,
      icon: icon,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Fingerprint decoration based on offsite status
    BoxDecoration fingerprintDecoration;
    if (isOffsite) {
      fingerprintDecoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      );
    } else {
      fingerprintDecoration = const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.green],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black54 : Colors.black12, // Shadow color for dark mode
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Date and Time
            const LiveTimeDisplay(),
            const SizedBox(height: 16),

            // Fingerprint button with dynamic background color
            Container(
              width: 80,
              height: 80,
              decoration: fingerprintDecoration,
              child: const Icon(
                Icons.fingerprint,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Check In/Check Out button text
            Text(
              isCheckInActive ? AppLocalizations.of(context)!.checkOut : AppLocalizations.of(context)!.checkIn,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Register presence text
            Text(
              AppLocalizations.of(context)!.registerPresenceStartWork,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Month and Year display (e.g., February - 2024)
            Text(
              DateFormat('MMMM - yyyy').format(DateTime.now()),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  context,
                  AppLocalizations.of(context)!.checkIn,
                  totalCheckInDelay,
                  Icons.login,
                  Colors.green,
                ),
                _buildSummaryItem(
                  context,
                  AppLocalizations.of(context)!.checkOut,
                  totalCheckOutDelay,
                  Icons.logout,
                  Colors.red,
                ),
                _buildSummaryItem(
                  context,
                  AppLocalizations.of(context)!.workingHours,
                  totalWorkDuration,
                  Icons.timer,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Main Attendance Screen Widget incorporating all improvements.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  AttendanceScreenState createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen>
    with AuthenticationMixin, GeolocationMixin {
  @override
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final userPreferences = sl<UserPreferences>();
// 0 for Home/Office, 1 for Offsite
  bool _isCheckInActive = false;
  String _checkInTime = '--:--:--';
  String _checkOutTime = '--:--:--';
  DateTime? _checkInDateTime;
  DateTime? _checkOutDateTime;
  Duration _workingHours = Duration.zero;
  Timer? _workingHoursTimer;
  @override
  String _currentSection = 'Home';
  String _deviceId = '';
  List<Map<String, String>> _weeklyRecords = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _isOffsite = false;
  String _totalCheckInDelay = '--:--:--';
  String _totalCheckOutDelay = '--:--:--';
  String _totalWorkDuration = '--:--:--';
  static const String officeApiUrl =
      'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/office';
  static const String offsiteApiUrl =
      'https://demo-application-api.flexiflows.co/api/attendance/checkin-checkout/offsite';

  static LatLng officeLocation = const LatLng(2.891589, 101.524822);

  @override
  void initState() {
    super.initState();
    _fetchWeeklyRecords();
    _retrieveSavedState();
    _retrieveDeviceId();
    startLocationMonitoring();
    _startRefreshTimer();
    _determineAndShowLocationModal();
    _listenToConnectivityChanges();
  }

  /// Listens to connectivity changes to handle offline and online states.
  void _listenToConnectivityChanges() {
    Connectivity().onConnectivityChanged.listen((source) {
      if (source == ConnectivityResult.wifi ||
          source == ConnectivityResult.mobile) {
        offlineProvider.autoOffline(false);
        offlineProvider.syncPendingAttendance();
      }
    });
  }

  /// Starts a timer to refresh weekly records every hour.
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _fetchWeeklyRecords();
    });
  }

  /// Determines the user's location and shows a modal if necessary.
  Future<void> _determineAndShowLocationModal() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      _determineSectionFromPosition(currentPosition);
    }

    setState(() {
      _isLoading = false;
    });

    // Uncomment the below line if you want to show location modal
    // _showLocationModal(_isOffsite ? 'Offsite' : 'Office');
  }

  /// Retrieves and stores the device ID.
  Future<void> _retrieveDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor!;
    }
    setState(() {
      sl<UserPreferences>().setDevice(_deviceId);
      if (kDebugMode) {
        print('Device ID retrieved: $_deviceId');
      }
    });
  }

  /// Retrieves saved state from local storage.
  Future<void> _retrieveSavedState() async {
    String? savedCheckInTime = userPreferences.getCheckInTime();
    String? savedCheckOutTime = userPreferences.getCheckOutTime();
    Duration? savedWorkingHours = userPreferences.getWorkingHours();

    setState(() {
      _checkInTime = savedCheckInTime ?? '--:--:--';
      _checkInDateTime = savedCheckInTime != null
          ? DateFormat('HH:mm:ss').parse(savedCheckInTime)
          : null;
      _checkOutTime = savedCheckOutTime ?? '--:--:--'; // Restore checkout time
      _isCheckInActive = savedCheckInTime != null && savedCheckOutTime == null;
// Check if checkout is available
      _workingHours = savedWorkingHours ?? Duration.zero;
    });

    if (_isCheckInActive) {
      _startTimerForWorkingHours();
    }
  }

  @override
  void dispose() {
    _workingHoursTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Performs the check-in operation.
  Future<void> _performCheckIn(DateTime now) async {
    setState(() {
      _checkInTime = DateFormat('HH:mm:ss').format(now);
      _checkOutTime = '--:--:--';
      _checkInDateTime = now;
      _checkOutDateTime = null;
      _workingHours = Duration.zero;
      _isCheckInActive = true;
    });

    // Store check-in time locally
    userPreferences.storeCheckInTime(_checkInTime); // Save the new check-in time
    userPreferences.storeCheckOutTime(_checkOutTime); // Reset stored check-out time to --:--:--

    // Create AttendanceRecord
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '',
      longitude: '',
      section: _isOffsite ? 'Offsite' : 'Office',
      type: 'checkIn',
      timestamp: now,
    );

    // Get current position
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();
    }

    // Check connectivity
    await connectivityResult.checkConnectivity().then((e) async {
      if (e.contains(ConnectivityResult.none)) {
        await offlineProvider.addPendingAttendance(record);
        await offlineProvider.autoOffline(true);
        print('No internet connection. Check-in stored locally.');
      } else {
        try {
          await _sendCheckInOutRequest(record);
          print('Check-in request sent successfully.');
          await _showCheckInNotification(_checkInTime);
        } catch (error) {
          print('Error during Check-in process: $error');
        }
      }
    });

    await _showCheckInNotification(_checkInTime);
  }

  /// Displays a notification upon successful check-in.
  Future<void> _showCheckInNotification(String checkInTime) async {
    if (kDebugMode) {
      print('Attempting to show Check-in notification with time: $checkInTime');
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'attendance_channel_id',
        'Attendance Notifications',
        channelDescription: 'Notifications for check-in/check-out',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        100, // Unique Notification ID for Check-in
        'Check-in Successful', // Title
        'Check-in Time: $checkInTime', // Body
        notificationDetails,
        payload: 'check_in', // Optional payload
      );

      if (kDebugMode) {
        print('Check-in notification displayed successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error displaying Check-in notification: $e');
      }
    }
  }

  /// Performs the check-out operation.
  Future<void> _performCheckOut(DateTime now) async {
    setState(() {
      _checkOutTime = DateFormat('HH:mm:ss').format(now);
      _checkOutDateTime = now;
      if (_checkInDateTime != null) {
        _workingHours = now.difference(_checkInDateTime!); // Calculate working hours
        _isCheckInActive = false;
        _workingHoursTimer?.cancel(); // Stop the working hours timer
      }
    });

    // Store check-out time and working hours locally
    userPreferences.storeCheckOutTime(_checkOutTime); // Save the new check-out time
    userPreferences.storeWorkingHours(_workingHours); // Save the total working hours

    // Create AttendanceRecord
    AttendanceRecord record = AttendanceRecord(
      deviceId: _deviceId,
      latitude: '',
      longitude: '',
      section: _isOffsite ? 'Offsite' : 'Office',
      type: 'checkOut',
      timestamp: now,
    );

    // Get current position
    Position? currentPosition = await _getCurrentPosition();
    if (currentPosition != null) {
      record.latitude = currentPosition.latitude.toString();
      record.longitude = currentPosition.longitude.toString();
    }

    // Check connectivity
    await connectivityResult.checkConnectivity().then((e) async {
      if (e.contains(ConnectivityResult.none)) {
        await offlineProvider.addPendingAttendance(record);
        print('No internet connection. Check-out stored locally.');
      } else {
        try {
          await _sendCheckInOutRequest(record);
          print('Check-out request sent successfully.');
          await _showCheckOutNotification(_checkOutTime, _workingHours);
        } catch (error) {
          print('Error during Check-out process: $error');
        }
      }
    });

    await _showCheckOutNotification(_checkOutTime, _workingHours);
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    String hoursStr = hours.toString().padLeft(2, '0');
    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');
    return '$hoursStr:$minutesStr:$secondsStr';
  }

  String _getCurrentApiUrl() {
    return _isOffsite ? offsiteApiUrl : officeApiUrl;
  }

  /// Displays a notification upon successful check-out.
  Future<void> _showCheckOutNotification(
      String checkOutTime, Duration workingHours) async {
    if (kDebugMode) {
      print(
          'Attempting to show Check-out notification with time: $checkOutTime and working hours: $workingHours');
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'attendance_channel_id',
        'Attendance Notifications',
        channelDescription: 'Notifications for check-in/check-out',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      String workingHoursString = _formatDuration(workingHours);

      await flutterLocalNotificationsPlugin.show(
        101, // Unique Notification ID for Check-out
        'Check-out Successful', // Title
        'Check-out Time: $checkOutTime\nWorking Hours: $workingHoursString', // Body
        notificationDetails,
        payload: 'check_out', // Optional payload
      );

      if (kDebugMode) {
        print('Check-out notification displayed successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error displaying Check-out notification: $e');
      }
    }
  }


  /// Sends check-in or check-out request to the server.
  Future<void> _sendCheckInOutRequest(AttendanceRecord record) async {
    if (sl<OfflineProvider>().isOfflineService.value) return;

    String url = _getCurrentApiUrl();

    String? token = userPreferences.getToken();

    if (token == null) {
      if (mounted) {
        _showCustomDialog(
          context,
          AppLocalizations.of(context)!.error,
          AppLocalizations.of(context)!.noTokenFound,
          isSuccess: false,
        );
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "device_id": record.deviceId,
          "latitude": record.latitude,
          "longitude": record.longitude,
        }),
      );

      if (response.statusCode == 201) {
        jsonDecode(response.body);
        // Optionally handle success response
      } else if (response.statusCode == 202 && url == officeApiUrl) {
        // Show modal indicating check-in is not allowed
        if (mounted) {
          _showCheckInNotAllowedModalLocation();
        }
        return; // Do not proceed further
      } else {
        throw Exception('Failed with status code ${response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        // If sending fails, save to local storage
        await offlineProvider.addPendingAttendance(record);
        if (mounted) {
          _showCustomDialog(
            context,
            AppLocalizations.of(context)!.error,
            '${AppLocalizations.of(context)!.failedToCheckInOut}: $error',
            isSuccess: false,
          );
        }
      }
    }
  }

  /// Fetches weekly attendance records from the server.
  Future<void> _fetchWeeklyRecords() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String endpoint = '$baseUrl/api/attendance/checkin-checkout/offices/weekly/me';

    try {
      String? token = userPreferences.getToken();

      if (token == null) {
        if (mounted) {
          throw Exception(AppLocalizations.of(context)!.noTokenFound);
        }
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final monthlyData = data['TotalWorkDurationForMonth'];

        setState(() {
          _weeklyRecords = (data['weekly'] as List).map((item) {
            return {
              'date': item['check_in_date'].toString(),
              'checkIn': item['check_in_time'].toString(),
              'checkOut': item['check_out_time'].toString(),
              'workingHours': item['workDuration'].toString(),
              'checkInStatus': item['check_in_status']?.toString() ?? 'unknown',
              'checkOutStatus': item['check_out_status']?.toString() ?? 'unknown',
            };
          }).toList();

          // Extract monthly totals
          _totalCheckInDelay = monthlyData['totalCheckInDelay']?.toString() ?? '--:--:--';
          _totalCheckOutDelay = monthlyData['totalCheckOutDelay']?.toString() ?? '--:--:--';
          _totalWorkDuration = monthlyData['totalWorkDuration']?.toString() ?? '--:--:--';
        });
      } else {
        if (mounted) {
          throw Exception(AppLocalizations.of(context)!.failedToLoadWeeklyRecords);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching weekly records: $e');
      }
      // Optionally, show a dialog or snackbar
    }
  }

  /// Displays a modal indicating check-in is not allowed based on location.
  void _showCheckInNotAllowedModalLocation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              border: Border.all(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/attendance.png',
                          width: 40,
                          color: isDarkMode ? const Color(0xFFDBB342) : null,
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          AppLocalizations.of(context)!.checkInNotAllowed,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Message
                        Text(
                          AppLocalizations.of(context)!.checkInNotAllowedMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342), // Gold color for button
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.close,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Starts a timer to update working hours.
  void _startTimerForWorkingHours() {
    _workingHoursTimer?.cancel();
    _workingHoursTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_checkInDateTime != null && _checkOutDateTime == null) {
        setState(() {
          _workingHours = DateTime.now().difference(_checkInDateTime!);
        });

        // Save the working hours in SharedPreferences
        userPreferences.storeWorkingHours(_workingHours);
      }
    });
  }

  /// Authenticates the user and performs check-in or check-out based on the flag.
  Future<void> _authenticateAndProceed(bool isCheckIn) async {
    bool isAuthenticated = await authenticateUser(context);

    if (isAuthenticated) {
      if (isCheckIn) {
        _performCheckIn(DateTime.now());
      } else {
        _performCheckOut(DateTime.now());
      }
    }
  }

  /// Retrieves the current position of the user.
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving location: $e');
      }
      return null;
    }
  }

  /// Builds the main page content with optimized UI rendering.
  Widget _buildPageContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchWeeklyRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Your attendance data has been refreshed successfully",
              style: TextStyle(fontSize: 13, color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            margin: EdgeInsets.all(20),
            duration: Duration(seconds: 3),
          ),
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            HeaderContentWidget(
              isCheckInActive: _isCheckInActive,
              isOffsite: _isOffsite,
              onTap: () async {
                if (!_isCheckInActive) {
                  final now = DateTime.now();
                  final checkInTimeAllowed = DateTime(now.year, now.month, now.day, 0, 0);
                  final checkInDisabledTime = DateTime(now.year, now.month, now.day, 22, 0);

                  if (now.isBefore(checkInTimeAllowed) || now.isAfter(checkInDisabledTime)) {
                    _showCustomDialog(
                      context,
                      AppLocalizations.of(context)!.checkInNotAllowed,
                      AppLocalizations.of(context)!.checkInLateNotAllowed,
                      isSuccess: false,
                    );
                  } else if (isCheckInEnabled()) {
                    await _authenticateAndProceed(true); // Pass 'true' for check-in
                  }
                } else {
                  await _authenticateAndProceed(false); // Pass 'false' for check-out
                }
              },
              checkInTime: _checkInTime,
              checkOutTime: _checkOutTime,
              workingHours: _workingHours,
              totalCheckInDelay: _totalCheckInDelay,
              totalCheckOutDelay: _totalCheckOutDelay,
              totalWorkDuration: _totalWorkDuration,
            ),
            _buildWeeklyRecordsList(),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MonthlyAttendanceReport()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFDBB342) // Dark mode background color (#DBB342)
                      : Colors.green, // Light mode background color (green)
                  elevation: 4,
                ),
                icon: const Icon(Icons.view_agenda, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.viewAll,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  /// Determines if check-in is enabled based on current state and time.
  bool isCheckInEnabled() {
    final now = DateTime.now();
    final checkInTimeAllowed = DateTime(now.year, now.month, now.day, 0, 0);
    final checkInDisabledTime = DateTime(now.year, now.month, now.day, 22, 0);
    return !_isCheckInActive && now.isAfter(checkInTimeAllowed) && now.isBefore(checkInDisabledTime);
  }

  /// Shows a loading indicator overlay.
  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
    );
  }

  /// Builds the list of weekly attendance records.
  Widget _buildWeeklyRecordsList() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_weeklyRecords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          AppLocalizations.of(context)!.noWeeklyRecordsFound,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
            fontSize: 16,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header Row
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.green : const Color(0xFFD5AD32),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.checkIn,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.checkOut,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.workingHours,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Weekly Records List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _weeklyRecords.length,
          itemBuilder: (context, index) {
            return AttendanceRowWidget(record: _weeklyRecords[index]);
          },
        ),
      ],
    );
  }

  /// Displays a custom dialog with given title and message.
  @override
  void _showCustomDialog(BuildContext context, String title, String message, {bool isSuccess = true}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              border: Border.all(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: constraints.maxWidth < 400 ? constraints.maxWidth * 0.9 : 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Attendance icon and text row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/attendance.png',
                              width: 40,
                              color: isDarkMode ? const Color(0xFFDBB342) : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.attendance,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Icon and Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                              color: isSuccess
                                  ? (isDarkMode ? Colors.greenAccent : Colors.green)
                                  : (isDarkMode ? Colors.redAccent : Colors.red),
                              size: constraints.maxWidth < 400 ? 40 : 50,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 18 : 20,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Message
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 400 ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBB342), // Gold color for button
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.close,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 400 ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Builds the section toggle container (Offsite/Office).
  Widget _buildSectionContainer() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Offsite button background color and icon/text colors based on state
    Color offsiteBgColor = _isOffsite
        ? Colors.red
        : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200);

    Color offsiteIconColor = _isOffsite ? Colors.white : Colors.red;
    Color offsiteTextColor = _isOffsite
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: GestureDetector(
          onTap: () async {
            setState(() {
              _isOffsite = !_isOffsite;
            });

            // Show dialog based on the new state
            if (_isOffsite) {
              _showCustomDialog(
                context,
                AppLocalizations.of(context)!.offsiteModeTitle, // e.g., "Offsite Mode"
                AppLocalizations.of(context)!.offsiteModeMessage, // e.g., "You're in offsite attendance mode."
                isSuccess: true,
              );
            } else {
              _showCustomDialog(
                context,
                AppLocalizations.of(context)!.officeModeTitle, // e.g., "Office Mode"
                AppLocalizations.of(context)!.officeModeMessage, // e.g., "You're in office/home attendance mode."
                isSuccess: true,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: offsiteBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/offsite.png',
                  width: 18,
                  height: 18,
                  color: offsiteIconColor,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.offsite, // Ensure this localization key exists
                  style: TextStyle(
                    color: offsiteTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            flexibleSpace: PreferredSize(
              preferredSize: const Size.fromHeight(80.0),
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: Text(
                        AppLocalizations.of(context)!.attendance,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            centerTitle: true,
            toolbarHeight: 100,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: Stack(
            children: [
              _buildPageContent(context),
              if (_isLoading) _buildLoadingIndicator(),
            ],
          ),
        ),
        // Positioned container above the AppBar area
        Positioned(
          top: MediaQuery.of(context).padding.top + 84,
          left: 200,
          right: 0,
          child: Center(
            child: _buildSectionContainer(),
          ),
        ),
      ],
    );
  }
}
