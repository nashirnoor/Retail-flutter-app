import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/customer.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import 'package:intl/intl.dart';
import '../common/transaction_details_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;
  
  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final _db = DatabaseHelper();
  bool _loading = true;
  
  Map<String, dynamic> _summary = {
    'total_products_quantity': 0,
    'total_sales_amount': 0.0,
    'total_paid_amount': 0.0,
    'pending_amount': 0.0,
  };
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    final summary = await _db.getCustomerSummary(widget.customer.id!);
    final transactions = await _db.getCustomerSalesTransactions(widget.customer.id!);
    
    setState(() {
      _summary = summary;
      _transactions = transactions;
      _loading = false;
    });
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title, 
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.customer.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Top Summary Dashboard
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Pending Amount',
                              'QAR ${(_summary['pending_amount'] as double).toStringAsFixed(2)}',
                              Icons.account_balance_wallet_rounded,
                              AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Paid',
                              'QAR ${(_summary['total_paid_amount'] as double).toStringAsFixed(2)}',
                              Icons.payments_rounded,
                              AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Sales',
                              'QAR ${(_summary['total_sales_amount'] as double).toStringAsFixed(2)}',
                              Icons.trending_up_rounded,
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Items',
                              '${_summary['total_products_quantity']}',
                              Icons.inventory_2_rounded,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.cardBorder, height: 1),
                
                // Transactions List
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: const Text('Transaction History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                
                Expanded(
                  child: _transactions.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          message: 'No Transactions',
                          subtitle: 'This customer has not made any purchases yet',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                if (result == true) _loadData();
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
                                          Text('${t['item_count']} items  •  ${DateFormat('MMM dd').format(date)}', 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
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
                                              const SizedBox(width: 8),
                                              Text('ID: ${t['transaction_id']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('QAR ${total.toStringAsFixed(2)}', 
                                          style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
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
    );
  }
}
