import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.model.dart';

class ApiService {
  // 🟢 កំណត់ IP របស់ Laravel backend (កែសម្រួលតាម IP ម៉ាស៊ីនរបស់អ្នក)
  static const String baseUrl = "http://192.168.100.11:8000";

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ptt_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ១. ឡុកអ៊ិន (Login)
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': 'MobileApp',
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ptt_token', data['token']);
      await prefs.setString('ptt_username', data['user']['name']);
      await prefs.setString('ptt_email', data['user']['email']);
      await prefs.setString('ptt_role', data['user']['role'] ?? 'user');
      await prefs.setString('ptt_avatar', data['user']['avatar'] ?? '');
      return {'success': true, 'user': User.fromJson(data['user'])};
    }
    return {'success': false, 'message': data['message'] ?? 'ឡុកអ៊ិនបរាជ័យ'};
  }

  // ២. កែប្រែព័ត៌មានផ្ទាល់ខ្លួន (Update Profile)
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? password,
    String? avatar,
  }) async {
    final headers = await _getHeaders();
    final body = {
      'name': name,
      'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
      if (avatar != null) 'avatar': avatar,
    };

    final response = await http.put(
      Uri.parse('$baseUrl/api/profile'),
      headers: headers,
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ptt_username', data['user']['name']);
      await prefs.setString('ptt_email', data['user']['email']);
      await prefs.setString('ptt_avatar', data['user']['avatar'] ?? '');
      return {'success': true, 'user': User.fromJson(data['user'])};
    }
    return {'success': false, 'message': data['message'] ?? 'កែប្រែព័ត៌មានបរាជ័យ'};
  }

  // ៣. ទាញយកក្រុមរបស់ខ្ញុំ (My Groups)
  static Future<List<Group>> getMyGroups() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/my-groups'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((g) => Group.fromJson(g)).toList();
    }
    return [];
  }

  // ៤. [Admin] ទាញយកបញ្ជីអ្នកប្រើប្រាស់ទាំងអស់ (List Users)
  static Future<List<User>> getAllUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((u) => User.fromJson(u)).toList();
    }
    return [];
  }

  // ៤b. ទាញយកសមាជិកក្នុងក្រុមមួយ (Group Members by ID)
  static Future<List<User>> getGroupMembers(int groupId) async {
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/groups/$groupId/members'),
        headers: headers,
      );

      debugPrint('[API] getGroupMembers($groupId) status=${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // Backend now returns a plain array
        if (decoded is List) {
          return decoded.map((u) => User.fromJson(u)).toList();
        } else {
          debugPrint('[API] getGroupMembers unexpected format: ${response.body}');
          return [];
        }
      } else {
        debugPrint('[API] getGroupMembers error: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e, st) {
      debugPrint('[API] getGroupMembers exception: $e\n$st');
      return [];
    }
  }

  // ៥. [Admin] ទាញយកក្រុមទាំងអស់ដែលមានក្នុងប្រព័ន្ធ
  static Future<List<Group>> getAllGroups() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/all-groups'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((g) => Group.fromJson(g)).toList();
    }
    return [];
  }

  // ៦. [Admin] បង្កើតអ្នកប្រើប្រាស់ថ្មី (Create User)
  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users'),
      headers: headers,
      body: jsonEncode(userData),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return {'success': true, 'user': User.fromJson(data['user'])};
    }
    return {'success': false, 'message': data['message'] ?? 'បង្កើតអ្នកប្រើប្រាស់បរាជ័យ'};
  }

  // ៧. [Admin] កែប្រែអ្នកប្រើប្រាស់ (Update User)
  static Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> userData) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/users/$id'),
      headers: headers,
      body: jsonEncode(userData),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return {'success': true, 'user': User.fromJson(data['user'])};
    }
    return {'success': false, 'message': data['message'] ?? 'កែប្រែអ្នកប្រើប្រាស់បរាជ័យ'};
  }

  // ៨. [Admin] លុបអ្នកប្រើប្រាស់ (Delete User)
  static Future<Map<String, dynamic>> deleteUser(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/users/$id'),
      headers: headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return {'success': true, 'message': data['message']};
    }
    return {'success': false, 'message': data['message'] ?? 'លុបអ្នកប្រើប្រាស់បរាជ័យ'};
  }
}
