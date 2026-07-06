import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../database/database_helper.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';
import '../../models/purchase.dart';
import '../../models/sale.dart';
import '../../models/product.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseHelper();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: buildAppTheme(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showExecutiveSummary() async {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = '${DateFormat('yyyy-MM-dd').format(_endDate)} 23:59:59';
    
    try {
      final summary = await _db.getExecutiveSummaryData(startStr, endStr);
      if (mounted) {
        _showSummaryModal(summary);
      }
    } catch (e) {
      debugPrint('Error generating summary: $e');
    }
  }

  void _showSummaryModal(Map<String, dynamic> data) {
    final agg = data['aggregates'] as Map<String, double>;
    final totalComm = data['totalCommission'] as double;
    final topProducts = data['topProducts'] as List<Map<String, dynamic>>;
    final topCustomers = data['topCustomers'] as List<Map<String, dynamic>>;
    final topVendors = data['topVendors'] as List<Map<String, dynamic>>;

    // Calculations
    final grossProfit = agg['totalSales']! - agg['totalCOGS']!;
    final netProfit = grossProfit - agg['paidExpenses']! - totalComm;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Executive Summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              Text(
                '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              
              // Financial KPI Cards
              Row(
                children: [
                   _buildSummaryCard('REVENUE', agg['totalSales']!, Colors.blue, Icons.payments_rounded),
                   const SizedBox(width: 12),
                   _buildSummaryCard('GROSS PROFIT', grossProfit, grossProfit >= 0 ? Colors.teal : AppColors.error, Icons.account_balance_wallet_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   _buildSummaryCard('EXPENSES', agg['paidExpenses']!, AppColors.error, Icons.receipt_long_rounded),
                   const SizedBox(width: 12),
                   _buildSummaryCard('NET PROFIT', netProfit, netProfit >= 0 ? AppColors.accent : AppColors.error, Icons.auto_graph_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   _buildSummaryCard('COMMISSIONS', totalComm, Colors.orange, Icons.percent_rounded),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Top Selling Products
              _buildSectionHeader('Top Selling Products', Icons.star_rounded),
              const SizedBox(height: 12),
              ...topProducts.map((p) => _buildListItem(
                title: p['name'], 
                subtitle: 'Sold: ${p['total_qty']} units',
                amount: p['revenue'],
                color: AppColors.accent
              )),
              if (topProducts.isEmpty) _buildNoData(),

              const SizedBox(height: 32),
              
              // Top Customers
              _buildSectionHeader('Top Customers', Icons.people_alt_rounded),
              const SizedBox(height: 12),
              ...topCustomers.map((c) => _buildListItem(
                title: c['name'], 
                subtitle: 'Total Sales',
                amount: c['total_spent'],
                color: Colors.blue
              )),
              if (topCustomers.isEmpty) _buildNoData(),

              const SizedBox(height: 32),

              // Top Vendors
              _buildSectionHeader('Top Vendors (Spending)', Icons.local_shipping_rounded),
              const SizedBox(height: 12),
              ...topVendors.map((v) => _buildListItem(
                title: v['name'], 
                subtitle: 'Purchase Value',
                amount: v['total_supplied'],
                color: AppColors.primary
              )),
              if (topVendors.isEmpty) _buildNoData(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                'QAR ${value.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildListItem({required String title, required String subtitle, required double amount, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text(
              'QAR ${amount.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoData() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text('No data found for this period', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
    );
  }

  void _showReportData(String type) async {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    // Add time component to end date to ensure it covers the whole day
    final endStr = '${DateFormat('yyyy-MM-dd').format(_endDate)} 23:59:59';
    
    try {
      List<dynamic> items = [];
      Map<String, double>? aggregates;

      if (type == 'Sales') {
        items = await _db.getSalesByDateRange(startStr, endStr);
      } else if (type == 'Purchases') {
        items = await _db.getPurchasesByDateRange(startStr, endStr);
      } else if (type == 'Inventory') {
        // For inventory, we just fetch all products to show current stock
        items = await _db.getProducts();
      } else if (type == 'Profit') {
        items = await _db.getProfitReport(startStr, endStr);
        aggregates = await _db.getProfitAggregateValues(startStr, endStr);
      }

      if (mounted) {
        _showResultsModal(type, items, aggregates: aggregates);
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _shareInventoryViaWhatsApp(List<dynamic> products) async {
    String text = "*Inventory Report*\n";
    text += "Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}\n\n";
    
    for (var p in products) {
      if ((p.currentStock ?? 0) <= 0) continue;
      // Swapped SKU for Product Code
      text += "• ${p.name} (Code: ${p.productCode})\n";
      text += "  Stock: ${p.currentStock}\n\n";
    }
    
    final url = "whatsapp://send?text=${Uri.encodeComponent(text)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      final webUrl = "https://wa.me/?text=${Uri.encodeComponent(text)}";
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
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
            _startDate = start!;
            _endDate = end!;
          });
        }
      },
    );
  }

  void _showResultsModal(String title, List<dynamic> items, {Map<String, double>? aggregates}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$title Report', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          if (title == 'Inventory' && items.isNotEmpty)
                            IconButton(
                              onPressed: () => _shareInventoryViaWhatsApp(items), 
                              icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                              tooltip: 'Share to WhatsApp',
                            ),
                          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'From ${DateFormat('MMM d, yyyy').format(_startDate)} to ${DateFormat('MMM d, yyyy').format(_endDate)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                if (title == 'Profit' && aggregates != null)
                  _buildProfitAggregates(aggregates, items),
                const SizedBox(height: 10),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('No data found for this period', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder),
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            
                            if (title == 'Inventory') {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                  child: const Icon(Icons.inventory_2, color: AppColors.primary),
                                ),
                                title: Text(item.name ?? 'Unknown', style: const TextStyle(color: AppColors.textPrimary)),
                                subtitle: Text('Code: ${item.productCode}', style: const TextStyle(color: AppColors.textSecondary)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.currentStock}',
                                      style: TextStyle(
                                        color: item.currentStock <= 5 ? AppColors.error : AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Text('In Stock', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              );
                            }

                            if (title == 'Profit') {
                              final revenue = (item['total_revenue'] as num?)?.toDouble() ?? 0.0;
                              final avgCost = (item['avg_purchase_price'] as num?)?.toDouble() ?? 0.0;
                              final totalCost = avgCost * (item['total_qty'] as int);
                              final profit = revenue - totalCost;
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: profit >= 0 ? AppColors.accent.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2),
                                  child: Icon(profit >= 0 ? Icons.trending_up : Icons.trending_down, color: profit >= 0 ? AppColors.accent : AppColors.error),
                                ),
                                title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('Qty Sold: ${item['total_qty']}  •  Avg Cost: ${avgCost.toStringAsFixed(2)}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('PROFIT: QAR ${profit.toStringAsFixed(2)}', 
                                      style: TextStyle(color: profit >= 0 ? AppColors.accent : AppColors.error, fontWeight: FontWeight.bold)),
                                    Text('Rev: ${revenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ),
                              );
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: title == 'Sales' ? AppColors.accent.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
                                child: Icon(
                                  title == 'Sales' ? Icons.point_of_sale : Icons.shopping_cart,
                                  color: title == 'Sales' ? AppColors.accent : AppColors.primary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(item.productName ?? 'Unknown', style: const TextStyle(color: AppColors.textPrimary))),
                                  if (title == 'Purchases' && item is Purchase)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: (item.status == 'Received' ? AppColors.accent : AppColors.primary).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(item.status.toUpperCase(), style: TextStyle(color: item.status == 'Received' ? AppColors.accent : AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              subtitle: Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(item.date)), style: const TextStyle(color: AppColors.textSecondary)),
                              trailing: Text(
                                '${title == 'Sales' ? '-' : '+'}${item.quantity}',
                                style: TextStyle(
                                  color: title == 'Sales' ? AppColors.error : AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectPresetDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, color: AppColors.primary),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text('Tap to change', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            const Text('Generate Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            
            _buildReportCard(
              title: 'Executive Business Summary',
              desc: 'Detailed overview of KPIs, net profit, top customers, and vendors.',
              icon: Icons.analytics_rounded,
              color: Colors.deepPurple,
              onTap: _showExecutiveSummary,
            ),
            const SizedBox(height: 16),
            
            _buildReportCard(
              title: 'Sales Report',
              desc: 'View all items sold during the selected period.',
              icon: Icons.trending_up_rounded,
              color: AppColors.accent,
              onTap: () => _showReportData('Sales'),
            ),
            const SizedBox(height: 16),
            _buildReportCard(
              title: 'Purchases Report',
              desc: 'View incoming stock over the selected period.',
              icon: Icons.add_shopping_cart_rounded,
              color: AppColors.primary,
              onTap: () => _showReportData('Purchases'),
            ),
            const SizedBox(height: 16),
            _buildReportCard(
              title: 'Inventory Report',
              desc: 'View all current products and their stock levels.',
              icon: Icons.inventory_2_rounded,
              color: Colors.orange,
              onTap: () => _showReportData('Inventory'),
            ),
            const SizedBox(height: 16),
            _buildReportCard(
              title: 'Profit & Loss Report',
              desc: 'Analyze revenue vs cost and net profit per product.',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.teal,
              onTap: () => _showReportData('Profit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitAggregates(Map<String, double> agg, List<dynamic> items) {
    double totalRevenue = 0;
    double totalCOGS = 0;
    for(var item in items) {
       final rev = (item['total_revenue'] as num?)?.toDouble() ?? 0.0;
       final qty = item['total_qty'] as int;
       final avgCost = (item['avg_purchase_price'] as num?)?.toDouble() ?? 0.0;
       totalRevenue += rev;
       totalCOGS += (qty * avgCost);
    }
    double grossProfit = totalRevenue - totalCOGS;
    double netProfit = grossProfit - agg['paidExpenses']!;

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _buildAggRow('Total Revenue (Sales)', totalRevenue),
          _buildAggRow('Cost of Goods Sold (Sold Items)', totalCOGS),
          const Divider(height: 16),
          _buildAggRow('Gross Profit', grossProfit, isBold: true),
          const SizedBox(height: 8),
          _buildAggRow('Total Sales (Expected Rev.)', agg['totalSales']!),
          _buildAggRow('Amount Collected (Cash)', agg['totalCollected']!, color: AppColors.accent),
          _buildAggRow('Pending Receivables', agg['totalSales']! - agg['totalCollected']!, color: AppColors.error),
          const Divider(height: 16),
          _buildAggRow('Total Purchases (Total Acquired)', agg['totalPurchases']!),
          _buildAggRow('Paid Expenses', agg['paidExpenses']!),
          _buildAggRow('Unpaid Expenses', agg['unpaidExpenses']!, color: AppColors.error),
          const Divider(height: 16),
          _buildAggRow('Net Profit (Gross - Paid Expenses)', netProfit, isBold: true, color: netProfit >= 0 ? AppColors.accent : AppColors.error),
        ],
      ),
    );
  }

  Widget _buildAggRow(String label, double value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? AppColors.textSecondary, fontSize: isBold ? 14 : 13)),
          Text('QAR ${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? AppColors.textPrimary, fontSize: isBold ? 15 : 13)),
        ],
      ),
    );
  }
}
