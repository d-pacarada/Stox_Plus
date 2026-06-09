// lib/screens/settings_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../widgets/user_navbar.dart';
import '../widgets/admin_navbar.dart';
import 'products_page.dart';
import 'sales_page.dart';
import 'customers_page.dart';
import 'purchase_page.dart';
import 'incomes_page.dart';
import 'contact_page.dart';
import 'users_page.dart';
import 'messages_page.dart';
import 'admin_panel_page.dart';
import 'login_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Password form
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSavingPassword = false;

  // Details form
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _transitController = TextEditingController();
  bool _isSavingDetails = false;

  String _role = 'User';
  bool get isAdmin => _role == 'Admin';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getString('role') ?? 'User';
    if (mounted) setState(() => _role = r);
  }

  // -------------------------------------------------------------
  // Update Password
  // -------------------------------------------------------------
  Future<void> _submitPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _isSavingPassword = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('Session expired. Please login again.');
        return;
      }

      final url =
          Uri.parse('${ApiConfig.baseUrl}/settings/update-password');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'CurrentPassword': _currentPasswordController.text,
          'NewPassword': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Password updated successfully ✅', isSuccess: true);
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else if (response.statusCode == 400) {
        _showSnackBar(response.body.isNotEmpty
            ? response.body
            : 'Current password is incorrect.');
      } else if (response.statusCode == 404) {
        _showSnackBar('User not found.');
      } else {
        _showSnackBar('Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Connection error: $e');
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  // -------------------------------------------------------------
  // Update Details
  // -------------------------------------------------------------
  Future<void> _submitDetails() async {
    if (_addressController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty &&
        _transitController.text.trim().isEmpty) {
      _showSnackBar('Please fill at least one field to update.');
      return;
    }

    setState(() => _isSavingDetails = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('Session expired. Please login again.');
        return;
      }

      final url =
          Uri.parse('${ApiConfig.baseUrl}/settings/update-details');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'Address': _addressController.text.trim(),
          'PhoneNumber': _phoneController.text.trim(),
          'TransitNumber': _transitController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Details updated successfully ✅', isSuccess: true);
        _addressController.clear();
        _phoneController.clear();
        _transitController.clear();
      } else if (response.statusCode == 404) {
        _showSnackBar('User not found.');
      } else {
        _showSnackBar('Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Connection error: $e');
    } finally {
      if (mounted) setState(() => _isSavingDetails = false);
    }
  }

  // -------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------
  void _handleNavTap(int index) {
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProductsPage(role: _role)),
      );
      return;
    }
    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SalesPage(role: 'User'))
      );
      return;
    }
    if (index == 3) {
      _showMoreDrawer();
    }
  }

  void _onCameraPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera scanner coming soon!')));
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
      ),
    );
  }

  // -------------------------------------------------------------
  // MORE DRAWER
  // -------------------------------------------------------------
  void _showMoreDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => isAdmin ? _adminMoreSheet() : _userMoreSheet(),
    );
  }

  Widget _userMoreSheet() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          const SizedBox(height: 24),
          const Text('User',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2D4F))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.people_alt_outlined, 'Customers', () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CustomersPage(role: _role)),
                );
              }),
              _moreItem(Icons.add_box_outlined, 'Purchase', () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PurchasePage(role: _role)));
              }),
              _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => IncomesPage(role: _role)));
              }),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ContactPage()));
              }),
              _moreItem(Icons.settings_outlined, 'Settings', () {
                Navigator.pop(context); // zaten Settings'teyiz
              }),
              _moreItem(Icons.logout_rounded, 'Logout', _logout),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _adminMoreSheet() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          const SizedBox(height: 16),
          const Text(
            'Admin',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2D4F),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _moreItem(Icons.admin_panel_settings_outlined, 'Admin Panel',
                    () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPanelPage()));
                }),
                _moreItem(Icons.people_alt_outlined, 'Customers', () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CustomersPage(role: _role)),
                  );
                }),
                _moreItem(Icons.supervised_user_circle_outlined, 'Users',
                    () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UsersPage()));
                }),
                _moreItem(Icons.chat_bubble_outline_rounded, 'Messages',
                    () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MessagesPage()));
                }),
                _moreItem(Icons.add_box_outlined, 'Purchase', () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PurchasePage(role: _role)));
                }),
                _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => IncomesPage(role: _role)));
                }),
                _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ContactPage()));
                }),
                _moreItem(Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context); // zaten Settings'teyiz
                }),
                _moreItem(Icons.logout_rounded, 'Logout', _logout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _moreItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1B2D4F), size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1B2D4F),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('role');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _transitController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STOX Header
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
                  color: const Color(0xFF1B2D4F)),

              const SizedBox(height: 32),

              // CHANGE PASSWORD
              const Center(
                child: Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Current password'),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _currentPasswordController,
                      hintText: 'password',
                      obscureText: true,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your current password'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _buildLabel('New password'),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _newPasswordController,
                      hintText: 'password',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        if (v == _currentPasswordController.text) {
                          return 'New password must differ from current';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildLabel('Confirm password'),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _confirmPasswordController,
                      hintText: 'password',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (v != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00AA13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.4),
                        ),
                        onPressed:
                            _isSavingPassword ? null : _submitPassword,
                        child: _isSavingPassword
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5)
                            : const Text(
                                'Save',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              Container(height: 1, color: const Color(0xFFE8EDF2)),
              const SizedBox(height: 32),

              // UPDATE DETAILS
              const Center(
                child: Text(
                  'Update Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Leave fields empty if you don\'t want to change them',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel('Address'),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _addressController,
                hintText: 'New address (optional)',
              ),
              const SizedBox(height: 18),
              _buildLabel('Phone Number'),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _phoneController,
                hintText: 'New phone number (optional)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              _buildLabel('Transit Number'),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _transitController,
                hintText: 'New transit number (optional)',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.4),
                  ),
                  onPressed: _isSavingDetails ? null : _submitDetails,
                  child: _isSavingDetails
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)
                      : const Text(
                          'Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isAdmin
          ? AdminNavBar(
              currentIndex: 3,
              onTap: _handleNavTap,
              onCameraPressed: _onCameraPressed,
            )
          : UserNavBar(
              currentIndex: 3,
              onTap: _handleNavTap,
              onCameraPressed: _onCameraPressed,
            ),
    );
  }

  // -------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1B2D4F),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF1B2D4F), fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF1B2D4F), width: 1.5)),
          fillColor: Colors.white,
          filled: true,
        ),
        validator: validator,
      ),
    );
  }
}