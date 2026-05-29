import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ActivityLog {
  final int userId;
  final String businessName;
  final String? action;
  final DateTime timestamp;

  ActivityLog({
    required this.userId,
    required this.businessName,
    this.action,
    required this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> j) => ActivityLog(
        userId: j['userId'],
        businessName: j['business_Name'] ?? '',
        action: j['action'],
        timestamp: DateTime.parse(j['timestamp']).toLocal(),
      );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  bool _loading = true;
  String? _error;
  List<ActivityLog> _loggedInToday = [];
  List<ActivityLog> _latestLogs = [];

  static const int _maxLatestLogs = 10; // 🔥 Son 10 aktivite

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // 🔥 Products/Customers ile aynı base URL
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/user-activity'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final allLogs = (data['latestLogs'] as List)
            .map((e) => ActivityLog.fromJson(e))
            .toList();

        // En yeni olanlar üstte olsun
        allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _loggedInToday = (data['usersLoggedInToday'] as List)
              .map((e) => ActivityLog.fromJson(e))
              .toList();
          // 🔥 Sadece son 10
          _latestLogs = allLogs.take(_maxLatestLogs).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _loading = false;
      });
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}  ${_formatTime(dt)}';
  }

  Color _actionColor(String? action) {
    switch (action) {
      case 'Logged in':
        return const Color(0xFF22C55E);
      case 'Logged out':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _actionIcon(String? action) {
    switch (action) {
      case 'Logged in':
        return Icons.login_rounded;
      case 'Logged out':
        return Icons.logout_rounded;
      default:
        return Icons.flash_on_rounded;
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B2D4F)))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2D4F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Admin Panel',
            style: TextStyle(
              color: Color(0xFF1B2D4F),
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _fetchData,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1B2D4F)),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2D4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: const Color(0xFF1B2D4F),
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Stat cards ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Logged In Today',
                  value: _loggedInToday.length.toString(),
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCard(
                  icon: Icons.history_rounded,
                  label: 'Recent Activities',
                  value: _latestLogs.length.toString(),
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Logged in today ────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.login_rounded,
            title: 'Users Logged In Today',
            count: _loggedInToday.length,
          ),
          const SizedBox(height: 10),

          if (_loggedInToday.isEmpty)
            const _EmptyState(message: 'No users logged in today yet.')
          else
            ..._loggedInToday.map((log) => _UserLoginCard(
                  log: log,
                  formatTime: _formatTime,
                )),

          const SizedBox(height: 24),

          // ── Latest activities (max 10) ─────────────────────────────────────
          _SectionHeader(
            icon: Icons.timeline_rounded,
            title: 'Latest Activities',
            count: _latestLogs.length,
          ),
          const SizedBox(height: 10),

          if (_latestLogs.isEmpty)
            const _EmptyState(message: 'No activity records yet.')
          else
            ..._latestLogs.map((log) => _ActivityRow(
                  log: log,
                  formatDateTime: _formatDateTime,
                  actionColor: _actionColor,
                  actionIcon: _actionIcon,
                )),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1B2D4F)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2D4F),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2D4F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2D4F),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ),
    );
  }
}

class _UserLoginCard extends StatelessWidget {
  final ActivityLog log;
  final String Function(DateTime) formatTime;

  const _UserLoginCard({required this.log, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF1B2D4F).withOpacity(0.08),
            child: Text(
              log.businessName.isNotEmpty
                  ? log.businessName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2D4F),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.businessName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1B2D4F),
                  ),
                ),
                Text(
                  'ID: ${log.userId}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          // Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              formatTime(log.timestamp),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF22C55E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityLog log;
  final String Function(DateTime) formatDateTime;
  final Color Function(String?) actionColor;
  final IconData Function(String?) actionIcon;

  const _ActivityRow({
    required this.log,
    required this.formatDateTime,
    required this.actionColor,
    required this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final color = actionColor(log.action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        children: [
          // Action icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(actionIcon(log.action), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.businessName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1B2D4F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.action ?? 'Unknown action',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Time
          Text(
            formatDateTime(log.timestamp),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}