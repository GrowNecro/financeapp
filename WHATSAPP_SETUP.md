# 🤖 Setup WhatsApp Bot untuk Finance App

## 📋 Overview

Integrasi WhatsApp Bot memungkinkan pengguna untuk:
- ✅ Mencatat transaksi melalui pesan WhatsApp
- ✅ Cek saldo via WhatsApp
- ✅ Kategori otomatis terdeteksi
- ✅ Real-time sync dengan aplikasi

---

## 🎯 Arsitektur Sistem

```
WhatsApp User
     ↓
WhatsApp Cloud API (Meta)
     ↓
Webhook Server (Node.js)
     ↓
Firebase Firestore
     ↓
Flutter App (Real-time sync)
```

---

## 📱 Setup WhatsApp Business API (Meta Cloud API)

### Step 1: Buat Meta Developer Account

1. Kunjungi: https://developers.facebook.com/
2. Login dengan Facebook account
3. Klik **"My Apps"** → **"Create App"**
4. Pilih **"Business"** sebagai app type
5. Isi form:
   - App Name: `Finance Bot`
   - Contact Email: email Anda
   - Business Account: pilih atau buat baru

### Step 2: Setup WhatsApp Product

1. Di dashboard app, klik **"Add Product"**
2. Pilih **"WhatsApp"** → **"Set Up"**
3. Pilih Business Portfolio atau buat baru
4. Tambahkan nomor telepon:
   - Bisa gunakan nomor test gratis dari Meta
   - Atau verifikasi nomor sendiri (untuk production)

### Step 3: Dapatkan Credentials

1. **Phone Number ID:**
   - Di WhatsApp → API Setup
   - Copy **Phone Number ID**

2. **Access Token:**
   - Di WhatsApp → API Setup
   - Copy **Temporary Access Token** (24 jam)
   - Untuk permanent: System Users → Generate Token

3. **Verify Token:**
   - Buat sendiri (string rahasia, contoh: `MySecretToken123`)

### Step 4: Konfigurasi Webhook

**PENTING:** Webhook harus HTTPS!

1. Di WhatsApp → Configuration → Webhook
2. Klik **"Edit"**
3. Isi:
   - **Callback URL:** `https://your-domain.com/webhook`
   - **Verify Token:** token yang Anda buat di Step 3
4. Subscribe ke field: `messages`

---

## 🚀 Deploy Webhook Server

### Opsi 1: Deploy ke Vercel (Recommended)

```bash
cd whatsapp-webhook

# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
vercel deploy --prod
```

Setelah deploy, copy URL HTTPS Anda dan masukkan ke Meta Webhook config.

### Opsi 2: Deploy ke Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Init project
railway init

# Deploy
railway up

# Set environment variables
railway variables set FIREBASE_PROJECT_ID=xxx
railway variables set WHATSAPP_ACCESS_TOKEN=xxx
# ... set semua env vars
```

### Opsi 3: Testing Local dengan Ngrok

```bash
# Terminal 1: Jalankan server
cd whatsapp-webhook
npm install
npm run dev

# Terminal 2: Jalankan ngrok
ngrok http 3000

# Copy HTTPS URL dari ngrok (contoh: https://abc123.ngrok.io)
# Paste ke Meta Webhook → Callback URL: https://abc123.ngrok.io/webhook
```

---

## 🔧 Konfigurasi Environment Variables

### 1. Firebase Admin SDK

#### Download Service Account Key:

1. Buka Firebase Console: https://console.firebase.google.com/
2. Pilih project Anda
3. Settings (⚙️) → Project Settings
4. Tab **"Service Accounts"**
5. Klik **"Generate new private key"**
6. Download file JSON

#### Extract Credentials dari JSON:

```json
{
  "project_id": "your-project-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",
  "client_email": "firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com"
}
```

### 2. Buat file `.env`

```bash
cd whatsapp-webhook
cp .env.example .env
```

Edit `.env`:

```env
# Firebase
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour private key\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com

# WhatsApp
WHATSAPP_PHONE_NUMBER_ID=123456789012345
WHATSAPP_ACCESS_TOKEN=EAAxxxxxxxxxxxxx
WHATSAPP_VERIFY_TOKEN=MySecretToken123

