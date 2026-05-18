// lib/screens/edit_customer_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class EditCustomerPage extends StatefulWidget {
  final dynamic customer; 

  const EditCustomerPage({super.key, required this.customer});

  @override
  State<EditCustomerPage> createState() => _EditCustomerPageState();
}

class _EditCustomerPageState extends State<EditCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    final fullName = (widget.customer['full_Name'] ?? widget.customer['Full_Name'] ?? '').toString();
    final nameParts = fullName.split(' ');
    
    String firstName = nameParts.isNotEmpty ? nameParts.first : '';
    String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController = TextEditingController(text: widget.customer['email'] ?? widget.customer['Email'] ?? '');
    _phoneController = TextEditingController(text: widget.customer['phone_Number'] ?? widget.customer['Phone_Number'] ?? '');
    _addressController = TextEditingController(text: widget.customer['address'] ?? widget.customer['Address'] ?? '');
  }

  Future<void> _updateCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final dbId = widget.customer['customer_ID'] ?? widget.customer['Customer_ID'] ?? widget.customer['id'];
    if (dbId == null) {
      _showSnackBar('Error: Customer ID not found.');
      setState(() => _isSaving = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = Uri.parse('${ApiConfig.baseUrl}/customer/$dbId');
      
      // 🔥 Notes alanı payload'dan kaldırıldı
      final Map<String, dynamic> bodyData = {
        'customer_ID': dbId,
        'full_Name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'email': _emailController.text.trim(),
        'phone_Number': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'isDeleted': false,
      };

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Customer updated successfully!', isSuccess: true);
        if (mounted) Navigator.pop(context, true); 
      } else {
        _showSnackBar('Update failed. Error code: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isSuccess ? Colors.green : Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayId = widget.customer['localId'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B2D4F), size: 20),
                        label: const Text('Back', style: TextStyle(color: Color(0xFF1B2D4F), fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      const Text(
                        'STOX',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F), letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(height: 3, width: double.infinity, color: const Color(0xFF1B2D4F)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        'Customer #$displayId',
                        style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Edit Customer',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F)),
                      ),
                      const SizedBox(height: 24),

                      _buildInputField(Icons.person_outline, 'First Name', _firstNameController),
                      _buildInputField(Icons.person_outline, 'Last Name', _lastNameController),
                      _buildInputField(Icons.mail_outline, 'Email', _emailController, isEmail: true),
                      _buildInputField(Icons.phone_outlined, 'Phone Number', _phoneController),
                      _buildInputField(Icons.home_outlined, 'Address', _addressController),
                      
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B2D4F),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00A624), 
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isSaving ? null : _updateCustomer,
                                child: _isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(IconData icon, String label, TextEditingController controller, {int maxLines = 1, bool isEmail = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF1B2D4F), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                TextFormField(
                  controller: controller,
                  maxLines: maxLines,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF1B2D4F), fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '$label cannot be empty';
                    }
                    if (isEmail && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}