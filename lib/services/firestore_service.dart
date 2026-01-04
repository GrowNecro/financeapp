import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _currentUser;
  bool _isSyncing = false;

  // Get current user
  User? getCurrentUser() => _auth.currentUser;
  String? getUserEmail() => _auth.currentUser?.email ?? _auth.currentUser?.displayName;
  bool get isSyncing => _isSyncing;

  // Sign in with Google (via Firebase Auth)
  Future<bool> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In...');
      
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ User canceled sign-in');
        return false; // User canceled
      }

      print('✅ Google account selected: ${googleUser.email}');

      // Obtain auth details from Google Sign-In
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('✅ Got authentication tokens');

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('✅ Created Firebase credential');

      // Sign in to Firebase with Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      _currentUser = userCredential.user;
      print('✅ Signed in to Firebase: ${_currentUser?.email}');
      
      return _currentUser != null;
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      return false;
    }
  }

  // Sign in anonymously (for personal use)
  Future<bool> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      _currentUser = userCredential.user;
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  // Sign in with email/password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _currentUser = userCredential.user;
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  // Sign up with email/password
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _currentUser = userCredential.user;
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _currentUser = null;
  }

  // Check if signed in
  Future<bool> isSignedIn() async {
    _currentUser = _auth.currentUser;
    return _currentUser != null;
  }

  // Get user's Firestore collection reference
  CollectionReference _getUserCollection(String collectionName) {
    final userId = _auth.currentUser?.uid ?? 'anonymous';
    return _firestore.collection('users').doc(userId).collection(collectionName);
  }

  // Upload all data to Firestore (background sync)
  Future<String> uploadToFirestore(List<TransactionModel> transactions) async {
    if (_isSyncing) return 'Sync sedang berjalan...';
    
    try {
      _isSyncing = true;
      
      final user = _auth.currentUser;
      if (user == null) return 'Error: Not signed in';

      final prefs = await SharedPreferences.getInstance();
      final db = await DatabaseHelper.instance.database;

      // Get all data from database
      final recurringResult = await db.query('recurring_transactions');
      final walletsResult = await db.query('wallet_accounts');

      // Get financial planner settings from SharedPreferences
      final plannerSettings = {
        'monthly_budget': prefs.getDouble('monthly_budget') ?? 0.0,
        'savings_target': prefs.getDouble('savings_target') ?? 0.0,
        'current_savings': prefs.getDouble('current_savings') ?? 0.0,
        'category_budgets': <String, double>{},
      };

      // Get category budgets
      final allKeys = prefs.getKeys();
      for (var key in allKeys) {
        if (key.startsWith('budget_')) {
          final category = key.replaceFirst('budget_', '');
          final budgets = plannerSettings['category_budgets'] as Map<String, double>;
          budgets[category] = prefs.getDouble(key) ?? 0.0;
        }
      }

      final batch = _firestore.batch();
      final userDoc = _firestore.collection('users').doc(user.uid);

      // Upload transactions
      int transactionCount = 0;
      for (var transaction in transactions) {
        final docRef = _getUserCollection('transactions').doc(transaction.id?.toString());
        batch.set(docRef, transaction.toJson(), SetOptions(merge: true));
        transactionCount++;
      }

      // Upload recurring transactions
      int recurringCount = 0;
      for (var recurring in recurringResult) {
        final docRef = _getUserCollection('recurring_transactions').doc(recurring['id']?.toString());
        batch.set(docRef, recurring, SetOptions(merge: true));
        recurringCount++;
      }

      // Upload wallet accounts
      int walletCount = 0;
      for (var wallet in walletsResult) {
        final docRef = _getUserCollection('wallet_accounts').doc(wallet['id']?.toString());
        batch.set(docRef, wallet, SetOptions(merge: true));
        walletCount++;
      }

      // Upload planner settings
      batch.set(
        userDoc.collection('settings').doc('planner'),
        plannerSettings,
        SetOptions(merge: true),
      );

      // Update last sync timestamp
      batch.set(
        userDoc,
        {
          'last_sync': FieldValue.serverTimestamp(),
          'email': user.email ?? user.uid,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Save last sync timestamp locally
      await prefs.setString('lastSyncTime', DateTime.now().toIso8601String());

      return 'Sync berhasil! $transactionCount transaksi, $recurringCount recurring, $walletCount wallet';
    } catch (e) {
      return 'Error sync: ${e.toString()}';
    } finally {
      _isSyncing = false;
    }
  }

  // Download all data from Firestore (restore)
  Future<String> downloadFromFirestore() async {
    if (_isSyncing) return 'Sync sedang berjalan...';
    
    try {
      _isSyncing = true;
      
      final user = _auth.currentUser;
      if (user == null) return 'Error: Not signed in';

      final prefs = await SharedPreferences.getInstance();
      final db = await DatabaseHelper.instance.database;

      // Download transactions
      final transactionsSnapshot = await _getUserCollection('transactions').get();
      final transactionList = transactionsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      print('📊 Firestore data - Transactions: ${transactionList.length}');

      // Download recurring transactions
      final recurringSnapshot = await _getUserCollection('recurring_transactions').get();
      final recurringList = recurringSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      print('📊 Firestore data - Recurring: ${recurringList.length}');

      // Download wallet accounts
      final walletsSnapshot = await _getUserCollection('wallet_accounts').get();
      final walletsList = walletsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      print('📊 Firestore data - Wallets: ${walletsList.length}');

      // Download planner settings
      final plannerDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('planner')
          .get();
      final plannerSettings = plannerDoc.data() ?? {};

      // Check if backup has any data
      if (transactionList.isEmpty && recurringList.isEmpty && walletsList.isEmpty) {
        return 'Tidak ada data di cloud.';
      }

      // === RESTORE TRANSACTIONS ===
      final existingResult = await db.rawQuery(
        'SELECT id, description, date, amount, lastModified FROM transactions',
      );

      final existingMap = <String, Map<String, dynamic>>{};
      for (var row in existingResult) {
        final key = '${row['description']}_${row['date']}_${row['amount']}';
        existingMap[key] = row;
      }

      int newCount = 0;
      int updatedCount = 0;

      print('🔍 Processing ${transactionList.length} transactions from Firestore...');

      for (var json in transactionList) {
        print('📝 Processing transaction: ${json['description']} - ${json['amount']}');
        
        // Check if transaction already exists
        final existingTrans = await db.query(
          'transactions',
          where: 'description = ? AND date = ? AND amount = ?',
          whereArgs: [json['description'], json['date'], json['amount']],
        );

        if (existingTrans.isEmpty) {
          print('  ➕ NEW transaction, inserting directly to database...');
          
          // Insert directly to database (like wallet restore)
          final transactionData = Map<String, dynamic>.from(json);
          transactionData.remove('id'); // Remove Firestore ID
          
          // Ensure correct column names
          if (transactionData.containsKey('receiptPhoto')) {
            transactionData['photoPath'] = transactionData['receiptPhoto'];
            transactionData.remove('receiptPhoto');
          }
          
          await db.insert('transactions', transactionData);
          newCount++;
          print('  ✅ Inserted to database');
        } else {
          print('  ⏭️ SKIP - transaction already exists');
          
          // Check if need update based on lastModified
          final existingModified = DateTime.parse(existingTrans.first['lastModified'] as String);
          final cloudModified = DateTime.parse(json['lastModified']);
          
          if (cloudModified.isAfter(existingModified)) {
            print('  🔄 UPDATING - cloud version is newer');
            
            final transactionData = Map<String, dynamic>.from(json);
            transactionData['id'] = existingTrans.first['id'];
            
            if (transactionData.containsKey('receiptPhoto')) {
              transactionData['photoPath'] = transactionData['receiptPhoto'];
              transactionData.remove('receiptPhoto');
            }
            
            await db.update(
              'transactions',
              transactionData,
              where: 'id = ?',
              whereArgs: [existingTrans.first['id']],
            );
            updatedCount++;
            print('  ✅ Updated');
          }
        }
      }

      print('✅ Restore complete: $newCount new, $updatedCount updated');

      // === RESTORE RECURRING TRANSACTIONS ===
      int recurringRestored = 0;
      for (var json in recurringList) {
        final recurring = json;

        final existingRecurring = await db.query(
          'recurring_transactions',
          where: 'description = ? AND category = ? AND amount = ?',
          whereArgs: [recurring['description'], recurring['category'], recurring['amount']],
        );

        if (existingRecurring.isEmpty) {
          await db.insert('recurring_transactions', recurring..remove('id'));
          recurringRestored++;
        }
      }

      // === RESTORE WALLET ACCOUNTS ===
      int walletsRestored = 0;
      for (var json in walletsList) {
        final wallet = json;

        final existingWallet = await db.query(
          'wallet_accounts',
          where: 'name = ? AND type = ?',
          whereArgs: [wallet['name'], wallet['type']],
        );

        if (existingWallet.isEmpty) {
          await db.insert('wallet_accounts', wallet..remove('id'));
          walletsRestored++;
        }
      }

      // === RESTORE PLANNER SETTINGS ===
      if (plannerSettings.isNotEmpty) {
        if (plannerSettings['monthly_budget'] != null) {
          await prefs.setDouble('monthly_budget', (plannerSettings['monthly_budget'] as num).toDouble());
        }
        if (plannerSettings['savings_target'] != null) {
          await prefs.setDouble('savings_target', (plannerSettings['savings_target'] as num).toDouble());
        }
        if (plannerSettings['current_savings'] != null) {
          await prefs.setDouble('current_savings', (plannerSettings['current_savings'] as num).toDouble());
        }

        final categoryBudgets = plannerSettings['category_budgets'] as Map<String, dynamic>? ?? {};
        for (var entry in categoryBudgets.entries) {
          await prefs.setDouble('budget_${entry.key}', (entry.value as num).toDouble());
        }
      }

      // Save last sync timestamp
      await prefs.setString('lastSyncTime', DateTime.now().toIso8601String());

      // Build success message
      final messages = <String>[];
      if (newCount > 0) messages.add('$newCount transaksi baru');
      if (updatedCount > 0) messages.add('$updatedCount transaksi diupdate');
      if (recurringRestored > 0) messages.add('$recurringRestored recurring');
      if (walletsRestored > 0) messages.add('$walletsRestored wallet');
      if (plannerSettings.isNotEmpty) messages.add('planner settings');

      if (messages.isNotEmpty) {
        return 'Sync berhasil! ${messages.join(", ")}';
      }
      return 'Semua data sudah sinkron';
    } catch (e) {
      return 'Error sync: ${e.toString()}';
    } finally {
      _isSyncing = false;
    }
  }

  // Setup real-time listener for transactions
  Stream<List<TransactionModel>> streamTransactions() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _getUserCollection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Sync single transaction (called after add/edit/delete)
  Future<void> syncTransaction(TransactionModel transaction, {bool isDelete = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docRef = _getUserCollection('transactions').doc(transaction.id?.toString());

      if (isDelete) {
        await docRef.delete();
      } else {
        await docRef.set(transaction.toJson(), SetOptions(merge: true));
      }
    } catch (e) {
      // Silent fail - background sync
    }
  }

  // Sync single recurring transaction (called after add/edit/delete)
  Future<void> syncRecurringTransaction(Map<String, dynamic> recurring, {bool isDelete = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docRef = _getUserCollection('recurring_transactions').doc(recurring['id']?.toString());

      if (isDelete) {
        await docRef.delete();
      } else {
        await docRef.set(recurring, SetOptions(merge: true));
      }
    } catch (e) {
      // Silent fail - background sync
    }
  }

  // Sync wallet account (called after add/edit/delete)
  Future<void> syncWalletAccount(Map<String, dynamic> wallet, {bool isDelete = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docRef = _getUserCollection('wallet_accounts').doc(wallet['id']?.toString());

      if (isDelete) {
        await docRef.delete();
      } else {
        await docRef.set(wallet, SetOptions(merge: true));
      }
    } catch (e) {
      // Silent fail - background sync
    }
  }
}
