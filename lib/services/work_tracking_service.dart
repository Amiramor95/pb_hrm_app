import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WorkTrackingService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  // Helper to get the headers with the auth token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (kDebugMode) {
      debugPrint('Retrieved Token: $token');
    } // Debug line

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch a list of user's projects
  Future<List<Map<String, dynamic>>> fetchMyProjects() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/work-tracking/proj/find-My-Project-list'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['result'] != null && body['result'] is List) {
        return (body['result'] as List)
            .map((item) => {
                  'project_id': item['project_id'],
                  'p_name': item['p_name'],
                  's_name': item['s_name'],
                  'precent': item['precent'],
                  'dl': item['dl'],
                  'extend': item['extend'],
                  'create_project_by': item['create_project_by'],
                  'd_name': item['d_name'],
                  'b_name': item['b_name'],
                  'created_project_at': item['created_project_at'],
                })
            .toList();
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load projects');
    }
  }

  // Fetch the latest project for the current user
  Future<Map<String, dynamic>?> fetchLatestProject() async {
    final projects = await fetchMyProjects();
    if (projects.isNotEmpty) {
      return projects.first;
    }
    return null;
  }

  /// Fetch all available projects.
  Future<List<Map<String, dynamic>>> fetchAllProjects() async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/work-tracking/proj/projects';
    if (kDebugMode) {
      debugPrint('Fetching All Projects from: $url');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      if (kDebugMode) {
        debugPrint('Response Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        var body = json.decode(response.body);
        if (body['result'] != null && body['result'] is List) {
          List<Map<String, dynamic>> projects =
              List<Map<String, dynamic>>.from(body['result']);
          if (kDebugMode) {
            debugPrint('Fetched ${projects.length} all projects.');
          }
          return projects;
        } else {
          if (kDebugMode) {
            debugPrint('Unexpected response format for fetchAllProjects.');
          }
          return []; // Return an empty list if the response format is unexpected
        }
      } else {
        if (kDebugMode) {
          debugPrint('Failed to fetch all projects: ${response.reasonPhrase}');
        }
        return []; // Return an empty list on HTTP error
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in fetchAllProjects: $e');
      }
      return []; // Return an empty list on any exception
    }
  }

  /// Add a new project.
  Future<String?> addProject(Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/work-tracking/proj/insert';
    if (kDebugMode) {
      debugPrint('Adding Project to: $url');
      debugPrint('Project Data: ${jsonEncode(projectData)}');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(projectData),
      );

      if (kDebugMode) {
        debugPrint('Response Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody != null && responseBody['id'] != null) {
          final String projectId = responseBody['id'];
          if (kDebugMode) {
            debugPrint('Project successfully created with ID: $projectId');
          }
          return projectId;
        } else {
          if (kDebugMode) {
            debugPrint('Project created but no project_id in response.');
          }
          return null;
        }
      } else {
        throw Exception('Failed to add project: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in addProject: $e');
      }
      rethrow;
    }
  }

  /// Update a project by its ID.
  Future<http.Response> updateProject(
      String projectId, Map<String, dynamic> projectData) async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/work-tracking/proj/update/$projectId';
    if (kDebugMode) {
      debugPrint('Updating Project at: $url');
      debugPrint('Update Data: ${jsonEncode(projectData)}');
    }

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(projectData),
      );

      if (kDebugMode) {
        debugPrint('Response Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          debugPrint('Project successfully updated.');
        }
      } else {
        throw Exception('Failed to update project: ${response.reasonPhrase}');
      }

      return response; // Return the actual response
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in updateProject: $e');
      }
      rethrow;
    }
  }

  /// Delete a project by its ID.
  Future<bool> deleteProject(String projectId) async {
    final headers = await _getHeaders();
    final url = '$baseUrl/api/work-tracking/proj/delete';
    if (kDebugMode) {
      debugPrint('Deleting Project at: $url');
      debugPrint('Project ID to Delete: $projectId');
    }

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          "projectIDs": [
            {"projectID": projectId}
          ]
        }),
      );

      if (kDebugMode) {
        debugPrint('Response Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          debugPrint('Project successfully deleted.');
        }
        return true;
      } else {
        throw Exception('Failed to delete project: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in deleteProject: $e');
      }
      rethrow;
    }
  }

  /// Fetch project members by project ID.
  Future<List<Map<String, dynamic>>> fetchMembersByProjectId(
      String projectId) async {
    final headers = await _getHeaders();
    final url =
        '$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId';
    if (kDebugMode) {
      debugPrint('Fetching Members for Project ID: $projectId from: $url');
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (kDebugMode) {
        debugPrint('Response Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        var body = json.decode(response.body);
        if (body['results'] != null && body['results'] is List) {
          List<Map<String, dynamic>> members =
              List<Map<String, dynamic>>.from(body['results']);
          if (kDebugMode) {
            debugPrint(
                'Fetched ${members.length} members for Project ID: $projectId');
          }
          return members;
        } else {
          throw Exception(
              'Unexpected response format for fetchMembersByProjectId.');
        }
      } else {
        throw Exception(
            'Failed to fetch project members: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in fetchMembersByProjectId: $e');
      }
      rethrow;
    }
  }

  Future<String?> addProcessing(Map<String, dynamic> processingData) async {
    final headers = await _getHeaders();

    // Prepare the request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/work-tracking/meeting/insert'),
    );
    request.headers.addAll(headers);

    // Add fields to the request
    processingData.forEach((key, value) {
      if (value != null && value is! List<File>) {
        request.fields[key] = value.toString();
      }
    });

    // Add files to the request
    if (processingData['file_name'] != null &&
        processingData['file_name'] is List<File>) {
      for (var file in processingData['file_name']) {
        request.files
            .add(await http.MultipartFile.fromPath('file_name', file.path));
      }
    }

    // Send the request
    var response = await request.send();

    if (response.statusCode == 200 || response.statusCode == 201) {
      var responseBody = await response.stream.bytesToString();
      var decodedResponse = jsonDecode(responseBody);
      return decodedResponse['meeting_id'];
    } else {
      throw Exception('Failed to add processing: ${response.reasonPhrase}');
    }
  }

  // Fetch chat messages for a project
  Future<List<Map<String, dynamic>>> fetchChatMessages(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/project-comments/comments?project_id=$projectId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return List<Map<String, dynamic>>.from(
            body['results'].where((item) => item['project_id'] == projectId));
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load chat messages');
    }
  }

  // Send a chat message to a project
  Future<void> sendChatMessage(String projectId, String message,
      {String? filePath, String? fileType}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/project-comments/insert'),
      headers: headers,
      body: jsonEncode({
        'project_id': projectId,
        'comments': message,
        'file_path': filePath,
        'file_type': fileType,
      }),
    );

    if (response.statusCode == 201) {
      if (kDebugMode) {
        debugPrint('Message sent successfully.');
      }
    } else {
      throw Exception(
          'Failed to send chat message: ${response.reasonPhrase}. Details: ${response.body}');
    }
  }

