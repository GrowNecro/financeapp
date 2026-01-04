class TransactionModel {
  final int? id;
  final DateTime date;
  final String description;
  final String category;
  final TransactionType type;
  final double amount;
  final String? receiptPhoto; // Path foto struk (opsional)
  final int? walletAccountId; // Wallet account reference
  final DateTime lastModified; // Untuk conflict resolution multi-device

  TransactionModel({
    this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.type,
    required this.amount,
    this.receiptPhoto,
    this.walletAccountId,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now();

  // Convert to JSON
  Map<String, dynamic> toJson() {
    final map = {
      'date': date.toIso8601String(),
      'description': description,
      'category': category,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'amount': amount,
      'photoPath': receiptPhoto,
      'walletAccountId': walletAccountId,
      'lastModified': lastModified.toIso8601String(),
    };

    if (id != null) {
      map['id'] = id!;
    }

    return map;
  }

  // Create from JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int?,
      date: DateTime.parse(json['date']),
      description: json['description'],
      category: json['category'],
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      amount: (json['amount'] as num).toDouble(),
      receiptPhoto: json['photoPath'] ?? json['receiptPhoto'],
      walletAccountId: json['walletAccountId'] as int?,
      lastModified: json['lastModified'] != null 
          ? DateTime.parse(json['lastModified'])
          : DateTime.now(),
    );
  }

  TransactionModel copyWith({
    int? id,
    DateTime? date,
    String? description,
    String? category,
    TransactionType? type,
    double? amount,
    String? receiptPhoto,
    int? walletAccountId,
    DateTime? lastModified,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      receiptPhoto: receiptPhoto ?? this.receiptPhoto,
      walletAccountId: walletAccountId ?? this.walletAccountId,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

enum TransactionType { income, expense }
