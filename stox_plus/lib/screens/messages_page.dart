// lib/screens/messages_page.dart
import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2D4F)),
      ),
      body: const Center(child: Text('Mesajlar Çok Yakında!')),
    );
  }
}