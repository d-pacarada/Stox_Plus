import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/api_config.dart';
import '../widgets/user_navbar.dart';
import '../widgets/admin_navbar.dart';
import 'add_product_page.dart';
import 'edit_product_page.dart';
import 'sales_page.dart';
import 'customers_page.dart';
import 'purchase_page.dart';
import 'incomes_page.dart';
import 'contact_page.dart';
import 'settings_page.dart';
import 'users_page.dart';
import 'messages_page.dart';
import 'admin_panel_page.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

class ProductsPage extends StatefulWidget {
  final String role;
  const ProductsPage({super.key, required this.role});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSortAscending = true;

  final Set<int> _expandedDescriptions = {};
  final Set<int> _expandedQrCodes = {};
  int _visibleCount = 3;
  final int _loadIncrement = 3;

  final TextEditingController _searchController = TextEditingController();
  bool get isAdmin => widget.role == 'Admin';

  // Per-user local ID system
  Map<int, int> _idMap = {};
  int? _currentUserId;

  String get _idMapKey => _currentUserId != null
      ? 'product_local_id_map_$_currentUserId'
      : 'product_local_id_map_anonymous';

  int? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1];
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

      final candidates = [
        'userId', 'user_id', 'userid', 'UserId', 'nameid', 'sub',
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
    if (_currentUserId != null) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('user_ID') ??
        prefs.getInt('userId') ??
        prefs.getInt('userid');
    if (stored != null) {
      _currentUserId = stored;
      return;
    }
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
    return _idMap.values.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _assignLocalIds(List<dynamic> products) async {
    await _resolveCurrentUserId();
    _idMap = await _loadIdMap();
    bool changed = false;

    final activeIds = products
        .map((p) => (p['product_ID'] ?? p['Product_ID'] ?? 0) as int)
        .where((id) => id != 0)
        .toSet();

    final orphans = _idMap.keys.where((k) => !activeIds.contains(k)).toList();
    if (orphans.isNotEmpty) {
      for (final k in orphans) _idMap.remove(k);
      changed = true;
    }

    for (final p in products) {
      final int productId = (p['product_ID'] ?? p['Product_ID'] ?? 0) as int;
      if (productId == 0) continue;

      if (_idMap.containsKey(productId)) {
        p['localId'] = _idMap[productId];
      } else {
        final newLocalId = _nextLocalId();
        _idMap[productId] = newLocalId;
        p['localId'] = newLocalId;
        changed = true;
      }
    }

    if (changed) await _saveIdMap();
  }

  Future<void> _removeFromIdMap(int productId) async {
    if (_idMap.containsKey(productId)) {
      _idMap.remove(productId);
      await _saveIdMap();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProducts();
  }

  // -------------------------------------------------------------
  // Fetch
  // -------------------------------------------------------------
  Future<void> _fetchUserProducts() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('Session token not found. Please login again.');
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/product/user');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetched = jsonDecode(response.body);
        await _assignLocalIds(fetched);
        setState(() {
          _allProducts = fetched;
          _filteredProducts = List.from(_allProducts);
          _visibleCount = 3;
          _expandedDescriptions.clear();
          _expandedQrCodes.clear();
        });
        _applySort();
      } else {
        _showSnackBar('Failed to load products (${response.statusCode})');
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
  Future<void> _deleteProduct(dynamic product) async {
    final int dbId = (product['product_ID'] ?? product['Product_ID'] ?? 0) as int;
    if (dbId == 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = Uri.parse('${ApiConfig.baseUrl}/product/$dbId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _removeFromIdMap(dbId);
        _showSnackBar('Product successfully deleted.', isSuccess: true);
        _fetchUserProducts();
      } else {
        _showSnackBar('Delete failed.');
      }
    } catch (e) {
      _showSnackBar('Connection error: $e');
    }
  }

  // -------------------------------------------------------------
  // Scanner
  // -------------------------------------------------------------
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
      _showSnackBar('Session expired. Please log in again.');
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
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/product/scan/$barcode'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final product = jsonDecode(response.body);
        _showScannedProductSheet(product);
      } else if (response.statusCode == 404) {
        _showSnackBar('Product not found for this barcode.');
      } else {
        _showSnackBar('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Could not connect to server: $e');
    }
  }

  void _showScannedProductSheet(Map<String, dynamic> product) {
    final String name = (product['product_Name'] ?? product['productName'] ?? '').toString();
    final String category = (product['category_Name'] ?? product['categoryName'] ?? '').toString();
    final int stock = (product['stock_Quantity'] ?? product['stockQuantity'] ?? 0) as int;
    final num price = (product['price'] ?? 0) as num;

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
            Text(name,
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF1B2D4F),
              ),
            ),
            const SizedBox(height: 4),
            Text(category,
              style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip(Icons.inventory_2_outlined, 'Stock', '$stock'),
                _statChip(Icons.euro_rounded, 'Price', '${price}€'),
                _statChip(
                  stock > 10 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  'Status',
                  stock > 10 ? 'OK' : 'Low',
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2D4F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
              fontSize: 16, fontWeight: FontWeight.w800,
              color: Color(0xFF1B2D4F),
            ),
          ),
          Text(label,
            style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Search & Sort
  // -------------------------------------------------------------
  void _runSearch(String query) {
    List<dynamic> results = [];
    if (query.isEmpty) {
      results = _allProducts;
    } else {
      final q = query.toLowerCase();
      results = _allProducts.where((p) {
        final name = (p['product_Name'] ?? p['Product_Name'] ?? '').toString().toLowerCase();
        final cat = (p['category_Name'] ?? p['Category_Name'] ?? '').toString().toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    }
    setState(() {
      _filteredProducts = results;
      _visibleCount = 3;
    });
    _applySort();
  }

  void _applySort() {
    setState(() {
      _filteredProducts.sort((a, b) {
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
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
      ),
    );
  }

  // -------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------
  void _handleNavTap(int index) {
    if (index == 1) return;
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SalesPage(role: widget.role)),
      );
      return;
    }
    if (index == 3) _showMoreDrawer();
  }

  // -------------------------------------------------------------
  // More Drawer
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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.people_alt_outlined, 'Customers', () {
                Navigator.pop(context);
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) => CustomersPage(role: widget.role)));
              }),
              _moreItem(Icons.add_box_outlined, 'Purchase', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PurchasePage(role: widget.role)));
              }),
              _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => IncomesPage(role: widget.role)));
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
                  Navigator.pushReplacement(context,
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
                      MaterialPageRoute(builder: (_) => PurchasePage(role: widget.role)));
                }),
                _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => IncomesPage(role: widget.role)));
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // Build
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final int dynamicItemCount = _filteredProducts.length > _visibleCount
        ? _visibleCount + 1
        : _filteredProducts.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STOX',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2D4F), letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Container(height: 3, width: double.infinity, color: const Color(0xFF1B2D4F)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _isSearching
                        ? Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                            onTap: () => setState(() => _isSearching = true),
                            child: _buildActionButton(Icons.search, 'search'),
                          ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      _isSortAscending = !_isSortAscending;
                      _applySort();
                    },
                    child: _buildActionButton(
                        _isSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        'sort ID ${_isSortAscending ? "(1-N)" : "(N-1)"}'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2D4F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddProductPage()),
                    );
                    if (result == true) _fetchUserProducts();
                  },
                  child: const Text('Add Product',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B2D4F)))
                  : _filteredProducts.isEmpty
                      ? const Center(
                          child: Text('No products found.',
                              style: TextStyle(color: Color(0xFF1B2D4F))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: dynamicItemCount,
                          itemBuilder: (context, index) {
                            if (index == _visibleCount) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24, top: 8),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1B2D4F),
                                    backgroundColor: const Color(0xFFEEF2F7),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    setState(() => _visibleCount += _loadIncrement);
                                  },
                                  child: const Text('Load More...',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                              );
                            }
                            return _buildProductCard(_filteredProducts[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isAdmin
          ? AdminNavBar(currentIndex: 1, onTap: _handleNavTap, onCameraPressed: _onCameraPressed)
          : UserNavBar(currentIndex: 1, onTap: _handleNavTap, onCameraPressed: _onCameraPressed),
    );
  }

  Widget _buildActionButton(IconData icon, String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))
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
                  color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Product Card
  // -------------------------------------------------------------
  Widget _buildProductCard(dynamic product) {
    final int productId = product['product_ID'] ?? product['Product_ID'] ?? 0;
    final int displayId = product['localId'] ?? 0;
    final String name = (product['product_Name'] ?? product['Product_Name'] ?? '').toString();
    final String description = (product['description'] ?? product['Description'] ?? '').toString();
    final String category = (product['category_Name'] ?? product['Category_Name'] ?? '-').toString();
    final int stock = (product['stock_Quantity'] ?? product['Stock_Quantity'] ?? 0) as int;
    final num priceNum = (product['price'] ?? product['Price'] ?? 0) as num;
    final String priceText = _formatPrice(priceNum);
    final String barcode = (product['barcode'] ?? product['Barcode'] ?? '').toString();

    final bool isExpanded = _expandedDescriptions.contains(productId);
    final bool isQrExpanded = _expandedQrCodes.contains(productId);
    final bool isLongDescription = description.length > 40;
    final String shownDescription = (!isLongDescription || isExpanded)
        ? description
        : '${description.substring(0, 40)}...';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF1B2D4F).withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name + ID
            Text(
              'ID: $displayId - $name',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F)),
            ),
            const SizedBox(height: 4),

            // Description
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF1B2D4F)),
                children: [
                  const TextSpan(
                      text: 'Description: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: shownDescription),
                ],
              ),
            ),
            if (isLongDescription)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedDescriptions.remove(productId);
                    } else {
                      _expandedDescriptions.add(productId);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isExpanded ? 'Show less' : 'Read more',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1B2D4F),
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Category, Stock, Price row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMiniRow('Category', category),
                      _buildMiniRow('Stock', stock.toString()),
                    ],
                  ),
                ),
                Text(priceText,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F))),
              ],
            ),
            const SizedBox(height: 10),

            // QR Code toggle button
            if (barcode.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isQrExpanded) {
                      _expandedQrCodes.remove(productId);
                    } else {
                      _expandedQrCodes.add(productId);
                    }
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      isQrExpanded ? Icons.qr_code : Icons.qr_code_2_outlined,
                      size: 16,
                      color: const Color(0xFF1B2D4F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isQrExpanded ? 'Hide QR Code' : 'Show QR Code',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1B2D4F),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            // QR Code display (expandable)
            if (isQrExpanded && barcode.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF1B2D4F).withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: barcode,
                        version: QrVersions.auto,
                        size: 160.0,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        barcode,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9BA5B4),
                            letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Edit / Delete buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCardButton('Edit', const Color(0xFF1B2D4F), () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProductPage(product: product),
                    ),
                  );
                  if (result == true) _fetchUserProducts();
                }),
                const SizedBox(width: 8),
                _buildCardButton('Delete', const Color(0xFFD30000), () {
                  _showDeleteConfirmationDialog(product);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(num value) {
    if (value == value.toInt()) return '${value.toInt()}€';
    return '${value.toStringAsFixed(2)}€';
  }

  Widget _buildMiniRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF1B2D4F)),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showDeleteConfirmationDialog(dynamic product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete',
              style: TextStyle(color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFD30000), fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProduct(product);
              },
            ),
          ],
        );
      },
    );
  }
}