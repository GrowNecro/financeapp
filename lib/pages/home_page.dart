import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/firestore_service.dart';
import '../services/recurring_service.dart';
import 'add_transaction_page.dart';
import 'transaction_detail_page.dart';
import 'financial_planner_page.dart';
import 'analytics_page.dart';
import 'recurring_transactions_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TransactionService _service = TransactionService();
  final FirestoreService _firestoreService = FirestoreService();
  final RecurringService _recurringService = RecurringService();
  final TextEditingController _searchController = TextEditingController();
  List<TransactionModel> _transactions = [];
  List<TransactionModel> _filteredTransactions = [];
  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  bool _isSignedIn = false;
  bool _isSyncing = false;
  String _lastSyncTime = '';

  String _filterType = 'Semua'; // Semua, Pemasukan, Pengeluaran
  String _filterCategory = 'Semua';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  double? _filterMinAmount;
  double? _filterMaxAmount;
  String _sortBy = 'date_desc'; // date_desc, date_asc, amount_desc, amount_asc

  @override
  void initState() {
    super.initState();
    _autoGenerateRecurring();
    _loadData();
    _checkSignInStatus();
    _loadLastSyncTime();
    _autoDownloadOnStart();
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('lastSyncTime');
    
    if (lastSync != null) {
      final syncTime = DateTime.parse(lastSync);
      final now = DateTime.now();
      final diff = now.difference(syncTime);
      
      String timeAgo;
      if (diff.inMinutes < 1) {
        timeAgo = 'Baru saja';
      } else if (diff.inHours < 1) {
        timeAgo = '${diff.inMinutes} menit lalu';
      } else if (diff.inDays < 1) {
        timeAgo = '${diff.inHours} jam lalu';
      } else {
        timeAgo = '${diff.inDays} hari lalu';
      }
      
      setState(() {
        _lastSyncTime = timeAgo;
      });
    }
  }

  Future<void> _autoGenerateRecurring() async {
    try {
      final count = await _recurringService.generateDueRecurringTransactions();
      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $count transaksi berulang dibuat otomatis'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _checkSignInStatus() async {
    final isSignedIn = await _firestoreService.isSignedIn();
    setState(() {
      _isSignedIn = isSignedIn;
    });
  }

  Future<void> _autoDownloadOnStart() async {
    final isSignedIn = await _firestoreService.isSignedIn();
    if (!isSignedIn || !mounted) return;

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final result = await _firestoreService.downloadFromFirestore();

      if (result.contains('berhasil') || result.contains('sinkron')) {
        await _loadData();
        await _loadLastSyncTime();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Silently fail - tidak mengganggu UX
    }
  }

  Future<void> _loadData() async {
    print('📖 Loading data from database...');
    final transactions = await _service.getAllTransactions();
    print('📊 Database returned ${transactions.length} transactions');
    
    final balance = await _service.getBalance();
    final income = await _service.getTotalIncome();
    final expense = await _service.getTotalExpense();

    print('💰 Balance: $balance, Income: $income, Expense: $expense');

    setState(() {
      _transactions = transactions..sort((a, b) => b.date.compareTo(a.date));
      _applyFilter();
      _balance = balance;
      _totalIncome = income;
      _totalExpense = expense;
    });
    
    print('✅ State updated - _transactions: ${_transactions.length}, _filteredTransactions: ${_filteredTransactions.length}');
  }

  void _applyFilter() {
    List<TransactionModel> filtered = List.from(_transactions);

    // Search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.description.toLowerCase().contains(searchQuery) ||
            t.category.toLowerCase().contains(searchQuery);
      }).toList();
    }

    // Filter by type
    if (_filterType == 'Pemasukan') {
      filtered = filtered
          .where((t) => t.type == TransactionType.income)
          .toList();
    } else if (_filterType == 'Pengeluaran') {
      filtered = filtered
          .where((t) => t.type == TransactionType.expense)
          .toList();
    }

    // Filter by category
    if (_filterCategory != 'Semua') {
      filtered = filtered.where((t) => t.category == _filterCategory).toList();
    }

    // Filter by date range
    if (_filterStartDate != null) {
      filtered = filtered.where((t) => t.date.isAfter(_filterStartDate!.subtract(const Duration(days: 1)))).toList();
    }
    if (_filterEndDate != null) {
      filtered = filtered.where((t) => t.date.isBefore(_filterEndDate!.add(const Duration(days: 1)))).toList();
    }

    // Filter by amount range
    if (_filterMinAmount != null) {
      filtered = filtered.where((t) => t.amount >= _filterMinAmount!).toList();
    }
    if (_filterMaxAmount != null) {
      filtered = filtered.where((t) => t.amount <= _filterMaxAmount!).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'date_desc':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'amount_desc':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'amount_asc':
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    _filteredTransactions = filtered;
  }

  Set<String> _getAllCategories() {
    return _transactions.map((t) => t.category).toSet();
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Transaksi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tipe Transaksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['Semua', 'Pemasukan', 'Pengeluaran'].map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _filterType == type,
                    onSelected: (selected) {
                      setStateDialog(() {
                        _filterType = type;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Kategori',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Semua', ..._getAllCategories()].map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _filterCategory == category,
                    onSelected: (selected) {
                      setStateDialog(() {
                        _filterCategory = category;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterType = 'Semua';
                          _filterCategory = 'Semua';
                          _filterStartDate = null;
                          _filterEndDate = null;
                          _filterMinAmount = null;
                          _filterMaxAmount = null;
                          _applyFilter();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _applyFilter();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvancedFilterDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Lanjutan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // Date Range
                const Text('Rentang Tanggal', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _filterStartDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setStateDialog(() => _filterStartDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_filterStartDate != null
                            ? DateFormat('d MMM yy').format(_filterStartDate!)
                            : 'Dari'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('-'),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _filterEndDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setStateDialog(() => _filterEndDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_filterEndDate != null
                            ? DateFormat('d MMM yy').format(_filterEndDate!)
                            : 'Sampai'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Amount Range
                const Text('Rentang Nominal', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                          text: _filterMinAmount?.toInt().toString() ?? '',
                        ),
                        onChanged: (value) {
                          _filterMinAmount = double.tryParse(value);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('-'),
                    ),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                          text: _filterMaxAmount?.toInt().toString() ?? '',
                        ),
                        onChanged: (value) {
                          _filterMaxAmount = double.tryParse(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _filterStartDate = null;
                            _filterEndDate = null;
                            _filterMinAmount = null;
                            _filterMaxAmount = null;
                            _applyFilter();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _applyFilter();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text(
                          'Terapkan',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Urutkan Berdasarkan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Tanggal Terbaru'),
              trailing: _sortBy == 'date_desc' ? const Icon(Icons.check, color: Colors.teal) : null,
              onTap: () {
                setState(() {
                  _sortBy = 'date_desc';
                  _applyFilter();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Tanggal Terlama'),
              trailing: _sortBy == 'date_asc' ? const Icon(Icons.check, color: Colors.teal) : null,
              onTap: () {
                setState(() {
                  _sortBy = 'date_asc';
                  _applyFilter();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Nominal Terbesar'),
              trailing: _sortBy == 'amount_desc' ? const Icon(Icons.check, color: Colors.teal) : null,
              onTap: () {
                setState(() {
                  _sortBy = 'amount_desc';
                  _applyFilter();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Nominal Terkecil'),
              trailing: _sortBy == 'amount_asc' ? const Icon(Icons.check, color: Colors.teal) : null,
              onTap: () {
                setState(() {
                  _sortBy = 'amount_asc';
                  _applyFilter();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<TransactionModel?> _deleteTransaction(int id) async {
    // Get transaction before deleting for undo
    final transaction = _transactions.firstWhere((t) => t.id == id);
    await _service.deleteTransaction(id);
    await _loadData();
    
    return transaction;
  }
  
  Future<void> _restoreTransaction(TransactionModel transaction) async {
    // Create new transaction with all original data but new ID and timestamp
    final restoredTransaction = TransactionModel(
      id: null, // Reset ID for new insert
      date: transaction.date,
      description: transaction.description,
      category: transaction.category,
      type: transaction.type,
      amount: transaction.amount,
      receiptPhoto: transaction.receiptPhoto,
      walletAccountId: transaction.walletAccountId,
      lastModified: DateTime.now(), // Update timestamp for sync
    );
    
    await _service.saveTransaction(restoredTransaction);
    
    // Reload data - _loadData already has setState inside
    await _loadData();
    
    // Auto-sync after restore
    _autoSyncToFirestore();
  }

  Future<void> _autoSyncToFirestore() async {
    if (!_isSignedIn || _isSyncing) return;

    setState(() => _isSyncing = true);
    try {
      final transactions = await _service.getAllTransactions();
      await _firestoreService.uploadToFirestore(transactions);
    } catch (e) {
      // Silent fail
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleFirebaseSignIn() async {
    setState(() => _isSyncing = true);

    if (_isSignedIn) {
      // Sign out
      await _firestoreService.signOut();
      setState(() {
        _isSignedIn = false;
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil keluar dari Firebase')),
        );
      }
    } else {
      // Sign in
      final success = await _firestoreService.signInWithGoogle();
      setState(() {
        _isSignedIn = success;
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Berhasil masuk: ${_firestoreService.getUserEmail() ?? "User"}'
                  : 'Tidak dapat menghubungkan ke Google',
            ),
          ),
        );
      }
    }
  }

  Future<void> _syncToFirestore() async {
    if (!_isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    setState(() => _isSyncing = true);
    final transactions = await _service.getAllTransactions();
    final result = await _firestoreService.uploadToFirestore(transactions);
    await _loadLastSyncTime();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _restoreFromFirestore() async {
    if (!_isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    setState(() => _isSyncing = true);
    
    try {
      print('🔄 Starting restore from Firestore...');
      final result = await _firestoreService.downloadFromFirestore();
      print('📥 Restore result: $result');
      
      await _loadLastSyncTime();
      
      // Determine success or error
      final isSuccess = result.contains('berhasil') || 
                        result.contains('sinkron') || 
                        result.contains('baru') ||
                        result.contains('diupdate');
      
      // RELOAD data from database BEFORE setting isSyncing = false
      print('🔃 Reloading data from database...');
      await _loadData();
      print('✅ Data reloaded, filtered transaction count: ${_filteredTransactions.length}');
      print('✅ Total transaction count: ${_transactions.length}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: isSuccess ? Colors.green : Colors.orange,
            duration: Duration(seconds: isSuccess ? 2 : 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Restore error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showSyncMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sinkronisasi Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_isSignedIn) ...[
              Text(
                'Login sebagai: ${_firestoreService.getUserEmail()}',
                style: const TextStyle(color: Colors.grey),
              ),
              if (_lastSyncTime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Sync terakhir: $_lastSyncTime',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.cloud_upload, color: Colors.teal),
                title: const Text('Backup ke Cloud'),
                subtitle: const Text('Upload data ke Cloud Storage'),
                onTap: () {
                  Navigator.pop(context);
                  _syncToFirestore();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.blue),
                title: const Text('Restore dari Cloud'),
                subtitle: const Text('Download data dari Cloud Storage'),
                onTap: () {
                  Navigator.pop(context);
                  _restoreFromFirestore();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Keluar'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFirebaseSignIn();
                },
              ),
            ] else ...[
              const Text(
                'Login untuk backup otomatis ke cloud',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFirebaseSignIn();
                },
                icon: const Icon(Icons.login),
                label: const Text('Login ke Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Keuangan'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'Transaksi Berulang',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecurringTransactionsPage(),
                ),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Financial Planner',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinancialPlannerPage(),
                ),
              ).then((_) => _loadData());
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                  color: _isSignedIn ? Colors.white : Colors.white70,
                ),
                onPressed: _isSyncing ? null : _showSyncMenu,
                tooltip: _isSignedIn ? 'Sinkronisasi' : 'Login Google',
              ),
              if (_isSyncing)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Card Saldo
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Saldo',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(_balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pemasukan',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(_totalIncome),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pengeluaran',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(_totalExpense),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari transaksi...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _applyFilter();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _applyFilter();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showAdvancedFilterDialog,
                  tooltip: 'Filter',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.teal.withOpacity(0.1),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: _showSortDialog,
                  tooltip: 'Sort',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.teal.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List Transaksi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Transaksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text(
                      '${_filteredTransactions.length} transaksi',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color:
                            (_filterType != 'Semua' ||
                                _filterCategory != 'Semua')
                            ? Colors.teal
                            : Colors.grey[600],
                      ),
                      onPressed: _showFilterDialog,
                      tooltip: 'Filter',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada transaksi',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _filteredTransactions[index];
                      final isIncome =
                          transaction.type == TransactionType.income;

                      return Dismissible(
                        key: Key(transaction.id.toString()),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          // Show confirmation dialog
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Transaksi?'),
                              content: Text(
                                'Yakin ingin menghapus "${transaction.description}"?\n\nAnda punya waktu 5 detik untuk membatalkan setelah menghapus.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (_) async {
                          final transactionId = transaction.id;
                          if (transactionId == null) return;
                          
                          // Delete and get the deleted transaction
                          final deletedTransaction = await _deleteTransaction(transactionId);
                          
                          if (deletedTransaction != null && mounted) {
                            // Capture ScaffoldMessenger before async gap
                            final messenger = ScaffoldMessenger.of(context);
                            
                            // Show SnackBar with Undo action
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('"${deletedTransaction.description}" dihapus'),
                                duration: const Duration(seconds: 5),
                                backgroundColor: Colors.red,
                                action: SnackBarAction(
                                  label: 'BATALKAN',
                                  textColor: Colors.yellow,
                                  onPressed: () async {
                                    await _restoreTransaction(deletedTransaction);
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Transaksi dipulihkan'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TransactionDetailPage(
                                    transaction: transaction,
                                  ),
                                ),
                              );
                              if (result == 'refresh') {
                                _loadData();
                              }
                            },
                            leading: CircleAvatar(
                              backgroundColor: isIncome
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(
                              transaction.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      transaction.category,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (transaction.receiptPhoto != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.image,
                                        size: 14,
                                        color: Colors.teal,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                    'id_ID',
                                  ).format(transaction.date),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              '${isIncome ? '+' : '-'} ${_formatCurrency(transaction.amount)}',
                              style: TextStyle(
                                color: isIncome ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
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
            MaterialPageRoute(builder: (context) => const AddTransactionPage()),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
