require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const axios = require('axios');

const app = express();
app.use(bodyParser.json());

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  }),
});

const db = admin.firestore();

// WhatsApp Config
const WHATSAPP_API_URL = `https://graph.facebook.com/v18.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`;
const WHATSAPP_TOKEN = process.env.WHATSAPP_ACCESS_TOKEN;

// Send WhatsApp Message
async function sendWhatsAppMessage(to, message) {
  try {
    await axios.post(
      WHATSAPP_API_URL,
      {
        messaging_product: 'whatsapp',
        to: to,
        type: 'text',
        text: { body: message },
      },
      {
        headers: {
          Authorization: `Bearer ${WHATSAPP_TOKEN}`,
          'Content-Type': 'application/json',
        },
      }
    );
    console.log(`✅ Message sent to ${to}`);
  } catch (error) {
    console.error('❌ Error sending message:', error.response?.data || error.message);
  }
}

// Webhook Verification (GET)
app.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === process.env.WHATSAPP_VERIFY_TOKEN) {
    console.log('✅ Webhook verified');
    res.status(200).send(challenge);
  } else {
    res.sendStatus(403);
  }
});

// Webhook Handler (POST)
app.post('/webhook', async (req, res) => {
  try {
    const body = req.body;

    // Check if this is a WhatsApp message
    if (body.object !== 'whatsapp_business_account') {
      return res.sendStatus(404);
    }

    const entry = body.entry?.[0];
    const changes = entry?.changes?.[0];
    const value = changes?.value;

    // Check if there's a message
    if (!value?.messages) {
      return res.sendStatus(200);
    }

    const message = value.messages[0];
    const from = message.from; // Phone number
    const messageText = message.text?.body?.trim();

    console.log(`📨 Message from ${from}: ${messageText}`);

    // Process message
    await processMessage(from, messageText);

    res.sendStatus(200);
  } catch (error) {
    console.error('❌ Webhook error:', error);
    res.sendStatus(500);
  }
});

// Process WhatsApp Message
async function processMessage(phoneNumber, message) {
  try {
    // Normalize phone number
    let normalizedPhone = phoneNumber;
    if (!normalizedPhone.startsWith('+')) {
      normalizedPhone = '+' + normalizedPhone;
    }

    const messageLower = message.toLowerCase();

    // Command: DAFTAR
    if (messageLower === 'daftar') {
      await handleRegister(normalizedPhone);
      return;
    }

    // Command: VERIFY [code]
    if (messageLower.startsWith('verify ')) {
      const code = message.split(' ')[1];
      await handleVerify(normalizedPhone, code);
      return;
    }

    // Command: SALDO
    if (messageLower === 'saldo') {
      await handleBalance(normalizedPhone);
      return;
    }

    // Command: HELP
    if (messageLower === 'help' || messageLower === 'bantuan') {
      await handleHelp(normalizedPhone);
      return;
    }

    // Transaction command
    await handleTransaction(normalizedPhone, message);
  } catch (error) {
    console.error('❌ Process message error:', error);
    await sendWhatsAppMessage(
      phoneNumber,
      '❌ Terjadi kesalahan. Silakan coba lagi.'
    );
  }
}

// Handle DAFTAR command
async function handleRegister(phoneNumber) {
  try {
    // Generate verification code
    const code = Math.floor(1000 + Math.random() * 9000).toString();

    // Check if already registered
    const existingQuery = await db
      .collection('whatsapp_users')
      .where('phoneNumber', '==', phoneNumber)
      .get();

    if (!existingQuery.empty) {
      const existing = existingQuery.docs[0].data();
      if (existing.isVerified) {
        await sendWhatsAppMessage(
          phoneNumber,
          '✅ Nomor Anda sudah terdaftar dan terverifikasi!'
        );
        return;
      }
    }

    // For registration, user must do it from app first
    await sendWhatsAppMessage(
      phoneNumber,
      '⚠️ Untuk mendaftar:\n\n' +
        '1. Buka aplikasi Finance App\n' +
        '2. Pilih menu WhatsApp Integration\n' +
        '3. Daftar nomor Anda\n' +
        '4. Kirim kode verifikasi ke sini'
    );
  } catch (error) {
    console.error('❌ Register error:', error);
    await sendWhatsAppMessage(phoneNumber, '❌ Gagal mendaftar. Silakan coba lagi.');
  }
}

