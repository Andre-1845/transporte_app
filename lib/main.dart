import 'package:flutter/material.dart';
import 'core/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/trips/trips_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget home = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  void checkAuth() async {
    final auth = AuthService();
    final token = await auth.getToken();

    setState(() {
      home = token != null ? const TripsPage() : const LoginPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: home);
  }
}
