import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/brand.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/sale_payment.dart';
import '../models/purchase_payment.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _version = 15;

  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _database = await _initDB();
    } catch (e) {
      debugPrint("Critical Error in Database Initialization: $e");
      // Fallback: try to open without migration or recreate
      try {
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'inventory.db');
        _database = await openDatabase(path, version: _version); 
      } catch (e2) {
        debugPrint("Complete failure to open database: $e2");
        rethrow;
      }
    }
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'inventory.db');
    return openDatabase(
      path,
      version: _version, // Use static constant (8)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Optional: Ensure foreign keys
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'inventory.db');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE brands(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL,
        product_code TEXT NOT NULL,
        opening_stock INTEGER NOT NULL DEFAULT 0,
        current_stock INTEGER NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0.0,
        brand_id INTEGER NOT NULL,
        FOREIGN KEY (brand_id) REFERENCES brands(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL DEFAULT 0.0,
        date TEXT NOT NULL,
        transaction_id TEXT,
        status TEXT NOT NULL DEFAULT 'Received',
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact TEXT NOT NULL,
        company TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL DEFAULT 0.0,
        date TEXT NOT NULL,
        transaction_id TEXT,
        customer_id INTEGER,
        status TEXT NOT NULL DEFAULT 'Paid',
        due_date TEXT,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'Paid',
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE company_profile(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');
    await db.insert('company_profile', {
      'name': 'My Company',
      'address': '123 Fake Street',
      'phone': '(555) 123-4567'
    });

    await db.execute('''
      CREATE TABLE sale_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE products ADD COLUMN selling_price REAL NOT NULL DEFAULT 0.0');
      }
      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE company_profile(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            phone TEXT NOT NULL
          )
        ''');
        await db.insert('company_profile', {
          'name': 'My Company',
          'address': '123 Fake Street',
          'phone': '(555) 123-4567'
        });
      }
      if (oldVersion < 4) {
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            contact TEXT NOT NULL
          )
        ''');
        await db.execute('ALTER TABLE sales ADD COLUMN customer_id INTEGER');
      }
      if (oldVersion < 5) {
        await db.execute("ALTER TABLE suppliers ADD COLUMN address TEXT NOT NULL DEFAULT ''");
        await db.execute("ALTER TABLE purchases ADD COLUMN price REAL NOT NULL DEFAULT 0.0");
        await db.execute("ALTER TABLE sales ADD COLUMN price REAL NOT NULL DEFAULT 0.0");
      }
      if (oldVersion < 6) {
        await db.execute("ALTER TABLE purchases ADD COLUMN transaction_id TEXT");
        await db.execute("ALTER TABLE sales ADD COLUMN transaction_id TEXT");
      }
      if (oldVersion < 7) {
        await db.execute("ALTER TABLE customers ADD COLUMN address TEXT NOT NULL DEFAULT ''");
      }
      if (oldVersion < 8) {
        await db.execute("ALTER TABLE purchases ADD COLUMN status TEXT NOT NULL DEFAULT 'Received'");
      }
      if (oldVersion < 9) {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            description TEXT NOT NULL,
            amount REAL NOT NULL DEFAULT 0.0,
            status TEXT NOT NULL DEFAULT 'Paid',
            date TEXT NOT NULL
          )
        ''');
      }
      if (oldVersion < 10) {
        await db.execute("ALTER TABLE customers ADD COLUMN company TEXT NOT NULL DEFAULT ''");
      }
      if (oldVersion < 11) {
        await db.execute("ALTER TABLE sales ADD COLUMN status TEXT NOT NULL DEFAULT 'Paid'");
        await db.execute("ALTER TABLE sales ADD COLUMN due_date TEXT");
      }
      if (oldVersion < 12) {
        await db.execute("ALTER TABLE sales ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0.0");
      }
      if (oldVersion < 13) {
        await db.execute("ALTER TABLE purchases ADD COLUMN commission REAL NOT NULL DEFAULT 0.0");
      }
      if (oldVersion < 14) {
        await db.execute('''
          CREATE TABLE sale_payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL
          )
        ''');
        
        // Migrate existing payments
        final sales = await db.rawQuery('SELECT transaction_id, date, paid_amount FROM sales WHERE paid_amount > 0 GROUP BY transaction_id');
        for (var sale in sales) {
          final tid = sale['transaction_id'] as String;
          final amt = (sale['paid_amount'] as num).toDouble();
          final dt = sale['date'] as String;
          await db.insert('sale_payments', {
            'transaction_id': tid,
            'amount': amt,
            'date': dt,
          });
        }
      }
      if (oldVersion < 15) {
        await db.execute("ALTER TABLE purchases ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'Paid'");
        await db.execute("ALTER TABLE purchases ADD COLUMN due_date TEXT");
        await db.execute("ALTER TABLE purchases ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0.0");
        
        await db.execute('''
          CREATE TABLE purchase_payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL
          )
        ''');

        // Migrate existing purchases by setting their paid_amount to the total and creating a payment record
        final purchases = await db.rawQuery('SELECT transaction_id, date, SUM((price * quantity) + commission) as total FROM purchases GROUP BY transaction_id');
        for (var p in purchases) {
          final tid = p['transaction_id'] as String;
          final dt = p['date'] as String;
          final total = (p['total'] as num).toDouble();
          
          await db.update('purchases', {'paid_amount': total}, where: 'transaction_id = ?', whereArgs: [tid]);
          if (total > 0) {
            await db.insert('purchase_payments', {
              'transaction_id': tid,
              'amount': total,
              'date': dt,
            });
          }
        }
      }
    } catch (e) {
      // Log error but don't crash the whole app if possible
      debugPrint("Database migration error: $e");
    }
  }

  // ─── COMPANY PROFILE ──────────────────────────────────────────────────────
  
  Future<Map<String, dynamic>> getCompanyProfile() async {
    final db = await database;
    final maps = await db.query('company_profile', limit: 1);
    if (maps.isEmpty) {
      return {'name': '', 'address': '', 'phone': ''};
    }
    return maps.first;
  }

  Future<void> updateCompanyProfile(String name, String address, String phone) async {
    final db = await database;
    await db.update('company_profile', {
      'name': name,
      'address': address,
      'phone': phone,
    });
  }

  // ─── BRANDS ───────────────────────────────────────────────────────────────

  Future<int> insertBrand(Brand brand) async {
    final db = await database;
    return db.insert('brands', brand.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Brand>> getBrands() async {
    final db = await database;
    final maps = await db.query('brands', orderBy: 'name ASC');
    return maps.map((m) => Brand.fromMap(m)).toList();
  }

  Future<int> updateBrand(Brand brand) async {
    final db = await database;
    return db.update('brands', brand.toMap(),
        where: 'id = ?', whereArgs: [brand.id]);
  }

  Future<int> deleteBrand(int id) async {
    final db = await database;
    return db.delete('brands', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isBrandUsed(int id) async {
    final db = await database;
    final res = await db.query('products', where: 'brand_id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty;
  }

  // ─── PRODUCTS ─────────────────────────────────────────────────────────────

  Future<int> insertProduct(Product product, {double? openingCost}) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('products', product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      if (openingCost != null && openingCost > 0 && product.openingStock > 0) {
        // Create an "Initial Stock" supplier if it doesn't exist
        var suppliers = await txn.query('suppliers', where: 'name = ?', whereArgs: ['Initial Stock'], limit: 1);
        int supplierId;
        if (suppliers.isEmpty) {
          supplierId = await txn.insert('suppliers', {
            'name': 'Initial Stock',
            'contact': 'System',
            'address': 'System'
          });
        } else {
          supplierId = suppliers.first['id'] as int;
        }

        // Insert a purchase record for the opening stock
        await txn.insert('purchases', {
          'product_id': id,
          'supplier_id': supplierId,
          'quantity': product.openingStock,
          'price': openingCost,
          'date': DateTime.now().toIso8601String(),
          'transaction_id': 'SYS-OPN-${id}',
          'status': 'Received'
        });
      }
      return id;
    });
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<double?> getOpeningStockCost(int productId) async {
    final db = await database;
    final res = await db.query('purchases', 
      where: 'transaction_id = ?', 
      whereArgs: ['SYS-OPN-$productId'], 
      limit: 1
    );
    if (res.isEmpty) return null;
    return res.first['price'] as double;
  }

  Future<int> updateProduct(Product product, {double? openingCost}) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.update('products', product.toMap(),
          where: 'id = ?', whereArgs: [product.id]);

      if (openingCost != null && product.openingStock > 0) {
        final tid = 'SYS-OPN-${product.id}';
        final existing = await txn.query('purchases', where: 'transaction_id = ?', whereArgs: [tid], limit: 1);
        
        if (existing.isNotEmpty) {
          await txn.update('purchases', {'price': openingCost}, where: 'transaction_id = ?', whereArgs: [tid]);
        } else {
          // Create initial stock record if it was missing
          var suppliers = await txn.query('suppliers', where: 'name = ?', whereArgs: ['Initial Stock'], limit: 1);
          int supplierId;
          if (suppliers.isEmpty) {
            supplierId = await txn.insert('suppliers', {'name': 'Initial Stock', 'contact': 'System', 'address': 'System'});
          } else {
            supplierId = suppliers.first['id'] as int;
          }
          await txn.insert('purchases', {
            'product_id': product.id,
            'supplier_id': supplierId,
            'quantity': product.openingStock,
            'price': openingCost,
            'date': DateTime.now().toIso8601String(),
            'transaction_id': tid,
            'status': 'Received'
          });
        }
      }
      return rows;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isProductUsed(int id) async {
    final db = await database;
    final pRes = await db.query('purchases', where: 'product_id = ?', whereArgs: [id], limit: 1);
    if (pRes.isNotEmpty) return true;
    final sRes = await db.query('sales', where: 'product_id = ?', whereArgs: [id], limit: 1);
    return sRes.isNotEmpty;
  }

  Future<List<Product>> getProductsByBrand(int brandId) async {
    final db = await database;
    final maps = await db.query('products', where: 'brand_id = ?', whereArgs: [brandId], orderBy: 'name ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  // ─── SUPPLIERS ────────────────────────────────────────────────────────────

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return db.insert('suppliers', supplier.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await database;
    return db.update('suppliers', supplier.toMap(),
        where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isSupplierUsed(int id) async {
    final db = await database;
    final res = await db.query('purchases', where: 'supplier_id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty;
  }

  // ─── CUSTOMERS ────────────────────────────────────────────────────────────

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return db.update('customers', customer.toMap(),
        where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getCustomerSummary(int customerId) async {
    final db = await database;
    
    // Total quantity
    final qtyRes = await db.rawQuery('SELECT SUM(quantity) as total_qty FROM sales WHERE customer_id = ?', [customerId]);
    final totalQty = (qtyRes.first['total_qty'] as int?) ?? 0;
    
    // Total sales amount
    final totalSalesRes = await db.rawQuery('SELECT SUM(quantity * price) as total FROM sales WHERE customer_id = ?', [customerId]);
    final totalSalesAmount = (totalSalesRes.first['total'] as num?)?.toDouble() ?? 0.0;
    
    // Total paid amount
    final totalPaidRes = await db.rawQuery('''
      SELECT SUM(sp.amount) as total_paid
      FROM sale_payments sp
      INNER JOIN (SELECT DISTINCT transaction_id FROM sales WHERE customer_id = ?) s
      ON sp.transaction_id = s.transaction_id
    ''', [customerId]);
    final totalPaidAmount = (totalPaidRes.first['total_paid'] as num?)?.toDouble() ?? 0.0;
    
    final pendingAmount = totalSalesAmount - totalPaidAmount;

    return {
      'total_products_quantity': totalQty,
      'total_sales_amount': totalSalesAmount,
      'total_paid_amount': totalPaidAmount,
      'pending_amount': pendingAmount > 0 ? pendingAmount : 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getCustomerSalesTransactions(int customerId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.transaction_id, s.date, s.status, s.due_date, s.paid_amount, c.name as customer_name, SUM(s.price * s.quantity) as total_amount, COUNT(s.id) as item_count
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE s.customer_id = ?
      GROUP BY s.transaction_id
      ORDER BY s.date DESC
    ''', [customerId]);
  }

  // ─── PURCHASES ────────────────────────────────────────────────────────────

  Future<int> insertPurchase(Purchase purchase) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('purchases', purchase.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      // Increase current_stock
      await txn.rawUpdate(
        'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
        [purchase.quantity, purchase.productId],
      );
      return id;
    });
  }

  Future<void> insertPurchases(List<Purchase> purchases) async {
    final db = await database;
    await db.transaction((txn) async {
      final tid = purchases.first.transactionId ?? 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      for (var p in purchases) {
        var map = p.toMap();
        map['transaction_id'] = tid;
        await txn.insert('purchases', map);
        if (p.status == 'Received') {
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [p.quantity, p.productId],
          );
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPurchaseTransactions({String? search, DateTime? start, DateTime? end}) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];
    
    if (search != null && search.isNotEmpty) {
      where += " AND (s.name LIKE ? OR p.transaction_id LIKE ?)";
      args.add('%$search%');
      args.add('%$search%');
    }
    if (start != null && end != null) {
      where += " AND date(p.date) BETWEEN date(?) AND date(?)";
      args.add(start.toIso8601String());
      args.add(end.toIso8601String());
    }

    return db.rawQuery('''
      SELECT p.transaction_id, p.date, p.status, s.name as supplier_name, SUM((p.price * p.quantity) + p.commission) as total_amount, COUNT(p.id) as item_count, SUM(p.commission) as total_commission
      FROM purchases p
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE 1=1 $where
      GROUP BY p.transaction_id
      ORDER BY p.date DESC
    ''', args);
  }

  Future<List<Purchase>> getPurchasesByTransaction(String tid) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT p.*, pr.name AS product_name, pr.product_code, s.name AS supplier_name, b.name AS brand_name
      FROM purchases p
      LEFT JOIN products pr ON p.product_id = pr.id
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      LEFT JOIN brands b ON pr.brand_id = b.id
      WHERE p.transaction_id = ?
    ''', [tid]);
    return res.map((m) => Purchase.fromMap(m)).toList();
  }

  Future<List<Purchase>> getPurchases() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.*, pr.name AS product_name, pr.product_code, s.name AS supplier_name
      FROM purchases p
      LEFT JOIN products pr ON p.product_id = pr.id
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      ORDER BY p.date DESC, p.id DESC
    ''');
    return maps.map((m) => Purchase.fromMap(m)).toList();
  }

  Future<void> deletePurchaseTransaction(String tid) async {
    final db = await database;
    await db.transaction((txn) async {
      final items = await txn.query('purchases', where: 'transaction_id = ?', whereArgs: [tid]);
      for (var item in items) {
        if (item['status'] == 'Received') {
          final qty = item['quantity'] as int;
          final prodId = item['product_id'] as int;
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [qty, prodId],
          );
        }
      }
      await txn.delete('purchases', where: 'transaction_id = ?', whereArgs: [tid]);
      await txn.delete('purchase_payments', where: 'transaction_id = ?', whereArgs: [tid]);
    });
  }

  Future<void> updatePurchasePaymentStatus(String tid, String paymentStatus, String? dueDate, {double? paidAmount}) async {
    final db = await database;
    await db.update('purchases', 
      {
        'payment_status': paymentStatus, 
        'due_date': dueDate,
        if (paidAmount != null) 'paid_amount': paidAmount,
      },
      where: 'transaction_id = ?',
      whereArgs: [tid]
    );
  }

  Future<void> insertPurchasePayment(String tid, double amount, String date) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('purchase_payments', {
        'transaction_id': tid,
        'amount': amount,
        'date': date,
      });
    });
  }

  Future<List<PurchasePayment>> getPurchasePayments(String tid) async {
    final db = await database;
    final maps = await db.query('purchase_payments', 
      where: 'transaction_id = ?', 
      whereArgs: [tid],
      orderBy: 'date ASC',
    );
    return maps.map((m) => PurchasePayment.fromMap(m)).toList();
  }

  Future<void> updatePurchaseItem(int id, int productId, int oldQty, int newQty, double newPrice, {String? newStatus}) async {
    final db = await database;
    await db.transaction((txn) async {
      // Get old status
      final oldItem = await txn.query('purchases', where: 'id = ?', whereArgs: [id], limit: 1);
      final oldStatus = oldItem.first['status'] as String;
      final status = newStatus ?? oldStatus;

      // Handle stock logic
      if (oldStatus == 'Received' && status == 'Received') {
        final diff = newQty - oldQty;
        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
          [diff, productId],
        );
      } else if (oldStatus == 'Ordered' && status == 'Received') {
        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
          [newQty, productId],
        );
      } else if (oldStatus == 'Received' && status == 'Ordered') {
        // Revert stock
        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
          [oldQty, productId],
        );
      }

      await txn.update('purchases', {
        'quantity': newQty,
        'price': newPrice,
        if (newStatus != null) 'status': newStatus,
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deletePurchaseItem(int id, int productId, int qty) async {
    final db = await database;
    await db.transaction((txn) async {
      final item = await txn.query('purchases', where: 'id = ?', whereArgs: [id], limit: 1);
      if (item.isNotEmpty && item.first['status'] == 'Received') {
        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
          [qty, productId],
        );
      }
      await txn.delete('purchases', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── SALES ────────────────────────────────────────────────────────────────

  Future<void> updatePurchaseCommission(String tid, double totalCommission) async {
    final db = await database;
    await db.transaction((txn) async {
      final items = await txn.query('purchases', where: 'transaction_id = ?', whereArgs: [tid]);
      if (items.isEmpty) return;
      final commissionPerItem = totalCommission / items.length;
      await txn.rawUpdate('UPDATE purchases SET commission = ? WHERE transaction_id = ?', [commissionPerItem, tid]);
    });
  }

  Future<int> insertSale(Sale sale) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('sales', sale.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      // Decrease current_stock
      await txn.rawUpdate(
        'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
        [sale.quantity, sale.productId],
      );
      return id;
    });
  }

  Future<void> insertSales(List<Sale> sales) async {
    final db = await database;
    await db.transaction((txn) async {
      final tid = sales.first.transactionId ?? 'SAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final status = sales.first.status;
      final dueDate = sales.first.dueDate;
      for (final s in sales) {
        var map = s.toMap();
        map['transaction_id'] = tid;
        map['status'] = status;
        map['due_date'] = dueDate;
        map['paid_amount'] = s.paidAmount;
        await txn.insert('sales', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
        // Decrease current_stock
        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
          [s.quantity, s.productId],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSaleTransactions({String? search, DateTime? start, DateTime? end, String? status}) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];
    
    if (search != null && search.isNotEmpty) {
      where += " AND (c.name LIKE ? OR pr.name LIKE ? OR s.transaction_id LIKE ?)";
      args.add('%$search%');
      args.add('%$search%');
      args.add('%$search%');
    }
    if (start != null && end != null) {
      where += " AND date(s.date) BETWEEN date(?) AND date(?)";
      args.add(start.toIso8601String());
      args.add(end.toIso8601String());
    }
    if (status != null && status != 'All') {
      where += " AND s.status = ?";
      args.add(status);
    }

    return db.rawQuery('''
      SELECT s.transaction_id, s.date, s.status, s.due_date, s.paid_amount, c.name as customer_name, SUM(s.price * s.quantity) as total_amount, COUNT(s.id) as item_count
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN products pr ON s.product_id = pr.id
      WHERE 1=1 $where
      GROUP BY s.transaction_id
      ORDER BY s.date DESC
    ''', args);
  }

  Future<List<Sale>> getSalesByTransaction(String tid) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT s.*, pr.name AS product_name, pr.product_code, 
             c.name AS customer_name, c.contact AS customer_contact, c.address AS customer_address, c.company AS customer_company,
             b.name AS brand_name
      FROM sales s
      LEFT JOIN products pr ON s.product_id = pr.id
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN brands b ON pr.brand_id = b.id
      WHERE s.transaction_id = ?
    ''', [tid]);
    return res.map((m) => Sale.fromMap(m)).toList();
  }

  Future<List<Sale>> getSales() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.*, p.name AS product_name, p.product_code, c.name AS customer_name
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      LEFT JOIN customers c ON s.customer_id = c.id
      ORDER BY s.date DESC, s.id DESC
    ''');
    return maps.map((m) => Sale.fromMap(m)).toList();
  }

  Future<void> deleteSaleTransaction(String tid) async {
    final db = await database;
    await db.transaction((txn) async {
      final items = await txn.query('sales', where: 'transaction_id = ?', whereArgs: [tid]);
      for (var item in items) {
        final qty = item['quantity'] as int;
        final prodId = item['product_id'] as int;
        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
          [qty, prodId],
        );
      }
      await txn.delete('sales', where: 'transaction_id = ?', whereArgs: [tid]);
      await txn.delete('sale_payments', where: 'transaction_id = ?', whereArgs: [tid]);
    });
  }

  Future<void> updateSaleItem(int id, int productId, int oldQty, int newQty, double newPrice) async {
    final db = await database;
    await db.transaction((txn) async {
      final diff = newQty - oldQty;
      await txn.rawUpdate(
        'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
        [diff, productId],
      );
      await txn.update('sales', {
        'quantity': newQty,
        'price': newPrice,
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteSaleItem(int id, int productId, int qty) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
        [qty, productId],
      );
      await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> updateSaleTransactionStatus(String tid, String status, String? dueDate, {double? paidAmount}) async {
    final db = await database;
    await db.update('sales', 
      {
        'status': status, 
        'due_date': dueDate,
        if (paidAmount != null) 'paid_amount': paidAmount,
      },
      where: 'transaction_id = ?',
      whereArgs: [tid]
    );
  }

  Future<void> insertSalePayment(String tid, double amount, String date) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sale_payments', {
        'transaction_id': tid,
        'amount': amount,
        'date': date,
      });
    });
  }

  Future<List<SalePayment>> getSalePayments(String tid) async {
    final db = await database;
    final maps = await db.query('sale_payments', 
      where: 'transaction_id = ?', 
      whereArgs: [tid],
      orderBy: 'date ASC',
    );
    return maps.map((m) => SalePayment.fromMap(m)).toList();
  }

  // ─── DASHBOARD QUERIES ────────────────────────────────────────────────────

  /// Total Sales Value
  Future<double> getTotalSalesValue() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(quantity * price) as total 
      FROM sales
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalAmountCollected() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM sale_payments');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Total quantity sold across all sales
  Future<int> getTotalQuantitySold() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT SUM(quantity) as total FROM sales');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Number of products with current_stock == 0
  Future<int> getLowStockCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM products WHERE current_stock <= 5');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Total stock value
  Future<double> getTotalStockValue() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(current_stock * selling_price) as total FROM products');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Sales value for the current month
  Future<double> getCurrentMonthSalesValue() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(quantity * price) as total 
      FROM sales 
      WHERE strftime('%Y-%m', date) = strftime('%Y-%m', 'now')
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalProfit() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(s.quantity * (s.price - IFNULL((SELECT AVG(price) FROM purchases WHERE product_id = s.product_id AND status = 'Received'), 0))) as profit
      FROM sales s
    ''');
    return (result.first['profit'] as num?)?.toDouble() ?? 0.0;
  }

  /// Top 5 products by total value sold
  Future<List<Map<String, dynamic>>> getTop5Products() async {
    final db = await database;
    return db.rawQuery('''
      SELECT p.name, SUM(s.quantity * s.price) as total_sold
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      GROUP BY s.product_id
      ORDER BY total_sold DESC
      LIMIT 5
    ''');
  }

  /// Monthly sales value totals for last 6 months (for chart)
  Future<List<Map<String, dynamic>>> getMonthlySales() async {
    final db = await database;
    return db.rawQuery('''
      SELECT strftime('%Y-%m', date) as month, SUM(quantity * price) as total
      FROM sales
      WHERE date >= date('now', 'start of month', '-5 months')
      GROUP BY month
      ORDER BY month ASC
    ''');
  }

  // ─── REPORTS ──────────────────────────────────────────────────────────────

  Future<List<Purchase>> getPurchasesByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.*, pr.name AS product_name, pr.product_code, s.name AS supplier_name
      FROM purchases p
      LEFT JOIN products pr ON p.product_id = pr.id
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE p.date BETWEEN ? AND ?
      ORDER BY p.date DESC
    ''', [startDate, endDate]);
    return maps.map((m) => Purchase.fromMap(m)).toList();
  }

  Future<List<Sale>> getSalesByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.*, p.name AS product_name, p.product_code, c.name AS customer_name
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE s.date BETWEEN ? AND ?
      ORDER BY s.date DESC
    ''', [startDate, endDate]);
    return maps.map((m) => Sale.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getProfitReport(String startDate, String endDate) async {
    final db = await database;
    return db.rawQuery('''
      SELECT 
        p.name,
        p.product_code,
        SUM(s.quantity) as total_qty,
        SUM(s.quantity * s.price) as total_revenue,
        (
          SELECT AVG(price) 
          FROM purchases 
          WHERE product_id = p.id AND date <= ? AND status = 'Received'
        ) as avg_purchase_price
      FROM products p
      INNER JOIN sales s ON p.id = s.product_id
      WHERE s.date BETWEEN ? AND ?
      GROUP BY p.id
      ORDER BY total_revenue DESC
    ''', [endDate, startDate, endDate]);
  }

  // ─── AGGREGATES & EXPENSES ────────────────────────────────────────────────

  Future<Map<String, double>> getProfitAggregateValues(String startDate, String endDate) async {
    final db = await database;
    
    final purchasesResult = await db.rawQuery('''
      SELECT SUM(quantity * price) as total FROM purchases 
      WHERE date(date) BETWEEN date(?) AND date(?) AND status = 'Received'
    ''', [startDate, endDate]);
    
    final paidExpResult = await db.rawQuery('''
      SELECT SUM(amount) as total FROM expenses 
      WHERE date(date) BETWEEN date(?) AND date(?) AND status = 'Paid'
    ''', [startDate, endDate]);

    final unpaidExpResult = await db.rawQuery('''
      SELECT SUM(amount) as total FROM expenses 
      WHERE date(date) BETWEEN date(?) AND date(?) AND status = 'Unpaid'
    ''', [startDate, endDate]);

    final salesResult = await db.rawQuery('''
      SELECT 
        SUM(quantity * price) as total_rev, 
        SUM(quantity * IFNULL((
          SELECT AVG(price) 
          FROM purchases 
          WHERE product_id = sales.product_id AND date <= sales.date AND status = 'Received'
        ), 0)) as total_cogs
      FROM sales 
      WHERE date(date) BETWEEN date(?) AND date(?)
    ''', [startDate, endDate]);

    final collectedResult = await db.rawQuery('''
      SELECT SUM(amount) as total_collected
      FROM sale_payments
      WHERE date(date) BETWEEN date(?) AND date(?)
    ''', [startDate, endDate]);

    return {
      'totalPurchases': (purchasesResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'paidExpenses': (paidExpResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'unpaidExpenses': (unpaidExpResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'totalSales': (salesResult.first['total_rev'] as num?)?.toDouble() ?? 0.0,
      'totalCollected': (collectedResult.first['total_collected'] as num?)?.toDouble() ?? 0.0,
      'totalCOGS': (salesResult.first['total_cogs'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ─── EXPENSES CRUD ────────────────────────────────────────────────────────
  
  Future<int> insertExpense(Expense expense) async {

    final db = await database;
    return db.insert('expenses', expense.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final maps = await db.query('expenses', orderBy: 'date DESC, id DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return db.update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getExecutiveSummaryData(String startDate, String endDate) async {
    final db = await database;
    
    // 1. Basic Financials
    final aggregates = await getProfitAggregateValues(startDate, endDate);
    
    // 2. Commission Total
    final commResult = await db.rawQuery('''
      SELECT SUM(commission) as total FROM purchases 
      WHERE date(date) BETWEEN date(?) AND date(?)
    ''', [startDate, endDate]);
    final totalCommission = (commResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Top 5 Products by Revenue
    final topProducts = await db.rawQuery('''
      SELECT p.name, SUM(s.quantity) as total_qty, SUM(s.quantity * s.price) as revenue
      FROM sales s
      JOIN products p ON s.product_id = p.id
      WHERE date(s.date) BETWEEN date(?) AND date(?)
      GROUP BY p.id
      ORDER BY revenue DESC
      LIMIT 5
    ''', [startDate, endDate]);

    // 4. Top 5 Customers by Value
    final topCustomers = await db.rawQuery('''
      SELECT c.name, SUM(s.quantity * s.price) as total_spent
      FROM sales s
      JOIN customers c ON s.customer_id = c.id
      WHERE date(s.date) BETWEEN date(?) AND date(?)
      GROUP BY c.id
      ORDER BY total_spent DESC
      LIMIT 5
    ''', [startDate, endDate]);

    // 5. Top 5 Vendors by Value
    final topVendors = await db.rawQuery('''
      SELECT v.name, SUM(p.quantity * p.price) as total_supplied
      FROM purchases p
      JOIN suppliers v ON p.supplier_id = v.id
      WHERE date(p.date) BETWEEN date(?) AND date(?)
      GROUP BY v.id
      ORDER BY total_supplied DESC
      LIMIT 5
    ''', [startDate, endDate]);

    return {
      'aggregates': aggregates,
      'totalCommission': totalCommission,
      'topProducts': topProducts,
      'topCustomers': topCustomers,
      'topVendors': topVendors,
    };
  }
}