// Handle VERIFY command
async function handleVerify(phoneNumber, code) {
  try {
    const query = await db
      .collection('whatsapp_users')
      .where('phoneNumber', '==', phoneNumber)
      .where('verificationCode', '==', code)
      .get();

    if (query.empty) {
      await sendWhatsAppMessage(
        phoneNumber,
        '❌ Kode verifikasi salah atau tidak ditemukan.'
      );
      return;
    }

    const doc = query.docs[0];
    await doc.ref.update({
      isVerified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verificationCode: null,
    });

    await sendWhatsAppMessage(
      phoneNumber,
      '✅ Verifikasi berhasil!\n\n' +
        'Sekarang Anda bisa catat transaksi:\n\n' +
        '📤 keluar 50000 makan siang\n' +
        '📥 masuk 1000000 gaji\n\n' +
        'Ketik HELP untuk bantuan.'
    );
  } catch (error) {
    console.error('❌ Verify error:', error);
    await sendWhatsAppMessage(phoneNumber, '❌ Gagal verifikasi. Silakan coba lagi.');
  }
}

// Handle SALDO command
async function handleBalance(phoneNumber) {
  try {
    const userQuery = await db
      .collection('whatsapp_users')
      .where('phoneNumber', '==', phoneNumber)
      .where('isVerified', '==', true)
      .get();

    if (userQuery.empty) {
      await sendWhatsAppMessage(
        phoneNumber,
        '❌ Nomor belum terdaftar/terverifikasi.\nKetik DAFTAR untuk memulai.'
      );
      return;
    }

    const userId = userQuery.docs[0].data().userId;

    // Get transactions
    const transactionsRef = await db
      .collection('users')
      .doc(userId)
      .collection('transactions')
      .get();

    let totalIncome = 0;
    let totalExpense = 0;

    transactionsRef.docs.forEach((doc) => {
      const data = doc.data();
      const amount = data.amount || 0;
      if (data.type === 'income') {
        totalIncome += amount;
      } else if (data.type === 'expense') {
        totalExpense += amount;
      }
    });

    const balance = totalIncome - totalExpense;

    const message =
      '💰 *SALDO ANDA*\n\n' +
      `📥 Pemasukan: Rp ${totalIncome.toLocaleString('id-ID')}\n` +
      `📤 Pengeluaran: Rp ${totalExpense.toLocaleString('id-ID')}\n` +
      `━━━━━━━━━━━━━━\n` +
      `💵 Saldo: Rp ${balance.toLocaleString('id-ID')}\n\n` +
      `Total Transaksi: ${transactionsRef.size}`;

    await sendWhatsAppMessage(phoneNumber, message);
  } catch (error) {
    console.error('❌ Balance error:', error);
    await sendWhatsAppMessage(phoneNumber, '❌ Gagal mengambil saldo.');
  }
}

// Handle HELP command
async function handleHelp(phoneNumber) {
  const helpMessage =
    '📖 *PANDUAN FINANCE BOT*\n\n' +
    '🔹 Catat Pengeluaran:\n' +
    'keluar 50000 makan siang\n\n' +
    '🔹 Catat Pemasukan:\n' +
    'masuk 1000000 gaji\n\n' +
    '🔹 Cek Saldo:\n' +
    'SALDO\n\n' +
    '🔹 Bantuan:\n' +
    'HELP\n\n' +
    '💡 Kategori otomatis terdeteksi dari keterangan!';

  await sendWhatsAppMessage(phoneNumber, helpMessage);
}

