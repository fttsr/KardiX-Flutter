import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kardix_flutter/pages/bluetooth_connection.dart';
import 'package:kardix_flutter/pages/home.dart';
import 'package:kardix_flutter/pages/welcome.dart';

void main() async {
  // Гарантия плавной работы (движок готов перед выполнением операций)
  WidgetsFlutterBinding.ensureInitialized();

  // initialize Hive
  await Hive.initFlutter();

  // open the box
  var box = await Hive.openBox('db');

  final userName = box.get("userName");

  runApp(
    MyApp(
      showWelcome:
          userName == null || userName.toString().trim().isEmpty,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showWelcome;
  const MyApp({super.key, required this.showWelcome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Quicksand'),
      home: showWelcome
          ? const WelcomeScreen()
          : const HomeScreen(),
      initialRoute: '/',
      routes: {
        // '/': (context) => WelcomeScreen(),
        '/bluetooth': (context) => BluetoothConnectionScreen(),
        // '/ecg': (context) => EcgScreen(device: device,),
      },
    );
  }
}
