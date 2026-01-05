# WhatsApp Bot Webhook untuk Finance App

Backend webhook untuk menerima pesan WhatsApp dan memproses transaksi.

## Setup WhatsApp Business API

### Opsi 1: WhatsApp Cloud API (Gratis - Recommended)

1. **Buat Meta Developer Account**
   - Kunjungi: https://developers.facebook.com/
   - Buat App baru → Pilih "Business" type
   - Tambahkan produk "WhatsApp"

2. **Dapatkan Credentials**
   - Phone Number ID
   - WhatsApp Business Account ID
   - Access Token

3. **Setup Webhook**
   - Verify Token: buat token rahasia sendiri
   - Callback URL: URL server Anda (gunakan ngrok untuk testing)

### Opsi 2: Twilio WhatsApp (Bayar)

1. Buat akun Twilio: https://www.twilio.com/
2. Aktifkan WhatsApp sandbox
3. Dapatkan Account SID dan Auth Token

## Instalasi

```bash
npm install
```

## Environment Variables

Buat file `.env`:

```env
# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="your-private-key"
FIREBASE_CLIENT_EMAIL=your-client-email

# WhatsApp Cloud API (Meta)
WHATSAPP_PHONE_NUMBER_ID=your-phone-number-id
WHATSAPP_ACCESS_TOKEN=your-access-token
WHATSAPP_VERIFY_TOKEN=your-verify-token

# Server
PORT=3000
```

## Download Firebase Service Account

1. Buka Firebase Console → Project Settings
2. Service Accounts → Generate new private key
3. Simpan file JSON
4. Copy credentials ke .env

## Jalankan Server

```bash
# Development
npm run dev

# Production
npm start
```

## Testing dengan Ngrok

```bash
# Install ngrok
npm install -g ngrok

# Jalankan ngrok
ngrok http 3000

# Copy HTTPS URL ke Meta Webhook Config
```

## Format Pesan WhatsApp

### Daftar Nomor
Kirim: `DAFTAR`
Reply: Kode verifikasi

### Verifikasi
Kirim: `VERIFY [kode]`
Reply: Konfirmasi verifikasi

### Catat Transaksi
```
keluar 50000 makan siang
masuk 1000000 gaji
keluar 15000 transportasi
```

### Cek Saldo
Kirim: `SALDO`
Reply: Informasi saldo

## Webhook Events

- `messages` - Menerima pesan masuk
- `message_status` - Status pengiriman pesan

## Error Handling

Server akan otomatis:
- Validasi format pesan
- Verifikasi nomor terdaftar
- Return error message jika gagal

## Security

- Gunakan HTTPS (required by Meta)
- Verify webhook signature
- Rate limiting
- Environment variables untuk credentials

## Deployment

### Vercel (Recommended)
```bash
vercel deploy
```

### Heroku
```bash
heroku create
git push heroku main
```

### Railway
```bash
railway init
railway up
```

## Monitoring

Log disimpan di:
- Console output
- Firebase Firestore (optional)

## Support

Dokumentasi:
- Meta WhatsApp Cloud API: https://developers.facebook.com/docs/whatsapp
- Firebase Admin SDK: https://firebase.google.com/docs/admin/setup
