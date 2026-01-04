import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';
import '../widgets/custom_number_keyboard.dart';

class FinancialPlannerPage extends StatefulWidget {
  const FinancialPlannerPage({super.key});

  @override
  State<FinancialPlannerPage> createState() => _FinancialPlannerPageState();
}

class _FinancialPlannerPageState extends State<FinancialPlannerPage> {
  final TransactionService _service = TransactionService();
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Budget planning
  double _monthlyBudget = 0;
  Map<String, double> _categoryBudgets = {};

  // Savings target
  double _savingsTarget = 0;
  double _currentSavings = 0;

  // Current month data
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  Map<String, double> _categorySpending = {};

  @override
  void initState() {
    super.initState();
    _loadPlannerData();
  }

  Future<void> _loadPlannerData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load budget settings
    _monthlyBudget = prefs.getDouble('monthly_budget') ?? 0;
    _savingsTarget = prefs.getDouble('savings_target') ?? 0;
    _currentSavings = prefs.getDouble('current_savings') ?? 0;

    // Load category budgets
    final categories = [
      'Makanan',
      'Transport',
      'Belanja',
      'Tabungan',
      'Hiburan',
      'Tagihan',
      'Lainnya',
    ];
    for (var category in categories) {
      _categoryBudgets[category] = prefs.getDouble('budget_$category') ?? 0;
    }

    // Calculate current month data
    await _calculateMonthlyData();

