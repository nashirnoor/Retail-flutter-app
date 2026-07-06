import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/customer.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import 'customer_details_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _db = DatabaseHelper();
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final customers = await _db.getCustomers();
    setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  Future<void> _showCustomerDialog([Customer? customer]) async {
    final nameCtrl = TextEditingController(text: customer?.name);
    final contactCtrl = TextEditingController(text: customer?.contact);
    final addressCtrl = TextEditingController(text: customer?.address);
    final companyCtrl = TextEditingController(text: customer?.company);

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
                   Text(customer == null ? 'Add Customer' : 'Edit Customer', 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                controller: companyCtrl,
                decoration: const InputDecoration(labelText: 'Company Name (Optional)', prefixIcon: Icon(Icons.business_rounded)),
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
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_rounded)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final contact = contactCtrl.text.trim();
                    final address = addressCtrl.text.trim();
                    final company = companyCtrl.text.trim();
                    if (name.isEmpty) return;
                    
                    if (customer == null) {
                      await _db.insertCustomer(Customer(name: name, contact: contact, address: address, company: company));
                    } else {
                      await _db.updateCustomer(Customer(id: customer.id, name: name, contact: contact, address: address, company: company));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadData();
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(customer == null ? 'Save Customer' : 'Update Customer'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteCustomer(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteCustomer(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _customers.isEmpty
              ? const EmptyState(
                  icon: Icons.people_alt_rounded,
                  message: 'No Customers Found',
                  subtitle: 'Tap the button below to add your first customer',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _customers.length,
                  itemBuilder: (ctx, i) {
                     final c = _customers[i];
                     return Container(
                       margin: const EdgeInsets.only(bottom: 12),
                       decoration: BoxDecoration(
                         color: AppColors.surface,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: AppColors.cardBorder),
                       ),
                       child: ListTile(
                         onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailsScreen(customer: c)));
                         },
                         leading: CircleAvatar(
                           backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                           child: Text(c.name[0].toUpperCase(), style: const TextStyle(color: AppColors.accent)),
                         ),
                         title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                         subtitle: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             if (c.company.isNotEmpty)
                               Text(c.company, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                             Text(c.contact, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                             if (c.address.isNotEmpty)
                               Text(c.address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                           ],
                         ),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             IconButton(
                               icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                               onPressed: () => _showCustomerDialog(c),
                             ),
                             IconButton(
                               icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                               onPressed: () => _deleteCustomer(c.id!),
                             ),
                           ],
                         ),
                       ),
                     );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Customer'),
      ),
    );
  }
}
