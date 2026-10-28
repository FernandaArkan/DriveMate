import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import '../services/currency_service.dart';
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
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<Vehicle>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VehicleFormDialog(vehicle: vehicle),
    );

    if (!mounted || result == null) return;

    bool success;
    if (vehicle == null) {
      success = await _repo.addVehicle(result);
      if (success && _repo.vehicles.isNotEmpty) {
        _selectedVehicleId = _repo.primaryVehicle?.id ?? _repo.vehicles.last.id;
      }
    } else {
      success = await _repo.updateVehicle(result);
      if (success) {
        _selectedVehicleId = result.id;
      }
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (vehicle == null
                    ? l10n.vehicleAddedSuccess
                    : l10n.vehicleUpdatedSuccess)
                : l10n.vehicleProcessFailed,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            l10n.deleteVehicleConfirmTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            l10n.deleteVehicleConfirmContent(
              vehicle.brand,
              vehicle.name,
              vehicle.plate,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.delete),
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
            success ? l10n.vehicleDeletedSuccess : l10n.vehicleDeleteFailed,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showDetailModal(Vehicle vehicle) {
    final l10n = AppLocalizations.of(context);
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
                      l10n.translateVehicleStatus(vehicle.status),
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
              _detailRow(l10n.plateNumberLabel, vehicle.plate),
              _detailRow(l10n.manufactureYearLabel, '${vehicle.year}'),
              _detailRow(l10n.totalMileageLabel, '${_formatMileage(vehicle.mileage)} km'),
              _detailRow(l10n.fuelCapacityLabel, '${vehicle.fuelLevel}%'),
              _detailRow(l10n.lastServiceLabel, vehicle.lastServiceDate ?? '10 Mar 2025'),
              _detailRow(l10n.taxDueDateLabel, vehicle.taxDueDate ?? '12 Jul 2026'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCostModal(Vehicle vehicle) {
    final l10n = AppLocalizations.of(context);
    final currencyService = CurrencyService.instance;

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
              Text(
                l10n.costEstimationTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.forVehiclePrefix} ${vehicle.brand} ${vehicle.name} (${vehicle.plate})',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              _detailRow(l10n.nextPeriodicService, currencyService.format(1250000)),
              _detailRow(l10n.oilChangeEstimation, currencyService.format(450000)),
              _detailRow(l10n.annualTax, currencyService.format(3850000)),
              _detailRow(l10n.yearServiceExpense, currencyService.format(2400000)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDocumentModal(Vehicle vehicle) {
    final l10n = AppLocalizations.of(context);
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
              Text(
                l10n.vehicleDocumentTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _detailRow('${l10n.plateNumberLabel} (STNK)', vehicle.plate),
              _detailRow(l10n.stnk5YearExpiryLabel, '12 Juli 2029'),
              _detailRow(l10n.annualTaxLabel, vehicle.taxDueDate ?? '12 Juli 2026'),
              _detailRow(l10n.bpkbStatusLabel, l10n.bpkbStatusVal),
              _detailRow(l10n.insuranceLabel, l10n.insuranceVal),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.close),
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
    final l10n = AppLocalizations.of(context);
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
                Text(
                  l10n.vehiclesTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.addVehicleBtn),
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
                hintText: l10n.searchVehicleHint,
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
              _buildEmptyState(l10n)
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
                                  active.isPrimary
                                      ? l10n.primaryVehicleLabel
                                      : l10n.secondaryVehicleLabel,
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
                          '${l10n.distancePrefix}: ${_formatMileage(active.mileage)} km',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        Text(
                          '${l10n.fuelPrefix}: ${active.fuelLevel}%',
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
                      title: l10n.vehicleDetailTitle,
                      onTap: () => _showDetailModal(active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.history_rounded,
                      title: l10n.serviceHistory,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ServiceHistoryPage(initialVehicle: active),
                          ),
                        ).then((_) {
                          _repo.loadVehicles();
                        });
                      },
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.payments_outlined,
                      title: l10n.costEstimation,
                      onTap: () => _showCostModal(active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.description_outlined,
                      title: l10n.vehicleDocumentTitle,
                      onTap: () => _showDocumentModal(active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.edit_outlined,
                      title: l10n.editVehicle,
                      onTap: () => _openForm(vehicle: active),
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                    _buildMenuItem(
                      icon: Icons.delete_outline_rounded,
                      title: l10n.deleteVehicle,
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

  Widget _buildEmptyState(AppLocalizations l10n) {
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
            Text(
              l10n.noVehicleHeader,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noVehicleSub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(l10n.addVehicleBtn),
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
