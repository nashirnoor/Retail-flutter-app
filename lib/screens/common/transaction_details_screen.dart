import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/purchase.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../theme.dart';
import '../../services/invoice_service.dart';
import '../../models/sale_payment.dart';
import '../../models/purchase_payment.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final String transactionId;
  final String date;
  final String partnerName;
  final double totalAmount;
  final bool isPurchase;

  const TransactionDetailsScreen({
    super.key,
    required this.transactionId,
    required this.date,
    required this.partnerName,
    required this.totalAmount,
    required this.isPurchase,
  });

  @override
  State<TransactionDetailsScreen> createState() => _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  final _db = DatabaseHelper();
  List<dynamic> _items = [];
  List<Product> _allProducts = [];
  List<dynamic> _payments = [];
  bool _anyChanges = false;
  double _totalAmount = 0;
  double _totalCommission = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _db.getProducts();
    setState(() => _allProducts = products);
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    List<dynamic> items;
    List<dynamic> payments = [];
    if (widget.isPurchase) {
      items = await _db.getPurchasesByTransaction(widget.transactionId);
      payments = await _db.getPurchasePayments(widget.transactionId);
    } else {
      items = await _db.getSalesByTransaction(widget.transactionId);
      payments = await _db.getSalePayments(widget.transactionId);
    }

    double total = 0;
    double totalCommission = 0;
    for (var item in items) {
      final qty = widget.isPurchase ? (item as Purchase).quantity : (item as Sale).quantity;
      final price = widget.isPurchase ? (item as Purchase).price : (item as Sale).price;
      total += qty * price;
      if (widget.isPurchase) {
        totalCommission += (item as Purchase).commission;
      }
    }

    setState(() {
      _items = items;
      _payments = payments;
      _totalAmount = total + totalCommission;
      _totalCommission = totalCommission;
      _loading = false;
    });
  }

  Future<void> _printInvoice() async {
    final company = await _db.getCompanyProfile();
    if (widget.isPurchase) {
      await InvoiceService.generatePurchaseInvoice(
        company: company,
        supplier: {'name': widget.partnerName, 'address': '', 'contact': ''},
        items: _items.cast<Purchase>(),
        transactionId: widget.transactionId,
        date: widget.date,
      );
    } else {
      final sale = _items.first as Sale;
      await InvoiceService.generateSaleInvoice(
        company: company,
        customer: {
          'name': widget.partnerName, 
          'contact': sale.customerContact ?? '', 
          'address': sale.customerAddress ?? '',
          'company': sale.customerCompany ?? ''
        },
        items: _items.cast<Sale>(),
        transactionId: widget.transactionId,
        date: widget.date,
      );
    }
  }

  Future<void> _shareInvoice() async {
    final company = await _db.getCompanyProfile();
    if (widget.isPurchase) {
      await InvoiceService.sharePurchaseInvoice(
        company: company,
        supplier: {'name': widget.partnerName, 'address': '', 'contact': ''},
        items: _items.cast<Purchase>(),
        transactionId: widget.transactionId,
        date: widget.date,
      );
    } else {
      final sale = _items.first as Sale;
      await InvoiceService.shareSaleInvoice(
        company: company,
        customer: {
          'name': widget.partnerName, 
          'contact': sale.customerContact ?? '', 
          'address': sale.customerAddress ?? '',
          'company': sale.customerCompany ?? ''
        },
        items: _items.cast<Sale>(),
        transactionId: widget.transactionId,
        date: widget.date,
      );
    }
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this entire transaction? This will also revert the stock levels of all products involved (only if already received).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (widget.isPurchase) {
        await _db.deletePurchaseTransaction(widget.transactionId);
      } else {
        await _db.deleteSaleTransaction(widget.transactionId);
      }
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _editPurchaseCommission() async {
    final commissionCtrl = TextEditingController(text: _totalCommission.toStringAsFixed(2));
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Commission'),
        content: TextField(
          controller: commissionCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Total Commission Amount', prefixIcon: Icon(Icons.monetization_on_rounded)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newCommission = double.tryParse(commissionCtrl.text) ?? 0.0;
      await _db.updatePurchaseCommission(widget.transactionId, newCommission);
      _anyChanges = true;
      _loadItems();
    }
  }

  Future<void> _editItem(dynamic item) async {
    final isPurchase = widget.isPurchase;
    int id = isPurchase ? (item as Purchase).id! : (item as Sale).id!;
    int productId = isPurchase ? (item as Purchase).productId : (item as Sale).productId;
    int oldQty = isPurchase ? (item as Purchase).quantity : (item as Sale).quantity;
    double oldPrice = isPurchase ? (item as Purchase).price : (item as Sale).price;
    String name = isPurchase ? (item as Purchase).productName ?? '' : (item as Sale).productName ?? '';

    final qtyCtrl = TextEditingController(text: oldQty.toString());
    final priceCtrl = TextEditingController(text: oldPrice.toStringAsFixed(2));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Item: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newQty = int.tryParse(qtyCtrl.text) ?? oldQty;
      final newPrice = double.tryParse(priceCtrl.text) ?? oldPrice;

      if (isPurchase) {
        await _db.updatePurchaseItem(id, productId, oldQty, newQty, newPrice);
      } else {
        await _db.updateSaleItem(id, productId, oldQty, newQty, newPrice);
      }
      _anyChanges = true;
      _loadItems();
    }
  }

  Future<void> _deleteItem(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Remove this item from the transaction and revert its stock (if received)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (widget.isPurchase) {
        final p = item as Purchase;
        await _db.deletePurchaseItem(p.id!, p.productId, p.quantity);
      } else {
        final s = item as Sale;
        await _db.deleteSaleItem(s.id!, s.productId, s.quantity);
      }
      _anyChanges = true;
      _loadItems();
    }
  }

  void _showAddItemModal() {
    if (_allProducts.isEmpty) return;

    Product? selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '0.0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setBS) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownMenu<Product>(
                    width: MediaQuery.of(ctx).size.width - 40,
                    menuHeight: 250,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    label: const Text('Search or Select Product'),
                    onSelected: (p) {
                      setBS(() {
                        selectedProduct = p;
                        priceCtrl.text = p?.sellingPrice.toString() ?? '0.0';
                      });
                    },
                    dropdownMenuEntries: _allProducts.map((p) => DropdownMenuEntry(
                      value: p,
                      label: '${p.name} (Code: ${p.productCode})',
                    )).toList(),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedProduct == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a product')));
                        return;
                      }
                      final qty = int.tryParse(qtyCtrl.text) ?? 0;
                      final price = double.tryParse(priceCtrl.text) ?? 0.0;
                      if (qty <= 0) return;

                      if (_items.isEmpty) {
                        Navigator.pop(ctx);
                        return;
                      }

                      if (widget.isPurchase) {
                        final first = _items.first as Purchase;
                        await _db.insertPurchases([Purchase(
                          productId: selectedProduct!.id!,
                          supplierId: first.supplierId,
                          quantity: qty,
                          price: price,
                          transactionId: widget.transactionId,
                          date: widget.date,
                          status: first.status, // Match existing status
                        )]);
                      } else {
                        final first = _items.first as Sale;
                        await _db.insertSales([Sale(
                          productId: selectedProduct!.id!,
                          customerId: first.customerId,
                          quantity: qty,
                          price: price,
                          transactionId: widget.transactionId,
                          date: widget.date,
                        )]);
                      }
                      
                      _anyChanges = true;
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadItems();
                    },
                    child: const Text('Add to Transaction'),
                  ),
                ),
              ],
            ),
            ),
          );
        });
      },
    );
  }
  Future<void> _addPayment() async {
    if (_items.isEmpty) return;
    
    double currentPaid = _payments.fold(0.0, (sum, p) => sum + p.amount);
    double remaining = _totalAmount - currentPaid;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This transaction is already fully paid')));
      return;
    }

    final paidCtrl = TextEditingController(text: remaining.toStringAsFixed(2));
    DateTime selectedPaymentDate = DateTime.now();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remaining Balance: QAR ${remaining.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: paidCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Payment Amount', prefixIcon: Icon(Icons.payments_rounded)),
                ),
                const SizedBox(height: 16),
                const Text('Payment Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedPaymentDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedPaymentDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd').format(selectedPaymentDate)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  final val = double.tryParse(paidCtrl.text) ?? 0.0;
                  Navigator.pop(ctx, {'amount': val, 'date': selectedPaymentDate});
                },
                child: const Text('Add Payment'),
              ),
            ],
          );
        }
      ),
    );

    if (result != null && (result['amount'] as double) > 0) {
      final amt = result['amount'] as double;
      final dt = result['date'] as DateTime;
      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      
      double newPaid = currentPaid + amt;
      String newStatus = newPaid >= _totalAmount ? 'Paid' : 'Partially Paid';
      
      if (widget.isPurchase) {
        await _db.insertPurchasePayment(widget.transactionId, amt, dateStr);
        String? dueDate = (_items.first as Purchase).dueDate;
        if (newStatus == 'Paid') dueDate = null;
        await _db.updatePurchasePaymentStatus(widget.transactionId, newStatus, dueDate, paidAmount: newPaid);
      } else {
        await _db.insertSalePayment(widget.transactionId, amt, dateStr);
        String? dueDate = (_items.first as Sale).dueDate;
        if (newStatus == 'Paid') dueDate = null;
        await _db.updateSaleTransactionStatus(widget.transactionId, newStatus, dueDate, paidAmount: newPaid);
      }
      
      _anyChanges = true;
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isPurchase ? 'Purchase Details' : 'Sale Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _anyChanges),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _deleteTransaction,
            tooltip: 'Delete Transaction',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareInvoice,
            tooltip: 'Share/Download PDF',
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: _printInvoice,
            tooltip: 'Print Invoice',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildHeader(),
                const Divider(height: 1, color: AppColors.cardBorder),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _showAddItemModal,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildItemsList()),
                if (_payments.isNotEmpty)
                  _buildPaymentHistory(),
                _buildSummary(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    String status = 'Received';
    if (widget.isPurchase) {
      status = (_items.isNotEmpty && _items.first is Purchase) ? (_items.first as Purchase).status : 'Received';
    } else {
      status = (_items.isNotEmpty && _items.first is Sale) ? (_items.first as Sale).status : 'Paid';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.isPurchase ? 'Supplier' : 'Customer',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(widget.partnerName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: () {
                  String status = '';
                  String paymentStatus = '';
                  double paidAmount = 0.0;
                  String? dueDate;
                  
                  if (_items.isNotEmpty) {
                    if (widget.isPurchase) {
                      status = (_items.first as Purchase).status;
                      paymentStatus = (_items.first as Purchase).paymentStatus;
                      paidAmount = (_items.first as Purchase).paidAmount;
                      dueDate = (_items.first as Purchase).dueDate;
                    } else {
                      status = (_items.first as Sale).status;
                      paymentStatus = status; // For sales, status is payment status
                      paidAmount = (_items.first as Sale).paidAmount;
                      dueDate = (_items.first as Sale).dueDate;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Payment Status Chip
                          InkWell(
                            onTap: _addPayment,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (paymentStatus == 'Paid' ? AppColors.accent : AppColors.error).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    paymentStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: paymentStatus == 'Paid' ? AppColors.accent : (paymentStatus == 'Partially Paid' ? Colors.orange : AppColors.error),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (paymentStatus != 'Paid') ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.add_circle_outline_rounded, size: 12, color: Colors.orange),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (widget.isPurchase) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (status == 'Received' ? AppColors.primary : Colors.orange).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'Received' ? AppColors.primary : Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (paymentStatus == 'Partially Paid')
                        Text(
                          'Paid: QAR ${paidAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 2),
                      Text('ID: ${widget.transactionId}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  );
                }(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(widget.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                  if ((_items.isNotEmpty && widget.isPurchase ? (_items.first as Purchase).paymentStatus : (_items.isNotEmpty ? (_items.first as Sale).status : '')) != 'Paid' && _items.isNotEmpty && (widget.isPurchase ? (_items.first as Purchase).dueDate : (_items.first as Sale).dueDate) != null)
                    Row(
                      children: [
                        const Icon(Icons.event_note_rounded, size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Text('Due: ${widget.isPurchase ? (_items.first as Purchase).dueDate : (_items.first as Sale).dueDate}', style: const TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),],
                ),
          if (widget.isPurchase && _items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_totalCommission > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'COMMISSION: QAR ${_totalCommission.toStringAsFixed(2)}', 
                          style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(),
                TextButton.icon(
                  onPressed: _editPurchaseCommission,
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit Commission'),
                ),
              ],
            ),
          ],
          if (!widget.isPurchase && status == 'Partially Paid' && _items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'PENDING BALANCE: QAR ${(widget.totalAmount - (_items.first as Sale).paidAmount).toStringAsFixed(2)}', 
                        style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (widget.isPurchase && status == 'Ordered')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Mark as Received & Update Stock'),
                  onPressed: () async {
                    for (var item in _items) {
                      final p = item as Purchase;
                      await _db.updatePurchaseItem(p.id!, p.productId, p.quantity, p.quantity, p.price, newStatus: 'Received');
                    }
                    _anyChanges = true;
                    _loadItems();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order received. Inventory updated.'), backgroundColor: AppColors.accent),
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final item = _items[i];
        final name = widget.isPurchase ? (item as Purchase).productName : (item as Sale).productName;
        final qty = widget.isPurchase ? (item as Purchase).quantity : (item as Sale).quantity;
        final price = widget.isPurchase ? (item as Purchase).price : (item as Sale).price;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name ?? 'Unknown Product', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Qty: $qty x QAR ${price.toStringAsFixed(2)}', 
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  Text('QAR ${(qty * price).toStringAsFixed(2)}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              const Divider(height: 24, color: AppColors.cardBorder),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editItem(item),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                    label: const Text('Delete', style: TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentHistory() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ExpansionTile(
        title: const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: [
          for (var i = 0; i < _payments.length; i++) ...[
            Builder(
              builder: (ctx) {
                dynamic p = _payments[i];
                final date = DateTime.tryParse(p.date) ?? DateTime.now();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(DateFormat('MMM dd, yyyy HH:mm').format(date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ),
                      Text('QAR ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _printPaymentReceipt(p.amount, date),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        tooltip: 'Print Receipt',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }
            ),
            if (i < _payments.length - 1) const Divider(height: 12, color: AppColors.cardBorder),
          ]
        ],
      ),
    );
  }

  Future<void> _printPaymentReceipt(double amount, DateTime date) async {
    final company = await _db.getCompanyProfile();
    
    Map<String, dynamic> partner = {'name': widget.partnerName, 'contact': '', 'address': '', 'company': ''};
    if (!widget.isPurchase && _items.isNotEmpty) {
      final sale = _items.first as Sale;
      partner = {
        'name': widget.partnerName,
        'contact': sale.customerContact ?? '',
        'address': sale.customerAddress ?? '',
        'company': sale.customerCompany ?? ''
      };
    }

    double currentPaid = _payments.fold(0.0, (sum, p) => sum + p.amount);
    double remaining = _totalAmount - currentPaid;
    if (remaining < 0) remaining = 0;

    await InvoiceService.generatePaymentReceipt(
      company: company,
      partner: partner,
      transactionId: widget.transactionId,
      amount: amount,
      date: DateFormat('yyyy-MM-dd HH:mm').format(date),
      isPurchase: widget.isPurchase,
      remainingBalance: remaining,
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('QAR ${_totalAmount.toStringAsFixed(2)}', 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}
