import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomNumberKeyboard extends StatefulWidget {
  final Function(double) onConfirm;
  final String title;
  final double? initialValue;
  final bool allowZero;

  const CustomNumberKeyboard({
    super.key,
    required this.onConfirm,
    this.title = 'Masukkan Nominal',
    this.initialValue,
    this.allowZero = false,
  });

  @override
  State<CustomNumberKeyboard> createState() => _CustomNumberKeyboardState();
}

class _CustomNumberKeyboardState extends State<CustomNumberKeyboard> {
  String _displayValue = '0';
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      if (widget.initialValue! > 0 || (widget.allowZero && widget.initialValue! == 0)) {
        _displayValue = widget.initialValue!.toInt().toString();
      }
    }
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_displayValue == '0') {
        _displayValue = number;
      } else {
        _displayValue += number;
      }
    });
  }

  void _onClear() {
    setState(() {
      _displayValue = '0';
    });
  }

  void _onBackspace() {
    setState(() {
      if (_displayValue.length > 1) {
        _displayValue = _displayValue.substring(0, _displayValue.length - 1);
      } else {
        _displayValue = '0';
      }
    });
  }

  void _onConfirm() {
    final value = double.tryParse(_displayValue) ?? 0;
    if (value > 0 || (widget.allowZero && value == 0)) {
      widget.onConfirm(value);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal yang valid'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = double.tryParse(_displayValue) ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _displayValue,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(currentValue),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Keyboard
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Row 1: 1, 2, 3
                Row(
                  children: [
                    _buildNumberButton('1'),
                    const SizedBox(width: 8),
                    _buildNumberButton('2'),
                    const SizedBox(width: 8),
                    _buildNumberButton('3'),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: 4, 5, 6
                Row(
                  children: [
                    _buildNumberButton('4'),
                    const SizedBox(width: 8),
                    _buildNumberButton('5'),
                    const SizedBox(width: 8),
                    _buildNumberButton('6'),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 3: 7, 8, 9
                Row(
                  children: [
                    _buildNumberButton('7'),
                    const SizedBox(width: 8),
                    _buildNumberButton('8'),
                    const SizedBox(width: 8),
                    _buildNumberButton('9'),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 4: 00, 0, 000
                Row(
                  children: [
                    _buildNumberButton('00'),
                    const SizedBox(width: 8),
                    _buildNumberButton('0'),
                    const SizedBox(width: 8),
                    _buildNumberButton('000'),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 5: Clear, Backspace, OK
                Row(
                  children: [
                    _buildActionButton(
                      'C',
                      Icons.clear,
                      Colors.red,
                      _onClear,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      '⌫',
                      Icons.backspace_outlined,
                      Colors.orange,
                      _onBackspace,
                    ),
                    const SizedBox(width: 8),
                    _buildConfirmButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _onNumberPressed(number),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[100],
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Expanded(
      child: ElevatedButton(
        onPressed: _onConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Icon(Icons.check, size: 24),
      ),
    );
  }
}

// Helper function to show the keyboard
Future<double?> showCustomNumberKeyboard(
  BuildContext context, {
  String title = 'Masukkan Nominal',
  double? initialValue,
  bool allowZero = false,
}) async {
  double? result;
  
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CustomNumberKeyboard(
      title: title,
      initialValue: initialValue,
      allowZero: allowZero,
      onConfirm: (value) {
        result = value;
      },
    ),
  );
  
  return result;
}
