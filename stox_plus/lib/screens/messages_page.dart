// lib/screens/messages_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<dynamic> _allMessages = [];
  List<dynamic> _filteredMessages = [];

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSortAscending = false; // varsayılan: en yeni mesaj üstte

  // Hangi kartların mesajı tam açık
  final Set<int> _expandedMessages = {};

  int _visibleCount = 3;
  final int _loadIncrement = 3;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  // -------------------------------------------------------------
  // Fetch
  // -------------------------------------------------------------
  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('Session token not found. Please login again.');
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts');
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
          _allMessages = fetched;
          _filteredMessages = List.from(_allMessages);
          _visibleCount = 3;
          _expandedMessages.clear();
        });

        _applySort();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _showSnackBar('Yetkisiz erişim.');
      } else {
        _showSnackBar('Failed to load messages (${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------------------------------------
  // Delete (hard delete — backend Remove yapıyor)
  // -------------------------------------------------------------
  Future<void> _deleteMessage(dynamic msg) async {
    final dbId = msg['contact_ID'] ?? msg['Contact_ID'];
    if (dbId == null) {
      _showSnackBar('Contact ID not found.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts/$dbId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Message deleted.', isSuccess: true);
        _fetchMessages();
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
      results = _allMessages;
    } else {
      final q = query.toLowerCase();
      results = _allMessages.where((m) {
        final email = _getEmail(m).toLowerCase();
        final message = _getMessage(m).toLowerCase();
        return email.contains(q) || message.contains(q);
      }).toList();
    }

    setState(() {
      _filteredMessages = results;
      _visibleCount = 3;
    });
    _applySort();
  }

  void _applySort() {
    setState(() {
      _filteredMessages.sort((a, b) {
        final int idA = a['localId'] ?? 0;
        final int idB = b['localId'] ?? 0;
        return _isSortAscending ? idA.compareTo(idB) : idB.compareTo(idA);
      });
    });
  }

  // Defensive getters
  String _getEmail(dynamic m) =>
      (m['email'] ?? m['Email'] ?? '-').toString();
  String _getMessage(dynamic m) =>
      (m['message'] ?? m['Message'] ?? '').toString();
  String _getFormattedDate(dynamic m) {
    final raw = m['date'] ?? m['Date'];
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$d.$mo.${dt.year}  $h:$mi';
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
    final int dynamicItemCount = _filteredMessages.length > _visibleCount
        ? _visibleCount + 1
        : _filteredMessages.length;

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

            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Messages',
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
                                hintText: 'Search email or text...',
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
                        _isSortAscending ? 'oldest first' : 'newest first'),
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
                  onPressed: _isLoading ? null : _fetchMessages,
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
                  : _filteredMessages.isEmpty
                      ? const Center(
                          child: Text('No messages found.',
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
                            final msg = _filteredMessages[index];
                            return _buildMessageCard(msg);
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
  // Message Card
  // -------------------------------------------------------------
  Widget _buildMessageCard(dynamic msg) {
    final int displayId = msg['localId'] ?? 0;
    final int dbId = (msg['contact_ID'] ?? msg['Contact_ID'] ?? 0) as int;
    final String email = _getEmail(msg);
    final String message = _getMessage(msg);
    final String dateStr = _getFormattedDate(msg);

    final bool isExpanded = _expandedMessages.contains(dbId);
    final bool isLong = message.length > 80;
    final String shownMessage = (!isLong || isExpanded)
        ? message
        : '${message.substring(0, 80)}...';

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
            // Header: ID + Email + Date
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Message #$displayId',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2D4F)),
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(height: 14, thickness: 0.5),

            // Email — clickable to copy/contact
            _buildInfoRow('From', email),
            const SizedBox(height: 6),

            // Message body
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1B2D4F)),
                children: [
                  const TextSpan(
                      text: 'Message: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: shownMessage),
                ],
              ),
            ),

            if (isLong)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedMessages.remove(dbId);
                    } else {
                      _expandedMessages.add(dbId);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
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

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCardButton('Delete', const Color(0xFFD30000), () {
                  _showDeleteConfirmationDialog(msg);
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Color(0xFF1B2D4F)),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value ?? '-'),
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

  void _showDeleteConfirmationDialog(dynamic msg) {
    final String email = _getEmail(msg);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete',
              style: TextStyle(
                  color: Color(0xFF1B2D4F), fontWeight: FontWeight.bold)),
          content: Text(
              'Delete this message from "$email"?\n\nThis action cannot be undone.'),
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
                _deleteMessage(msg);
              },
            ),
          ],
        );
      },
    );
  }
}