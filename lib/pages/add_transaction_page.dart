import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_number_keyboard.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionModel? transaction;
  
  const AddTransactionPage({super.key, this.transaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final TransactionService _service = TransactionService();
  final FirestoreService _driveService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Makanan & Minuman';
  String? _receiptPhotoPath;
  bool _isScanning = false;

  final List<String> _expenseCategories = [
    'Makanan & Minuman',
    'Transportasi',
    'Parkir',
    'Bensin',
    'Belanja',
    'Tabungan',
    'Tagihan',
    'Pulsa & Internet',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Rumah Tangga',
    'Pakaian',
    'Kecantikan',
    'Olahraga',
    'Lainnya',
  ];

  final List<String> _incomeCategories = [
    'Gaji',
    'Bonus',
    'Investasi',
    'Penarikan Tabungan',
    'Hadiah',
    'Lainnya',
  ];

  // Default nominal untuk kategori tertentu
  final Map<String, double> _defaultAmounts = {'Parkir': 2000, 'Bensin': 30000};

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      // Edit mode - populate fields
      final transaction = widget.transaction!;
      _descriptionController.text = transaction.description;
      _selectedDate = transaction.date;
      _selectedType = transaction.type;
      _selectedCategory = transaction.category;
      _receiptPhotoPath = transaction.receiptPhoto;
      
      // Format amount
      final formatter = NumberFormat('#,###', 'id_ID');
      _amountController.text = formatter.format(transaction.amount);
    }
  }

  List<String> get _categories {
    return _selectedType == TransactionType.expense
        ? _expenseCategories
        : _incomeCategories;
  }

  void _setDefaultAmountForCategory(String category) {
    if (_defaultAmounts.containsKey(category)) {
      final formatter = NumberFormat('#,###', 'id_ID');
      setState(() {
        _amountController.text = formatter.format(_defaultAmounts[category]!);
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      // Remove formatting dari amount sebelum disimpan
      final digitsOnly = _amountController.text.replaceAll(
        RegExp(r'[^\d]'),
        '',
      );

      final transaction = TransactionModel(
        id: widget.transaction?.id, // Preserve ID if editing
        date: _selectedDate,
        description: _descriptionController.text,
        category: _selectedCategory,
        type: _selectedType,
        amount: double.parse(digitsOnly),
        receiptPhoto: _receiptPhotoPath,
      );

      await _service.saveTransaction(transaction);

      // Auto-sync ke Firestore setelah transaksi berhasil disimpan
      _autoSyncToFirestore();

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _autoSyncToFirestore() async {
    try {
      final currentUser = _driveService.getCurrentUser();
      if (currentUser != null) {
        // User sudah login, lakukan auto-sync
        final transactions = await _service.getAllTransactions();
        await _driveService.uploadToFirestore(transactions);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Auto-sync ke Cloud berhasil'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Silent fail - jangan ganggu user jika sync gagal
      debugPrint('Auto-sync failed: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _receiptPhotoPath = image.path;
          _isScanning = true;
        });
        await _scanReceiptText(image.path);
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _receiptPhotoPath = image.path;
          _isScanning = true;
        });
        await _scanReceiptText(image.path);
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _scanReceiptText(String imagePath) async {
    // Skip scan untuk web karena ML Kit tidak support web
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto tersimpan (scan hanya tersedia di mobile)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      // Extract amount dari text yang di-scan
      double? scannedAmount;
      String scannedText = '';
      List<double> allAmounts = [];

      for (TextBlock block in recognizedText.blocks) {
        scannedText += block.text + ' ';

        // Pattern 1: Rp 10.000 atau Rp10000
        final RegExp pattern1 = RegExp(
          r'[Rr][Pp][\s.]*([\d.,]+)',
          caseSensitive: false,
        );
        final matches1 = pattern1.allMatches(block.text);

        for (var match in matches1) {
          final amountStr = match
              .group(1)
              ?.replaceAll('.', '')
              .replaceAll(',', '');
          if (amountStr != null) {
            final amount = double.tryParse(amountStr);
            if (amount != null && amount > 100) {
              allAmounts.add(amount);
            }
          }
        }

        // Pattern 2: Total: 10.000 atau TOTAL 10000
        final RegExp pattern2 = RegExp(r'[Tt][Oo][Tt][Aa][Ll][\s:.]*([\d.,]+)');
        final matches2 = pattern2.allMatches(block.text);

        for (var match in matches2) {
          final amountStr = match
              .group(1)
              ?.replaceAll('.', '')
              .replaceAll(',', '');
          if (amountStr != null) {
            final amount = double.tryParse(amountStr);
            if (amount != null && amount > 100) {
              allAmounts.add(amount);
            }
          }
        }
      }

      // Ambil amount terbesar (biasanya total)
      if (allAmounts.isNotEmpty) {
        allAmounts.sort();
        scannedAmount = allAmounts.last;
      }

      textRecognizer.close();

      if (mounted) {
        final formatter = NumberFormat('#,###', 'id_ID');

        // Auto-fill jumlah jika terdeteksi
        if (scannedAmount != null && _amountController.text.isEmpty) {
          setState(() {
            _amountController.text = formatter.format(scannedAmount);
          });
        }

        // Auto-fill keterangan jika kosong
        if (_descriptionController.text.isEmpty && scannedText.isNotEmpty) {
          final shortText = scannedText.trim().split('\n').first;
          if (shortText.length < 50 && shortText.length > 3) {
            setState(() {
              _descriptionController.text = shortText;
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              scannedAmount != null
                  ? 'Terdeteksi: ${_formatCurrency(scannedAmount)}'
                  : 'Foto tersimpan (tidak ada nominal terdeteksi)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto tersimpan (scan gagal: ${e.toString()})'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  Future<void> _showAmountKeyboard() async {
    // Parse current value from text field
    final digitsOnly = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final currentValue = double.tryParse(digitsOnly) ?? 0;

    final result = await showCustomNumberKeyboard(
      context,
      title: 'Masukkan Nominal',
      initialValue: currentValue > 0 ? currentValue : null,
    );

    if (result != null) {
      final formatter = NumberFormat('#,###', 'id_ID');
      setState(() {
        _amountController.text = formatter.format(result);
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _receiptPhotoPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Tambah Transaksi' : 'Edit Transaksi'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pilih Tipe Transaksi
              const Text(
                'Tipe Transaksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedType = TransactionType.income;
                          _selectedCategory = _incomeCategories[0];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedType == TransactionType.income
                              ? Colors.green
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              color: _selectedType == TransactionType.income
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pemasukan',
                              style: TextStyle(
                                color: _selectedType == TransactionType.income
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedType = TransactionType.expense;
                          _selectedCategory = _expenseCategories[0];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedType == TransactionType.expense
                              ? Colors.red
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              color: _selectedType == TransactionType.expense
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pengeluaran',
                              style: TextStyle(
                                color: _selectedType == TransactionType.expense
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Jumlah
              const Text(
                'Jumlah',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                readOnly: true,
                onTap: _showAmountKeyboard,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Tap untuk input nominal',
                  suffixIcon: Icon(Icons.dialpad, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Jumlah harus diisi';
                  }
                  final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (double.tryParse(digitsOnly) == null) {
                    return 'Jumlah harus berupa angka';
                  }
                  if (double.parse(digitsOnly) <= 0) {
                    return 'Jumlah harus lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Kategori
              const Text(
                'Kategori',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                  _setDefaultAmountForCategory(value!);
                },
              ),
              const SizedBox(height: 24),

              // Keterangan
              Text(
                _selectedType == TransactionType.income
                    ? 'Keterangan (Opsional)'
                    : 'Keterangan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: _selectedType == TransactionType.income
                      ? 'Contoh: Gaji bulan ini (opsional)'
                      : 'Contoh: Beli makan siang',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 3,
                validator: (value) {
                  // Keterangan wajib diisi untuk pengeluaran, opsional untuk pemasukan
                  if (_selectedType == TransactionType.expense) {
                    if (value == null || value.isEmpty) {
                      return 'Keterangan harus diisi untuk pengeluaran';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Foto Struk (hanya untuk pengeluaran)
              if (_selectedType == TransactionType.expense) ...[
                Row(
                  children: [
                    const Text(
                      'Foto Struk (Opsional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isScanning)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'Foto akan di-scan otomatis untuk isi detail',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                if (_receiptPhotoPath != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: kIsWeb
                            ? Image.network(
                                _receiptPhotoPath!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    width: double.infinity,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 50),
                                  );
                                },
                              )
                            : Image.file(
                                File(_receiptPhotoPath!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: _removePhoto,
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isScanning ? null : _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Kamera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isScanning ? null : _pickImageFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeri'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],

              // Tanggal
              const Text(
                'Tanggal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[100],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat(
                          'dd MMMM yyyy',
                          'id_ID',
                        ).format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Simpan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
