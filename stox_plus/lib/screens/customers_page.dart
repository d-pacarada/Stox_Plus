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
  
  // 🔥 LOAD MORE İÇİN DEĞİŞKENLER
  int _visibleCount = 3; // Ekranda ilk başta kaç müşteri görünecek
  final int _loadIncrement = 3; // Load More butonuna basınca kaçar kaçar artacak

  final TextEditingController _searchController = TextEditingController();
  bool get isAdmin => widget.role == 'Admin';

  @override
  void initState() {
    super.initState();
    _fetchUserCustomers();
  }

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
        final activeCustomers = fetchedData.where((c) => c['isDeleted'] == false || c['IsDeleted'] == false).toList();

        for (int i = 0; i < activeCustomers.length; i++) {
          activeCustomers[i]['localId'] = i + 1; 
        }

        setState(() {
          _allCustomers = activeCustomers;
          _filteredCustomers = List.from(_allCustomers);
          _visibleCount = 3; // Yeni veri çekildiğinde görünür sayıyı resetle
        });
        
        _applySort(); 
      } else {
        _showSnackBar('Failed to load customers (${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCustomer(dynamic customer) async {
    final dbId = customer['customer_ID'] ?? customer['Customer_ID'] ?? customer['id'];
    if (dbId == null) return;

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
        _showSnackBar('Customer successfully deleted.', isSuccess: true);
        _fetchUserCustomers(); 
      } else {
        _showSnackBar('Delete failed.');
      }
    } catch (e) {
      _showSnackBar('Connection error: $e');
    }
  }

  void _runSearch(String query) {
    List<dynamic> results = [];
    if (query.isEmpty) {
      results = _allCustomers;
    } else {
      results = _allCustomers.where((customer) {
        final name = (customer['full_Name'] ?? customer['Full_Name'] ?? '').toString().toLowerCase();
        final email = (customer['email'] ?? customer['Email'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredCustomers = results;
      _visibleCount = 3; // Arama yapıldığında görünür sayıyı tekrar 3'e çekiyoruz
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
      SnackBar(content: Text(message), backgroundColor: isSuccess ? Colors.green : Colors.redAccent),
    );
  }

  void _onCameraPressed() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera scanner coming soon!')));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ekranda gerçekten render edilecek dinamik eleman sayısını hesapla
    final int dynamicItemCount = _filteredCustomers.length > _visibleCount 
        ? _visibleCount + 1  // Listeye +1 ekliyoruz çünkü en alta "Load More" butonu basacağız
        : _filteredCustomers.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 YENİ HEADER TASARIMI: Sol tarafta BACK butonu, Sağ tarafta STOX yazısı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B2D4F), size: 24),
                        onPressed: () => Navigator.pop(context), // Geri dönme aksiyonu
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

            // Search & Sort Bölümü
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _isSearching
                        ? Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
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
                      'sort ID ${_isSortAscending ? "(1-N)" : "(N-1)"}'
                    ),
                  ),
                ],
              ),
            ),

            // Add Customer Butonu
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
                      MaterialPageRoute(builder: (context) => const AddCustomerPage()),
                    );
                    if (result == true) _fetchUserCustomers();
                  },
                  child: const Text('Add Customer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Müşteri Kartları Listesi (Dinamik Load More Entegreli)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B2D4F)))
                  : _filteredCustomers.isEmpty
                      ? const Center(child: Text('No customers found.', style: TextStyle(color: Color(0xFF1B2D4F))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: dynamicItemCount,
                          itemBuilder: (context, index) {
                            // Eğer indeks görünür sınırı geçtiyse alt kısma "Load More" butonunu koyuyoruz
                            if (index == _visibleCount) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24, top: 8),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1B2D4F),
                                    backgroundColor: const Color(0xFFEEF2F7),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _visibleCount += _loadIncrement; // Limit değerini 3 arttırır
                                    });
                                  },
                                  child: const Text('Load More...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

      // Navbar Düzeni
      bottomNavigationBar: isAdmin
          ? AdminNavBar(
              currentIndex: 3, 
              onTap: (index) {
                if (index != 3) {
                  Navigator.pop(context);
                } else {
                  _showMoreDrawer(); 
                }
              },
              onCameraPressed: _onCameraPressed,
            )
          : UserNavBar(
              currentIndex: 3, 
              onTap: (index) {
                if (index != 3) {
                  Navigator.pop(context);
                } else {
                  _showMoreDrawer(); 
                }
              },
              onCameraPressed: _onCameraPressed,
            ),
    );
  }

  Widget _buildActionButton(IconData icon, String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1B2D4F)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(dynamic customer) {
    final int displayId = customer['localId'] ?? 0;

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
            Text(
              'Customer #$displayId - ${customer['full_Name'] ?? customer['Full_Name']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2D4F)),
            ),
            const Divider(height: 16, thickness: 0.5),
            _buildInfoRow('Email', customer['email'] ?? customer['Email']),
            _buildInfoRow('Phone Number', customer['phone_Number'] ?? customer['Phone_Number']),
            _buildInfoRow('Address', customer['address'] ?? customer['Address']),
            // 🔥 Notlar satırı buradaki listeden tamamen kaldırıldı, kart artık daha kompakt!
            const SizedBox(height: 10),
           //  YENİ HALİ:
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    _buildCardButton('Edit', const Color(0xFF1B2D4F), () async {
      // Edit ekranına gidiyoruz ve seçili müşteri verisini (customer) gönderiyoruz
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditCustomerPage(customer: customer),
        ),
      );
      
      // Eğer Edit sayfasında kaydetme başarılı olduysa (true döndüyse) listeyi yenile
      if (result == true) {
        _fetchUserCustomers();
      }
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
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showDeleteConfirmationDialog(dynamic customer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete', style: TextStyle(color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete this customer?'),
          actions: [
            TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Color(0xFFD30000), fontWeight: FontWeight.bold)),
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

  // More Butonuna 2. Kez Basınca Tetiklenecek BottomSheet Metotları
  void _showMoreDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
          const Text('User', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.people_alt_outlined, 'Customers', () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adminMoreSheet() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          const SizedBox(height: 24),
          const Text('Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1B2D4F))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moreItem(Icons.people_alt_outlined, 'Customers', () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle() => Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 8), color: Colors.grey[300]);

  Widget _moreItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: const Color(0xFFEEF2F7), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: const Color(0xFF1B2D4F), size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1B2D4F), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}