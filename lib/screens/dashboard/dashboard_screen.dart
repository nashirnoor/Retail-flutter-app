import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../theme.dart';
import '../../widgets/stat_card.dart';
import '../settings/company_profile_screen.dart';
import '../expenses/expense_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper();

  String _companyName = 'Dashboard';
  double _totalSalesValue = 0;
  double _currentMonthSalesValue = 0;
  int _lowStock = 0;
  double _totalStockValue = 0;
  List<Map<String, dynamic>> _top5 = [];
  List<FlSpot> _chartSpots = [];
  List<String> _chartLabels = [];
  double _chartMaxY = 100;
  double _totalProfit = 0;
  double _totalReceivables = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (!_loading) setState(() => _loading = true);
    
    try {
      // Parallel fetching for performance
      final results = await Future.wait([
        _db.getCompanyProfile(),
        _db.getTotalSalesValue(),
        _db.getCurrentMonthSalesValue(),
        _db.getLowStockCount(),
        _db.getTotalStockValue(),
        _db.getTop5Products(),
        _db.getMonthlySales(),
        _db.getTotalProfit(),
        _db.getTotalAmountCollected(),
      ]);

      final company = results[0] as Map<String, dynamic>;
      final totalSales = results[1] as double;
      final monthSales = results[2] as double;
      final lowStock = results[3] as int;
      final totalStock = results[4] as double;
      final top5 = results[5] as List<Map<String, dynamic>>;
      final monthly = results[6] as List<Map<String, dynamic>>;
      final totalProfit = results[7] as double;
      final totalCollected = results[8] as double;

      // Build chart data
      final spots = <FlSpot>[];
      final labels = <String>[];
      for (int i = 0; i < monthly.length; i++) {
        final m = monthly[i];
        spots.add(FlSpot(i.toDouble(), (m['total'] as num?)?.toDouble() ?? 0.0));
        final parts = (m['month'] as String).split('-');
        final monthNum = (parts.length > 1) ? (int.tryParse(parts[1]) ?? 1) : 1;
        const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        labels.add(monthNum < monthNames.length ? monthNames[monthNum] : '???');
      }

      setState(() {
        _companyName = company['name'] ?? 'InvoEase';
        _totalSalesValue = totalSales;
        _currentMonthSalesValue = monthSales;
        _lowStock = lowStock;
        _totalStockValue = totalStock;
        _top5 = top5;
        _chartSpots = spots;
        _chartLabels = labels;
        _chartMaxY = spots.isEmpty ? 100 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.3;
        if (_chartMaxY == 0) _chartMaxY = 100;
        _totalProfit = totalProfit;
        _totalReceivables = totalSales - totalCollected;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_loading ? 'Loading...' : _companyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_rounded),
            tooltip: 'Expenses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded),
            tooltip: 'Company Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
              ).then((_) => loadData()); // Refresh if company profile changed
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildStatGrid(),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 8),
                        RepaintBoundary(child: _buildChartSection()),
                        const SizedBox(height: 24),
                        RepaintBoundary(child: _buildTop5Section()),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your inventory performance',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 145,
      ),
      delegate: SliverChildListDelegate([
        StatCard(
          label: 'Total Sales',
          value: 'QAR ${_totalSalesValue.toStringAsFixed(2)}',
          icon: Icons.attach_money_rounded,
          color: AppColors.primary,
        ),
        StatCard(
          label: 'This Month',
          value: 'QAR ${_currentMonthSalesValue.toStringAsFixed(2)}',
          icon: Icons.show_chart_rounded,
          color: AppColors.accent,
        ),
        StatCard(
          label: 'Total Profit',
          value: 'QAR ${_totalProfit.toStringAsFixed(2)}',
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.teal,
        ),
        StatCard(
          label: 'Receivables',
          value: 'QAR ${_totalReceivables.toStringAsFixed(2)}',
          icon: Icons.pending_actions_rounded,
          color: Colors.orange,
        ),
        StatCard(
          label: 'Stock Value',
          value: 'QAR ${_totalStockValue.toStringAsFixed(2)}',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFFFFB74D),
        ),
        StatCard(
          label: 'Low Stock Items',
          value: _lowStock.toString(),
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
        ),
      ]),
    );
  }

  Widget _buildChartSection() {
    // Dynamic interval to prevent thousands of grid lines/titles when value is large
    final double gridInterval = _chartMaxY / 4;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Sales',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text('Last 6 months',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: _chartSpots.isEmpty
                ? Center(
                    child: Text('No sales data yet',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : AbsorbPointer(
                    child: BarChart(
                      swapAnimationDuration: Duration.zero,
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _chartMaxY,
                        barTouchData: BarTouchData(enabled: false),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: gridInterval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppColors.cardBorder,
                            strokeWidth: 0.5,
                          ),
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= _chartLabels.length) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    _chartLabels[idx],
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: gridInterval,
                              getTitlesWidget: (v, meta) {
                                if (v == meta.max || v == meta.min) return const SizedBox.shrink();
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    'QAR ${v.toInt()}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10),
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        barGroups: _chartSpots.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.y,
                                color: AppColors.primary,
                                width: 22,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: _chartMaxY,
                                  color: AppColors.primary.withValues(alpha: 0.05),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTop5Section() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 Selling Products',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _top5.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No sales recorded yet',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : Column(
                  children: _top5.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final rank = i + 1;
                    final colors = [
                      const Color(0xFFFFD700),
                      const Color(0xFFC0C0C0),
                      const Color(0xFFCD7F32),
                      AppColors.primary,
                      AppColors.primary,
                    ];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colors[i].withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '#$rank',
                                    style: TextStyle(
                                      color: colors[i],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'QAR ${(item['total_sold'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < _top5.length - 1)
                          const Divider(height: 1, color: AppColors.cardBorder),
                      ],
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}
