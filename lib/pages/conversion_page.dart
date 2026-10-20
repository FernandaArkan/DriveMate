import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class ConversionPage extends StatefulWidget {
  const ConversionPage({super.key});

  @override
  State<ConversionPage> createState() => _ConversionPageState();
}

class _ConversionPageState extends State<ConversionPage> {
  int _currentTab = 0; // 0 = Mata Uang, 1 = Waktu

  // Mata Uang
  final TextEditingController _amountController = TextEditingController(text: '100');
  String _fromCurrency = 'USD';
  String _toCurrency = 'IDR';
  double _convertedResult = 1542000.0;
  DateTime _lastRatesUpdate = DateTime.now();

  // Kurs dasar terhadap 1 USD
  final Map<String, double> _ratesAgainstUSD = {
    'USD': 1.0,
    'IDR': 15420.0,
    'EUR': 0.92,
    'SGD': 1.34,
    'JPY': 151.5,
    'MYR': 4.72,
  };

  final Map<String, String> _currencyNames = {
    'USD': 'USD - US Dollar',
    'IDR': 'IDR - Rupiah',
    'EUR': 'EUR - Euro',
    'SGD': 'SGD - Singapore Dollar',
    'JPY': 'JPY - Japanese Yen',
    'MYR': 'MYR - Malaysian Ringgit',
  };

  // Konversi Waktu
  String _fromTz = 'WIB (GMT+7)';
  String _toTz = 'JST (GMT+9)';
  DateTime _selectedTime = DateTime.now();
  String _timeResultText = '';

  final Map<String, int> _tzOffsets = {
    'WIB (GMT+7)': 7,
    'WITA (GMT+8)': 8,
    'WIT (GMT+9)': 9,
    'JST (GMT+9)': 9,
    'UTC (GMT+0)': 0,
    'EST (GMT-5)': -5,
  };

  @override
  void initState() {
    super.initState();
    _calculateCurrency();
    _calculateTime();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculateCurrency() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final fromRate = _ratesAgainstUSD[_fromCurrency] ?? 1.0;
    final toRate = _ratesAgainstUSD[_toCurrency] ?? 1.0;

    // Convert: amount in From -> USD -> To
    final inUSD = amount / fromRate;
    final result = inUSD * toRate;

    setState(() {
      _convertedResult = result;
      _lastRatesUpdate = DateTime.now();
    });
  }

  void _swapCurrency() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
    _calculateCurrency();
  }

  void _calculateTime() {
    final fromOffset = _tzOffsets[_fromTz] ?? 7;
    final toOffset = _tzOffsets[_toTz] ?? 9;
    final diffHours = toOffset - fromOffset;

    final targetTime = _selectedTime.add(Duration(hours: diffHours));
    final formatter = DateFormat('EEEE, dd MMM yyyy • HH:mm');

    setState(() {
      _timeResultText =
          '${formatter.format(targetTime)} (${diffHours >= 0 ? "+$diffHours" : "$diffHours"} jam)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Konversi',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Segmented Tab Button
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E9F3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _tabButton(label: 'Mata Uang', index: 0),
                  ),
                  Expanded(
                    child: _tabButton(label: 'Waktu', index: 1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            if (_currentTab == 0) _buildCurrencySection() else _buildTimeSection(),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({required String label, required int index}) {
    final isSelected = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencySection() {
    final currencyFormatter = NumberFormat.currency(
      locale: _toCurrency == 'IDR' ? 'id_ID' : 'en_US',
      symbol: _toCurrency == 'IDR'
          ? 'Rp '
          : (_toCurrency == 'USD' ? '\$ ' : '$_toCurrency '),
      decimalDigits: _toCurrency == 'IDR' ? 0 : 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Konversi Mata Uang',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Input Jumlah
        const Text('Jumlah', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _calculateCurrency(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Dropdown Dari
        const Text('Dari', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        _currencyDropdown(
          value: _fromCurrency,
          onChanged: (val) {
            if (val != null) {
              setState(() => _fromCurrency = val);
              _calculateCurrency();
            }
          },
        ),

        const SizedBox(height: 10),

        Center(
          child: IconButton.filledTonal(
            onPressed: _swapCurrency,
            icon: const Icon(Icons.swap_vert_rounded, color: AppTheme.primary),
          ),
        ),

        const SizedBox(height: 10),

        // Dropdown Ke
        const Text('Ke', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        _currencyDropdown(
          value: _toCurrency,
          onChanged: (val) {
            if (val != null) {
              setState(() => _toCurrency = val);
              _calculateCurrency();
            }
          },
        ),

        const SizedBox(height: 20),

        // Hasil Box (Mockup Layar 9)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E9F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hasil Konversi', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.primary),
                    onPressed: _calculateCurrency,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                currencyFormatter.format(_convertedResult),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '1 USD = 15.420 IDR • Update: ${DateFormat('HH:mm:ss').format(_lastRatesUpdate)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currencyDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9F3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: _ratesAgainstUSD.keys.map((code) {
            return DropdownMenuItem(
              value: code,
              child: Text(
                _currencyNames[code] ?? code,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Konversi Waktu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        const Text('Dari Zona Waktu', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        _tzDropdown(
          value: _fromTz,
          onChanged: (val) {
            if (val != null) {
              setState(() => _fromTz = val);
              _calculateTime();
            }
          },
        ),

        const SizedBox(height: 16),

        const Text('Ke Zona Waktu', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        _tzDropdown(
          value: _toTz,
          onChanged: (val) {
            if (val != null) {
              setState(() => _toTz = val);
              _calculateTime();
            }
          },
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              setState(() => _selectedTime = DateTime.now());
              _calculateTime();
            },
            child: const Text('Perbarui Waktu Real-Time'),
          ),
        ),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E9F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Waktu Hasil Konversi', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text(
                _timeResultText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Waktu Acuan: ${DateFormat('dd MMM yyyy, HH:mm').format(_selectedTime)} ($_fromTz)',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tzDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9F3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: _tzOffsets.keys.map((tz) {
            return DropdownMenuItem(
              value: tz,
              child: Text(tz, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
