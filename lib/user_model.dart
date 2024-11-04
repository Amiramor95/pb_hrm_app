import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/services/services_locator.dart';

// User Model
class User {
  String id;
  String name;
  List<String> roles;

  User({required this.id, required this.name, required this.roles});

  bool hasRole(String role) {
    return roles.contains(role);
  }
}

// User Provider that includes token management and API interaction
class UserProvider extends ChangeNotifier {
  User _currentUser = User(id: '1', name: 'Default User', roles: ['User']);
  bool _isLoggedIn = false;
  String _token = '';
  DateTime? _loginTime;

  User get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String get token => _token;

  UserProvider() {
    loadUser();
  }

  // Public method to load user login status and token from shared preferences
  Future<void> loadUser() async {
    _isLoggedIn = sl<UserPreferences>().getLoggedIn() ?? false;
    _token = sl<UserPreferences>().getToken() ?? '';
    _loginTime = DateTime.tryParse(sl<UserPreferences>().getLoginSession() ?? '');
    notifyListeners();
  }

  bool get isSessionValid {
    if (_loginTime == null) return false;
    return DateTime.now().difference(_loginTime!).inHours < 8;
  }

  Future<void> setLoginTime() async {
    _loginTime = DateTime.now();
    sl<UserPreferences>().setLoginSession(_loginTime.toString());
    notifyListeners();
  }

  // Update the current user and notify listeners
  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  // Fetch user data from API and update current user
  Future<void> fetchAndUpdateUser() async {
    final String? token = sl<UserPreferences>().getToken();

    if (token == null) {
      debugPrint('No token found');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/display/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson = jsonDecode(response.body)['results'][0];

        List<String> roles = (userJson['roles'] as String).split(',');

        User loggedInUser = User(
          id: userJson['id'],
          name: userJson['employee_name'],
          roles: roles,
        );

        updateUser(loggedInUser);
      } else {
        print('Failed to fetch user data. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while fetching user data: $e');
    }
  }

  // Log in the user, save token and notify listeners
  Future<void> login(String token) async {
    _isLoggedIn = true;
    _token = token;
    sl<UserPreferences>().setLoggedIn(true);
    sl<UserPreferences>().setToken(token);
    await setLoginTime(); // Save login time immediately after login
    notifyListeners();
  }

  // Log out the user, clear token and notify listeners
  Future<void> logout() async {
    _isLoggedIn = false;
    _token = '';
    _loginTime = null;

    await sl<UserPreferences>().setLoggedOff();
    await sl<UserPreferences>().removeToken();
    await sl<UserPreferences>().removeLoginSession();

    notifyListeners(); // Notify listeners to refresh UI based on the new state
  }
}
