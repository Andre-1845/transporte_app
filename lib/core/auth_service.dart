import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://192.168.0.6:8000/api/v1",
      headers: {"Accept": "application/json"},
    ),
  );

  Future<String?> login(String email, String password) async {
    try {
      final response = await dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      final token = response.data['token'];
      final roles = List<String>.from(response.data['user']['roles']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setStringList('roles', roles);

      return token;
    } catch (e) {
      print("Erro no login: $e");
      return null;
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<String>> getRoles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('roles') ?? [];
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
