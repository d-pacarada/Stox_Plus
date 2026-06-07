import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/user_navbar.dart';
import '../widgets/admin_navbar.dart';
import '../config/api_config.dart';
import 'login_screen.dart';
import 'customers_page.dart';
import 'products_page.dart';
import 'sales_page.dart';
import 'purchase_page.dart';
import 'incomes_page.dart';
import 'contact_page.dart';
import 'settings_page.dart';
import 'users_page.dart';
import 'messages_page.dart';
import 'admin_panel_page.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  const HomeScreen({super.key, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool get isAdmin => widget.role == 'Admin';

  // Missing info alert
  bool _hasMissingInfo = false;
  bool _alertDismissed = false;

  // Complete profile form controllers
  final _businessNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _transitController = TextEditingController();
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _checkMissingInfo();
  }

  @override
  void dispose() {
    _businessNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _transitController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // Check if user has missing info
  // -------------------------------------------------------------
  Future<void> _checkMissingInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/settings/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool missing =
            (data['business_Number'] == null || data['business_Number'].toString().isEmpty) ||
            (data['phone_Number'] == null || data['phone_Number'].toString().isEmpty) ||
            (data['address'] == null || data['address'].toString().isEmpty) ||
            (data['transit_Number'] == null || data['transit_Number'].toString().isEmpty);

        if (mounted) setState(() => _hasMissingInfo = missing);
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // Save missing info
  // -------------------------------------------------------------
  Future<void> _saveMissingInfo() async {
    if (_businessNumberController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty &&
        _addressController.text.trim().isEmpty &&
        _transitController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in at least one field.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/settings/update-details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'BusinessNumber': _businessNumberController.text.trim(),
          'PhoneNumber': _phoneController.text.trim(),
          'Address': _addressController.text.trim(),
          'TransitNumber': _transitController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pop(context); // close dialog
        setState(() {
          _hasMissingInfo = false;
          _alertDismissed = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed successfully ✅'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  // -------------------------------------------------------------
  // Show complete profile popup
  // -------------------------------------------------------------
  void _showCompleteProfileDialog() {
    _businessNumberController.clear();
    _phoneController.clear();
    _addressController.clear();
    _transitController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete Your Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2D4F),
                              ),
                            ),
                            Text(
                              'Some information is missing',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9BA5B4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF9BA5B4)),
                        onPressed: () {
                          setState(() => _alertDismissed = true);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE8EDF2)),
                  const SizedBox(height: 16),

                  // Business Number
                  _dialogLabel('Business Number'),
                  const SizedBox(height: 6),
                  _dialogInput(
                    controller: _businessNumberController,
                    hint: 'Enter business number',
                    icon: Icons.business_outlined,
                  ),
                  const SizedBox(height: 14),

                  // Phone Number
                  _dialogLabel('Phone Number'),
                  const SizedBox(height: 6),
                  _dialogInput(
                    controller: _phoneController,
                    hint: 'Enter phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  // Address
                  _dialogLabel('Address'),
                  const SizedBox(height: 6),
                  _dialogInput(
                    controller: _addressController,
                    hint: 'Enter address',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 14),

                  // Transit Number
                  _dialogLabel('Transit Number'),
                  const SizedBox(height: 6),
                  _dialogInput(
                    controller: _transitController,
                    hint: 'Enter transit number',
                    icon: Icons.numbers_outlined,
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2D4F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSavingProfile ? null : _saveMissingInfo,
                      child: _isSavingProfile
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Text(
                              'Save & Complete Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Skip button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() => _alertDismissed = true);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          color: Color(0xFF9BA5B4),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1B2D4F),
      ),
    );
  }

  Widget _dialogInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF1B2D4F), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1B2D4F), size: 18),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1B2D4F), width: 1.5),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------
  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => ProductsPage(role: widget.role)));
      return;
    }
    if (index == 2) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SalesPage()));
      return;
    }
    if (index == 3) {
      _showMoreDrawer();
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _onCameraPressed() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (barcode == null) return;
    await _handleScannedBarcode(barcode);
  }

  Future<void> _handleScannedBarcode(String barcode) async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B2D4F)),
      ),
    );

    try {
      final url = '${ApiConfig.baseUrl}/product/scan/$barcode';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final product = jsonDecode(response.body);
        _showProductBottomSheet(product);
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product not found for this barcode.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not connect to server: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showProductBottomSheet(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              product['product_Name'] ?? product['productName'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF1B2D4F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product['category_Name'] ?? product['categoryName'] ?? '',
              style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip(Icons.inventory_2_outlined, 'Stock',
                    '${product['stock_Quantity'] ?? product['stockQuantity'] ?? 0}'),
                _statChip(Icons.euro_rounded, 'Price', '${product['price'] ?? 0}€'),
                _statChip(Icons.tag_rounded, 'ID',
                    '#${product['product_ID'] ?? product['productId'] ?? ''}'),
              ],
            ),
            if ((product['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(product['description'],
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2D4F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProductsPage(role: widget.role)));
                },
                child: const Text('View All Products',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1B2D4F), size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F))),
          Text(label,
              style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 11)),
        ],
      ),
    );
  }

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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.people_alt_outlined, 'Customers', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => CustomersPage(role: widget.role)));
              }),
              _moreItem(Icons.add_box_outlined, 'Purchase', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const PurchasePage()));
              }),
              _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const IncomesPage()));
              }),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const ContactPage()));
              }),
              _moreItem(Icons.settings_outlined, 'Settings', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()));
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
          const Text('Admin',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F))),
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
                _moreItem(Icons.admin_panel_settings_outlined, 'Admin Panel', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const AdminPanelPage()));
                }),
                _moreItem(Icons.people_alt_outlined, 'Customers', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => CustomersPage(role: widget.role)));
                }),
                _moreItem(Icons.supervised_user_circle_outlined, 'Users', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const UsersPage()));
                }),
                _moreItem(Icons.chat_bubble_outline_rounded, 'Messages', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const MessagesPage()));
                }),
                _moreItem(Icons.add_box_outlined, 'Purchase', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const PurchasePage()));
                }),
                _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const IncomesPage()));
                }),
                _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const ContactPage()));
                }),
                _moreItem(Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()));
                }),
                _moreItem(Icons.logout_rounded, 'Logout', _logout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _moreItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1B2D4F), size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF1B2D4F), fontWeight: FontWeight.w500)),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STOX',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2D4F), letterSpacing: 1)),
                      Container(height: 3, width: double.infinity,
                          color: const Color(0xFF1B2D4F)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.07),
                            blurRadius: 10, offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Sales',
                            style: TextStyle(color: Color(0xFF9BA5B4),
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text('850€',
                            style: TextStyle(color: Color(0xFF1B2D4F),
                                fontSize: 24, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8EDF2)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 220, child: _buildBarChart()),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 12, height: 12, color: const Color(0xFF2D4169)),
                            const SizedBox(width: 8),
                            const Text('weekly sales',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(false),
                    const SizedBox(width: 8),
                    _dot(true),
                    const SizedBox(width: 8),
                    _dot(false),
                  ],
                ),
              ],
            ),

            // ✅ RED ALERT BUTTON — bottom right, only when missing info
            if (_hasMissingInfo && !_alertDismissed)
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: _showCompleteProfileDialog,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.person_outline,
                            color: Colors.white, size: 26),
                        // Notification dot
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: isAdmin
          ? AdminNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
              onCameraPressed: _onCameraPressed,
            )
          : UserNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
              onCameraPressed: _onCameraPressed,
            ),
    );
  }

  Widget _dot(bool active) {
    return Container(
      width: active ? 14 : 10,
      height: active ? 14 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF1B2D4F) : Colors.transparent,
        border: active ? null : Border.all(color: const Color(0xFF1B2D4F), width: 1.5),
      ),
    );
  }

  Widget _buildBarChart() {
    final data = [
      {'label': 'Week 1', 'value': 900.0},
      {'label': 'Week 2', 'value': 1200.0},
      {'label': 'Week 3', 'value': 2400.0},
      {'label': 'Week 4', 'value': 2500.0},
    ];
    final maxValue = 5000.0;
    final yLabels = ['5000€', '2500€', '1000€', '500€', '100€', '0€'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: yLabels
              .map((l) => Text(l,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9BA5B4))))
              .toList(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomPaint(
            painter: _GridPainter(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((item) {
                final value = item['value'] as double;
                final heightFraction = value / maxValue;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: heightFraction,
                        child: Container(
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D4169),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(item['label'] as String,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5EAF0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const lineCount = 6;
    for (int i = 0; i < lineCount; i++) {
      final y = size.height * i / (lineCount - 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}