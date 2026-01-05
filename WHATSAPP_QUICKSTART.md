# 🚀 Quick Start - WhatsApp Bot Integration

## ✅ Yang Sudah Dibuat

### 1. **Flutter App** 
- ✅ Model: `whatsapp_user.dart`
- ✅ Service: `whatsapp_service.dart`
- ✅ UI: `whatsapp_integration_page.dart`
- ✅ Menu di HomePage (icon chat bubble)

### 2. **Webhook Server** (Node.js)
- ✅ `whatsapp-webhook/index.js` - Server utama
- ✅ `whatsapp-webhook/package.json` - Dependencies
- ✅ `whatsapp-webhook/.env.example` - Template config

---

## 📋 Langkah Setup (30 Menit)

### Step 1: Setup Meta WhatsApp API (10 menit)

1. Buka: https://developers.facebook.com/
2. Create App → Business
3. Add Product → WhatsApp
4. Ambil credentials:
   - Phone Number ID
   - Access Token
   - Buat Verify Token sendiri

**Detail lengkap:** [WHATSAPP_SETUP.md](./WHATSAPP_SETUP.md)

### Step 2: Setup Firebase (5 menit)

1. Firebase Console → Project Settings → Service Accounts
2. Generate new private key → Download JSON
3. Extract 3 values:
   - `project_id`
   - `private_key`
   - `client_email`

### Step 3: Deploy Webhook (10 menit)

**Opsi A: Vercel (Recommended)**
```bash
cd whatsapp-webhook
npm install
vercel deploy --prod
```

**Opsi B: Test Local**
```bash
cd whatsapp-webhook
npm install
cp .env.example .env
# Edit .env dengan credentials

npm run dev

# Terminal baru
ngrok http 3000
```

### Step 4: Connect Webhook ke Meta (5 menit)

1. Copy URL dari Vercel/ngrok
2. Meta Console → WhatsApp → Configuration → Webhook
3. Edit → Callback URL: `https://your-url.com/webhook`
4. Verify Token: token yang Anda buat
5. Subscribe: `messages`

---

## 🎯 Testing

### 1. Daftar Nomor di App

```
1. Buka app → Icon chat bubble
2. Input nomor: 08123456789
3. Klik "Daftar Nomor"
4. Copy kode verifikasi (contoh: 1234)
```

### 2. Verifikasi via WhatsApp

Kirim ke nomor WhatsApp Bot:
```
VERIFY 1234
```

### 3. Test Transaksi

```
keluar 50000 makan siang
masuk 1000000 gaji
SALDO
```

---

## 💡 Format Pesan

| Perintah | Contoh |
|----------|--------|
| Daftar | `DAFTAR` |
| Verifikasi | `VERIFY 1234` |
| Pengeluaran | `keluar 50000 makan` |
| Pemasukan | `masuk 1000000 gaji` |
| Cek Saldo | `SALDO` |
| Bantuan | `HELP` |

---

## 🔧 Environment Variables

File: `whatsapp-webhook/.env`

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@xxx.iam.gserviceaccount.com

WHATSAPP_PHONE_NUMBER_ID=123456789
WHATSAPP_ACCESS_TOKEN=EAAxxxxxxxxx
WHATSAPP_VERIFY_TOKEN=MySecretToken123

PORT=3000
```

---

## 🐛 Troubleshooting

### Bot tidak respon
- ✅ Cek server running: `curl https://your-url.com/`
- ✅ Cek logs di Vercel/ngrok
- ✅ Pastikan webhook verified di Meta

### "Nomor belum terdaftar"
- ✅ Daftar dari app dulu
- ✅ Pastikan nomor sama (format +62)
- ✅ Cek Firestore collection `whatsapp_users`

### Webhook verification failed
- ✅ VERIFY_TOKEN harus sama di .env dan Meta
- ✅ Webhook URL harus HTTPS
- ✅ URL format: `https://domain.com/webhook`

---

## 📚 Dokumentasi Lengkap

- **Setup Detail:** [WHATSAPP_SETUP.md](./WHATSAPP_SETUP.md)
- **Webhook README:** [whatsapp-webhook/README.md](./whatsapp-webhook/README.md)

---

## ✨ Fitur

✅ Verifikasi nomor WhatsApp\
✅ Catat transaksi via chat\
✅ Auto-detect kategori\
✅ Cek saldo real-time\
✅ Sync otomatis ke app\
✅ Format pesan sederhana

---

**Selamat mencoba! 🎉**
