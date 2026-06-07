// lib/screens/customers_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../widgets/user_navbar.dart';
import '../widgets/admin_navbar.dart';
import 'add_customer_page.dart';
import 'edit_customer_page.dart';
import 'products_page.dart';
import 'sales_page.dart';
import 'purchase_page.dart';
import 'incomes_page.dart';
import 'contact_page.dart';
import 'settings_page.dart';
import 'users_page.dart';
import 'messages_page.dart';
import 'admin_panel_page.dart';
import 'login_screen.dart';

class CustomersPage extends StatefulWidget {
  final String role;
  const CustomersPage({super.key, required this.role});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<dynamic> _allCustomers = [];
  List<dynamic> _filteredCustomers = [];

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSortAscending = true;

  int _visibleCount = 3;
  final int _loadIncrement = 3;

  final TextEditingController _searchController = TextEditingController();
  bool get isAdmin => widget.role == 'Admin';

  // ════════════════════════════════════════════════════════════════════
  // PER-USER LOCAL ID SYSTEM
  // ────────────────────────────────────────────────────────────────────
  // Her user için ayrı map: SharedPreferences key'i userId ile suffixed.
  // Örn: User 5 → 'customer_local_id_map_5'
  //      User 12 → 'customer_local_id_map_12'
  // Bu sayede her user kendi 1, 2, 3... sıralamasını görür.
  // ════════════════════════════════════════════════════════════════════

  Map<int, int> _idMap = {}; // customer_ID → localId
  int? _currentUserId; // JWT'den çekilen userId

  String get _idMapKey =>
      _currentUserId != null
          ? 'customer_local_id_map_$_currentUserId'
          : 'customer_local_id_map_anonymous';

