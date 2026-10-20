import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import '../theme/app_theme.dart';

class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({super.key, this.initialVehicle});

  final Vehicle? initialVehicle;

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<ServiceRecord> _records = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';
  bool _isChainValid = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final vehicle = widget.initialVehicle ?? VehicleRepository.instance.primaryVehicle;
    final records = await _dbHelper.getServiceRecords(vehicleId: vehicle?.id);
    final isChainValid = await _dbHelper.verifyBlockchainIntegrity(vehicleId: vehicle?.id);

    if (mounted) {
      setState(() {
        _records = records;
        _isChainValid = isChainValid;
        _isLoading = false;
      });
    }
  }

  List<ServiceRecord> get _filteredRecords {
    if (_selectedFilter == 'Semua') return _records;
    return _records.where((r) => r.serviceType.toLowerCase() == _selectedFilter.toLowerCase()).toList();
  }

  Future<void> _addNewRecord() async {
    final vehicle = widget.initialVehicle ?? VehicleRepository.instance.primaryVehicle;
    if (vehicle == null) return;

    final titleCtrl = TextEditingController();
    final workshopCtrl = TextEditingController(text: 'AutoCare Bengkel');
    final mileageCtrl = TextEditingController(text: '${vehicle.mileage + 1000}');
    final costCtrl = TextEditingController(text: '500000');
    String serviceType = 'Servis';

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Tambah Catatan Servis (Blockchain)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Servis / Pekerjaan',
                    hintText: 'Contoh: Ganti Oli Mesin',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: serviceType,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const [
                    DropdownMenuItem(value: 'Servis', child: Text('Servis')),
                    DropdownMenuItem(value: 'Penggantian', child: Text('Penggantian')),
                    DropdownMenuItem(value: 'Pemeriksaan', child: Text('Pemeriksaan')),
                    DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => serviceType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: workshopCtrl,
                  decoration: const InputDecoration(labelText: 'Bengkel'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mileageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kilometer Kendaraan (km)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Biaya (Rp)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;

                // Ambil block terakhir untuk rantai hash
                final lastRecords = await _dbHelper.getServiceRecords(vehicleId: vehicle.id);
                final prevHash = lastRecords.isNotEmpty
                    ? lastRecords.first.hash
                    : '0000000000000000000000000000000000000000000000000000000000000000';

                final now = DateTime.now();
                final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
                final mileage = int.tryParse(mileageCtrl.text.trim()) ?? vehicle.mileage;
                final cost = int.tryParse(costCtrl.text.trim()) ?? 0;

                final newRec = ServiceRecord(
                  vehicleId: vehicle.id ?? 1,
                  title: titleCtrl.text.trim(),
                  serviceType: serviceType,
                  date: dateStr,
                  mileage: mileage,
                  workshop: workshopCtrl.text.trim(),
                  cost: cost,
                  prevHash: prevHash,
                  timestamp: now.toIso8601String(),
                );

                await _dbHelper.addServiceRecord(newRec);

                // Update juga mileage kendaraan jika bertambah
                if (mileage > vehicle.mileage) {
                  vehicle.mileage = mileage;
                  vehicle.lastServiceDate = dateStr;
                  await VehicleRepository.instance.updateVehicle(vehicle);
                }

                if (context.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Simpan & Hash Blok'),
            ),
          ],
        ),
      ),
    );

    if (added == true) {
      _loadRecords();
    }
  }

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.initialVehicle ?? VehicleRepository.instance.primaryVehicle;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Riwayat Servis',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Catatan Servis',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
            onPressed: _addNewRecord,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Vehicle Header Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5EDF7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle?.brand ?? 'Honda'} ${vehicle?.name ?? 'Civic'} ${vehicle?.year ?? 2022}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicle?.plate ?? 'B 1234 KZ',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isChainValid
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isChainValid ? Icons.verified_rounded : Icons.warning_rounded,
                          size: 14,
                          color: _isChainValid ? AppTheme.success : AppTheme.danger,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isChainValid ? 'Blockchain Valid' : 'Integritas Rusak',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _isChainValid ? AppTheme.success : AppTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Chips Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Servis', 'Penggantian', 'Pemeriksaan', 'Lainnya'].map((chip) {
                  final isSelected = _selectedFilter == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() => _selectedFilter = chip);
                      },
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: AppTheme.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : const Color(0xFFE2E9F3),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_filteredRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada riwayat servis',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              )
            else
              ..._filteredRecords.map((rec) => _buildRecordCard(rec)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(ServiceRecord rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.build_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.date,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rec.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatNumber(rec.mileage)} km • ${rec.workshop}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rec.status,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Hash Info Bar (Blockchain verification)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SHA-256: ${rec.hash.substring(0, 16)}...',
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  rec.cost > 0 ? 'Rp ${_formatNumber(rec.cost)}' : '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
  }
}
