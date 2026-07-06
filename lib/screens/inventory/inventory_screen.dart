import 'package:flutter/material.dart';
import 'brand_screen.dart';
import 'product_screen.dart';
import '../../theme.dart';

class InventoryScreen extends StatelessWidget {
  final GlobalKey<ProductScreenState>? productKey;
  const InventoryScreen({super.key, this.productKey});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Inventory'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Products'),
              Tab(icon: Icon(Icons.branding_watermark_rounded), text: 'Brands'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProductScreen(key: productKey),
            const BrandScreen(),
          ],
        ),
      ),
    );
  }
}
