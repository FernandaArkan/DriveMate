import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/vehicle_form_dialog.dart';
import 'service_history_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final VehicleRepository _repo = VehicleRepository.instance;
  String _searchQuery = '';
  int? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoUpdated);
    _repo.loadVehicles();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdated);
    super.dispose();
  }

  void _onRepoUpdated() {
    if (mounted) setState(() {});
  }

  Vehicle? get _activeVehicle {
    if (_repo.vehicles.isEmpty) return null;
    if (_selectedVehicleId != null) {
      final found = _repo.vehicles.where((v) => v.id == _selectedVehicleId);
      if (found.isNotEmpty) return found.first;
    }
    return _repo.primaryVehicle ?? _repo.vehicles.first;
  }

  List<Vehicle> get _filteredVehicles {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _repo.vehicles;

    return _repo.vehicles.where((v) {
      return v.name.toLowerCase().contains(query) ||
          v.brand.toLowerCase().contains(query) ||
          v.plate.toLowerCase().contains(query) ||
          v.year.toString().contains(query);
    }).toList();
  }

  Future<void> _openForm({Vehicle? vehicle}) async {
    final result = await showDialog<Vehicle>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VehicleFormDialog(vehicle: vehicle),
    );

    if (!mounted || result == null) return;

    bool success;
    if (vehicle == null) {
      success = await _repo.addVehicle(result);
    } else {
      success = await _repo.updateVehicle(result);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (vehicle == null
                    ? 'Kendaraan berhasil ditambahkan ke database.'
                    : 'Data kendaraan berhasil diperbarui.')
                : 'Gagal memproses data kendaraan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Hapus Kendaraan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus '
            '${vehicle.brand} ${vehicle.name} (${vehicle.plate}) dari database?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || vehicle.id == null) return;

    final success = await _repo.deleteVehicle(vehicle.id!);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Kendaraan berhasil dihapus.'
                : 'Gagal menghapus kendaraan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showDetailModal(Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vehicle.status,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow('Nomor Polisi', vehicle.plate),
              _detailRow('Tahun Pembuatan', '${vehicle.year}'),
              _detailRow('Total Jarak Tempuh', '${_formatMileage(vehicle.mileage)} km'),
              _detailRow('Kapasitas Bahan Bakar', '${vehicle.fuelLevel}%'),
              _detailRow('Servis Terakhir', vehicle.lastServiceDate ?? '10 Mar 2025'),
              _detailRow('Jatuh Tempo Pajak', vehicle.taxDueDate ?? '12 Jul 2026'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCostModal(Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimasi Biaya Perawatan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Untuk ${vehicle.brand} ${vehicle.name} (${vehicle.plate})',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              _detailRow('Servis Berkala Berikutnya', 'Rp 1.250.000'),
              _detailRow('Estimasi Ganti Oli', 'Rp 450.000'),
              _detailRow('Pajak Tahunan PKB', 'Rp 3.850.000'),
              _detailRow('Pengeluaran Servis Tahun Ini', 'Rp 2.400.000'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kembali'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDocumentModal(Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dokumen Kendaraan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _detailRow('Nomor Polisi (STNK)', vehicle.plate),
              _detailRow('Masa Berlaku STNK 5 Thn', '12 Juli 2029'),
              _detailRow('Pajak Tahunan', vehicle.taxDueDate ?? '12 Juli 2026'),
              _detailRow('Status BPKB', 'Lengkap (Tersimpan Aman)'),
              _detailRow('Asuransi Kendaraan', 'Comprehensive (All Risk)'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeVehicle;
    final allVehicles = _filteredVehicles;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            // HEADER DENGAN TOMBOL TAMBAH KENDARAAN (PERSIS MOCKUP LAYAR 4)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kendaraan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Kendaraan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // PENCARIAN KENDARAAN
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari nama, merek, atau plat nomor...',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            if (_repo.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (active == null)
              _buildEmptyState()
            else ...[
              // KARTU KENDARAAN AKTIF (PERSIS MOCKUP LAYAR 4)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE5EDF7)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.navy.withValues(alpha: 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${active.brand} ${active.name} ${active.year}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                active.plate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  active.isPrimary ? 'Kendaraan Utama' : 'Kendaraan Tambahan',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Gambar Mobil di Kanan (Mockup Layar 4)
                        SizedBox(
                          width: 130,
                          height: 75,
                          child: Image.asset(
                            'assets/images/honda_civic.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.directions_car_filled_rounded,
                              size: 60,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jarak: ${_formatMileage(active.mileage)} km',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        Text(
                          'Bahan Bakar: ${active.fuelLevel}%',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // PILIH KENDARAAN (JIKA ADA LEBIH DARI 1)
              if (allVehicles.length > 1) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allVehicles.map((v) {
                      final isSelected = v.id == active.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${v.brand} ${v.name} (${v.plate})'),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val && v.id != null) {
                              setState(() => _selectedVehicleId = v.id);
                              _repo.setPrimaryVehicle(v.id!);
                            }
                          },
                          selectedColor: AppTheme.navy,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // MENU LIST KENDARAAN (PERSIS MOCKUP LAYAR 4)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5EDF7)),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.article_outlined,
                      title: 'Detail Kendaraan',
                      onTap: () => _showDetailModal(active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.history_rounded,
                      title: 'Riwayat Servis',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ServiceHistoryPage(initialVehicle: active),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.payments_outlined,
                      title: 'Biaya Perawatan',
                      onTap: () => _showCostModal(active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.description_outlined,
                      title: 'Dokumen Kendaraan',
                      onTap: () => _showDocumentModal(active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.edit_outlined,
                      title: 'Edit Data',
                      onTap: () => _openForm(vehicle: active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Hapus Kendaraan',
                      color: AppTheme.danger,
                      onTap: () => _deleteVehicle(active),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppTheme.textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color == AppTheme.danger ? AppTheme.danger : AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_outlined, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada kendaraan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan kendaraan Anda untuk mulai memantau dan mencatat servis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kendaraan'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMileage(int mileage) {
    return mileage.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
  }
}
