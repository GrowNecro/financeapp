import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction_model.dart';
import '../services/recurring_service.dart';
import '../widgets/custom_number_keyboard.dart';

class RecurringTransactionsPage extends StatefulWidget {
  const RecurringTransactionsPage({super.key});

  @override
  State<RecurringTransactionsPage> createState() => _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState extends State<RecurringTransactionsPage> {
  final RecurringService _service = RecurringService();
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  List<RecurringTransaction> _recurring = [];
  bool _isLoading = true;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    _loadRecurring();
  }

  Future<void> _loadRecurring() async {
    setState(() => _isLoading = true);

    final recurring = _showActiveOnly
        ? await _service.getActiveRecurring()
        : await _service.getAllRecurring();

    setState(() {
      _recurring = recurring;
      _isLoading = false;
    });
  }

  Future<void> _generateNow() async {
    final count = await _service.generateDueRecurringTransactions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? 'Berhasil generate $count transaksi'
              : 'Tidak ada transaksi yang jatuh tempo'),
          backgroundColor: count > 0 ? Colors.green : Colors.orange,
        ),
      );
      _loadRecurring();
    }
  }

  Future<void> _showAddEditDialog([RecurringTransaction? recurring]) async {
    await showDialog(
      context: context,
      builder: (context) => AddEditRecurringDialog(recurring: recurring),
    );
    _loadRecurring();
  }

  Future<void> _deleteRecurring(RecurringTransaction recurring) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Recurring?'),
        content: Text('Hapus "${recurring.description}"?\n\nTransaksi yang sudah dibuat tidak akan terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteRecurring(recurring.id!);
      _loadRecurring();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Berulang'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Generate Sekarang',
            onPressed: _generateNow,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(_showActiveOnly ? Icons.check_box : Icons.check_box_outline_blank),
                    const SizedBox(width: 8),
                    const Text('Tampilkan Aktif Saja'),
                  ],
                ),
                onTap: () {
                  setState(() => _showActiveOnly = !_showActiveOnly);
                  _loadRecurring();
                },
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recurring.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _showActiveOnly
                            ? 'Belum ada transaksi berulang aktif'
                            : 'Belum ada transaksi berulang',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tambahkan untuk auto-generate transaksi rutin',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecurring,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recurring.length,
                    itemBuilder: (context, index) {
                      final recurring = _recurring[index];
                      return _buildRecurringCard(recurring);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  Widget _buildRecurringCard(RecurringTransaction recurring) {
    final nextOccurrences = _service.getNextOccurrences(recurring, 3);
    final isExpired = recurring.endDate != null && DateTime.now().isAfter(recurring.endDate!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: recurring.isActive && !isExpired
                  ? (recurring.type == TransactionType.income ? Colors.green : Colors.red)
                  : Colors.grey,
              child: Icon(
                recurring.type == TransactionType.income
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: Colors.white,
              ),
            ),
            title: Text(
              recurring.description,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: !recurring.isActive || isExpired ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${recurring.category} • ${_getFrequencyText(recurring.frequency)}'),
                if (isExpired)
                  const Text(
                    'Sudah berakhir',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currencyFormat.format(recurring.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: recurring.type == TransactionType.income ? Colors.green : Colors.red,
                  ),
                ),
                if (recurring.lastGenerated != null)
                  Text(
                    'Terakhir: ${DateFormat('d MMM').format(recurring.lastGenerated!)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            onTap: () => _showAddEditDialog(recurring),
          ),
          if (nextOccurrences.isNotEmpty && recurring.isActive && !isExpired) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('Selanjutnya: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    nextOccurrences.map((d) => DateFormat('d MMM').format(d)).join(', '),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await _service.toggleRecurring(recurring);
                    _loadRecurring();
                  },
                  icon: Icon(recurring.isActive ? Icons.pause : Icons.play_arrow, size: 18),
                  label: Text(recurring.isActive ? 'Pause' : 'Aktifkan'),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(recurring),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteRecurring(recurring),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyText(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Harian';
      case 'weekly':
        return 'Mingguan';
      case 'monthly':
        return 'Bulanan';
      case 'yearly':
        return 'Tahunan';
      default:
        return frequency;
    }
  }
}

class AddEditRecurringDialog extends StatefulWidget {
  final RecurringTransaction? recurring;

  const AddEditRecurringDialog({super.key, this.recurring});

  @override
  State<AddEditRecurringDialog> createState() => _AddEditRecurringDialogState();
}

class _AddEditRecurringDialogState extends State<AddEditRecurringDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final RecurringService _service = RecurringService();

  late TransactionType _type;
  late String _category;
  double _amount = 0;
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int? _dayOfMonth;
  bool _isActive = true;

  final List<String> _expenseCategories = [
    'Makanan',
    'Transport',
    'Tagihan',
    'Pulsa & Internet',
    'Hiburan',
    'Belanja',
    'Lainnya',
  ];

  final List<String> _incomeCategories = [
    'Gaji',
    'Bonus',
    'Investasi',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.recurring != null) {
      final r = widget.recurring!;
      _descriptionController.text = r.description;
      _type = r.type;
      _category = r.category;
      _amount = r.amount;
      _frequency = r.frequency;
      _startDate = r.startDate;
      _endDate = r.endDate;
      _dayOfMonth = r.dayOfMonth;
      _isActive = r.isActive;
    } else {
      _type = TransactionType.expense;
      _category = _expenseCategories[0];
    }
  }

  List<String> get _categories {
    return _type == TransactionType.expense ? _expenseCategories : _incomeCategories;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recurring == null ? 'Tambah Recurring' : 'Edit Recurring',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Type
                const Text('Tipe', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pemasukan'),
                        selected: _type == TransactionType.income,
                        onSelected: (selected) {
                          setState(() {
                            _type = TransactionType.income;
                            _category = _incomeCategories[0];
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pengeluaran'),
                        selected: _type == TransactionType.expense,
                        onSelected: (selected) {
                          setState(() {
                            _type = TransactionType.expense;
                            _category = _expenseCategories[0];
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Keterangan harus diisi' : null,
                ),
                const SizedBox(height: 16),

                // Category
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Nominal',
                    prefixText: 'Rp ',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.dialpad),
                  ),
                  controller: TextEditingController(
                    text: _amount > 0 ? NumberFormat('#,###', 'id_ID').format(_amount) : '',
                  ),
                  onTap: () async {
                    final result = await showCustomNumberKeyboard(
                      context,
                      title: 'Masukkan Nominal',
                      initialValue: _amount > 0 ? _amount : null,
                    );
                    if (result != null) {
                      setState(() => _amount = result);
                    }
                  },
                  validator: (value) =>
                      _amount <= 0 ? 'Nominal harus diisi' : null,
                ),
                const SizedBox(height: 16),

                // Frequency
                DropdownButtonFormField<String>(
                  value: _frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frekuensi',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Harian')),
                    DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
                    DropdownMenuItem(value: 'monthly', child: Text('Bulanan')),
                    DropdownMenuItem(value: 'yearly', child: Text('Tahunan')),
                  ],
                  onChanged: (value) => setState(() => _frequency = value!),
                ),
                const SizedBox(height: 16),

                // Day of Month (for monthly)
                if (_frequency == 'monthly') ...[
                  DropdownButtonFormField<int>(
                    value: _dayOfMonth ?? _startDate.day,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal dalam Bulan',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(31, (i) => i + 1).map((day) {
                      return DropdownMenuItem(value: day, child: Text('Tanggal $day'));
                    }).toList(),
                    onChanged: (value) => setState(() => _dayOfMonth = value),
                  ),
                  const SizedBox(height: 16),
                ],

                // Start Date
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _startDate = date);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Mulai: ${DateFormat('d MMM yyyy').format(_startDate)}'),
                ),
                const SizedBox(height: 8),

                // End Date
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
                      firstDate: _startDate,
                      lastDate: DateTime(2030),
                    );
                    setState(() => _endDate = date);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _endDate != null
                        ? 'Berakhir: ${DateFormat('d MMM yyyy').format(_endDate!)}'
                        : 'Tanpa Batas Akhir',
                  ),
                ),
                if (_endDate != null) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() => _endDate = null),
                    child: const Text('Hapus Tanggal Akhir'),
                  ),
                ],
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text(
                          'Simpan',
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final recurring = RecurringTransaction(
      id: widget.recurring?.id,
      description: _descriptionController.text,
      category: _category,
      type: _type,
      amount: _amount,
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
      dayOfMonth: _frequency == 'monthly' ? (_dayOfMonth ?? _startDate.day) : null,
      isActive: _isActive,
      lastGenerated: widget.recurring?.lastGenerated,
    );

    await _service.saveRecurring(recurring);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recurring berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