// Handle Transaction
async function handleTransaction(phoneNumber, message) {
  try {
    // Check if user is verified
    const userQuery = await db
      .collection('whatsapp_users')
      .where('phoneNumber', '==', phoneNumber)
      .where('isVerified', '==', true)
      .get();

    if (userQuery.empty) {
      await sendWhatsAppMessage(
        phoneNumber,
        '❌ Nomor belum terdaftar/terverifikasi.\n\n' +
          'Ketik DAFTAR untuk memulai.'
      );
      return;
    }

    const userId = userQuery.docs[0].data().userId;

    // Parse transaction
    const parts = message.trim().toLowerCase().split(' ');
    if (parts.length < 2) {
      await sendWhatsAppMessage(
        phoneNumber,
        '❌ Format salah!\n\n' +
          'Gunakan:\n' +
          'keluar 50000 makan siang\n' +
          'masuk 1000000 gaji'
      );
      return;
    }

    const typeStr = parts[0];
    const amountStr = parts[1].replace(/[^\d]/g, '');
    const amount = parseFloat(amountStr);

    if (!amount || amount <= 0) {
      await sendWhatsAppMessage(
        phoneNumber,
        '❌ Jumlah tidak valid! Masukkan angka yang benar.'
      );
      return;
    }

    let type;
    if (typeStr.includes('keluar') || typeStr.includes('expense')) {
      type = 'expense';
    } else if (typeStr.includes('masuk') || typeStr.includes('income')) {
      type = 'income';
    } else {
      await sendWhatsAppMessage(
        phoneNumber,
        '❌ Jenis transaksi tidak dikenal!\n\n' +
          'Gunakan "keluar" atau "masuk"'
      );
      return;
    }

    const description = parts.length > 2 ? parts.slice(2).join(' ') : 'Transaksi via WhatsApp';
    const category = detectCategory(description);

    // Save to Firestore
    const transaction = {
      date: new Date().toISOString(),
      description: description,
      category: category,
      type: type,
      amount: amount,
      lastModified: new Date().toISOString(),
    };

    await db
      .collection('users')
      .doc(userId)
      .collection('transactions')
      .add(transaction);

    const typeText = type === 'expense' ? '📤 Pengeluaran' : '📥 Pemasukan';
    const successMessage =
      '✅ *TRANSAKSI TERSIMPAN*\n\n' +
      `${typeText}\n` +
      `💵 Rp ${amount.toLocaleString('id-ID')}\n` +
      `📂 ${category}\n` +
      `📝 ${description}\n\n` +
      'Ketik SALDO untuk cek saldo.';

    await sendWhatsAppMessage(phoneNumber, successMessage);
  } catch (error) {
    console.error('❌ Transaction error:', error);
    await sendWhatsAppMessage(
      phoneNumber,
      '❌ Gagal menyimpan transaksi. Silakan coba lagi.'
    );
  }
}

// Detect Category
function detectCategory(description) {
  const lowerDesc = description.toLowerCase();

  if (
    lowerDesc.includes('makan') ||
    lowerDesc.includes('makanan') ||
    lowerDesc.includes('cafe')
  ) {
    return 'Makanan';
  } else if (
    lowerDesc.includes('transport') ||
    lowerDesc.includes('bensin') ||
    lowerDesc.includes('grab') ||
    lowerDesc.includes('gojek')
  ) {
    return 'Transport';
  } else if (
    lowerDesc.includes('belanja') ||
    lowerDesc.includes('shopping') ||
    lowerDesc.includes('beli')
  ) {
    return 'Belanja';
  } else if (lowerDesc.includes('tabung') || lowerDesc.includes('saving')) {
    return 'Tabungan';
  } else if (
    lowerDesc.includes('hiburan') ||
    lowerDesc.includes('nonton') ||
    lowerDesc.includes('game')
  ) {
    return 'Hiburan';
  } else if (
    lowerDesc.includes('tagihan') ||
    lowerDesc.includes('listrik') ||
    lowerDesc.includes('air')
  ) {
    return 'Tagihan';
  } else if (
    lowerDesc.includes('gaji') ||
    lowerDesc.includes('salary') ||
    lowerDesc.includes('bonus')
  ) {
    return 'Gaji';
  }

  return 'Lainnya';
}

// Health check
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    message: 'WhatsApp Finance Bot Webhook',
    timestamp: new Date().toISOString(),
  });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📱 WhatsApp webhook ready`);
});
