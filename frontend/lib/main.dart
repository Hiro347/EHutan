import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Hutan',
      theme: ThemeData(
        primaryColor: const Color(0xFF609008), 
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Koneksi Supabase via .env Berhasil! 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}