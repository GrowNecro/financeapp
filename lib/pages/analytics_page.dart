import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final TransactionService _service = TransactionService();
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  List<TransactionModel> _transactions = [];
  Map<String, double> _categorySpending = {};
  Map<String, double> _monthlyExpenses = {};
  Map<String, double> _monthlyIncome = {};
  bool _isLoading = true;
  String _selectedPeriod = '6'; // Default 6 months

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    final transactions = await _service.getAllTransactions();
    final now = DateTime.now();
    final monthsBack = int.parse(_selectedPeriod);
    final startDate = DateTime(now.year, now.month - monthsBack, 1);

    _transactions = transactions
        .where((t) => t.date.isAfter(startDate))
        .toList();

    // Category spending (current month expenses only)
    final currentMonthStart = DateTime(now.year, now.month, 1);
    _categorySpending.clear();
    for (var transaction in _transactions) {
      if (transaction.type == TransactionType.expense &&
          transaction.date.isAfter(currentMonthStart)) {
        _categorySpending[transaction.category] =
            (_categorySpending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    // Monthly trends
    _monthlyExpenses.clear();
    _monthlyIncome.clear();
    for (var transaction in _transactions) {
      final monthKey = DateFormat('MMM yy').format(transaction.date);
      if (transaction.type == TransactionType.expense) {
        _monthlyExpenses[monthKey] =
            (_monthlyExpenses[monthKey] ?? 0) + transaction.amount;
      } else {
        _monthlyIncome[monthKey] =
            (_monthlyIncome[monthKey] ?? 0) + transaction.amount;
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalExpense = _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome = _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '1', child: Text('1 Bulan')),
              const PopupMenuItem(value: '3', child: Text('3 Bulan')),
              const PopupMenuItem(value: '6', child: Text('6 Bulan')),
              const PopupMenuItem(value: '12', child: Text('1 Tahun')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Pemasukan',
                    totalIncome,
                    Colors.green,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Pengeluaran',
                    totalExpense,
                    Colors.red,
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryCard(
              'Saldo',
              totalIncome - totalExpense,
              totalIncome >= totalExpense ? Colors.blue : Colors.orange,
              Icons.account_balance_wallet,
            ),

            const SizedBox(height: 24),

            // Category Breakdown
            if (_categorySpending.isNotEmpty) ...[
              const Text(
                'Pengeluaran per Kategori (Bulan Ini)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildCategoryPieChart(),
              const SizedBox(height: 16),
              _buildCategoryLegend(),
              const SizedBox(height: 24),
            ],

            // Monthly Trend
            if (_monthlyExpenses.isNotEmpty) ...[
              const Text(
                'Trend Bulanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildMonthlyLineChart(),
              const SizedBox(height: 24),
            ],

            // Top Spending
            const Text(
              'Top 5 Pengeluaran Terbesar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTopSpendingList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    final sections = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections.take(10).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final total = _categorySpending.values.fold(0.0, (a, b) => a + b);
            final percentage = (category.value / total * 100);

            return PieChartSectionData(
              color: colors[index % colors.length],
              value: category.value,
              title: '${percentage.toStringAsFixed(1)}%',
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 0,
        ),
      ),
    );
  }

  Widget _buildCategoryLegend() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    final sections = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: sections.take(10).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.key,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    currencyFormat.format(category.value),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthlyLineChart() {
    if (_monthlyExpenses.isEmpty && _monthlyIncome.isEmpty) {
      return const SizedBox();
    }

    final allMonths = <String>{
      ..._monthlyExpenses.keys,
      ..._monthlyIncome.keys,
    }.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMM yy').parse(a);
        final dateB = DateFormat('MMM yy').parse(b);
        return dateA.compareTo(dateB);
      });

    final expenseSpots = <FlSpot>[];
    final incomeSpots = <FlSpot>[];

    for (var i = 0; i < allMonths.length; i++) {
      final month = allMonths[i];
      expenseSpots.add(FlSpot(i.toDouble(), _monthlyExpenses[month] ?? 0));
      incomeSpots.add(FlSpot(i.toDouble(), _monthlyIncome[month] ?? 0));
    }

    final maxY = [
      ..._monthlyExpenses.values,
      ..._monthlyIncome.values,
    ].fold(0.0, (max, val) => val > max ? val : max);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value / 1000000).toStringAsFixed(0)}jt',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= allMonths.length) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      allMonths[index],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSpendingList() {
    final expenseTransactions = _transactions
        .where((t) => t.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final topFive = expenseTransactions.take(5).toList();

    if (topFive.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Belum ada data pengeluaran')),
        ),
      );
    }

    return Card(
      child: Column(
        children: topFive.asMap().entries.map((entry) {
          final index = entry.key;
          final transaction = entry.value;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withOpacity(0.1),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              transaction.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${transaction.category} • ${DateFormat('d MMM yyyy').format(transaction.date)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              currencyFormat.format(transaction.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