# Server
PORT=3000
```

**PENTING untuk Private Key:**
- Harus dalam quotes
- Tetap pakai `\n` untuk line breaks
- Jangan hapus `-----BEGIN` dan `-----END`

---

## 📱 Setup di Aplikasi Flutter

### 1. Jalankan Aplikasi

```bash
flutter run
```

### 2. Daftar Nomor WhatsApp

1. Buka aplikasi
2. Klik icon **WhatsApp** di AppBar
3. Masukkan nomor WhatsApp (format: 08xxx atau +62xxx)
4. Klik **"Daftar Nomor"**
5. Copy kode verifikasi yang muncul

### 3. Verifikasi via WhatsApp

Kirim pesan ke nomor WhatsApp Bot Meta:

```
VERIFY [kode-verifikasi]
```

Contoh:
```
VERIFY 1234
```

Bot akan reply: ✅ Verifikasi berhasil!

---

## 💬 Cara Menggunakan Bot

### Catat Pengeluaran

```
keluar 50000 makan siang
keluar 15000 transportasi
keluar 100000 belanja bulanan
```

### Catat Pemasukan

```
masuk 1000000 gaji
masuk 500000 bonus
```

### Cek Saldo

```
SALDO
```

### Bantuan

```
HELP
```

---

## 🎨 Auto-Detect Kategori

Bot otomatis mendeteksi kategori dari keterangan:

| Keywords | Kategori |
|----------|----------|
| makan, makanan, cafe | Makanan |
| transport, bensin, grab, gojek | Transport |
| belanja, shopping, beli | Belanja |
| tabung, saving | Tabungan |
| hiburan, nonton, game | Hiburan |
| tagihan, listrik, air | Tagihan |
| gaji, salary, bonus | Gaji |
| lainnya | Lainnya |

---

## 🔍 Testing Webhook

### Test Verification (GET)

```bash
curl "https://your-domain.com/webhook?hub.mode=subscribe&hub.verify_token=MySecretToken123&hub.challenge=test123"
```

Response: `test123`

### Test Health Check

```bash
curl https://your-domain.com/
```

Response:
```json
{
  "status": "ok",
  "message": "WhatsApp Finance Bot Webhook",
  "timestamp": "2026-01-05T10:30:00.000Z"
}
```

---

## 🐛 Troubleshooting

### Bot tidak merespon

1. Cek server running: `curl https://your-domain.com/`
2. Cek logs di server
3. Verifikasi webhook di Meta Console
4. Pastikan nomor terverifikasi di database

### Webhook verification failed

1. Cek VERIFY_TOKEN sama dengan yang di Meta
2. Pastikan endpoint `/webhook` accessible
3. Harus HTTPS (tidak bisa HTTP)

### Transaksi tidak masuk ke app

1. Cek Firestore rules (harus allow write)
2. Cek Firebase credentials benar
3. Refresh app untuk sync
4. Cek logs error di webhook

### Error "Nomor belum terdaftar"

1. Daftar nomor dari aplikasi dulu
2. Pastikan format nomor sama (gunakan +62)
3. Verifikasi dengan kode yang benar

---

## 🔐 Security Best Practices

1. **Environment Variables:**
   - Jangan commit `.env` ke git
   - Gunakan secret management di hosting

2. **Firestore Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /whatsapp_users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId}/transactions/{transactionId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

3. **Rate Limiting:**
   - Implementasi rate limit di webhook
   - Cegah spam messages

---

## 📊 Monitoring

### Check Logs

**Vercel:**
```bash
vercel logs
```

**Railway:**
```bash
railway logs
```

**Local:**
```bash
npm run dev
# Logs muncul di console
```

### Monitor Firestore

1. Firebase Console → Firestore Database
2. Cek collection `whatsapp_users`
3. Cek collection `users/{userId}/transactions`

---

## 💰 Biaya

### WhatsApp Cloud API (Meta)

- **Gratis:** 1000 conversations/bulan
- **Berbayar:** $0.005 - $0.09 per conversation
- Test number: Gratis unlimited

### Hosting

- **Vercel:** Gratis untuk personal
- **Railway:** $5/bulan (include $5 credit)
- **Heroku:** $7/bulan

### Firebase

- **Spark Plan (Gratis):**
  - 50K reads/day
  - 20K writes/day
  - 1GB storage

---

## 🎉 Selesai!

Sekarang Anda bisa catat transaksi via WhatsApp!

### Next Steps:

1. ✅ Deploy webhook server
2. ✅ Setup WhatsApp Business API
3. ✅ Daftar nomor di aplikasi
4. ✅ Mulai catat transaksi via WhatsApp!

### Support

Jika ada masalah:
- Cek logs di server
- Cek Firestore data
- Verifikasi semua credentials
- Test dengan ngrok local dulu

---

**Happy Tracking! 💸📱**
