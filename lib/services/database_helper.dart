import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE transactions (
        id $idType,
        type $textType,
        category $textType,
        amount $doubleType,
        description $textType,
        date $textType,
        photoPath TEXT,
        walletAccountId INTEGER,
        lastModified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create wallet accounts table
    await db.execute('''
      CREATE TABLE wallet_accounts (
        id $idType,
        name $textType,
        type $textType,
        icon TEXT,
        initialBalance REAL DEFAULT 0,
        color TEXT,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // Create recurring transactions table
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id $idType,
        description $textType,
        category $textType,
        type $textType,
        amount $doubleType,
        frequency $textType,
        startDate $textType,
        endDate TEXT,
        dayOfMonth INTEGER,
        dayOfWeek INTEGER,
        isActive INTEGER DEFAULT 1,
        walletAccountId INTEGER,
        lastGenerated TEXT
      )
    ''');

    // Create indexes for frequently queried columns
    await db.execute('CREATE INDEX idx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_category ON transactions(category)');
    await db.execute('CREATE INDEX idx_wallet ON transactions(walletAccountId)');
    
    // Insert default wallet
    await db.insert('wallet_accounts', {
      'name': 'Cash',
      'type': 'cash',
      'icon': 'account_balance_wallet',
      'initialBalance': 0,
      'color': '4CAF50',
      'isActive': 1,
    });
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add indexes when upgrading from version 1
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_date ON transactions(date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_type ON transactions(type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_category ON transactions(category)',
      );
    }
    
    if (oldVersion < 3) {
      // Add walletAccountId column to existing transactions
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN walletAccountId INTEGER',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wallet ON transactions(walletAccountId)',
      );
      
      // Create wallet accounts table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wallet_accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          icon TEXT,
          initialBalance REAL DEFAULT 0,
          color TEXT,
          isActive INTEGER DEFAULT 1
        )
      ''');
      
      // Create recurring transactions table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT NOT NULL,
          category TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          frequency TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT,
          dayOfMonth INTEGER,
          dayOfWeek INTEGER,
          isActive INTEGER DEFAULT 1,
          walletAccountId INTEGER,
          lastGenerated TEXT
        )
      ''');
      
      // Insert default wallet if no wallets exist
      final walletCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM wallet_accounts'),
      ) ?? 0;
      
      if (walletCount == 0) {
        await db.insert('wallet_accounts', {
          'name': 'Cash',
          'type': 'cash',
          'icon': 'account_balance_wallet',
          'initialBalance': 0,
          'color': '4CAF50',
          'isActive': 1,
        });
      }
    }
    
    if (oldVersion < 4) {
      // Add lastModified column for conflict resolution
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN lastModified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      );
    }
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toJson());
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'date DESC');

    return result.map((json) => TransactionModel.fromJson(json)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toJson(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<List<TransactionModel>> getTransactionsByType(String type) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'date DESC',
    );

    return result.map((json) => TransactionModel.fromJson(json)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByCategory(
    String category,
  ) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date DESC',
    );

    return result.map((json) => TransactionModel.fromJson(json)).toList();
  }

  Future<double> getTotalIncome() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ?',
      ['income'],
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<double> getTotalExpense() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ?',
      ['expense'],
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  // Recurring Transactions CRUD
  Future<int> insertRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    return await db.insert('recurring_transactions', recurring.toJson());
  }

  Future<List<RecurringTransaction>> getAllRecurringTransactions() async {
    final db = await database;
    final result = await db.query(
      'recurring_transactions',
      orderBy: 'startDate DESC',
    );

    return result.map((json) => RecurringTransaction.fromJson(json)).toList();
  }

  Future<List<RecurringTransaction>> getActiveRecurringTransactions() async {
    final db = await database;
    final result = await db.query(
      'recurring_transactions',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'startDate DESC',
    );

    return result.map((json) => RecurringTransaction.fromJson(json)).toList();
  }

  Future<int> updateRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    return await db.update(
      'recurring_transactions',
      recurring.toJson(),
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  Future<int> deleteRecurringTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
