import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/brand.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';

class BrandScreen extends StatefulWidget {
  const BrandScreen({super.key});

  @override
  State<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends State<BrandScreen> {
  final _db = DatabaseHelper();
  List<Brand> _brands = [];
  List<Brand> _filteredBrands = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _searchCtrl.addListener(_filterBrands);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterBrands() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredBrands = _brands.where((b) => b.name.toLowerCase().contains(query)).toList();
    });
  }

  Future<void> _loadBrands() async {
    setState(() => _loading = true);
    final brands = await _db.getBrands();
    setState(() {
      _brands = brands;
      _filteredBrands = brands;
      _loading = false;
    });
  }

  Future<void> _showAddDialog({Brand? brand}) async {
    final controller = TextEditingController(text: brand?.name);
    final isEdit = brand != null;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isEdit ? 'Edit Brand' : 'Add Brand'),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.pop(ctx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Brand Name',
            prefixIcon: Icon(Icons.branding_watermark_rounded),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      if (isEdit) {
        await _db.updateBrand(Brand(id: brand.id, name: controller.text.trim()));
      } else {
        await _db.insertBrand(Brand(name: controller.text.trim()));
      }
      _loadBrands();
    }
  }

  Future<void> _deleteBrand(Brand brand) async {
    // Integrity check
    final isUsed = await _db.isBrandUsed(brand.id!);
    if (isUsed) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: Text('Brand "${brand.name}" is linked to existing products and cannot be deleted.'),
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
        title: const Text('Delete Brand'),
        content:
            Text('Delete "${brand.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteBrand(brand.id!);
      _loadBrands();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _brands.isEmpty
              ? EmptyState(
                  icon: Icons.branding_watermark_rounded,
                  message: 'No Brands Yet',
                  subtitle: 'Tap + to add your first brand',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search brands...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filteredBrands.isEmpty
                        ? const Center(child: Text('No brands match your search', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredBrands.length,
                        itemBuilder: (ctx, i) {
                          final brand = _filteredBrands[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: ListTile(
                              onTap: () => _showBrandProducts(brand),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.branding_watermark_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                        title: Text(brand.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text('ID: ${brand.id}',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                              onPressed: () => _showAddDialog(brand: brand),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error),
                              onPressed: () => _deleteBrand(brand),
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
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showBrandProducts(Brand brand) async {
    final products = await _db.getProductsByBrand(brand.id!);
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (ctx, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Products: ${brand.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: products.isEmpty
                        ? const Center(child: Text('No products found', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder),
                            itemBuilder: (ctx, i) {
                              final p = products[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('Code: ${p.productCode}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${p.currentStock}', style: TextStyle(color: p.currentStock <= 5 ? AppColors.error : AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Text('In Stock', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }
}
