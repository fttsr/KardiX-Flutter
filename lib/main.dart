import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kardix_flutter/pages/bluetooth_connection.dart';
import 'package:kardix_flutter/pages/ecg.dart';
import 'package:kardix_flutter/pages/home.dart';
import 'package:kardix_flutter/pages/welcome.dart';



void main() async {
  // Гарантия плавной работы (движок готов перед выполнением операций)
  WidgetsFlutterBinding.ensureInitialized();

  // initialize Hive
  await Hive.initFlutter();

  // open the box
  var box = await Hive.openBox('db');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Quicksand'),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/bluetooth': (context) => BluetoothConnectionScreen(),
        '/ecg': (context) => EcgScreen(),
      },
    );
  }
}
