import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/purchases/purchase_screen.dart';
import 'screens/sales/sales_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/inventory/product_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint("Flutter Error: ${details.exception}");
      debugPrint("Stack: ${details.stack}");
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint("Platform Error: $error");
      debugPrint("Stack: $stack");
      return true;
    };

    runApp(const InventoryApp());
  }, (error, stack) {
    debugPrint("Uncaught Error: $error");
    debugPrint("Stack: $stack");
  });
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Manager',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  // Keys to trigger refreshes on tabs
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<ProductScreenState> _productKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Re-create pages list to include keys
    final List<Widget> pages = [
      DashboardScreen(key: _dashboardKey),
      InventoryScreen(productKey: _productKey),
      const PurchaseScreen(),
      const SalesScreen(),
      const ReportsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Trigger refresh based on target tab
          if (index == 0) {
            _dashboardKey.currentState?.loadData();
          } else if (index == 1) {
            _productKey.currentState?.loadData();
          }
        },
        type: BottomNavigationBarType.fixed, // Ensure consistency
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_rounded),
            label: 'Purchases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
