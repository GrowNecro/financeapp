import 'transaction_model.dart';

class RecurringTransaction {
  final int? id;
  final String description;
  final String category;
  final TransactionType type;
  final double amount;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime? endDate;
  final int? dayOfMonth; // For monthly (1-31)
  final int? dayOfWeek; // For weekly (1-7, 1=Monday)
  final bool isActive;
  final int? walletAccountId;
  final DateTime? lastGenerated;

  RecurringTransaction({
    this.id,
    required this.description,
    required this.category,
    required this.type,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.dayOfMonth,
    this.dayOfWeek,
    this.isActive = true,
    this.walletAccountId,
    this.lastGenerated,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'description': description,
      'category': category,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'amount': amount,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'isActive': isActive ? 1 : 0,
      'walletAccountId': walletAccountId,
      'lastGenerated': lastGenerated?.toIso8601String(),
    };

    if (id != null) {
      map['id'] = id!;
    }

    return map;
  }

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as int?,
      description: json['description'],
      category: json['category'],
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      amount: (json['amount'] as num).toDouble(),
      frequency: json['frequency'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      dayOfMonth: json['dayOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
      isActive: (json['isActive'] as int?) == 1,
      walletAccountId: json['walletAccountId'] as int?,
      lastGenerated: json['lastGenerated'] != null
          ? DateTime.parse(json['lastGenerated'])
          : null,
    );
  }

  RecurringTransaction copyWith({
    int? id,
    String? description,
    String? category,
    TransactionType? type,
    double? amount,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
    int? walletAccountId,
    DateTime? lastGenerated,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isActive: isActive ?? this.isActive,
      walletAccountId: walletAccountId ?? this.walletAccountId,
      lastGenerated: lastGenerated ?? this.lastGenerated,
    );
  }

  // Calculate next occurrence date
  DateTime? getNextOccurrence() {
    final now = DateTime.now();
    final lastGen = lastGenerated ?? startDate;

    if (endDate != null && now.isAfter(endDate!)) {
      return null; // Recurring has ended
    }

    switch (frequency) {
      case 'daily':
        return lastGen.add(const Duration(days: 1));
      case 'weekly':
        return lastGen.add(const Duration(days: 7));
      case 'monthly':
        var nextDate = DateTime(lastGen.year, lastGen.month + 1, dayOfMonth ?? lastGen.day);
        if (nextDate.isBefore(now)) {
          nextDate = DateTime(lastGen.year, lastGen.month + 2, dayOfMonth ?? lastGen.day);
        }
        return nextDate;
      case 'yearly':
        return DateTime(lastGen.year + 1, lastGen.month, lastGen.day);
      default:
        return null;
    }
  }
}