// Add a person to a project
  Future<void> addPeopleToProject(
      String projectId, List<Map<String, String>> employees) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
      headers: headers,
      body: jsonEncode({
        'project_id': projectId,
        'employees_member': employees,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to add people to project: ${response.reasonPhrase}. Details: ${response.body}');
    }
  }

  // Fetch assignments by project ID
  Future<List<Map<String, dynamic>>> fetchAssignments(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/ass/assignments?proj_id=$projectId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return List<Map<String, dynamic>>.from(body['results']);
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to load assignments');
    }
  }

  /// Add a new assignment to a project with file uploads
  Future<String?> addAssignment(
    String baseUrl,
    Map<String, dynamic> assignmentData,
    List<File> files,
  ) async {
    try {
      var uri = Uri.parse('$baseUrl/api/work-tracking/ass/insert');
      var request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add form fields
      request.fields['project_id'] = assignmentData['project_id'];
      request.fields['status_id'] = assignmentData['status_id'];
      request.fields['title'] = assignmentData['title'];
      request.fields['descriptions'] = assignmentData['descriptions'];
      request.fields['memberDetails'] = assignmentData['memberDetails'];

      // Add files
      for (var file in files) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file_name',
            file.path,
            filename: file.path.split('/').last,
          ),
        );
      }

      // Send the request
      var streamedResponse = await request.send();

      // Parse the response
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // The API returns 'id' as 'as_id'
        return data['id'];
      } else {
        throw Exception('Failed to add assignment: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exception in addAssignment: $e');
      }
      throw Exception('Failed to add assignment: $e');
    }
  }

  // Update an assignment
  Future<void> updateAssignment(
      String asId, Map<String, dynamic> taskData) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/ass/update/$asId'),
      headers: headers,
      body: jsonEncode(taskData),
    );

    if (response.statusCode == 200) {
      if (kDebugMode) {
        debugPrint('Assignment successfully updated.');
      }
    } else {
      if (kDebugMode) {
        debugPrint(
            'Failed to update assignment: ${response.statusCode} ${response.reasonPhrase}. Details: ${response.body}');
      }
      throw Exception(
          'Failed to update assignment: ${response.reasonPhrase}. Details: ${response.body}');
    }
  }

  // Delete an assignment
  Future<void> deleteAssignment(String asId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete/$asId'),
      headers: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (kDebugMode) {
        debugPrint('Assignment successfully deleted.');
      }
    } else if (response.statusCode == 404) {
      if (kDebugMode) {
        debugPrint('Assignment not found: $asId');
      }
      throw Exception('Assignment not found.');
    } else {
      throw Exception(
          'Failed to delete assignment: ${response.reasonPhrase}. Details: ${response.body}');
    }
  }

  /// Upload files to an existing assignment
  Future<bool> addFilesToAssignment(
    String baseUrl,
    String assignmentId,
    List<File> files,
  ) async {
    try {
      var uri =
          Uri.parse('$baseUrl/api/work-tracking/ass/add-files/$assignmentId');
      var request = http.MultipartRequest('PUT', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add files
      for (var file in files) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file_name',
            file.path,
            filename: file.path.split('/').last,
          ),
        );
      }

      // Send the request
      var streamedResponse = await request.send();

      // Parse the response
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to upload files: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exception in addFilesToAssignment: $e');
      }
      throw Exception('Failed to upload files: $e');
    }
  }

  // Delete a file from an assignment
  Future<void> deleteFileFromAssignment(String asId, String fileName) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/work-tracking/ass/delete-file/$asId'),
      headers: headers,
      body: jsonEncode({
        "file_name": fileName,
      }),
    );

    if (response.statusCode == 200) {
      if (kDebugMode) {
        debugPrint('File deleted successfully.');
      }
    } else {
      throw Exception(
          'Failed to delete file from assignment: ${response.reasonPhrase}. Details: ${response.body}');
    }
  }

  // Get a list of all employees (for member selection)
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    // Step 1: Retrieve headers (including the authorization token)
    final headers = await _getHeaders();

    // Step 2: Retrieve the current user's employee_id from SharedPreferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentUserEmployeeId = prefs.getString('employee_id');

    // Check if currentUserEmployeeId is available
    if (currentUserEmployeeId == null || currentUserEmployeeId.isEmpty) {
      throw Exception('Current user employee_id not found.');
    }

    // Step 3: Make the API request to fetch all employees
    final response = await http.get(
      Uri.parse('$baseUrl/api/work-tracking/project-member/get-all-employees'),
      headers: headers,
    );

    // Step 4: Handle the API response
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        // Convert the results to a List of Map<String, dynamic>
        List<Map<String, dynamic>> allEmployees =
            List<Map<String, dynamic>>.from(body['results']);

        // Step 5: Filter out the current user from the list
        List<Map<String, dynamic>> filteredEmployees =
            allEmployees.where((employee) {
          return employee['employee_id'] != currentUserEmployeeId;
        }).toList();

        return filteredEmployees;
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to fetch employees: ${response.reasonPhrase}');
    }
  }

  // Fetch members for a specific project
  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/proj/find-Member-By-ProjectId/$projectId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return List<Map<String, dynamic>>.from(body['results']);
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception(
          'Failed to load project members');
    }
  }

  // Fetch assignment members
  Future<List<Map<String, dynamic>>> fetchAssignmentMembers(String asId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/work-tracking/assignment-members/assignment-members?as_id=$asId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['results'] != null && body['results'] is List) {
        return (body['results'] as List)
            .map((item) => {
                  'id': item['member_id'],
                  'name': item['name'],
                  'surname': item['surname'],
                  'email': item['email'],
                  'isSelected': false,
                })
            .toList();
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception(
          'Failed to load assignment members');
    }
  }

  // Add members to an assignment
  Future<void> addMembersToAssignment(
      String asId, List<Map<String, dynamic>> members) async {
    try {
      // Get the authorization headers (you might need to implement _getHeaders)
      final headers = await _getHeaders();

      // Prepare the member data to be sent to the server
      final memberData = {
        "as_id": asId,
        "members": members
            .map((member) => {"employee_id": member['employee_id']})
            .toList(),
      };

      // Make the API call to add members to the assignment
      final response = await http.post(
        Uri.parse('$baseUrl/api/work-tracking/ass/add-members/$asId'),
        headers: headers,
        body: jsonEncode(memberData),
      );

      // Handle the response
      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('Members successfully added to the assignment.');
      } else {
        throw Exception(
            'Failed to add members to the assignment: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('Error adding members to assignment: $e');
      throw Exception('Failed to add members to the assignment');
    }
  }

  Future<void> addMembersToProject(
      String projectId, List<Map<String, dynamic>> members) async {
    final headers = await _getHeaders();

    final memberData = {
      "project_id": projectId,
      "employees_member": members.map((member) {
        return {
          "employee_id": member['employee_id'],
          "member_status": member['member_status'],
        };
      }).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/work-tracking/project-member/insert'),
        headers: headers,
        body: jsonEncode(memberData),
      );

      // Log the response for debugging purposes
      if (kDebugMode) {
        debugPrint('API Response Status Code: ${response.statusCode}');
        debugPrint('API Response Body: ${response.body}');
      }

      // Handle 201 (Created), 200 (OK), and 202 (Accepted) as success
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 202) {
        if (kDebugMode) {
          debugPrint('Members successfully added to the project.');
        }
      } else {
        // If status code is not 2xx, log error details and throw an exception
        String errorMessage =
            'Failed to add members to the project: Status Code ${response.statusCode}, ${response.reasonPhrase}';
        if (kDebugMode) {
          debugPrint('Error Response: ${response.body}');
        }
        throw Exception(errorMessage);
      }
    } catch (error) {
      // Log the error and throw it again so the calling function can handle it
      if (kDebugMode) {
        debugPrint('An error occurred while adding members: $error');
      }
      throw Exception('An error occurred: $error');
    }
  }
}
