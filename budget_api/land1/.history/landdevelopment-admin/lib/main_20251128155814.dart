import 'package:admin/screens/login_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AranpaniAdminApp());
}

class AranpaniAdminApp extends StatelessWidget {
  const AranpaniAdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aranpani Admin',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
