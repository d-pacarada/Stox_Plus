import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../widgets/user_navbar.dart';
import '../widgets/admin_navbar.dart';
import 'home_screen.dart';
import 'products_page.dart';
import 'sales_page.dart';
import 'customers_page.dart';
import 'purchase_page.dart';
import 'contact_page.dart';
import 'settings_page.dart';
import 'users_page.dart';
import 'messages_page.dart';
import 'admin_panel_page.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

class IncomesPage extends StatefulWidget {
  final String role;
  const IncomesPage({super.key, required this.role});

  @override
  State<IncomesPage> createState() => _IncomesPageState();
}

class _IncomesPageState extends State<IncomesPage> {
  String _selectedFilter = 'weekly';
  List<dynamic> _incomeData = [];
  bool _isLoading = true;
  bool get isAdmin => widget.role == 'Admin';

  int _visibleCount = 5;
  final int _loadIncrement = 5;

  DateTimeRange? _customRange;

  final List<Map<String, String>> _filters = [
    {'key': 'daily', 'label': 'Daily'},
    {'key': 'weekly', 'label': 'Weekly'},
    {'key': 'monthly', 'label': 'Monthly'},
    {'key': 'yearly', 'label': 'Yearly'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchIncome();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchIncome() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      String url;

      if (_customRange != null) {
        final start = _customRange!.start.toIso8601String();
        final end = _customRange!.end.toIso8601String();
        url =
            '${ApiConfig.baseUrl}/income?startDate=$start&endDate=$end';
      } else {
        url =
            '${ApiConfig.baseUrl}/income?filter=$_selectedFilter';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _incomeData = jsonDecode(response.body) as List;
            _visibleCount = 5;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B2D4F),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedFilter = '';
      });
      _fetchIncome();
    }
  }

  String _formatAmount(num amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k€';
    }
    return '${amount.toStringAsFixed(2)}€';
  }

  double get _totalIncome => _incomeData.fold(
      0, (sum, item) => sum + (item['amount'] as num).toDouble());

  // -------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------
  void _handleNavTap(int index) {
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    if (index == 1) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(
              builder: (_) => ProductsPage(role: widget.role)));
      return;
    }
    if (index == 2) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(
              builder: (_) => SalesPage(role: widget.role)));
      return;
    }
    if (index == 3) _showMoreDrawer();
  }

  Future<void> _onCameraPressed() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (barcode == null || !mounted) return;
  }

  void _showMoreDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) =>
          isAdmin ? _adminMoreSheet() : _userMoreSheet(),
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
                        builder: (_) =>
                            CustomersPage(role: widget.role)));
              }),
              _moreItem(Icons.add_box_outlined, 'Purchase', () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PurchasePage(role: widget.role)));
              }),
              _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                Navigator.pop(context);
              }),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.mail_outline_rounded, 'Contact Us',
                  () {
                Navigator.pop(context);
                Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) => const ContactPage()));
              }),
              _moreItem(Icons.settings_outlined, 'Settings', () {
                Navigator.pop(context);
                Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsPage()));
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
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2D4F))),
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
                _moreItem(
                    Icons.admin_panel_settings_outlined,
                    'Admin Panel', () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPanelPage()));
                }),
                _moreItem(Icons.people_alt_outlined, 'Customers',
                    () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CustomersPage(role: widget.role)));
                }),
                _moreItem(
                    Icons.supervised_user_circle_outlined, 'Users',
                    () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UsersPage()));
                }),
                _moreItem(
                    Icons.chat_bubble_outline_rounded, 'Messages',
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
                          builder: (_) =>
                              PurchasePage(role: widget.role)));
                }),
                _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                  Navigator.pop(context);
                }),
                _moreItem(Icons.mail_outline_rounded, 'Contact Us',
                    () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ContactPage()));
                }),
                _moreItem(Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsPage()));
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
          borderRadius: BorderRadius.circular(2)));

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
                borderRadius: BorderRadius.circular(14)),
            child:
                Icon(icon, color: const Color(0xFF1B2D4F), size: 26),
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
          (_) => false);
    }
  }

  // -------------------------------------------------------------
  // Build
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final int dynamicCount = _incomeData.length > _visibleCount
        ? _visibleCount + 1
        : _incomeData.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STOX',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2D4F),
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Container(
                      height: 3,
                      width: double.infinity,
                      color: const Color(0xFF1B2D4F)),
                ],
              ),
            ),

            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      children: [
                        // Sort button
                        Container(
                          width: double.infinity,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF1B2D4F)
                                    .withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sort,
                                  size: 18,
                                  color: Color(0xFF1B2D4F)),
                              const SizedBox(width: 8),
                              Text(
                                'sort by ${_customRange != null ? 'Custom Range' : _filters.firstWhere((f) => f['key'] == _selectedFilter, orElse: () => {'label': 'Date'})['label']!} (Newest)',
                                style: const TextStyle(
                                    color: Color(0xFF1B2D4F),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Custom Date Range button
                        GestureDetector(
                          onTap: _pickCustomDateRange,
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _customRange != null
                                  ? const Color(0xFF1B2D4F)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF1B2D4F)
                                      .withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.date_range_outlined,
                                  size: 18,
                                  color: _customRange != null
                                      ? Colors.white
                                      : const Color(0xFF1B2D4F),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _customRange != null
                                      ? '${_formatDate(_customRange!.start)} → ${_formatDate(_customRange!.end)}'
                                      : 'Select Custom Date Range',
                                  style: TextStyle(
                                    color: _customRange != null
                                        ? Colors.white
                                        : const Color(0xFF1B2D4F),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_customRange != null) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _customRange = null;
                                        _selectedFilter = 'weekly';
                                      });
                                      _fetchIncome();
                                    },
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 18),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Filter tabs
                        Row(
                          children: _filters.map((f) {
                            final isSelected =
                                _selectedFilter == f['key'] &&
                                    _customRange == null;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFilter = f['key']!;
                                    _customRange = null;
                                  });
                                  _fetchIncome();
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1B2D4F)
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF1B2D4F)
                                            .withOpacity(0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: Text(
                                    f['label']!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1B2D4F),
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Income list
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF1B2D4F)))
                        : _incomeData.isEmpty
                            ? const Center(
                                child: Text('No income data found.',
                                    style: TextStyle(
                                        color: Color(0xFF1B2D4F))))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                itemCount: dynamicCount,
                                itemBuilder: (context, index) {
                                  if (index == _visibleCount) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 24, top: 8),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton(
                                          style:
                                              ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1B2D4F),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(10)),
                                          ),
                                          onPressed: () => setState(() =>
                                              _visibleCount +=
                                                  _loadIncrement),
                                          child: const Text(
                                              'Load More',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 15)),
                                        ),
                                      ),
                                    );
                                  }
                                  return _buildIncomeCard(
                                      _incomeData[index]);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isAdmin
          ? AdminNavBar(
              currentIndex: 3,
              onTap: _handleNavTap,
              onCameraPressed: _onCameraPressed)
          : UserNavBar(
              currentIndex: 3,
              onTap: _handleNavTap,
              onCameraPressed: _onCameraPressed),
    );
  }

  Widget _buildIncomeCard(dynamic item) {
    final String label = item['displayLabel'] ?? '';
    final num amount = item['amount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF1B2D4F).withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2D4F)),
          ),
          Text(
            '${amount.toStringAsFixed(0)}€',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2D4F)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}