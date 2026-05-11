import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const String baseUrl = ApiConfig.baseUrl;

  // ─── Register ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String businessName,
    required String businessNumber,
    required String email,
    required String phone,
    required String address,
    required String transit,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'businessName': businessName,
          'businessNumber': businessNumber,
          'email': email,
          'phone': phone,
          'address': address,
          'transit': transit,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['token'], data['refreshToken'], data['role']);
        return {'success': true, 'role': data['role']};
      }

      String message = _parseError(response.body);
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Is the server running?'};
    }
  }

  // ─── Login ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['token'], data['refreshToken'], data['role']);
        return {'success': true, 'role': data['role']};
      }

      String message = _parseError(response.body);
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Is the server running?'};
    }
  }

  // ─── Logout ─────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      await prefs.remove('token');
      await prefs.remove('refreshToken');
      await prefs.remove('role');
    } catch (_) {}
  }

  // ─── Helpers ────────────────────────────────────────────────
  static String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) return data['message'] ?? data.toString();
      return data.toString();
    } catch (_) {
      return body.replaceAll('"', '').trim();
    }
  }

  static Future<void> _saveTokens(String token, String refreshToken, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('refreshToken', refreshToken);
    await prefs.setString('role', role); // ← saves role
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role') ?? 'User';
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}