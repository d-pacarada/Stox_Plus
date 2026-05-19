// lib/screens/products_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  // Read More / Load More
  final Set<int> _expandedDescriptions = {};
  int _visibleCount = 3;
  final int _loadIncrement = 3;

  final TextEditingController _searchController = TextEditingController();
  bool get isAdmin => widget.role == 'Admin';

  @override
  void initState() {
    super.initState();
    _fetchUserProducts();
  }

  // -------------------------------------------------------------
  // Fetch products
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

        for (int i = 0; i < fetched.length; i++) {
          fetched[i]['localId'] = i + 1;
        }

        setState(() {
          _allProducts = fetched;
          _filteredProducts = List.from(_allProducts);
          _visibleCount = 3;
          _expandedDescriptions.clear();
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
  // Delete product (soft delete)
  // -------------------------------------------------------------
  Future<void> _deleteProduct(dynamic product) async {
    final dbId =
        product['product_ID'] ?? product['Product_ID'] ?? product['id'];
    if (dbId == null) return;

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
  // Search & Sort
  // -------------------------------------------------------------
  void _runSearch(String query) {
    List<dynamic> results = [];
    if (query.isEmpty) {
      results = _allProducts;
    } else {
      final q = query.toLowerCase();
      results = _allProducts.where((p) {
        final name = (p['product_Name'] ?? p['Product_Name'] ?? '')
            .toString()
            .toLowerCase();
        final cat = (p['category_Name'] ?? p['Category_Name'] ?? '')
            .toString()
            .toLowerCase();
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
          backgroundColor: isSuccess ? Colors.green : Colors.redAccent),
    );
  }

  // -------------------------------------------------------------
  // NAVIGATION
  // -------------------------------------------------------------
  void _handleNavTap(int index) {
    if (index == 1) return; // zaten buradayız (Products)

    if (index == 0) {
      // Overview → Home'a dön
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    if (index == 2) {
      // Sales → direkt geç
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SalesPage()),
      );
      return;
    }

    if (index == 3) {
      // More → drawer aç
      _showMoreDrawer();
    }
  }

  void _onCameraPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera scanner coming soon!')));
  }

  // -------------------------------------------------------------
  // MORE DRAWER (Home ile aynı)
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
                    builder: (context) =>
                        CustomersPage(role: widget.role),
                  ),
                );
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CustomersPage(role: widget.role),
                    ),
                  );
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

  Widget _sheetHandle() {
    return Container(
      width: 40,
      height: 4,
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
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // BUILD
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
            // STOX header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STOX',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2D4F),
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Container(
                      height: 3,
                      width: double.infinity,
                      color: const Color(0xFF1B2D4F)),
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

            // Add Product Button
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
                          builder: (context) => const AddProductPage()),
                    );
                    if (result == true) _fetchUserProducts();
                  },
                  child: const Text('Add Product',
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
                  : _filteredProducts.isEmpty
                      ? const Center(
                          child: Text('No products found.',
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
                            final product = _filteredProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: isAdmin
          ? AdminNavBar(
              currentIndex: 1,
              onTap: _handleNavTap,
              onCameraPressed: _onCameraPressed,
            )
          : UserNavBar(
              currentIndex: 1,
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

  // -------------------------------------------------------------
  // Product Card
  // -------------------------------------------------------------
  Widget _buildProductCard(dynamic product) {
    final int productId =
        product['product_ID'] ?? product['Product_ID'] ?? 0;
    final String name =
        (product['product_Name'] ?? product['Product_Name'] ?? '').toString();
    final String description =
        (product['description'] ?? product['Description'] ?? '').toString();
    final String category =
        (product['category_Name'] ?? product['Category_Name'] ?? '-')
            .toString();
    final int stock = (product['stock_Quantity'] ??
            product['Stock_Quantity'] ??
            0) as int;
    final num priceNum = (product['price'] ?? product['Price'] ?? 0) as num;
    final String priceText = _formatPrice(priceNum);

    final bool isExpanded = _expandedDescriptions.contains(productId);
    final bool isLongDescription = description.length > 40;
    final String shownDescription = (!isLongDescription || isExpanded)
        ? description
        : '${description.substring(0, 40)}...';

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
              name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2D4F)),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1B2D4F)),
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
                Text(
                  priceText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCardButton('Edit', const Color(0xFF1B2D4F), () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditProductPage(product: product),
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
    if (value == value.toInt()) {
      return '${value.toInt()}€';
    }
    return '${value.toStringAsFixed(2)}€';
  }

  Widget _buildMiniRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF1B2D4F)),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showDeleteConfirmationDialog(dynamic product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete',
              style: TextStyle(
                  color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
          content:
              const Text('Are you sure you want to delete this product?'),
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
                _deleteProduct(product);
              },
            ),
          ],
        );
      },
    );
  }
}