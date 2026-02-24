import 'package:flutter/material.dart';
import '../../core/auth_service.dart';
import '../trips/trips_page.dart';
import '../driver/driver_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  void handleLogin() async {
    setState(() => loading = true);

    final auth = AuthService();
    final token = await auth.login(
      emailController.text,
      passwordController.text,
    );

    setState(() => loading = false);

    if (token != null && mounted) {
      final roles = await auth.getRoles();

      if (roles.contains("driver")) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TripsPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login inválido")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Senha"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: handleLogin,
                    child: const Text("Entrar"),
                  ),
          ],
        ),
      ),
    );
  }
}
