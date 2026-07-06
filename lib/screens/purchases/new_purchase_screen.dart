import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';
import '../../models/product.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';

// Represents an uncommitted line item in our cart
class PurchaseLineItem {
  Product product;
  int quantity;
  double price;
  PurchaseLineItem({required this.product, required this.quantity, required this.price});
}

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final _db = DatabaseHelper();
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  
  Supplier? _selectedSupplier;
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'Received'; // Default delivery status
  String _paymentStatus = 'Paid'; // Default payment status
  DateTime? _dueDate;
  bool _loading = true;

  // The "cart" of products
  final List<PurchaseLineItem> _lineItems = [];
  final TextEditingController _commissionCtrl = TextEditingController(text: '0.0');
  final TextEditingController _paidAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final suppliers = await _db.getSuppliers();
    final products = await _db.getProducts();
    setState(() {
      _suppliers = suppliers;
      _products = products;
      if (_suppliers.isNotEmpty) _selectedSupplier = _suppliers.first;
      _loading = false;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: buildAppTheme(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: buildAppTheme(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _showAddProductModal() {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available to add')),
      );
      return;
    }

    Product? selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: selectedProduct?.sellingPrice.toString() ?? '0.0');

    showModalBottomSheet(
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Product to Purchase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                
                const Text('Select Product', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownMenu<Product>(
                  width: MediaQuery.of(ctx).size.width - 40,
                  menuHeight: 250,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.inventory_2_rounded, color: AppColors.textSecondary),
                  label: const Text('Search or Select Product'),
                  onSelected: (p) {
                    setBS(() {
                      selectedProduct = p;
                      priceCtrl.text = p?.sellingPrice.toString() ?? '0.0';
                    });
                  },
                  dropdownMenuEntries: _products.map((p) => DropdownMenuEntry(
                    value: p,
                    label: '${p.name} (Code: ${p.productCode})',
                  )).toList(),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity', style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.numbers_rounded)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unit Price (QAR)', style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.payments_rounded)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Add to List'),
                    onPressed: () {
                      if (selectedProduct == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a product')));
                        return;
                      }
                      final qty = int.tryParse(qtyCtrl.text) ?? 0;
                      final price = double.tryParse(priceCtrl.text) ?? 0.0;
                      if (qty <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Quantity must be > 0')));
                        return;
                      }

                      setState(() {
                        // Check if product already exists with same price
                        final existingIndex = _lineItems.indexWhere((item) => item.product.id == selectedProduct!.id && item.price == price);
                        if (existingIndex >= 0) {
                          _lineItems[existingIndex].quantity += qty;
                        } else {
                          _lineItems.add(PurchaseLineItem(product: selectedProduct!, quantity: qty, price: price));
                        }
                      });
                      Navigator.pop(ctx);
                    },
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

  Future<void> _savePurchase() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select supplier')),
      );
      return;
    }
    
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate);
    final supplierId = _selectedSupplier!.id!;
    final totalCommission = double.tryParse(_commissionCtrl.text) ?? 0.0;
    final commissionPerItem = _lineItems.isNotEmpty ? totalCommission / _lineItems.length : 0.0;
    final tid = 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final purchases = _lineItems.map((item) {
      return Purchase(
        productId: item.product.id!,
        supplierId: supplierId,
        quantity: item.quantity,
        price: item.price,
        date: dateStr,
        transactionId: tid,
        status: _selectedStatus,
        commission: commissionPerItem,
        paymentStatus: _paymentStatus,
        dueDate: (_paymentStatus == 'Unpaid' || _paymentStatus == 'Partially Paid') && _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
        paidAmount: _paymentStatus == 'Paid' ? (item.price * item.quantity + commissionPerItem) : (_paymentStatus == 'Partially Paid' ? (double.tryParse(_paidAmountCtrl.text) ?? 0.0) / _lineItems.length : 0.0),
      );
    }).toList();

    await _db.insertPurchases(purchases);

    double totalPaid = 0.0;
    if (_paymentStatus == 'Paid') {
      totalPaid = _lineItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity)) + totalCommission;
    } else if (_paymentStatus == 'Partially Paid') {
      totalPaid = double.tryParse(_paidAmountCtrl.text) ?? 0.0;
    }

    if (totalPaid > 0) {
      await _db.insertPurchasePayment(tid, totalPaid, dateStr);
    }

    if (mounted) {
      Navigator.pop(context, true); // Return true indicating success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Purchase')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Purchase Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Supplier>(
                        value: _selectedSupplier,
                        dropdownColor: AppColors.surfaceVariant,
                        items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (s) => setState(() => _selectedSupplier = s),
                        decoration: const InputDecoration(labelText: 'Supplier', prefixIcon: Icon(Icons.business_rounded)),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Purchase Date', prefixIcon: Icon(Icons.calendar_today_rounded)),
                          child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commissionCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Total Commission Paid (Optional)', prefixIcon: Icon(Icons.monetization_on_rounded)),
                      ),
                      const SizedBox(height: 16),
                      const Text('Delivery Status', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Received', label: Text('Direct Purchase'), icon: Icon(Icons.check_circle_rounded)),
                            ButtonSegment(value: 'Ordered', label: Text('Purchase Order'), icon: Icon(Icons.hourglass_bottom_rounded)),
                          ],
                          selected: {_selectedStatus},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _selectedStatus = newSelection.first;
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: _selectedStatus == 'Received' ? AppColors.accent.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
                            selectedForegroundColor: _selectedStatus == 'Received' ? AppColors.accent : AppColors.primary,
                          ),
                        ),
                      ),
                      if (_selectedStatus == 'Ordered') 
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Note: Purchase Orders do not increase stock levels until marked as received.', 
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                        ),
                      
                      const SizedBox(height: 16),
                      const Text('Payment Status', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Paid', label: Text('Paid'), icon: Icon(Icons.check_circle_rounded)),
                            ButtonSegment(value: 'Partially Paid', label: Text('Partial'), icon: Icon(Icons.timelapse_rounded)),
                            ButtonSegment(value: 'Unpaid', label: Text('Unpaid'), icon: Icon(Icons.cancel_rounded)),
                          ],
                          selected: {_paymentStatus},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _paymentStatus = newSelection.first;
                              if (_paymentStatus == 'Paid') {
                                _paidAmountCtrl.clear();
                                _dueDate = null;
                              }
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: _paymentStatus == 'Paid' ? AppColors.accent.withValues(alpha: 0.2) : (_paymentStatus == 'Partially Paid' ? Colors.orange.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2)),
                            selectedForegroundColor: _paymentStatus == 'Paid' ? AppColors.accent : (_paymentStatus == 'Partially Paid' ? Colors.orange : AppColors.error),
                          ),
                        ),
                      ),
                      if (_paymentStatus == 'Partially Paid') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _paidAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount Paid (QAR)', prefixIcon: Icon(Icons.payments_rounded)),
                        ),
                      ],
                      if (_paymentStatus == 'Unpaid' || _paymentStatus == 'Partially Paid') ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _selectDueDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Due Date', prefixIcon: Icon(Icons.event_note_rounded)),
                            child: Text(_dueDate == null ? 'Select Due Date' : DateFormat('yyyy-MM-dd').format(_dueDate!)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const Divider(color: AppColors.cardBorder, height: 1),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: _showAddProductModal,
                        icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                        label: const Text('Add Product', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _lineItems.isEmpty
                      ? const Center(child: Text('No products added yet', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _lineItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final item = _lineItems[i];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${item.product.name} - QAR ${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text('QTY: ${item.quantity}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                    onPressed: () {
                                      setState(() {
                                        _lineItems.removeAt(i);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            icon: Icon(_selectedStatus == 'Received' ? Icons.save_rounded : Icons.history_edu_rounded),
            label: Text(_selectedStatus == 'Received' ? 'Save Purchase (${_lineItems.length} items)' : 'Create Order (${_lineItems.length} items)'),
            onPressed: _lineItems.isEmpty ? null : _savePurchase,
          ),
        ),
      ),
    );
  }
}
