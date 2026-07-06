import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../models/brand.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => ProductScreenState();
}

class ProductScreenState extends State<ProductScreen> {
  final _db = DatabaseHelper();
  List<Product> _products = [];
  List<Product> _filtered = [];
  List<Brand> _brands = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() => _loading = true);
    try {
      final products = await _db.getProducts();
      final brands = await _db.getBrands();
      setState(() {
        _products = products;
        _filtered = products;
        _brands = brands;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _products
          : _products
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  p.sku.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _showAddProductSheet({Product? product}) async {
    if (_brands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add a brand first!'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?.name);
    final codeCtrl = TextEditingController(text: product?.productCode);
    final stockCtrl = TextEditingController(text: product?.openingStock.toString() ?? '0');
    final costCtrl = TextEditingController(text: '0.0');
    final priceCtrl = TextEditingController(text: product?.sellingPrice.toString() ?? '0.0');
    Brand? selectedBrand = isEdit 
      ? _brands.firstWhere((b) => b.id == product?.brandId, orElse: () => _brands.first)
      : _brands.first;
    
    if (isEdit && product.openingStock > 0) {
      final existingCost = await _db.getOpeningStockCost(product.id!);
      if (existingCost != null) {
        costCtrl.text = existingCost.toStringAsFixed(2);
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setBS) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? 'Edit Product' : 'Add Product',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.inventory_2_rounded))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: codeCtrl,
                          decoration: InputDecoration(
                              labelText: 'Product Code',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                                onPressed: () async {
                                  var res = await Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (context) => const SimpleBarcodeScannerPage(),
                                      ));
                                  if (res is String && res != '-1') {
                                    setBS(() => codeCtrl.text = res);
                                  }
                                },
                              ),
                          ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Selling Price (QAR)',
                            prefixIcon: Icon(Icons.attach_money_rounded)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isEdit) ...[
                    TextField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(labelText: 'Opening Stock'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setBS(() {}), // Refresh to show/hide cost field
                    ),
                    const SizedBox(height: 12),
                ],
                if (!isEdit || (product != null && product.openingStock > 0)) ...[
                    if ((int.tryParse(stockCtrl.text) ?? 0) > 0 || (isEdit && product!.openingStock > 0)) ...[
                      TextField(
                        controller: costCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Purchase Price for Opening Stock (QAR)',
                            prefixIcon: Icon(Icons.shopping_cart_checkout_rounded)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
                DropdownButtonFormField<Brand>(
                  value: selectedBrand,
                  decoration: const InputDecoration(labelText: 'Brand'),
                  dropdownColor: AppColors.surfaceVariant,
                  items: _brands
                      .map((b) =>
                          DropdownMenuItem(value: b, child: Text(b.name)))
                      .toList(),
                  onChanged: (b) => setBS(() => selectedBrand = b),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: Text(isEdit ? 'Update Product' : 'Save Product'),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim();
                      final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      if (name.isEmpty) return;
                      
                      if (isEdit) {
                        final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                        await _db.updateProduct(Product(
                          id: product.id,
                          name: name,
                          sku: product.sku,
                          productCode: code,
                          openingStock: product.openingStock,
                          currentStock: product.currentStock,
                          brandId: selectedBrand!.id!,
                          sellingPrice: price,
                        ), openingCost: (product.openingStock > 0) ? cost : null);
                      } else {
                        // Auto-generated SKU via timestamp
                        final autoSku = 'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                        final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                        await _db.insertProduct(Product(
                          name: name,
                          sku: autoSku,
                          productCode: code,
                          openingStock: stock,
                          currentStock: stock,
                          brandId: selectedBrand!.id!,
                          sellingPrice: price,
                        ), openingCost: (stock > 0) ? cost : null);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      loadData();
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _deleteProduct(Product p) async {
    // Check if product is used
    final isUsed = await _db.isProductUsed(p.id!);
    if (isUsed) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: Text('Product "${p.name}" is linked to existing purchases or sales and cannot be deleted.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteProduct(p.id!);
      loadData();
    }
  }

  String _getBrandName(int brandId) {
    try {
      return _brands.firstWhere((b) => b.id == brandId).name;
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                        })
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_rounded,
                        message: 'No Products Found',
                        subtitle: _searchCtrl.text.isEmpty
                            ? 'Tap + to add your first product'
                            : 'Try a different search term',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final p = _filtered[i];
                          final isLow = p.currentStock <= 5;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.inventory_2_rounded,
                                        color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15)),
                                        const SizedBox(height: 2),
                                            Text(
                                                'SKU: ${p.sku}  •  ${_getBrandName(p.brandId)}\nStock: ${p.currentStock}  •  Price: QAR ${p.sellingPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                            onPressed: () => _showAddProductSheet(product: p),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                            onPressed: () => _deleteProduct(p),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isLow
                                              ? AppColors.error
                                                  .withValues(alpha: 0.15)
                                              : AppColors.accent
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${p.currentStock}',
                                          style: TextStyle(
                                            color: isLow
                                                ? AppColors.error
                                                : AppColors.accent,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(isLow ? 'Low Stock' : 'In Stock',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isLow
                                                  ? AppColors.error
                                                  : AppColors.accent)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