    setState(() {});
  }

  Future<void> _calculateMonthlyData() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final transactions = await _service.getAllTransactions();

    _monthlyIncome = 0;
    _monthlyExpense = 0;
    _categorySpending.clear();

    for (var transaction in transactions) {
      if (transaction.date.isAfter(
            firstDay.subtract(const Duration(days: 1)),
          ) &&
          transaction.date.isBefore(lastDay.add(const Duration(days: 1)))) {
        if (transaction.type.toString().contains('income')) {
          _monthlyIncome += transaction.amount;
        } else {
          _monthlyExpense += transaction.amount;
          _categorySpending[transaction.category] =
              (_categorySpending[transaction.category] ?? 0) +
              transaction.amount;
        }
      }
    }
  }

  Future<void> _savePlannerData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', _monthlyBudget);
    await prefs.setDouble('savings_target', _savingsTarget);
    await prefs.setDouble('current_savings', _currentSavings);

    for (var entry in _categoryBudgets.entries) {
      await prefs.setDouble('budget_${entry.key}', entry.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savingsProgress = _savingsTarget > 0
        ? (_currentSavings / _savingsTarget).clamp(0.0, 1.0)
        : 0.0;
    final budgetUsed = _monthlyBudget > 0
        ? (_monthlyExpense / _monthlyBudget).clamp(0.0, 1.0)
        : 0.0;
    final monthName = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlannerData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Monthly Budget Card
            _buildBudgetCard(
              title: 'Budget Bulanan',
              subtitle: monthName,
              amount: _monthlyBudget,
              spent: _monthlyExpense,
              progress: budgetUsed,
              icon: Icons.account_balance_wallet,
              color: budgetUsed > 0.8 ? Colors.red : Colors.blue,
            ),

            const SizedBox(height: 16),

            // Savings Target Card
            _buildSavingsCard(
              title: 'Target Tabungan',
              target: _savingsTarget,
              current: _currentSavings,
              progress: savingsProgress,
            ),

            const SizedBox(height: 24),

            // Monthly Summary
            _buildMonthlySummary(),

            const SizedBox(height: 24),

            // Category Budgets
            const Text(
              'Budget per Kategori',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ..._categoryBudgets.entries.map((entry) {
              final spent = _categorySpending[entry.key] ?? 0;
              final budget = entry.value;
              final progress = budget > 0
                  ? (spent / budget).clamp(0.0, 1.0)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCategoryBudgetCard(
                  category: entry.key,
                  budget: budget,
                  spent: spent,
                  progress: progress,
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            // Add budget button
            OutlinedButton.icon(
              onPressed: _showCategoryBudgetDialog,
              icon: const Icon(Icons.add),
              label: const Text('Atur Budget Kategori'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard({
    required String title,
    required String subtitle,
    required double amount,
    required double spent,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    final remaining = amount - spent;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showBudgetDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              currencyFormat.format(amount),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  progress > 0.8
                      ? Colors.red
                      : (progress > 0.5 ? Colors.orange : Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terpakai',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      currencyFormat.format(spent),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Sisa',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      currencyFormat.format(remaining > 0 ? remaining : 0),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: remaining < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsCard({
    required String title,
    required double target,
    required double current,
    required double progress,
  }) {
    final remaining = target - current;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: const Icon(Icons.savings, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _showSavingsDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      currencyFormat.format(target),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Terkumpul',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      currencyFormat.format(current),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${(progress * 100).toStringAsFixed(1)}% tercapai',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Kurang ${currencyFormat.format(remaining)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_monthlyIncome > _monthlyExpense && _monthlyIncome > 0)
                Center(
                  child: Text(
                    'Dengan sisa Rp ${currencyFormat.format(_monthlyIncome - _monthlyExpense)}/bulan, target tercapai dalam ${(remaining / (_monthlyIncome - _monthlyExpense)).ceil()} bulan',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            if (progress >= 1.0) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.celebration, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Target tercapai! 🎉',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quickAddSavings(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: current > 0 ? () => _quickWithdrawSavings(context) : null,
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Tarik'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final balance = _monthlyIncome - _monthlyExpense;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Bulan Ini',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildSummaryRow('Pemasukan', _monthlyIncome, Colors.green),
            const SizedBox(height: 12),
            _buildSummaryRow('Pengeluaran', _monthlyExpense, Colors.red),
            const Divider(height: 24),
            _buildSummaryRow(
              'Saldo',
              balance,
              balance >= 0 ? Colors.blue : Colors.red,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    Color color, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? color : Colors.grey[800],
          ),
        ),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBudgetCard({
    required String category,
    required double budget,
    required double spent,
    required double progress,
  }) {
    final remaining = budget - spent;
    final isOverBudget = spent > budget && budget > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  budget > 0 ? currencyFormat.format(budget) : 'Tidak diatur',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            if (budget > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(
                    isOverBudget
                        ? Colors.red
                        : (progress > 0.7 ? Colors.orange : Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terpakai: ${currencyFormat.format(spent)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    isOverBudget
                        ? 'Over: ${currencyFormat.format(-remaining)}'
                        : 'Sisa: ${currencyFormat.format(remaining)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverBudget ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ] else if (spent > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Terpakai: ${currencyFormat.format(spent)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBudgetDialog() async {
    final result = await showCustomNumberKeyboard(
      context,
      title: 'Atur Budget Bulanan',
      initialValue: _monthlyBudget > 0 ? _monthlyBudget : null,
    );

    if (result != null) {
      setState(() {
        _monthlyBudget = result;
      });
      _savePlannerData();
    }
  }

  void _showSavingsDialog() async {
    // First, get target amount
    final targetResult = await showCustomNumberKeyboard(
      context,
      title: 'Target Tabungan',
      initialValue: _savingsTarget > 0 ? _savingsTarget : null,
    );

    if (targetResult != null) {
      // Then, get current savings (allow 0)
      final currentResult = await showCustomNumberKeyboard(
        context,
        title: 'Tabungan Saat Ini',
        initialValue: _currentSavings >= 0 ? _currentSavings : null,
        allowZero: true,
      );

      if (currentResult != null) {
        setState(() {
          _savingsTarget = targetResult;
          _currentSavings = currentResult;
        });
        _savePlannerData();
      }
    }
  }

  void _showCategoryBudgetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atur Budget Kategori'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _categoryBudgets.keys.map((category) {
              final controller = TextEditingController(
                text: _categoryBudgets[category].toString(),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: category,
                    prefixText: 'Rp ',
                  ),
                  onChanged: (value) {
                    _categoryBudgets[category] = double.tryParse(value) ?? 0;
                  },
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              _savePlannerData();
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan Planner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset Semua Budget'),
              onTap: () {
                Navigator.pop(context);
                _showResetConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Tentang Financial Planner'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Budget?'),
        content: const Text('Semua pengaturan budget akan dihapus. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              setState(() {
                _monthlyBudget = 0;
                _savingsTarget = 0;
                _currentSavings = 0;
                _categoryBudgets.clear();
              });
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang Financial Planner'),
        content: const Text(
          'Financial Planner membantu Anda:\n\n'
          '• Mengatur budget bulanan\n'
          '• Membuat target tabungan\n'
          '• Tracking pengeluaran per kategori\n'
          '• Monitoring kesehatan keuangan\n\n'
          'Atur budget dan pantau pengeluaran Anda secara real-time!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _quickAddSavings(BuildContext context) async {
    final result = await showCustomNumberKeyboard(
      context,
      title: 'Tambah Tabungan',
      initialValue: null,
    );

    if (result != null && result > 0) {
      setState(() {
        _currentSavings += result;
      });
      _savePlannerData();
      
      // Catat sebagai transaksi
      final transaction = TransactionModel(
        type: TransactionType.expense,
        category: 'Tabungan',
        amount: result,
        description: 'Menabung',
        date: DateTime.now(),
      );
      await _service.saveTransaction(transaction);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil menambah ${currencyFormat.format(result)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _quickWithdrawSavings(BuildContext context) async {
    final result = await showCustomNumberKeyboard(
      context,
      title: 'Tarik Tabungan (Saldo: ${currencyFormat.format(_currentSavings)})',
      initialValue: null,
    );

    if (result != null && result > 0) {
      if (result <= _currentSavings) {
        setState(() {
          _currentSavings -= result;
        });
        _savePlannerData();
        
        // Catat sebagai transaksi penarikan (income karena uang kembali)
        final transaction = TransactionModel(
          type: TransactionType.income,
          category: 'Penarikan Tabungan',
          amount: result,
          description: 'Tarik tabungan',
          date: DateTime.now(),
        );
        await _service.saveTransaction(transaction);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil menarik ${currencyFormat.format(result)}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saldo tidak cukup'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
