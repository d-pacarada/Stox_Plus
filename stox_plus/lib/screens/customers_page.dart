// customers_page.dart
import 'package:flutter/material.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        backgroundColor: const Color(0xFF1B2D4F),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Müşteriler Listesi Burada Olacak', style: TextStyle(fontSize: 20))),
    );
  }
}