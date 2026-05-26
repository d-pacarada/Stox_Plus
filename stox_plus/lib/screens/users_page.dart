// lib/screens/users_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSortAscending = true;

  // Hangi kartlar "Show more" ile açık
  final Set<int> _expandedCards = {};

  int _visibleCount = 3;
  final int _loadIncrement = 3;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // -------------------------------------------------------------
  // Fetch
  // -------------------------------------------------------------
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('Session token not found. Please login again.');
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/users');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetched = jsonDecode(response.body);

        // Backend zaten IsDeleted=false döner ama defansif
        final activeUsers = fetched
            .where((u) =>
                (u['isDeleted'] ?? u['IsDeleted'] ?? false) == false)
            .toList();

        for (int i = 0; i < activeUsers.length; i++) {
          activeUsers[i]['localId'] = i + 1;
        }

        setState(() {
          _allUsers = activeUsers;
          _filteredUsers = List.from(_allUsers);
          _visibleCount = 3;
          _expandedCards.clear();
        });

        _applySort();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _showSnackBar('Yetkisiz erişim. Admin olarak giriş yapmalısınız.');
      } else {
        _showSnackBar('Failed to load users (${response.statusCode})');
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
  Future<void> _deleteUser(dynamic user) async {
    final dbId = user['user_ID'] ?? user['User_ID'];
    if (dbId == null) {
      _showSnackBar('User ID not found.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = Uri.parse('${ApiConfig.baseUrl}/users/$dbId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('User successfully deleted.', isSuccess: true);
        _fetchUsers();
      } else {
        _showSnackBar('Delete failed (${response.statusCode}).');
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
      results = _allUsers;
    } else {
      final q = query.toLowerCase();
      results = _allUsers.where((u) {
        final name = _getBusinessName(u).toLowerCase();
        final email = _getEmail(u).toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    setState(() {
      _filteredUsers = results;
      _visibleCount = 3;
    });
    _applySort();
  }

  void _applySort() {
    setState(() {
      _filteredUsers.sort((a, b) {
        final int idA = a['localId'] ?? 0;
        final int idB = b['localId'] ?? 0;
        return _isSortAscending ? idA.compareTo(idB) : idB.compareTo(idA);
      });
    });
  }

  // Backend genelde camelCase JSON döner ama ikisini de yakalayalım
  String _getBusinessName(dynamic u) =>
      (u['business_Name'] ?? u['Business_Name'] ?? '-').toString();
  String _getEmail(dynamic u) =>
      (u['email'] ?? u['Email'] ?? '-').toString();
  String _getPhone(dynamic u) =>
      (u['phone_Number'] ?? u['Phone_Number'] ?? '-').toString();
  String _getBusinessNumber(dynamic u) =>
      (u['business_Number'] ?? u['Business_Number'] ?? '-').toString();
  String _getAddress(dynamic u) =>
      (u['address'] ?? u['Address'] ?? '-').toString();
  String _getTransitNumber(dynamic u) =>
      (u['transit_Number'] ?? u['Transit_Number'] ?? '-').toString();
  String _getRegistrationDate(dynamic u) {
    final raw = u['date'] ?? u['DATE'] ?? u['Date'];
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? Colors.green : Colors.redAccent),
    );
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
    final int dynamicItemCount = _filteredUsers.length > _visibleCount
        ? _visibleCount + 1
        : _filteredUsers.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — Back + STOX
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

            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Users Management',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F)),
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

            // Refresh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2D4F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _fetchUsers,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Refresh',
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
                  : _filteredUsers.isEmpty
                      ? const Center(
                          child: Text('No users found.',
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
                            final user = _filteredUsers[index];
                            return _buildUserCard(user);
                          },
                        ),
            ),
          ],
        ),
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
  // User Card — temel info + Show more açılır
  // -------------------------------------------------------------
  Widget _buildUserCard(dynamic user) {
    final int displayId = user['localId'] ?? 0;
    final int dbId = (user['user_ID'] ?? user['User_ID'] ?? 0) as int;
    final String name = _getBusinessName(user);
    final String email = _getEmail(user);
    final String phone = _getPhone(user);

    final bool isExpanded = _expandedCards.contains(dbId);

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
            // Header: ID + Business Name
            Text(
              'User #$displayId - $name',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2D4F)),
            ),
            const Divider(height: 16, thickness: 0.5),

            // Her zaman görünen: Email + Phone
            _buildInfoRow('Email', email),
            _buildInfoRow('Phone', phone),

            // Show more / less ile açılan kısım
            if (isExpanded) ...[
              _buildInfoRow('Business Number', _getBusinessNumber(user)),
              _buildInfoRow('Address', _getAddress(user)),
              _buildInfoRow('Transit Number', _getTransitNumber(user)),
              _buildInfoRow('Registered', _getRegistrationDate(user)),
            ],

            // Toggle button
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCards.remove(dbId);
                  } else {
                    _expandedCards.add(dbId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isExpanded ? 'Show less' : 'Show more',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1B2D4F),
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCardButton('Delete', const Color(0xFFD30000), () {
                  _showDeleteConfirmationDialog(user);
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

  void _showDeleteConfirmationDialog(dynamic user) {
    final String name = _getBusinessName(user);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete',
              style: TextStyle(
                  color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
          content: Text(
              'Are you sure you want to delete user "$name"?\n\nThis will soft-delete the user from the system.'),
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
                _deleteUser(user);
              },
            ),
          ],
        );
      },
    );
  }
}