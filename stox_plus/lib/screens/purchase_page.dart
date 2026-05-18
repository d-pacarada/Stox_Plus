// lib/screens/purchase_page.dart
import 'package:flutter/material.dart';

class PurchasePage extends StatelessWidget {
  const PurchasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FD),
      appBar: AppBar(
        title: const Text('Purchase', style: TextStyle(color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2D4F)),
      ),
      body: const Center(
        child: Text('Purchase Sayfası Hazır!', style: TextStyle(fontSize: 18, color: Color(0xFF1B2D4F))),
      ),
    );
  }
}