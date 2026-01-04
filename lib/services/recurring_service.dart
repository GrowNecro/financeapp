import '../models/transaction_model.dart';
import '../models/recurring_transaction.dart';
import '../services/database_helper.dart';
import '../services/transaction_service.dart';
import '../services/firestore_service.dart';

class RecurringService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TransactionService _transactionService = TransactionService();
  final FirestoreService _firestoreService = FirestoreService();

  // Check and generate due recurring transactions
  Future<int> generateDueRecurringTransactions() async {
    final recurringList = await _dbHelper.getActiveRecurringTransactions();
    final now = DateTime.now();
    int generatedCount = 0;

    for (var recurring in recurringList) {
      // Check if end date has passed
      if (recurring.endDate != null && now.isAfter(recurring.endDate!)) {
        // Deactivate expired recurring
        await _dbHelper.updateRecurringTransaction(
          recurring.copyWith(isActive: false),
        );
        continue;
      }

      // Get next occurrence
      final nextDate = recurring.getNextOccurrence();
      if (nextDate == null) continue;

      // Check if it's due (next occurrence is today or in the past)
      if (nextDate.isBefore(now) || _isSameDay(nextDate, now)) {
        // Generate transaction
        final transaction = TransactionModel(
          date: nextDate,
          description: recurring.description,
          category: recurring.category,
          type: recurring.type,
          amount: recurring.amount,
          walletAccountId: recurring.walletAccountId,
        );

        await _transactionService.saveTransaction(transaction);

        // Update last generated date
        await _dbHelper.updateRecurringTransaction(
          recurring.copyWith(lastGenerated: nextDate),
        );

        generatedCount++;
      }
    }

    return generatedCount;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<List<RecurringTransaction>> getAllRecurring() async {
    return await _dbHelper.getAllRecurringTransactions();
  }

  Future<List<RecurringTransaction>> getActiveRecurring() async {
    return await _dbHelper.getActiveRecurringTransactions();
  }

  Future<void> saveRecurring(RecurringTransaction recurring) async {
    if (recurring.id == null) {
      await _dbHelper.insertRecurringTransaction(recurring);
    } else {
      await _dbHelper.updateRecurringTransaction(recurring);
    }
  }

  Future<void> deleteRecurring(int id) async {
    // Get recurring transaction before deleting for sync
    final recurringList = await _dbHelper.getAllRecurringTransactions();
    final recurring = recurringList.firstWhere((r) => r.id == id);
    
    // Delete from local database
    await _dbHelper.deleteRecurringTransaction(id);
    
    // Sync delete to Firestore
    await _firestoreService.syncRecurringTransaction(
      recurring.toJson(),
      isDelete: true,
    );
  }

  Future<void> toggleRecurring(RecurringTransaction recurring) async {
    await _dbHelper.updateRecurringTransaction(
      recurring.copyWith(isActive: !recurring.isActive),
    );
  }

  // Preview next 5 occurrences
  List<DateTime> getNextOccurrences(RecurringTransaction recurring, int count) {
    final occurrences = <DateTime>[];
    var current = recurring.lastGenerated ?? recurring.startDate;

    for (var i = 0; i < count; i++) {
      final next = _calculateNextOccurrence(current, recurring);
      if (next == null) break;
      
      // Check if past end date
      if (recurring.endDate != null && next.isAfter(recurring.endDate!)) {
        break;
      }

      occurrences.add(next);
      current = next;
    }

    return occurrences;
  }

  DateTime? _calculateNextOccurrence(DateTime from, RecurringTransaction recurring) {
    switch (recurring.frequency) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(from.year, from.month + 1, recurring.dayOfMonth ?? from.day);
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day);
      default:
        return null;
    }
  }
}
