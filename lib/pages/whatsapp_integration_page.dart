import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/whatsapp_service.dart';
import '../models/whatsapp_user.dart';

class WhatsAppIntegrationPage extends StatefulWidget {
  const WhatsAppIntegrationPage({super.key});

  @override
  State<WhatsAppIntegrationPage> createState() =>
      _WhatsAppIntegrationPageState();
}

class _WhatsAppIntegrationPageState extends State<WhatsAppIntegrationPage> {
  final WhatsAppService _whatsappService = WhatsAppService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  WhatsAppUser? _whatsappUser;
  bool _isLoading = false;
  String? _verificationCode;

  @override
  void initState() {
    super.initState();
    _loadWhatsAppUser();
  }

  Future<void> _loadWhatsAppUser() async {
    setState(() => _isLoading = true);
    final user = await _whatsappService.getVerifiedWhatsAppUser();
    setState(() {
      _whatsappUser = user;
      _isLoading = false;
    });
  }

  Future<void> _registerPhone() async {
    if (_phoneController.text.trim().isEmpty) {
      _showMessage('Masukkan nomor WhatsApp Anda');
      return;
    }

    setState(() => _isLoading = true);

    final result =
        await _whatsappService.registerWhatsAppNumber(_phoneController.text);

    setState(() => _isLoading = false);

    if (result.startsWith('Error')) {
      _showMessage(result);
    } else {
      setState(() => _verificationCode = result);
      _showMessage(
        'Kode verifikasi: $result\n\nSilakan kirim kode ini ke bot WhatsApp untuk verifikasi.',
        isSuccess: true,
      );
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      _showMessage('Masukkan kode verifikasi');
      return;
    }

    setState(() => _isLoading = true);

    final success =
        await _whatsappService.verifyWhatsAppNumber(_codeController.text);

    setState(() => _isLoading = false);

    if (success) {
      _showMessage('WhatsApp berhasil terverifikasi!', isSuccess: true);
      _loadWhatsAppUser();
      _phoneController.clear();
      _codeController.clear();
      setState(() => _verificationCode = null);
    } else {
      _showMessage('Kode verifikasi salah');
    }
  }

  Future<void> _unregister() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Integrasi WhatsApp?'),
        content: const Text(
          'Anda tidak akan bisa lagi menambah transaksi melalui WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _whatsappService.unregisterWhatsAppNumber();
      setState(() => _isLoading = false);

      if (success) {
        _showMessage('Integrasi WhatsApp berhasil dihapus', isSuccess: true);
        _loadWhatsAppUser();
      } else {
        _showMessage('Gagal menghapus integrasi');
      }
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Integration'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _whatsappUser != null
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _whatsappUser != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _whatsappUser != null
                                    ? 'Terhubung'
                                    : 'Belum Terhubung',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_whatsappUser != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Nomor: ${_whatsappUser!.phoneNumber}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Terverifikasi: ${_formatDate(_whatsappUser!.verifiedAt!)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions
                  if (_whatsappUser == null) ...[
                    const Text(
                      'Cara Menghubungkan WhatsApp',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      '1',
                      'Masukkan nomor WhatsApp Anda',
                    ),
                    _buildInstructionStep(
                      '2',
                      'Sistem akan generate kode verifikasi',
                    ),
                    _buildInstructionStep(
                      '3',
                      'Kirim kode ke bot WhatsApp kami',
                    ),
                    _buildInstructionStep(
                      '4',
                      'Masukkan kode untuk verifikasi',
                    ),

                    const SizedBox(height: 24),

                    // Phone Input
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor WhatsApp',
                        hintText: '08123456789',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText: 'Format: 08xxx atau +62xxx',
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _registerPhone,
                        icon: const Icon(Icons.send),
                        label: const Text('Daftar Nomor'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Verification Code Input
                    if (_verificationCode != null) ...[
                      const SizedBox(height: 24),
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Kode Verifikasi Anda:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _verificationCode!,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 8,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: _verificationCode!),
                                      );
                                      _showMessage('Kode disalin!',
                                          isSuccess: true);
                                    },
                                    icon: const Icon(Icons.copy),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Kirim kode ini ke bot WhatsApp',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: InputDecoration(
                          labelText: 'Masukkan Kode Verifikasi',
                          prefixIcon: const Icon(Icons.key),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _verifyCode,
                          icon: const Icon(Icons.verified),
                          label: const Text('Verifikasi'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Connected - Show Usage Instructions
                    const Text(
                      'Cara Menggunakan Bot WhatsApp',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildUsageCard(
                      'Catat Pengeluaran',
                      'keluar 50000 makan siang',
                      Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _buildUsageCard(
                      'Catat Pemasukan',
                      'masuk 1000000 gaji bulanan',
                      Colors.green,
                    ),

                    const SizedBox(height: 16),

                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '💡 Tips:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTip('Kategori akan otomatis terdeteksi'),
                            _buildTip(
                                'Format: [jenis] [jumlah] [keterangan]'),
                            _buildTip(
                                'Transaksi langsung tersimpan di aplikasi'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _unregister,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Hapus Integrasi'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.teal,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard(String title, String example, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  title.contains('Pengeluaran')
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      example,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: example));
                      _showMessage('Contoh disalin!', isSuccess: true);
                    },
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
