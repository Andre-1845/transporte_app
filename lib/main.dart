import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'core/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/trips/trips_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'core/location_background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // carregar variáveis de ambiente
  await dotenv.load(fileName: ".env");

  // inicializar Firebase
  await Firebase.initializeApp();

  // inicializar serviço de background
  await initializeBackgroundService();

  runApp(const MyApp());
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: "location_service",
      initialNotificationTitle: "Transporte Escolar",
      initialNotificationContent: "Enviando localização do ônibus",
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: null,
    ),
  );
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

  Future<void> checkAuth() async {
    try {
      final auth = AuthService();
      final token = await auth.getToken();

      if (!mounted) return;

      setState(() {
        home = token != null ? const TripsPage() : const LoginPage();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        home = const LoginPage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Transporte Escolar",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: home,
    );
  }
}
