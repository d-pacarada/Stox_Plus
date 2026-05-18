import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/user_navbar.dart';
import '../widgets/admin_navbar.dart';
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



class HomeScreen extends StatefulWidget {
  final String role;
  const HomeScreen({super.key, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool get isAdmin => widget.role == 'Admin';

void _onNavTap(int index) {
    // 1. Eğer alt bardan Products (index 1) tıklandıysa
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProductsPage()),
      );
      return; // Aşağıdaki setState'e girmesini engeller
    }
    
    // 2. Eğer alt bardan Sales (index 2) tıklandıysa
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SalesPage()),
      );
      return; // Aşağıdaki setState'e girmesini engeller
    }

    // 3. Eğer alt bardan More (index 3) tıklandıysa menüyü aç
    if (index == 3) {
      _showMoreDrawer();
      return;
    }
    
    // Sadece Overview (index 0) tıklandığında ekran indexini güncelle
    setState(() => _currentIndex = index);
  }

  void _onCameraPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera scanner coming soon!')),
    );
  }

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
              Navigator.pop(context); // Önce alttan açılan menüyü kapatır
              // home_screen.dart içinde CustomersPage yönlendirmelerini tam olarak böyle yap:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CustomersPage(role: widget.role), // <-- widget.role değerini gönderiyoruz!
  ),
);
            }),
            _moreItem(Icons.add_box_outlined, 'Purchase', () {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchasePage()));
    }),
    
    // YENİ INCOMES YÖNLENDİRMESİ
    _moreItem(Icons.trending_up_rounded, 'Incomes', () {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const IncomesPage()));
    }),
  ],
),
          const SizedBox(height: 20),
          Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    // CONTACT US
    _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
      Navigator.pop(context); // Menüyü kapat
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactPage())); // Sayfaya git
    }),
    
    // SETTINGS
    _moreItem(Icons.settings_outlined, 'Settings', () {
      Navigator.pop(context); // Menüyü kapat
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())); // Sayfaya git
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
        mainAxisSize: MainAxisSize.min, // Sadece içeriği kadar yer kaplasın
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
          
          // 3x3 Matris Düzeni
          Flexible(
            child: GridView.count(
              shrinkWrap: true, // GridView'un sonsuz yüksekliğe ulaşıp patlamasını engeller
              physics: const NeverScrollableScrollPhysics(), // İçeride ekstra kaydırmayı kapatır
              crossAxisCount: 3, // Yan yana tam 3 adet buton olacak
              crossAxisSpacing: 12, // Butonların yatay arası boşluk
              mainAxisSpacing: 16,  // Butonların dikey arası boşluk
              childAspectRatio: 0.95, // Butonların genişlik/yükseklik oranı (Kareye yakın)
              children: [
                // 1. Satır
                // home_screen.dart içindeki _adminMoreSheet fonksiyonunun ilk butonunu şu şekilde güncelle:

                _moreItem(Icons.admin_panel_settings_outlined, 'Admin Panel', () {
                 Navigator.pop(context); // Önce alt menüyü (BottomSheet) kapat
                Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const AdminPanelPage()) // Sayfaya git
                );
                }),
                _moreItem(Icons.people_alt_outlined, 'Customers', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomersPage(role: widget.role),));
                }),
                _moreItem(Icons.supervised_user_circle_outlined, 'Users', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const UsersPage()));
                }),

                // 2. Satır
                _moreItem(Icons.chat_bubble_outline_rounded, 'Messages', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesPage()));
                }),
                _moreItem(Icons.add_box_outlined, 'Purchase', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchasePage()));
                }),
                _moreItem(Icons.trending_up_rounded, 'Incomes', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const IncomesPage()));
                }),

                // 3. Satır
                _moreItem(Icons.mail_outline_rounded, 'Contact Us', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactPage()));
                }),
                _moreItem(Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STOX',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2D4F),
                          letterSpacing: 1)),
                  Container(
                      height: 3,
                      width: double.infinity,
                      color: const Color(0xFF1B2D4F)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Daily Sales Card
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Sales',
                        style: TextStyle(
                            color: Color(0xFF9BA5B4),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Text('850€',
                        style: TextStyle(
                            color: Color(0xFF1B2D4F),
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8EDF2)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04), blurRadius: 8)
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: 220, child: _buildBarChart()),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 12,
                            height: 12,
                            color: const Color(0xFF2D4169)),
                        const SizedBox(width: 8),
                        const Text('weekly sales',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Page dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_dot(false), const SizedBox(width: 8), _dot(true), const SizedBox(width: 8), _dot(false)],
            ),
          ],
        ),
      ),
      bottomNavigationBar: isAdmin
          ? AdminNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
              onCameraPressed: _onCameraPressed,
            )
          : UserNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
              onCameraPressed: _onCameraPressed,
            ),
    );
  }

  Widget _dot(bool active) {
    return Container(
      width: active ? 14 : 10,
      height: active ? 14 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF1B2D4F) : Colors.transparent,
        border: active
            ? null
            : Border.all(color: const Color(0xFF1B2D4F), width: 1.5),
      ),
    );
  }

  Widget _buildBarChart() {
    final data = [
      {'label': 'Week 1', 'value': 900.0},
      {'label': 'Week 2', 'value': 1200.0},
      {'label': 'Week 3', 'value': 2400.0},
      {'label': 'Week 4', 'value': 2500.0},
    ];
    final maxValue = 5000.0;
    final yLabels = ['5000€', '2500€', '1000€', '500€', '100€', '0€'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: yLabels
              .map((l) => Text(l,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9BA5B4))))
              .toList(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomPaint(
            painter: _GridPainter(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((item) {
                final value = item['value'] as double;
                final heightFraction = value / maxValue;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: heightFraction,
                        child: Container(
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D4169),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(item['label'] as String,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
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

    const lineCount = 6;
    for (int i = 0; i < lineCount; i++) {
      final y = size.height * i / (lineCount - 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}