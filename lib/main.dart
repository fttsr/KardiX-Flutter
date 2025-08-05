import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kardix/pages/home.dart';
import 'package:kardix/pages/welcome.dart';

void main() async {
  // Гарантия плавной работы (движок готов перед выполнением операций)
  WidgetsFlutterBinding.ensureInitialized();

  // initialize Hive
  await Hive.initFlutter();

  // open the box
  var box = await Hive.openBox('db');

  runApp(MyApp());

  //123
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Quicksand'),
      initialRoute: '/',
      routes: {'/': (context) => WelcomeScreen()},
    );
  }
}
