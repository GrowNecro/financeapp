import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/whatsapp_user.dart';
import '../models/transaction_model.dart';

class WhatsAppService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate verification code
  String generateVerificationCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  // Register WhatsApp number
  Future<String> registerWhatsAppNumber(String phoneNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Error: User not logged in';

      // Normalize phone number (add +62 if needed)
      String normalizedPhone = phoneNumber.trim();
      if (normalizedPhone.startsWith('0')) {
        normalizedPhone = '+62${normalizedPhone.substring(1)}';
      } else if (!normalizedPhone.startsWith('+')) {
        normalizedPhone = '+62$normalizedPhone';
      }

      // Check if phone already registered
      final existingQuery = await _firestore
          .collection('whatsapp_users')
          .where('phoneNumber', isEqualTo: normalizedPhone)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        final existing = existingQuery.docs.first;
        if (existing.data()['userId'] != user.uid) {
          return 'Error: Nomor sudah terdaftar untuk user lain';
        }
      }

      // Generate verification code
      final verificationCode = generateVerificationCode();

      final whatsappUser = WhatsAppUser(
        userId: user.uid,
        phoneNumber: normalizedPhone,
        verificationCode: verificationCode,
        isVerified: false,
      );

      // Save to Firestore
      await _firestore
          .collection('whatsapp_users')
          .doc(user.uid)
          .set(whatsappUser.toJson());

      return verificationCode;
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  // Verify WhatsApp number with code
  Future<bool> verifyWhatsAppNumber(String code) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('whatsapp_users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final whatsappUser = WhatsAppUser.fromJson(doc.data()!);

      if (whatsappUser.verificationCode == code) {
        await _firestore
            .collection('whatsapp_users')
            .doc(user.uid)
            .update({
          'isVerified': true,
          'verifiedAt': DateTime.now().toIso8601String(),
          'verificationCode': null, // Clear code after verification
        });
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Get verified WhatsApp user
  Future<WhatsAppUser?> getVerifiedWhatsAppUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('whatsapp_users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      final whatsappUser = WhatsAppUser.fromJson(doc.data()!);
      return whatsappUser.isVerified ? whatsappUser : null;
    } catch (e) {
      return null;
    }
  }

  // Parse WhatsApp message to transaction
  // Format: "keluar 50000 makan siang" atau "masuk 1000000 gaji"
  TransactionModel? parseMessageToTransaction(String message) {
    try {
      final parts = message.trim().toLowerCase().split(' ');
      if (parts.length < 2) return null;

      final typeStr = parts[0];
      final amountStr = parts[1].replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.tryParse(amountStr);

      if (amount == null || amount <= 0) return null;

      TransactionType type;
      String category = 'Lainnya';

      // Determine type
      if (typeStr.contains('keluar') || typeStr.contains('expense')) {
        type = TransactionType.expense;
      } else if (typeStr.contains('masuk') || typeStr.contains('income')) {
        type = TransactionType.income;
      } else {
        return null;
      }

      // Get description (remaining parts)
      String description = 'Transaksi via WhatsApp';
      if (parts.length > 2) {
        description = parts.sublist(2).join(' ');

        // Auto-detect category
        category = _detectCategory(description);
      }

      return TransactionModel(
        date: DateTime.now(),
        description: description,
        category: category,
        type: type,
        amount: amount,
      );
    } catch (e) {
      return null;
    }
  }

  // Auto-detect category from description
  String _detectCategory(String description) {
    final lowerDesc = description.toLowerCase();

    if (lowerDesc.contains('makan') ||
        lowerDesc.contains('makanan') ||
        lowerDesc.contains('restaurant') ||
        lowerDesc.contains('cafe')) {
      return 'Makanan';
    } else if (lowerDesc.contains('transport') ||
        lowerDesc.contains('bensin') ||
        lowerDesc.contains('grab') ||
        lowerDesc.contains('gojek')) {
      return 'Transport';
    } else if (lowerDesc.contains('belanja') ||
        lowerDesc.contains('shopping') ||
        lowerDesc.contains('beli')) {
      return 'Belanja';
    } else if (lowerDesc.contains('tabung') ||
        lowerDesc.contains('saving')) {
      return 'Tabungan';
    } else if (lowerDesc.contains('hiburan') ||
        lowerDesc.contains('nonton') ||
        lowerDesc.contains('game')) {
      return 'Hiburan';
    } else if (lowerDesc.contains('tagihan') ||
        lowerDesc.contains('bill') ||
        lowerDesc.contains('listrik') ||
        lowerDesc.contains('air')) {
      return 'Tagihan';
    } else if (lowerDesc.contains('gaji') ||
        lowerDesc.contains('salary') ||
        lowerDesc.contains('bonus')) {
      return 'Gaji';
    }

    return 'Lainnya';
  }

  // Process incoming WhatsApp message (will be called by webhook)
  Future<String> processWhatsAppMessage(
    String phoneNumber,
    String message,
  ) async {
    try {
      // Find user by phone number
      final userQuery = await _firestore
          .collection('whatsapp_users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .where('isVerified', isEqualTo: true)
          .get();

      if (userQuery.docs.isEmpty) {
        return 'Nomor WhatsApp tidak terdaftar atau belum diverifikasi.';
      }

      final whatsappUser = WhatsAppUser.fromJson(userQuery.docs.first.data());

      // Parse message to transaction
      final transaction = parseMessageToTransaction(message);

      if (transaction == null) {
        return 'Format pesan salah. Gunakan: "keluar [jumlah] [keterangan]" atau "masuk [jumlah] [keterangan]"\n\nContoh:\nkeluar 50000 makan siang\nmasuk 1000000 gaji bulanan';
      }

      // Save transaction to Firestore under the user
      final docRef = _firestore
          .collection('users')
          .doc(whatsappUser.userId)
          .collection('transactions')
          .doc();

      final transactionWithId = TransactionModel(
        id: int.tryParse(docRef.id.substring(0, 8), radix: 16),
        date: transaction.date,
        description: transaction.description,
        category: transaction.category,
        type: transaction.type,
        amount: transaction.amount,
      );

      await docRef.set(transactionWithId.toJson());

      final typeText = transaction.type == TransactionType.expense
          ? 'Pengeluaran'
          : 'Pemasukan';

      return '✅ Transaksi berhasil disimpan!\n\n'
          'Jenis: $typeText\n'
          'Jumlah: Rp ${transaction.amount.toStringAsFixed(0)}\n'
          'Kategori: ${transaction.category}\n'
          'Keterangan: ${transaction.description}';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  // Unregister WhatsApp number
  Future<bool> unregisterWhatsAppNumber() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('whatsapp_users').doc(user.uid).delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}