  /// JWT token'ı decode edip içindeki userId claim'ini çıkarır.
  /// Backend `User.FindFirst("userId")` ile okuduğu için "userId" key'i var.
  /// Yedek olarak "nameid", "sub", "user_id" gibi standart claim'leri de denerim.
  int? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1];
      // Base64Url padding
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final Map<String, dynamic> claims = jsonDecode(decoded);

      // Olası claim isimleri
      final candidates = [
        'userId',
        'user_id',
        'userid',
        'UserId',
        'nameid',
        'sub',
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
      ];

      for (final key in candidates) {
        final v = claims[key];
        if (v == null) continue;
        if (v is int) return v;
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolveCurrentUserId() async {
    if (_currentUserId != null) return; // zaten çözüldü

    final prefs = await SharedPreferences.getInstance();

    // 1) Doğrudan saklanmış mı?
    final stored = prefs.getInt('user_ID') ??
        prefs.getInt('userId') ??
        prefs.getInt('userid');
    if (stored != null) {
      _currentUserId = stored;
      return;
    }

    // 2) Token'dan decode et
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      _currentUserId = _extractUserIdFromToken(token);
    }
  }

  Future<Map<int, int>> _loadIdMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_idMapKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(int.parse(k), v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveIdMap() async {
    final prefs = await SharedPreferences.getInstance();
    final encodable = _idMap.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString(_idMapKey, jsonEncode(encodable));
  }

  int _nextLocalId() {
    if (_idMap.isEmpty) return 1;
    final maxId = _idMap.values.reduce((a, b) => a > b ? a : b);
    return maxId + 1;
  }

  /// Backend listesi gelince her customer'a localId atar.
  Future<void> _assignLocalIds(List<dynamic> customers) async {
  await _resolveCurrentUserId();
  _idMap = await _loadIdMap();
  bool changed = false;

  final activeIds = customers
      .map((c) => (c['customer_ID'] ?? c['Customer_ID'] ?? 0) as int)
      .where((id) => id != 0)
      .toSet();

  final orphans =
      _idMap.keys.where((k) => !activeIds.contains(k)).toList();
  if (orphans.isNotEmpty) {
    for (final k in orphans) {
      _idMap.remove(k);
    }
    changed = true;
  }

  for (final c in customers) {
    final int customerId =
        (c['customer_ID'] ?? c['Customer_ID'] ?? 0) as int;
    if (customerId == 0) continue;

    if (_idMap.containsKey(customerId)) {
      c['localId'] = _idMap[customerId];
    } else {
      final newLocalId = _nextLocalId();
      _idMap[customerId] = newLocalId;
      c['localId'] = newLocalId;
      changed = true;
    }
  }

  if (changed) await _saveIdMap();
}

  Future<void> _removeFromIdMap(int customerId) async {
    if (_idMap.containsKey(customerId)) {
      _idMap.remove(customerId);
      await _saveIdMap();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserCustomers();
  }

  // -------------------------------------------------------------
  // Fetch
  // -------------------------------------------------------------
  Future<void> _fetchUserCustomers() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('Session token not found. Please login again.');
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/customer/user');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedData = jsonDecode(response.body);
        final activeCustomers = fetchedData
            .where((c) =>
                (c['isDeleted'] ?? c['IsDeleted'] ?? false) == false)
            .toList();

        // 🔥 User'a özel localId ata
        await _assignLocalIds(activeCustomers);

        setState(() {
          _allCustomers = activeCustomers;
          _filteredCustomers = List.from(_allCustomers);
          _visibleCount = 3;
        });

        _applySort();
      } else {
        _showSnackBar('Failed to load customers (${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------------------------------------
  // Delete
  // -------------------------------------------------------------
  Future<void> _deleteCustomer(dynamic customer) async {
    final int dbId =
        (customer['customer_ID'] ?? customer['Customer_ID'] ?? 0) as int;
    if (dbId == 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = Uri.parse('${ApiConfig.baseUrl}/customer/$dbId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _removeFromIdMap(dbId);
        _showSnackBar('Customer successfully deleted.', isSuccess: true);
        _fetchUserCustomers();
      } else {
        _showSnackBar('Delete failed.');
      }
    } catch (e) {
      _showSnackBar('Connection error: $e');
    }
  }

  // -------------------------------------------------------------
  // Search & Sort
  // -------------------------------------------------------------
  void _runSearch(String query) {
    List<dynamic> results = [];
    if (query.isEmpty) {
      results = _allCustomers;
    } else {
      final q = query.toLowerCase();
      results = _allCustomers.where((customer) {
        final name = (customer['full_Name'] ?? customer['Full_Name'] ?? '')
            .toString()
            .toLowerCase();
        final email = (customer['email'] ?? customer['Email'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    setState(() {
      _filteredCustomers = results;
      _visibleCount = 3;
    });
    _applySort();
  }

  void _applySort() {
    setState(() {
      _filteredCustomers.sort((a, b) {
        final int idA = a['localId'] ?? 0;
        final int idB = b['localId'] ?? 0;
        return _isSortAscending ? idA.compareTo(idB) : idB.compareTo(idA);
      });
    });
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? Colors.green : Colors.redAccent),
    );
  }

  // -------------------------------------------------------------
  // NAVIGATION
  // -------------------------------------------------------------
  void _handleNavTap(int index) {
    if (index == 3) {
      _showMoreDrawer();
      return;
    }
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => ProductsPage(role: widget.role)),
      );
      return;
    }
    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SalesPage(role: widget.role)),
      );
    }
  }

  void _onCameraPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera scanner coming soon!')));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final int dynamicItemCount = _filteredCustomers.length > _visibleCount
        ? _visibleCount + 1
        : _filteredCustomers.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Color(0xFF1B2D4F), size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'STOX',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B2D4F),
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                        height: 3,
                        width: double.infinity,
                        color: const Color(0xFF1B2D4F)),
                  ),
                ],
              ),
            ),

            // Search & Sort
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _isSearching
                        ? Container(
                            height: 40,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8)),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _runSearch('');
                                    setState(() => _isSearching = false);
                                  },
                                ),
                              ),
                              onChanged: (value) => _runSearch(value),
                            ),
                          )
                        : GestureDetector(
                            onTap: () =>
                                setState(() => _isSearching = true),
                            child:
                                _buildActionButton(Icons.search, 'search'),
                          ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      _isSortAscending = !_isSortAscending;
                      _applySort();
                    },
                    child: _buildActionButton(
                        _isSortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        'sort ID ${_isSortAscending ? "(1-N)" : "(N-1)"}'),
                  ),
                ],
              ),
            ),

            // Add Customer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2D4F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddCustomerPage()),
                    );
                    if (result == true) _fetchUserCustomers();
                  },
                  child: const Text('Add Customer',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1B2D4F)))
                  : _filteredCustomers.isEmpty
                      ? const Center(
                          child: Text('No customers found.',
                              style: TextStyle(color: Color(0xFF1B2D4F))))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: dynamicItemCount,
                          itemBuilder: (context, index) {
                            if (index == _visibleCount) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 24, top: 8),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        const Color(0xFF1B2D4F),
                                    backgroundColor:
                                        const Color(0xFFEEF2F7),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _visibleCount += _loadIncrement;
                                    });
                                  },
                                  child: const Text('Load More...',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                ),
                              );
                            }
                            final customer = _filteredCustomers[index];
                            return _buildCustomerCard(customer);
                          },
                        ),
            ),
          ],
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

  Widget _buildActionButton(IconData icon, String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1B2D4F)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFF1B2D4F),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(dynamic customer) {
    final int displayId = customer['localId'] ?? 0;
    final String name =
        (customer['full_Name'] ?? customer['Full_Name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
            color: const Color(0xFF1B2D4F).withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: $displayId - $name',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2D4F)),
            ),
            const Divider(height: 16, thickness: 0.5),
            _buildInfoRow('Email', customer['email'] ?? customer['Email']),
            _buildInfoRow('Phone Number',
                customer['phone_Number'] ?? customer['Phone_Number']),
            _buildInfoRow(
                'Address', customer['address'] ?? customer['Address']),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCardButton('Edit', const Color(0xFF1B2D4F), () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditCustomerPage(customer: customer),
                    ),
                  );
                  if (result == true) _fetchUserCustomers();
                }),
                const SizedBox(width: 8),
                _buildCardButton('Delete', const Color(0xFFD30000), () {
                  _showDeleteConfirmationDialog(customer);
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Color(0xFF1B2D4F)),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildCardButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 28,
      width: 75,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showDeleteConfirmationDialog(dynamic customer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete',
              style: TextStyle(
                  color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
          content:
              const Text('Are you sure you want to delete this customer?'),
          actions: [
            TextButton(
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Delete',
                  style: TextStyle(
                      color: Color(0xFFD30000),
                      fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCustomer(customer);
              },
            ),
          ],
        );
      },
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              }),
              _moreItem(Icons.add_box_outlined, 'Purchase', () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PurchasePage()));
              }),
              _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const IncomesPage()));
              }),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ContactPage()));
              }),
              _moreItem(Icons.settings_outlined, 'Settings', () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()));
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
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminPanelPage()));
                }),
                _moreItem(Icons.people_alt_outlined, 'Customers', () {
                  Navigator.pop(context);
                }),
                _moreItem(Icons.supervised_user_circle_outlined, 'Users',
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UsersPage()));
                }),
                _moreItem(Icons.chat_bubble_outline_rounded, 'Messages',
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MessagesPage()));
                }),
                _moreItem(Icons.add_box_outlined, 'Purchase', () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PurchasePage()));
                }),
                _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IncomesPage()));
                }),
                _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ContactPage()));
                }),
                _moreItem(Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()));
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
        margin: const EdgeInsets.only(bottom: 8),
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
                borderRadius: BorderRadius.circular(14)),
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
}