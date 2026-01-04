import '../models/transaction_model.dart';
import 'database_helper.dart';
import 'firestore_service.dart';

class TransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Simpan transaksi
  Future<void> saveTransaction(TransactionModel transaction) async {
    if (transaction.id == null) {
      // Transaksi baru - insert
      await _dbHelper.insertTransaction(transaction);
    } else {
      // Update transaksi yang sudah ada
      await _dbHelper.updateTransaction(transaction);
    }
  }

  // Ambil semua transaksi
  Future<List<TransactionModel>> getAllTransactions() async {
    return await _dbHelper.getAllTransactions();
  }

  // Hapus transaksi
  Future<void> deleteTransaction(int id) async {
    // Get transaction before deleting for sync
    final transactions = await _dbHelper.getAllTransactions();
    final transaction = transactions.firstWhere((t) => t.id == id);
    
    // Delete from local database
    await _dbHelper.deleteTransaction(id);
    
    // Sync delete to Firestore
    await _firestoreService.syncTransaction(transaction, isDelete: true);
  }

  // Hitung total pemasukan
  Future<double> getTotalIncome() async {
    return await _dbHelper.getTotalIncome();
  }

  // Hitung total pengeluaran
  Future<double> getTotalExpense() async {
    return await _dbHelper.getTotalExpense();
  }

  // Hitung saldo
  Future<double> getBalance() async {
    final income = await getTotalIncome();
    final expense = await getTotalExpense();
    return income - expense;
  }

  // Filter transaksi berdasarkan tipe
  Future<List<TransactionModel>> getTransactionsByType(
    TransactionType type,
  ) async {
    final typeString = type == TransactionType.income ? 'income' : 'expense';
    return await _dbHelper.getTransactionsByType(typeString);
  }

  // Filter transaksi berdasarkan kategori
  Future<List<TransactionModel>> getTransactionsByCategory(
    String category,
  ) async {
    return await _dbHelper.getTransactionsByCategory(category);
  }
}
