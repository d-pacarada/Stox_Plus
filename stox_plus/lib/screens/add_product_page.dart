// lib/screens/add_product_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // Backend Product model ile eşleşen Controller'lar
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final FocusNode _categoryFocusNode = FocusNode();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  bool _isLoading = false;
  List<dynamic> _userCategories = []; // Bu user'a ait kategoriler

  @override
  void initState() {
    super.initState();
    _fetchUserCategories();
  }

  // -------------------------------------------------------------
  // 1) Kullanıcının kategorilerini backend'ten çek (dropdown için)
  // -------------------------------------------------------------
  Future<void> _fetchUserCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/product/category/user');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() => _userCategories = data);
      }
    } catch (_) {
      // sessizce geç, kullanıcı yine de yeni kategori yazabilir
    }
  }

  // -------------------------------------------------------------
  // 2) Yazılan kategori adına göre Category_ID döndür.
  //    Varsa mevcut ID'yi al, yoksa user'a özel olarak oluştur.
  // -------------------------------------------------------------
  Future<int?> _resolveCategoryId(String categoryName, String token) async {
    final trimmed = categoryName.trim();
    if (trimmed.isEmpty) return null;

    // 2.a) Önce mevcut listede ara (case-insensitive)
    for (final c in _userCategories) {
      final name = (c['category_Name'] ?? c['Category_Name'] ?? '').toString();
      if (name.toLowerCase() == trimmed.toLowerCase()) {
        return (c['category_ID'] ?? c['Category_ID']) as int?;
      }
    }

    // 2.b) Yoksa yeni kategori oluştur
    final url = Uri.parse('${ApiConfig.baseUrl}/product/category');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'Category_Name': trimmed}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return (data['category_ID'] ?? data['Category_ID']) as int?;
    }
    return null;
  }

  // -------------------------------------------------------------
  // 3) Ürünü ekle
  // -------------------------------------------------------------
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        _showSnackBar('Oturum anahtarı bulunamadı, lütfen tekrar giriş yapın.');
        return;
      }

      // Önce kategori ID'sini çöz (varsa al, yoksa oluştur)
      final categoryId =
          await _resolveCategoryId(_categoryController.text, token);
      if (categoryId == null) {
        _showSnackBar('Kategori oluşturulamadı veya bulunamadı.');
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/product');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'Product_Name': _nameController.text.trim(),
          'Description': _descriptionController.text.trim(),
          'Category_ID': categoryId,
          'Stock_Quantity': int.tryParse(_stockController.text.trim()) ?? 0,
          'Price': double.tryParse(
                  _priceController.text.trim().replaceAll(',', '.')) ??
              0.0,
          'IsDeleted': false,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('Ürün başarıyla eklendi! 🎉', isSuccess: true);
        if (mounted) Navigator.pop(context, true);
      } else {
        final errorMsg =
            response.body.isNotEmpty ? response.body : 'Bir hata oluştu.';
        _showSnackBar('Hata (${response.statusCode}): $errorMsg');
      }
    } catch (e) {
      _showSnackBar('Sunucuya bağlanılamadı: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STOX Header
                const Text(
                  'STOX',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2D4F),
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  height: 3,
                  width: double.infinity,
                  color: const Color(0xFF1B2D4F),
                ),
                const SizedBox(height: 32),

                // Title
                const Center(
                  child: Text(
                    'Add New Product',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2D4F),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Form Fields
                _buildInputField('Product name', _nameController,
                    'Please enter product name'),
                const SizedBox(height: 18),
                _buildInputField('Description', _descriptionController,
                    'Please enter description',
                    hintText: 'Description...', maxLines: 3),
                const SizedBox(height: 18),

                // 🔥 Kategori — Autocomplete (varsa seç, yoksa yaz)
                _buildCategoryField(),
                const SizedBox(height: 18),

                _buildInputField('Stock Quantity', _stockController,
                    'Please enter stock quantity',
                    keyboardType: TextInputType.number, hintText: '600'),
                const SizedBox(height: 18),
                _buildInputField('Price', _priceController,
                    'Please enter price',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    hintText: '30'),
                const SizedBox(height: 36),

                // Back & Add Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B2D4F),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.4),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00AA13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.4),
                          ),
                          onPressed: _isLoading ? null : _submitProduct,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Add',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 Kategori dropdown + serbest yazma alanı
  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2D4F))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: RawAutocomplete<String>(
            textEditingController: _categoryController,
            focusNode: _categoryFocusNode,
            optionsBuilder: (TextEditingValue value) {
              final allNames = _userCategories
                  .map((c) =>
                      (c['category_Name'] ?? c['Category_Name'] ?? '').toString())
                  .where((n) => n.isNotEmpty)
                  .toList();
              if (value.text.trim().isEmpty) return allNames;
              return allNames.where((name) =>
                  name.toLowerCase().contains(value.text.toLowerCase()));
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(
                    color: Color(0xFF1B2D4F), fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Category',
                  hintStyle:
                      const TextStyle(color: Colors.black26, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF1B2D4F), width: 1.5)),
                  fillColor: Colors.white,
                  filled: true,
                  suffixIcon: const Icon(Icons.arrow_drop_down,
                      color: Color(0xFF1B2D4F)),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter or select a category'
                    : null,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 200,
                      maxWidth: MediaQuery.of(context).size.width - 48,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(option,
                                style: const TextStyle(
                                    color: Color(0xFF1B2D4F))),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Choose existing or type a new category',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
      String label, TextEditingController controller, String errorText,
      {TextInputType keyboardType = TextInputType.text,
      String? hintText,
      int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2D4F))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style:
                const TextStyle(color: Color(0xFF1B2D4F), fontSize: 15),
            decoration: InputDecoration(
              hintText: hintText ?? label,
              hintStyle:
                  const TextStyle(color: Colors.black26, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF1B2D4F), width: 1.5)),
              fillColor: Colors.white,
              filled: true,
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? errorText : null,
          ),
        ),
      ],
    );
  }
}