import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import 'new_sale_screen.dart';
import 'customer_screen.dart';
import 'package:intl/intl.dart';
import '../common/transaction_details_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadSales();
    _searchCtrl.addListener(() {
      _loadSales();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    final data = await _db.getSaleTransactions(
      search: _searchCtrl.text,
      start: _dateRange?.start,
      end: _dateRange?.end,
      status: _selectedStatus,
    );
    setState(() {
      _transactions = data;
      _loading = false;
    });
  }

  Future<void> _selectPresetDateRange() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Date Range', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildPresetButton(ctx, 'Today', DateTime.now(), DateTime.now()),
              _buildPresetButton(ctx, 'Last 7 Days', DateTime.now().subtract(const Duration(days: 7)), DateTime.now()),
              _buildPresetButton(ctx, 'This Month', DateTime(DateTime.now().year, DateTime.now().month, 1), DateTime.now()),
              _buildPresetButton(ctx, 'Last 30 Days', DateTime.now().subtract(const Duration(days: 30)), DateTime.now()),
              _buildPresetButton(ctx, 'Custom Range', null, null, isCustom: true),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadSales();
    }
  }

  Widget _buildPresetButton(BuildContext ctx, String label, DateTime? start, DateTime? end, {bool isCustom = false}) {
    return ListTile(
      title: Text(label),
      leading: Icon(isCustom ? Icons.date_range_rounded : Icons.history_rounded, color: AppColors.primary),
      onTap: () {
        Navigator.pop(ctx);
        if (isCustom) {
          _selectDateRange();
        } else {
          setState(() {
            _dateRange = DateTimeRange(start: start!, end: end!);
          });
          _loadSales();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _transactions.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_rounded,
                        message: 'No Transactions Found',
                        subtitle: 'Try adjusting your filters or record a sale',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        itemBuilder: (ctx, i) {
                          final t = _transactions[i];
                          final dateStr = t['date'] as String;
                          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                          final total = (t['total_amount'] as num?)?.toDouble() ?? 0.0;
                          
                          return InkWell(
                            onTap: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetailsScreen(
                                transactionId: t['transaction_id'],
                                date: DateFormat('yyyy-MM-dd HH:mm').format(date),
                                partnerName: t['customer_name'] ?? 'Walk-in Customer',
                                totalAmount: total,
                                isPurchase: false,
                              )));
                              if (result == true) _loadSales();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_rounded, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t['customer_name'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('${t['item_count']} items  •  ${DateFormat('MMM dd').format(date)}', 
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (t['status'] == 'Paid' ? AppColors.accent : (t['status'] == 'Partially Paid' ? Colors.orange : AppColors.error)).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                (t['status'] ?? 'Paid').toUpperCase(),
                                                style: TextStyle(
                                                  color: t['status'] == 'Paid' ? AppColors.accent : (t['status'] == 'Partially Paid' ? Colors.orange : AppColors.error),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text('ID: ${t['transaction_id']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('QAR ${total.toStringAsFixed(2)}', 
                                            style: const TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.bold)),
                                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Transaction'),
                                              content: const Text('Are you sure you want to delete this entire sale transaction? stock will be reverted.'),
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
                                            await _db.deleteSaleTransaction(t['transaction_id']);
                                            _loadSales();
                                          }
                                        },
                                      ),
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
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewSaleScreen()),
          );
          if (result == true) _loadSales();
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: AppColors.surface,
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by customer or product...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => _searchCtrl.clear()) 
                : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectPresetDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          _dateRange == null 
                            ? 'All Dates' 
                            : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_dateRange != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list_off_rounded, color: AppColors.error),
                  onPressed: () {
                    setState(() => _dateRange = null);
                    _loadSales();
                  },
                ),
              ],
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: _selectedStatus,
                onSelected: (s) {
                  setState(() => _selectedStatus = s);
                  _loadSales();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'All', child: Text('All Status')),
                  const PopupMenuItem(value: 'Paid', child: Text('Paid')),
                  const PopupMenuItem(value: 'Partially Paid', child: Text('Partially Paid')),
                  const PopupMenuItem(value: 'Unpaid', child: Text('Unpaid')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedStatus == 'All' ? Colors.transparent : (_selectedStatus == 'Paid' ? AppColors.accent : (_selectedStatus == 'Partially Paid' ? Colors.orange : AppColors.error)).withValues(alpha: 0.1),
                    border: Border.all(color: _selectedStatus == 'All' ? AppColors.cardBorder : (_selectedStatus == 'Paid' ? AppColors.accent : (_selectedStatus == 'Partially Paid' ? Colors.orange : AppColors.error))),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments_rounded, 
                        size: 18, 
                        color: _selectedStatus == 'All' ? AppColors.primary : (_selectedStatus == 'Paid' ? AppColors.accent : (_selectedStatus == 'Partially Paid' ? Colors.orange : AppColors.error))
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedStatus,
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedStatus == 'All' ? Colors.white : (_selectedStatus == 'Paid' ? AppColors.accent : (_selectedStatus == 'Partially Paid' ? Colors.orange : AppColors.error)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Sales'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history_rounded), text: 'History'),
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Customers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SalesHistoryScreen(),
            CustomerScreen(),
          ],
        ),
      ),
    );
  }
}
