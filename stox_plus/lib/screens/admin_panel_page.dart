// lib/screens/admin_panel_page.dart
import 'package:flutter/material.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // Diğer sayfalarla aynı arka plan
      appBar: AppBar(
        title: const Text(
          'Admin Panel', 
          style: TextStyle(color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2D4F)),
      ),
      body: const Center(
        child: Text(
          'Admin Panel Sayfası Hazır!', 
          style: TextStyle(fontSize: 18, color: Color(0xFF1B2D4F)),
        ),
      ),
    );
  }
}