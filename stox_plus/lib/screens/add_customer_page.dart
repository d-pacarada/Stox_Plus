// lib/screens/add_customer_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({super.key});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Backend Model ile birebir eşleşen Controller'lar
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = false;

  // Backend'deki POST api/customer endpoint'ine istek atan fonksiyon
  Future<void> _submitCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Girişte saklanan JWT Token

      if (token == null) {
        _showSnackBar('Oturum anahtarı bulunamadı, lütfen tekrar giriş yapın.');
        return;
      }

      // Backend API URL'i (Android Emulator için local adres, gerekirse IP ile değiştir)
      // lib/screens/add_customer_page.dart içindeki ilgili satırı değiştir:
// En üste import eklemeyi unutma: import '../config/api_config.dart';

    final url = Uri.parse('${ApiConfig.baseUrl}/customer');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // [Authorize] filtresini geçmek için
        },
        body: jsonEncode({
          'Full_Name': _fullNameController.text.trim(),
          'Email': _emailController.text.trim(),
          'Phone_Number': _phoneController.text.trim(),
          'Address': _addressController.text.trim(),
          'IsDeleted': false
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('Customer added successfully! 🎉', isSuccess: true);
        
        // Ekleme başarılı olunca bir önceki ekrana (Listeye) true dönerek geri git
        if (mounted) {
          Navigator.pop(context, true); 
        }
      } else {
        final errorMsg = response.body.isNotEmpty ? response.body : 'Bir hata oluştu.';
        _showSnackBar('Hata (${response.statusCode}): $errorMsg');
      }
    } catch (e) {
      _showSnackBar('Sunucuya bağlanılamadı: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "STOX" Başlığı ve Alt Çizgisi
                const Text(
                  'STOX',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F),
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  height: 3,
                  width: double.infinity,
                  color: const Color(0xFF1B2D4F),
                ),
                const SizedBox(height: 32),

                // "Add New Customer"
                const Center(
                  child: Text(
                    'Add New Customer',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2D4F),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Form Giriş Alanları
                _buildInputField('Full name', _fullNameController, 'Please enter full name'),
                const SizedBox(height: 18),
                _buildInputField('Email', _emailController, 'Please enter email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 18),
                _buildInputField('Phone Number', _phoneController, 'Please enter phone number', keyboardType: TextInputType.phone, hintText: '044 111 111'),
                const SizedBox(height: 18),
                _buildInputField('Address', _addressController, 'Please enter address', hintText: 'Bardhosh'),
                const SizedBox(height: 36),

                // Butonlar Bölümü (Back & Add)
                Row(
                  children: [
                    // BACK BUTONU
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B2D4F),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.4),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    
                    // ADD BUTONU
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00AA13), // Resimdeki yeşil tonu
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.4),
                          ),
                          onPressed: _isLoading ? null : _submitCustomer,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Add', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String errorText, {TextInputType keyboardType = TextInputType.text, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B2D4F))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Color(0xFF1B2D4F), fontSize: 15),
            decoration: InputDecoration(
              hintText: hintText ?? label,
              hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1B2D4F), width: 1.5)),
              fillColor: Colors.white,
              filled: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty ? errorText : null,
          ),
        ),
      ],
    );
  }
}