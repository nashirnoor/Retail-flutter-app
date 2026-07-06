import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';

// Represents an uncommitted line item in our cart
class SaleLineItem {
  Product product;
  int quantity;
  double price;
  SaleLineItem({required this.product, required this.quantity, required this.price});
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _db = DatabaseHelper();
  List<Product> _products = [];
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  
  DateTime _selectedDate = DateTime.now();
  String _paymentStatus = 'Paid';
  final _paidAmountCtrl = TextEditingController(text: '0.0');
  DateTime? _dueDate;
  bool _loading = true;

  // The "cart" of products
  final List<SaleLineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final products = await _db.getProducts();
    final customers = await _db.getCustomers();
    setState(() {
      _products = products;
      _customers = customers;
      _loading = false;
    });
  }

  Future<void> _addQuickCustomer() async {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
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
                  const Text('Quick Add Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact Number', prefixIcon: Icon(Icons.phone_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_rounded)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final contact = contactCtrl.text.trim();
                    final address = addressCtrl.text.trim();
                    if (name.isEmpty) return;
                    
                    final newCustId = await _db.insertCustomer(Customer(
                      name: name,
                      contact: contact,
                      address: address,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    
                    // Reload customers and Auto-select new customer
                    final newCustomers = await _db.getCustomers();
                    setState(() {
                      _customers = newCustomers;
                      _selectedCustomer = _customers.firstWhere((c) => c.id == newCustId, orElse: () => _customers.last);
                    });
                  },
                  child: const Text('Save & Select'),
                ),
              )
            ],
          ),
        );
      },
    );
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        const SnackBar(content: Text('No products available to sell')),
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
                    const Text('Add Product to Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                    label: '${p.name} (Stock: ${p.currentStock})',
                  )).toList(),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity Sold', style: TextStyle(color: AppColors.textSecondary)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    label: const Text('Add to Sale'),
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

                      // Compute effective stock already in cart
                      int currentInCart = 0;
                      // Only combine if price is also same
                      final existingIndex = _lineItems.indexWhere((item) => item.product.id == selectedProduct!.id && item.price == price);
                      if (existingIndex >= 0) {
                        currentInCart = _lineItems[existingIndex].quantity;
                      } else {
                        // Still check total qty in cart for this product against stock
                        for(var item in _lineItems) {
                          if (item.product.id == selectedProduct!.id) currentInCart += item.quantity;
                        }
                      }

                      if (currentInCart + qty > selectedProduct!.currentStock) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Not enough stock available!')));
                        return;
                      }

                      setState(() {
                        if (existingIndex >= 0) {
                          _lineItems[existingIndex].quantity += qty;
                        } else {
                          _lineItems.add(SaleLineItem(product: selectedProduct!, quantity: qty, price: price));
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

  Future<void> _saveSale() async {
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate);
    final tid = 'SAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final sales = _lineItems.map((item) {
      return Sale(
        productId: item.product.id!,
        quantity: item.quantity,
        price: item.price,
        date: dateStr,
        transactionId: tid,
        customerId: _selectedCustomer?.id,
        status: _paymentStatus,
        dueDate: (_paymentStatus == 'Unpaid' || _paymentStatus == 'Partially Paid') && _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
        paidAmount: _paymentStatus == 'Paid' ? (item.price * item.quantity) : (_paymentStatus == 'Partially Paid' ? (double.tryParse(_paidAmountCtrl.text) ?? 0.0) / _lineItems.length : 0.0),
      );
    }).toList();

    await _db.insertSales(sales);

    double totalPaid = 0.0;
    if (_paymentStatus == 'Paid') {
      totalPaid = _lineItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    } else if (_paymentStatus == 'Partially Paid') {
      totalPaid = double.tryParse(_paidAmountCtrl.text) ?? 0.0;
    }

    if (totalPaid > 0) {
      await _db.insertSalePayment(tid, totalPaid, dateStr);
    }
    if (mounted) {
      Navigator.pop(context, true); // Return true indicating success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Sale')),
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
                      const Text('Sale Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Customer>(
                              value: _selectedCustomer,
                              dropdownColor: AppColors.surfaceVariant,
                              items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                              onChanged: (c) => setState(() => _selectedCustomer = c),
                              decoration: const InputDecoration(labelText: 'Customer (Optional)', prefixIcon: Icon(Icons.person_rounded)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _addQuickCustomer,
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 28),
                            tooltip: 'Add New Customer',
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Sale Date', prefixIcon: Icon(Icons.calendar_today_rounded)),
                          child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Payment Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Paid'),
                              selected: _paymentStatus == 'Paid',
                              selectedColor: AppColors.accent.withValues(alpha: 0.2),
                              labelStyle: TextStyle(color: _paymentStatus == 'Paid' ? AppColors.accent : AppColors.textSecondary),
                              onSelected: (s) => setState(() => _paymentStatus = 'Paid'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Partial'),
                              selected: _paymentStatus == 'Partially Paid',
                              selectedColor: Colors.orange.withValues(alpha: 0.2),
                              labelStyle: TextStyle(color: _paymentStatus == 'Partially Paid' ? Colors.orange : AppColors.textSecondary),
                              onSelected: (s) => setState(() => _paymentStatus = 'Partially Paid'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Unpaid'),
                              selected: _paymentStatus == 'Unpaid',
                              selectedColor: AppColors.error.withValues(alpha: 0.2),
                              labelStyle: TextStyle(color: _paymentStatus == 'Unpaid' ? AppColors.error : AppColors.textSecondary),
                              onSelected: (s) => setState(() => _paymentStatus = 'Unpaid'),
                            ),
                          ),
                        ],
                      ),
                      if (_paymentStatus == 'Partially Paid') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _paidAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount Paid Now',
                            prefixIcon: Icon(Icons.payments_rounded),
                            hintText: 'Enter amount paid by customer',
                          ),
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
                                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                    child: const Icon(Icons.point_of_sale_rounded, color: AppColors.accent, size: 20),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            icon: const Icon(Icons.shopping_cart_checkout_rounded),
            label: Text('Record Sale (${_lineItems.length} items)'),
            onPressed: _lineItems.isEmpty ? null : _saveSale,
          ),
        ),
      ),
    );
  }
}
