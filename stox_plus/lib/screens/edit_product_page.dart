// lib/screens/edit_product_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class EditProductPage extends StatefulWidget {
  final dynamic product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _stockController;
  late final TextEditingController _priceController;
  final FocusNode _categoryFocusNode = FocusNode();

  bool _isLoading = false;
  List<dynamic> _userCategories = [];

  late final int _productId;
  late final int _originalCategoryId;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _productId = (p['product_ID'] ?? p['Product_ID'] ?? 0) as int;
    _originalCategoryId =
        (p['category_ID'] ?? p['Category_ID'] ?? 0) as int;

    _nameController = TextEditingController(
        text: (p['product_Name'] ?? p['Product_Name'] ?? '').toString());
    _descriptionController = TextEditingController(
        text: (p['description'] ?? p['Description'] ?? '').toString());
    _categoryController = TextEditingController(
        text: (p['category_Name'] ?? p['Category_Name'] ?? '').toString());
    _stockController = TextEditingController(
        text:
            ((p['stock_Quantity'] ?? p['Stock_Quantity'] ?? 0)).toString());
    final priceValue = p['price'] ?? p['Price'] ?? 0;
    _priceController =
        TextEditingController(text: priceValue.toString());

    _fetchUserCategories();
  }

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
    } catch (_) {}
  }

  Future<int?> _resolveCategoryId(String categoryName, String token) async {
    final trimmed = categoryName.trim();
    if (trimmed.isEmpty) return null;

    // 1) Eğer kategori adı değiştirilmediyse orijinal ID'yi koru
    final originalName = (widget.product['category_Name'] ??
            widget.product['Category_Name'] ??
            '')
        .toString();
    if (trimmed.toLowerCase() == originalName.toLowerCase()) {
      return _originalCategoryId;
    }

    // 2) User'ın mevcut kategorilerinden eşleşeni bul
    for (final c in _userCategories) {
      final name = (c['category_Name'] ?? c['Category_Name'] ?? '').toString();
      if (name.toLowerCase() == trimmed.toLowerCase()) {
        return (c['category_ID'] ?? c['Category_ID']) as int?;
      }
    }

    // 3) Yoksa yeni kategori oluştur
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

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        _showSnackBar('Oturum anahtarı bulunamadı.');
        return;
      }

      final categoryId =
          await _resolveCategoryId(_categoryController.text, token);
      if (categoryId == null) {
        _showSnackBar('Kategori çözümlenemedi.');
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/product/$_productId');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'Product_ID': _productId,
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

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Ürün güncellendi ✅', isSuccess: true);
        if (mounted) Navigator.pop(context, true);
      } else {
        _showSnackBar('Hata (${response.statusCode}): ${response.body}');
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
          backgroundColor: isSuccess ? Colors.green : Colors.redAccent),
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
                const Text(
                  'STOX',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2D4F),
                      letterSpacing: 1),
                ),
                Container(
                    height: 3,
                    width: double.infinity,
                    color: const Color(0xFF1B2D4F)),
                const SizedBox(height: 32),

                const Center(
                  child: Text(
                    'Edit Product',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2D4F)),
                  ),
                ),
                const SizedBox(height: 32),

                _buildInputField('Product name', _nameController,
                    'Please enter product name'),
                const SizedBox(height: 18),
                _buildInputField('Description', _descriptionController,
                    'Please enter description',
                    hintText: 'Description...', maxLines: 3),
                const SizedBox(height: 18),

                _buildCategoryField(),
                const SizedBox(height: 18),

                _buildInputField('Stock Quantity', _stockController,
                    'Please enter stock quantity',
                    keyboardType: TextInputType.number),
                const SizedBox(height: 18),
                _buildInputField('Price', _priceController,
                    'Please enter price',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true)),
                const SizedBox(height: 36),

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
                          onPressed: _isLoading ? null : _submitUpdate,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Save',
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