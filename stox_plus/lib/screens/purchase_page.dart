import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../config/api_config.dart';
import '../widgets/user_navbar.dart';
import '../widgets/admin_navbar.dart';
import 'home_screen.dart';
import 'products_page.dart';
import 'sales_page.dart';
import 'customers_page.dart';
import 'incomes_page.dart';
import 'contact_page.dart';
import 'settings_page.dart';
import 'users_page.dart';
import 'messages_page.dart';
import 'admin_panel_page.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

class PurchasePage extends StatefulWidget {
  final String role;
  const PurchasePage({super.key, required this.role});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  List<dynamic> _purchases = [];
  List<dynamic> _products = [];
  bool _isLoading = true;
  bool get isAdmin => widget.role == 'Admin';

  int _visibleCount = 3;
  final int _loadIncrement = 3;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchPurchases(), _fetchProducts()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchPurchases() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/purchase/user'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (mounted) setState(() => _purchases = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/product/user'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) setState(() => _products = jsonDecode(response.body));
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // View Purchase Details
  // -------------------------------------------------------------
  void _viewPurchaseDetails(dynamic purchase) {
    final items = purchase['items'] as List? ?? [];

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Purchase Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2D4F))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Expanded(
                      flex: 4,
                      child: Text('Product Name',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2D4F),
                              fontSize: 12))),
                  Expanded(
                      flex: 2,
                      child: Text('Qty',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2D4F),
                              fontSize: 12))),
                  Expanded(
                      flex: 2,
                      child: Text('Price',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2D4F),
                              fontSize: 12))),
                  Expanded(
                      flex: 2,
                      child: Text('Amount',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2D4F),
                              fontSize: 12))),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 4,
                            child: Text(item['name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1B2D4F)))),
                        Expanded(
                            flex: 2,
                            child: Text('${item['quantity']}',
                                style: const TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 2,
                            child: Text('${item['unit_Cost']}€',
                                style: const TextStyle(fontSize: 12))),
                        Expanded(
                            flex: 2,
                            child: Text(
                                '${((item['quantity'] as num) * (item['unit_Cost'] as num)).toStringAsFixed(2)}€',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  )),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${purchase['total_Amount']}€',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF1B2D4F)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Generate & Save PDF
  // -------------------------------------------------------------
  Future<void> _generatePdf(dynamic purchase) async {
    final token = await _getToken();
    final purchaseId = purchase['purchase_ID'];
    final items = purchase['items'] as List? ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B2D4F))),
    );

    try {
      final pdfResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/purchase/generate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'From': purchase['supplier_Name'] ?? 'Supplier',
          'To': 'STOX Business',
          'Number': purchaseId,
          'Items': items
              .map((item) => {
                    'Name': item['name'],
                    'Quantity': item['quantity'],
                    'Unit_Cost': item['unit_Cost'],
                  })
              .toList(),
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (pdfResponse.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/purchase_$purchaseId.pdf');
        await file.writeAsBytes(pdfResponse.bodyBytes);
        await OpenFile.open(file.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF saved and opened!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // Send Email
  // -------------------------------------------------------------
  Future<void> _sendEmail(dynamic purchase) async {
    final token = await _getToken();
    final purchaseId = purchase['purchase_ID'];
    final items = purchase['items'] as List? ?? [];
    final supplierEmail = purchase['supplier_Email'] ?? '';

    if (supplierEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No supplier email available.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B2D4F))),
    );

    try {
      final emailResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/purchase/email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'From': 'STOX Business',
          'To': supplierEmail,
          'Number': purchaseId,
          'Items': items
              .map((item) => {
                    'Name': item['name'],
                    'Quantity': item['quantity'],
                    'Unit_Cost': item['unit_Cost'],
                  })
              .toList(),
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailResponse.statusCode == 200
              ? 'Purchase invoice emailed!'
              : 'Failed to send email.'),
          backgroundColor:
              emailResponse.statusCode == 200 ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // Delete Purchase
  // -------------------------------------------------------------
  void _confirmDelete(dynamic purchase) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('DELETE PURCHASE',
            style: TextStyle(
                color: Color(0xFF1B2D4F),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
                'Are you sure you want to delete this purchase ?',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deletePurchase(purchase['purchase_ID']);
            },
            child: const Text('Yes, I\'m sure',
                style: TextStyle(color: Colors.white)),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('No, cancel',
                style: TextStyle(color: Color(0xFF1B2D4F))),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePurchase(int purchaseId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/purchase/$purchaseId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchase deleted.'),
              backgroundColor: Colors.green),
        );
        _fetchPurchases();
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // Add Purchase Dialog
  // -------------------------------------------------------------
  void _showAddPurchaseDialog() {
    final _supplierController = TextEditingController();

    List<Map<String, dynamic>> _items = [
      {
        'productId': null,
        'quantity': 1,
        'price': 0.0,
        'qtyController': TextEditingController(text: '1'),
        'priceDisplay': '0.00€',
      }
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double total = _items.fold(0.0, (sum, item) {
            final qty = item['quantity'] as int;
            final price = (item['price'] as num).toDouble();
            return sum + (qty * price);
          });

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Purchase',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2D4F))),
                  const SizedBox(height: 16),

                  // Supplier Name
                  const Text('Supplier',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B2D4F),
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _supplierController,
                    style: const TextStyle(
                        color: Color(0xFF1B2D4F), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Supplier Name',
                      hintStyle: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF1B2D4F))),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Items header
                  Row(
                    children: const [
                      Expanded(
                          flex: 4,
                          child: Text('Product',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF1B2D4F)))),
                      SizedBox(width: 6),
                      Expanded(
                          flex: 2,
                          child: Text('Qty',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF1B2D4F)))),
                      SizedBox(width: 6),
                      Expanded(
                          flex: 2,
                          child: Text('Price',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF1B2D4F)))),
                      SizedBox(width: 6),
                      Expanded(
                          flex: 2,
                          child: Text('Amount',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF1B2D4F)))),
                      SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Item rows
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final amount = (item['quantity'] as int) *
                        (item['price'] as num).toDouble();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          // Product dropdown
                          Expanded(
                            flex: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  hint: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Text('Product',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                  ),
                                  value: item['productId'],
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 6),
                                  items: _products
                                      .map<DropdownMenuItem<int>>(
                                          (p) {
                                    return DropdownMenuItem<int>(
                                      value: p['product_ID'] ??
                                          p['Product_ID'],
                                      child: Text(
                                        p['product_Name'] ??
                                            p['Product_Name'] ??
                                            '',
                                        style: const TextStyle(
                                            fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      item['productId'] = val;
                                      // Auto-fill price from DB
                                      final product =
                                          _products.firstWhere(
                                        (p) =>
                                            (p['product_ID'] ??
                                                p['Product_ID']) ==
                                            val,
                                        orElse: () => {},
                                      );
                                      if (product.isNotEmpty) {
                                        final price =
                                            (product['price'] ?? 0)
                                                .toDouble();
                                        item['price'] = price;
                                        item['priceDisplay'] =
                                            '${price.toStringAsFixed(2)}€';
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Quantity
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: item['qtyController']
                                  as TextEditingController,
                              keyboardType: TextInputType.number,
                              style:
                                  const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color:
                                            Colors.grey.shade300)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color:
                                            Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color:
                                            Color(0xFF1B2D4F))),
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  item['quantity'] =
                                      int.tryParse(val) ?? 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Price — read only from DB
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2F7),
                                border: Border.all(
                                    color: Colors.grey.shade200),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Text(
                                item['priceDisplay'] ?? '0.00€',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1B2D4F),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Amount
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${amount.toStringAsFixed(2)}€',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B2D4F)),
                            ),
                          ),

                          // Remove row
                          if (_items.length > 1)
                            GestureDetector(
                              onTap: () {
                                (item['qtyController']
                                        as TextEditingController)
                                    .dispose();
                                setDialogState(
                                    () => _items.removeAt(i));
                              },
                              child: const Icon(Icons.close,
                                  color: Colors.red, size: 20),
                            )
                          else
                            const SizedBox(width: 20),
                        ],
                      ),
                    );
                  }),

                  // Add Item button
                  GestureDetector(
                    onTap: () => setDialogState(() {
                      _items.add({
                        'productId': null,
                        'quantity': 1,
                        'price': 0.0,
                        'qtyController':
                            TextEditingController(text: '1'),
                        'priceDisplay': '0.00€',
                      });
                    }),
                    child: const Text('+ Add Item',
                        style: TextStyle(
                            color: Color(0xFF1B2D4F),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            decoration: TextDecoration.underline)),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2D4F))),
                      Text('${total.toStringAsFixed(2)}€',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2D4F))),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Back & Add buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            side: const BorderSide(
                                color: Color(0xFF1B2D4F)),
                          ),
                          onPressed: () {
                            _supplierController.dispose();
                            for (final item in _items) {
                              (item['qtyController']
                                      as TextEditingController)
                                  .dispose();
                            }
                            Navigator.pop(context);
                          },
                          child: const Text('Back',
                              style: TextStyle(
                                  color: Color(0xFF1B2D4F),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (_supplierController.text
                                .trim()
                                .isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please enter supplier name.')),
                              );
                              return;
                            }
                            if (_items.any(
                                (i) => i['productId'] == null)) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please select all products.')),
                              );
                              return;
                            }
                            if (_items.any((i) =>
                                (i['quantity'] as int) <= 0)) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Quantity must be at least 1.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final supplierName =
                                _supplierController.text.trim();
                            _supplierController.dispose();
                            for (final item in _items) {
                              (item['qtyController']
                                      as TextEditingController)
                                  .dispose();
                            }
                            Navigator.pop(context);
                            await _createPurchase(
                                supplierName, _items, total);
                          },
                          child: const Text('Add',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createPurchase(String supplierName,
      List<Map<String, dynamic>> items, double total) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'Supplier_Name': supplierName,
          'Total_Amount': total,
          'Items': items
              .map((item) => {
                    'Product_ID': item['productId'],
                    'Quantity': item['quantity'],
                    'Price': item['price'],
                  })
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchase created successfully!'),
              backgroundColor: Colors.green),
        );
        _fetchPurchases();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: ${response.body}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scanned: $barcode')),
    );
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
              }),
              _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                Navigator.pop(context);
                Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) => IncomesPage(role: widget.role)));
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
                }),
                _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => IncomesPage(role: widget.role)));
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
    final int dynamicCount = _purchases.length > _visibleCount
        ? _visibleCount + 1
        : _purchases.length;

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

            // Search & Sort
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 3))
                          ]),
                      child: const Row(
                        children: [
                          SizedBox(width: 12),
                          Icon(Icons.search,
                              size: 18, color: Color(0xFF1B2D4F)),
                          SizedBox(width: 6),
                          Text('search',
                              style: TextStyle(
                                  color: Color(0xFF9BA5B4),
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 40,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 3))
                        ]),
                    child: const Row(
                      children: [
                        Icon(Icons.sort,
                            size: 18, color: Color(0xFF1B2D4F)),
                        SizedBox(width: 6),
                        Text('sort by',
                            style: TextStyle(
                                color: Color(0xFF1B2D4F),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Add Purchase button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2D4F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _showAddPurchaseDialog,
                  child: const Text('Add Purchase',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Purchase list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1B2D4F)))
                  : _purchases.isEmpty
                      ? const Center(
                          child: Text('No purchases found.',
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
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        const Color(0xFF1B2D4F),
                                    backgroundColor:
                                        const Color(0xFFEEF2F7),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                8)),
                                  ),
                                  onPressed: () => setState(() =>
                                      _visibleCount +=
                                          _loadIncrement),
                                  child: const Text('Load More...',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 15)),
                                ),
                              );
                            }
                            return _buildPurchaseCard(
                                _purchases[index], index);
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
              onCameraPressed: _onCameraPressed)
          : UserNavBar(
              currentIndex: 3,
              onTap: _handleNavTap,
              onCameraPressed: _onCameraPressed),
    );
  }

  Widget _buildPurchaseCard(dynamic purchase, int index) {
    final String supplierName =
        purchase['supplier_Name'] ?? 'Unknown Supplier';
    final String dateStr = purchase['purchase_Date'] ?? '';
    final num total = purchase['total_Amount'] ?? 0;
    final int purchaseId = purchase['purchase_ID'] ?? 0;

    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {}

    final String formattedDate = date != null
        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : dateStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
            color: const Color(0xFF1B2D4F).withOpacity(0.3),
            width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purchase #$purchaseId',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9BA5B4))),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(supplierName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2D4F))),
                Text('${total.toStringAsFixed(2)}€',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2D4F))),
              ],
            ),
            const SizedBox(height: 2),
            Text(formattedDate,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9BA5B4))),
            const SizedBox(height: 10),
            Row(
              children: [
                _actionBtn('View', const Color(0xFF1B2D4F),
                    () => _viewPurchaseDetails(purchase)),
                const SizedBox(width: 6),
                _actionBtn('Delete', const Color(0xFFD30000),
                    () => _confirmDelete(purchase)),
                const SizedBox(width: 6),
                _actionBtn('Email', const Color(0xFF0066CC),
                    () => _sendEmail(purchase)),
                const SizedBox(width: 6),
                _actionBtn('PDF', const Color(0xFF00AA13),
                    () => _generatePdf(purchase)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
      String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}