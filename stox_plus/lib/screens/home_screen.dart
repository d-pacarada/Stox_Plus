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

enum ChartFilter { daily, weekly, monthly }

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

  // Chart swipe controller
  late PageController _pageController;
  ChartFilter _currentFilter = ChartFilter.daily;

  // Data per filter
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _monthlyData = [];
  bool _chartLoading = false;

  // Selected bar index per page
  int? _selectedDailyIndex;
  int? _selectedWeeklyIndex;
  int? _selectedMonthlyIndex;

  // Complete profile form controllers
  final _businessNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _transitController = TextEditingController();
  bool _isSavingProfile = false;

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------
  int? get _selectedIndex {
    switch (_currentFilter) {
      case ChartFilter.daily:   return _selectedDailyIndex;
      case ChartFilter.weekly:  return _selectedWeeklyIndex;
      case ChartFilter.monthly: return _selectedMonthlyIndex;
    }
  }

  void _setSelectedIndex(int? idx) {
    switch (_currentFilter) {
      case ChartFilter.daily:   setState(() => _selectedDailyIndex = idx);   break;
      case ChartFilter.weekly:  setState(() => _selectedWeeklyIndex = idx);  break;
      case ChartFilter.monthly: setState(() => _selectedMonthlyIndex = idx); break;
    }
  }

  /// ISO week number (1–52/53) for a given date.
  int _isoWeekNumber(DateTime date) {
    // Find nearest Thursday to determine ISO week
    final thursday = date.add(Duration(days: 4 - (date.weekday)));
    final firstJan = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkMissingInfo();
    _fetchAllData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _businessNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _transitController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // Fetch all three datasets at once
  // ----------------------------------------------------------------
  Future<void> _fetchAllData() async {
    setState(() => _chartLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final results = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/income?filter=daily'),
            headers: {'Authorization': 'Bearer $token'}),
        http.get(Uri.parse('${ApiConfig.baseUrl}/income?filter=weekly'),
            headers: {'Authorization': 'Bearer $token'}),
        http.get(Uri.parse('${ApiConfig.baseUrl}/income?filter=monthly'),
            headers: {'Authorization': 'Bearer $token'}),
      ]);

      if (!mounted) return;

      // Daily — last 7 days
      if (results[0].statusCode == 200) {
        final raw = jsonDecode(results[0].body) as List;
        final last7 = raw.take(7).toList().reversed.toList();
        _dailyData = last7.asMap().entries.map((e) {
          final dateStr = e.value['date']?.toString() ?? '';
          return {
            'label':     _shortDayLabel(dateStr, e.key, total: last7.length),
            'sublabel':  _dayMonthLabel(dateStr, fallbackIdx: e.key, total: last7.length),
            'fullLabel': _fullDayLabel(dateStr, e.key, total: last7.length),
            'value':     (e.value['amount'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();
      }

      // Weekly — last 8 weeks with ISO week number + month under bar
      if (results[1].statusCode == 200) {
        final raw = jsonDecode(results[1].body) as List;
        final last8 = raw.take(8).toList().reversed.toList();
        _weeklyData = last8.asMap().entries.map((e) {
          final dateStr = e.value['date']?.toString() ??
                          e.value['weekStart']?.toString() ?? '';
          int weekNum = e.value['weekNumber'] as int? ?? 0;
          String monthStr = '';
          if (dateStr.isNotEmpty) {
            try {
              final dt = DateTime.parse(dateStr);
              if (weekNum == 0) weekNum = _isoWeekNumber(dt);
              const months = ['Jan','Feb','Mar','Apr','May','Jun',
                              'Jul','Aug','Sep','Oct','Nov','Dec'];
              monthStr = months[dt.month - 1];
            } catch (_) {}
          }
          if (weekNum == 0) weekNum = e.key + 1;
          return {
            'label':     'W$weekNum',
            'sublabel':  monthStr,
            'fullLabel': monthStr.isEmpty
                ? 'Week $weekNum'
                : 'Week $weekNum · $monthStr',
            'value':     (e.value['amount'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();
      }

      // Monthly — last 6 months
      if (results[2].statusCode == 200) {
        final raw = jsonDecode(results[2].body) as List;
        final last6 = raw.take(6).toList().reversed.toList();
        // Work out a base date so fallbacks count backwards from today
        final now = DateTime.now();
        _monthlyData = last6.asMap().entries.map((e) {
          // Try every field the API might use
          final monthStr   = e.value['month']?.toString() ?? '';
          final monthName  = e.value['monthName']?.toString() ?? '';
          final monthIndex = e.value['monthIndex'];   // 1-based int
          final dateStr    = e.value['date']?.toString() ?? '';

          // Derive a DateTime we can use for labels
          DateTime? dt;
          if (monthStr.isNotEmpty) {
            // "2025-06"  or  "2025-06-01"
            try { dt = DateTime.parse(monthStr.length <= 7 ? '$monthStr-01' : monthStr); } catch (_) {}
            // plain "6" or "06"
            if (dt == null) {
              final idx = int.tryParse(monthStr);
              if (idx != null && idx >= 1 && idx <= 12) {
                dt = DateTime(now.year, idx);
              }
            }
          }
          if (dt == null && dateStr.isNotEmpty) {
            try { dt = DateTime.parse(dateStr); } catch (_) {}
          }
          if (dt == null && monthIndex != null) {
            final idx = (monthIndex as num).toInt();
            if (idx >= 1 && idx <= 12) dt = DateTime(now.year, idx);
          }
          if (dt == null && monthName.isNotEmpty) {
            const names = ['january','february','march','april','may','june',
                           'july','august','september','october','november','december'];
            final idx = names.indexOf(monthName.toLowerCase());
            if (idx >= 0) dt = DateTime(now.year, idx + 1);
          }
          // Last-resort: count backwards from current month
          dt ??= DateTime(now.year, now.month - (last6.length - 1 - e.key));

          const shortM = ['Jan','Feb','Mar','Apr','May','Jun',
                          'Jul','Aug','Sep','Oct','Nov','Dec'];
          const longM  = ['January','February','March','April','May','June',
                          'July','August','September','October','November','December'];

          return {
            'label':     shortM[dt!.month - 1],
            'sublabel':  '${dt.year}',
            'fullLabel': '${longM[dt.month - 1]} ${dt.year}',
            'value':     (e.value['amount'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();
      }

      setState(() {});
    } catch (_) {
    } finally {
      if (mounted) setState(() => _chartLoading = false);
    }
  }

  // ── Label helpers ──────────────────────────────────────────────

  /// Fallback: count back from today so we always get a real date.
  DateTime _fallbackDay(int idx, int total) {
    final today = DateTime.now();
    return today.subtract(Duration(days: total - 1 - idx));
  }

  String _shortDayLabel(String raw, int fallbackIdx, {int total = 7}) {
    DateTime? dt;
    try { dt = DateTime.parse(raw); } catch (_) {}
    dt ??= _fallbackDay(fallbackIdx, total);
    const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return d[dt.weekday - 1];
  }

  /// "Jun 9" shown under daily bar
  String _dayMonthLabel(String raw, {int fallbackIdx = 0, int total = 7}) {
    DateTime? dt;
    try { dt = DateTime.parse(raw); } catch (_) {}
    dt ??= _fallbackDay(fallbackIdx, total);
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _fullDayLabel(String raw, int fallbackIdx, {int total = 7}) {
    DateTime? dt;
    try { dt = DateTime.parse(raw); } catch (_) {}
    dt ??= _fallbackDay(fallbackIdx, total);
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Monday','Tuesday','Wednesday','Thursday',
                  'Friday','Saturday','Sunday'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  // ----------------------------------------------------------------
  // Missing info
  // ----------------------------------------------------------------
  Future<void> _checkMissingInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/settings/profile'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
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

  Future<void> _saveMissingInfo() async {
    if (_businessNumberController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty &&
        _addressController.text.trim().isEmpty &&
        _transitController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in at least one field.'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSavingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/settings/update-details'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'BusinessNumber': _businessNumberController.text.trim(),
          'PhoneNumber':    _phoneController.text.trim(),
          'Address':        _addressController.text.trim(),
          'TransitNumber':  _transitController.text.trim(),
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.pop(context);
        setState(() { _hasMissingInfo = false; _alertDismissed = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile completed successfully ✅'),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${response.statusCode}'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showCompleteProfileDialog() {
    _businessNumberController.clear();
    _phoneController.clear();
    _addressController.clear();
    _transitController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, _setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complete Your Profile', style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F))),
                        Text('Some information is missing', style: TextStyle(
                            fontSize: 12, color: Color(0xFF9BA5B4))),
                      ],
                    )),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9BA5B4)),
                      onPressed: () {
                        setState(() => _alertDismissed = true);
                        Navigator.pop(context);
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE8EDF2)),
                  const SizedBox(height: 16),
                  _dialogLabel('Business Number'), const SizedBox(height: 6),
                  _dialogInput(controller: _businessNumberController,
                      hint: 'Enter business number', icon: Icons.business_outlined),
                  const SizedBox(height: 14),
                  _dialogLabel('Phone Number'), const SizedBox(height: 6),
                  _dialogInput(controller: _phoneController,
                      hint: 'Enter phone number', icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _dialogLabel('Address'), const SizedBox(height: 6),
                  _dialogInput(controller: _addressController,
                      hint: 'Enter address', icon: Icons.location_on_outlined),
                  const SizedBox(height: 14),
                  _dialogLabel('Transit Number'), const SizedBox(height: 6),
                  _dialogInput(controller: _transitController,
                      hint: 'Enter transit number', icon: Icons.numbers_outlined),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2D4F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSavingProfile ? null : _saveMissingInfo,
                      child: _isSavingProfile
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('Save & Complete Profile', style: TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() => _alertDismissed = true);
                        Navigator.pop(context);
                      },
                      child: const Text('Skip for now',
                          style: TextStyle(color: Color(0xFF9BA5B4), fontSize: 14)),
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

  Widget _dialogLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B2D4F)));

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
        filled: true, fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1B2D4F), width: 1.5)),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Navigation
  // ----------------------------------------------------------------
  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(role: widget.role)));
      return;
    }
    if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SalesPage(role: widget.role)));
      return;
    }
    if (index == 3) { _showMoreDrawer(); return; }
    setState(() => _currentIndex = index);
  }

  Future<void> _onCameraPressed() async {
    final barcode = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (barcode == null) return;
    await _handleScannedBarcode(barcode);
  }

  Future<void> _handleScannedBarcode(String barcode) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')));
      return;
    }
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF1B2D4F))));
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/product/scan/$barcode'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (response.statusCode == 200) {
        _showProductBottomSheet(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Product not found for this barcode.'),
            backgroundColor: Colors.red));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not connect to server: $e'), backgroundColor: Colors.red));
    }
  }

  void _showProductBottomSheet(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(product['product_Name'] ?? product['productName'] ?? 'Unknown',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F))),
            const SizedBox(height: 4),
            Text(product['category_Name'] ?? product['categoryName'] ?? '',
                style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 14)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _statChip(Icons.inventory_2_outlined, 'Stock',
                  '${product['stock_Quantity'] ?? product['stockQuantity'] ?? 0}'),
              _statChip(Icons.euro_rounded, 'Price', '${product['price'] ?? 0}€'),
              _statChip(Icons.tag_rounded, 'ID',
                  '#${product['product_ID'] ?? product['productId'] ?? ''}'),
            ]),
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
                    style: TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600)),
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
      decoration: BoxDecoration(color: const Color(0xFFEEF2F7),
          borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Icon(icon, color: const Color(0xFF1B2D4F), size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F))),
        Text(label, style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 11)),
      ]),
    );
  }

  void _showMoreDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => isAdmin ? _adminMoreSheet() : _userMoreSheet(),
    );
  }

  Widget _userMoreSheet() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(), const SizedBox(height: 24),
        const Text('User', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F))),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _moreItem(Icons.people_alt_outlined, 'Customers', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => CustomersPage(role: widget.role)));
          }),
          _moreItem(Icons.add_box_outlined, 'Purchase', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => PurchasePage(role: widget.role)));
          }),
          _moreItem(Icons.trending_up_rounded, 'Incomes', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => IncomesPage(role: widget.role)));
          }),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()));
          }),
          _moreItem(Icons.settings_outlined, 'Settings', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          }),
          _moreItem(Icons.logout_rounded, 'Logout', _logout),
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _adminMoreSheet() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(), const SizedBox(height: 16),
        const Text('Admin', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F))),
        const SizedBox(height: 16),
        Flexible(child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 16,
          childAspectRatio: 0.95,
          children: [
            _moreItem(Icons.admin_panel_settings_outlined, 'Admin Panel', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelPage()));
            }),
            _moreItem(Icons.people_alt_outlined, 'Customers', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CustomersPage(role: widget.role)));
            }),
            _moreItem(Icons.supervised_user_circle_outlined, 'Users', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersPage()));
            }),
            _moreItem(Icons.chat_bubble_outline_rounded, 'Messages', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesPage()));
            }),
            _moreItem(Icons.add_box_outlined, 'Purchase', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PurchasePage(role: widget.role)));
            }),
            _moreItem(Icons.trending_up_rounded, 'Incomes', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => IncomesPage(role: widget.role)));
            }),
            _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()));
            }),
            _moreItem(Icons.settings_outlined, 'Settings', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            }),
            _moreItem(Icons.logout_rounded, 'Logout', _logout),
          ],
        )),
      ]),
    );
  }

  Widget _sheetHandle() => Container(width: 40, height: 4,
      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)));

  Widget _moreItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 60, height: 60,
            decoration: BoxDecoration(color: const Color(0xFFEEF2F7),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: const Color(0xFF1B2D4F), size: 26)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12,
            color: Color(0xFF1B2D4F), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('role');
    if (mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  // ----------------------------------------------------------------
  // Bar tapped
  // ----------------------------------------------------------------
  void _onBarTapped(int index, List<Map<String, dynamic>> data) {
    if (index >= data.length) return;
    final alreadySelected = _selectedIndex == index;
    _setSelectedIndex(alreadySelected ? null : index);

    if (!alreadySelected) {
      final item = data[index];
      final amount = (item['value'] as double);
      final label = item['fullLabel'] as String;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.euro_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('$label  •  ${amount.toStringAsFixed(2)}€',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          ]),
          backgroundColor: const Color(0xFF1B2D4F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ----------------------------------------------------------------
  // Bar chart widget
  // ----------------------------------------------------------------
  Widget _buildBarChart(
    List<Map<String, dynamic>> data,
    ChartFilter filter,
    int? selectedIdx,
  ) {
    if (data.isEmpty) {
      final count = filter == ChartFilter.daily ? 7
          : filter == ChartFilter.monthly ? 6 : 8;
      data = List.generate(count, (i) =>
          {'label': '—', 'sublabel': '', 'fullLabel': '—', 'value': 0.0});
    }

    final double maxVal = data
        .map((d) => (d['value'] as double))
        .fold(0.0, (a, b) => a > b ? a : b);
    final double maxValue = maxVal <= 0 ? 1000.0 : (maxVal * 1.3).ceilToDouble();

    final List<String> yLabels = [
      '${maxValue.toStringAsFixed(0)}€',
      '${(maxValue * 0.75).toStringAsFixed(0)}€',
      '${(maxValue * 0.5).toStringAsFixed(0)}€',
      '${(maxValue * 0.25).toStringAsFixed(0)}€',
      '0€',
    ];

    // Narrow bars for daily (7) and weekly (8), wider for monthly (6)
    final double barWidth = filter == ChartFilter.monthly ? 36.0 : 26.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Y-axis
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: yLabels.map((l) => Text(l,
              style: const TextStyle(fontSize: 9, color: Color(0xFF9BA5B4)))).toList(),
        ),
        const SizedBox(width: 8),
        // Bars
        Expanded(
          child: CustomPaint(
            painter: _GridPainter(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final value = (item['value'] as double);
                final heightFraction = maxValue > 0 ? value / maxValue : 0.0;
                final isSelected = selectedIdx == i;
                final sublabel = item['sublabel'] as String? ?? '';

                return GestureDetector(
                  onTap: () => _onBarTapped(i, data),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value tooltip above bar when selected
                      if (isSelected)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2D4F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${value.toStringAsFixed(0)}€',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 9, fontWeight: FontWeight.w700)),
                        )
                      else
                        const SizedBox(height: 20),

                      // Bar
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: heightFraction.clamp(0.0, 1.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: barWidth,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4A6FA5)
                                  : const Color(0xFF2D4169),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Main label (day name / W28 / Jan)
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF1B2D4F)
                              : const Color(0xFF4B5563),
                        ),
                      ),

                      // Sub-label (Jun 9 / Jun / 2025)
                      if (sublabel.isNotEmpty)
                        Text(
                          sublabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected
                                ? const Color(0xFF1B2D4F).withOpacity(0.7)
                                : const Color(0xFF9BA5B4),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── STOX header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STOX',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2D4F), letterSpacing: 1)),
                      Container(height: 3, width: double.infinity,
                          color: const Color(0xFF1B2D4F)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Swipeable chart card ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8EDF2)),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: Column(
                      children: [
                        // Chart title row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  _currentFilter == ChartFilter.daily   ? 'Daily Sales'
                                    : _currentFilter == ChartFilter.weekly ? 'Weekly Sales'
                                    : 'Monthly Sales',
                                  key: ValueKey(_currentFilter),
                                  style: const TextStyle(fontSize: 15,
                                      fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F)),
                                ),
                              ),
                              Row(children: [
                                Container(width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D4169),
                                      borderRadius: BorderRadius.circular(2),
                                    )),
                                const SizedBox(width: 6),
                                const Text('income', style: TextStyle(
                                    color: Color(0xFF9BA5B4), fontSize: 12)),
                              ]),
                            ],
                          ),
                        ),

                        // PageView chart
                        SizedBox(
                          height: 230,
                          child: _chartLoading
                              ? const Center(child: CircularProgressIndicator(
                                  color: Color(0xFF1B2D4F), strokeWidth: 2))
                              : PageView(
                                  controller: _pageController,
                                  onPageChanged: (page) {
                                    setState(() {
                                      _currentFilter = ChartFilter.values[page];
                                    });
                                  },
                                  children: [
                                    _buildBarChart(_dailyData,   ChartFilter.daily,   _selectedDailyIndex),
                                    _buildBarChart(_weeklyData,  ChartFilter.weekly,  _selectedWeeklyIndex),
                                    _buildBarChart(_monthlyData, ChartFilter.monthly, _selectedMonthlyIndex),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 10),

                        // Page indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chevron_left, size: 14, color: Color(0xFFBBC5D0)),
                            const SizedBox(width: 4),
                            ...ChartFilter.values.map((f) {
                              final active = _currentFilter == f;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: active ? 20 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFF1B2D4F)
                                      : const Color(0xFFD0D8E4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 14, color: Color(0xFFBBC5D0)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _currentFilter == ChartFilter.daily   ? 'Daily  ·  swipe for weekly & monthly'
                              : _currentFilter == ChartFilter.weekly ? 'Weekly  ·  swipe for daily & monthly'
                              : 'Monthly  ·  swipe for daily & weekly',
                            key: ValueKey(_currentFilter),
                            style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Missing info FAB ──
          if (_hasMissingInfo && !_alertDismissed)
            Positioned(
              bottom: 90, right: 16,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _showCompleteProfileDialog,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4),
                          blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(Icons.person_outline, color: Colors.white, size: 26),
                      Positioned(top: 10, right: 10,
                          child: Container(width: 10, height: 10,
                              decoration: const BoxDecoration(
                                  color: Colors.yellow, shape: BoxShape.circle))),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isAdmin
          ? AdminNavBar(currentIndex: _currentIndex, onTap: _onNavTap,
              onCameraPressed: _onCameraPressed)
          : UserNavBar(currentIndex: _currentIndex, onTap: _onNavTap,
              onCameraPressed: _onCameraPressed),
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
    const lineCount = 5;
    for (int i = 0; i < lineCount; i++) {
      final y = size.height * i / (lineCount - 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}